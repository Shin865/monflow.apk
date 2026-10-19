/// Aturan perhitungan forecast/proyeksi — porting dari backend Python.
///
/// Sumber: backend/app/routes/forecast.py
class ForecastRules {
  const ForecastRules._();

  /// Pengali skenario sesuai backend Python.
  static const scenarios = {
    'conservative': (incomeMultiplier: 0.9, expenseMultiplier: 1.1),
    'normal': (incomeMultiplier: 1.0, expenseMultiplier: 1.0),
    'optimistic': (incomeMultiplier: 1.1, expenseMultiplier: 0.9),
  };

  /// Hitung rata-rata income/expense dari data historis.
  ///
  /// [totalIncome] total income dalam periode
  /// [totalExpense] total expense dalam periode
  /// [months] jumlah bulan dalam periode
  static ({int avgIncome, int avgExpense}) historicalAverages({
    required int totalIncome,
    required int totalExpense,
    required int months,
  }) {
    if (months <= 0) return (avgIncome: 0, avgExpense: 0);
    return (
      avgIncome: (totalIncome / months).round(),
      avgExpense: (totalExpense / months).round(),
    );
  }

  /// Proyeksikan saldo untuk N bulan ke depan berdasarkan skenario.
  ///
  /// Sesuai Python:
  /// net_flow = s_income - s_expense - monthly_purchase
  /// running_balance += net_flow
  /// projected_balance = max(0, round(running_balance, 0))
  static List<MonthProjection> project({
    required int currentBalance,
    required int avgMonthlyIncome,
    required int avgMonthlyExpense,
    required int monthlyPurchaseSavings,
    required double incomeMultiplier,
    required double expenseMultiplier,
    required int months,
    required DateTime startDate,
  }) {
    final sIncome = (avgMonthlyIncome * incomeMultiplier).round();
    final sExpense = (avgMonthlyExpense * expenseMultiplier).round();
    final projections = <MonthProjection>[];
    var runningBalance = currentBalance;

    for (var i = 0; i < months; i++) {
      final projDate = DateTime(
        startDate.year,
        startDate.month + i,
        startDate.day,
      );
      final netFlow = sIncome - sExpense - monthlyPurchaseSavings;
      runningBalance += netFlow;

      projections.add(MonthProjection(
        date: projDate,
        income: sIncome,
        expense: sExpense,
        purchaseSavings: monthlyPurchaseSavings,
        netFlow: netFlow,
        projectedBalance: runningBalance > 0 ? runningBalance : 0,
      ));
    }

    return projections;
  }

  /// Proyeksikan semua 3 skenario sekaligus.
  static Map<String, List<MonthProjection>> projectAllScenarios({
    required int currentBalance,
    required int avgMonthlyIncome,
    required int avgMonthlyExpense,
    required int monthlyPurchaseSavings,
    required int months,
    DateTime? startDate,
  }) {
    final start = startDate ?? DateTime.now();
    final result = <String, List<MonthProjection>>{};

    for (final entry in scenarios.entries) {
      result[entry.key] = project(
        currentBalance: currentBalance,
        avgMonthlyIncome: avgMonthlyIncome,
        avgMonthlyExpense: avgMonthlyExpense,
        monthlyPurchaseSavings: monthlyPurchaseSavings,
        incomeMultiplier: entry.value.incomeMultiplier,
        expenseMultiplier: entry.value.expenseMultiplier,
        months: months,
        startDate: start,
      );
    }

    return result;
  }

  /// Cek apakah data historis mencukupi untuk membuat proyeksi yang bermakna.
  /// Memenuhi kriteria: "Jika data tidak cukup, tampilkan peringatan atau hasil terbatas, bukan angka presisi yang menyesatkan."
  static bool isDataSufficient({
    required int historicalTransactionCount,
    required int distinctMonthsWithTransactions,
  }) {
    return historicalTransactionCount >= 3 &&
        distinctMonthsWithTransactions >= 1;
  }
}

/// Hasil proyeksi satu bulan.
class MonthProjection {
  final DateTime date;
  final int income;
  final int expense;
  final int purchaseSavings;
  final int netFlow;
  final int projectedBalance;

  const MonthProjection({
    required this.date,
    required this.income,
    required this.expense,
    required this.purchaseSavings,
    required this.netFlow,
    required this.projectedBalance,
  });
}

/// Laporan perkiraan proyeksi lengkap dengan asumsi eksplisit.
class ForecastReport {
  final int currentBalance;
  final int avgMonthlyIncome;
  final int avgMonthlyExpense;
  final int monthlyPurchaseSavings;
  final int months;
  final bool hasSufficientData;
  final String? warningMessage;
  final Map<String, List<MonthProjection>> scenarios;

  const ForecastReport({
    required this.currentBalance,
    required this.avgMonthlyIncome,
    required this.avgMonthlyExpense,
    required this.monthlyPurchaseSavings,
    required this.months,
    required this.hasSufficientData,
    this.warningMessage,
    required this.scenarios,
  });
}
