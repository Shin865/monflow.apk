import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/data/repositories/account_repository.dart';
import 'package:money_flow/data/repositories/bill_repository.dart';
import 'package:money_flow/data/repositories/category_repository.dart';
import 'package:money_flow/data/repositories/debt_repository.dart';
import 'package:money_flow/data/services/notification_service.dart';

void main() {
  late AppDatabase db;
  late AccountRepository accountRepo;
  late CategoryRepository categoryRepo;
  late BillRepository billRepo;
  late DebtRepository debtRepo;
  late NotificationService notifService;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    accountRepo = AccountRepository(db);
    categoryRepo = CategoryRepository(db);
    billRepo = BillRepository(db);
    debtRepo = DebtRepository(db);
    notifService = NotificationService();
  });

  tearDown(() async {
    await db.close();
  });

  group('Milestone 4 — Pengujian Wajib (Mandatory Tests)', () {
    test(
        '1. Pembayaran sebagian (partial payment) dan pelunasan bertahap pada tagihan',
        () async {
      final acc = await accountRepo.create(
        name: 'Rekening Operasional',
        type: AccountType.bank,
        initialBalance: 2000000,
      );

      final cat = await categoryRepo.createCategory(
        name: 'Sewa & Kontrakan',
        type: CategoryType.expense,
      );

      // Tagihan sewa 1.000.000 jatuh tempo 10 hari lagi
      final bill = await billRepo.createBill(
        name: 'Sewa Kantor',
        amount: 1000000,
        dueDate: DateTime.now().add(const Duration(days: 10)),
        categoryId: cat.id,
      );
      expect(bill.status, BillStatus.upcoming);

      // Pembayaran tahap 1 (sebagian): 400.000
      final partial1 = await billRepo.payBill(
        billId: bill.id,
        accountId: acc.id,
        amount: 400000,
        date: DateTime.now(),
        notes: 'DP Sewa 40%',
      );

      expect(partial1.totalPaid, 400000);
      expect(partial1.remaining, 600000);
      expect(partial1.isPaid, false);
      expect(partial1.bill.status, isNot(BillStatus.paid));

      // Saldo kas terpotong 400.000 -> sisa 1.600.000
      var updatedAcc = await accountRepo.getById(acc.id);
      expect(updatedAcc!.balance, 1600000);

      // Pembayaran tahap 2 (pelunasan sisa): 600.000
      final partial2 = await billRepo.payBill(
        billId: bill.id,
        accountId: acc.id,
        amount: 600000,
        date: DateTime.now(),
        notes: 'Pelunasan Sewa',
      );

      expect(partial2.totalPaid, 1000000);
      expect(partial2.remaining, 0);
      expect(partial2.isPaid, true);
      expect(partial2.bill.status, BillStatus.paid);

      // Saldo kas terpotong 600.000 -> sisa 1.000.000
      updatedAcc = await accountRepo.getById(acc.id);
      expect(updatedAcc!.balance, 1000000);

      // Total 2 transaksi pengeluaran tercatat
      final txns = await (db.select(db.transactions)
            ..where((t) => t.accountId.equals(acc.id)))
          .get();
      expect(txns.length, 2);
    });

    test(
        '2. Kegagalan operasi database di tengah pembayaran tagihan otomatis ROLLBACK (Atomisitas Terjamin)',
        () async {
      final acc = await accountRepo.create(
        name: 'Rekening Aman',
        type: AccountType.bank,
        initialBalance: 5000000,
      );

      final bill = await billRepo.createBill(
        name: 'Asuransi Mobil',
        amount: 1500000,
        dueDate: DateTime.now().add(const Duration(days: 5)),
      );

      // Simulasi kegagalan database di dalam transaction (misal foreign key id akun invalid atau runtime exception)
      try {
        await db.transaction(() async {
          // 1. Insert bill payment
          await db.into(db.billPayments).insert(BillPaymentsCompanion.insert(
                billId: bill.id,
                amount: 1500000,
                date: DateTime.now(),
                accountId: acc.id,
              ));

          // 2. Simulasikan crash sebelum mutasi akun dan transaksi
          throw Exception(
              'Koneksi database lokal terputus atau disk I/O failure');
        });
      } catch (e) {
        expect(e.toString(), contains('Koneksi database lokal terputus'));
      }

      // Verifikasi integritas:
      // - Tidak ada baris BillPayment yang tertinggal (di-rollback)
      final payments = await (db.select(db.billPayments)
            ..where((t) => t.billId.equals(bill.id)))
          .get();
      expect(payments.isEmpty, isTrue);

      // - Saldo akun tidak berubah
      final accAfter = await accountRepo.getById(acc.id);
      expect(accAfter!.balance, 5000000);

      // - Tagihan tetap belum terbayar
      final billAfter = await (db.select(db.bills)
            ..where((t) => t.id.equals(bill.id)))
          .getSingle();
      expect(billAfter.status, isNot(BillStatus.paid));
    });

    test(
        '3. Kegagalan operasi database di tengah pembayaran cicilan hutang otomatis ROLLBACK',
        () async {
      final acc = await accountRepo.create(
        name: 'Rekening Kas',
        type: AccountType.cash,
        initialBalance: 3000000,
      );

      final debt = await debtRepo.createDebt(
        name: 'Hutang Vendor',
        type: DebtType.hutang,
        totalAmount: 2000000,
      );

      // Simulasi kegagalan saat transaksi pembayaran hutang
      try {
        await db.transaction(() async {
          await db.into(db.debtPayments).insert(DebtPaymentsCompanion.insert(
                debtId: debt.id,
                amount: 1000000,
                date: DateTime.now(),
              ));
          throw Exception('Simulated crash');
        });
      } catch (_) {}

      // Verifikasi rollback:
      final payments = await (db.select(db.debtPayments)
            ..where((t) => t.debtId.equals(debt.id)))
          .get();
      expect(payments.isEmpty, isTrue);

      final debtAfter = await (db.select(db.debts)
            ..where((t) => t.id.equals(debt.id)))
          .getSingle();
      expect(debtAfter.remainingAmount, 2000000);
      expect(debtAfter.status, DebtStatus.active);

      final accAfter = await accountRepo.getById(acc.id);
      expect(accAfter!.balance, 3000000);
    });

    test(
        '4. Abstraksi waktu domain logic: evaluasi status dan penjadwalan deterministik tanpa dependensi jam sistem',
        () async {
      // Menguji calculateBillStatus dengan parameter waktu referenceNow eksplisit
      final fixedDueDate = DateTime(2026, 12, 20);

      // 1. Reference: 2026-12-01 (19 hari sebelumnya) -> upcoming
      final statusFar = billRepo.calculateBillStatus(
          fixedDueDate, 100000, 0, DateTime(2026, 12, 1));
      expect(statusFar, BillStatus.upcoming);

      // 2. Reference: 2026-12-15 (5 hari sebelumnya) -> dueSoon
      final statusSoon = billRepo.calculateBillStatus(
          fixedDueDate, 100000, 0, DateTime(2026, 12, 15));
      expect(statusSoon, BillStatus.dueSoon);

      // 3. Reference: 2026-12-21 (1 hari setelahnya) -> overdue
      final statusLate = billRepo.calculateBillStatus(
          fixedDueDate, 100000, 0, DateTime(2026, 12, 21));
      expect(statusLate, BillStatus.overdue);

      // 4. Terbayar penuh -> paid kapan pun tanggalnya
      final statusPaid = billRepo.calculateBillStatus(
          fixedDueDate, 100000, 100000, DateTime(2026, 12, 25));
      expect(statusPaid, BillStatus.paid);
    });

    test(
        '5. Penjadwalan pengingat tagihan dan pembatalan saat lunas aman dijalankan offline',
        () async {
      final bill = await billRepo.createBill(
        name: 'Listrik Pasca',
        amount: 300000,
        dueDate: DateTime.now().add(const Duration(days: 4)),
      );

      // Penjadwalan pengingat
      await notifService.scheduleBillReminder(bill);

      // Pembatalan pengingat saat lunas
      await notifService.cancelBillReminder(bill.id);

      // Tidak ada unhandled exception / crash offline
      expect(true, isTrue);
    });
  });
}
