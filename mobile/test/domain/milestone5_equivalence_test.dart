import 'package:flutter_test/flutter_test.dart';
import 'package:money_flow/domain/rules/deposit_rules.dart';
import 'package:money_flow/domain/rules/investment_rules.dart';

/// Milestone 5 — Synthetic Parity & Financial Equivalence Unit Tests
/// Directly mirroring `docs/milestone_5_test_spec.py` to ensure Dart matches Python exactly.
void main() {
  group('Milestone 5 — Synthetic Parity Tests (Matching Python Spec)', () {
    test('Test 1: Simple Interest (625 bps, 12 mo, 2000 bps tax)', () {
      final res = DepositRules.calculateDeposit(
        principal: 100000000,
        rateBps: 625,
        tenorMonths: 12,
        isCompound: false,
        taxRateBps: 2000,
      );

      expect(res.grossInterest, equals(6250000));
      expect(res.taxAmount, equals(1250000));
      expect(res.netInterest, equals(5000000));
      expect(res.maturityAmount, equals(105000000));
    });

    test('Test 2: Simple Interest with Fee (500 bps, 6 mo, fee 25,000)', () {
      final res = DepositRules.calculateDeposit(
        principal: 50000000,
        rateBps: 500,
        tenorMonths: 6,
        isCompound: false,
        taxRateBps: 2000,
        feeAmount: 25000,
      );

      expect(res.grossInterest, equals(1250000));
      expect(res.taxAmount, equals(250000));
      expect(res.netInterest, equals(975000));
      expect(res.maturityAmount, equals(50975000));
    });

    test('Test 3: Compound Interest (400 bps, 12 mo, monthly n=12)', () {
      final res = DepositRules.calculateDeposit(
        principal: 100000000,
        rateBps: 400,
        tenorMonths: 12,
        isCompound: true,
        compoundFrequency: 12,
        taxRateBps: 2000,
      );

      expect(res.grossInterest, equals(4074154));
      expect(res.taxAmount, equals(814831));
      expect(res.netInterest, equals(3259323));
      expect(res.maturityAmount, equals(103259323));
    });

    test('Test 4: Compound Interest Quarterly (600 bps, 24 mo, quarterly n=4)',
        () {
      final res = DepositRules.calculateDeposit(
        principal: 60000000,
        rateBps: 600,
        tenorMonths: 24,
        isCompound: true,
        compoundFrequency: 4,
        taxRateBps: 2000,
      );

      expect(res.grossInterest, equals(7589555));
      expect(res.taxAmount, equals(1517911));
      expect(res.netInterest, equals(6071644));
      expect(res.maturityAmount, equals(66071644));
    });

    test('Test 5: Leap Year & Maturity Date Transitions', () {
      // Leap year: 2024-02-29 + 12 months -> 2025-02-28
      final dLeap = DateTime(2024, 2, 29);
      final mLeap = DepositRules.calculateMaturityDate(dLeap, 12);
      expect(mLeap.year, equals(2025));
      expect(mLeap.month, equals(2));
      expect(mLeap.day, equals(28));

      // Month rollover: 2026-10-31 + 3 months -> 2027-01-31
      final dRoll = DateTime(2026, 10, 31);
      final mRoll = DepositRules.calculateMaturityDate(dRoll, 3);
      expect(mRoll.year, equals(2027));
      expect(mRoll.month, equals(1));
      expect(mRoll.day, equals(31));
    });

    test('Test 6: Half-Up Rounding Verification', () {
      expect(DepositRules.roundHalfUp(100.4), equals(100));
      expect(DepositRules.roundHalfUp(100.5), equals(101));
      expect(DepositRules.roundHalfUp(100.6), equals(101));
      expect(DepositRules.roundHalfUp(-100.4), equals(-100));
      expect(DepositRules.roundHalfUp(-100.5), equals(-101));
      expect(DepositRules.roundHalfUp(-100.6), equals(-101));
    });

    test('Test 7: Investment Portfolio & Realized Gain on Sell', () {
      final gain = InvestmentRules.unrealizedGain(
        initialCost: 10000000,
        currentValue: 12500000,
      );
      final returnPct = InvestmentRules.returnPercent(
        initialCost: 10000000,
        currentValue: 12500000,
      );
      expect(gain, equals(2500000));
      expect(returnPct, closeTo(25.0, 0.0001));

      // Sell half (5 units out of 10) at price 1,500,000 per unit, fee 10,000
      final sell = InvestmentRules.calculateSale(
        totalCost: 10000000,
        totalUnits: 10.0,
        unitsSold: 5.0,
        sellPricePerUnit: 1500000,
        sellFee: 10000,
      );

      expect(sell.grossProceeds, equals(7500000));
      expect(sell.netProceeds, equals(7490000));
      expect(sell.costBasisSold, equals(5000000));
      expect(sell.realizedGain, equals(2490000));
      expect(sell.remainingCost, equals(5000000));
      expect(sell.remainingUnits, equals(5.0));
    });

    test('Test 10: Safe Arithmetic Boundary (100 Billion Rupiah)', () {
      const largeP = 100000000000; // 100 Billion Rupiah
      final res = DepositRules.calculateDeposit(
        principal: largeP,
        rateBps: 750,
        tenorMonths: 12,
        isCompound: false,
        taxRateBps: 2000,
      );

      expect(res.grossInterest, equals(7500000000)); // 7.5 Billion
      expect(res.taxAmount, equals(1500000000)); // 1.5 Billion
      expect(res.netInterest, equals(6000000000)); // 6.0 Billion
      expect(res.maturityAmount, equals(106000000000)); // 106 Billion
    });
  });
}
