import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/domain/rules/net_worth_rules.dart';
import 'package:money_flow/domain/rules/forecast_rules.dart';
import 'package:money_flow/data/repositories/budget_repository.dart';
import 'package:money_flow/data/services/forecast_service.dart';

/// DTO Ringkasan Arus Kas
class CashFlowReport {
  final int totalIncome;
  final int totalExpense;
  final int netCashFlow;
  final int transactionCount;
  final DateTime startDate;
  final DateTime endDate;
  final List<MonthlyFlowItem> monthlyTrends;

  const CashFlowReport({
    required this.totalIncome,
    required this.totalExpense,
    required this.netCashFlow,
    required this.transactionCount,
    required this.startDate,
    required this.endDate,
    required this.monthlyTrends,
  });
}

class MonthlyFlowItem {
  final String monthLabel;
  final int year;
  final int month;
  final int income;
  final int expense;
  final int netFlow;

  const MonthlyFlowItem({
    required this.monthLabel,
    required this.year,
    required this.month,
    required this.income,
    required this.expense,
    required this.netFlow,
  });
}

/// DTO Laporan Kategori
class CategoryBreakdownItem {
  final int categoryId;
  final String categoryName;
  final String? icon;
  final String? color;
  final int totalAmount;
  final double percentage;
  final int transactionCount;

  const CategoryBreakdownItem({
    required this.categoryId,
    required this.categoryName,
    this.icon,
    this.color,
    required this.totalAmount,
    required this.percentage,
    required this.transactionCount,
  });
}

/// DTO Saldo Akun
class AccountBalanceReportItem {
  final int accountId;
  final String accountName;
  final AccountType type;
  final int balance;
  final double shareOfTotal;

  const AccountBalanceReportItem({
    required this.accountId,
    required this.accountName,
    required this.type,
    required this.balance,
    required this.shareOfTotal,
  });
}

/// DTO Anggaran vs Realisasi
class BudgetVsActualItem {
  final int categoryId;
  final String categoryName;
  final String? icon;
  final int budgetAmount;
  final int actualSpent;
  final int remaining;
  final double usedPercent;
  final BudgetAlertStatus status;

  const BudgetVsActualItem({
    required this.categoryId,
    required this.categoryName,
    this.icon,
    required this.budgetAmount,
    required this.actualSpent,
    required this.remaining,
    required this.usedPercent,
    required this.status,
  });
}

/// DTO Laporan Keuangan Menyeluruh (Comprehensive Financial Report)
class FinancialComprehensiveReport {
  final DateTime startDate;
  final DateTime endDate;
  final CashFlowReport cashFlow;
  final List<CategoryBreakdownItem> expenseCategories;
  final List<CategoryBreakdownItem> incomeSources;
  final List<AccountBalanceReportItem> accountBalances;
  final List<BudgetVsActualItem> budgetRealizations;
  final int totalCashBalance;
  final int totalInvestmentsValue;
  final int totalInvestmentsCost;
  final int totalDepositsPrincipal;
  final int totalReceivables;
  final int totalDebts;
  final int totalAssets;
  final int netWorth;
  final ForecastReport forecast;

  const FinancialComprehensiveReport({
    required this.startDate,
    required this.endDate,
    required this.cashFlow,
    required this.expenseCategories,
    required this.incomeSources,
    required this.accountBalances,
    required this.budgetRealizations,
    required this.totalCashBalance,
    required this.totalInvestmentsValue,
    required this.totalInvestmentsCost,
    required this.totalDepositsPrincipal,
    required this.totalReceivables,
    required this.totalDebts,
    required this.totalAssets,
    required this.netWorth,
    required this.forecast,
  });
}

/// Service Laporan Keuangan berbasis agregasi database SQL efisien.
class ReportService {
  final AppDatabase _db;
  final ForecastService _forecastService;

  ReportService(this._db, this._forecastService);

  /// Dapatkan laporan arus kas pada rentang tanggal tertentu.
  Future<CashFlowReport> getCashFlowReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // 1. Agregasi total Income dan Expense menggunakan SQL
    final txns = await (_db.select(_db.transactions)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(startDate) &
              t.date.isSmallerOrEqualValue(endDate) &
              t.isActual.equals(true)))
        .get();

    var totalIncome = 0;
    var totalExpense = 0;
    final monthlyMap =
        <String, ({int year, int month, int income, int expense})>{};

    for (final t in txns) {
      final key = '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}';
      final current = monthlyMap[key] ??
          (year: t.date.year, month: t.date.month, income: 0, expense: 0);

      if (t.type == TransactionType.income) {
        totalIncome += t.amount;
        monthlyMap[key] = (
          year: current.year,
          month: current.month,
          income: current.income + t.amount,
          expense: current.expense,
        );
      } else if (t.type == TransactionType.expense) {
        totalExpense += t.amount;
        monthlyMap[key] = (
          year: current.year,
          month: current.month,
          income: current.income,
          expense: current.expense + t.amount,
        );
      }
    }

    final sortedKeys = monthlyMap.keys.toList()..sort();
    final monthlyTrends = sortedKeys.map((k) {
      final item = monthlyMap[k]!;
      const monthNames = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des'
      ];
      final label = '${monthNames[item.month]} ${item.year}';
      return MonthlyFlowItem(
        monthLabel: label,
        year: item.year,
        month: item.month,
        income: item.income,
        expense: item.expense,
        netFlow: item.income - item.expense,
      );
    }).toList();

    return CashFlowReport(
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      netCashFlow: totalIncome - totalExpense,
      transactionCount: txns.length,
      startDate: startDate,
      endDate: endDate,
      monthlyTrends: monthlyTrends,
    );
  }

  /// Dapatkan rincian pengeluaran per kategori.
  Future<List<CategoryBreakdownItem>> getCategoryBreakdown({
    required DateTime startDate,
    required DateTime endDate,
    TransactionType type = TransactionType.expense,
  }) async {
    final query = _db.select(_db.transactions).join([
      innerJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.transactions.categoryId),
      ),
    ]);

    query.where(
      _db.transactions.type.equals(type.index) &
          _db.transactions.date.isBiggerOrEqualValue(startDate) &
          _db.transactions.date.isSmallerOrEqualValue(endDate) &
          _db.transactions.isActual.equals(true),
    );

    final rows = await query.get();

    final aggMap = <int,
        ({String name, String? icon, String? color, int total, int count})>{};
    var grandTotal = 0;

    for (final row in rows) {
      final t = row.readTable(_db.transactions);
      final c = row.readTable(_db.categories);

      grandTotal += t.amount;
      final existing = aggMap[c.id];
      if (existing == null) {
        aggMap[c.id] = (
          name: c.name,
          icon: c.icon,
          color: c.color,
          total: t.amount,
          count: 1,
        );
      } else {
        aggMap[c.id] = (
          name: c.name,
          icon: c.icon,
          color: c.color,
          total: existing.total + t.amount,
          count: existing.count + 1,
        );
      }
    }

    final result = aggMap.entries.map((entry) {
      final pct =
          grandTotal > 0 ? (entry.value.total / grandTotal) * 100.0 : 0.0;
      return CategoryBreakdownItem(
        categoryId: entry.key,
        categoryName: entry.value.name,
        icon: entry.value.icon,
        color: entry.value.color,
        totalAmount: entry.value.total,
        percentage: pct,
        transactionCount: entry.value.count,
      );
    }).toList();

    result.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    return result;
  }

  /// Dapatkan rincian saldo per akun aktif.
  Future<List<AccountBalanceReportItem>> getAccountBalances() async {
    final accounts = await (_db.select(_db.accounts)
          ..where((a) => a.isActive.equals(true))
          ..orderBy([(a) => OrderingTerm.desc(a.balance)]))
        .get();

    final total = accounts.fold<int>(
        0, (sum, a) => sum + (a.balance > 0 ? a.balance : 0));

    return accounts.map((a) {
      final share =
          total > 0 && a.balance > 0 ? (a.balance / total) * 100.0 : 0.0;
      return AccountBalanceReportItem(
        accountId: a.id,
        accountName: a.name,
        type: a.type,
        balance: a.balance,
        shareOfTotal: share,
      );
    }).toList();
  }

  /// Dapatkan laporan anggaran versus realisasi untuk bulan tertentu.
  Future<List<BudgetVsActualItem>> getBudgetVsActualReport({
    required int year,
    required int month,
  }) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);

    final budgetList = await (_db.select(_db.budgets)
          ..where((b) => b.year.equals(year) & b.month.equals(month)))
        .get();

    final categoryMap = {
      for (final c in await _db.select(_db.categories).get()) c.id: c
    };

    // Ambil pengeluaran per kategori di bulan ini
    final expenses = await (_db.select(_db.transactions)
          ..where((t) =>
              t.type.equals(TransactionType.expense.index) &
              t.date.isBiggerOrEqualValue(start) &
              t.date.isSmallerOrEqualValue(end) &
              t.isActual.equals(true)))
        .get();

    final spentByCategory = <int, int>{};
    for (final t in expenses) {
      spentByCategory[t.categoryId] =
          (spentByCategory[t.categoryId] ?? 0) + t.amount;
    }

    final items = <BudgetVsActualItem>[];
    for (final b in budgetList) {
      final cat = categoryMap[b.categoryId];
      final spent = spentByCategory[b.categoryId] ?? 0;
      final remaining = (b.amount - spent > 0) ? b.amount - spent : 0;
      final percent = b.amount > 0 ? (spent / b.amount) * 100.0 : 0.0;
      final status = percent > 100.0
          ? BudgetAlertStatus.exceeded
          : (percent >= 80.0
              ? BudgetAlertStatus.nearLimit
              : BudgetAlertStatus.safe);

      items.add(BudgetVsActualItem(
        categoryId: b.categoryId,
        categoryName: cat?.name ?? 'Kategori #${b.categoryId}',
        icon: cat?.icon,
        budgetAmount: b.amount,
        actualSpent: spent,
        remaining: remaining,
        usedPercent: percent,
        status: status,
      ));
    }

    items.sort((a, b) => b.budgetAmount.compareTo(a.budgetAmount));
    return items;
  }

  /// Bangun laporan komprehensif lengkap.
  Future<FinancialComprehensiveReport> getComprehensiveReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final now = DateTime.now();
    final start = startDate ?? DateTime(now.year, now.month, 1);
    final end = endDate ?? DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final cashFlow = await getCashFlowReport(startDate: start, endDate: end);
    final expenseBreakdown = await getCategoryBreakdown(
        startDate: start, endDate: end, type: TransactionType.expense);
    final incomeBreakdown = await getCategoryBreakdown(
        startDate: start, endDate: end, type: TransactionType.income);
    final accounts = await getAccountBalances();
    final budgetVsActual =
        await getBudgetVsActualReport(year: start.year, month: start.month);

    // Investasi aktif
    final invs = await (_db.select(_db.investments)
          ..where((i) => i.isActive.equals(true)))
        .get();
    final totalInvCost = invs.fold<int>(0, (sum, i) => sum + i.initialCost);
    final totalInvVal = invs.fold<int>(0, (sum, i) => sum + i.currentValue);

    // Deposito aktif
    final deps = await (_db.select(_db.deposits)
          ..where((d) => d.status.isNotIn([DepositStatus.withdrawn.index])))
        .get();
    final totalDeps = deps.fold<int>(0, (sum, d) => sum + d.principal);

    // Hutang & Piutang
    final debts = await (_db.select(_db.debts)
          ..where((d) => d.status.equals(DebtStatus.active.index)))
        .get();
    var totalHutang = 0;
    var totalPiutang = 0;
    for (final d in debts) {
      if (d.type == DebtType.hutang) {
        totalHutang += d.remainingAmount;
      } else if (d.type == DebtType.piutang) {
        totalPiutang += d.remainingAmount;
      }
    }

    final totalCash = accounts.fold<int>(0, (sum, a) => sum + a.balance);

    final totalAssets = NetWorthRules.totalAssets(
      totalBalance: totalCash,
      totalInvestmentValue: totalInvVal,
      totalDeposit: totalDeps,
      totalPiutang: totalPiutang,
    );

    final netWorth = NetWorthRules.netWorth(
      totalBalance: totalCash,
      totalInvestmentValue: totalInvVal,
      totalDeposit: totalDeps,
      totalPiutang: totalPiutang,
      totalHutang: totalHutang,
    );

    final forecast =
        await _forecastService.generateForecast(projectionMonths: 6);

    return FinancialComprehensiveReport(
      startDate: start,
      endDate: end,
      cashFlow: cashFlow,
      expenseCategories: expenseBreakdown,
      incomeSources: incomeBreakdown,
      accountBalances: accounts,
      budgetRealizations: budgetVsActual,
      totalCashBalance: totalCash,
      totalInvestmentsValue: totalInvVal,
      totalInvestmentsCost: totalInvCost,
      totalDepositsPrincipal: totalDeps,
      totalReceivables: totalPiutang,
      totalDebts: totalHutang,
      totalAssets: totalAssets,
      netWorth: netWorth,
      forecast: forecast,
    );
  }
}

final reportServiceProvider = Provider<ReportService>((ref) {
  final db = ref.watch(databaseProvider);
  final forecast = ref.watch(forecastServiceProvider);
  return ReportService(db, forecast);
});
