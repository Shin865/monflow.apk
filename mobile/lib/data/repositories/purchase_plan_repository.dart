import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:money_flow/core/database/database.dart';

class PurchasePlanSummary {
  final int totalActiveTarget;
  final int totalHistoryTarget;
  final int activeCount;
  final int achievedCount;

  const PurchasePlanSummary({
    required this.totalActiveTarget,
    required this.totalHistoryTarget,
    required this.activeCount,
    required this.achievedCount,
  });

  // Legacy compatibility getters if needed
  int get totalAllocated => 0;
  int get monthlyCommittedSavings => 0;
}

class PurchasePlanRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  PurchasePlanRepository(this._db);

  /// Watch semua rencana pembelian aktif & tercapai.
  Stream<List<PurchasePlan>> watchPlans() {
    return (_db.select(_db.purchasePlans)
          ..where((p) => p.status.isNotIn([PlanStatus.cancelled.index]))
          ..orderBy([
            (p) => OrderingTerm.asc(p.status),
            (p) => OrderingTerm.asc(p.targetDate)
          ]))
        .watch();
  }

  /// Get semua rencana pembelian.
  Future<List<PurchasePlan>> getPlans() {
    return (_db.select(_db.purchasePlans)
          ..where((p) => p.status.isNotIn([PlanStatus.cancelled.index]))
          ..orderBy([
            (p) => OrderingTerm.asc(p.status),
            (p) => OrderingTerm.asc(p.targetDate)
          ]))
        .get();
  }

  /// Ambil satu rencana berdasarkan ID.
  Future<PurchasePlan?> getById(int id) {
    return (_db.select(_db.purchasePlans)..where((p) => p.id.equals(id)))
        .getSingleOrNull();
  }

  /// Watch ringkasan rencana pembelian (tanpa nominal terkumpul).
  Stream<PurchasePlanSummary> watchSummary() {
    return watchPlans().map((plans) {
      var totalActive = 0;
      var totalHistory = 0;
      var activeCount = 0;
      var achievedCount = 0;

      for (final p in plans) {
        if (p.status == PlanStatus.active) {
          totalActive += p.targetAmount;
          activeCount++;
        } else if (p.status == PlanStatus.achieved) {
          totalHistory += p.targetAmount;
          achievedCount++;
        }
      }

      return PurchasePlanSummary(
        totalActiveTarget: totalActive,
        totalHistoryTarget: totalHistory,
        activeCount: activeCount,
        achievedCount: achievedCount,
      );
    });
  }

  /// Watch riwayat perubahan suatu rencana pembelian.
  Stream<List<PurchasePlanHistory>> watchHistories(int planId) {
    return (_db.select(_db.purchasePlanHistories)
          ..where((h) => h.planId.equals(planId))
          ..orderBy([(h) => OrderingTerm.desc(h.timestamp)]))
        .watch();
  }

  /// Ambil riwayat perubahan suatu rencana pembelian.
  Future<List<PurchasePlanHistory>> getHistories(int planId) {
    return (_db.select(_db.purchasePlanHistories)
          ..where((h) => h.planId.equals(planId))
          ..orderBy([(h) => OrderingTerm.desc(h.timestamp)]))
        .get();
  }

  /// Buat rencana pembelian baru dan catat di riwayat audit.
  Future<PurchasePlan> create({
    required String name,
    required int targetAmount,
    DateTime? targetDate,
    PlanPriority priority = PlanPriority.medium,
    String? category,
    String? urlLink,
    String? description,
    int allocatedAmount = 0, // diabaikan untuk UI murni harga rencana
  }) async {
    final now = DateTime.now();
    final companion = PurchasePlansCompanion(
      uuid: Value(_uuid.v4()),
      name: Value(name),
      targetAmount: Value(targetAmount),
      allocatedAmount: const Value(0),
      targetDate: Value(targetDate),
      priority: Value(priority),
      status: const Value(PlanStatus.active),
      category: Value(category),
      urlLink: Value(urlLink),
      description: Value(description),
      createdAt: Value(now),
      updatedAt: Value(now),
    );

    return await _db.transaction(() async {
      final id = await _db.into(_db.purchasePlans).insert(companion);

      // Catat riwayat pembuatan
      await _db.into(_db.purchasePlanHistories).insert(
            PurchasePlanHistoriesCompanion.insert(
              planId: id,
              action: 'created',
              timestamp: Value(now),
              details: Value('Rencana dibuat dengan nominal Rp $targetAmount'),
              notes: Value(description),
            ),
          );

      return (await getById(id))!;
    });
  }

  /// Update data rencana pembelian.
  Future<void> update(
    int id, {
    String? name,
    int? targetAmount,
    DateTime? targetDate,
    PlanPriority? priority,
    PlanStatus? status,
    String? category,
    String? urlLink,
    String? description,
    int? allocatedAmount,
  }) async {
    final plan = await getById(id);
    if (plan == null) return;

    if (plan.status == PlanStatus.achieved &&
        targetAmount != null &&
        targetAmount != plan.targetAmount) {
      throw StateError(
          'Tidak dapat mengubah nominal rencana yang telah direalisasikan.');
    }

    final now = DateTime.now();
    final companion = PurchasePlansCompanion(
      name: name != null ? Value(name) : const Value.absent(),
      targetAmount:
          targetAmount != null ? Value(targetAmount) : const Value.absent(),
      targetDate: targetDate != null ? Value(targetDate) : const Value.absent(),
      priority: priority != null ? Value(priority) : const Value.absent(),
      status: status != null ? Value(status) : const Value.absent(),
      category: category != null ? Value(category) : const Value.absent(),
      urlLink: urlLink != null ? Value(urlLink) : const Value.absent(),
      description:
          description != null ? Value(description) : const Value.absent(),
      updatedAt: Value(now),
    );

    await _db.transaction(() async {
      await (_db.update(_db.purchasePlans)..where((p) => p.id.equals(id)))
          .write(companion);

      // Catat riwayat pembaruan
      await _db.into(_db.purchasePlanHistories).insert(
            PurchasePlanHistoriesCompanion.insert(
              planId: id,
              action: 'updated',
              timestamp: Value(now),
              details: const Value('Informasi rencana diperbarui'),
              notes: Value(description),
            ),
          );
    });
  }

  /// Realisasi rencana pembelian menjadi transaksi pengeluaran nyata.
  ///
  /// Jaminan Konsistensi & Atomisitas:
  /// - Menolak jika rencana sudah berstatus achieved (pencegahan transaksi ganda).
  /// - Memotong saldo dompet yang dipilih tepat satu kali.
  /// - Mencatat transaksi pengeluaran (EXPENSE) aktual.
  /// - Mengubah status rencana menjadi achieved dan menyimpan relasi transactionId.
  /// - Mencatat riwayat realisasi pada tabel audit `purchase_plan_histories`.
  Future<void> completePlan(
    int id, {
    required int accountId,
    required int categoryId,
    int? amount,
    DateTime? date,
    String? notes,
  }) async {
    final plan = await getById(id);
    if (plan == null) {
      throw ArgumentError('Rencana pembelian tidak ditemukan.');
    }

    if (plan.status == PlanStatus.achieved) {
      throw StateError(
          'Rencana pembelian ini sudah direalisasikan sebelumnya.');
    }

    final now = DateTime.now();
    final expenseDate = date ?? now;
    final expenseAmount = amount ?? plan.targetAmount;

    if (expenseAmount <= 0) {
      throw ArgumentError('Nominal realisasi harus lebih besar dari 0.');
    }

    await _db.transaction(() async {
      final account = await (_db.select(_db.accounts)
            ..where((a) => a.id.equals(accountId)))
          .getSingleOrNull();

      if (account == null) {
        throw ArgumentError('Dompet / akun sumber dana tidak ditemukan.');
      }

      // 1. Potong saldo dompet
      await (_db.update(_db.accounts)..where((a) => a.id.equals(accountId)))
          .write(
        AccountsCompanion(
          balance: Value(account.balance - expenseAmount),
          updatedAt: Value(now),
        ),
      );

      // 2. Catat transaksi pengeluaran aktual
      final txnId = await _db.into(_db.transactions).insert(
            TransactionsCompanion(
              uuid: Value(_uuid.v4()),
              type: const Value(TransactionType.expense),
              accountId: Value(accountId),
              categoryId: Value(categoryId),
              amount: Value(expenseAmount),
              date: Value(expenseDate),
              description: Value('Realisasi Rencana: ${plan.name}'),
              notes: Value(notes ?? plan.description),
              isActual: const Value(true),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      // 3. Tandai rencana achieved & simpan relasi transactionId
      await (_db.update(_db.purchasePlans)..where((p) => p.id.equals(id)))
          .write(
        PurchasePlansCompanion(
          status: const Value(PlanStatus.achieved),
          allocatedAmount: Value(expenseAmount),
          transactionId: Value(txnId),
          updatedAt: Value(now),
        ),
      );

      // 4. Catat riwayat audit realisasi
      await _db.into(_db.purchasePlanHistories).insert(
            PurchasePlanHistoriesCompanion.insert(
              planId: id,
              action: 'realized',
              timestamp: Value(now),
              details: Value(
                  'Realisasi sebesar Rp $expenseAmount menggunakan akun ${account.name} (Txn #$txnId)'),
              notes: Value(notes),
            ),
          );
    });
  }

  /// Batalkan realisasi rencana yang telah dilakukan (Pembalikan Transaksi Eksplisit).
  ///
  /// - Mengembalikan saldo akun tepat satu kali.
  /// - Menghapus / membatalkan transaksi pengeluaran.
  /// - Mengembalikan status rencana ke active.
  /// - Mencatat riwayat pembalikan.
  Future<void> cancelRealization(int id) async {
    final plan = await getById(id);
    if (plan == null) {
      throw ArgumentError('Rencana pembelian tidak ditemukan.');
    }

    if (plan.status != PlanStatus.achieved || plan.transactionId == null) {
      throw StateError(
          'Rencana belum direalisasikan atau tidak memiliki transaksi terkait.');
    }

    final now = DateTime.now();
    final txnId = plan.transactionId!;

    await _db.transaction(() async {
      final txn = await (_db.select(_db.transactions)
            ..where((t) => t.id.equals(txnId)))
          .getSingleOrNull();

      if (txn != null) {
        final account = await (_db.select(_db.accounts)
              ..where((a) => a.id.equals(txn.accountId)))
            .getSingleOrNull();

        if (account != null) {
          // Pulihkan saldo akun
          await (_db.update(_db.accounts)
                ..where((a) => a.id.equals(account.id)))
              .write(
            AccountsCompanion(
              balance: Value(account.balance + txn.amount),
              updatedAt: Value(now),
            ),
          );
        }

        // Hapus transaksi pengeluaran realisasi
        await (_db.delete(_db.transactions)..where((t) => t.id.equals(txnId)))
            .go();
      }

      // Reset status rencana
      await (_db.update(_db.purchasePlans)..where((p) => p.id.equals(id)))
          .write(
        PurchasePlansCompanion(
          status: const Value(PlanStatus.active),
          allocatedAmount: const Value(0),
          transactionId: const Value(null),
          updatedAt: Value(now),
        ),
      );

      // Catat riwayat pembatalan realisasi
      await _db.into(_db.purchasePlanHistories).insert(
            PurchasePlanHistoriesCompanion.insert(
              planId: id,
              action: 'unrealized',
              timestamp: Value(now),
              details: const Value(
                  'Pembatalan realisasi: saldo dipulihkan dan pengeluaran dibatalkan.'),
            ),
          );
    });
  }

  /// Batalkan / hapus rencana pembelian.
  /// Jika rencana sudah direalisasikan, transaksi keuangan aktual tidak dihapus secara diam-diam.
  Future<void> delete(int id, {bool hardDelete = false}) async {
    final plan = await getById(id);
    if (plan == null) return;

    final now = DateTime.now();

    await _db.transaction(() async {
      // Catat riwayat pembatalan
      await _db.into(_db.purchasePlanHistories).insert(
            PurchasePlanHistoriesCompanion.insert(
              planId: id,
              action: 'cancelled',
              timestamp: Value(now),
              details: const Value('Rencana pembelian dibatalkan / dihapus'),
            ),
          );

      if (hardDelete && plan.status != PlanStatus.achieved) {
        await (_db.delete(_db.purchasePlanHistories)
              ..where((h) => h.planId.equals(id)))
            .go();
        await (_db.delete(_db.purchasePlans)..where((p) => p.id.equals(id)))
            .go();
      } else {
        await (_db.update(_db.purchasePlans)..where((p) => p.id.equals(id)))
            .write(
          PurchasePlansCompanion(
            status: const Value(PlanStatus.cancelled),
            updatedAt: Value(now),
          ),
        );
      }
    });
  }
}

final purchasePlanRepositoryProvider = Provider<PurchasePlanRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return PurchasePlanRepository(db);
});
