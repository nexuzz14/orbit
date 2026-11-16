import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/bill_notification_service.dart';
import 'package:orbit_app/core/services/notification_scheduler_service.dart';
import 'package:orbit_app/core/services/notification_service.dart';
import 'package:orbit_app/features/settings/notification_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

class FakeRecordedNotification {
  final int id;
  final String title;
  final String body;
  final String channelId;
  final String? payload;
  final tz.TZDateTime? scheduledDate;
  final DateTimeComponents? repeatComponents;

  const FakeRecordedNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.channelId,
    this.payload,
    this.scheduledDate,
    this.repeatComponents,
  });
}

class FakeNotificationAdapter implements NotificationAdapter {
  bool initialized = false;
  bool permissionResult = true;
  bool enabledResult = true;
  int cancelAllCount = 0;
  String? launchPayload;
  void Function(String? payload)? _onTap;

  final List<FakeRecordedNotification> shown = [];
  final List<FakeRecordedNotification> scheduled = [];

  void simulateTap(String? payload) {
    _onTap?.call(payload);
  }

  @override
  Future<void> initialize({required void Function(String? payload) onTap}) async {
    initialized = true;
    _onTap = onTap;
  }

  @override
  Future<bool?> requestPermission() async => permissionResult;

  @override
  Future<bool?> areNotificationsEnabled() async => enabledResult;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required String channelDescription,
    String? payload,
  }) async {
    shown.add(
      FakeRecordedNotification(
        id: id,
        title: title,
        body: body,
        channelId: channelId,
        payload: payload,
      ),
    );
  }

  @override
  Future<void> zonedSchedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required String channelId,
    required String channelName,
    required String channelDescription,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    scheduled.add(
      FakeRecordedNotification(
        id: id,
        title: title,
        body: body,
        channelId: channelId,
        payload: payload,
        scheduledDate: scheduledDate,
        repeatComponents: matchDateTimeComponents,
      ),
    );
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCount++;
    scheduled.clear();
  }

  @override
  Future<void> cancel(int id) async {
    scheduled.removeWhere((e) => e.id == id);
  }

  @override
  Future<List<PendingNotificationRequest>> pendingRequests() async {
    return scheduled
        .map(
          (e) => PendingNotificationRequest(
            e.id,
            e.title,
            e.body,
            e.payload,
          ),
        )
        .toList();
  }

  @override
  Future<String?> getLaunchPayload() async => launchPayload;
}

void main() {
  late FakeNotificationAdapter fakeAdapter;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakeAdapter = FakeNotificationAdapter();
    NotificationService.overrideAdapterForTesting(fakeAdapter);
    await NotificationService.initialize();
  });

  tearDown(() {
    NotificationService.overrideAdapterForTesting(null);
  });

  test('NotificationPayload encode & decode roundtrip + malformed fallback', () {
    const payload = NotificationPayload(
      type: 'task',
      targetTab: 1,
      agendaMode: 'tugas',
      itemId: 'task-42',
    );
    final decoded = NotificationPayload.tryDecode(payload.encode());
    expect(decoded, isNotNull);
    expect(decoded!.type, 'task');
    expect(decoded.targetTab, 1);
    expect(decoded.agendaMode, 'tugas');
    expect(decoded.itemId, 'task-42');

    expect(NotificationPayload.tryDecode(null), isNull);
    expect(NotificationPayload.tryDecode('not-json'), isNull);
  });

  test('Permission request and tap deep-link routing stream', () async {
    expect(fakeAdapter.initialized, isTrue);

    fakeAdapter.permissionResult = true;
    expect(await NotificationService.requestPermission(), isTrue);

    fakeAdapter.permissionResult = false;
    expect(await NotificationService.requestPermission(), isFalse);

    final events = <NotificationPayload>[];
    final sub = NotificationService.onNotificationTap.listen(events.add);

    const expected = NotificationPayload(
      type: 'bill',
      targetTab: 2,
      uangSection: 'tagihan',
      itemId: 'bill-1',
    );
    fakeAdapter.simulateTap(expected.encode());
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(events.length, 1);
    expect(events.first.targetTab, 2);
    expect(events.first.uangSection, 'tagihan');

    final consumed = NotificationService.consumePendingPayload();
    expect(consumed?.itemId, 'bill-1');
    expect(NotificationService.consumePendingPayload(), isNull);

    await sub.cancel();
  });

  test('Cold-start launch payload is captured on initialize', () async {
    final coldAdapter = FakeNotificationAdapter()
      ..launchPayload = const NotificationPayload(
        type: 'event',
        targetTab: 1,
        agendaMode: 'jadwal',
        itemId: 'evt-99',
      ).encode();

    NotificationService.overrideAdapterForTesting(coldAdapter);
    await NotificationService.initialize();

    final pending = NotificationService.consumePendingPayload();
    expect(pending, isNotNull);
    expect(pending!.targetTab, 1);
    expect(pending.agendaMode, 'jadwal');
    expect(pending.itemId, 'evt-99');
  });

  test('BillNotificationService redacts nominal & bill names when showDetails=false', () async {
    await BillNotificationService.showBillDueNotification(
      id: 501,
      billName: 'Sewa Kos',
      amount: 1750000,
      daysLeft: 3,
    );

    expect(fakeAdapter.shown.length, 1);
    final hidden = fakeAdapter.shown.last;
    expect(hidden.channelId, NotificationService.channelBillId);
    expect(hidden.body.contains('1.750.000'), isFalse);
    expect(hidden.body.contains('Sewa Kos'), isFalse);

    await BillNotificationService.showBillDueNotification(
      id: 502,
      billName: 'Sewa Kos',
      amount: 1750000,
      daysLeft: 0,
      showDetails: true,
    );

    final visible = fakeAdapter.shown.last;
    expect(visible.body.contains('Sewa Kos'), isTrue);
    expect(visible.body.contains('1.750.000'), isTrue);
  });

  test('NotificationSchedulerService evaluates WIB morning summary, events, tasks, bills, and budgets', () {
    // 2026-11-15 05:00 WIB = 2026-11-14 22:00 UTC
    final nowUtc = DateTime.utc(2026, 11, 14, 22, 0);

    final events = [
      LocalEvent(
        id: 'evt-1',
        workspaceId: 'ws-1',
        projectId: null,
        kind: 'kuliah',
        title: 'Basis Data Lanjut',
        description: null,
        location: 'Ruang 302',
        startsAt: DateTime.utc(2026, 11, 15, 2, 0), // 09:00 WIB
        endsAt: DateTime.utc(2026, 11, 15, 4, 0), // 11:00 WIB
        allDay: false,
        timezone: 'Asia/Jakarta',
        recurrence: null,
        deletedAt: null,
      ),
    ];

    final tasks = [
      LocalTask(
        id: 'task-1',
        workspaceId: 'ws-1',
        projectId: null,
        kind: 'freelance',
        title: 'Kirim Invoice Rahasia',
        description: null,
        status: 'doing',
        priority: 'tinggi',
        dueAt: DateTime.utc(2026, 11, 16, 10, 0), // 16 Nov 17:00 WIB -> reminder H-1 18:00 = 15 Nov 18:00 WIB
        dueIsDateOnly: true,
        completedAt: null,
        milestonePaymentId: null,
        sortOrder: 0,
        progressPercent: 40,
        revisionCount: 0,
        deletedAt: null,
      ),
      LocalTask(
        id: 'task-done',
        workspaceId: 'ws-1',
        projectId: null,
        kind: 'pribadi',
        title: 'Selesai',
        description: null,
        status: 'done',
        priority: 'rendah',
        dueAt: DateTime.utc(2026, 11, 16, 10, 0),
        dueIsDateOnly: true,
        completedAt: DateTime.utc(2026, 11, 14, 10, 0),
        milestonePaymentId: null,
        sortOrder: 1,
        progressPercent: 100,
        revisionCount: 0,
        deletedAt: null,
      ),
    ];

    final bills = [
      const LocalRecurringBill(
        id: 'bill-1',
        workspaceId: 'ws-1',
        name: 'Internet Fiber',
        amount: 350000,
        categoryId: 'cat-1',
        accountId: 'acc-1',
        scheduleType: 'monthly',
        scheduleValue: 18, // 2026-11-18 = H-3 from 2026-11-15
        remindDaysBefore: '[3, 0]',
        active: true,
        autoCreateDraft: true,
        deletedAt: null,
      ),
    ];

    final categories = [
      const LocalCategory(
        id: 'cat-makan',
        workspaceId: 'ws-1',
        name: 'Makan',
        type: 'expense',
        parentId: null,
        systemKey: null,
        archived: false,
        sortOrder: 0,
      ),
    ];

    final budgets = [
      const LocalBudget(
        id: 'bud-1',
        workspaceId: 'ws-1',
        categoryId: 'cat-makan',
        amount: 1000000,
        period: 'monthly',
        rollover: false,
        notifyAtPercent: 80,
        deletedAt: null,
      ),
    ];

    final transactions = [
      LocalTransaction(
        id: 'tx-1',
        workspaceId: 'ws-1',
        accountId: 'acc-1',
        categoryId: 'cat-makan',
        type: 'expense',
        status: 'confirmed',
        draftState: null,
        amount: 850000, // 85% >= 80%
        currency: 'IDR',
        source: 'personal',
        merchant: 'Warteg',
        note: null,
        occurredAt: DateTime.utc(2026, 11, 10, 5, 0),
        transferGroupId: null,
        transferDirection: null,
        origin: 'manual',
        deletedAt: null,
      ),
    ];

    final plan = NotificationSchedulerService.evaluatePlan(
      nowUtc: nowUtc,
      prefs: const OrbitNotificationPrefs(showTitleOnLockscreen: false),
      events: events,
      tasks: tasks,
      bills: bills,
      budgets: budgets,
      transactions: transactions,
      categories: categories,
    );

    // Morning summary + event reminder (08:30 WIB) + task reminder (15 Nov 18:00 WIB) + bill Hari-H (18 Nov 09:00 WIB)
    final morning = plan.scheduled.firstWhere(
      (e) => e.id == NotificationSchedulerService.morningSummaryId,
    );
    expect(morning.scheduledAt.toUtc(), DateTime.utc(2026, 11, 14, 23, 30)); // 06:30 WIB = 23:30 UTC
    expect(morning.body.contains('1 jadwal'), isTrue);
    expect(morning.body.contains('1 tugas aktif'), isTrue);
    expect(morning.body.contains('Basis Data Lanjut'), isFalse);
    expect(morning.body.contains('Invoice Rahasia'), isFalse);

    final evtReminder = plan.scheduled.firstWhere((e) => e.payload.type == 'event');
    expect(evtReminder.scheduledAt.toUtc(), DateTime.utc(2026, 11, 15, 1, 30)); // 08:30 WIB
    expect(evtReminder.body.contains('Basis Data Lanjut'), isFalse);

    final taskReminder = plan.scheduled.firstWhere((e) => e.payload.type == 'task');
    expect(taskReminder.scheduledAt.toUtc(), DateTime.utc(2026, 11, 15, 11, 0)); // 18:00 WIB
    expect(taskReminder.body.contains('Invoice Rahasia'), isFalse);

    expect(plan.immediateBillAlerts.length, 1);
    expect(plan.immediateBillAlerts.first.daysLeft, 3);

    expect(plan.immediateBudgetAlerts.length, 1);
    expect(plan.immediateBudgetAlerts.first.exceeded, isFalse);
    expect(plan.immediateBudgetAlerts.first.percentSpent, 85.0);
  });

  test('NotificationSchedulerService.rescheduleAll writes zonedSchedule to adapter idempotently', () async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    await db.into(db.localEvents).insert(
          LocalEventsCompanion.insert(
            id: 'evt-future',
            workspaceId: 'ws-1',
            kind: 'intern',
            title: 'Standup Harian',
            startsAt: DateTime.now().toUtc().add(const Duration(hours: 2)),
            endsAt: DateTime.now().toUtc().add(const Duration(hours: 3)),
          ),
        );

    final scheduledCount = await NotificationSchedulerService.rescheduleAll(db);
    expect(scheduledCount, greaterThanOrEqualTo(2)); // Morning summary + Event reminder
    expect(fakeAdapter.cancelAllCount, 1);
    expect(fakeAdapter.scheduled.length, scheduledCount);

    // Run again to verify idempotency (cancelAll prevents duplicate piling)
    final scheduledCount2 = await NotificationSchedulerService.rescheduleAll(db);
    expect(fakeAdapter.cancelAllCount, 2);
    expect(fakeAdapter.scheduled.length, scheduledCount2);

    await db.close();
  });

  testWidgets('NotificationSettingsScreen displays permission state & test buttons', (tester) async {
    final db = AppDatabase.forExecutor(NativeDatabase.memory());
    AppDatabase.overrideForTesting(db);

    await tester.pumpWidget(
      const MaterialApp(
        home: NotificationSettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Status Izin Notifikasi Android'), findsOneWidget);
    expect(find.text('Tes Sekarang'), findsOneWidget);
    expect(find.text('Tes Terjadwal 5 Detik'), findsOneWidget);

    await tester.tap(find.text('Tes Sekarang'));
    await tester.pumpAndSettle();
    expect(fakeAdapter.shown.length, 1);
    expect(fakeAdapter.shown.first.title, 'Orbit: Notifikasi Aktif');

    AppDatabase.overrideForTesting(null);
    await db.close();
  });
}
