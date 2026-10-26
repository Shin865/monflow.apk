import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/core/formatting/formatters.dart';

/// Notifier untuk preferensi menyembunyikan/menampilkan saldo dan kekayaan (Privacy Mode).
///
/// Preferensi disimpan secara persisten di tabel `settings` SQLite lokal
/// sehingga tetap bertahan saat aplikasi dibuka kembali.
class BalanceVisibilityNotifier extends StateNotifier<bool> {
  final AppDatabase _db;
  static const String _settingKey = 'privacy_hide_balance';

  BalanceVisibilityNotifier(this._db) : super(false) {
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    try {
      final setting = await (_db.select(_db.settings)
            ..where((s) => s.key.equals(_settingKey)))
          .getSingleOrNull();
      if (setting != null) {
        state = setting.value == 'true';
      }
    } catch (_) {}
  }

  /// Toggle tampilkan/sembunyikan saldo
  Future<void> toggle() async {
    final nextState = !state;
    state = nextState;
    try {
      final existing = await (_db.select(_db.settings)
            ..where((s) => s.key.equals(_settingKey)))
          .getSingleOrNull();
      if (existing == null) {
        await _db.into(_db.settings).insert(
              SettingsCompanion.insert(
                key: _settingKey,
                value: Value(nextState ? 'true' : 'false'),
                description:
                    const Value('Preferensi privasi sembunyikan saldo'),
              ),
            );
      } else {
        await (_db.update(_db.settings)
              ..where((s) => s.key.equals(_settingKey)))
            .write(
          SettingsCompanion(
            value: Value(nextState ? 'true' : 'false'),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    } catch (_) {}
  }

  /// Format angka Rupiah atau samarkan dengan placeholder jika mode privasi aktif.
  static String formatOrMask(int amount, {required bool isHidden}) {
    if (isHidden) {
      return 'Rp ••••••';
    }
    return formatRupiah(amount);
  }
}

final balanceVisibilityProvider =
    StateNotifierProvider<BalanceVisibilityNotifier, bool>((ref) {
  final db = ref.watch(databaseProvider);
  return BalanceVisibilityNotifier(db);
});
