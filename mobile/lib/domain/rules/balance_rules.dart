import 'package:money_flow/core/database/database.dart';

/// Aturan saldo akun — porting dari backend Python.
///
/// Sumber: backend/app/routes/transactions.py → _apply_balance_change()
///
/// INCOME:     balance += amount
/// EXPENSE:    balance -= amount
/// REFUND:     balance += amount (mengembalikan uang)
/// ADJUSTMENT: balance += amount (bisa +/-)
class BalanceRules {
  const BalanceRules._();

  /// Hitung perubahan saldo berdasarkan tipe transaksi.
  /// Mengembalikan delta yang harus ditambahkan ke saldo akun.
  ///
  /// [amount] harus positif (validasi di UI/repository).
  /// [reverse] = true untuk membatalkan efek transaksi (delete/update).
  static int calculateDelta({
    required TransactionType type,
    required int amount,
    bool reverse = false,
  }) {
    assert(amount >= 0, 'Amount must be non-negative');

    int delta;
    switch (type) {
      case TransactionType.income:
        delta = amount;
        break;
      case TransactionType.expense:
        delta = -amount;
        break;
      case TransactionType.refund:
        delta = amount;
        break;
      case TransactionType.adjustment:
        delta = amount;
        break;
    }

    return reverse ? -delta : delta;
  }

  /// Hitung saldo baru setelah transaksi.
  static int applyTransaction({
    required int currentBalance,
    required TransactionType type,
    required int amount,
    bool reverse = false,
  }) {
    return currentBalance +
        calculateDelta(
          type: type,
          amount: amount,
          reverse: reverse,
        );
  }

  /// Hitung saldo setelah transfer (sisi pengirim).
  /// Transfer mengurangi saldo pengirim.
  static int applyTransferFrom({
    required int currentBalance,
    required int amount,
    bool reverse = false,
  }) {
    return reverse ? currentBalance + amount : currentBalance - amount;
  }

  /// Hitung saldo setelah transfer (sisi penerima).
  /// Transfer menambah saldo penerima.
  static int applyTransferTo({
    required int currentBalance,
    required int amount,
    bool reverse = false,
  }) {
    return reverse ? currentBalance - amount : currentBalance + amount;
  }

  /// Verifikasi bahwa transfer tidak mengubah total aset gabungan.
  /// Mengembalikan true jika total sebelum == total sesudah.
  static bool verifyTransferNeutral({
    required int fromBefore,
    required int toBefore,
    required int fromAfter,
    required int toAfter,
  }) {
    return (fromBefore + toBefore) == (fromAfter + toAfter);
  }
}
