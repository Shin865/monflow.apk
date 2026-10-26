import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:money_flow/core/formatting/thousand_separator_formatter.dart';
import 'package:money_flow/core/providers/balance_visibility_provider.dart';

void main() {
  group('ThousandSeparatorInputFormatter & Nominal Formatting Tests', () {
    final formatter = ThousandSeparatorInputFormatter();

    test('Mengosongkan input menghasilkan string kosong tanpa angka 0 otomatis',
        () {
      const oldValue = TextEditingValue(text: '1000');
      const newValue = TextEditingValue(text: '');
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '');
    });

    test(
        'Input 1 karakter angka menghasilkan digit tunggal tanpa format ribuan',
        () {
      const oldValue = TextEditingValue(text: '');
      const newValue = TextEditingValue(
          text: '1', selection: TextSelection.collapsed(offset: 1));
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '1');
    });

    test('Input 1000 diformat otomatis menjadi 1.000', () {
      const oldValue = TextEditingValue(text: '100');
      const newValue = TextEditingValue(
          text: '1000', selection: TextSelection.collapsed(offset: 4));
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '1.000');
    });

    test('Input 1000000 diformat otomatis menjadi 1.000.000', () {
      const oldValue = TextEditingValue(text: '100000');
      const newValue = TextEditingValue(
          text: '1000000', selection: TextSelection.collapsed(offset: 7));
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '1.000.000');
    });

    test('parseFormattedAmount mengekstrak integer dengan benar', () {
      expect(parseFormattedAmount(''), isNull);
      expect(parseFormattedAmount('   '), isNull);
      expect(parseFormattedAmount('1'), 1);
      expect(parseFormattedAmount('1.000'), 1000);
      expect(parseFormattedAmount('1.500.000'), 1500000);
      expect(parseFormattedAmount('25.000.000'), 25000000);
    });
  });

  group('BalanceVisibilityNotifier Privacy Balance Tests', () {
    test('formatOrMask menampilkan nominal asli jika isHidden false', () {
      final formatted =
          BalanceVisibilityNotifier.formatOrMask(1500000, isHidden: false);
      expect(formatted, contains('1.500.000'));
    });

    test(
        'formatOrMask menyamarkan nominal dengan placeholder jika isHidden true',
        () {
      final formatted =
          BalanceVisibilityNotifier.formatOrMask(1500000, isHidden: true);
      expect(formatted, 'Rp ••••••');
      expect(formatted.contains('1.500.000'), isFalse);
    });

    test('formatOrMask menyamarkan saldo negatif atau nol', () {
      expect(BalanceVisibilityNotifier.formatOrMask(0, isHidden: true),
          'Rp ••••••');
      expect(BalanceVisibilityNotifier.formatOrMask(-50000, isHidden: true),
          'Rp ••••••');
    });
  });
}
