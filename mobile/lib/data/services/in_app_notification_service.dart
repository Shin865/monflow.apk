import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/core/formatting/formatters.dart';

/// Model item notifikasi dalam aplikasi
class AppNotificationItem {
  final String id; // Kunci unik deterministik: bill_{billId}_h_{offset}
  final int billId;
  final String title;
  final String message;
  final DateTime scheduledTime;
  final bool isRead;
  final DateTime createdAt;

  const AppNotificationItem({
    required this.id,
    required this.billId,
    required this.title,
    required this.message,
    required this.scheduledTime,
    this.isRead = false,
    required this.createdAt,
  });

  AppNotificationItem copyWith({
    String? id,
    int? billId,
    String? title,
    String? message,
    DateTime? scheduledTime,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotificationItem(
      id: id ?? this.id,
      billId: billId ?? this.billId,
      title: title ?? this.title,
      message: message ?? this.message,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'billId': billId,
        'title': title,
        'message': message,
        'scheduledTime': scheduledTime.toIso8601String(),
        'isRead': isRead,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AppNotificationItem.fromJson(Map<String, dynamic> map) {
    return AppNotificationItem(
      id: map['id'] as String,
      billId: map['billId'] as int,
      title: map['title'] as String,
      message: map['message'] as String,
      scheduledTime: DateTime.parse(map['scheduledTime'] as String),
      isRead: map['isRead'] as bool? ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }
}

/// State notifier pengelola daftar notifikasi dalam aplikasi
class InAppNotificationsNotifier
    extends StateNotifier<List<AppNotificationItem>> {
  final AppDatabase _db;
  static const String _storageKey = 'in_app_notifications_list';
  static const String _reminderSettingKey = 'setting_bill_reminder_enabled';

  InAppNotificationsNotifier(this._db) : super([]) {
    _loadFromSettings();
  }

  Future<void> _loadFromSettings() async {
    try {
      final setting = await (_db.select(_db.settings)
            ..where((s) => s.key.equals(_storageKey)))
          .getSingleOrNull();

      if (setting != null && setting.value != null) {
        final decoded = jsonDecode(setting.value!) as List<dynamic>;
        final items = decoded
            .map((e) => AppNotificationItem.fromJson(e as Map<String, dynamic>))
            .toList();
        // Urutkan terbaru di atas berdasarkan scheduledTime/createdAt
        items.sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
        state = items;
      }
    } catch (e) {
      debugPrint('Error loading in-app notifications: $e');
    }
  }

  Future<void> _persist() async {
    try {
      final jsonStr = jsonEncode(state.map((e) => e.toJson()).toList());
      final existing = await (_db.select(_db.settings)
            ..where((s) => s.key.equals(_storageKey)))
          .getSingleOrNull();

      if (existing == null) {
        await _db.into(_db.settings).insert(
              SettingsCompanion.insert(
                key: _storageKey,
                value: Value(jsonStr),
                description: const Value('Penyimpanan daftar notifikasi lokal'),
              ),
            );
      } else {
        await (_db.update(_db.settings)
              ..where((s) => s.key.equals(_storageKey)))
            .write(
          SettingsCompanion(
            value: Value(jsonStr),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error persisting in-app notifications: $e');
    }
  }

  /// Sinkronkan notifikasi in-app dari daftar tagihan aktif saat ini
  Future<void> syncWithBills(List<Bill> bills) async {
    // Cek apakah pengingat tagihan diaktifkan di pengaturan
    final setting = await (_db.select(_db.settings)
          ..where((s) => s.key.equals(_reminderSettingKey)))
        .getSingleOrNull();
    final isEnabled = setting == null || setting.value != 'false';

    if (!isEnabled) {
      return;
    }

    final now = DateTime.now();
    final currentItems = <String, AppNotificationItem>{
      for (final item in state) item.id: item,
    };

    // Kumpulkan ID tagihan yang masih aktif dan belum lunas
    final activeUnpaidBills =
        bills.where((b) => b.isActive && b.status != BillStatus.paid).toList();
    final activeBillIds = activeUnpaidBills.map((b) => b.id).toSet();

    // Hapus notifikasi dari tagihan yang sudah dihapus/lunas
    currentItems
        .removeWhere((id, item) => !activeBillIds.contains(item.billId));

    // offsets: 7 hari, 3 hari, 1 hari, 0 hari (hari H)
    const offsets = [7, 3, 1, 0];

    for (final bill in activeUnpaidBills) {
      final due = bill.dueDate;
      for (final offset in offsets) {
        final notifId = 'bill_${bill.id}_h_$offset';
        final scheduledDate =
            DateTime(due.year, due.month, due.day - offset, 9, 0);

        // Hanya tampilkan jika scheduledTime sudah tiba/lewat dalam batas wajar
        // tetapi tanggal jatuh tempo belum kadaluarsa lebih dari 30 hari
        if (now.isAfter(scheduledDate)) {
          final existing = currentItems[notifId];

          String title;
          String msg;
          final formattedAmount = formatRupiah(bill.amount);

          if (offset == 0) {
            title = 'Tagihan Jatuh Tempo Hari Ini';
            msg = '${bill.name} sebesar $formattedAmount jatuh tempo hari ini!';
          } else if (offset == 1) {
            title = 'Tagihan Jatuh Tempo Besok';
            msg =
                '${bill.name} sebesar $formattedAmount jatuh tempo besok (${formatDate(bill.dueDate)}).';
          } else {
            title = 'Pengingat Tagihan: ${bill.name}';
            msg =
                'Tagihan ${bill.name} jatuh tempo $offset hari lagi ($formattedAmount).';
          }

          if (existing == null) {
            currentItems[notifId] = AppNotificationItem(
              id: notifId,
              billId: bill.id,
              title: title,
              message: msg,
              scheduledTime: scheduledDate,
              isRead: false,
              createdAt: scheduledDate,
            );
          } else {
            // Perbarui judul/pesan jika nama/nominal tagihan diedit
            currentItems[notifId] = existing.copyWith(
              title: title,
              message: msg,
              scheduledTime: scheduledDate,
            );
          }
        }
      }
    }

    final updatedList = currentItems.values.toList()
      ..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));
    state = updatedList;
    await _persist();
  }

  /// Tandai satu notifikasi telah dibaca
  Future<void> markAsRead(String id) async {
    state = [
      for (final item in state)
        if (item.id == id) item.copyWith(isRead: true) else item,
    ];
    await _persist();
  }

  /// Tandai semua notifikasi telah dibaca
  Future<void> markAllAsRead() async {
    state = [
      for (final item in state) item.copyWith(isRead: true),
    ];
    await _persist();
  }

  /// Hapus satu notifikasi
  Future<void> removeNotification(String id) async {
    state = state.where((item) => item.id != id).toList();
    await _persist();
  }

  /// Hapus seluruh notifikasi
  Future<void> clearAll() async {
    state = [];
    await _persist();
  }

  int get unreadCount => state.where((item) => !item.isRead).length;
}

final inAppNotificationsProvider = StateNotifierProvider<
    InAppNotificationsNotifier, List<AppNotificationItem>>((ref) {
  final db = ref.watch(databaseProvider);
  return InAppNotificationsNotifier(db);
});
