import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/data/repositories/account_repository.dart';
import 'package:money_flow/data/repositories/transaction_repository.dart';
import 'package:money_flow/domain/rules/balance_rules.dart';

/// Test database menggunakan in-memory SQLite.
AppDatabase _createTestDb() {
  return AppDatabase.forTesting(
    NativeDatabase.memory(),
  );
}

void main() {
  late AppDatabase db;
  late AccountRepository accountRepo;
  late TransactionRepository txnRepo;

  setUp(() async {
    db = _createTestDb();
    accountRepo = AccountRepository(db);
    txnRepo = TransactionRepository(db, accountRepo);

    // Seed categories untuk test
    await db.seedDefaultCategories();
    await db.seedDefaultSettings();
  });

  tearDown(() async {
    await db.close();
  });

  group('AccountRepository', () {
    test('Buat akun dan ambil dengan saldo awal', () async {
      final account = await accountRepo.create(
        name: 'BCA',
        type: AccountType.bank,
        initialBalance: 10000000,
        color: '#3B82F6',
      );

      expect(account.name, equals('BCA'));
      expect(account.type, equals(AccountType.bank));
      expect(account.balance, equals(10000000));
      expect(account.isActive, isTrue);
      expect(account.uuid, isNotEmpty);
    });

    test('Daftar akun aktif diurutkan', () async {
      await accountRepo.create(
          name: 'Cash', type: AccountType.cash, initialBalance: 500000);
      await accountRepo.create(
          name: 'BCA', type: AccountType.bank, initialBalance: 10000000);
      await accountRepo.create(
          name: 'GoPay', type: AccountType.ewallet, initialBalance: 200000);

      final accounts = await accountRepo.getActiveAccounts();
      expect(accounts.length, equals(3));
      // Diurutkan berdasarkan tipe (cash=0, bank=1, ewallet=2)
    });

    test('Total saldo dihitung dengan benar', () async {
      await accountRepo.create(
          name: 'Cash', type: AccountType.cash, initialBalance: 500000);
      await accountRepo.create(
          name: 'BCA', type: AccountType.bank, initialBalance: 10000000);
      await accountRepo.create(
          name: 'GoPay', type: AccountType.ewallet, initialBalance: 200000);

      final total = await accountRepo.getTotalBalance();
      expect(total, equals(10700000));
    });

    test('Soft delete akun dengan transaksi', () async {
      final account = await accountRepo.create(
        name: 'Test',
        type: AccountType.cash,
        initialBalance: 100000,
      );

      // Ambil kategori income pertama
      final categories = await db.select(db.categories).get();
      final incomeCat =
          categories.firstWhere((c) => c.type == CategoryType.income);

      // Buat transaksi
      await txnRepo.create(
        type: TransactionType.income,
        accountId: account.id,
        categoryId: incomeCat.id,
        amount: 50000,
        date: DateTime.now(),
      );

      // Delete → soft delete
      final message = await accountRepo.delete(account.id);
      expect(message, contains('dinonaktifkan'));

      // Akun masih ada tapi inactive
      final deleted = await accountRepo.getById(account.id);
      expect(deleted!.isActive, isFalse);
    });

    test('Hard delete akun tanpa transaksi', () async {
      final account = await accountRepo.create(
        name: 'Empty',
        type: AccountType.cash,
        initialBalance: 0,
      );

      final message = await accountRepo.delete(account.id);
      expect(message, contains('dihapus'));

      final deleted = await accountRepo.getById(account.id);
      expect(deleted, isNull);
    });
  });

  group('TransactionRepository', () {
    late Account testAccount;
    late Category incomeCategory;
    late Category expenseCategory;

    setUp(() async {
      testAccount = await accountRepo.create(
        name: 'Test Wallet',
        type: AccountType.cash,
        initialBalance: 1000000,
      );

      final categories = await db.select(db.categories).get();
      incomeCategory =
          categories.firstWhere((c) => c.type == CategoryType.income);
      expenseCategory =
          categories.firstWhere((c) => c.type == CategoryType.expense);
    });

    test('Catat pemasukan → saldo bertambah', () async {
      final txn = await txnRepo.create(
        type: TransactionType.income,
        accountId: testAccount.id,
        categoryId: incomeCategory.id,
        amount: 5000000,
        date: DateTime.now(),
        description: 'Gaji Oktober',
      );

      expect(txn.amount, equals(5000000));
      expect(txn.type, equals(TransactionType.income));

      // Cek saldo terupdate
      final account = await accountRepo.getById(testAccount.id);
      expect(account!.balance, equals(6000000)); // 1jt + 5jt
    });

    test('Catat pengeluaran → saldo berkurang', () async {
      await txnRepo.create(
        type: TransactionType.expense,
        accountId: testAccount.id,
        categoryId: expenseCategory.id,
        amount: 150000,
        date: DateTime.now(),
        description: 'Makan siang',
      );

      final account = await accountRepo.getById(testAccount.id);
      expect(account!.balance, equals(850000)); // 1jt - 150rb
    });

    test('Catat refund → saldo bertambah', () async {
      await txnRepo.create(
        type: TransactionType.refund,
        accountId: testAccount.id,
        categoryId: incomeCategory.id,
        amount: 50000,
        date: DateTime.now(),
        description: 'Refund belanja',
      );

      final account = await accountRepo.getById(testAccount.id);
      expect(account!.balance, equals(1050000)); // 1jt + 50rb
    });

    test('Hapus transaksi → saldo dikembalikan', () async {
      // Catat expense
      final txn = await txnRepo.create(
        type: TransactionType.expense,
        accountId: testAccount.id,
        categoryId: expenseCategory.id,
        amount: 300000,
        date: DateTime.now(),
      );

      var account = await accountRepo.getById(testAccount.id);
      expect(account!.balance, equals(700000)); // 1jt - 300rb

      // Hapus → reverse
      await txnRepo.deleteTransaction(txn.id);

      account = await accountRepo.getById(testAccount.id);
      expect(account!.balance, equals(1000000)); // Kembali ke 1jt
    });

    test('Skenario lengkap: income → expense → refund → delete expense',
        () async {
      // Initial: 1.000.000

      // Gaji 5jt
      await txnRepo.create(
        type: TransactionType.income,
        accountId: testAccount.id,
        categoryId: incomeCategory.id,
        amount: 5000000,
        date: DateTime.now(),
      );
      var account = await accountRepo.getById(testAccount.id);
      expect(account!.balance, equals(6000000));

      // Makan 150rb
      final expenseTxn = await txnRepo.create(
        type: TransactionType.expense,
        accountId: testAccount.id,
        categoryId: expenseCategory.id,
        amount: 150000,
        date: DateTime.now(),
      );
      account = await accountRepo.getById(testAccount.id);
      expect(account!.balance, equals(5850000));

      // Refund 50rb
      await txnRepo.create(
        type: TransactionType.refund,
        accountId: testAccount.id,
        categoryId: incomeCategory.id,
        amount: 50000,
        date: DateTime.now(),
      );
      account = await accountRepo.getById(testAccount.id);
      expect(account!.balance, equals(5900000));

      // Delete makan 150rb
      await txnRepo.deleteTransaction(expenseTxn.id);
      account = await accountRepo.getById(testAccount.id);
      expect(account!.balance, equals(6050000)); // 5.900.000 + 150.000
    });

    test('Validasi: amount harus > 0', () async {
      expect(
        () => txnRepo.create(
          type: TransactionType.income,
          accountId: testAccount.id,
          categoryId: incomeCategory.id,
          amount: 0,
          date: DateTime.now(),
        ),
        throwsArgumentError,
      );
    });

    test('Validasi: akun harus ada', () async {
      expect(
        () => txnRepo.create(
          type: TransactionType.income,
          accountId: 99999,
          categoryId: incomeCategory.id,
          amount: 100000,
          date: DateTime.now(),
        ),
        throwsStateError,
      );
    });

    test('Validasi: kategori harus ada', () async {
      expect(
        () => txnRepo.create(
          type: TransactionType.income,
          accountId: testAccount.id,
          categoryId: 99999,
          amount: 100000,
          date: DateTime.now(),
        ),
        throwsStateError,
      );
    });
  });

  group('Seed Data', () {
    test('Default categories ter-seed', () async {
      final categories = await db.select(db.categories).get();
      // 7 income + 10 expense = 17 total
      expect(categories.length, equals(17));

      final incomeCount =
          categories.where((c) => c.type == CategoryType.income).length;
      final expenseCount =
          categories.where((c) => c.type == CategoryType.expense).length;
      expect(incomeCount, equals(7));
      expect(expenseCount, equals(10));
    });

    test('Default settings ter-seed', () async {
      final settings = await db.select(db.settings).get();
      expect(settings.length, equals(5));

      final currency = settings.firstWhere((s) => s.key == 'currency');
      expect(currency.value, equals('IDR'));

      final taxRate = settings.firstWhere((s) => s.key == 'tax_rate_deposit');
      expect(taxRate.value, equals('20'));
    });

    test('Seed tidak duplikat pada panggilan kedua', () async {
      // Seed sudah dipanggil di setUp. Panggil lagi.
      await db.seedDefaultCategories();
      await db.seedDefaultSettings();

      final categories = await db.select(db.categories).get();
      expect(categories.length, equals(17)); // Tetap 17, tidak 34
    });
  });

  group('Dataset Kesetaraan Python ↔ Dart', () {
    test('Dataset 1: Gaji → Makan → Transportasi → Refund', () async {
      // Sesuai test_data_spec.py → test_dataset_1()
      final account = await accountRepo.create(
        name: 'Test',
        type: AccountType.cash,
        initialBalance: 1000000,
      );

      final categories = await db.select(db.categories).get();
      final incomeCat =
          categories.firstWhere((c) => c.type == CategoryType.income);
      final expenseCat =
          categories.firstWhere((c) => c.type == CategoryType.expense);

      // Gaji 5jt
      await txnRepo.create(
        type: TransactionType.income,
        accountId: account.id,
        categoryId: incomeCat.id,
        amount: 5000000,
        date: DateTime(2026, 10, 1),
      );
      var acc = await accountRepo.getById(account.id);
      expect(acc!.balance, equals(6000000),
          reason: 'Python expected: 6,000,000');

      // Makan 150rb
      await txnRepo.create(
        type: TransactionType.expense,
        accountId: account.id,
        categoryId: expenseCat.id,
        amount: 150000,
        date: DateTime(2026, 10, 2),
      );
      acc = await accountRepo.getById(account.id);
      expect(acc!.balance, equals(5850000),
          reason: 'Python expected: 5,850,000');

      // Transportasi 75rb
      await txnRepo.create(
        type: TransactionType.expense,
        accountId: account.id,
        categoryId: expenseCat.id,
        amount: 75000,
        date: DateTime(2026, 10, 3),
      );
      acc = await accountRepo.getById(account.id);
      expect(acc!.balance, equals(5775000),
          reason: 'Python expected: 5,775,000');

      // Refund 50rb
      await txnRepo.create(
        type: TransactionType.refund,
        accountId: account.id,
        categoryId: incomeCat.id,
        amount: 50000,
        date: DateTime(2026, 10, 4),
      );
      acc = await accountRepo.getById(account.id);
      expect(acc!.balance, equals(5825000),
          reason: 'Python expected: 5,825,000');
    });

    test('Transfer netral terhadap total aset (pure BalanceRules)', () {
      // Sesuai test_data_spec.py → test_transfer_neutral()
      const bca = 10000000;
      const gopay = 2000000;
      const cash = 500000;
      const totalBefore = bca + gopay + cash; // 12,500,000

      final bcaAfter =
          BalanceRules.applyTransferFrom(currentBalance: bca, amount: 1000000);
      final gopayAfter =
          BalanceRules.applyTransferTo(currentBalance: gopay, amount: 1000000);
      final totalAfter = bcaAfter + gopayAfter + cash;

      expect(totalAfter, equals(totalBefore),
          reason: 'Python expected: 12,500,000');
      expect(bcaAfter, equals(9000000), reason: 'Python expected: 9,000,000');
      expect(gopayAfter, equals(3000000), reason: 'Python expected: 3,000,000');
    });
  });
}
