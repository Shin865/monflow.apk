import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/features/accounts/screens/create_account_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:drift/native.dart';

/// Helper untuk membungkus widget dengan providers dan theme.
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

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.seedDefaultCategories();
    await db.seedDefaultSettings();
  });

  tearDown(() async {
    await db.close();
  });

  group('CreateAccountScreen Widget', () {
    testWidgets('Menampilkan form dengan field yang benar', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(
        const CreateAccountScreen(),
        db,
      ));
      await tester.pumpAndSettle();

      // Cek judul
      expect(find.text('Buat Dompet Baru'), findsOneWidget);

      // Cek field nama
      expect(find.text('Nama Dompet'), findsOneWidget);

      // Cek tipe dompet options
      expect(find.text('Uang Tunai'), findsOneWidget);
      expect(find.text('Rekening Bank'), findsOneWidget);
      expect(find.text('E-Wallet'), findsOneWidget);
      expect(find.text('Tabungan'), findsOneWidget);

      // Cek saldo awal field
      expect(find.text('Saldo Awal (Rp)'), findsOneWidget);

      // Cek tombol submit
      expect(find.text('Simpan Dompet'), findsOneWidget);
    });

    testWidgets('Validasi nama kosong', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(
        const CreateAccountScreen(),
        db,
      ));
      await tester.pumpAndSettle();

      // Tap submit tanpa isi nama
      await tester.ensureVisible(find.text('Simpan Dompet'));
      await tester.tap(find.text('Simpan Dompet'));
      await tester.pumpAndSettle();

      // Pesan error muncul
      expect(find.text('Nama dompet wajib diisi'), findsOneWidget);
    });

    testWidgets('Bisa mengisi nama dan memilih tipe', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp(
        const CreateAccountScreen(),
        db,
      ));
      await tester.pumpAndSettle();

      // Isi nama
      await tester.enterText(
        find.byType(TextFormField).first,
        'BCA Utama',
      );

      // Pilih tipe Bank
      await tester.tap(find.text('Rekening Bank'));
      await tester.pumpAndSettle();

      // Bank harus terpilih (visual check — border berubah)
      // Cek teks masih ada
      expect(find.text('BCA Utama'), findsOneWidget);
    });
  });
}
