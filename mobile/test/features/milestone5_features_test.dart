import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/data/repositories/account_repository.dart';
import 'package:money_flow/data/repositories/investment_repository.dart';
import 'package:money_flow/data/repositories/deposit_repository.dart';
import 'package:money_flow/data/repositories/savings_goal_repository.dart';
import 'package:money_flow/data/repositories/purchase_plan_repository.dart';
import 'package:money_flow/data/services/forecast_service.dart';
import 'package:money_flow/domain/rules/net_worth_rules.dart';

void main() {
  late AppDatabase db;
  late AccountRepository accountRepo;
  late InvestmentRepository investmentRepo;
  late DepositRepository depositRepo;
  late SavingsGoalRepository savingsGoalRepo;
  late PurchasePlanRepository purchasePlanRepo;
  late ForecastService forecastService;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.seedDefaultCategories();
    accountRepo = AccountRepository(db);
    investmentRepo = InvestmentRepository(db);
    depositRepo = DepositRepository(db);
    savingsGoalRepo = SavingsGoalRepository(db);
    purchasePlanRepo = PurchasePlanRepository(db);
    forecastService = ForecastService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Milestone 5 — Investment Repository Tests', () {
    test('Create investment and track initial buy transaction', () async {
      final inv = await investmentRepo.create(
        name: 'BBCA Stock',
        type: InvestmentType.saham,
        initialCost: 10000000,
        currentValue: 10000000,
        units: 1000.0,
      );

      expect(inv.id, isNotNull);
      expect(inv.name, equals('BBCA Stock'));
      expect(inv.initialCost, equals(10000000));
      expect(inv.currentValue, equals(10000000));
      expect(inv.units, equals(1000.0));

      final txns = await db.select(db.investmentTransactions).get();
      expect(txns.length, equals(1));
      expect(txns.first.type, equals(InvestmentTxnType.buy));
      expect(txns.first.amount, equals(10000000));
    });

    test('Update valuation records valuation history and leaves cost unchanged',
        () async {
      final inv = await investmentRepo.create(
        name: 'SBN Ritel',
        type: InvestmentType.obligasi,
        initialCost: 20000000,
        currentValue: 20000000,
      );

      await investmentRepo.updateValuation(
        inv.id,
        newValue: 21500000,
        notes: 'Kenaikan harga pasar sekunder',
      );

      final updated = await investmentRepo.getById(inv.id);
      expect(updated!.initialCost, equals(20000000));
      expect(updated.currentValue, equals(21500000));

      final txns = await db.select(db.investmentTransactions).get();
      expect(txns.length, equals(2));
      expect(txns.last.type, equals(InvestmentTxnType.valuation));
      expect(txns.last.amount, equals(21500000));
    });

    test('Add sell transaction reduces units and cost basis', () async {
      final inv = await investmentRepo.create(
        name: 'Reksadana Saham',
        type: InvestmentType.reksadana,
        initialCost: 10000000,
        currentValue: 12000000,
        units: 100.0,
      );

      // Jual 50 unit pada harga 120,000/unit (gross 6M), fee 10,000
      await investmentRepo.addTransaction(
        inv.id,
        type: InvestmentTxnType.sell,
        amount: 6000000,
        units: 50.0,
        pricePerUnit: 120000.0,
        fee: 10000,
        date: DateTime.now(),
        notes: 'Profit taking sebagian',
      );

      final updated = await investmentRepo.getById(inv.id);
      expect(updated!.units, equals(50.0));
      expect(updated.initialCost, equals(5000000)); // (50/100) * 10M sisa
    });
  });

  group('Milestone 5 — Deposit Repository Tests', () {
    test(
        'Create deposit with basis point interest and calculate maturity correctly',
        () async {
      final startDate = DateTime(2026, 1, 15);
      final dep = await depositRepo.create(
        name: 'Deposito BCA',
        bankName: 'BCA',
        principal: 50000000,
        annualRateBps: 625, // 6.25%
        tenorMonths: 12,
        taxRateBps: 2000, // 20%
        startDate: startDate,
      );

      expect(dep.id, isNotNull);
      expect(dep.principal, equals(50000000));
      expect(dep.annualRateBps, equals(625));
      expect(dep.tenorMonths, equals(12));
      expect(dep.status, equals(DepositStatus.active));
      expect(dep.maturityDate.year, equals(2027));
      expect(dep.maturityDate.month, equals(1));
      expect(dep.maturityDate.day, equals(15));
    });

    test('Withdraw deposit credits principal and net interest to cash account',
        () async {
      final acc = await accountRepo.create(
        name: 'Rekening Giro',
        type: AccountType.bank,
        initialBalance: 10000000,
      );

      // Deposito 100M, rate 400 bps (4%), tenor 12 bulan -> net interest 3,200,000
      // Maturity = 103,200,000
      final dep = await depositRepo.create(
        name: 'Deposito Mandiri',
        principal: 100000000,
        annualRateBps: 400,
        tenorMonths: 12,
        startDate: DateTime(2025, 1, 1),
      );

      await depositRepo.withdraw(
        dep.id,
        returnToAccountId: acc.id,
        recordInterestIncome: true,
      );

      final updatedDep = await depositRepo.getById(dep.id);
      expect(updatedDep!.status, equals(DepositStatus.withdrawn));

      final updatedAcc = await accountRepo.getById(acc.id);
      // Saldo awal 10M + 103.2M = 113.2M
      expect(updatedAcc!.balance, equals(113200000));
    });

    test('Rollover deposit updates startDate and maturityDate', () async {
      final dep = await depositRepo.create(
        name: 'Deposito BRI',
        principal: 30000000,
        annualRateBps: 550,
        tenorMonths: 6,
        startDate: DateTime(2026, 1, 1),
      );

      await depositRepo.rollover(
        dep.id,
        newRateBps: 575,
        newTenorMonths: 12,
      );

      final updated = await depositRepo.getById(dep.id);
      expect(updated!.annualRateBps, equals(575));
      expect(updated.tenorMonths, equals(12));
      expect(updated.status, equals(DepositStatus.active));
    });
  });

  group('Milestone 5 — Savings Goals Tests', () {
    test(
        'Create savings goal and add virtual contribution (no account deduction)',
        () async {
      final goal = await savingsGoalRepo.create(
        name: 'Dana Darurat 6 Bulan',
        targetAmount: 30000000,
        currentAmount: 5000000,
      );

      expect(goal.status, equals(SavingsGoalStatus.active));

      // Virtual contribution
      await savingsGoalRepo.addContribution(goal.id, 10000000);

      final updated = await savingsGoalRepo.getById(goal.id);
      expect(updated!.currentAmount, equals(15000000));
      expect(updated.status, equals(SavingsGoalStatus.active));

      // Add remaining to achieve goal
      await savingsGoalRepo.addContribution(goal.id, 15000000);
      final achieved = await savingsGoalRepo.getById(goal.id);
      expect(achieved!.currentAmount, equals(30000000));
      expect(achieved.status, equals(SavingsGoalStatus.achieved));
    });

    test('Savings goal contribution from real account deducts account balance',
        () async {
      final acc = await accountRepo.create(
        name: 'Tabungan Utama',
        type: AccountType.bank,
        initialBalance: 20000000,
      );

      final goal = await savingsGoalRepo.create(
        name: 'Liburan Akhir Tahun',
        targetAmount: 10000000,
        isVirtual: false,
      );

      await savingsGoalRepo.addContribution(
        goal.id,
        3000000,
        sourceAccountId: acc.id,
      );

      final updatedGoal = await savingsGoalRepo.getById(goal.id);
      expect(updatedGoal!.currentAmount, equals(3000000));

      final updatedAcc = await accountRepo.getById(acc.id);
      expect(updatedAcc!.balance, equals(17000000)); // 20M - 3M
    });
  });

  group('Milestone 5 — Purchase Plan Tests', () {
    test('Create purchase plan and complete with real expense', () async {
      final acc = await accountRepo.create(
        name: 'Dompet Operasional',
        type: AccountType.bank,
        initialBalance: 25000000,
      );

      final cat = (await db.select(db.categories).get()).first;

      final plan = await purchasePlanRepo.create(
        name: 'MacBook Air M2',
        targetAmount: 16000000,
        priority: PlanPriority.high,
      );

      expect(plan.status, equals(PlanStatus.active));

      // Add saving allocation
      await purchasePlanRepo.addSaving(plan.id, 6000000);
      var currentPlan = await purchasePlanRepo.getById(plan.id);
      expect(currentPlan!.allocatedAmount, equals(6000000));

      // Complete purchase
      await purchasePlanRepo.completePlan(
        plan.id,
        accountId: acc.id,
        categoryId: cat.id,
        amount: 15800000,
      );

      final completedPlan = await purchasePlanRepo.getById(plan.id);
      expect(completedPlan!.status, equals(PlanStatus.achieved));

      final updatedAcc = await accountRepo.getById(acc.id);
      expect(updatedAcc!.balance, equals(25000000 - 15800000)); // 9,200,000

      final expenseTxns = await (db.select(db.transactions)
            ..where((t) => t.type.equals(TransactionType.expense.index)))
          .get();
      expect(expenseTxns.any((t) => t.amount == 15800000), isTrue);
    });
  });

  group('Milestone 5 — Forecast Read-Only & Sufficiency Tests', () {
    test('Forecast detects insufficient data when transactions < 3', () async {
      final report = await forecastService.generateForecast();
      expect(report.hasSufficientData, isFalse);
      expect(report.warningMessage, isNotNull);
      expect(report.scenarios.containsKey('conservative'), isTrue);
      expect(report.scenarios.containsKey('normal'), isTrue);
      expect(report.scenarios.containsKey('optimistic'), isTrue);
    });

    test('Forecast is strictly read-only and never alters database state',
        () async {
      final acc = await accountRepo.create(
        name: 'Akun Tes Proyeksi',
        type: AccountType.bank,
        initialBalance: 50000000,
      );

      final cat = (await db.select(db.categories).get()).first;

      // Buat transaksi historis bulan lalu
      final lastMonth =
          DateTime(DateTime.now().year, DateTime.now().month - 1, 10);
      for (var i = 1; i <= 4; i++) {
        await db.into(db.transactions).insert(
              TransactionsCompanion(
                uuid: Value('txn-hist-$i'),
                type: Value(i % 2 == 0
                    ? TransactionType.income
                    : TransactionType.expense),
                accountId: Value(acc.id),
                categoryId: Value(cat.id),
                amount: const Value(2000000),
                date: Value(lastMonth),
                isActual: const Value(true),
              ),
            );
      }

      final beforeTxnCount = (await db.select(db.transactions).get()).length;
      final beforeBalance = (await accountRepo.getById(acc.id))!.balance;

      // Jalankan forecast
      final report =
          await forecastService.generateForecast(projectionMonths: 6);

      final afterTxnCount = (await db.select(db.transactions).get()).length;
      final afterBalance = (await accountRepo.getById(acc.id))!.balance;

      expect(afterTxnCount, equals(beforeTxnCount));
      expect(afterBalance, equals(beforeBalance));
      expect(report.currentBalance, equals(beforeBalance));
    });
  });

  group('Milestone 5 — Net Worth & Anti-Double-Counting Rules', () {
    test(
        'Total Assets and Net Worth correctly aggregate without double counting',
        () {
      const cash = 30000000;
      const investments = 15000000;
      const deposits = 25000000;
      const piutang = 5000000;
      const hutang = 10000000;

      final netWorth = NetWorthRules.netWorth(
        totalBalance: cash,
        totalInvestmentValue: investments,
        totalDeposit: deposits,
        totalPiutang: piutang,
        totalHutang: hutang,
      );

      // Net worth = 30M + 15M + 25M + 5M - 10M = 65M
      expect(netWorth, equals(65000000));

      final assets = NetWorthRules.totalAssets(
        totalBalance: cash,
        totalInvestmentValue: investments,
        totalDeposit: deposits,
        totalPiutang: piutang,
      );

      // Total assets = 30M + 15M + 25M + 5M = 75M
      expect(assets, equals(75000000));
    });
  });
}
