import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:money_flow/core/formatting/formatters.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });
  group('formatRupiah', () {
    test('Format angka positif', () {
      expect(formatRupiah(1500000), equals('Rp 1.500.000'));
    });

    test('Format nol', () {
      expect(formatRupiah(0), equals('Rp 0'));
    });

    test('Format angka negatif', () {
      expect(formatRupiah(-500000), equals('-Rp 500.000'));
    });

    test('Format angka besar', () {
      expect(formatRupiah(100000000), equals('Rp 100.000.000'));
    });

    test('Format angka kecil', () {
      expect(formatRupiah(500), equals('Rp 500'));
    });
  });

  group('formatRupiahCompact', () {
    test('Format jutaan', () {
      expect(formatRupiahCompact(1500000), equals('Rp 1.5 jt'));
    });

    test('Format miliaran', () {
      expect(formatRupiahCompact(2500000000), equals('Rp 2.5 M'));
    });

    test('Format ribuan', () {
      expect(formatRupiahCompact(50000), equals('Rp 50 rb'));
    });

    test('Format di bawah seribu', () {
      expect(formatRupiahCompact(500), equals('Rp 500'));
    });
  });

  group('formatDate', () {
    test('Format tanggal Indonesia', () {
      final date = DateTime(2026, 10, 12);
      final result = formatDate(date);
      // Harus mengandung tanggal 12, bulan Oktober (Okt), dan tahun 2026
      expect(result, contains('12'));
      expect(result, contains('2026'));
    });
  });

  group('formatDateIso & parseDateIso', () {
    test('Round-trip ISO date', () {
      final original = DateTime(2026, 10, 12);
      final iso = formatDateIso(original);
      expect(iso, equals('2026-10-12'));

      final parsed = parseDateIso(iso);
      expect(parsed.year, equals(2026));
      expect(parsed.month, equals(10));
      expect(parsed.day, equals(12));
    });
  });

  group('formatNumber', () {
    test('Format angka dengan pemisah ribuan', () {
      expect(formatNumber(1234567), equals('1.234.567'));
    });

    test('Format angka kecil tanpa pemisah', () {
      expect(formatNumber(999), equals('999'));
    });
  });
}
