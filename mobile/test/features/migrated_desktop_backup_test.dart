import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/data/services/backup_restore_service.dart';

void main() {
  late AppDatabase db;
  late BackupRestoreService backupService;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    backupService = BackupRestoreService(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('Validates and restores migrated desktop user data backup successfully',
      () async {
    final file = File('../docs/desktop_migrated_backup.json');
    expect(file.existsSync(), isTrue);
    final jsonString = await file.readAsString();

    final validationError = BackupRestoreService.validateBackupJson(jsonString);
    expect(validationError, isNull, reason: 'JSON format should be valid');

    final result = await backupService.restoreFromJson(jsonString);
    expect(result.success, isTrue, reason: result.message);

    // Verify database contents
    final accounts = await db.select(db.accounts).get();
    expect(accounts.length, 3);
    expect(accounts.any((a) => a.name == 'SEA BANK'), isTrue);
    expect(accounts.any((a) => a.name == 'DOMPET'), isTrue);
    expect(accounts.any((a) => a.name == 'SHOPEEPAY'), isTrue);

    final transactions = await db.select(db.transactions).get();
    expect(transactions.length, 16);

    final transfers = await db.select(db.transfers).get();
    expect(transfers.length, 2);

    final deposits = await db.select(db.deposits).get();
    expect(deposits.length, 1);
    expect(deposits.first.name, '3 BULAN');
    expect(deposits.first.principal, 7000000);
    expect(deposits.first.annualRateBps, 600);

    final bills = await db.select(db.bills).get();
    expect(bills.length, 2);
    expect(bills.any((b) => b.name == 'WIFI'), isTrue);
    expect(bills.any((b) => b.name == 'BPJS'), isTrue);

    final purchasePlans = await db.select(db.purchasePlans).get();
    expect(purchasePlans.length, 13);
  });
}
