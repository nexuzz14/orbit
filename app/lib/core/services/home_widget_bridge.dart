import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/privacy_and_lock_service.dart';
import 'package:orbit_app/core/widgets/orbit_formatters.dart';

class OrbitWidgetTodayItem {
  final String title;
  final String timeLabel;
  final String kind;
  final String itemType; // 'event' | 'task'

  const OrbitWidgetTodayItem({
    required this.title,
    required this.timeLabel,
    required this.kind,
    required this.itemType,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'timeLabel': timeLabel,
    'kind': kind,
    'itemType': itemType,
  };
}

class OrbitWidgetTaskItem {
  final String id;
  final String title;
  final String status;
  final String dueLabel;

  const OrbitWidgetTaskItem({
    required this.id,
    required this.title,
    required this.status,
    required this.dueLabel,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'status': status,
    'dueLabel': dueLabel,
  };
}

/// Payload ringkas & aman privasi untuk 4 widget homescreen Android Orbit.
class OrbitWidgetSnapshot {
  final String dateLabelWib;
  final String updatedAtLabelWib;
  final bool privacyMasked;
  final String balanceDisplayText;
  final int activeTaskCount;
  final List<OrbitWidgetTodayItem> todayItems;
  final List<OrbitWidgetTaskItem> priorityTasks;

  const OrbitWidgetSnapshot({
    required this.dateLabelWib,
    required this.updatedAtLabelWib,
    required this.privacyMasked,
    required this.balanceDisplayText,
    required this.activeTaskCount,
    required this.todayItems,
    required this.priorityTasks,
  });

  Map<String, dynamic> toAndroidPayload() {
    return {
      'dateLabelWib': dateLabelWib,
      'updatedAtLabelWib': updatedAtLabelWib,
      'privacyMasked': privacyMasked,
      'balanceDisplayText': balanceDisplayText,
      'activeTaskCount': activeTaskCount,
      'todayItems': todayItems.map((e) => e.toJson()).toList(),
      'priorityTasks': priorityTasks.map((e) => e.toJson()).toList(),
      'todayItemsJson': jsonEncode(todayItems.map((e) => e.toJson()).toList()),
      'priorityTasksJson': jsonEncode(
        priorityTasks.map((e) => e.toJson()).toList(),
      ),
    };
  }
}

/// Bridge antara Flutter Drift DB / PrivacyMode dan Android AppWidgets + WorkManager.
class HomeWidgetBridge {
  HomeWidgetBridge._();

  static const MethodChannel _channel = MethodChannel(
    'id.my.nabilcf.orbit/home_widget',
  );

  static bool _listenerAttached = false;
  static void Function(String actionType)? _onQuickAdd;

  static void registerQuickAddHandler(void Function(String actionType) handler) {
    _onQuickAdd = handler;
    if (_listenerAttached) return;
    _listenerAttached = true;
    try {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onQuickAddAction') {
          final type = call.arguments?.toString();
          if (_isValidQuickAddType(type)) {
            _onQuickAdd?.call(type!);
          }
        }
      });
    } on MissingPluginException {
      // Aman saat headless test.
    } catch (_) {}
  }

  static Future<String?> consumePendingQuickAddAction() async {
    try {
      final raw = await _channel.invokeMethod<dynamic>(
        'consumePendingQuickAddAction',
      );
      final val = raw is String ? raw : null;
      return _isValidQuickAddType(val) ? val : null;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    } catch (_) {
      return null;
    }
  }

  static String? parseQuickAddTypeFromUri(Uri uri) {
    if (uri.scheme == 'io.supabase.orbit' && uri.host == 'quick-add') {
      final t = uri.queryParameters['type']?.trim().toLowerCase();
      if (_isValidQuickAddType(t)) return t;
    }
    return null;
  }

  static bool _isValidQuickAddType(String? value) =>
      value == 'transaction' || value == 'task' || value == 'receipt';

  /// Susun snapshot deterministik dari Drift DB & status Mode Privasi.
  static Future<OrbitWidgetSnapshot> buildSnapshotFromDatabase(
    AppDatabase db, {
    DateTime? nowUtc,
    bool? forcePrivacyMask,
  }) async {
    final now = (nowUtc ?? DateTime.now()).toUtc();
    final nowWib = now.add(const Duration(hours: 7));
    final todayStartWib = DateTime.utc(nowWib.year, nowWib.month, nowWib.day);
    final todayEndWib = todayStartWib.add(const Duration(days: 1));
    final todayStartUtc = todayStartWib.subtract(const Duration(hours: 7));
    final todayEndUtc = todayEndWib.subtract(const Duration(hours: 7));

    final accounts = await db.select(db.localAccounts).get();
    final liquidTotal = accounts
        .where((a) => !a.archived && a.isLiquid)
        .fold<double>(0.0, (sum, a) => sum + a.currentBalance);

    final masked =
        forcePrivacyMask ??
        PrivacyModeController.instance.shouldMaskWidgetBalance;
    final balanceDisplay = masked
        ? PrivacyModeController.maskedPlaceholder
        : formatRupiah(liquidTotal);

    final events = await (db.select(
      db.localEvents,
    )..where((e) => e.deletedAt.isNull())).get();
    final tasks = await (db.select(
      db.localTasks,
    )..where((t) => t.deletedAt.isNull())).get();

    // Kumpulkan item Hari Ini (event hari ini WIB + tugas due hari ini WIB).
    final todayItems = <OrbitWidgetTodayItem>[];
    final todayEvents =
        events
            .where(
              (e) =>
                  e.startsAt.isBefore(todayEndUtc) &&
                  e.endsAt.isAfter(todayStartUtc),
            )
            .toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    for (final ev in todayEvents) {
      if (todayItems.length >= 3) break;
      final startWib = ev.startsAt.toUtc().add(const Duration(hours: 7));
      final hh = startWib.hour.toString().padLeft(2, '0');
      final mm = startWib.minute.toString().padLeft(2, '0');
      todayItems.add(
        OrbitWidgetTodayItem(
          title: ev.title,
          timeLabel: ev.allDay ? 'Seharian' : '$hh:$mm WIB',
          kind: ev.kind,
          itemType: 'event',
        ),
      );
    }

    final activeTasks = tasks.where((t) => t.status != 'done').toList();

    if (todayItems.length < 3) {
      final dueTodayTasks =
          activeTasks
              .where(
                (t) =>
                    t.dueAt != null &&
                    !t.dueAt!.isBefore(todayStartUtc) &&
                    t.dueAt!.isBefore(todayEndUtc),
              )
              .toList()
            ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));

      for (final task in dueTodayTasks) {
        if (todayItems.length >= 3) break;
        final dueWib = task.dueAt!.toUtc().add(const Duration(hours: 7));
        final hh = dueWib.hour.toString().padLeft(2, '0');
        final mm = dueWib.minute.toString().padLeft(2, '0');
        todayItems.add(
          OrbitWidgetTodayItem(
            title: task.title,
            timeLabel: 'Deadline $hh:$mm',
            kind: task.kind,
            itemType: 'task',
          ),
        );
      }
    }

    // Urutkan tugas prioritas: revisi/doing/todo, urgent > high > medium > low, dueAt.
    final sortedTasks = List<LocalTask>.from(activeTasks)
      ..sort((a, b) {
        final statusRankA = _taskStatusRank(a.status);
        final statusRankB = _taskStatusRank(b.status);
        if (statusRankA != statusRankB) {
          return statusRankA.compareTo(statusRankB);
        }
        final prioRankA = _priorityRank(a.priority);
        final prioRankB = _priorityRank(b.priority);
        if (prioRankA != prioRankB) {
          return prioRankA.compareTo(prioRankB);
        }
        final dueA = a.dueAt ?? DateTime.utc(2099);
        final dueB = b.dueAt ?? DateTime.utc(2099);
        return dueA.compareTo(dueB);
      });

    final priorityTasks = sortedTasks.take(3).map((t) {
      final statusLabel = switch (t.status) {
        'doing' => 'Doing',
        'revisi' => 'Revisi',
        _ => 'Todo',
      };
      String dueLabel = statusLabel;
      if (t.dueAt != null) {
        final dueWib = t.dueAt!.toUtc().add(const Duration(hours: 7));
        dueLabel = '$statusLabel - ${_formatDayMonthWib(dueWib)}';
      }
      return OrbitWidgetTaskItem(
        id: t.id,
        title: t.title,
        status: t.status,
        dueLabel: dueLabel,
      );
    }).toList();

    final hh = nowWib.hour.toString().padLeft(2, '0');
    final mm = nowWib.minute.toString().padLeft(2, '0');

    return OrbitWidgetSnapshot(
      dateLabelWib: _formatHeaderDateWib(nowWib),
      updatedAtLabelWib: 'Diperbarui $hh:$mm WIB',
      privacyMasked: masked,
      balanceDisplayText: balanceDisplay,
      activeTaskCount: activeTasks.length,
      todayItems: todayItems,
      priorityTasks: priorityTasks,
    );
  }

  /// Sinkronkan data widget terbaru dari Drift ke SharedPreferences Android & refresh UI widget.
  static Future<OrbitWidgetSnapshot> syncFromDatabase(
    AppDatabase db, {
    DateTime? nowUtc,
    bool? forcePrivacyMask,
  }) async {
    final snapshot = await buildSnapshotFromDatabase(
      db,
      nowUtc: nowUtc,
      forcePrivacyMask: forcePrivacyMask,
    );
    try {
      await _channel.invokeMethod<bool>(
        'updateWidgetData',
        snapshot.toAndroidPayload(),
      );
    } on MissingPluginException {
      // Aman saat headless test.
    } on PlatformException {
      // Aman bila kanal belum aktif.
    }
    return snapshot;
  }

  /// Minta Android WorkManager menjalankan satu kali penyegaran latar segera.
  static Future<bool> triggerBackgroundRefreshNow() async {
    try {
      final res = await _channel.invokeMethod<bool>('triggerPeriodicSyncNow');
      return res ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static int _taskStatusRank(String status) {
    switch (status) {
      case 'revisi':
        return 0;
      case 'doing':
        return 1;
      case 'todo':
        return 2;
      default:
        return 3;
    }
  }

  static int _priorityRank(String priority) {
    switch (priority) {
      case 'urgent':
        return 0;
      case 'high':
        return 1;
      case 'medium':
        return 2;
      case 'low':
        return 3;
      default:
        return 4;
    }
  }

  static String _formatHeaderDateWib(DateTime wib) {
    const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final d = days[(wib.weekday - 1).clamp(0, 6)];
    final m = months[(wib.month - 1).clamp(0, 11)];
    return '$d, ${wib.day} $m';
  }

  static String _formatDayMonthWib(DateTime wib) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final m = months[(wib.month - 1).clamp(0, 11)];
    return '${wib.day} $m';
  }
}
