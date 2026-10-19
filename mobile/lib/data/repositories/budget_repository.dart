import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:uuid/uuid.dart';

/// Status evaluasi anggaran kategori
enum BudgetAlertStatus {
  safe, // < 80%
  nearLimit, // 80% - 100%
  exceeded, // > 100%
}

/// DTO untuk status anggaran kategori bulanan
class CategoryBudgetSummary {
  final Budget? budget;
  final Category category;
  final int budgetAmount;
  final int actualSpent;
  final int remaining;
  final double percentage;
  final BudgetAlertStatus alertStatus;

  const CategoryBudgetSummary({
    required this.budget,
    required this.category,
    required this.budgetAmount,
    required this.actualSpent,
    required this.remaining,
    required this.percentage,
    required this.alertStatus,
  });

  bool get hasBudget => budget != null && budgetAmount > 0;
}

/// DTO ringkasan total anggaran bulanan
class MonthlyBudgetSummary {
  final int year;
  final int month;
  final int totalBudgeted;
  final int totalSpent;
  final int totalRemaining;
  final double totalPercentage;
  final List<CategoryBudgetSummary> items;

  const MonthlyBudgetSummary({
    required this.year,
    required this.month,
    required this.totalBudgeted,
    required this.totalSpent,
    required this.totalRemaining,
    required this.totalPercentage,
    required this.items,
  });
}

/// Repository untuk manajemen Anggaran (Budget) bulanan per kategori.
class BudgetRepository {
  final AppDatabase _db;
  final Uuid _uuid;

  BudgetRepository(this._db, [Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  /// Simpan atau perbarui anggaran bulanan suatu kategori
  Future<Budget> setBudget({
    required int categoryId,
    required int year,
    required int month,
    required int amount,
  }) async {
    final existing = await (_db.select(_db.budgets)
          ..where((tbl) =>
              tbl.categoryId.equals(categoryId) &
              tbl.year.equals(year) &
              tbl.month.equals(month)))
        .getSingleOrNull();

    final now = DateTime.now();

    if (existing != null) {
      final updated = existing.copyWith(
        amount: amount,
        updatedAt: now,
      );
      await _db.update(_db.budgets).replace(updated);
      return updated;
    } else {
      final companion = BudgetsCompanion.insert(
        uuid: Value(_uuid.v4()),
        categoryId: categoryId,
        year: year,
        month: month,
        amount: amount,
        createdAt: Value(now),
        updatedAt: Value(now),
      );
      final id = await _db.into(_db.budgets).insert(companion);
      return (await (_db.select(_db.budgets)..where((t) => t.id.equals(id)))
          .getSingle());
    }
  }

  /// Hapus anggaran
  Future<void> deleteBudget(int id) async {
    await (_db.delete(_db.budgets)..where((tbl) => tbl.id.equals(id))).go();
  }

  /// Ambil ringkasan performa anggaran bulanan untuk periode tertentu.
  /// Memperhitungkan:
  /// - Transaksi pengeluaran (expense)
  /// - Transaksi refund (mengurangi beban pengeluaran)
  /// - Mengabaikan transaksi yang bukan actual
  /// - Transfer tidak termasuk karena berada di tabel berbeda
  Future<MonthlyBudgetSummary> getMonthlyBudgetSummary(
      int year, int month) async {
    // 1. Ambil semua kategori pengeluaran aktif
    final expenseCategories = await (_db.select(_db.categories)
          ..where((t) =>
              t.type.equals(CategoryType.expense.index) &
              t.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();

    // 2. Ambil semua baris budget untuk tahun dan bulan ini
    final budgetRows = await (_db.select(_db.budgets)
          ..where((t) => t.year.equals(year) & t.month.equals(month)))
        .get();

    final budgetMap = {for (final b in budgetRows) b.categoryId: b};

    // 3. Rentang tanggal bulan ini
    final startDate = DateTime(year, month, 1);
    final nextMonthDate =
        month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
    final endDate = nextMonthDate.subtract(const Duration(milliseconds: 1));

    // 4. Ambil semua transaksi actual untuk bulan ini
    final txList = await (_db.select(_db.transactions)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(startDate) &
              t.date.isSmallerOrEqualValue(endDate) &
              t.isActual.equals(true) &
              (t.type.equals(TransactionType.expense.index) |
                  t.type.equals(TransactionType.refund.index))))
        .get();

    // 5. Agregasikan per kategori (expense menambah, refund mengurangi)
    final spentMap = <int, int>{};
    for (final tx in txList) {
      final current = spentMap[tx.categoryId] ?? 0;
      if (tx.type == TransactionType.expense) {
        spentMap[tx.categoryId] = current + tx.amount;
      } else if (tx.type == TransactionType.refund) {
        spentMap[tx.categoryId] = current - tx.amount;
      }
    }

    final items = <CategoryBudgetSummary>[];
    int totalBudgeted = 0;
    int totalSpent = 0;

    for (final cat in expenseCategories) {
      final b = budgetMap[cat.id];
      final budgetAmount = b?.amount ?? 0;
      final actualSpent = spentMap[cat.id] ?? 0;
      final remaining = budgetAmount - actualSpent;
      final percentage = budgetAmount > 0
          ? (actualSpent / budgetAmount * 100)
          : (actualSpent > 0 ? 100.0 : 0.0);

      BudgetAlertStatus alertStatus;
      if (budgetAmount <= 0) {
        alertStatus = actualSpent > 0
            ? BudgetAlertStatus.nearLimit
            : BudgetAlertStatus.safe;
      } else if (actualSpent > budgetAmount) {
        alertStatus = BudgetAlertStatus.exceeded;
      } else if (percentage >= 80) {
        alertStatus = BudgetAlertStatus.nearLimit;
      } else {
        alertStatus = BudgetAlertStatus.safe;
      }

      totalBudgeted += budgetAmount;
      totalSpent += actualSpent;

      items.add(CategoryBudgetSummary(
        budget: b,
        category: cat,
        budgetAmount: budgetAmount,
        actualSpent: actualSpent,
        remaining: remaining,
        percentage: percentage,
        alertStatus: alertStatus,
      ));
    }

    final totalRemaining = totalBudgeted - totalSpent;
    final totalPercentage = totalBudgeted > 0
        ? (totalSpent / totalBudgeted * 100)
        : (totalSpent > 0 ? 100.0 : 0.0);

    return MonthlyBudgetSummary(
      year: year,
      month: month,
      totalBudgeted: totalBudgeted,
      totalSpent: totalSpent,
      totalRemaining: totalRemaining,
      totalPercentage: totalPercentage,
      items: items,
    );
  }

  /// Stream perubahan data anggaran bulan terkait
  Stream<List<Budget>> watchBudgets(int year, int month) {
    return (_db.select(_db.budgets)
          ..where((t) => t.year.equals(year) & t.month.equals(month)))
        .watch();
  }

  /// Ambil riwayat transaksi actual pada kategori dan bulan tertentu
  Future<List<Transaction>> getCategoryTransactions(
      int categoryId, int year, int month) {
    final startDate = DateTime(year, month, 1);
    final nextMonthDate =
        month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
    final endDate = nextMonthDate.subtract(const Duration(milliseconds: 1));

    return (_db.select(_db.transactions)
          ..where((t) =>
              t.categoryId.equals(categoryId) &
              t.date.isBiggerOrEqualValue(startDate) &
              t.date.isSmallerOrEqualValue(endDate) &
              t.isActual.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.date)]))
        .get();
  }
}

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return BudgetRepository(db);
});
