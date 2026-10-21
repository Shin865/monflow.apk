import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:money_flow/core/database/database.dart';

/// Provider state untuk tema aplikasi (Terang, Gelap, Sistem).
/// Tersimpan secara persisten di database SQLite lokal tabel Settings.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final AppDatabase _db;
  static const _themeKey = 'app_theme_mode';

  ThemeModeNotifier(this._db) : super(ThemeMode.dark) {
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    try {
      final setting = await (_db.select(_db.settings)
            ..where((s) => s.key.equals(_themeKey)))
          .getSingleOrNull();

      if (setting?.value != null) {
        switch (setting!.value) {
          case 'light':
            state = ThemeMode.light;
            break;
          case 'dark':
            state = ThemeMode.dark;
            break;
          case 'system':
            state = ThemeMode.system;
            break;
        }
      }
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final val = mode == ThemeMode.light
          ? 'light'
          : (mode == ThemeMode.dark ? 'dark' : 'system');

      final existing = await (_db.select(_db.settings)
            ..where((s) => s.key.equals(_themeKey)))
          .getSingleOrNull();

      if (existing != null) {
        await (_db.update(_db.settings)..where((s) => s.key.equals(_themeKey)))
            .write(SettingsCompanion(
          value: Value(val),
          updatedAt: Value(DateTime.now()),
        ));
      } else {
        await _db.into(_db.settings).insert(SettingsCompanion.insert(
              key: _themeKey,
              value: Value(val),
              description: const Value('Pengaturan Tema Tampilan Aplikasi'),
            ));
      }
    } catch (_) {}
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final db = ref.watch(databaseProvider);
  return ThemeModeNotifier(db);
});
