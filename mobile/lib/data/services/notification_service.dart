import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/core/formatting/formatters.dart';
import 'package:money_flow/data/services/in_app_notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Service pengingat lokal Android untuk tagihan jatuh tempo (H-7, H-3, H-1, H-0).
/// Menggunakan jadwal inexact (tidak-tepat) agar tidak memerlukan izin exact alarm (SCHEDULE_EXACT_ALARM).
class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  final Ref? _ref;
  bool _isInitialized = false;

  NotificationService({FlutterLocalNotificationsPlugin? plugin, Ref? ref})
      : _notificationsPlugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _ref = ref;

  /// Inisialisasi notifikasi lokal dan zona waktu
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();
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

  /// ID deterministik: (billId * 10) + offsetIndex
  /// Memastikan id stabil dan tidak bertabrakan (offset 7->0, 3->1, 1->2, 0->3)
  int getDeterministicNotificationId(int billId, int offsetDays) {
    int subIndex;
    switch (offsetDays) {
      case 7:
        subIndex = 1;
        break;
      case 3:
        subIndex = 2;
        break;
      case 1:
        subIndex = 3;
        break;
      default:
        subIndex = 4;
        break;
    }
    return 100000 + ((billId % 80000) * 10) + subIndex;
  }

  /// Jadwalkan pengingat tagihan pada H-7, H-3, H-1, dan hari H (pukul 09:00 pagi)
  Future<void> scheduleBillReminder(Bill bill) async {
    if (!_isInitialized) await init();

    // Jika tagihan sudah lunas atau nonaktif, batalkan semua pengingat terkait
    if (bill.status == BillStatus.paid || !bill.isActive) {
      await cancelBillReminder(bill.id);
      return;
    }

    try {
      final now = DateTime.now();
      const offsets = [7, 3, 1, 0];
      final due = bill.dueDate;

      for (final offset in offsets) {
        final notifId = getDeterministicNotificationId(bill.id, offset);
        final targetDate =
            DateTime(due.year, due.month, due.day - offset, 9, 0);

        // Lewati pengingat yang waktunya sudah lewat
        if (targetDate.isBefore(now)) {
          continue;
        }

        final scheduledTZ = tz.TZDateTime.from(targetDate, tz.local);

        String title;
        String body;
        final formattedAmount = formatRupiah(bill.amount);

        if (offset == 0) {
          title = 'Tagihan Jatuh Tempo Hari Ini';
          body = '${bill.name} sebesar $formattedAmount jatuh tempo hari ini!';
        } else if (offset == 1) {
          title = 'Tagihan Jatuh Tempo Besok';
          body = '${bill.name} sebesar $formattedAmount jatuh tempo besok.';
        } else {
          title = 'Pengingat Tagihan: ${bill.name}';
          body =
              'Tagihan ${bill.name} sebesar $formattedAmount jatuh tempo $offset hari lagi.';
        }

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
          title,
          body,
          scheduledTZ,
          details,
          androidScheduleMode: AndroidScheduleMode.inexact,
          payload: 'bill_${bill.id}',
        );

        debugPrint(
            'Scheduled reminder #$notifId for bill #${bill.id} (H-$offset) at $scheduledTZ');
      }
    } catch (e) {
      debugPrint('Gagal menjadwalkan notifikasi tagihan #${bill.id}: $e');
    }
  }

  /// Batalkan seluruh pengingat untuk satu tagihan (H-7, H-3, H-1, H-0)
  Future<void> cancelBillReminder(int billId) async {
    try {
      if (!_isInitialized) await init();
      const offsets = [7, 3, 1, 0];
      for (final offset in offsets) {
        final notifId = getDeterministicNotificationId(billId, offset);
        await _notificationsPlugin.cancel(notifId);
      }
      debugPrint('Cancelled all scheduled notifications for bill #$billId');
    } catch (e) {
      debugPrint('Error cancelling notifications for bill #$billId: $e');
    }
  }

  /// Sinkronkan seluruh jadwal notifikasi sistem & notifikasi in-app
  Future<void> syncAllBillReminders(List<Bill> bills) async {
    for (final b in bills) {
      if (b.isActive && b.status != BillStatus.paid) {
        await scheduleBillReminder(b);
      } else {
        await cancelBillReminder(b.id);
      }
    }

    // Sinkronkan juga daftar notifikasi dalam aplikasi jika ref tersedia
    if (_ref != null) {
      await _ref.read(inAppNotificationsProvider.notifier).syncWithBills(bills);
    }
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref: ref);
});
