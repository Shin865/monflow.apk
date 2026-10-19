import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/data/repositories/category_repository.dart';
import 'package:money_flow/features/categories/screens/categories_screen.dart';
import 'package:money_flow/features/settings/screens/settings_screen.dart';

void main() {
  late AppDatabase db;
  late CategoryRepository categoryRepo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    categoryRepo = CategoryRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('SettingsScreen — Widget UI Test', () {
    testWidgets(
        'Menampilkan menu pengaturan, master data kategori, dan cadangan',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Pengaturan'), findsOneWidget);
      expect(find.text('Money Flow'), findsOneWidget);
      expect(find.text('Kelola Kategori'), findsOneWidget);
      expect(find.text('Cadangkan Data (JSON)'), findsOneWidget);
      expect(find.text('Pulihkan Data (Restore)'), findsOneWidget);
      expect(find.textContaining('Standalone Offline'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });

  group('CategoriesScreen — Widget UI Test', () {
    testWidgets(
        'Menampilkan tab Pengeluaran dan Pemasukan serta daftar kategori',
        (tester) async {
      await categoryRepo.createCategory(
        name: 'Makan & Minum',
        type: CategoryType.expense,
        icon: '🍔',
      );
      await categoryRepo.createCategory(
        name: 'Gaji Tetap',
        type: CategoryType.income,
        icon: '💼',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: CategoriesScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tab Pengeluaran & Pemasukan
      expect(find.text('Pengeluaran'), findsOneWidget);
      expect(find.text('Pemasukan'), findsOneWidget);

      // Kategori Pengeluaran muncul di tab default (index 0)
      expect(find.text('Makan & Minum'), findsOneWidget);
      expect(find.text('Tambah Kategori'), findsOneWidget);

      // Switch ke tab Pemasukan
      await tester.tap(find.text('Pemasukan'));
      await tester.pumpAndSettle();

      expect(find.text('Gaji Tetap'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}
