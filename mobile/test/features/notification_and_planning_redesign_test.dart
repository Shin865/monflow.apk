import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_flow/core/database/database.dart';
import 'package:money_flow/data/repositories/bill_repository.dart';
import 'package:money_flow/data/repositories/purchase_plan_repository.dart';
import 'package:money_flow/data/services/in_app_notification_service.dart';
import 'package:money_flow/data/services/notification_service.dart';
import 'package:money_flow/features/dashboard/screens/dashboard_screen.dart';
import 'package:money_flow/features/notifications/screens/notifications_screen.dart';
import 'package:money_flow/features/planning/screens/planning_screen.dart';

void main() {
  late AppDatabase db;
  late BillRepository billRepo;
  late PurchasePlanRepository planRepo;
  late NotificationService notifService;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    notifService = NotificationService();
    billRepo = BillRepository(db, null, notifService);
    planRepo = PurchasePlanRepository(db);

    await db.seedDefaultCategories();
    await db.seedDefaultSettings();
  });

  tearDown(() async {
    await db.close();
  });

  group('Bagian 3 — Rencana Pembelian Tests (Terealisasi vs Belum Terealisasi)',
      () {
    test(
        'Kalkulasi Belum Terealisasi dan Sudah Terealisasi dari Database secara Reaktif',
        () async {
      // 1. Awalnya belum ada rencana
      var summary = await planRepo.watchSummary().first;
      expect(summary.totalActiveTarget, equals(0));
      expect(summary.totalHistoryTarget, equals(0));
      expect(summary.activeCount, equals(0));
      expect(summary.achievedCount, equals(0));

      // 2. Buat akun untuk pendanaan realisasi
      final accountId = await db.into(db.accounts).insert(
            AccountsCompanion.insert(
              name: 'Dompet Utama',
              type: AccountType.bank,
              balance: const Value(50000000),
            ),
          );

      // 3. Tambah Rencana 1: Laptop (Rp 15.000.000)
      final plan1 = await planRepo.create(
        name: 'MacBook Air M2',
        targetAmount: 15000000,
        category: 'Elektronik',
        priority: PlanPriority.high,
      );

      // Tambah Rencana 2: Meja Kerja (Rp 3.500.000)
      await planRepo.create(
        name: 'Standing Desk Ergonomic',
        targetAmount: 3500000,
        category: 'Perabot',
        priority: PlanPriority.medium,
      );

      summary = await planRepo.watchSummary().first;
      expect(summary.totalActiveTarget, equals(18500000));
      expect(summary.totalHistoryTarget, equals(0));
      expect(summary.activeCount, equals(2));
      expect(summary.achievedCount, equals(0));

      // 4. Realisasikan Rencana 1 dengan nominal aktual Rp 14.500.000
      await planRepo.completePlan(
        plan1.id,
        accountId: accountId,
        categoryId: 1,
        amount: 14500000,
      );

      summary = await planRepo.watchSummary().first;
      // Belum Terealisasi hanya menyisakan Rencana 2 (Rp 3.500.000)
      expect(summary.totalActiveTarget, equals(3500000));
      expect(summary.activeCount, equals(1));

      // Sudah Terealisasi mencatat nominal realisasi Rp 14.500.000
      expect(summary.totalHistoryTarget, equals(14500000));
      expect(summary.achievedCount, equals(1));

      // 5. Batalkan Realisasi Rencana 1
      await planRepo.cancelRealization(plan1.id);
      summary = await planRepo.watchSummary().first;
      expect(summary.totalActiveTarget, equals(18500000));
      expect(summary.totalHistoryTarget, equals(0));
      expect(summary.activeCount, equals(2));
      expect(summary.achievedCount, equals(0));
    });
  });

  group('Bagian 2.3 — Logika Pengingat Tagihan & Penjadwalan Tests', () {
    test(
        'Penjadwalan deterministik H-7, H-3, H-1, H-0 dan pembersihan saat lunas/dihapus',
        () async {
      final now = DateTime.now();

      // Buat tagihan jatuh tempo 5 hari ke depan
      final dueDate = now.add(const Duration(days: 5));
      final bill = await billRepo.createBill(
        name: 'Tagihan Listrik PLN',
        amount: 450000,
        dueDate: dueDate,
      );

      // Verifikasi ID deterministik: (billId % 80000) * 10 + offsetIndex
      final idH7 = notifService.getDeterministicNotificationId(bill.id, 7);
      final idH3 = notifService.getDeterministicNotificationId(bill.id, 3);
      final idH1 = notifService.getDeterministicNotificationId(bill.id, 1);
      final idH0 = notifService.getDeterministicNotificationId(bill.id, 0);

      expect(idH7, isNot(equals(idH3)));
      expect(idH3, isNot(equals(idH1)));
      expect(idH1, isNot(equals(idH0)));

      // Sinkronkan ke in-app notifications
      final inAppNotifier = InAppNotificationsNotifier(db);
      await inAppNotifier.syncWithBills([bill]);

      // Karena jatuh tempo 5 hari lagi, H-7 (2 hari yang lalu) sudah terlewat targetnya sehingga entri in-app terbentuk
      final notifications = inAppNotifier.state;
      expect(notifications.any((n) => n.billId == bill.id), isTrue);

      // Pelunasan tagihan
      final accId = await db.into(db.accounts).insert(
            AccountsCompanion.insert(
              name: 'Kas',
              type: AccountType.cash,
              balance: const Value(1000000),
            ),
          );

      await billRepo.payBill(
        billId: bill.id,
        accountId: accId,
        amount: 450000,
        date: now,
      );

      // Setelah lunas, tagihan berstatus paid
      final updatedBill = (await billRepo.getBillDetail(bill.id))!.bill;
      expect(updatedBill.status, equals(BillStatus.paid));

      // Sinkronkan kembali in-app notification: entri tagihan yang sudah lunas harus bersih/dihapus
      await inAppNotifier.syncWithBills([updatedBill]);
      expect(inAppNotifier.state.any((n) => n.billId == bill.id), isFalse);
    });

    test(
        'Layar Notifikasi — Operasi tandai dibaca, tandai semua dibaca, dan hapus',
        () async {
      final inAppNotifier = InAppNotificationsNotifier(db);
      final now = DateTime.now();

      // Tambahkan item notifikasi contoh
      final bill = await billRepo.createBill(
        name: 'Internet Indihome',
        amount: 380000,
        dueDate: now.add(const Duration(days: 2)),
      );

      await inAppNotifier.syncWithBills([bill]);
      expect(inAppNotifier.state.isNotEmpty, isTrue);

      final firstId = inAppNotifier.state.first.id;
      expect(inAppNotifier.state.first.isRead, isFalse);

      // Tandai 1 dibaca
      await inAppNotifier.markAsRead(firstId);
      expect(inAppNotifier.state.firstWhere((n) => n.id == firstId).isRead,
          isTrue);

      // Tandai semua dibaca
      await inAppNotifier.markAllAsRead();
      expect(inAppNotifier.unreadCount, equals(0));

      // Hapus satu notifikasi
      await inAppNotifier.removeNotification(firstId);
      expect(inAppNotifier.state.any((n) => n.id == firstId), isFalse);

      // Hapus semua
      await inAppNotifier.clearAll();
      expect(inAppNotifier.state.isEmpty, isTrue);
    });
  });

  group('Widget UI Verification Tests — Dashboard Grid 2x3 & Planning Screen',
      () {
    testWidgets('Dashboard renders 2x3 grid shortcuts without overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifikasi ikon aplikasi launcher dan nama Money Flow tampil
      expect(find.text('Money Flow'), findsOneWidget);
      expect(find.byTooltip('Notifikasi'), findsOneWidget);

      // Verifikasi keenam pintasan menu pada grid 2x3
      expect(find.text('Dompet Baru'), findsOneWidget);
      expect(find.text('Kategori'), findsOneWidget);
      expect(find.text('Tagihan'), findsOneWidget);
      expect(find.text('Hutang'), findsOneWidget);
      expect(find.text('Investasi'), findsOneWidget);
      expect(find.text('Rencana'), findsOneWidget);

      // Clean unmount to prevent fake timer leaks from drift query streams
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets(
        'PlanningScreen renders Belum Terealisasi and Sudah Terealisasi with textScale 1.3',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(380, 850));

      // Tambahkan data sample
      await planRepo.create(
        name: 'Sepeda Lipat',
        targetAmount: 4000000,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(1.3),
              ),
              child: child!,
            ),
            home: const PlanningScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Total Kebutuhan Belanja Aktif'), findsOneWidget);
      expect(find.text('Belum Terealisasi'), findsOneWidget);
      expect(find.text('Sudah Terealisasi'), findsWidgets);

      // Clean unmount to prevent fake timer leaks
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('NotificationsScreen empty state renders cleanly',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: NotificationsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Notifikasi'), findsOneWidget);
      expect(find.text('Tidak Ada Pemberitahuan'), findsOneWidget);
    });
  });
}
