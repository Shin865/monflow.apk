import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/data/repositories/account_repository.dart';
import 'package:money_flow/data/repositories/debt_repository.dart';

void main() {
  late AppDatabase db;
  late AccountRepository accountRepo;
  late DebtRepository debtRepo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    accountRepo = AccountRepository(db);
    debtRepo = DebtRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('DebtRepository — Milestone 4 Debt & Receivables Tests', () {
    test(
        'Pencatatan hutang & piutang, nilai pokok awal, dan ringkasan agregasi',
        () async {
      // 1. Hutang motor 12.000.000
      await debtRepo.createDebt(
        name: 'Cicilan Motor Beat',
        type: DebtType.hutang,
        totalAmount: 12000000,
        person: 'Leasing FIF',
        tenorMonths: 12,
        installmentAmount: 1000000,
      );

      // 2. Piutang teman 3.000.000
      await debtRepo.createDebt(
        name: 'Pinjaman Modal Budi',
        type: DebtType.piutang,
        totalAmount: 3000000,
        person: 'Budi Santoso',
      );

      final summary = await debtRepo.getDebtSummary();
      expect(summary.totalHutang, 12000000);
      expect(summary.totalPiutang, 3000000);
      expect(summary.net, -9000000); // 3jt - 12jt = -9jt
    });

    test(
        'Pembayaran hutang atomik: pemisahan pokok dan bunga, mutasi akun, dan sisa pokok berkurang',
        () async {
      final acc = await accountRepo.create(
        name: 'Bank Mandiri',
        type: AccountType.bank,
        initialBalance: 5000000,
      );

      final debt = await debtRepo.createDebt(
        name: 'Pinjaman KTA',
        type: DebtType.hutang,
        totalAmount: 4000000,
        accountId: acc.id,
      );

      // Bayar cicilan: Total 1.200.000 (Pokok: 1.000.000, Bunga: 200.000)
      final result = await debtRepo.recordPayment(
        debtId: debt.id,
        amount: 1200000,
        principalAmount: 1000000,
        interestAmount: 200000,
        date: DateTime(2026, 10, 15),
        accountId: acc.id,
        notes: 'Cicilan 1',
      );

      // 1. Sisa pokok berkurang HANYA sebesar alokasi pokok (4.000.000 - 1.000.000 = 3.000.000)
      expect(result.debt.remainingAmount, 3000000);
      expect(result.debt.status, DebtStatus.active);

      // 2. Saldo akun kas berkurang sebesar total nominal pembayaran (5.000.000 - 1.200.000 = 3.800.000)
      final updatedAcc = await accountRepo.getById(acc.id);
      expect(updatedAcc!.balance, 3800000);

      // 3. Pelunasan sisa pokok
      final lunasResult = await debtRepo.recordPayment(
        debtId: debt.id,
        amount: 3000000,
        principalAmount: 3000000,
        date: DateTime(2026, 11, 15),
        accountId: acc.id,
      );
      expect(lunasResult.debt.remainingAmount, 0);
      expect(lunasResult.isPaid, true);
      expect(lunasResult.debt.status, DebtStatus.paid);
    });

    test('Penerimaan piutang menambah saldo kas akun penerima', () async {
      final acc = await accountRepo.create(
        name: 'Dompet Tunai',
        type: AccountType.cash,
        initialBalance: 500000,
      );

      final piutang = await debtRepo.createDebt(
        name: 'Talangan Tiket Andi',
        type: DebtType.piutang,
        totalAmount: 1000000,
      );

      // Andi mencicil bayar 400.000
      await debtRepo.recordPayment(
        debtId: piutang.id,
        amount: 400000,
        date: DateTime(2026, 10, 18),
        accountId: acc.id,
      );

      final detail = await debtRepo.getDebtDetail(piutang.id);
      expect(detail!.debt.remainingAmount, 600000);

      // Saldo kas bertambah (500.000 + 400.000 = 900.000)
      final updatedAcc = await accountRepo.getById(acc.id);
      expect(updatedAcc!.balance, 900000);
    });

    test('Penyusunan jadwal cicilan (installment schedule) berdasarkan tenor',
        () async {
      final debt = await debtRepo.createDebt(
        name: 'Pinjaman Renovasi',
        type: DebtType.hutang,
        totalAmount: 3000000,
        tenorMonths: 3,
        installmentAmount: 1000000,
        dueDate: DateTime(2026, 10, 20),
      );

      var detail = await debtRepo.getDebtDetail(debt.id);
      expect(detail!.schedule.length, 3);
      expect(detail.schedule[0].isPaid, false);
      expect(detail.schedule[1].isPaid, false);
      expect(detail.schedule[2].isPaid, false);

      // Bayar cicilan ke-1
      await debtRepo.recordPayment(
        debtId: debt.id,
        amount: 1000000,
        principalAmount: 1000000,
        date: DateTime(2026, 10, 19),
      );

      detail = await debtRepo.getDebtDetail(debt.id);
      expect(detail!.schedule[0].isPaid, true);
      expect(detail.schedule[1].isPaid, false);
      expect(detail.schedule[2].isPaid, false);
    });
  });
}
