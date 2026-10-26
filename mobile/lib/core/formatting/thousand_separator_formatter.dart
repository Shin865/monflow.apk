import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// TextInputFormatter yang otomatis memformat angka dengan pemisah ribuan Indonesia
/// saat pengguna mengetik nominal di field input.
///
/// Contoh: user ketik "1500000" → ditampilkan sebagai "1.500.000"
///
/// Cara pakai:
/// ```dart
/// TextField(
///   inputFormatters: [
///     FilteringTextInputFormatter.digitsOnly,
///     ThousandSeparatorInputFormatter(),
///   ],
/// )
/// ```
class ThousandSeparatorInputFormatter extends TextInputFormatter {
  static final _formatter = NumberFormat('#,###', 'id_ID');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Hapus semua titik (pemisah ribuan) dari teks baru
    final digitsOnly = newValue.text.replaceAll('.', '').replaceAll(',', '');

    if (digitsOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final number = int.tryParse(digitsOnly);
    if (number == null) {
      return oldValue;
    }

    final formatted = _formatter.format(number);

    // Hitung posisi kursor yang benar setelah formatting
    // Perbedaan panjang teks terformat vs digit mentah = jumlah titik pemisah
    final cursorOffset = formatted.length - digitsOnly.length;
    final oldCursorPos = newValue.selection.baseOffset;
    final newCursorPos = oldCursorPos + cursorOffset;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: newCursorPos.clamp(0, formatted.length),
      ),
    );
  }
}

/// Helper: mengekstrak nilai integer dari teks terformat (dengan pemisah ribuan).
/// Contoh: "1.500.000" → 1500000
int? parseFormattedAmount(String text) {
  final cleanedText = text.replaceAll('.', '').replaceAll(',', '').trim();
  if (cleanedText.isEmpty) return null;
  return int.tryParse(cleanedText);
}
