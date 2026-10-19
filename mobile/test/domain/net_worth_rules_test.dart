import 'package:flutter_test/flutter_test.dart';
import 'package:money_flow/domain/rules/net_worth_rules.dart';

void main() {
  group('NetWorthRules — Net Worth', () {
    test('Net worth dasar: saldo saja', () {
      final nw = NetWorthRules.netWorth(totalBalance: 10000000);
      expect(nw, equals(10000000));
    });

    test('Net worth lengkap sesuai Python dashboard.py', () {
      /// Python:
      /// total_assets = total_balance + total_investment_value + total_deposit + total_piutang
      /// total_liabilities = total_hutang
      /// net_worth = total_assets - total_liabilities
      final nw = NetWorthRules.netWorth(
        totalBalance: 15000000,
        totalInvestmentValue: 5000000,
        totalDeposit: 100000000,
        totalPiutang: 2000000,
        totalHutang: 10000000,
      );
      // Assets = 15M + 5M + 100M + 2M = 122M
      // Liabilities = 10M
      // Net worth = 122M - 10M = 112M
      expect(nw, equals(112000000));
    });

    test('Net worth bisa negatif (hutang > aset)', () {
      final nw = NetWorthRules.netWorth(
        totalBalance: 1000000,
        totalHutang: 50000000,
      );
      expect(nw, equals(-49000000));
    });
  });

  group('NetWorthRules — Cash Flow', () {
    test('Cash flow = income + refund - expense', () {
      /// Python: net_flow = income + refund - expense
      final cf = NetWorthRules.monthlyCashFlow(
        income: 8500000,
        expense: 3200000,
        refund: 150000,
      );
      // 8,500,000 + 150,000 - 3,200,000 = 5,450,000
      expect(cf, equals(5450000));
    });

    test('Cash flow negatif (expense > income)', () {
      final cf = NetWorthRules.monthlyCashFlow(
        income: 3000000,
        expense: 5000000,
      );
      expect(cf, equals(-2000000));
    });
  });

  group('NetWorthRules — Investasi', () {
    test('Unrealized gain positif', () {
      final gain = NetWorthRules.unrealizedGain(
        totalInvestmentCost: 10000000,
        totalInvestmentValue: 12000000,
      );
      expect(gain, equals(2000000));
    });

    test('Unrealized loss negatif', () {
      final gain = NetWorthRules.unrealizedGain(
        totalInvestmentCost: 10000000,
        totalInvestmentValue: 8000000,
      );
      expect(gain, equals(-2000000));
    });

    test('Return persen 20%', () {
      final pct = NetWorthRules.investmentReturnPercent(
        totalInvestmentCost: 10000000,
        totalInvestmentValue: 12000000,
      );
      expect(pct, closeTo(20.0, 0.01));
    });

    test('Return persen 0% jika cost = 0', () {
      final pct = NetWorthRules.investmentReturnPercent(
        totalInvestmentCost: 0,
        totalInvestmentValue: 5000000,
      );
      expect(pct, equals(0.0));
    });
  });
}
