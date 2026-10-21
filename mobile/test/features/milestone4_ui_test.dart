import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/data/repositories/bill_repository.dart';
import 'package:money_flow/data/repositories/debt_repository.dart';
import 'package:money_flow/features/bills/screens/bills_screen.dart';
import 'package:money_flow/features/debts/screens/debts_screen.dart';

Widget _buildTestApp(Widget child, AppDatabase db) {
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('id', 'ID')],
      locale: const Locale('id', 'ID'),
      home: child,
    ),
  );
}

void main() {
  late AppDatabase db;
  late BillRepository billRepo;
  late DebtRepository debtRepo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    billRepo = BillRepository(db);
    debtRepo = DebtRepository(db);

    await db.seedDefaultCategories();
    await db.seedDefaultSettings();
  });

  tearDown(() async {
    await db.close();
  });

  group('Milestone 4 UI & Widget Tests', () {
    testWidgets(
        'BillsScreen — Menampilkan filter chip, daftar tagihan, dan tombol bayar',
        (tester) async {
      await billRepo.createBill(
        name: 'Tagihan WiFi Indihome',
        amount: 385000,
        dueDate: DateTime.now().add(const Duration(days: 3)),
      );

      await tester.pumpWidget(_buildTestApp(const BillsScreen(), db));
      await tester.pumpAndSettle();

      expect(find.text('Tagihan (Bills)'), findsOneWidget);
      expect(find.text('Belum Lunas'), findsOneWidget);
      expect(find.text('Semua'), findsOneWidget);
      expect(find.text('Terlambat'), findsOneWidget);
      expect(find.text('Tagihan WiFi Indihome'), findsOneWidget);
      expect(find.text('Rp 385.000'), findsOneWidget);
      expect(find.text('Bayar'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets(
        'DebtsScreen — Menampilkan kartu ringkasan, tab Hutang & Piutang, dan daftar',
        (tester) async {
      await debtRepo.createDebt(
        name: 'Pinjaman Renovasi Rumah',
        type: DebtType.hutang,
        totalAmount: 15000000,
        person: 'Bank Mandiri',
      );

      await tester.pumpWidget(_buildTestApp(const DebtsScreen(), db));
      await tester.pumpAndSettle();

      expect(find.text('Hutang & Piutang'), findsOneWidget);
      expect(find.text('Total Hutang Kita'), findsOneWidget);
      expect(find.text('Uang di Orang'), findsOneWidget);
      expect(find.text('Selisih Bersih'), findsOneWidget);
      expect(find.text('Pinjaman Renovasi Rumah'), findsOneWidget);
      expect(find.text('Rp 15.000.000'), findsWidgets);
      expect(find.text('Bayar Cicilan'), findsOneWidget);

      // Tab Piutang
      await tester.tap(find.text('Piutang (Uang di Orang)'));
      await tester.pumpAndSettle();

      expect(find.text('Tidak ada piutang saat ini.'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}
