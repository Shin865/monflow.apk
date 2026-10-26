import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/data/repositories/account_repository.dart';
import 'package:money_flow/features/transactions/screens/create_transaction_screen.dart';

/// Helper untuk membungkus widget dengan ProviderScope dan konfigurasi locale Indonesia.
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
  late AccountRepository accountRepo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    accountRepo = AccountRepository(db);

    await db.seedDefaultCategories();
    await db.seedDefaultSettings();

    // Buat akun awal untuk pengujian
    await accountRepo.create(
      name: 'BCA Utama',
      type: AccountType.bank,
      initialBalance: 1000000,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('CreateTransactionScreen Widget', () {
    testWidgets('Menampilkan form catat transaksi dengan lengkap',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(
        const CreateTransactionScreen(),
        db,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Catat Transaksi'), findsOneWidget);
      expect(find.text('Pengeluaran'), findsOneWidget);
      expect(find.text('Pemasukan'), findsOneWidget);
      expect(find.text('Refund'), findsOneWidget);
      expect(find.text('Jumlah (Rp)'), findsOneWidget);
      expect(find.text('Dompet'), findsOneWidget);
      expect(find.text('BCA Utama'), findsOneWidget);
      expect(find.text('Kategori'), findsOneWidget);
    });

    testWidgets('Validasi jumlah kosong saat simpan', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(
        const CreateTransactionScreen(),
        db,
      ));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Simpan Pengeluaran'));
      await tester.tap(find.text('Simpan Pengeluaran'));
      await tester.pumpAndSettle();

      expect(find.text('Jumlah wajib diisi'), findsOneWidget);
    });

    testWidgets('Bisa memilih Pemasukan dan mengisi jumlah', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(
        const CreateTransactionScreen(),
        db,
      ));
      await tester.pumpAndSettle();

      // Pilih Pemasukan
      await tester.tap(find.text('Pemasukan'));
      await tester.pumpAndSettle();

      // Tombol submit berubah menjadi Simpan Pemasukan
      await tester.ensureVisible(find.text('Simpan Pemasukan'));
      expect(find.text('Simpan Pemasukan'), findsOneWidget);

      // Kategori income (Gaji) harus tampil
      expect(find.text('Gaji'), findsOneWidget);

      // Isi nominal pemasukan 2.500.000
      final amountField = find.byType(TextFormField).first;
      await tester.enterText(amountField, '2500000');
      await tester.pumpAndSettle();

      expect(find.text('2.500.000'), findsOneWidget);
    });
  });
}
