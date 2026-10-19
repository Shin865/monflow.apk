import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/data/repositories/account_repository.dart';
import 'package:money_flow/data/services/backup_restore_service.dart';
import 'package:money_flow/data/services/encrypted_backup_service.dart';

void main() {
  late AppDatabase db;
  late AccountRepository accountRepo;
  late BackupRestoreService plainBackupService;
  late EncryptedBackupService encBackupService;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.seedDefaultCategories();
    accountRepo = AccountRepository(db);
    plainBackupService = BackupRestoreService(db);
    encBackupService = EncryptedBackupService(plainBackupService);
  });

  tearDown(() async {
    await db.close();
  });

  group('Milestone 6 — Encrypted Backup (AES-256-GCM + PBKDF2) Tests', () {
    test(
        'Export encrypted container contains standard header and cipher parameters',
        () async {
      await accountRepo.create(
          name: 'Dompet Rahasia',
          type: AccountType.cash,
          initialBalance: 750000);

      const password = 'SuperSecretPassword123!';
      final encryptedJson =
          await encBackupService.exportEncryptedToJson(password);
      final map = jsonDecode(encryptedJson) as Map<String, dynamic>;

      expect(map['format'], equals('money-flow-encrypted-backup'));
      expect(map['version'], equals(1));
      expect(map['cipher'], equals('AES-256-GCM'));
      expect(map['kdf'], equals('PBKDF2-HMAC-SHA256'));
      expect(map['kdf_iterations'], equals(10000));
      expect(map['salt'], isNotNull);
      expect(map['nonce'], isNotNull);
      expect(map['mac'], isNotNull);
      expect(map['ciphertext'], isNotNull);

      // Verify that user password is NOT inside the backup file
      expect(encryptedJson.contains(password), isFalse);
    });

    test('Header inspection validates metadata without decrypting', () async {
      const password = 'MyPassword999';
      final encJson = await encBackupService.exportEncryptedToJson(password);

      final header = EncryptedBackupService.inspectHeader(encJson);
      expect(header.isValidFormat, isTrue);
      expect(header.format, equals('money-flow-encrypted-backup'));
      expect(header.version, equals(1));
      expect(header.cipher, equals('AES-256-GCM'));
      expect(header.kdf, equals('PBKDF2-HMAC-SHA256'));
    });

    test('Decryption with correct password produces valid JSON snapshot',
        () async {
      await accountRepo.create(
          name: 'Bank Jago', type: AccountType.bank, initialBalance: 5000000);

      const password = 'CorrectPassword456';
      final encJson = await encBackupService.exportEncryptedToJson(password);

      final plainJson = await encBackupService.decryptToJson(encJson, password);
      final plainMap = jsonDecode(plainJson) as Map<String, dynamic>;

      expect(plainMap['format'], equals('money-flow-backup'));
      expect(plainMap['schema_version'], equals(3));
      final data = plainMap['data'] as Map<String, dynamic>;
      final accounts = data['accounts'] as List;
      expect(accounts.any((a) => a['name'] == 'Bank Jago'), isTrue);
    });

    test('Decryption with wrong password fails and throws FormatException',
        () async {
      await accountRepo.create(
          name: 'Tabungan Utama',
          type: AccountType.bank,
          initialBalance: 10000000);

      const correctPassword = 'StrongPassword123';
      final encJson =
          await encBackupService.exportEncryptedToJson(correctPassword);

      // Try decrypt with wrong password
      expect(
        () async =>
            await encBackupService.decryptToJson(encJson, 'WrongPassword'),
        throwsA(isA<FormatException>()),
      );
    });

    test('Tampered ciphertext fails authentication (AEAD integrity guarantee)',
        () async {
      const password = 'SecurePassword789';
      final encJson = await encBackupService.exportEncryptedToJson(password);
      final map = jsonDecode(encJson) as Map<String, dynamic>;

      // Tamper ciphertext
      final rawCipher = base64Decode(map['ciphertext'] as String);
      rawCipher[0] = rawCipher[0] ^ 0xFF; // flip bits
      map['ciphertext'] = base64Encode(rawCipher);

      final tamperedJson = jsonEncode(map);

      expect(
        () async =>
            await encBackupService.decryptToJson(tamperedJson, password),
        throwsA(isA<FormatException>()),
      );
    });

    test(
        'Failed restore leaves active database untouched (Atomicity guarantee)',
        () async {
      final initialAcc = await accountRepo.create(
          name: 'Data Penting Yang Harus Tetap Aman',
          type: AccountType.bank,
          initialBalance: 99999999);

      const password = 'RealPassword123';
      final encJson = await encBackupService.exportEncryptedToJson(password);

      // Restore with wrong password
      final failResult = await encBackupService.restoreEncryptedFromJson(
          encJson, 'WrongPassword');
      expect(failResult.success, isFalse);

      // Verify that database was NOT modified
      final accounts = await accountRepo.getActiveAccounts();
      expect(accounts.length, equals(1));
      expect(accounts.first.id, equals(initialAcc.id));
      expect(accounts.first.name, equals('Data Penting Yang Harus Tetap Aman'));
    });

    test('Successful encrypted restore reproduces complete database state',
        () async {
      await accountRepo.create(
          name: 'Dompet Tunai', type: AccountType.cash, initialBalance: 300000);

      const password = 'PasswordPemulihan123';
      final encJson = await encBackupService.exportEncryptedToJson(password);

      // Create new clean DB
      final targetDb = AppDatabase.forTesting(NativeDatabase.memory());
      final targetPlainService = BackupRestoreService(targetDb);
      final targetEncService = EncryptedBackupService(targetPlainService);
      final targetAccRepo = AccountRepository(targetDb);

      final restoreResult =
          await targetEncService.restoreEncryptedFromJson(encJson, password);
      expect(restoreResult.success, isTrue);

      final restoredAccs = await targetAccRepo.getActiveAccounts();
      expect(restoredAccs.length, equals(1));
      expect(restoredAccs.first.name, equals('Dompet Tunai'));
      expect(restoredAccs.first.balance, equals(300000));

      await targetDb.close();
    });
  });
}
