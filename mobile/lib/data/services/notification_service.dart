import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Service pengingat lokal Android untuk tagihan jatuh tempo.
/// Menggunakan jadwal inexact (tidak-tepat) agar tidak memerlukan izin exact alarm.
class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  bool _isInitialized = false;

  NotificationService([FlutterLocalNotificationsPlugin? plugin])
      : _notificationsPlugin = plugin ?? FlutterLocalNotificationsPlugin();

  /// Inisialisasi notifikasi lokal dan zona waktu
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();
      // Set default ke Asia/Jakarta jika tersedia, atau fallback ke UTC
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
      } catch (_) {
        tz.setLocalLocation(tz.local);
      }

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification clicked: ${response.payload}');
        },
      );

      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  /// Minta izin notifikasi Android 13+ (POST_NOTIFICATIONS)
  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return false;

    try {
      final androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        final granted =
            await androidImplementation.requestNotificationsPermission();
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('Notification permission error: $e');
    }
    return false;
  }

  /// Buat ID notifikasi stabil berdasarkan ID tagihan
  int _getStableNotificationId(int billId) {
    return 100000 + (billId % 900000);
  }

  /// Jadwalkan pengingat tagihan (H-1 sebelum jatuh tempo pada pukul 09:00 pagi)
  /// Menggunakan jadwal inexact agar hemat daya dan tidak membutuhkan exact alarm permission.
  Future<void> scheduleBillReminder(Bill bill) async {
    if (!_isInitialized) await init();

    // Jika tagihan sudah lunas atau nonaktif, batalkan notifikasinya
    if (bill.status == BillStatus.paid || !bill.isActive) {
      await cancelBillReminder(bill.id);
      return;
    }

    try {
      final notifId = _getStableNotificationId(bill.id);

      // Waktu target: H-1 sebelum jatuh tempo pada jam 09:00 pagi
      final due = bill.dueDate;
      var targetDate = DateTime(due.year, due.month, due.day - 1, 9, 0);

      final now = DateTime.now();
      // Jika H-1 sudah terlewat tetapi jatuh tempo adalah hari ini, ingatkan sekarang/hari ini
      if (targetDate.isBefore(now)) {
        if (DateTime(due.year, due.month, due.day)
            .isAfter(DateTime(now.year, now.month, now.day))) {
          targetDate = now.add(const Duration(minutes: 30));
        } else {
          // Jatuh tempo sudah hari ini atau lewat, tidak perlu jadwal masa depan
          return;
        }
      }

      final scheduledTZ = tz.TZDateTime.from(targetDate, tz.local);

      const androidDetails = AndroidNotificationDetails(
        'bills_reminder_channel',
        'Pengingat Tagihan',
        channelDescription: 'Pengingat jatuh tempo tagihan Money Flow',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const details = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.zonedSchedule(
        notifId,
        'Pengingat Tagihan: ${bill.name}',
        'Tagihan sebesar Rp ${bill.amount} akan jatuh tempo pada ${bill.dueDate.day}/${bill.dueDate.month}/${bill.dueDate.year}.',
        scheduledTZ,
        details,
        androidScheduleMode: AndroidScheduleMode.inexact,
        payload: 'bill_${bill.id}',
      );

      debugPrint('Scheduled reminder for bill #${bill.id} at $scheduledTZ');
    } catch (e) {
      debugPrint('Gagal menjadwalkan notifikasi tagihan #${bill.id}: $e');
    }
  }

  /// Batalkan pengingat tagihan
  Future<void> cancelBillReminder(int billId) async {
    try {
      if (!_isInitialized) await init();
      final notifId = _getStableNotificationId(billId);
      await _notificationsPlugin.cancel(notifId);
      debugPrint('Cancelled notification for bill #$billId');
    } catch (e) {
      debugPrint('Error cancelling notification #$billId: $e');
    }
  }

  /// Sinkronkan dan jadwalkan ulang seluruh notifikasi untuk semua tagihan aktif
  Future<void> syncAllBillReminders(List<Bill> bills) async {
    for (final b in bills) {
      if (b.isActive && b.status != BillStatus.paid) {
        await scheduleBillReminder(b);
      } else {
        await cancelBillReminder(b.id);
      }
    }
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
