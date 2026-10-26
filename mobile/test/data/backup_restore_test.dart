import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/data/repositories/account_repository.dart';
import 'package:money_flow/data/repositories/category_repository.dart';
import 'package:money_flow/data/repositories/transaction_repository.dart';
import 'package:money_flow/data/repositories/transfer_repository.dart';
import 'package:money_flow/data/services/backup_restore_service.dart';

void main() {
  late AppDatabase db;
  late AccountRepository accountRepo;
  late CategoryRepository categoryRepo;
  late TransactionRepository transactionRepo;
  late TransferRepository transferRepo;
  late BackupRestoreService backupService;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    accountRepo = AccountRepository(db);
    categoryRepo = CategoryRepository(db);
    transactionRepo = TransactionRepository(db, accountRepo);
    transferRepo = TransferRepository(db, accountRepo);
    backupService = BackupRestoreService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('BackupRestoreService — Format & Snapshot Export', () {
    test(
        'Export menghasilkan format money-flow-backup dengan schema_version 1 dan metadata',
        () async {
      final acc = await accountRepo.create(
        name: 'BCA Utama',
        type: AccountType.bank,
        initialBalance: 5000000,
      );
      final cat = await categoryRepo.createCategory(
        name: 'Gaji',
        type: CategoryType.income,
      );
      await transactionRepo.create(
        type: TransactionType.income,
        accountId: acc.id,
        categoryId: cat.id,
        amount: 10000000,
        date: DateTime.now(),
      );

      final jsonStr = await backupService.exportToJson();
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(map['format'], 'money-flow-backup');
      expect(map['schema_version'], BackupRestoreService.currentSchemaVersion);
      expect(map['app'], 'money_flow');
      expect(map['exported_at'], isNotNull);

      final metadata = map['metadata'] as Map<String, dynamic>;
      expect(metadata['total_accounts'], 1);
      expect(metadata['total_categories'], 1);
      expect(metadata['total_transactions'], 1);
      expect(metadata['total_balance'], 15000000); // 5jt + 10jt

      final data = map['data'] as Map<String, dynamic>;
      expect((data['accounts'] as List).length, 1);
      expect((data['categories'] as List).length, 1);
      expect((data['transactions'] as List).length, 1);
      expect((data['transfers'] as List).length, 0);
    });

    test('inspectBackup menghasilkan pratinjau yang valid dan akurat',
        () async {
      final acc1 = await accountRepo.create(
          name: 'Dompet', type: AccountType.cash, initialBalance: 200000);
      final acc2 = await accountRepo.create(
          name: 'Bank', type: AccountType.bank, initialBalance: 800000);
      await categoryRepo.createCategory(
          name: 'Makan', type: CategoryType.expense);
      await transferRepo.create(
          fromAccountId: acc2.id,
          toAccountId: acc1.id,
          amount: 100000,
          date: DateTime.now());

      final jsonStr = await backupService.exportToJson();
      final preview = backupService.inspectBackup(jsonStr);

      expect(preview.isValid, isTrue);
      expect(preview.format, 'money-flow-backup');
      expect(preview.schemaVersion, BackupRestoreService.currentSchemaVersion);
      expect(preview.accountsCount, 2);
      expect(preview.categoriesCount, 1);
      expect(preview.transfersCount, 1);
      expect(preview.totalBalance, 1000000); // 200k + 800k (transfer netral)
    });
  });

  group('BackupRestoreService — Validasi & Keamanan Skema', () {
    test('Validasi gagal jika string bukan JSON', () {
      const corrupt = 'bukan json { corrupt';
      final error = BackupRestoreService.validateBackupJson(corrupt);
      expect(error, contains('JSON'));

      final preview = backupService.inspectBackup(corrupt);
      expect(preview.isValid, isFalse);
    });

    test('Validasi gagal jika format tidak dikenal', () {
      final fake = jsonEncode({
        'format': 'unknown-app-backup',
        'schema_version': 1,
        'data': {
          'accounts': [],
          'categories': [],
          'transactions': [],
          'transfers': []
        }
      });
      final error = BackupRestoreService.validateBackupJson(fake);
      expect(error, contains('Format cadangan tidak dikenali'));
    });

    test('Validasi gagal jika schema_version berbeda', () {
      final futureVer = jsonEncode({
        'format': 'money-flow-backup',
        'schema_version': 99,
        'data': {
          'accounts': [],
          'categories': [],
          'transactions': [],
          'transfers': []
        }
      });
      final error = BackupRestoreService.validateBackupJson(futureVer);
      expect(error, contains('Versi skema cadangan (99) tidak didukung'));
    });

    test('Validasi gagal jika tabel wajib tidak ada', () {
      final missingTable = jsonEncode({
        'format': 'money-flow-backup',
        'schema_version': 1,
        'data': {'accounts': []} // categories & transactions missing
      });
      final error = BackupRestoreService.validateBackupJson(missingTable);
      expect(error, contains('tidak ditemukan'));
    });

    test(
        'Validasi gagal jika relasi transaksi rusak (Foreign Key account_id tidak ada)',
        () {
      final badFk = jsonEncode({
        'format': 'money-flow-backup',
        'schema_version': 1,
        'data': {
          'accounts': [
            {
              'id': 1,
              'name': 'Cash',
              'type': 0,
              'balance': 50000,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String()
            }
          ],
          'categories': [
            {'id': 1, 'name': 'Food', 'type': 1}
          ],
          'transactions': [
            // account_id 999 TIDAK ADA di accounts
            {
              'id': 1,
              'type': 1,
              'account_id': 999,
              'category_id': 1,
              'amount': 10000,
              'date': DateTime.now().toIso8601String(),
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String()
            }
          ],
          'transfers': []
        }
      });

      final error = BackupRestoreService.validateBackupJson(badFk);
      expect(
          error, contains('Relasi rusak: Transaksi mengacu pada Akun ID 999'));
    });

    test('Validasi gagal jika relasi transfer sama antara from dan to', () {
      final badTransfer = jsonEncode({
        'format': 'money-flow-backup',
        'schema_version': 1,
        'data': {
          'accounts': [
            {
              'id': 1,
              'name': 'Cash',
              'type': 0,
              'balance': 50000,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String()
            }
          ],
          'categories': [],
          'transactions': [],
          'transfers': [
            {
              'id': 1,
              'from_account_id': 1,
              'to_account_id': 1,
              'amount': 10000,
              'date': DateTime.now().toIso8601String(),
              'created_at': DateTime.now().toIso8601String()
            }
          ]
        }
      });

      final error = BackupRestoreService.validateBackupJson(badTransfer);
      expect(error, contains('Akun asal dan tujuan transfer tidak boleh sama'));
    });

    test('Validasi gagal jika nominal transaksi <= 0', () {
      final invalidAmount = jsonEncode({
        'format': 'money-flow-backup',
        'schema_version': 1,
        'data': {
          'accounts': [
            {
              'id': 1,
              'name': 'Cash',
              'type': 0,
              'balance': 50000,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String()
            }
          ],
          'categories': [
            {'id': 1, 'name': 'Food', 'type': 1}
          ],
          'transactions': [
            {
              'id': 1,
              'type': 1,
              'account_id': 1,
              'category_id': 1,
              'amount': 0,
              'date': DateTime.now().toIso8601String(),
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String()
            }
          ],
          'transfers': []
        }
      });

      final error = BackupRestoreService.validateBackupJson(invalidAmount);
      expect(
          error,
          contains(
              'Constraint dilanggar: Nominal transaksi harus bernilai integer > 0'));
    });
  });

  group('BackupRestoreService — Pemulihan Atomik (Atomicity & Full Replace)',
      () {
    test(
        'Pemulihan sukses mengembalikan seluruh data dengan Primary Key ID yang terjaga',
        () async {
      // 1. Populasi data awal
      final acc1 = await accountRepo.create(
          name: 'Dompet Asli', type: AccountType.cash, initialBalance: 150000);
      final acc2 = await accountRepo.create(
          name: 'Bank Mandiri',
          type: AccountType.bank,
          initialBalance: 1000000);
      final cat1 = await categoryRepo.createCategory(
          name: 'Transportasi', type: CategoryType.expense);
      await categoryRepo.createCategory(
          name: 'Bonus', type: CategoryType.income);

      await transactionRepo.create(
        type: TransactionType.expense,
        accountId: acc1.id,
        categoryId: cat1.id,
        amount: 25000,
        date: DateTime(2026, 10, 1),
      );
      await transferRepo.create(
        fromAccountId: acc2.id,
        toAccountId: acc1.id,
        amount: 100000,
        date: DateTime(2026, 10, 2),
      );

      // 2. Export ke JSON
      final exportedJson = await backupService.exportToJson();

      // 3. Ubah database aktif dengan data baru (untuk membuktikan full replace)
      await accountRepo.create(
          name: 'Akun Sementara Yang Akan Hilang',
          type: AccountType.other,
          initialBalance: 999999);
      final preCount = (await accountRepo.getActiveAccounts()).length;
      expect(preCount, 3);

      // 4. Lakukan Restore
      final result = await backupService.restoreFromJson(exportedJson);
      expect(result.success, isTrue);

      // 5. Verifikasi bahwa database terpulihkan secara presisi
      final restoredAccounts = await accountRepo.getActiveAccounts();
      expect(restoredAccounts.length, 2);
      expect(
          restoredAccounts
              .any((a) => a.name == 'Akun Sementara Yang Akan Hilang'),
          isFalse);

      final restoredAcc1 =
          restoredAccounts.firstWhere((a) => a.name == 'Dompet Asli');
      expect(restoredAcc1.id, acc1.id);
      expect(restoredAcc1.balance, 225000); // 150k - 25k + 100k

      final restoredCategories = await categoryRepo.getAllCategories();
      expect(restoredCategories.length, 2);

      final restoredTxns = await transactionRepo.getTransactions();
      expect(restoredTxns.length, 1);
      expect(restoredTxns.first.transaction.amount, 25000);
      expect(restoredTxns.first.accountName, 'Dompet Asli');
      expect(restoredTxns.first.categoryName, 'Transportasi');

      final restoredTransfers = await transferRepo.getAllTransfers();
      expect(restoredTransfers.length, 1);
      expect(restoredTransfers.first.amount, 100000);
    });

    test(
        'Kegagalan restore (misal relasi tidak valid) TIDAK merusak database aktif',
        () async {
      // 1. Data aktif di database
      final originalAccount = await accountRepo.create(
        name: 'Rekening Suci',
        type: AccountType.savings,
        initialBalance: 777000,
      );

      // 2. Buat JSON korup dengan relasi rusak
      final corruptPayload = jsonEncode({
        'format': 'money-flow-backup',
        'schema_version': 1,
        'data': {
          'accounts': [
            {
              'id': 1,
              'name': 'X',
              'type': 0,
              'balance': 1000,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String()
            }
          ],
          'categories': [],
          'transactions': [
            // category_id 9999 tidak ada
            {
              'id': 1,
              'type': 1,
              'account_id': 1,
              'category_id': 9999,
              'amount': 500,
              'date': DateTime.now().toIso8601String(),
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String()
            }
          ],
          'transfers': []
        }
      });

      // 3. Jalankan restore
      final result = await backupService.restoreFromJson(corruptPayload);
      expect(result.success, isFalse);
      expect(result.message, contains('Relasi rusak'));

      // 4. Pastikan data asli 'Rekening Suci' TETAP UTUH tanpa ada perubahan sama sekali!
      final activeAccounts = await accountRepo.getActiveAccounts();
      expect(activeAccounts.length, 1);
      expect(activeAccounts.first.id, originalAccount.id);
      expect(activeAccounts.first.name, 'Rekening Suci');
      expect(activeAccounts.first.balance, 777000);
    });
  });
}
