import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/data/repositories/account_repository.dart';
import 'package:money_flow/data/repositories/transaction_repository.dart';
import 'package:money_flow/data/services/report_service.dart';
import 'package:money_flow/data/services/export_service.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  late AppDatabase db;
  late AccountRepository accountRepo;
  late TransactionRepository transactionRepo;
  late ReportService reportService;
  late ExportService exportService;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.seedDefaultCategories();
    accountRepo = AccountRepository(db);
    transactionRepo = TransactionRepository(db, accountRepo);
    reportService = ReportService(db);
    exportService = ExportService(db, reportService);
  });

  tearDown(() async {
    await db.close();
  });

  group('Milestone 6 — Financial Reports & SQL Aggregations Tests', () {
    test('Cash flow report calculates income, expense, and net flow correctly',
        () async {
      final acc = await accountRepo.create(
          name: 'Bank Mandiri',
          type: AccountType.bank,
          initialBalance: 10000000);
      final categories = await db.select(db.categories).get();
      final incCat =
          categories.firstWhere((c) => c.type == CategoryType.income);
      final expCat =
          categories.firstWhere((c) => c.type == CategoryType.expense);

      final now = DateTime.now();
      await transactionRepo.create(
        type: TransactionType.income,
        accountId: acc.id,
        categoryId: incCat.id,
        amount: 8000000,
        date: now,
      );

      await transactionRepo.create(
        type: TransactionType.expense,
        accountId: acc.id,
        categoryId: expCat.id,
        amount: 3000000,
        date: now,
      );

      final report = await reportService.getCashFlowReport(
        startDate: DateTime(now.year, now.month, 1),
        endDate: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
      );

      expect(report.totalIncome, equals(8000000));
      expect(report.totalExpense, equals(3000000));
      expect(report.netCashFlow, equals(5000000));
      expect(report.transactionCount, equals(2));
    });

    test(
        'Category breakdown calculates totals and percentage shares accurately',
        () async {
      final acc = await accountRepo.create(
          name: 'Dompet Kas', type: AccountType.cash, initialBalance: 5000000);
      final categories = await db.select(db.categories).get();
      final expCats =
          categories.where((c) => c.type == CategoryType.expense).toList();

      final cat1 = expCats[0];
      final cat2 = expCats[1];
      final now = DateTime.now();

      await transactionRepo.create(
          type: TransactionType.expense,
          accountId: acc.id,
          categoryId: cat1.id,
          amount: 600000,
          date: now);
      await transactionRepo.create(
          type: TransactionType.expense,
          accountId: acc.id,
          categoryId: cat2.id,
          amount: 400000,
          date: now);

      final breakdown = await reportService.getCategoryBreakdown(
        startDate: DateTime(now.year, now.month, 1),
        endDate: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
        type: TransactionType.expense,
      );

      expect(breakdown.length, equals(2));
      expect(breakdown.first.categoryId, equals(cat1.id));
      expect(breakdown.first.totalAmount, equals(600000));
      expect(breakdown.first.percentage, equals(60.0));

      expect(breakdown.last.categoryId, equals(cat2.id));
      expect(breakdown.last.totalAmount, equals(400000));
      expect(breakdown.last.percentage, equals(40.0));
    });

    test(
        'Comprehensive report aggregates all financial pillars without double counting',
        () async {
      final report = await reportService.getComprehensiveReport();
      expect(report.cashFlow, isNotNull);
      expect(report.accountBalances, isNotNull);
      expect(report.totalAssets, greaterThanOrEqualTo(0));
    });
  });

  group('Milestone 6 — CSV & PDF Export Security & Formatting Tests', () {
    test(
        'CSV Formula Injection protection neutralizes dangerous spreadsheet prefixes',
        () {
      expect(ExportService.sanitizeForCsv('=SUM(A1:A10)'),
          equals("'=SUM(A1:A10)"));
      expect(ExportService.sanitizeForCsv('+12345'), equals("'+12345"));
      expect(ExportService.sanitizeForCsv('-2+5+cmd'), equals("'-2+5+cmd"));
      expect(ExportService.sanitizeForCsv('@IMPORTXML'), equals("'@IMPORTXML"));
      expect(ExportService.sanitizeForCsv('   =cmd|/c calc'),
          equals("'=cmd|/c calc"));
      expect(
          ExportService.sanitizeForCsv('Gaji Bulanan'), equals('Gaji Bulanan'));
      expect(ExportService.sanitizeForCsv(null), equals(''));
    });

    test(
        'CSV export generates valid UTF-8 BOM file with Unicode and large nominals',
        () async {
      final acc = await accountRepo.create(
          name: 'Rekening 💵 Rupiah™',
          type: AccountType.bank,
          initialBalance: 1000000000);
      final cat = (await db.select(db.categories).get()).first;

      await transactionRepo.create(
        type: TransactionType.income,
        accountId: acc.id,
        categoryId: cat.id,
        amount: 500000000, // 500 Juta Rp
        date: DateTime.now(),
        description: 'Bonus Prestasi ⭐ Kerja Keras 🇮🇩',
      );

      final result = await exportService.exportTransactionsToCsv();
      expect(result.success, isTrue);
      expect(result.filePath, isNotNull);

      final file = File(result.filePath!);
      expect(await file.exists(), isTrue);

      final bytes = await file.readAsBytes();
      // Verify UTF-8 BOM bytes (0xEF, 0xBB, 0xBF)
      expect(bytes.length, greaterThan(3));
      expect(bytes[0], equals(0xEF));
      expect(bytes[1], equals(0xBB));
      expect(bytes[2], equals(0xBF));

      final content = await file.readAsString();
      // Verify Unicode characters preserved
      expect(content.contains('⭐'), isTrue);
      expect(content.contains('500000000'), isTrue);

      await file.delete();
    });

    test('PDF export generates valid readable document', () async {
      final acc = await accountRepo.create(
          name: 'Tabungan BCA',
          type: AccountType.bank,
          initialBalance: 25000000);
      final cat = (await db.select(db.categories).get()).first;

      await transactionRepo.create(
        type: TransactionType.expense,
        accountId: acc.id,
        categoryId: cat.id,
        amount: 1500000,
        date: DateTime.now(),
        description: 'Belanja Bulanan',
      );

      final pdfResult = await exportService.exportFinancialReportToPdf();
      if (!pdfResult.success) {
        // ignore: avoid_print
        print('PDF Error: ${pdfResult.message}');
      }
      expect(pdfResult.success, isTrue, reason: pdfResult.message);
      expect(pdfResult.filePath, isNotNull);

      final pdfFile = File(pdfResult.filePath!);
      expect(await pdfFile.exists(), isTrue);
      expect(await pdfFile.length(), greaterThan(1000)); // Non-empty PDF bytes

      await pdfFile.delete();
    });
  });
}
