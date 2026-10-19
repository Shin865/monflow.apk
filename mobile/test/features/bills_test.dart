import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/data/repositories/account_repository.dart';
import 'package:money_flow/data/repositories/bill_repository.dart';
import 'package:money_flow/data/repositories/category_repository.dart';

void main() {
  late AppDatabase db;
  late AccountRepository accountRepo;
  late CategoryRepository categoryRepo;
  late BillRepository billRepo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    accountRepo = AccountRepository(db);
    categoryRepo = CategoryRepository(db);
    billRepo = BillRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('BillRepository — Milestone 4 Bills & Recurring Bills Tests', () {
    test('Membuat tagihan sekali bayar dan evaluasi status jatuh tempo',
        () async {
      final now = DateTime(2026, 10, 15);

      // 1. Tagihan jatuh tempo 15 hari lagi -> upcoming
      final bill1 = await billRepo.createBill(
        name: 'Internet IndiHome',
        amount: 350000,
        dueDate: DateTime.now().add(const Duration(days: 15)),
      );
      expect(bill1.status, BillStatus.upcoming);

      // 2. Evaluasi status tagihan jatuh tempo dalam 3 hari -> dueSoon
      final statusDueSoon =
          billRepo.calculateBillStatus(DateTime(2026, 10, 18), 350000, 0, now);
      expect(statusDueSoon, BillStatus.dueSoon);

      // 3. Evaluasi status tagihan kemarin -> overdue
      final statusOverdue =
          billRepo.calculateBillStatus(DateTime(2026, 10, 14), 350000, 0, now);
      expect(statusOverdue, BillStatus.overdue);
    });

    test(
        'Pembayaran tagihan secara atomik: saldo terpotong, tercatat BillPayment dan Transaksi Pengeluaran',
        () async {
      final acc = await accountRepo.create(
        name: 'Rekening Operasional',
        type: AccountType.bank,
        initialBalance: 2000000,
      );

      final cat = await categoryRepo.createCategory(
        name: 'Utilitas',
        type: CategoryType.expense,
      );

      final bill = await billRepo.createBill(
        name: 'Listrik PLN',
        amount: 500000,
        dueDate: DateTime(2026, 10, 20),
        categoryId: cat.id,
      );

      // Eksekusi pembayaran penuh
      final result = await billRepo.payBill(
        billId: bill.id,
        accountId: acc.id,
        amount: 500000,
        date: DateTime(2026, 10, 19),
        notes: 'Token listrik 500rb',
      );

      // 1. Tagihan menjadi LUNAS
      expect(result.isPaid, true);
      expect(result.bill.status, BillStatus.paid);
      expect(result.remaining, 0);
      expect(result.totalPaid, 500000);

      // 2. Saldo akun terpotong secara tepat
      final updatedAcc = await accountRepo.getById(acc.id);
      expect(updatedAcc!.balance, 1500000);

      // 3. Transaksi pengeluaran otomatis tercatat
      final transactions = await (db.select(db.transactions)
            ..where((t) => t.accountId.equals(acc.id)))
          .get();
      expect(transactions.length, 1);
      expect(transactions.first.type, TransactionType.expense);
      expect(transactions.first.amount, 500000);
      expect(transactions.first.description, 'Bayar tagihan: Listrik PLN');
      expect(transactions.first.isActual, true);

      // 4. Riwayat BillPayment tersimpan
      final payments = await (db.select(db.billPayments)
            ..where((t) => t.billId.equals(bill.id)))
          .get();
      expect(payments.length, 1);
      expect(payments.first.amount, 500000);
      expect(payments.first.accountId, acc.id);
    });

    test(
        'Lazy recurring bills generator: membentuk instans bulanan, penanganan akhir bulan, dan cegah duplikasi',
        () async {
      // Buat template tagihan rutin bulanan dengan tanggal jatuh tempo 31 (akhir bulan)
      final template = await billRepo.createBill(
        name: 'Iuran Pengurus RT',
        amount: 100000,
        dueDate: DateTime(2026, 1, 31),
        isRecurring: true,
        frequency: BillFrequency.monthly,
      );
      expect(template.dueDay, 31);

      // 1. Eksekusi lazy generator untuk bulan Februari 2026 (hanya 28 hari)
      final febReference = DateTime(2026, 2, 10);
      await billRepo.generateRecurringInstances(febReference);

      final febBills = await (db.select(db.bills)
            ..where((t) => t.parentBillId.equals(template.id)))
          .get();
      expect(febBills.length, 1);
      final febInstance = febBills.first;
      expect(febInstance.recurringKey, 'rec_${template.id}_2026_2');
      // Tanggal 31 di-clamp ke tanggal 28 Februari!
      expect(febInstance.dueDate.day, 28);
      expect(febInstance.dueDate.month, 2);
      expect(febInstance.dueDate.year, 2026);

      // 2. Eksekusi lazy generator sekali lagi pada periode yang sama -> TIDAK DUPLIKAT
      await billRepo.generateRecurringInstances(febReference);
      final countAfterSecondRun = await (db.select(db.bills)
            ..where((t) => t.parentBillId.equals(template.id)))
          .get();
      expect(countAfterSecondRun.length, 1);

      // 3. Eksekusi untuk bulan April 2026 (30 hari)
      final aprReference = DateTime(2026, 4, 15);
      await billRepo.generateRecurringInstances(aprReference);

      final allGenerated = await (db.select(db.bills)
            ..where((t) => t.parentBillId.equals(template.id)))
          .get();
      expect(allGenerated.length, 2);
      final aprInstance = allGenerated
          .firstWhere((b) => b.recurringKey == 'rec_${template.id}_2026_4');
      // Tanggal 31 di-clamp ke tanggal 30 April!
      expect(aprInstance.dueDate.day, 30);
      expect(aprInstance.dueDate.month, 4);
    });
  });
}
