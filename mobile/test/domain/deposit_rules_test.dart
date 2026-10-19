import 'package:flutter_test/flutter_test.dart';
import 'package:money_flow/domain/rules/deposit_rules.dart';

/// Unit test bunga deposito — memastikan kesetaraan dengan Python.
///
/// Expected values diambil dari docs/test_data_spec.py (ALL PASS).
void main() {
  group('DepositRules — Simple Interest', () {
    test('100jt, 4%, 12 bulan → gross 4jt', () {
      final gross = DepositRules.grossInterest(
        principal: 100000000,
        annualRatePercent: 4.0,
        tenorMonths: 12,
        isCompound: false,
      );
      expect(gross, closeTo(4000000.0, 0.01));
    });

    test('100jt, 4%, 12 bulan → tax 20% = 800rb', () {
      const gross = 4000000.0;
      final tax = DepositRules.taxAmount(
        grossInterestAmount: gross,
        taxRatePercent: 20.0,
      );
      expect(tax, closeTo(800000.0, 0.01));
    });

    test('100jt, 4%, 12 bulan → net 3.2jt', () {
      const gross = 4000000.0;
      final net = DepositRules.netInterest(
        grossInterestAmount: gross,
        taxRatePercent: 20.0,
      );
      expect(net, closeTo(3200000.0, 0.01));
    });

    test('100jt, 4%, 12 bulan → maturity 103.2jt', () {
      final maturity = DepositRules.maturityAmount(
        principal: 100000000,
        annualRatePercent: 4.0,
        tenorMonths: 12,
        isCompound: false,
        taxRatePercent: 20.0,
      );
      // Python expected: 103,200,000
      expect(maturity, closeTo(103200000.0, 0.01));
    });

    test('50jt, 5%, 6 bulan → gross 1.25jt', () {
      final gross = DepositRules.grossInterest(
        principal: 50000000,
        annualRatePercent: 5.0,
        tenorMonths: 6,
      );
      // 50M × 0.05 × 0.5 = 1,250,000
      expect(gross, closeTo(1250000.0, 0.01));
    });
  });

  group('DepositRules — Compound Interest', () {
    test('100jt, 4%, 12 bulan, bulanan → gross 4,074,154.29', () {
      final gross = DepositRules.grossInterest(
        principal: 100000000,
        annualRatePercent: 4.0,
        tenorMonths: 12,
        isCompound: true,
        compoundFrequency: 12,
      );
      // Python expected: 4,074,154.29
      expect(gross, closeTo(4074154.29, 1.0));
    });

    test('100jt, 4%, 12 bulan, bulanan → net 3,259,323.43', () {
      final gross = DepositRules.grossInterest(
        principal: 100000000,
        annualRatePercent: 4.0,
        tenorMonths: 12,
        isCompound: true,
        compoundFrequency: 12,
      );
      final net = DepositRules.netInterest(
        grossInterestAmount: gross,
        taxRatePercent: 20.0,
      );
      // Python expected: 3,259,323.43
      expect(net, closeTo(3259323.43, 1.0));
    });

    test('100jt, 4%, 12 bulan, bulanan → maturity 103,259,323.43', () {
      final maturity = DepositRules.maturityAmount(
        principal: 100000000,
        annualRatePercent: 4.0,
        tenorMonths: 12,
        isCompound: true,
        compoundFrequency: 12,
        taxRatePercent: 20.0,
      );
      // Python expected: 103,259,323.43
      expect(maturity, closeTo(103259323.43, 1.0));
    });

    test('Compound > Simple untuk rate dan tenor yang sama', () {
      const principal = 100000000;
      const rate = 4.0;
      const tenor = 12;

      final simple = DepositRules.grossInterest(
        principal: principal,
        annualRatePercent: rate,
        tenorMonths: tenor,
        isCompound: false,
      );
      final compound = DepositRules.grossInterest(
        principal: principal,
        annualRatePercent: rate,
        tenorMonths: tenor,
        isCompound: true,
        compoundFrequency: 12,
      );

      expect(compound, greaterThan(simple));
    });
  });

  group('DepositRules — Pembulatan', () {
    test('roundToRupiah membulatkan ke integer terdekat', () {
      expect(DepositRules.roundToRupiah(3259323.43), equals(3259323));
      expect(DepositRules.roundToRupiah(3259323.6), equals(3259324));
      expect(DepositRules.roundToRupiah(0.0), equals(0));
    });
  });
}
