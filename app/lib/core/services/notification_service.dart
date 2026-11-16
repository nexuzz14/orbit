import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class NotificationPayload {
  final String type; // today | event | task | bill | budget | test
  final int targetTab; // 0: Hari Ini, 1: Agenda, 2: Uang, 3: Lainnya
  final String? agendaMode; // jadwal | tugas
  final String? uangSection; // budget | tagihan | transaksi
  final String? itemId;

  const NotificationPayload({
    required this.type,
    required this.targetTab,
    this.agendaMode,
    this.uangSection,
    this.itemId,
  });

  String encode() => jsonEncode({
        'type': type,
        'tab': targetTab,
        if (agendaMode != null) 'agendaMode': agendaMode,
        if (uangSection != null) 'uangSection': uangSection,
        if (itemId != null) 'itemId': itemId,
      });

  static NotificationPayload? tryDecode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final type = decoded['type'] as String? ?? 'today';
      final tab = (decoded['tab'] as num?)?.toInt() ?? 0;
      return NotificationPayload(
        type: type,
        targetTab: tab.clamp(0, 3),
        agendaMode: decoded['agendaMode'] as String?,
        uangSection: decoded['uangSection'] as String?,
        itemId: decoded['itemId'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

class OrbitNotificationPrefs {
  final bool morningSummaryEnabled;
  final int morningHour;
  final int morningMinute;
  final bool scheduleRemindersEnabled;
  final int defaultEventReminderMinutes;
  final bool taskRemindersEnabled;
  final bool billRemindersEnabled;
  final bool budgetAlertsEnabled;
  final bool showTitleOnLockscreen;
  final bool weeklyDigestEnabled;
  final bool smartConflictAlertsEnabled;
  final bool stagnantTaskAlertsEnabled;

  const OrbitNotificationPrefs({
    this.morningSummaryEnabled = true,
    this.morningHour = 6,
    this.morningMinute = 30,
    this.scheduleRemindersEnabled = true,
    this.defaultEventReminderMinutes = 30,
    this.taskRemindersEnabled = true,
    this.billRemindersEnabled = true,
    this.budgetAlertsEnabled = true,
    this.showTitleOnLockscreen = false,
    this.weeklyDigestEnabled = true,
    this.smartConflictAlertsEnabled = true,
    this.stagnantTaskAlertsEnabled = true,
  });

  OrbitNotificationPrefs copyWith({
    bool? morningSummaryEnabled,
    int? morningHour,
    int? morningMinute,
    bool? scheduleRemindersEnabled,
    int? defaultEventReminderMinutes,
    bool? taskRemindersEnabled,
    bool? billRemindersEnabled,
    bool? budgetAlertsEnabled,
    bool? showTitleOnLockscreen,
    bool? weeklyDigestEnabled,
    bool? smartConflictAlertsEnabled,
    bool? stagnantTaskAlertsEnabled,
  }) {
    return OrbitNotificationPrefs(
      morningSummaryEnabled:
          morningSummaryEnabled ?? this.morningSummaryEnabled,
      morningHour: morningHour ?? this.morningHour,
      morningMinute: morningMinute ?? this.morningMinute,
      scheduleRemindersEnabled:
          scheduleRemindersEnabled ?? this.scheduleRemindersEnabled,
      defaultEventReminderMinutes:
          defaultEventReminderMinutes ?? this.defaultEventReminderMinutes,
      taskRemindersEnabled: taskRemindersEnabled ?? this.taskRemindersEnabled,
      billRemindersEnabled: billRemindersEnabled ?? this.billRemindersEnabled,
      budgetAlertsEnabled: budgetAlertsEnabled ?? this.budgetAlertsEnabled,
      showTitleOnLockscreen:
          showTitleOnLockscreen ?? this.showTitleOnLockscreen,
      weeklyDigestEnabled: weeklyDigestEnabled ?? this.weeklyDigestEnabled,
      smartConflictAlertsEnabled:
          smartConflictAlertsEnabled ?? this.smartConflictAlertsEnabled,
      stagnantTaskAlertsEnabled:
          stagnantTaskAlertsEnabled ?? this.stagnantTaskAlertsEnabled,
    );
  }

  static Future<OrbitNotificationPrefs> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return OrbitNotificationPrefs(
        morningSummaryEnabled: prefs.getBool('notif_morning_enabled') ?? true,
        morningHour: (prefs.getInt('notif_morning_hour') ?? 6).clamp(0, 23),
        morningMinute: (prefs.getInt('notif_morning_min') ?? 30).clamp(0, 59),
        scheduleRemindersEnabled:
            prefs.getBool('notif_schedule_enabled') ?? true,
        defaultEventReminderMinutes:
            (prefs.getInt('notif_event_mins') ?? 30).clamp(5, 180),
        taskRemindersEnabled: prefs.getBool('notif_task_enabled') ?? true,
        billRemindersEnabled: prefs.getBool('notif_bill_enabled') ?? true,
        budgetAlertsEnabled: prefs.getBool('notif_budget_enabled') ?? true,
        showTitleOnLockscreen: prefs.getBool('notif_show_titles') ?? false,
        weeklyDigestEnabled:
            prefs.getBool('notif_weekly_digest_enabled') ?? true,
        smartConflictAlertsEnabled:
            prefs.getBool('notif_conflict_alerts_enabled') ?? true,
        stagnantTaskAlertsEnabled:
            prefs.getBool('notif_stagnant_alerts_enabled') ?? true,
      );
    } catch (_) {
      return const OrbitNotificationPrefs();
    }
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notif_morning_enabled', morningSummaryEnabled);
      await prefs.setInt('notif_morning_hour', morningHour);
      await prefs.setInt('notif_morning_min', morningMinute);
      await prefs.setBool('notif_schedule_enabled', scheduleRemindersEnabled);
      await prefs.setInt('notif_event_mins', defaultEventReminderMinutes);
      await prefs.setBool('notif_task_enabled', taskRemindersEnabled);
      await prefs.setBool('notif_bill_enabled', billRemindersEnabled);
      await prefs.setBool('notif_budget_enabled', budgetAlertsEnabled);
      await prefs.setBool('notif_show_titles', showTitleOnLockscreen);
      await prefs.setBool('notif_weekly_digest_enabled', weeklyDigestEnabled);
      await prefs.setBool(
        'notif_conflict_alerts_enabled',
        smartConflictAlertsEnabled,
      );
      await prefs.setBool(
        'notif_stagnant_alerts_enabled',
        stagnantTaskAlertsEnabled,
      );
    } catch (e) {
      debugPrint('Failed saving notification preferences: $e');
    }
  }
}

abstract class NotificationAdapter {
  Future<void> initialize({
    required void Function(String? payload) onTap,
  });
  Future<bool?> requestPermission();
  Future<bool?> areNotificationsEnabled();
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    required String channelDescription,
    String? payload,
  });
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
  });
  Future<void> cancelAll();
  Future<void> cancel(int id);
  Future<List<PendingNotificationRequest>> pendingRequests();
  Future<String?> getLaunchPayload();
}

class _FlutterLocalNotificationAdapter implements NotificationAdapter {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  @override
  Future<void> initialize({
    required void Function(String? payload) onTap,
  }) async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) {
        onTap(response.payload);
      },
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          NotificationService.channelGeneralId,
          NotificationService.channelGeneralName,
          description: NotificationService.channelGeneralDesc,
          importance: Importance.high,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          NotificationService.channelScheduleId,
          NotificationService.channelScheduleName,
          description: NotificationService.channelScheduleDesc,
          importance: Importance.high,
        ),
      );
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          NotificationService.channelBillId,
          NotificationService.channelBillName,
          description: NotificationService.channelBillDesc,
          importance: Importance.high,
        ),
      );
    }

    _initialized = true;
  }

  @override
  Future<bool?> requestPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return androidPlugin?.requestNotificationsPermission();
  }

  @override
  Future<bool?> areNotificationsEnabled() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return androidPlugin?.areNotificationsEnabled();
  }

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
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        visibility: NotificationVisibility.private,
      ),
    );
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
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
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        visibility: NotificationVisibility.private,
      ),
    );
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: matchDateTimeComponents,
      payload: payload,
    );
  }

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<List<PendingNotificationRequest>> pendingRequests() =>
      _plugin.pendingNotificationRequests();

  @override
  Future<String?> getLaunchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details != null && details.didNotificationLaunchApp) {
      return details.notificationResponse?.payload;
    }
    return null;
  }
}

class NotificationService {
  static const String channelGeneralId = 'orbit_general_channel';
  static const String channelGeneralName = 'Orbit Ringkasan & Umum';
  static const String channelGeneralDesc =
      'Ringkasan harian dan notifikasi umum Orbit';

  static const String channelScheduleId = 'orbit_schedule_channel';
  static const String channelScheduleName = 'Orbit Jadwal & Tugas';
  static const String channelScheduleDesc =
      'Pengingat jadwal kegiatan dan tenggat tugas';

  static const String channelBillId = 'orbit_bill_channel';
  static const String channelBillName = 'Orbit Tagihan & Anggaran';
  static const String channelBillDesc =
      'Pengingat tagihan jatuh tempo dan peringatan batas anggaran';

  static NotificationAdapter _adapter = _FlutterLocalNotificationAdapter();
  static bool _tzInitialized = false;
  static NotificationPayload? _pendingLaunchPayload;
  static final StreamController<NotificationPayload> _tapController =
      StreamController<NotificationPayload>.broadcast();

  static Stream<NotificationPayload> get onNotificationTap =>
      _tapController.stream;

  static void overrideAdapterForTesting(NotificationAdapter? adapter) {
    _adapter = adapter ?? _FlutterLocalNotificationAdapter();
    _pendingLaunchPayload = null;
  }

  static void ensureTimezonesInitialized() {
    if (_tzInitialized) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
    _tzInitialized = true;
  }

  static tz.Location get jakartaLocation {
    ensureTimezonesInitialized();
    try {
      return tz.getLocation('Asia/Jakarta');
    } catch (_) {
      return tz.UTC;
    }
  }

  static tz.TZDateTime toJakartaTz(DateTime dt) {
    return tz.TZDateTime.from(dt.toUtc(), jakartaLocation);
  }

  static Future<void> initialize() async {
    ensureTimezonesInitialized();
    await _adapter.initialize(
      onTap: (rawPayload) {
        final parsed = NotificationPayload.tryDecode(rawPayload);
        if (parsed != null) {
          _pendingLaunchPayload = parsed;
          _tapController.add(parsed);
        }
      },
    );

    try {
      final launchPayload = await _adapter.getLaunchPayload();
      final parsed = NotificationPayload.tryDecode(launchPayload);
      if (parsed != null) {
        _pendingLaunchPayload = parsed;
      }
    } catch (_) {}
  }

  static NotificationPayload? consumePendingPayload() {
    final p = _pendingLaunchPayload;
    _pendingLaunchPayload = null;
    return p;
  }

  static Future<bool> requestPermission() async {
    try {
      final granted = await _adapter.requestPermission();
      return granted ?? true;
    } catch (e) {
      debugPrint('NotificationService.requestPermission error: $e');
      return false;
    }
  }

  static Future<bool> areNotificationsEnabled() async {
    try {
      final enabled = await _adapter.areNotificationsEnabled();
      return enabled ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String channelId = channelGeneralId,
    String channelName = channelGeneralName,
    String channelDescription = channelGeneralDesc,
    NotificationPayload? payload,
  }) async {
    await _adapter.show(
      id: id,
      title: title,
      body: body,
      channelId: channelId,
      channelName: channelName,
      channelDescription: channelDescription,
      payload: payload?.encode(),
    );
  }

  static Future<void> scheduleZonedNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledAt,
    String channelId = channelScheduleId,
    String channelName = channelScheduleName,
    String channelDescription = channelScheduleDesc,
    NotificationPayload? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    ensureTimezonesInitialized();
    final tzDate = toJakartaTz(scheduledAt);
    await _adapter.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tzDate,
      channelId: channelId,
      channelName: channelName,
      channelDescription: channelDescription,
      payload: payload?.encode(),
      matchDateTimeComponents: matchDateTimeComponents,
    );
  }

  // Ringkasan pagi (PRD M10c & M13: berisi jumlah jadwal, tugas, dan tenggat tanpa judul)
  static Future<void> showMorningSummary({
    required int eventCount,
    required int taskCount,
    int dueTodayCount = 0,
  }) async {
    final duePart =
        dueTodayCount > 0 ? ', $dueTodayCount jatuh tempo hari ini' : '';
    final body =
        'Hari ini Anda memiliki $eventCount jadwal kegiatan dan $taskCount tugas aktif$duePart.';
    await showNotification(
      id: 9999,
      title: 'Orbit: Ringkasan Hari Ini',
      body: body,
      channelId: channelGeneralId,
      channelName: channelGeneralName,
      channelDescription: channelGeneralDesc,
      payload: const NotificationPayload(type: 'today', targetTab: 0),
    );
  }

  static Future<List<PendingNotificationRequest>> getPendingRequests() async {
    try {
      return await _adapter.pendingRequests();
    } catch (_) {
      return [];
    }
  }

  static Future<void> cancelAll() => _adapter.cancelAll();

  static Future<void> cancel(int id) => _adapter.cancel(id);
}
