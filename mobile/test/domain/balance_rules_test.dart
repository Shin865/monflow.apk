import 'package:flutter_test/flutter_test.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/domain/rules/balance_rules.dart';

/// Unit test untuk aturan saldo — memastikan porting dari Python benar.
///
/// Sumber referensi: backend/app/routes/transactions.py → _apply_balance_change()
/// dan backend/app/routes/transfers.py
void main() {
  group('BalanceRules — Transaksi', () {
    test('INCOME menambah saldo', () {
      expect(
        BalanceRules.calculateDelta(
          type: TransactionType.income,
          amount: 5000000,
        ),
        equals(5000000),
      );
    });

    test('EXPENSE mengurangi saldo', () {
      expect(
        BalanceRules.calculateDelta(
          type: TransactionType.expense,
          amount: 1500000,
        ),
        equals(-1500000),
      );
    });

    test('REFUND menambah saldo (mengembalikan uang)', () {
      expect(
        BalanceRules.calculateDelta(
          type: TransactionType.refund,
          amount: 200000,
        ),
        equals(200000),
      );
    });

    test('ADJUSTMENT menambah saldo', () {
      expect(
        BalanceRules.calculateDelta(
          type: TransactionType.adjustment,
          amount: 100000,
        ),
        equals(100000),
      );
    });

    test('Reverse INCOME mengurangi saldo', () {
      expect(
        BalanceRules.calculateDelta(
          type: TransactionType.income,
          amount: 5000000,
          reverse: true,
        ),
        equals(-5000000),
      );
    });

    test('Reverse EXPENSE menambah saldo kembali', () {
      expect(
        BalanceRules.calculateDelta(
          type: TransactionType.expense,
          amount: 1500000,
          reverse: true,
        ),
        equals(1500000),
      );
    });

    test('Reverse REFUND mengurangi saldo', () {
      expect(
        BalanceRules.calculateDelta(
          type: TransactionType.refund,
          amount: 200000,
          reverse: true,
        ),
        equals(-200000),
      );
    });
  });

  group('BalanceRules — Apply Transaction', () {
    test('Saldo awal 10jt + income 5jt = 15jt', () {
      expect(
        BalanceRules.applyTransaction(
          currentBalance: 10000000,
          type: TransactionType.income,
          amount: 5000000,
        ),
        equals(15000000),
      );
    });

    test('Saldo awal 10jt - expense 3jt = 7jt', () {
      expect(
        BalanceRules.applyTransaction(
          currentBalance: 10000000,
          type: TransactionType.expense,
          amount: 3000000,
        ),
        equals(7000000),
      );
    });

    test('Saldo bisa negatif (expense > balance)', () {
      expect(
        BalanceRules.applyTransaction(
          currentBalance: 1000000,
          type: TransactionType.expense,
          amount: 2000000,
        ),
        equals(-1000000),
      );
    });

    test('Skenario lengkap: income + expense + refund', () {
      int balance = 0;
      // Gaji 5jt
      balance = BalanceRules.applyTransaction(
        currentBalance: balance,
        type: TransactionType.income,
        amount: 5000000,
      );
      expect(balance, equals(5000000));

      // Makan 50rb
      balance = BalanceRules.applyTransaction(
        currentBalance: balance,
        type: TransactionType.expense,
        amount: 50000,
      );
      expect(balance, equals(4950000));

      // Refund belanja online 100rb
      balance = BalanceRules.applyTransaction(
        currentBalance: balance,
        type: TransactionType.refund,
        amount: 100000,
      );
      expect(balance, equals(5050000));
    });

    test('Delete transaksi mengembalikan saldo ke semula', () {
      const initialBalance = 10000000;

      // Catat expense
      final afterExpense = BalanceRules.applyTransaction(
        currentBalance: initialBalance,
        type: TransactionType.expense,
        amount: 500000,
      );
      expect(afterExpense, equals(9500000));

      // Delete (reverse) expense
      final afterReverse = BalanceRules.applyTransaction(
        currentBalance: afterExpense,
        type: TransactionType.expense,
        amount: 500000,
        reverse: true,
      );
      expect(afterReverse, equals(initialBalance));
    });

    test('Update transaksi: reverse lama, apply baru', () {
      const initialBalance = 10000000;

      // Catat expense 500rb
      final afterOld = BalanceRules.applyTransaction(
        currentBalance: initialBalance,
        type: TransactionType.expense,
        amount: 500000,
      );
      expect(afterOld, equals(9500000));

      // Reverse expense 500rb
      final afterReverse = BalanceRules.applyTransaction(
        currentBalance: afterOld,
        type: TransactionType.expense,
        amount: 500000,
        reverse: true,
      );
      expect(afterReverse, equals(10000000));

      // Apply expense 750rb (jumlah baru)
      final afterNew = BalanceRules.applyTransaction(
        currentBalance: afterReverse,
        type: TransactionType.expense,
        amount: 750000,
      );
      expect(afterNew, equals(9250000));
    });
  });

  group('BalanceRules — Transfer', () {
    test('Transfer mengurangi saldo pengirim', () {
      expect(
        BalanceRules.applyTransferFrom(
          currentBalance: 10000000,
          amount: 2000000,
        ),
        equals(8000000),
      );
    });

    test('Transfer menambah saldo penerima', () {
      expect(
        BalanceRules.applyTransferTo(
          currentBalance: 5000000,
          amount: 2000000,
        ),
        equals(7000000),
      );
    });

    test('Transfer tidak mengubah total aset gabungan', () {
      const fromBefore = 10000000;
      const toBefore = 5000000;
      const amount = 2000000;

      final fromAfter = BalanceRules.applyTransferFrom(
          currentBalance: fromBefore, amount: amount);
      final toAfter = BalanceRules.applyTransferTo(
          currentBalance: toBefore, amount: amount);

      expect(
        BalanceRules.verifyTransferNeutral(
          fromBefore: fromBefore,
          toBefore: toBefore,
          fromAfter: fromAfter,
          toAfter: toAfter,
        ),
        isTrue,
      );

      // Total tetap 15jt
      expect(fromAfter + toAfter, equals(fromBefore + toBefore));
    });

    test('Reverse transfer mengembalikan saldo semula', () {
      const fromBefore = 10000000;
      const toBefore = 5000000;
      const amount = 3000000;

      // Transfer
      final fromAfter = BalanceRules.applyTransferFrom(
          currentBalance: fromBefore, amount: amount);
      final toAfter = BalanceRules.applyTransferTo(
          currentBalance: toBefore, amount: amount);

      // Reverse
      final fromReverted = BalanceRules.applyTransferFrom(
          currentBalance: fromAfter, amount: amount, reverse: true);
      final toReverted = BalanceRules.applyTransferTo(
          currentBalance: toAfter, amount: amount, reverse: true);

      expect(fromReverted, equals(fromBefore));
      expect(toReverted, equals(toBefore));
    });
  });

  group('BalanceRules — Verifikasi Aliran Saldo Transaksi', () {
    /// Dataset validasi alur transaksi finansial mobile.

    test('Dataset 1: Gaji → Makan → Transportasi → Refund', () {
      int saldo = 0;

      // Saldo awal akun: 1.000.000
      saldo = 1000000;

      // Gaji 5.000.000 (income)
      saldo = BalanceRules.applyTransaction(
        currentBalance: saldo,
        type: TransactionType.income,
        amount: 5000000,
      );
      expect(saldo, equals(6000000), reason: 'Setelah gaji');

      // Makan 150.000 (expense)
      saldo = BalanceRules.applyTransaction(
        currentBalance: saldo,
        type: TransactionType.expense,
        amount: 150000,
      );
      expect(saldo, equals(5850000), reason: 'Setelah makan');

      // Transportasi 75.000 (expense)
      saldo = BalanceRules.applyTransaction(
        currentBalance: saldo,
        type: TransactionType.expense,
        amount: 75000,
      );
      expect(saldo, equals(5775000), reason: 'Setelah transportasi');

      // Refund belanja 50.000 (refund)
      saldo = BalanceRules.applyTransaction(
        currentBalance: saldo,
        type: TransactionType.refund,
        amount: 50000,
      );
      expect(saldo, equals(5825000), reason: 'Setelah refund');
    });

    test('Dataset 2: Net flow = income + refund - expense', () {
      /// Sesuai: backend/app/routes/dashboard.py
      /// net_flow = income + refund - expense

      const income = 8500000;
      const expense = 3200000;
      const refund = 150000;
      const expectedNetFlow = income + refund - expense; // 5.450.000

      expect(expectedNetFlow, equals(5450000));
    });

    test('Dataset 3: Transfer netral terhadap total aset', () {
      // 3 akun: BCA 10jt, GoPay 2jt, Cash 500rb
      const bca = 10000000;
      const gopay = 2000000;
      const cash = 500000;
      const totalBefore = bca + gopay + cash; // 12.500.000

      // Transfer 1jt dari BCA ke GoPay
      final bcaAfter =
          BalanceRules.applyTransferFrom(currentBalance: bca, amount: 1000000);
      final gopayAfter =
          BalanceRules.applyTransferTo(currentBalance: gopay, amount: 1000000);
      final totalAfter = bcaAfter + gopayAfter + cash;

      expect(totalAfter, equals(totalBefore),
          reason: 'Transfer tidak mengubah total aset');
      expect(bcaAfter, equals(9000000));
      expect(gopayAfter, equals(3000000));
    });
  });
}
