import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:money_flow/core/formatting/formatters.dart';
import 'package:money_flow/core/theme/app_theme.dart';
import 'package:money_flow/core/widgets/common_widgets.dart';
import 'package:money_flow/data/repositories/bill_repository.dart';
import 'package:money_flow/data/services/in_app_notification_service.dart';
import 'package:money_flow/data/services/notification_service.dart';

/// Layar Notifikasi (In-App Notifications)
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Request permission kontekstual saat layar notifikasi dibuka
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationServiceProvider).requestPermission();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final notifications = ref.watch(inAppNotificationsProvider);
    final notifier = ref.read(inAppNotificationsProvider.notifier);

    return Scaffold(
      backgroundColor: tokens.ground,
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          if (notifications.isNotEmpty)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: tokens.textPrimary),
              onSelected: (val) {
                if (val == 'mark_all_read') {
                  notifier.markAllAsRead();
                } else if (val == 'clear_all') {
                  notifier.clearAll();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'mark_all_read',
                  child: Row(
                    children: [
                      Icon(Icons.done_all_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Tandai semua dibaca'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep_outlined,
                          size: 18, color: tokens.expense),
                      const SizedBox(width: 8),
                      Text('Hapus semua',
                          style: TextStyle(color: tokens.expense)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: notifications.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: MfEmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'Tidak Ada Pemberitahuan',
                  subtitle:
                      'Semua tagihan Anda aman! Pengingat otomatis akan muncul di sini menjelang tanggal jatuh tempo.',
                ),
              ),
            )
          : RefreshIndicator(
              color: tokens.brand,
              onRefresh: () async {
                final bills =
                    await ref.read(billRepositoryProvider).watchBills().first;
                await notifier.syncWithBills(bills);
              },
              child: ListView.separated(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: notifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = notifications[index];
                  return Dismissible(
                    key: Key(item.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: tokens.expense,
                        borderRadius:
                            BorderRadius.circular(tokens.radiusControl),
                      ),
                      child: const Icon(Icons.delete_outline_rounded,
                          color: Colors.white),
                    ),
                    onDismissed: (_) {
                      notifier.removeNotification(item.id);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: item.isRead
                            ? tokens.surface
                            : tokens.brandWash.withOpacity(0.5),
                        borderRadius:
                            BorderRadius.circular(tokens.radiusControl),
                        border: Border.all(
                          color: item.isRead
                              ? tokens.border
                              : tokens.brand.withOpacity(0.4),
                          width: item.isRead ? 1 : 1.2,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: item.isRead
                                ? tokens.surfaceRaised
                                : tokens.brand.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.receipt_long_rounded,
                            size: 18,
                            color: item.isRead
                                ? tokens.textSecondary
                                : tokens.brand,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: item.isRead
                                      ? FontWeight.w600
                                      : FontWeight.w700,
                                  color: tokens.textPrimary,
                                ),
                              ),
                            ),
                            if (!item.isRead) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: tokens.brand,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Text(
                              item.message,
                              style: TextStyle(
                                fontSize: 12,
                                color: tokens.textSecondary,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatDate(item.scheduledTime),
                              style: TextStyle(
                                fontSize: 10,
                                color: tokens.textMuted,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          notifier.markAsRead(item.id);
                          // Buka detail tagihan terkait
                          context.pushNamed('bill_detail', extra: item.billId);
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
