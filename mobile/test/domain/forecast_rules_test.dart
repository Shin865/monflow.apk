import 'package:flutter_test/flutter_test.dart';
import 'package:money_flow/domain/rules/forecast_rules.dart';
import 'package:money_flow/domain/rules/purchase_plan_rules.dart';

void main() {
  group('ForecastRules — Skenario', () {
    test('Skenario multipliers sesuai Python', () {
      // Python: conservative: income 0.9, expense 1.1
      expect(ForecastRules.scenarios['conservative']!.incomeMultiplier, 0.9);
      expect(ForecastRules.scenarios['conservative']!.expenseMultiplier, 1.1);

      expect(ForecastRules.scenarios['normal']!.incomeMultiplier, 1.0);
      expect(ForecastRules.scenarios['normal']!.expenseMultiplier, 1.0);

      expect(ForecastRules.scenarios['optimistic']!.incomeMultiplier, 1.1);
      expect(ForecastRules.scenarios['optimistic']!.expenseMultiplier, 0.9);
    });

    test('Normal scenario: net = income - expense - purchase', () {
      /// Python expected:
      /// normal: income=8,000,000  expense=5,000,000  net=2,500,000
      final projections = ForecastRules.project(
        currentBalance: 20000000,
        avgMonthlyIncome: 8000000,
        avgMonthlyExpense: 5000000,
        monthlyPurchaseSavings: 500000,
        incomeMultiplier: 1.0,
        expenseMultiplier: 1.0,
        months: 1,
        startDate: DateTime(2026, 10, 1),
      );

      expect(projections.length, 1);
      expect(projections[0].income, equals(8000000));
      expect(projections[0].expense, equals(5000000));
      expect(projections[0].netFlow, equals(2500000));
      expect(projections[0].projectedBalance, equals(22500000));
    });

    test('Conservative scenario: income × 0.9, expense × 1.1', () {
      /// Python expected:
      /// conservative: income=7,200,000  expense=5,500,000  net=1,200,000
      final projections = ForecastRules.project(
        currentBalance: 20000000,
        avgMonthlyIncome: 8000000,
        avgMonthlyExpense: 5000000,
        monthlyPurchaseSavings: 500000,
        incomeMultiplier: 0.9,
        expenseMultiplier: 1.1,
        months: 1,
        startDate: DateTime(2026, 10, 1),
      );

      expect(projections[0].income, equals(7200000));
      expect(projections[0].expense, equals(5500000));
      expect(projections[0].netFlow, equals(1200000));
      expect(projections[0].projectedBalance, equals(21200000));
    });

    test('Optimistic scenario: income × 1.1, expense × 0.9', () {
      /// Python expected:
      /// optimistic: income=8,800,000  expense=4,500,000  net=3,800,000
      final projections = ForecastRules.project(
        currentBalance: 20000000,
        avgMonthlyIncome: 8000000,
        avgMonthlyExpense: 5000000,
        monthlyPurchaseSavings: 500000,
        incomeMultiplier: 1.1,
        expenseMultiplier: 0.9,
        months: 1,
        startDate: DateTime(2026, 10, 1),
      );

      expect(projections[0].income, equals(8800000));
      expect(projections[0].expense, equals(4500000));
      expect(projections[0].netFlow, equals(3800000));
      expect(projections[0].projectedBalance, equals(23800000));
    });

    test('Projected balance tidak boleh negatif', () {
      final projections = ForecastRules.project(
        currentBalance: 100000,
        avgMonthlyIncome: 1000000,
        avgMonthlyExpense: 5000000,
        monthlyPurchaseSavings: 0,
        incomeMultiplier: 1.0,
        expenseMultiplier: 1.0,
        months: 1,
        startDate: DateTime(2026, 10, 1),
      );

      // Net = 1M - 5M = -4M, balance = 100K - 4M = -3.9M → capped at 0
      expect(projections[0].projectedBalance, equals(0));
    });

    test('projectAllScenarios menghasilkan 3 skenario', () {
      final result = ForecastRules.projectAllScenarios(
        currentBalance: 20000000,
        avgMonthlyIncome: 8000000,
        avgMonthlyExpense: 5000000,
        monthlyPurchaseSavings: 500000,
        months: 6,
      );

      expect(
          result.keys, containsAll(['conservative', 'normal', 'optimistic']));
      expect(result['conservative']!.length, 6);
      expect(result['normal']!.length, 6);
      expect(result['optimistic']!.length, 6);
    });
  });

  group('ForecastRules — Historical Averages', () {
    test('Rata-rata 3 bulan', () {
      final avgs = ForecastRules.historicalAverages(
        totalIncome: 24000000,
        totalExpense: 15000000,
        months: 3,
      );
      expect(avgs.avgIncome, equals(8000000));
      expect(avgs.avgExpense, equals(5000000));
    });

    test('0 bulan menghasilkan 0', () {
      final avgs = ForecastRules.historicalAverages(
        totalIncome: 1000000,
        totalExpense: 500000,
        months: 0,
      );
      expect(avgs.avgIncome, equals(0));
      expect(avgs.avgExpense, equals(0));
    });
  });

  group('PurchasePlanRules', () {
    test('Remaining = max(0, target - current)', () {
      expect(
        PurchasePlanRules.remaining(
            targetAmount: 15000000, currentSaving: 6000000),
        equals(9000000),
      );
      expect(
        PurchasePlanRules.remaining(
            targetAmount: 15000000, currentSaving: 20000000),
        equals(0), // Sudah tercapai
      );
    });

    test('Progress 40% — sesuai Python', () {
      /// Python expected: 40.0%
      final pct = PurchasePlanRules.progress(
        targetAmount: 15000000,
        currentSaving: 6000000,
      );
      expect(pct, closeTo(40.0, 0.01));
    });

    test('Progress di-cap 100%', () {
      final pct = PurchasePlanRules.progress(
        targetAmount: 10000000,
        currentSaving: 15000000,
      );
      expect(pct, equals(100.0));
    });

    test('Progress 0% jika target <= 0', () {
      final pct = PurchasePlanRules.progress(
        targetAmount: 0,
        currentSaving: 5000000,
      );
      expect(pct, equals(0.0));
    });

    test('Monthly required dihitung benar', () {
      final monthly = PurchasePlanRules.monthlyRequired(
        targetAmount: 15000000,
        currentSaving: 6000000,
        targetDate: DateTime(2027, 4, 1),
        today: DateTime(2026, 10, 1),
      );
      // 6 bulan tersisa, 9jt remaining → 1.5jt/bulan
      expect(monthly, equals(1500000));
    });

    test('Monthly required = remaining jika deadline sudah lewat', () {
      final monthly = PurchasePlanRules.monthlyRequired(
        targetAmount: 15000000,
        currentSaving: 6000000,
        targetDate: DateTime(2026, 9, 1), // Sudah lewat
        today: DateTime(2026, 10, 1),
      );
      expect(monthly, equals(9000000)); // Harus bayar semua sekarang
    });

    test('Monthly required = 0 jika sudah tercapai', () {
      final monthly = PurchasePlanRules.monthlyRequired(
        targetAmount: 15000000,
        currentSaving: 15000000,
        targetDate: DateTime(2027, 4, 1),
      );
      expect(monthly, equals(0));
    });
  });
}
