import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:uuid/uuid.dart';

/// DTO dengan data tagihan lengkap beserta total pembayaran dan relasi
class EnrichedBill {
  final Bill bill;
  final Category? category;
  final int totalPaid;
  final int remaining;
  final List<BillPayment> payments;

  const EnrichedBill({
    required this.bill,
    this.category,
    required this.totalPaid,
    required this.remaining,
    required this.payments,
  });

  bool get isPaid => bill.status == BillStatus.paid;
  bool get isOverdue => bill.status == BillStatus.overdue;
  bool get isDueSoon => bill.status == BillStatus.dueSoon;
}

/// Repository untuk mengelola tagihan, tagihan berulang (lazy generator),
/// dan pembayaran tagihan secara atomik.
class BillRepository {
  final AppDatabase _db;
  final Uuid _uuid;

  BillRepository(this._db, [Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  /// Hitung status tagihan berdasarkan tanggal jatuh tempo dan total terbayar
  BillStatus calculateBillStatus(DateTime dueDate, int amount, int totalPaid,
      [DateTime? referenceNow]) {
    if (totalPaid >= amount) {
      return BillStatus.paid;
    }
    final now = referenceNow ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);

    if (due.isBefore(today)) {
      return BillStatus.overdue;
    } else if (due.isBefore(today.add(const Duration(days: 8)))) {
      return BillStatus.dueSoon;
    } else {
      return BillStatus.upcoming;
    }
  }

  /// Tambah tagihan baru (sekali bayar atau template tagihan berulang)
  Future<Bill> createBill({
    required String name,
    required int amount,
    required DateTime dueDate,
    bool isRecurring = false,
    BillFrequency frequency = BillFrequency.monthly,
    int? categoryId,
    String? description,
  }) async {
    final now = DateTime.now();
    final dueDay = isRecurring ? dueDate.day : null;
    final status = calculateBillStatus(dueDate, amount, 0, now);

    final companion = BillsCompanion.insert(
      uuid: Value(_uuid.v4()),
      name: name,
      amount: amount,
      dueDate: dueDate,
      dueDay: Value(dueDay),
      frequency: Value(frequency),
      isRecurring: Value(isRecurring),
      categoryId: Value(categoryId),
      description: Value(description),
      status: Value(status),
      isActive: const Value(true),
      createdAt: Value(now),
      updatedAt: Value(now),
    );

    final id = await _db.into(_db.bills).insert(companion);
    return (await (_db.select(_db.bills)..where((t) => t.id.equals(id)))
        .getSingle());
  }

  /// Perbarui tagihan
  Future<Bill> updateBill({
    required int id,
    String? name,
    int? amount,
    DateTime? dueDate,
    bool? isRecurring,
    BillFrequency? frequency,
    int? categoryId,
    String? description,
  }) async {
    final existing = await (_db.select(_db.bills)
          ..where((t) => t.id.equals(id)))
        .getSingle();
    final payments = await (_db.select(_db.billPayments)
          ..where((t) => t.billId.equals(id)))
        .get();
    final totalPaid = payments.fold<int>(0, (sum, p) => sum + p.amount);

    final targetAmount = amount ?? existing.amount;
    final targetDueDate = dueDate ?? existing.dueDate;
    final newStatus =
        calculateBillStatus(targetDueDate, targetAmount, totalPaid);

    final updated = existing.copyWith(
      name: name ?? existing.name,
      amount: targetAmount,
      dueDate: targetDueDate,
      dueDay:
          Value(isRecurring == true ? (targetDueDate.day) : existing.dueDay),
      isRecurring: isRecurring ?? existing.isRecurring,
      frequency: frequency ?? existing.frequency,
      categoryId: Value(categoryId ?? existing.categoryId),
      description: Value(description ?? existing.description),
      status: newStatus,
      updatedAt: DateTime.now(),
    );

    await _db.update(_db.bills).replace(updated);
    return updated;
  }

  /// Hapus tagihan (soft-delete dengan menonaktifkan isActive)
  Future<void> deleteBill(int id) async {
    final existing = await (_db.select(_db.bills)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (existing != null) {
      await _db.update(_db.bills).replace(existing.copyWith(
            isActive: false,
            updatedAt: DateTime.now(),
          ));
    }
  }

  /// Eksekusi pembayaran tagihan secara atomik:
  /// 1. Catat baris BillPayment
  /// 2. Buat Transaksi Pengeluaran (is_actual: true)
  /// 3. Kurangi saldo Akun terkait
  /// 4. Perbarui status Tagihan
  Future<EnrichedBill> payBill({
    required int billId,
    required int accountId,
    required int amount,
    required DateTime date,
    String? notes,
  }) async {
    return await _db.transaction(() async {
      final bill = await (_db.select(_db.bills)
            ..where((t) => t.id.equals(billId)))
          .getSingle();
      final account = await (_db.select(_db.accounts)
            ..where((t) => t.id.equals(accountId)))
          .getSingle();

      // 1. Catat pembayaran tagihan
      final paymentCompanion = BillPaymentsCompanion.insert(
        uuid: Value(_uuid.v4()),
        billId: billId,
        amount: amount,
        date: date,
        accountId: accountId,
        notes: Value(notes),
        createdAt: Value(DateTime.now()),
      );
      await _db.into(_db.billPayments).insert(paymentCompanion);

      // 2. Buat transaksi pengeluaran
      final txCompanion = TransactionsCompanion.insert(
        uuid: Value(_uuid.v4()),
        type: TransactionType.expense,
        accountId: accountId,
        categoryId:
            bill.categoryId ?? 1, // Fallback jika tagihan tanpa kategori
        amount: amount,
        date: date,
        description: Value('Bayar tagihan: ${bill.name}'),
        notes: Value(notes),
        isActual: const Value(true),
        createdAt: Value(DateTime.now()),
        updatedAt: Value(DateTime.now()),
      );
      await _db.into(_db.transactions).insert(txCompanion);

      // 3. Potong saldo akun
      final newBalance = account.balance - amount;
      await _db.update(_db.accounts).replace(account.copyWith(
            balance: newBalance,
            updatedAt: DateTime.now(),
          ));

      // 4. Hitung total bayar & perbarui status tagihan
      final allPayments = await (_db.select(_db.billPayments)
            ..where((t) => t.billId.equals(billId)))
          .get();
      final totalPaid = allPayments.fold<int>(0, (sum, p) => sum + p.amount);
      final newStatus =
          calculateBillStatus(bill.dueDate, bill.amount, totalPaid);

      final updatedBill = bill.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      );
      await _db.update(_db.bills).replace(updatedBill);

      Category? category;
      if (updatedBill.categoryId != null) {
        category = await (_db.select(_db.categories)
              ..where((t) => t.id.equals(updatedBill.categoryId!)))
            .getSingleOrNull();
      }

      return EnrichedBill(
        bill: updatedBill,
        category: category,
        totalPaid: totalPaid,
        remaining:
            (updatedBill.amount - totalPaid).clamp(0, updatedBill.amount),
        payments: allPayments,
      );
    });
  }

  /// Lazy generator untuk tagihan berulang:
  /// Dipanggil saat aplikasi dibuka atau tab tagihan diakses.
  /// Membentuk instans tagihan periode berjalan tanpa menduplikasi data.
  Future<void> generateRecurringInstances([DateTime? referenceDate]) async {
    final now = referenceDate ?? DateTime.now();

    // Ambil semua aturan tagihan berulang yang aktif dan bukan instans turunan
    final templates = await (_db.select(_db.bills)
          ..where((t) =>
              t.isActive.equals(true) &
              t.isRecurring.equals(true) &
              t.parentBillId.isNull()))
        .get();

    for (final template in templates) {
      final periodKey = 'rec_${template.id}_${now.year}_${now.month}';

      // Cek apakah instans periode ini sudah pernah dibuat
      final existing = await (_db.select(_db.bills)
            ..where((t) => t.recurringKey.equals(periodKey)))
          .getSingleOrNull();

      if (existing == null) {
        // Tangani tanggal akhir bulan dengan aman (misal Feb 28/29, Apr 30)
        final lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;
        final targetDay =
            (template.dueDay ?? template.dueDate.day).clamp(1, lastDayOfMonth);
        final instanceDueDate = DateTime(now.year, now.month, targetDay);

        final initialStatus =
            calculateBillStatus(instanceDueDate, template.amount, 0, now);

        await _db.into(_db.bills).insert(BillsCompanion.insert(
              uuid: Value(_uuid.v4()),
              name: template.name,
              amount: template.amount,
              dueDate: instanceDueDate,
              dueDay: Value(targetDay),
              frequency: Value(template.frequency),
              isRecurring: const Value(false), // Instans tunggal
              categoryId: Value(template.categoryId),
              description: Value(template.description),
              status: Value(initialStatus),
              isActive: const Value(true),
              recurringKey: Value(periodKey),
              parentBillId: Value(template.id),
              createdAt: Value(now),
              updatedAt: Value(now),
            ));
      }
    }
  }

  /// Sinkronkan status semua tagihan aktif relatif terhadap tanggal hari ini
  Future<void> refreshAllBillStatuses([DateTime? referenceDate]) async {
    final now = referenceDate ?? DateTime.now();
    final activeBills = await (_db.select(_db.bills)
          ..where((t) => t.isActive.equals(true)))
        .get();

    for (final bill in activeBills) {
      if (bill.status == BillStatus.paid) continue;

      final payments = await (_db.select(_db.billPayments)
            ..where((t) => t.billId.equals(bill.id)))
          .get();
      final totalPaid = payments.fold<int>(0, (sum, p) => sum + p.amount);
      final currentStatus =
          calculateBillStatus(bill.dueDate, bill.amount, totalPaid, now);

      if (currentStatus != bill.status) {
        await _db.update(_db.bills).replace(bill.copyWith(
              status: currentStatus,
              updatedAt: now,
            ));
      }
    }
  }

  /// Ambil daftar tagihan lengkap dengan data relasi
  Future<List<EnrichedBill>> getEnrichedBills(
      {bool includePaid = false}) async {
    var query = _db.select(_db.bills)..where((t) => t.isActive.equals(true));
    if (!includePaid) {
      query = query..where((t) => t.status.isNotIn([BillStatus.paid.index]));
    }
    query = query..orderBy([(t) => OrderingTerm.asc(t.dueDate)]);

    final bills = await query.get();
    final categories = await _db.select(_db.categories).get();
    final catMap = {for (final c in categories) c.id: c};

    final result = <EnrichedBill>[];
    for (final b in bills) {
      final payments = await (_db.select(_db.billPayments)
            ..where((t) => t.billId.equals(b.id)))
          .get();
      final totalPaid = payments.fold<int>(0, (sum, p) => sum + p.amount);
      result.add(EnrichedBill(
        bill: b,
        category: b.categoryId != null ? catMap[b.categoryId] : null,
        totalPaid: totalPaid,
        remaining: (b.amount - totalPaid).clamp(0, b.amount),
        payments: payments,
      ));
    }

    return result;
  }

  /// Stream perubahan tagihan
  Stream<List<Bill>> watchBills({bool includePaid = false}) {
    var query = _db.select(_db.bills)..where((t) => t.isActive.equals(true));
    if (!includePaid) {
      query = query..where((t) => t.status.isNotIn([BillStatus.paid.index]));
    }
    query = query..orderBy([(t) => OrderingTerm.asc(t.dueDate)]);
    return query.watch();
  }

  /// Ambil detail satu tagihan beserta relasinya
  Future<EnrichedBill?> getBillDetail(int id) async {
    final bill = await (_db.select(_db.bills)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    if (bill == null) return null;

    Category? category;
    if (bill.categoryId != null) {
      category = await (_db.select(_db.categories)
            ..where((t) => t.id.equals(bill.categoryId!)))
          .getSingleOrNull();
    }

    final payments = await (_db.select(_db.billPayments)
          ..where((t) => t.billId.equals(id)))
        .get();
    final totalPaid = payments.fold<int>(0, (sum, p) => sum + p.amount);

    return EnrichedBill(
      bill: bill,
      category: category,
      totalPaid: totalPaid,
      remaining: (bill.amount - totalPaid).clamp(0, bill.amount),
      payments: payments,
    );
  }
}

final billRepositoryProvider = Provider<BillRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return BillRepository(db);
});
