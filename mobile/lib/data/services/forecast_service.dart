import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/domain/rules/forecast_rules.dart';
import 'package:money_flow/domain/rules/purchase_plan_rules.dart';

class ForecastService {
  final AppDatabase _db;

  ForecastService(this._db);

  /// Hitung rata-rata historis (default 3 bulan terakhir sebelum bulan berjalan).
  /// Sesuai desktop backend/app/routes/forecast.py -> _get_historical_averages()
  Future<
      ({
        int avgIncome,
        int avgExpense,
        int transactionCount,
        int distinctMonths
      })> getHistoricalMetrics({int months = 3}) async {
    final today = DateTime.now();
    final firstDayOfCurrentMonth = DateTime(today.year, today.month, 1);
    final startDate = DateTime(today.year, today.month - months, 1);

    final txns = await (_db.select(_db.transactions)
          ..where((t) =>
              t.date.isBiggerOrEqualValue(startDate) &
              t.date.isSmallerThanValue(firstDayOfCurrentMonth) &
              t.isActual.equals(true)))
        .get();

    var totalIncome = 0;
    var totalExpense = 0;
    final distinctMonthKeys = <String>{};

    for (final t in txns) {
      distinctMonthKeys.add('${t.date.year}-${t.date.month}');
      if (t.type == TransactionType.income) {
        totalIncome += t.amount;
      } else if (t.type == TransactionType.expense) {
        totalExpense += t.amount;
      }
    }

    final effectiveMonths = months > 0 ? months : 1;
    final avgIncome = (totalIncome / effectiveMonths).round();
    final avgExpense = (totalExpense / effectiveMonths).round();

    return (
      avgIncome: avgIncome,
      avgExpense: avgExpense,
      transactionCount: txns.length,
      distinctMonths: distinctMonthKeys.length,
    );
  }

  /// Hasilkan laporan forecast 3 skenario secara read-only.
  ///
  /// Tidak pernah memodifikasi saldo akun, tidak mengubah transaksi historis,
  /// dan tidak memasukkan data fiktif ke database.
  Future<ForecastReport> generateForecast({int projectionMonths = 6}) async {
    // 1. Ambil saldo total akun aktif saat ini
    final accounts = await (_db.select(_db.accounts)
          ..where((a) => a.isActive.equals(true)))
        .get();
    final currentBalance = accounts.fold<int>(0, (sum, a) => sum + a.balance);

    // 2. Ambil metrik historis
    final metrics = await getHistoricalMetrics(months: 3);

    // 3. Ambil komitmen tabungan rencana pembelian aktif
    final plans = await (_db.select(_db.purchasePlans)
          ..where((p) => p.status.equals(PlanStatus.active.index)))
        .get();

    final now = DateTime.now();
    var monthlyCommittedSavings = 0;
    for (final p in plans) {
      monthlyCommittedSavings += PurchasePlanRules.monthlyRequired(
        targetAmount: p.targetAmount,
        currentSaving: p.allocatedAmount,
        targetDate: p.targetDate,
        today: now,
      );
    }

    // 4. Validasi kecukupan data
    final hasSufficientData = ForecastRules.isDataSufficient(
      historicalTransactionCount: metrics.transactionCount,
      distinctMonthsWithTransactions: metrics.distinctMonths,
    );

    String? warning;
    if (!hasSufficientData) {
      warning =
          'Data transaksi 3 bulan terakhir belum cukup untuk proyeksi presisi. '
          'Angka proyeksi di bawah merupakan estimasi kasar.';
    }

    // 5. Proyeksikan 3 skenario
    final scenarios = ForecastRules.projectAllScenarios(
      currentBalance: currentBalance,
      avgMonthlyIncome: metrics.avgIncome,
      avgMonthlyExpense: metrics.avgExpense,
      monthlyPurchaseSavings: monthlyCommittedSavings,
      months: projectionMonths,
      startDate: now,
    );

    return ForecastReport(
      currentBalance: currentBalance,
      avgMonthlyIncome: metrics.avgIncome,
      avgMonthlyExpense: metrics.avgExpense,
      monthlyPurchaseSavings: monthlyCommittedSavings,
      months: projectionMonths,
      hasSufficientData: hasSufficientData,
      warningMessage: warning,
      scenarios: scenarios,
    );
  }
}

final forecastServiceProvider = Provider<ForecastService>((ref) {
  final db = ref.watch(databaseProvider);
  return ForecastService(db);
});
