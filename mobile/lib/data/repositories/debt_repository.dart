import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:uuid/uuid.dart';

/// DTO Ringkasan Agregasi Hutang & Piutang
class DebtSummary {
  final int totalHutang;
  final int totalPiutang;
  final int net;

  const DebtSummary({
    required this.totalHutang,
    required this.totalPiutang,
    required this.net,
  });
}

/// DTO Item Cicilan Terjadwal
class InstallmentScheduleItem {
  final int installmentNumber;
  final DateTime dueDate;
  final int expectedAmount;
  final bool isPaid;

  const InstallmentScheduleItem({
    required this.installmentNumber,
    required this.dueDate,
    required this.expectedAmount,
    required this.isPaid,
  });
}

/// DTO Hutang/Piutang lengkap dengan riwayat pembayaran dan jadwal cicilan
class EnrichedDebt {
  final Debt debt;
  final Account? account;
  final int totalPaid;
  final double progress;
  final List<DebtPayment> payments;
  final List<InstallmentScheduleItem> schedule;

  const EnrichedDebt({
    required this.debt,
    this.account,
    required this.totalPaid,
    required this.progress,
    required this.payments,
    required this.schedule,
  });

  bool get isPaid =>
      debt.status == DebtStatus.paid || debt.remainingAmount == 0;
  bool get isOverdue => debt.status == DebtStatus.overdue;
  bool get isHutang => debt.type == DebtType.hutang;
  bool get isPiutang => debt.type == DebtType.piutang;
}

/// Repository untuk manajemen Hutang dan Piutang.
class DebtRepository {
  final AppDatabase _db;
  final Uuid _uuid;

  DebtRepository(this._db, [Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  /// Buat catatan hutang atau piutang baru
  Future<Debt> createDebt({
    required String name,
    required DebtType type,
    required int totalAmount,
    String? person,
    String? description,
    DateTime? dueDate,
    int? tenorMonths,
    int? installmentAmount,
    int? installmentDay,
    double interestRate = 0.0,
    int? accountId,
  }) async {
    final now = DateTime.now();
    final companion = DebtsCompanion.insert(
      uuid: Value(_uuid.v4()),
      name: name,
      type: type,
      totalAmount: totalAmount,
      remainingAmount: totalAmount, // Sisa awal sama dengan pokok awal
      person: Value(person),
      description: Value(description),
      dueDate: Value(dueDate),
      tenorMonths: Value(tenorMonths),
      installmentAmount: Value(installmentAmount),
      installmentDay: Value(installmentDay),
      interestRate: Value(interestRate),
      status: const Value(DebtStatus.active),
      accountId: Value(accountId),
      createdAt: Value(now),
      updatedAt: Value(now),
    );

    final id = await _db.into(_db.debts).insert(companion);
    return (await (_db.select(_db.debts)..where((t) => t.id.equals(id)))
        .getSingle());
  }

  /// Perbarui informasi hutang/piutang
  Future<Debt> updateDebt({
    required int id,
    String? name,
    String? person,
    String? description,
    DateTime? dueDate,
    int? tenorMonths,
    int? installmentAmount,
    int? installmentDay,
    double? interestRate,
  }) async {
    final existing = await (_db.select(_db.debts)
          ..where((t) => t.id.equals(id)))
        .getSingle();

    final updated = existing.copyWith(
      name: name ?? existing.name,
      person: Value(person ?? existing.person),
      description: Value(description ?? existing.description),
      dueDate: Value(dueDate ?? existing.dueDate),
      tenorMonths: Value(tenorMonths ?? existing.tenorMonths),
      installmentAmount: Value(installmentAmount ?? existing.installmentAmount),
      installmentDay: Value(installmentDay ?? existing.installmentDay),
      interestRate: interestRate ?? existing.interestRate,
      updatedAt: DateTime.now(),
    );

    await _db.update(_db.debts).replace(updated);
    return updated;
  }

  /// Hapus hutang/piutang beserta riwayat pembayarannya
  Future<void> deleteDebt(int id) async {
    await _db.transaction(() async {
      await (_db.delete(_db.debtPayments)..where((t) => t.debtId.equals(id)))
          .go();
      await (_db.delete(_db.debts)..where((t) => t.id.equals(id))).go();
    });
  }

  /// Catat pembayaran atau penerimaan cicilan secara atomik.
  /// Memisahkan pokok, bunga, dan biaya:
  /// - Sisa pokok berkurang sebesar `principalAmount`.
  /// - Jika hutang dan ada akun: saldo akun berkurang sebesar total `amount`.
  /// - Jika piutang dan ada akun: saldo akun bertambah sebesar total `amount`.
  Future<EnrichedDebt> recordPayment({
    required int debtId,
    required int amount,
    int? principalAmount,
    int interestAmount = 0,
    int feeAmount = 0,
    required DateTime date,
    int? accountId,
    String? notes,
  }) async {
    return await _db.transaction(() async {
      final debt = await (_db.select(_db.debts)
            ..where((t) => t.id.equals(debtId)))
          .getSingle();

      // Hitung alokasi pokok (default: sisa dari bunga dan biaya atau maksimal sisa pokok)
      final effectivePrincipal = principalAmount ??
          (amount - interestAmount - feeAmount).clamp(0, debt.remainingAmount);

      // 1. Simpan baris DebtPayment
      final paymentCompanion = DebtPaymentsCompanion.insert(
        uuid: Value(_uuid.v4()),
        debtId: debtId,
        amount: amount,
        principalAmount: Value(effectivePrincipal),
        interestAmount: Value(interestAmount),
        feeAmount: Value(feeAmount),
        date: date,
        accountId: Value(accountId),
        notes: Value(notes),
        createdAt: Value(DateTime.now()),
      );
      await _db.into(_db.debtPayments).insert(paymentCompanion);

      // 2. Perbarui sisa pokok hutang/piutang
      final newRemaining = (debt.remainingAmount - effectivePrincipal)
          .clamp(0, debt.totalAmount);
      final newStatus = newRemaining == 0 ? DebtStatus.paid : debt.status;

      final updatedDebt = debt.copyWith(
        remainingAmount: newRemaining,
        status: newStatus,
        updatedAt: DateTime.now(),
      );
      await _db.update(_db.debts).replace(updatedDebt);

      // 3. Mutasi saldo akun keuangan jika ditentukan
      Account? account;
      if (accountId != null) {
        account = await (_db.select(_db.accounts)
              ..where((t) => t.id.equals(accountId)))
            .getSingleOrNull();
        if (account != null) {
          final balanceChange = debt.type == DebtType.hutang ? -amount : amount;
          final updatedAccount = account.copyWith(
            balance: account.balance + balanceChange,
            updatedAt: DateTime.now(),
          );
          await _db.update(_db.accounts).replace(updatedAccount);
          account = updatedAccount;
        }
      }

      // Ambil seluruh data pembayaran untuk DTO
      final payments = await (_db.select(_db.debtPayments)
            ..where((t) => t.debtId.equals(debtId)))
          .get();
      final totalPaid = payments.fold<int>(0, (sum, p) => sum + p.amount);
      final progress =
          debt.totalAmount > 0 ? (totalPaid / debt.totalAmount * 100) : 0.0;
      final schedule = _buildSchedule(updatedDebt, payments);

      return EnrichedDebt(
        debt: updatedDebt,
        account: account,
        totalPaid: totalPaid,
        progress: progress,
        payments: payments,
        schedule: schedule,
      );
    });
  }

  /// Susun jadwal cicilan jika tenor dan installmentAmount tersedia
  List<InstallmentScheduleItem> _buildSchedule(
      Debt debt, List<DebtPayment> payments) {
    final schedule = <InstallmentScheduleItem>[];
    if (debt.tenorMonths == null || debt.tenorMonths! <= 0) return schedule;

    final tenor = debt.tenorMonths!;
    final installmentAmt =
        debt.installmentAmount ?? (debt.totalAmount ~/ tenor);
    final totalPaidPrincipal = payments.fold<int>(
        0,
        (sum, p) =>
            sum + (p.principalAmount > 0 ? p.principalAmount : p.amount));

    final baseDate = debt.dueDate ?? debt.createdAt;
    final day = debt.installmentDay ?? baseDate.day;

    for (int i = 1; i <= tenor; i++) {
      final itemDate = DateTime(baseDate.year, baseDate.month + (i - 1), day);
      final cumulativeExpected = installmentAmt * i;
      final isPaid = totalPaidPrincipal >= cumulativeExpected;

      schedule.add(InstallmentScheduleItem(
        installmentNumber: i,
        dueDate: itemDate,
        expectedAmount: installmentAmt,
        isPaid: isPaid,
      ));
    }

    return schedule;
  }

  /// Ambil ringkasan total hutang, piutang, dan selisih bersih
  Future<DebtSummary> getDebtSummary() async {
    final activeDebts = await (_db.select(_db.debts)
          ..where((t) => t.status.isNotIn([DebtStatus.paid.index])))
        .get();

    int totalHutang = 0;
    int totalPiutang = 0;

    for (final d in activeDebts) {
      if (d.type == DebtType.hutang) {
        totalHutang += d.remainingAmount;
      } else {
        totalPiutang += d.remainingAmount;
      }
    }

    return DebtSummary(
      totalHutang: totalHutang,
      totalPiutang: totalPiutang,
      net: totalPiutang - totalHutang,
    );
  }

  /// Ambil daftar hutang/piutang lengkap
  Future<List<EnrichedDebt>> getEnrichedDebts({
    DebtType? type,
    bool includePaid = false,
  }) async {
    var query = _db.select(_db.debts);
    if (type != null) {
      query = query..where((t) => t.type.equals(type.index));
    }
    if (!includePaid) {
      query = query..where((t) => t.status.isNotIn([DebtStatus.paid.index]));
    }
    query = query..orderBy([(t) => OrderingTerm.asc(t.dueDate)]);

    final debts = await query.get();
    final accounts = await _db.select(_db.accounts).get();
    final accMap = {for (final a in accounts) a.id: a};

    final result = <EnrichedDebt>[];
    for (final d in debts) {
      final payments = await (_db.select(_db.debtPayments)
            ..where((t) => t.debtId.equals(d.id)))
          .get();
      final totalPaid = payments.fold<int>(0, (sum, p) => sum + p.amount);
      final progress =
          d.totalAmount > 0 ? (totalPaid / d.totalAmount * 100) : 0.0;
      final schedule = _buildSchedule(d, payments);

      result.add(EnrichedDebt(
        debt: d,
        account: d.accountId != null ? accMap[d.accountId] : null,
        totalPaid: totalPaid,
        progress: progress,
        payments: payments,
        schedule: schedule,
      ));
    }

    return result;
  }

  /// Stream perubahan hutang/piutang
  Stream<List<Debt>> watchDebts({DebtType? type, bool includePaid = false}) {
    var query = _db.select(_db.debts);
    if (type != null) {
      query = query..where((t) => t.type.equals(type.index));
    }
    if (!includePaid) {
      query = query..where((t) => t.status.isNotIn([DebtStatus.paid.index]));
    }
    query = query..orderBy([(t) => OrderingTerm.asc(t.dueDate)]);
    return query.watch();
  }

  /// Ambil detail satu hutang/piutang
  Future<EnrichedDebt?> getDebtDetail(int id) async {
    final debt = await (_db.select(_db.debts)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (debt == null) return null;

    Account? account;
    if (debt.accountId != null) {
      account = await (_db.select(_db.accounts)
            ..where((t) => t.id.equals(debt.accountId!)))
          .getSingleOrNull();
    }

    final payments = await (_db.select(_db.debtPayments)
          ..where((t) => t.debtId.equals(id)))
        .get();
    final totalPaid = payments.fold<int>(0, (sum, p) => sum + p.amount);
    final progress =
        debt.totalAmount > 0 ? (totalPaid / debt.totalAmount * 100) : 0.0;
    final schedule = _buildSchedule(debt, payments);

    return EnrichedDebt(
      debt: debt,
      account: account,
      totalPaid: totalPaid,
      progress: progress,
      payments: payments,
      schedule: schedule,
    );
  }
}

final debtRepositoryProvider = Provider<DebtRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return DebtRepository(db);
});
