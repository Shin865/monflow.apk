import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/domain/rules/purchase_plan_rules.dart';

class PurchasePlanSummary {
  final int totalActiveTarget;
  final int totalAllocated;
  final int totalHistoryTarget;
  final int activeCount;
  final int monthlyCommittedSavings;

  const PurchasePlanSummary({
    required this.totalActiveTarget,
    required this.totalAllocated,
    required this.totalHistoryTarget,
    required this.activeCount,
    required this.monthlyCommittedSavings,
  });
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

  /// Watch ringkasan rencana pembelian.
  Stream<PurchasePlanSummary> watchSummary() {
    return watchPlans().map((plans) {
      var totalActive = 0;
      var totalAllocated = 0;
      var totalHistory = 0;
      var activeCount = 0;
      var monthlyCommitted = 0;

      final now = DateTime.now();

      for (final p in plans) {
        if (p.status == PlanStatus.active) {
          totalActive += p.targetAmount;
          totalAllocated += p.allocatedAmount;
          activeCount++;
          monthlyCommitted += PurchasePlanRules.monthlyRequired(
            targetAmount: p.targetAmount,
            currentSaving: p.allocatedAmount,
            targetDate: p.targetDate,
            today: now,
          );
        } else if (p.status == PlanStatus.achieved) {
          totalHistory += p.targetAmount;
        }
      }

      return PurchasePlanSummary(
        totalActiveTarget: totalActive,
        totalAllocated: totalAllocated,
        totalHistoryTarget: totalHistory,
        activeCount: activeCount,
        monthlyCommittedSavings: monthlyCommitted,
      );
    });
  }

  /// Buat rencana pembelian baru.
  Future<PurchasePlan> create({
    required String name,
    required int targetAmount,
    int allocatedAmount = 0,
    DateTime? targetDate,
    PlanPriority priority = PlanPriority.medium,
    String? category,
    String? urlLink,
    String? description,
  }) async {
    final now = DateTime.now();
    final companion = PurchasePlansCompanion(
      uuid: Value(_uuid.v4()),
      name: Value(name),
      targetAmount: Value(targetAmount),
      allocatedAmount: Value(allocatedAmount),
      targetDate: Value(targetDate),
      priority: Value(priority),
      status: Value(allocatedAmount >= targetAmount
          ? PlanStatus.achieved
          : PlanStatus.active),
      category: Value(category),
      urlLink: Value(urlLink),
      description: Value(description),
      createdAt: Value(now),
      updatedAt: Value(now),
    );

    final id = await _db.into(_db.purchasePlans).insert(companion);
    return (await getById(id))!;
  }

  /// Update data rencana pembelian.
  Future<void> update(
    int id, {
    String? name,
    int? targetAmount,
    int? allocatedAmount,
    DateTime? targetDate,
    PlanPriority? priority,
    PlanStatus? status,
    String? category,
    String? urlLink,
    String? description,
  }) async {
    final companion = PurchasePlansCompanion(
      name: name != null ? Value(name) : const Value.absent(),
      targetAmount:
          targetAmount != null ? Value(targetAmount) : const Value.absent(),
      allocatedAmount: allocatedAmount != null
          ? Value(allocatedAmount)
          : const Value.absent(),
      targetDate: targetDate != null ? Value(targetDate) : const Value.absent(),
      priority: priority != null ? Value(priority) : const Value.absent(),
      status: status != null ? Value(status) : const Value.absent(),
      category: category != null ? Value(category) : const Value.absent(),
      urlLink: urlLink != null ? Value(urlLink) : const Value.absent(),
      description:
          description != null ? Value(description) : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    );

    await (_db.update(_db.purchasePlans)..where((p) => p.id.equals(id)))
        .write(companion);
  }

  /// Tambah alokasi tabungan untuk rencana pembelian.
  Future<void> addSaving(int id, int amount) async {
    final plan = await getById(id);
    if (plan == null) return;

    final now = DateTime.now();
    final newAlloc = plan.allocatedAmount + amount;
    final isAchieved = newAlloc >= plan.targetAmount;

    await (_db.update(_db.purchasePlans)..where((p) => p.id.equals(id))).write(
      PurchasePlansCompanion(
        allocatedAmount: Value(newAlloc),
        status: Value(isAchieved ? PlanStatus.achieved : PlanStatus.active),
        updatedAt: Value(now),
      ),
    );
  }

  /// Realisasi rencana pembelian menjadi transaksi pengeluaran nyata.
  ///
  /// Sesuai desktop `complete_plan`:
  /// - Memotong saldo dompet yang dipilih
  /// - Mencatat transaksi pengeluaran (EXPENSE)
  /// - Mengubah status rencana menjadi achieved
  Future<void> completePlan(
    int id, {
    required int accountId,
    required int categoryId,
    int? amount,
    DateTime? date,
  }) async {
    final plan = await getById(id);
    if (plan == null) return;

    final now = DateTime.now();
    final expenseDate = date ?? now;
    final expenseAmount = amount ?? plan.targetAmount;

    await _db.transaction(() async {
      final account = await (_db.select(_db.accounts)
            ..where((a) => a.id.equals(accountId)))
          .getSingleOrNull();

      if (account == null) {
        throw ArgumentError('Dompet tidak ditemukan');
      }

      // Potong saldo dompet
      await (_db.update(_db.accounts)..where((a) => a.id.equals(accountId)))
          .write(
        AccountsCompanion(
          balance: Value(account.balance - expenseAmount),
          updatedAt: Value(now),
        ),
      );

      // Catat transaksi pengeluaran
      await _db.into(_db.transactions).insert(
            TransactionsCompanion(
              uuid: Value(_uuid.v4()),
              type: const Value(TransactionType.expense),
              accountId: Value(accountId),
              categoryId: Value(categoryId),
              amount: Value(expenseAmount),
              date: Value(expenseDate),
              description: Value('Realisasi Rencana: ${plan.name}'),
              isActual: const Value(true),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      // Tandai rencana achieved
      await (_db.update(_db.purchasePlans)..where((p) => p.id.equals(id)))
          .write(
        PurchasePlansCompanion(
          allocatedAmount: Value(plan.targetAmount),
          status: const Value(PlanStatus.achieved),
          updatedAt: Value(now),
        ),
      );
    });
  }

  /// Batalkan / hapus rencana pembelian.
  Future<void> delete(int id) async {
    await (_db.update(_db.purchasePlans)..where((p) => p.id.equals(id))).write(
      PurchasePlansCompanion(
        status: const Value(PlanStatus.cancelled),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}

final purchasePlanRepositoryProvider = Provider<PurchasePlanRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return PurchasePlanRepository(db);
});
