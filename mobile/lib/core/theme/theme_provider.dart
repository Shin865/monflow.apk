import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_flow/core/database/database.dart';

/// Service migrasi aman untuk membersihkan preferensi tema lama di SQLite.
/// Money Flow kini sepenuhnya menggunakan Single Light Theme (Finsave).
final themeMigrationProvider = Provider<void>((ref) {
  final db = ref.watch(databaseProvider);
  // Bersihkan record app_theme_mode di database secara aman
  () async {
    try {
      await (db.delete(db.settings)
            ..where((s) => s.key.equals('app_theme_mode')))
          .go();
    } catch (_) {}
  }();
});
