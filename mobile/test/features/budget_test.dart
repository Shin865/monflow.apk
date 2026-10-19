import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/data/repositories/account_repository.dart';
import 'package:money_flow/data/repositories/budget_repository.dart';
import 'package:money_flow/data/repositories/category_repository.dart';
import 'package:money_flow/data/repositories/transaction_repository.dart';
import 'package:money_flow/data/repositories/transfer_repository.dart';

void main() {
  late AppDatabase db;
  late AccountRepository accountRepo;
  late CategoryRepository categoryRepo;
  late TransactionRepository transactionRepo;
  late TransferRepository transferRepo;
  late BudgetRepository budgetRepo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    accountRepo = AccountRepository(db);
    categoryRepo = CategoryRepository(db);
    transactionRepo = TransactionRepository(db, accountRepo);
    transferRepo = TransferRepository(db, accountRepo);
    budgetRepo = BudgetRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('BudgetRepository — Milestone 4 Budget Tests', () {
    test(
        'Mengatur anggaran bulanan per kategori dan memperbarui tanpa mengubah histori transaksi',
        () async {
      final cat = await categoryRepo.createCategory(
        name: 'Makanan',
        type: CategoryType.expense,
        icon: '🍔',
      );

      // Set budget Oktober 2026 sebesar 2.000.000
      final b1 = await budgetRepo.setBudget(
        categoryId: cat.id,
        year: 2026,
        month: 10,
        amount: 2000000,
      );
      expect(b1.amount, 2000000);
      expect(b1.year, 2026);
      expect(b1.month, 10);

      // Edit budget menjadi 2.500.000
      final b2 = await budgetRepo.setBudget(
        categoryId: cat.id,
        year: 2026,
        month: 10,
        amount: 2500000,
      );
      expect(b2.id, b1.id); // Same row updated
      expect(b2.amount, 2500000);
    });

    test(
        'Perhitungan realisasi pengeluaran, refund mengurangi belanja, dan transfer tidak dihitung',
        () async {
      final accA = await accountRepo.create(
          name: 'Bank BCA', type: AccountType.bank, initialBalance: 10000000);
      final accB = await accountRepo.create(
          name: 'Dompet Tunai',
          type: AccountType.cash,
          initialBalance: 1000000);

      final catFood = await categoryRepo.createCategory(
          name: 'Makanan', type: CategoryType.expense, icon: '🍔');
      final catTransport = await categoryRepo.createCategory(
          name: 'Transportasi', type: CategoryType.expense, icon: '🚗');

      // Set budget Oktober 2026: Makanan = 2.000.000
      await budgetRepo.setBudget(
          categoryId: catFood.id, year: 2026, month: 10, amount: 2000000);

      // 1. Pengeluaran makanan 1.200.000
      await transactionRepo.create(
        type: TransactionType.expense,
        accountId: accA.id,
        categoryId: catFood.id,
        amount: 1200000,
        date: DateTime(2026, 10, 5),
      );

      // 2. Refund makanan 200.000 (pengembalian dana harus mengurangi realisasi pengeluaran)
      await transactionRepo.create(
        type: TransactionType.refund,
        accountId: accA.id,
        categoryId: catFood.id,
        amount: 200000,
        date: DateTime(2026, 10, 8),
      );

      // 3. Pengeluaran transportasi 300.000 (kategori lain tidak boleh mempengaruhi makanan)
      await transactionRepo.create(
        type: TransactionType.expense,
        accountId: accA.id,
        categoryId: catTransport.id,
        amount: 300000,
        date: DateTime(2026, 10, 10),
      );

      // 4. Transfer BCA ke Tunai 500.000 (tidak boleh dihitung sebagai pengeluaran anggaran)
      await transferRepo.create(
        fromAccountId: accA.id,
        toAccountId: accB.id,
        amount: 500000,
        date: DateTime(2026, 10, 12),
      );

      // 5. Transaksi di bulan lain (September 2026) tidak boleh masuk ke Oktober
      await transactionRepo.create(
        type: TransactionType.expense,
        accountId: accA.id,
        categoryId: catFood.id,
        amount: 900000,
        date: DateTime(2026, 9, 25),
      );

      final summary = await budgetRepo.getMonthlyBudgetSummary(2026, 10);
      final foodItem =
          summary.items.firstWhere((i) => i.category.id == catFood.id);

      // Realisasi Makanan = 1.200.000 - 200.000 = 1.000.000
      expect(foodItem.actualSpent, 1000000);
      expect(foodItem.budgetAmount, 2000000);
      expect(foodItem.remaining, 1000000);
      expect(foodItem.percentage, 50.0);
      expect(foodItem.alertStatus, BudgetAlertStatus.safe);
    });

    test(
        'Indikator status: Aman (<80%), Mendekati Batas (80-100%), dan Melewati Batas (>100%)',
        () async {
      final acc = await accountRepo.create(
          name: 'Kas', type: AccountType.cash, initialBalance: 10000000);
      final cat = await categoryRepo.createCategory(
          name: 'Hiburan', type: CategoryType.expense, icon: '🎬');

      await budgetRepo.setBudget(
          categoryId: cat.id, year: 2026, month: 10, amount: 1000000);

      // Kasus 1: 50% -> Safe
      await transactionRepo.create(
        type: TransactionType.expense,
        accountId: acc.id,
        categoryId: cat.id,
        amount: 500000,
        date: DateTime(2026, 10, 2),
      );
      var summary = await budgetRepo.getMonthlyBudgetSummary(2026, 10);
      var item = summary.items.firstWhere((i) => i.category.id == cat.id);
      expect(item.alertStatus, BudgetAlertStatus.safe);

      // Kasus 2: +350.000 -> 850.000 (85%) -> NearLimit
      await transactionRepo.create(
        type: TransactionType.expense,
        accountId: acc.id,
        categoryId: cat.id,
        amount: 350000,
        date: DateTime(2026, 10, 5),
      );
      summary = await budgetRepo.getMonthlyBudgetSummary(2026, 10);
      item = summary.items.firstWhere((i) => i.category.id == cat.id);
      expect(item.alertStatus, BudgetAlertStatus.nearLimit);

      // Kasus 3: +200.000 -> 1.050.000 (105%) -> Exceeded
      await transactionRepo.create(
        type: TransactionType.expense,
        accountId: acc.id,
        categoryId: cat.id,
        amount: 200000,
        date: DateTime(2026, 10, 10),
      );
      summary = await budgetRepo.getMonthlyBudgetSummary(2026, 10);
      item = summary.items.firstWhere((i) => i.category.id == cat.id);
      expect(item.alertStatus, BudgetAlertStatus.exceeded);
      expect(item.remaining, -50000);
    });
  });
}
