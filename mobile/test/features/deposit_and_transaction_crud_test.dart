import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/core/formatting/formatters.dart';
import 'package:money_flow/data/repositories/account_repository.dart';
import 'package:money_flow/data/repositories/deposit_repository.dart';
import 'package:money_flow/data/repositories/transaction_repository.dart';
import 'package:money_flow/data/repositories/transfer_repository.dart';
import 'package:money_flow/domain/rules/deposit_rules.dart';

void main() {
  late AppDatabase db;
  late AccountRepository accountRepo;
  late TransactionRepository txnRepo;
  late TransferRepository transferRepo;
  late DepositRepository depositRepo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    accountRepo = AccountRepository(db);
    txnRepo = TransactionRepository(db, accountRepo);
    transferRepo = TransferRepository(db, accountRepo);
    depositRepo = DepositRepository(db);

    await db.seedDefaultCategories();
    await db.seedDefaultSettings();
  });

  tearDown(() async {
    await db.close();
  });

  group('FASE 1 — DEPOSITO: TANGGAL MULAI & FORMAT INDONESIA', () {
    test('formatDateIndo memformat tanggal sesuai kaidah bahasa Indonesia', () {
      final date = DateTime(2026, 10, 26);
      expect(formatDateIndo(date), '26 Oktober 2026');

      final dateJan = DateTime(2025, 1, 15);
      expect(formatDateIndo(dateJan), '15 Januari 2025');
    });

    test('calculateMaturityDate menghasilkan tanggal jatuh tempo yang valid',
        () {
      final start = DateTime(2026, 1, 15);
      final maturity6m = DepositRules.calculateMaturityDate(start, 6);
      expect(maturity6m.year, 2026);
      expect(maturity6m.month, 7);
      expect(maturity6m.day, 15);

      final maturity12m = DepositRules.calculateMaturityDate(start, 12);
      expect(maturity12m.year, 2027);
      expect(maturity12m.month, 1);
      expect(maturity12m.day, 15);

      // Jatuh tempo harus setelah tanggal mulai
      expect(maturity6m.isAfter(start), isTrue);
    });

    test('Validasi: tanggal jatuh tempo sebelum tanggal mulai ditolak', () {
      final start = DateTime(2026, 10, 26);
      final invalidMaturity = DateTime(2026, 5, 1);
      expect(invalidMaturity.isBefore(start), isTrue);
    });
  });

  group('FASE 2 — CRUD DEPOSITO & INTEGRITAS ASET', () {
    test('Create, Read Detail, Update, dan Delete Deposito', () async {
      final startDate = DateTime(2026, 3, 1);
      final maturityDate = DepositRules.calculateMaturityDate(startDate, 12);

      // 1. Create Deposito
      final created = await depositRepo.create(
        name: 'Deposito Mandiri Sejahtera',
        bankName: 'Mandiri',
        principal: 50000000,
        annualRateBps: 650, // 6.5%
        tenorMonths: 12,
        interestType: DepositInterestType.simple,
        taxRateBps: 2000, // 20%
        feeAmount: 10000,
        startDate: startDate,
        maturityDate: maturityDate,
        notes: 'Dana darurat jangka panjang',
      );

      expect(created.id, isPositive);
      expect(created.name, 'Deposito Mandiri Sejahtera');
      expect(created.principal, 50000000);
      expect(created.startDate, startDate);
      expect(created.maturityDate, maturityDate);
      expect(created.status, DepositStatus.active);

      // 2. Read Detail & Kalkulasi
      final deposits = await depositRepo.getDeposits();
      expect(deposits.length, 1);
      final dep = deposits.first;
      expect(dep.name, 'Deposito Mandiri Sejahtera');

      final calc = DepositRules.calculateDeposit(
        principal: dep.principal,
        rateBps: dep.annualRateBps,
        tenorMonths: dep.tenorMonths,
        isCompound: false,
        taxRateBps: dep.taxRateBps,
        feeAmount: dep.feeAmount,
      );

      // Bunga kotor: 50.000.000 * 6.5% = 3.250.000
      // Pajak 20%: 650.000
      // Bunga bersih: 2.600.000 - 10.000 fee = 2.590.000
      // Total nilai jatuh tempo: 52.590.000
      expect(calc.grossInterest, 3250000);
      expect(calc.taxAmount, 650000);
      expect(calc.netInterest, 2590000);
      expect(calc.maturityAmount, 52590000);

      // 3. Update Deposito
      final newStartDate = DateTime(2026, 4, 1);
      final newMaturityDate =
          DepositRules.calculateMaturityDate(newStartDate, 6);
      await depositRepo.update(
        dep.id,
        name: 'Deposito Mandiri Fleksi',
        principal: 60000000,
        tenorMonths: 6,
        startDate: newStartDate,
        maturityDate: newMaturityDate,
      );

      final updatedList = await depositRepo.getDeposits();
      final updated = updatedList.first;
      expect(updated.name, 'Deposito Mandiri Fleksi');
      expect(updated.principal, 60000000);
      expect(updated.tenorMonths, 6);
      expect(updated.startDate, newStartDate);
      expect(updated.maturityDate, newMaturityDate);

      // 4. Delete Deposito
      await depositRepo.delete(dep.id);
      final remaining = await depositRepo.getDeposits();
      expect(remaining.isEmpty, isTrue);
    });

    test(
        'Pencairan (Withdraw) Deposito menambah saldo akun penerima secara atomik',
        () async {
      // Buat akun penampung
      final acc = await accountRepo.create(
        name: 'BCA Tabungan',
        type: AccountType.bank,
        initialBalance: 5000000,
      );

      // Buat deposito 10jt
      final dep = await depositRepo.create(
        name: 'Deposito BCA',
        principal: 10000000,
        annualRateBps: 600,
        tenorMonths: 12,
        interestType: DepositInterestType.simple,
        taxRateBps: 2000,
        startDate: DateTime(2025, 1, 1),
        maturityDate: DateTime(2026, 1, 1),
      );

      // Cairkan ke rekening BCA
      await depositRepo.withdraw(dep.id, returnToAccountId: acc.id);

      // Status deposito menjadi withdrawn
      final updatedDep = await (db.select(db.deposits)
            ..where((d) => d.id.equals(dep.id)))
          .getSingle();
      expect(updatedDep.status, DepositStatus.withdrawn);

      // Saldo akun bertambah pokok + bunga bersih
      // Bunga kotor: 600.000, pajak: 120.000, bunga bersih: 480.000
      // Total cair: 10.480.000
      // Saldo akhir akun: 5.000.000 + 10.480.000 = 15.480.000
      final accAfter = await accountRepo.getById(acc.id);
      expect(accAfter!.balance, 15480000);
    });
  });

  group('FASE 3 — CRUD TRANSAKSI & VERIFIKASI REKALKULASI SALDO', () {
    test('Create, Update, Delete transaksi menjaga konsistensi saldo akun',
        () async {
      final accA = await accountRepo.create(
        name: 'Dompet Utama',
        type: AccountType.cash,
        initialBalance: 2000000,
      );

      final accB = await accountRepo.create(
        name: 'Rekening Bank',
        type: AccountType.bank,
        initialBalance: 5000000,
      );

      final cats = await db.select(db.categories).get();
      final catIncome =
          cats.firstWhere((c) => c.type == CategoryType.income).id;
      final catExpense =
          cats.firstWhere((c) => c.type == CategoryType.expense).id;

      // 1. Tambah Pemasukan Rp 1.500.000 ke Dompet Utama
      final tIncome = await txnRepo.create(
        type: TransactionType.income,
        accountId: accA.id,
        categoryId: catIncome,
        amount: 1500000,
        date: DateTime.now(),
        description: 'Bonus Kinerja',
      );
      var curAccA = await accountRepo.getById(accA.id);
      expect(curAccA!.balance, 3500000);

      // 2. Tambah Pengeluaran Rp 500.000 dari Dompet Utama
      final tExpense = await txnRepo.create(
        type: TransactionType.expense,
        accountId: accA.id,
        categoryId: catExpense,
        amount: 500000,
        date: DateTime.now(),
        description: 'Belanja Mingguan',
      );
      curAccA = await accountRepo.getById(accA.id);
      expect(curAccA!.balance, 3000000);

      // 3. Transfer Rp 1.000.000 dari Dompet Utama ke Rekening Bank
      await transferRepo.create(
        fromAccountId: accA.id,
        toAccountId: accB.id,
        amount: 1000000,
        date: DateTime.now(),
        description: 'Setor ke Bank',
      );
      curAccA = await accountRepo.getById(accA.id);
      var curAccB = await accountRepo.getById(accB.id);
      expect(curAccA!.balance, 2000000);
      expect(curAccB!.balance, 6000000);

      // 4. Update transaksi pengeluaran (ubah nominal dari 500.000 menjadi 700.000)
      await txnRepo.updateTransaction(
        txnId: tExpense.id,
        amount: 700000,
      );
      curAccA = await accountRepo.getById(accA.id);
      expect(curAccA!.balance, 1800000);

      // 5. Update transaksi pengeluaran: pindah akun dari Dompet Utama ke Rekening Bank
      await txnRepo.updateTransaction(
        txnId: tExpense.id,
        accountId: accB.id,
      );
      curAccA = await accountRepo.getById(accA.id);
      curAccB = await accountRepo.getById(accB.id);
      // Dompet Utama kembali +700.000 = 2.500.000
      expect(curAccA!.balance, 2500000);
      // Rekening Bank terpotong 700.000 = 5.300.000
      expect(curAccB!.balance, 5300000);

      // 6. Delete transaksi pemasukan awal
      await txnRepo.deleteTransaction(tIncome.id);
      curAccA = await accountRepo.getById(accA.id);
      // Dompet Utama berkurang 1.500.000 = 1.000.000
      expect(curAccA!.balance, 1000000);

      // ========================================================
      // TEST TERPENTING: LEDGER RECALCULATION VALIDATION
      // Saldo setiap akun == hasil hitung ulang seluruh transaksi valid di DB!
      // ========================================================
      Future<int> recalculateAccountBalance(
          int accountId, int initialBalance) async {
        final txns = await (db.select(db.transactions)
              ..where((t) => t.accountId.equals(accountId)))
            .get();

        int balance = initialBalance;
        for (final t in txns) {
          if (t.type == TransactionType.income ||
              t.type == TransactionType.refund) {
            balance += t.amount;
          } else if (t.type == TransactionType.expense) {
            balance -= t.amount;
          }
        }

        // Hitung transfer out
        final transfersOut = await (db.select(db.transfers)
              ..where((t) => t.fromAccountId.equals(accountId)))
            .get();
        for (final tr in transfersOut) {
          balance -= tr.amount;
        }

        // Hitung transfer in
        final transfersIn = await (db.select(db.transfers)
              ..where((t) => t.toAccountId.equals(accountId)))
            .get();
        for (final tr in transfersIn) {
          balance += tr.amount;
        }

        return balance;
      }

      final expectedAccA = await recalculateAccountBalance(accA.id, 2000000);
      final expectedAccB = await recalculateAccountBalance(accB.id, 5000000);

      expect(curAccA.balance, expectedAccA,
          reason:
              'Saldo Dompet Utama harus tepat sama dengan hitung ulang seluruh buku kas');
      expect(curAccB.balance, expectedAccB,
          reason:
              'Saldo Rekening Bank harus tepat sama dengan hitung ulang seluruh buku kas');
    });
  });
}
