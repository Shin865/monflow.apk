import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/data/repositories/account_repository.dart';
import 'package:money_flow/data/repositories/investment_repository.dart';
import 'package:money_flow/data/repositories/deposit_repository.dart';
import 'package:money_flow/data/repositories/savings_goal_repository.dart';
import 'package:money_flow/data/repositories/purchase_plan_repository.dart';
import 'package:money_flow/data/services/backup_restore_service.dart';

void main() {
  late AppDatabase db;
  late AccountRepository accountRepo;
  late InvestmentRepository investmentRepo;
  late DepositRepository depositRepo;
  late SavingsGoalRepository savingsGoalRepo;
  late PurchasePlanRepository purchasePlanRepo;
  late BackupRestoreService backupService;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.seedDefaultCategories();
    accountRepo = AccountRepository(db);
    investmentRepo = InvestmentRepository(db);
    depositRepo = DepositRepository(db);
    savingsGoalRepo = SavingsGoalRepository(db);
    purchasePlanRepo = PurchasePlanRepository(db);
    backupService = BackupRestoreService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Milestone 5 — Backup & Restore Schema Version 3', () {
    test('Export includes Milestone 5 tables in JSON snapshot', () async {
      final acc = await accountRepo.create(
          name: 'Bank Jago', type: AccountType.bank, initialBalance: 100000000);
      await investmentRepo.create(
        name: 'BBRI',
        type: InvestmentType.saham,
        accountId: acc.id,
        initialCost: 20000000,
        currentValue: 22000000,
        units: 4000.0,
      );
      await depositRepo.create(
        name: 'Deposito BCA 6%',
        principal: 50000000,
        annualRateBps: 600,
        tenorMonths: 12,
        startDate: DateTime(2026, 1, 1),
      );
      await savingsGoalRepo.create(
        name: 'Dana Darurat',
        targetAmount: 30000000,
        currentAmount: 10000000,
      );
      await purchasePlanRepo.create(
        name: 'Sepeda Lipat',
        targetAmount: 5000000,
        allocatedAmount: 2000000,
        priority: PlanPriority.high,
      );

      final jsonStr = await backupService.exportToJson();
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(map['schema_version'], equals(3));
      final data = map['data'] as Map<String, dynamic>;
      expect((data['investments'] as List).length, equals(1));
      expect((data['investment_transactions'] as List).length, equals(1));
      expect((data['deposits'] as List).length, equals(1));
      expect((data['savings_goals'] as List).length, equals(1));
      expect((data['purchase_plans'] as List).length, equals(1));
    });

    test('Atomic restore reproduces complete state in target database',
        () async {
      final acc = await accountRepo.create(
          name: 'Mandiri', type: AccountType.bank, initialBalance: 50000000);
      await investmentRepo.create(
        name: 'Emas Antam',
        type: InvestmentType.emas,
        accountId: acc.id,
        initialCost: 15000000,
        currentValue: 16500000,
        units: 15.0,
      );
      await depositRepo.create(
        name: 'Deposito BRI 5.5%',
        principal: 20000000,
        annualRateBps: 550,
        tenorMonths: 6,
        startDate: DateTime(2026, 3, 1),
      );
      await savingsGoalRepo.create(
        name: 'Renovasi Rumah',
        targetAmount: 100000000,
        currentAmount: 25000000,
      );
      await purchasePlanRepo.create(
        name: 'iPad Pro',
        targetAmount: 18000000,
        allocatedAmount: 18000000,
        priority: PlanPriority.medium,
      );

      final jsonStr = await backupService.exportToJson();

      // Buat database baru yang bersih
      final targetDb = AppDatabase.forTesting(NativeDatabase.memory());
      final targetBackupService = BackupRestoreService(targetDb);
      final targetInvRepo = InvestmentRepository(targetDb);
      final targetDepRepo = DepositRepository(targetDb);
      final targetGoalRepo = SavingsGoalRepository(targetDb);
      final targetPlanRepo = PurchasePlanRepository(targetDb);

      await targetBackupService.restoreFromJson(jsonStr);

      final restoredInvs = await targetInvRepo.getActiveInvestments();
      expect(restoredInvs.length, equals(1));
      expect(restoredInvs.first.name, equals('Emas Antam'));
      expect(restoredInvs.first.currentValue, equals(16500000));

      final restoredDeps = await targetDepRepo.getDeposits();
      expect(restoredDeps.length, equals(1));
      expect(restoredDeps.first.name, equals('Deposito BRI 5.5%'));
      expect(restoredDeps.first.principal, equals(20000000));

      final restoredGoals = await targetGoalRepo.getGoals();
      expect(restoredGoals.length, equals(1));
      expect(restoredGoals.first.name, equals('Renovasi Rumah'));
      expect(restoredGoals.first.targetAmount, equals(100000000));

      final restoredPlans = await targetPlanRepo.getPlans();
      expect(restoredPlans.length, equals(1));
      expect(restoredPlans.first.name, equals('iPad Pro'));
      expect(restoredPlans.first.status, equals(PlanStatus.achieved));

      await targetDb.close();
    });

    test(
        'Backward compatibility: restoring schema_version 1 or 2 json succeeds',
        () async {
      // JSON backup dari versi sebelumnya (hanya akun & kategori)
      final legacyBackup = {
        'format': 'money-flow-backup',
        'schema_version': 1,
        'app': 'money_flow',
        'exported_at': DateTime.now().toIso8601String(),
        'metadata': {
          'total_accounts': 1,
          'total_categories': 1,
          'total_transactions': 0,
          'total_transfers': 0,
          'total_balance': 500000,
        },
        'data': {
          'accounts': [
            {
              'id': 1,
              'uuid': 'acc-legacy-1',
              'name': 'Kas Lama',
              'type': 0,
              'balance': 500000,
              'initial_balance': 500000,
              'is_active': 1,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            }
          ],
          'categories': [
            {
              'id': 1,
              'uuid': 'cat-legacy-1',
              'name': 'Lain-lain',
              'type': 1,
              'is_system': 1,
              'is_active': 1,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            }
          ],
          'transactions': [],
          'transfers': [],
        }
      };

      final legacyJson = jsonEncode(legacyBackup);
      final preview = backupService.inspectBackup(legacyJson);
      expect(preview.isValid, isTrue);

      // Restore legacy
      await backupService.restoreFromJson(legacyJson);

      final accounts = await (db.select(db.accounts)).get();
      expect(accounts.length, equals(1));
      expect(accounts.first.name, equals('Kas Lama'));

      // Tabel M5 tetap ada dan kosong tanpa error
      final invs = await investmentRepo.getActiveInvestments();
      expect(invs.isEmpty, isTrue);
    });
  });
}
