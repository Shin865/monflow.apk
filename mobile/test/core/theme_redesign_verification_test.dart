import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/core/theme/app_theme.dart';
import 'package:money_flow/core/theme/theme_provider.dart';
import 'package:money_flow/core/widgets/common_widgets.dart';
import 'package:money_flow/features/settings/screens/settings_screen.dart';

void main() {
  group('Finsave Redesign & Single Theme Verification Tests', () {
    test('Token Warna Semantik Terpisah Jelas', () {
      // Brand Teal vs Income Green harus berbeda jelas
      expect(AppColors.brandTeal, isNot(equals(AppColors.income)));
      expect(AppColors.brandTeal.value, equals(0xFF0F6B5F));
      expect(AppColors.income.value, equals(0xFF16A34A));

      // Expense Red vs Warning Amber vs Transfer Slate
      expect(AppColors.expense.value, equals(0xFFDC2626));
      expect(AppColors.warning.value, equals(0xFFD97706));
      expect(AppColors.transfer.value, equals(0xFF475569));

      // Primary Button Charcoal
      expect(AppColors.primary.value, equals(0xFF18181B));
    });

    testWidgets('MfButton & MfCard Rendering Bergaya Finsave',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: MfCard(
              child: Column(
                children: [
                  const MfSectionHeader(
                      title: 'Transaksi', subtitle: 'Catatan'),
                  MfButton.primary(
                    label: 'Tombol Primer',
                    onPressed: () {},
                  ),
                  const SizedBox(height: 8),
                  MfButton.secondary(
                    label: 'Tombol Sekunder',
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Transaksi'), findsOneWidget);
      expect(find.text('Tombol Primer'), findsOneWidget);
      expect(find.text('Tombol Sekunder'), findsOneWidget);
    });

    testWidgets('MfPill Semantic Labels & Rendering',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Column(
                  children: [
                    MfPill.positive(context, '+ Rp 100.000'),
                    MfPill.negative(context, '- Rp 50.000'),
                    MfPill.warning(context, 'Jatuh Tempo'),
                    MfPill.neutral(context, 'Transfer'),
                  ],
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('+ Rp 100.000'), findsOneWidget);
      expect(find.text('- Rp 50.000'), findsOneWidget);
      expect(find.text('Jatuh Tempo'), findsOneWidget);
      expect(find.text('Transfer'), findsOneWidget);
    });

    testWidgets('Pengaturan TIDAK memiliki opsi tema gelap/terang/otomatis',
        (WidgetTester tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() => db.close());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Memastikan tidak ada opsi pengaturan tema
      expect(find.text('Mode Gelap'), findsNothing);
      expect(find.text('Tema Terang'), findsNothing);
      expect(find.text('Tema Otomatis'), findsNothing);
      expect(find.text('Pilih Tema'), findsNothing);
      expect(find.text('Tema Gelap'), findsNothing);
    });

    testWidgets('Migrasi preferensi tema lama berjalan aman tanpa crash',
        (WidgetTester tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(() => db.close());

      // Simpan dummy preference tema lama
      await db.into(db.settings).insert(
            SettingsCompanion.insert(
              key: 'app_theme_mode',
              value: const Value('dark'),
              updatedAt: Value(DateTime.now()),
            ),
          );

      // Jalankan provider migrasi
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      container.read(themeMigrationProvider);
      await tester.pump(const Duration(milliseconds: 150));

      // Verifikasi record app_theme_mode telah dibersihkan
      final setting = await (db.select(db.settings)
            ..where((s) => s.key.equals('app_theme_mode')))
          .getSingleOrNull();

      expect(setting, isNull);
    });

    testWidgets('Aksesibilitas: textScaleFactor 1.4 tidak menyebabkan overflow',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(1.4),
            ),
            child: Scaffold(
              body: MfCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const MfSectionHeader(
                      title: 'Saldo Tersedia',
                      subtitle: 'Ringkasan Seluruh Dompet',
                    ),
                    const FittedBox(
                      child: Text(
                        'Rp 1.250.000.000',
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: MfButton.primary(
                            label: 'Catat Transaksi',
                            onPressed: () {},
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: MfButton.secondary(
                            label: 'Transfer',
                            onPressed: () {},
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Rp 1.250.000.000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
