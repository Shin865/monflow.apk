import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/data/repositories/account_repository.dart';
import 'package:money_flow/data/repositories/category_repository.dart';
import 'package:money_flow/data/repositories/transaction_repository.dart';
import 'package:money_flow/data/repositories/transfer_repository.dart';
import 'package:money_flow/domain/rules/net_worth_rules.dart';
import 'package:money_flow/features/dashboard/screens/dashboard_screen.dart';

void main() {
  late AppDatabase db;
  late AccountRepository accountRepo;
  late CategoryRepository categoryRepo;
  late TransactionRepository transactionRepo;
  late TransferRepository transferRepo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    accountRepo = AccountRepository(db);
    categoryRepo = CategoryRepository(db);
    transactionRepo = TransactionRepository(db, accountRepo);
    transferRepo = TransferRepository(db, accountRepo);
  });

  tearDown(() async {
    await db.close();
  });

  group('Dashboard — Agregasi Keuangan & Aturan Domain', () {
    test('Total saldo dan Net Worth hanya menghitung akun aktif', () async {
      await accountRepo.create(
        name: 'Rekening Aktif 1',
        type: AccountType.bank,
        initialBalance: 2000000,
      );
      await accountRepo.create(
        name: 'Rekening Aktif 2',
        type: AccountType.cash,
        initialBalance: 500000,
      );
      final accInactive = await accountRepo.create(
        name: 'Rekening Nonaktif',
        type: AccountType.savings,
        initialBalance: 9000000,
      );
      await accountRepo.update(id: accInactive.id, isActive: false);

      final totalBalance = await accountRepo.getTotalBalance();
      expect(totalBalance, 2500000); // Hanya acc1 + acc2

      final netWorth = NetWorthRules.netWorth(totalBalance: totalBalance);
      expect(netWorth, 2500000);
    });

    test(
        'Transfer netral terhadap saldo total dan TIDAK dihitung sebagai pemasukan atau pengeluaran',
        () async {
      final accA = await accountRepo.create(
          name: 'Akun A', type: AccountType.bank, initialBalance: 1000000);
      final accB = await accountRepo.create(
          name: 'Akun B', type: AccountType.cash, initialBalance: 500000);

      final initialTotal = await accountRepo.getTotalBalance();
      expect(initialTotal, 1500000);

      // Lakukan transfer dari A ke B
      await transferRepo.create(
        fromAccountId: accA.id,
        toAccountId: accB.id,
        amount: 300000,
        date: DateTime(2026, 10, 15),
      );

      // 1. Total saldo akun aktif tetap 1.500.000 (tidak berkurang atau bertambah)
      final afterTransferTotal = await accountRepo.getTotalBalance();
      expect(afterTransferTotal, 1500000);

      // 2. Ringkasan cash flow bulanan (pemasukan & pengeluaran) tetap 0!
      final summary = await transactionRepo.getMonthlySummary(2026, 10);
      expect(summary.income, 0);
      expect(summary.expense, 0);
      expect(summary.netFlow, 0);
    });

    test(
        'Ringkasan arus kas bulanan menghitung income, expense, refund dengan benar',
        () async {
      final acc = await accountRepo.create(
          name: 'Akun', type: AccountType.bank, initialBalance: 1000000);
      final catIncome = await categoryRepo.createCategory(
          name: 'Gaji', type: CategoryType.income);
      final catExpense = await categoryRepo.createCategory(
          name: 'Belanja', type: CategoryType.expense);

      final date = DateTime(2026, 10, 10);

      // Income 5jt
      await transactionRepo.create(
        type: TransactionType.income,
        accountId: acc.id,
        categoryId: catIncome.id,
        amount: 5000000,
        date: date,
      );

      // Expense 1.5jt
      await transactionRepo.create(
        type: TransactionType.expense,
        accountId: acc.id,
        categoryId: catExpense.id,
        amount: 1500000,
        date: date,
      );

      // Refund 200rb
      await transactionRepo.create(
        type: TransactionType.refund,
        accountId: acc.id,
        categoryId: catExpense.id,
        amount: 200000,
        date: date,
      );

      final summary = await transactionRepo.getMonthlySummary(2026, 10);
      expect(summary.income, 5000000);
      expect(summary.expense, 1500000);
      expect(summary.refund, 200000);
      expect(summary.netFlow, 3700000); // 5.000.000 + 200.000 - 1.500.000
    });
  });

  group('DashboardScreen — Widget UI Test', () {
    testWidgets('Menampilkan komponen utama dashboard dengan data lokal',
        (tester) async {
      await accountRepo.create(
        name: 'Dompet Utama',
        type: AccountType.cash,
        initialBalance: 750000,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifikasi judul aplikasi
      expect(find.text('Money Flow'), findsOneWidget);

      // Verifikasi kartu saldo total & net worth
      expect(find.text('Total Saldo Akun Aktif'), findsOneWidget);
      expect(find.text('Kekayaan Bersih (Net Worth)'), findsOneWidget);
      expect(find.text('Rp 750.000'), findsWidgets);

      // Verifikasi aksi cepat
      expect(find.text('Pemasukan'), findsWidgets);
      expect(find.text('Pengeluaran'), findsWidgets);
      expect(find.text('Transfer'), findsOneWidget);
      expect(find.text('Dompet Baru'), findsOneWidget);

      // Verifikasi ringkasan arus kas
      expect(find.text('Ringkasan Arus Kas'), findsOneWidget);
      expect(find.text('Selisih Bersih'), findsOneWidget);

      // Verifikasi dompet terdaftar
      expect(find.text('Dompet Utama'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}
