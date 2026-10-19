import 'package:intl/intl.dart';

/// Format angka sebagai Rupiah.
/// Contoh: formatRupiah(1500000) → "Rp 1.500.000"
String formatRupiah(int amount) {
  final formatter = NumberFormat('#,###', 'id_ID');
  final prefix = amount < 0 ? '-Rp ' : 'Rp ';
  return '$prefix${formatter.format(amount.abs())}';
}

/// Format angka sebagai Rupiah singkat.
/// Contoh: formatRupiahCompact(1500000) → "Rp 1,5 jt"
String formatRupiahCompact(int amount) {
  final abs = amount.abs();
  final prefix = amount < 0 ? '-Rp ' : 'Rp ';

  if (abs >= 1000000000000) {
    return '$prefix${(abs / 1000000000000).toStringAsFixed(1)} T';
  } else if (abs >= 1000000000) {
    return '$prefix${(abs / 1000000000).toStringAsFixed(1)} M';
  } else if (abs >= 1000000) {
    return '$prefix${(abs / 1000000).toStringAsFixed(1)} jt';
  } else if (abs >= 1000) {
    return '$prefix${(abs / 1000).toStringAsFixed(0)} rb';
  }
  return '$prefix$abs';
}

/// Format tanggal dalam Bahasa Indonesia.
/// Contoh: formatDate(DateTime(2026, 10, 12)) → "12 Okt 2026"
String formatDate(DateTime date) {
  try {
    return DateFormat('dd MMM yyyy', 'id_ID').format(date);
  } catch (_) {
    return DateFormat('dd MMM yyyy').format(date);
  }
}

/// Format tanggal lengkap.
/// Contoh: formatDateFull(DateTime(2026, 10, 12)) → "Senin, 12 Oktober 2026"
String formatDateFull(DateTime date) {
  try {
    return DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(date);
  } catch (_) {
    return DateFormat('yyyy-MM-dd').format(date);
  }
}

/// Format tanggal ISO untuk penyimpanan.
String formatDateIso(DateTime date) {
  return DateFormat('yyyy-MM-dd').format(date);
}

/// Parse tanggal ISO string.
DateTime parseDateIso(String dateStr) {
  return DateFormat('yyyy-MM-dd').parse(dateStr);
}

/// Format bulan dan tahun.
/// Contoh: formatMonthYear(DateTime(2026, 10, 12)) → "Oktober 2026"
String formatMonthYear(DateTime date) {
  try {
    return DateFormat('MMMM yyyy', 'id_ID').format(date);
  } catch (_) {
    return DateFormat('yyyy-MM').format(date);
  }
}

/// Format angka dengan pemisah ribuan Indonesia.
String formatNumber(int number) {
  return NumberFormat('#,###', 'id_ID').format(number);
}
