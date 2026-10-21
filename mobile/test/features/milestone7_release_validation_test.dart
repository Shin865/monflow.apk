import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/data/repositories/account_repository.dart';
import 'package:money_flow/data/repositories/transaction_repository.dart';
import 'package:money_flow/data/repositories/transfer_repository.dart';
import 'package:money_flow/data/repositories/bill_repository.dart';
import 'package:money_flow/data/repositories/debt_repository.dart';
import 'package:money_flow/data/repositories/deposit_repository.dart';
import 'package:money_flow/data/repositories/purchase_plan_repository.dart';
import 'package:money_flow/data/services/backup_restore_service.dart';
import 'package:money_flow/data/services/encrypted_backup_service.dart';
import 'package:money_flow/data/services/report_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  late AppDatabase db;
  late AccountRepository accountRepo;
  late TransactionRepository transactionRepo;
  late TransferRepository transferRepo;
  late BillRepository billRepo;
  late DebtRepository debtRepo;
  late DepositRepository depositRepo;
  late PurchasePlanRepository purchasePlanRepo;
  late BackupRestoreService backupService;
  late EncryptedBackupService encryptedBackupService;
  late ReportService reportService;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.seedDefaultCategories();
    await db.seedDefaultSettings();

    accountRepo = AccountRepository(db);
    transactionRepo = TransactionRepository(db, accountRepo);
    transferRepo = TransferRepository(db, accountRepo);
    billRepo = BillRepository(db);
    debtRepo = DebtRepository(db);
    depositRepo = DepositRepository(db);
    purchasePlanRepo = PurchasePlanRepository(db);
    backupService = BackupRestoreService(db);
    encryptedBackupService = EncryptedBackupService(backupService);
    reportService = ReportService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Milestone 7 — Final Release Integrity & Data Validation Tests', () {
    test(
        'Offline-First: All repositories operate without internet or backend server',
        () async {
      // 1. Create account
      final acc = await accountRepo.create(
        name: 'BCA Utama',
        type: AccountType.bank,
        initialBalance: 15000000,
      );
      expect(acc.id, greaterThan(0));

      // 2. Add income & expense
      final categories = await db.select(db.categories).get();
      final gajiCat =
          categories.firstWhere((c) => c.type == CategoryType.income);
      final makanCat =
          categories.firstWhere((c) => c.type == CategoryType.expense);

      final inc = await transactionRepo.create(
        type: TransactionType.income,
        accountId: acc.id,
        categoryId: gajiCat.id,
        amount: 10000000,
        date: DateTime.now(),
        description: 'Gaji Bulanan',
      );
      expect(inc.id, greaterThan(0));

      final exp = await transactionRepo.create(
        type: TransactionType.expense,
        accountId: acc.id,
        categoryId: makanCat.id,
        amount: 2500000,
        date: DateTime.now(),
        description: 'Makan & Groceries',
      );
      expect(exp.id, greaterThan(0));

      // Verify balance updated strictly locally
      final updatedAcc = await accountRepo.getById(acc.id);
      expect(updatedAcc!.balance, equals(22500000)); // 15jt + 10jt - 2.5jt
    });

    test(
        'Transfer Invariance: Transfer between accounts preserves total combined assets',
        () async {
      final acc1 = await accountRepo.create(
          name: 'Mandiri', type: AccountType.bank, initialBalance: 10000000);
      final acc2 = await accountRepo.create(
          name: 'Dompet Kas', type: AccountType.cash, initialBalance: 2000000);

      final initialTotal = await accountRepo.getTotalBalance();
      expect(initialTotal, equals(12000000));

      // Execute transfer between accounts
      await transferRepo.create(
        fromAccountId: acc1.id,
        toAccountId: acc2.id,
        amount: 3000000,
        date: DateTime.now(),
        description: 'Tarik tunai ATM',
      );

      final postTransferAcc1 = await accountRepo.getById(acc1.id);
      final postTransferAcc2 = await accountRepo.getById(acc2.id);

      expect(
          postTransferAcc1!.balance, equals(10000000 - 3000000)); // 7.000.000
      expect(postTransferAcc2!.balance, equals(2000000 + 3000000)); // 5.000.000

      final postTotal = await accountRepo.getTotalBalance();
      // Invariance principle: Total assets remain unchanged
      expect(postTotal, equals(initialTotal));
    });

    test(
        'Clean Installation Restore: Backup with rich data restores completely onto clean install',
        () async {
      // 1. Populate source database with realistic diverse data
      final bank = await accountRepo.create(
          name: 'CIMB Niaga', type: AccountType.bank, initialBalance: 50000000);
      final ewallet = await accountRepo.create(
          name: 'GoPay', type: AccountType.ewallet, initialBalance: 1500000);
      expect(bank.id, greaterThan(0));
      expect(ewallet.id, greaterThan(0));

      final categories = await db.select(db.categories).get();
      final cat = categories.first;

      await transactionRepo.create(
        type: TransactionType.income,
        accountId: bank.id,
        categoryId: cat.id,
        amount: 15000000,
        date: DateTime.now(),
      );

      await purchasePlanRepo.create(
        name: 'Laptop Kerja',
        targetAmount: 18000000,
        description: 'Untuk produktivitas',
      );
      await billRepo.createBill(
        name: 'Tagihan Listrik PLN',
        amount: 750000,
        dueDate: DateTime.now().add(const Duration(days: 5)),
      );
      await debtRepo.createDebt(
        name: 'Piutang Budi',
        person: 'Budi Santoso',
        totalAmount: 2000000,
        type: DebtType.piutang,
      );
      await depositRepo.create(
        name: 'BCA Syariah Deposito',
        bankName: 'BCA Syariah',
        principal: 20000000,
        annualRateBps: 550, // 5.5%
        tenorMonths: 12,
        startDate: DateTime.now(),
      );

      // 2. Export Encrypted Backup
      const password = 'SuperSecretReleaseKey2026!';
      final encryptedJson =
          await encryptedBackupService.exportEncryptedToJson(password);
      expect(encryptedJson.isNotEmpty, isTrue);

      // 3. Setup a completely fresh/clean database instance
      final freshDb = AppDatabase.forTesting(NativeDatabase.memory());
      final freshPlainService = BackupRestoreService(freshDb);
      final freshEncryptedService = EncryptedBackupService(freshPlainService);

      // 4. Restore into clean database
      final restoreResult = await freshEncryptedService
          .restoreEncryptedFromJson(encryptedJson, password);
      expect(restoreResult.success, isTrue);

      // 5. Verify restored state
      final restoredAccounts = await freshDb.select(freshDb.accounts).get();
      expect(restoredAccounts.length, equals(2));
      expect(restoredAccounts.any((a) => a.name == 'CIMB Niaga'), isTrue);
      expect(restoredAccounts.any((a) => a.name == 'GoPay'), isTrue);

      final restoredPurchasePlans =
          await freshDb.select(freshDb.purchasePlans).get();
      expect(restoredPurchasePlans.length, equals(1));
      expect(restoredPurchasePlans.first.name, equals('Laptop Kerja'));

      final restoredBills = await freshDb.select(freshDb.bills).get();
      expect(restoredBills.length, equals(1));
      expect(restoredBills.first.name, equals('Tagihan Listrik PLN'));

      final restoredDebts = await freshDb.select(freshDb.debts).get();
      expect(restoredDebts.length, equals(1));
      expect(restoredDebts.first.name, equals('Piutang Budi'));

      final restoredDeposits = await freshDb.select(freshDb.deposits).get();
      expect(restoredDeposits.length, equals(1));
      expect(restoredDeposits.first.principal, equals(20000000));

      await freshDb.close();
    });

    test(
        'Atomicity Guarantee: Failed decryption leaves active database 100% untouched',
        () async {
      final initialAcc = await accountRepo.create(
          name: 'Dompet Intact',
          type: AccountType.cash,
          initialBalance: 5000000);
      final initialCount = (await db.select(db.accounts).get()).length;

      // Create an invalid/corrupted ciphertext
      final corruptedPayload = jsonEncode({
        'format': 'money-flow-encrypted-backup',
        'version': 1,
        'cipher': 'AES-256-GCM',
        'kdf': 'PBKDF2-HMAC-SHA256',
        'salt': '0102030405060708090a0b0c0d0e0f10',
        'nonce': '0102030405060708090a0b0c',
        'mac': '00000000000000000000000000000000',
        'ciphertext': 'deadbeefc001cafe',
      });

      final result = await encryptedBackupService.restoreEncryptedFromJson(
          corruptedPayload, 'AnyPassword');
      expect(result.success, isFalse);

      // Assert database unchanged
      final currentAccounts = await db.select(db.accounts).get();
      expect(currentAccounts.length, equals(initialCount));
      expect(currentAccounts.first.id, equals(initialAcc.id));
      expect(currentAccounts.first.balance, equals(5000000));
    });

    test(
        'Reports Consistency: Comprehensive net worth aggregates all pillars without drift',
        () async {
      final acc = await accountRepo.create(
          name: 'Bank Tabungan',
          type: AccountType.bank,
          initialBalance: 20000000);
      expect(acc.id, greaterThan(0));
      await depositRepo.create(
          name: 'Mandiri Deposito',
          bankName: 'Mandiri',
          principal: 10000000,
          annualRateBps: 500,
          tenorMonths: 6,
          startDate: DateTime.now());
      await debtRepo.createDebt(
          name: 'Pinjaman KTA',
          person: 'Bank Mandiri',
          totalAmount: 5000000,
          type: DebtType.hutang);

      final report = await reportService.getComprehensiveReport();
      expect(report.totalCashBalance, equals(20000000));
      expect(report.totalDepositsPrincipal, equals(10000000));
      expect(report.totalDebts, equals(5000000));
      expect(
          report.netWorth, equals(20000000 + 10000000 - 5000000)); // 25.000.000
    });
  });
}
