import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:money_flow/core/database/database.dart';

class SavingsGoalSummary {
  final int totalTarget;
  final int totalSaved;
  final int activeGoalsCount;
  final int achievedGoalsCount;

  const SavingsGoalSummary({
    required this.totalTarget,
    required this.totalSaved,
    required this.activeGoalsCount,
    required this.achievedGoalsCount,
  });
}

class SavingsGoalRepository {
  final AppDatabase _db;
  static const _uuid = Uuid();

  SavingsGoalRepository(this._db);

  /// Watch semua target tabungan (aktif & tercapai).
  Stream<List<SavingsGoal>> watchGoals() {
    return (_db.select(_db.savingsGoals)
          ..where((g) => g.status.isNotIn([SavingsGoalStatus.cancelled.index]))
          ..orderBy([
            (g) => OrderingTerm.asc(g.status),
            (g) => OrderingTerm.desc(g.createdAt)
          ]))
        .watch();
  }

  /// Get semua target tabungan.
  Future<List<SavingsGoal>> getGoals() {
    return (_db.select(_db.savingsGoals)
          ..where((g) => g.status.isNotIn([SavingsGoalStatus.cancelled.index]))
          ..orderBy([
            (g) => OrderingTerm.asc(g.status),
            (g) => OrderingTerm.desc(g.createdAt)
          ]))
        .get();
  }

  /// Ambil satu target berdasarkan ID.
  Future<SavingsGoal?> getById(int id) {
    return (_db.select(_db.savingsGoals)..where((g) => g.id.equals(id)))
        .getSingleOrNull();
  }

  /// Watch ringkasan target tabungan.
  Stream<SavingsGoalSummary> watchSummary() {
    return watchGoals().map((goals) {
      var totalTarget = 0;
      var totalSaved = 0;
      var activeCount = 0;
      var achievedCount = 0;

      for (final g in goals) {
        if (g.status == SavingsGoalStatus.active) {
          totalTarget += g.targetAmount;
          totalSaved += g.currentAmount;
          activeCount++;
        } else if (g.status == SavingsGoalStatus.achieved) {
          achievedCount++;
        }
      }

      return SavingsGoalSummary(
        totalTarget: totalTarget,
        totalSaved: totalSaved,
        activeGoalsCount: activeCount,
        achievedGoalsCount: achievedCount,
      );
    });
  }

  /// Buat target tabungan baru.
  Future<SavingsGoal> create({
    required String name,
    required int targetAmount,
    int currentAmount = 0,
    DateTime? targetDate,
    int? targetAccountId,
    bool isVirtual = true,
    String? notes,
  }) async {
    final now = DateTime.now();
    final companion = SavingsGoalsCompanion(
      uuid: Value(_uuid.v4()),
      name: Value(name),
      targetAmount: Value(targetAmount),
      currentAmount: Value(currentAmount),
      targetDate: Value(targetDate),
      targetAccountId: Value(targetAccountId),
      isVirtual: Value(isVirtual),
      notes: Value(notes),
      status: Value(currentAmount >= targetAmount
          ? SavingsGoalStatus.achieved
          : SavingsGoalStatus.active),
      createdAt: Value(now),
      updatedAt: Value(now),
    );

    final id = await _db.into(_db.savingsGoals).insert(companion);
    return (await getById(id))!;
  }

  /// Update data target tabungan.
  Future<void> update(
    int id, {
    String? name,
    int? targetAmount,
    int? currentAmount,
    DateTime? targetDate,
    int? targetAccountId,
    bool? isVirtual,
    String? notes,
    SavingsGoalStatus? status,
  }) async {
    final companion = SavingsGoalsCompanion(
      name: name != null ? Value(name) : const Value.absent(),
      targetAmount:
          targetAmount != null ? Value(targetAmount) : const Value.absent(),
      currentAmount:
          currentAmount != null ? Value(currentAmount) : const Value.absent(),
      targetDate: targetDate != null ? Value(targetDate) : const Value.absent(),
      targetAccountId: targetAccountId != null
          ? Value(targetAccountId)
          : const Value.absent(),
      isVirtual: isVirtual != null ? Value(isVirtual) : const Value.absent(),
      notes: notes != null ? Value(notes) : const Value.absent(),
      status: status != null ? Value(status) : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    );

    await (_db.update(_db.savingsGoals)..where((g) => g.id.equals(id)))
        .write(companion);
  }

  /// Tambah kontribusi tabungan.
  Future<void> addContribution(
    int id,
    int amount, {
    int? sourceAccountId,
  }) async {
    final goal = await getById(id);
    if (goal == null) return;

    final now = DateTime.now();
    final newAmount = goal.currentAmount + amount;
    final isAchieved = newAmount >= goal.targetAmount;

    await _db.transaction(() async {
      await (_db.update(_db.savingsGoals)..where((g) => g.id.equals(id))).write(
        SavingsGoalsCompanion(
          currentAmount: Value(newAmount),
          status: Value(isAchieved
              ? SavingsGoalStatus.achieved
              : SavingsGoalStatus.active),
          updatedAt: Value(now),
        ),
      );

      // Jika alokasi dipotong langsung dari akun nyata
      if (sourceAccountId != null) {
        final acc = await (_db.select(_db.accounts)
              ..where((a) => a.id.equals(sourceAccountId)))
            .getSingleOrNull();

        if (acc != null) {
          await (_db.update(_db.accounts)
                ..where((a) => a.id.equals(sourceAccountId)))
              .write(
            AccountsCompanion(
              balance: Value(acc.balance - amount),
              updatedAt: Value(now),
            ),
          );
        }
      }
    });
  }

  /// Hapus target tabungan (status cancelled).
  Future<void> delete(int id) async {
    await (_db.update(_db.savingsGoals)..where((g) => g.id.equals(id))).write(
      SavingsGoalsCompanion(
        status: const Value(SavingsGoalStatus.cancelled),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}

final savingsGoalRepositoryProvider = Provider<SavingsGoalRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SavingsGoalRepository(db);
});
