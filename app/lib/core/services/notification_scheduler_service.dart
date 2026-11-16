import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/bill_notification_service.dart';
import 'package:orbit_app/core/services/notification_service.dart';
import 'package:orbit_app/core/services/privacy_and_lock_service.dart';
import 'package:orbit_app/core/widgets/orbit_formatters.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

class ScheduledReminderItem {
  final int id;
  final String title;
  final String body;
  final DateTime scheduledAt;
  final String channelId;
  final String channelName;
  final String channelDescription;
  final NotificationPayload payload;
  final DateTimeComponents? repeatComponents;

  const ScheduledReminderItem({
    required this.id,
    required this.title,
    required this.body,
    required this.scheduledAt,
    required this.channelId,
    required this.channelName,
    required this.channelDescription,
    required this.payload,
    this.repeatComponents,
  });
}

class BillDueAlert {
  final int id;
  final String billId;
  final String billName;
  final double amount;
  final int daysLeft;

  const BillDueAlert({
    required this.id,
    required this.billId,
    required this.billName,
    required this.amount,
    required this.daysLeft,
  });
}

class BudgetThresholdAlert {
  final int id;
  final String budgetId;
  final String categoryName;
  final double percentSpent;
  final bool exceeded;

  const BudgetThresholdAlert({
    required this.id,
    required this.budgetId,
    required this.categoryName,
    required this.percentSpent,
    required this.exceeded,
  });
}

class ScheduleConflictAlert {
  final int id;
  final String firstEventId;
  final String secondEventId;
  final String firstTitle;
  final String secondTitle;
  final DateTime overlapStartUtc;

  const ScheduleConflictAlert({
    required this.id,
    required this.firstEventId,
    required this.secondEventId,
    required this.firstTitle,
    required this.secondTitle,
    required this.overlapStartUtc,
  });
}

class StagnantTaskAlert {
  final int id;
  final String taskId;
  final String title;
  final String status;
  final int stagnantDays;

  const StagnantTaskAlert({
    required this.id,
    required this.taskId,
    required this.title,
    required this.status,
    required this.stagnantDays,
  });
}

class WeeklyDigestSummary {
  final DateTime scheduledAtWib;
  final int completedTasksLast7Days;
  final int activeTasksCount;
  final int stagnantTasksCount;
  final int upcomingBillsCount;
  final double weeklyIncome;
  final double weeklyExpense;
  final bool privacyMasked;
  final String summaryText;
  final String lockscreenTitle;
  final String lockscreenBody;

  const WeeklyDigestSummary({
    required this.scheduledAtWib,
    required this.completedTasksLast7Days,
    required this.activeTasksCount,
    required this.stagnantTasksCount,
    required this.upcomingBillsCount,
    required this.weeklyIncome,
    required this.weeklyExpense,
    required this.privacyMasked,
    required this.summaryText,
    required this.lockscreenTitle,
    required this.lockscreenBody,
  });
}

class ReminderEvaluationResult {
  final List<ScheduledReminderItem> scheduled;
  final List<BillDueAlert> immediateBillAlerts;
  final List<BudgetThresholdAlert> immediateBudgetAlerts;
  final List<ScheduleConflictAlert> scheduleConflicts;
  final List<StagnantTaskAlert> stagnantTasks;
  final WeeklyDigestSummary? weeklyDigest;

  const ReminderEvaluationResult({
    required this.scheduled,
    required this.immediateBillAlerts,
    required this.immediateBudgetAlerts,
    this.scheduleConflicts = const [],
    this.stagnantTasks = const [],
    this.weeklyDigest,
  });
}

class NotificationSchedulerService {
  static const int morningSummaryId = 1000;
  static const int weeklyDigestId = 1001;
  static const int testInstantId = 9001;
  static const int testScheduledId = 9002;

  static int stableId(int prefix, String key) {
    var hash = 0;
    for (final unit in key.codeUnits) {
      hash = ((hash * 31) + unit) & 0xFFFF;
    }
    return prefix + hash;
  }

  /// Menghitung rencana pengingat deterministik berdasarkan zona Asia/Jakarta (UTC+7).
  /// Dapat dipanggil murni di unit test tanpa ketergantungan Android OS.
  static ReminderEvaluationResult evaluatePlan({
    required DateTime nowUtc,
    required OrbitNotificationPrefs prefs,
    required List<LocalEvent> events,
    required List<LocalTask> tasks,
    required List<LocalRecurringBill> bills,
    required List<LocalBudget> budgets,
    required List<LocalTransaction> transactions,
    required List<LocalCategory> categories,
    bool? forcePrivacyMask,
  }) {
    NotificationService.ensureTimezonesInitialized();
    final jakarta = NotificationService.jakartaLocation;
    final nowJakarta = tz.TZDateTime.from(nowUtc.toUtc(), jakarta);
    final todayStartJakarta = tz.TZDateTime(
      jakarta,
      nowJakarta.year,
      nowJakarta.month,
      nowJakarta.day,
    );

    final scheduled = <ScheduledReminderItem>[];
    final billAlerts = <BillDueAlert>[];
    final budgetAlerts = <BudgetThresholdAlert>[];
    final scheduleConflicts = <ScheduleConflictAlert>[];
    final stagnantTasks = <StagnantTaskAlert>[];

    // 1. Ringkasan Pagi Harian (PRD M10c & M13: tanpa judul tugas/acara, default 06.30 WIB)
    if (prefs.morningSummaryEnabled) {
      final activeEventsToday = events.where((e) {
        if (e.deletedAt != null) return false;
        final s = tz.TZDateTime.from(e.startsAt.toUtc(), jakarta);
        return s.year == nowJakarta.year &&
            s.month == nowJakarta.month &&
            s.day == nowJakarta.day;
      }).length;

      final activeTasks = tasks.where((t) {
        if (t.deletedAt != null) return false;
        return t.status != 'done' && t.status != 'selesai';
      }).toList();

      final dueTodayCount = activeTasks.where((t) {
        if (t.dueAt == null) return false;
        final d = tz.TZDateTime.from(t.dueAt!.toUtc(), jakarta);
        return d.year == nowJakarta.year &&
            d.month == nowJakarta.month &&
            d.day == nowJakarta.day;
      }).length;

      var nextMorning = tz.TZDateTime(
        jakarta,
        nowJakarta.year,
        nowJakarta.month,
        nowJakarta.day,
        prefs.morningHour,
        prefs.morningMinute,
      );
      if (!nextMorning.isAfter(nowJakarta)) {
        nextMorning = nextMorning.add(const Duration(days: 1));
      }

      final dueText = dueTodayCount > 0
          ? ', termasuk $dueTodayCount tenggat hari ini'
          : '';
      scheduled.add(
        ScheduledReminderItem(
          id: morningSummaryId,
          title: 'Orbit: Ringkasan Hari Ini',
          body:
              'Terdapat $activeEventsToday jadwal dan ${activeTasks.length} tugas aktif$dueText.',
          scheduledAt: nextMorning,
          channelId: NotificationService.channelGeneralId,
          channelName: NotificationService.channelGeneralName,
          channelDescription: NotificationService.channelGeneralDesc,
          payload: const NotificationPayload(type: 'today', targetTab: 0),
          repeatComponents: DateTimeComponents.time,
        ),
      );
    }

    // 2. Pengingat Jadwal (default 30 menit sebelum mulai)
    if (prefs.scheduleRemindersEnabled) {
      final maxHorizon = nowJakarta.add(const Duration(days: 7));
      for (final evt in events) {
        if (evt.deletedAt != null) continue;
        final startJkt = tz.TZDateTime.from(evt.startsAt.toUtc(), jakarta);
        if (startJkt.isAfter(maxHorizon)) continue;

        final remindAt = evt.allDay
            ? tz.TZDateTime(
                jakarta,
                startJkt.year,
                startJkt.month,
                startJkt.day,
                8,
                0,
              )
            : startJkt.subtract(
                Duration(minutes: prefs.defaultEventReminderMinutes),
              );

        if (remindAt.isAfter(nowJakarta)) {
          final kindLabel = _kindLabel(evt.kind);
          final body = prefs.showTitleOnLockscreen
              ? '$kindLabel: ${evt.title}'
              : 'Jadwal $kindLabel dimulai ${evt.allDay ? 'hari ini' : 'dalam ${prefs.defaultEventReminderMinutes} menit'}.';
          scheduled.add(
            ScheduledReminderItem(
              id: stableId(100000, evt.id),
              title: 'Pengingat Jadwal Orbit',
              body: body,
              scheduledAt: remindAt,
              channelId: NotificationService.channelScheduleId,
              channelName: NotificationService.channelScheduleName,
              channelDescription: NotificationService.channelScheduleDesc,
              payload: NotificationPayload(
                type: 'event',
                targetTab: 1,
                agendaMode: 'jadwal',
                itemId: evt.id,
              ),
            ),
          );
        }
      }
    }

    // 3. Pengingat Tenggat Tugas (H-24 jam & H-1 jam / H-1 pukul 18:00 untuk tanggal saja)
    if (prefs.taskRemindersEnabled) {
      for (final task in tasks) {
        if (task.deletedAt != null) continue;
        if (task.status == 'done' || task.status == 'selesai') continue;
        if (task.dueAt == null) continue;

        final dueJkt = tz.TZDateTime.from(task.dueAt!.toUtc(), jakarta);
        final kindLabel = _kindLabel(task.kind);

        if (task.dueIsDateOnly) {
          final prevDay = dueJkt.subtract(const Duration(days: 1));
          final remindAt = tz.TZDateTime(
            jakarta,
            prevDay.year,
            prevDay.month,
            prevDay.day,
            18,
            0,
          );
          if (remindAt.isAfter(nowJakarta)) {
            final body = prefs.showTitleOnLockscreen
                ? '[$kindLabel] ${task.title}'
                : 'Ada tugas $kindLabel mendekati batas tenggat.';
            scheduled.add(
              ScheduledReminderItem(
                id: stableId(200000, task.id),
                title: 'Pengingat Tenggat Tugas',
                body: body,
                scheduledAt: remindAt,
                channelId: NotificationService.channelScheduleId,
                channelName: NotificationService.channelScheduleName,
                channelDescription: NotificationService.channelScheduleDesc,
                payload: NotificationPayload(
                  type: 'task',
                  targetTab: 1,
                  agendaMode: 'tugas',
                  itemId: task.id,
                ),
              ),
            );
          }
        } else {
          final remind24h = dueJkt.subtract(const Duration(hours: 24));
          if (remind24h.isAfter(nowJakarta)) {
            final body24h = prefs.showTitleOnLockscreen
                ? 'H-24 jam [$kindLabel]: ${task.title}'
                : 'Ada tugas $kindLabel jatuh tempo dalam 24 jam.';
            scheduled.add(
              ScheduledReminderItem(
                id: stableId(205000, '${task.id}_24h'),
                title: 'Pengingat Tenggat H-24 Jam',
                body: body24h,
                scheduledAt: remind24h,
                channelId: NotificationService.channelScheduleId,
                channelName: NotificationService.channelScheduleName,
                channelDescription: NotificationService.channelScheduleDesc,
                payload: NotificationPayload(
                  type: 'task',
                  targetTab: 1,
                  agendaMode: 'tugas',
                  itemId: task.id,
                ),
              ),
            );
          }

          final remind1h = dueJkt.subtract(const Duration(hours: 1));
          if (remind1h.isAfter(nowJakarta)) {
            final body = prefs.showTitleOnLockscreen
                ? '[$kindLabel] ${task.title}'
                : 'Ada tugas $kindLabel mendekati batas tenggat dalam 1 jam.';
            scheduled.add(
              ScheduledReminderItem(
                id: stableId(200000, task.id),
                title: 'Pengingat Tenggat Tugas',
                body: body,
                scheduledAt: remind1h,
                channelId: NotificationService.channelScheduleId,
                channelName: NotificationService.channelScheduleName,
                channelDescription: NotificationService.channelScheduleDesc,
                payload: NotificationPayload(
                  type: 'task',
                  targetTab: 1,
                  agendaMode: 'tugas',
                  itemId: task.id,
                ),
              ),
            );
          }
        }
      }
    }

    // 4. Pengingat Tagihan Rutin (H-3 dan Hari-H)
    if (prefs.billRemindersEnabled) {
      for (final bill in bills) {
        if (bill.deletedAt != null || !bill.active) continue;
        final nextDue = _computeNextBillDueDate(nowJakarta, bill);
        if (nextDue == null) continue;

        List<int> remindOffsets = const [3, 0];
        try {
          final decoded = jsonDecode(bill.remindDaysBefore);
          if (decoded is List) {
            remindOffsets = decoded
                .map((e) => (e as num?)?.toInt() ?? 0)
                .toSet()
                .toList();
          }
        } catch (_) {}

        final daysDiff = nextDue.difference(todayStartJakarta).inDays;
        if (remindOffsets.contains(daysDiff)) {
          billAlerts.add(
            BillDueAlert(
              id: stableId(300000, '${bill.id}_$daysDiff'),
              billId: bill.id,
              billName: bill.name,
              amount: bill.amount,
              daysLeft: daysDiff,
            ),
          );
        }

        for (final offset in remindOffsets) {
          final targetDay = nextDue.subtract(Duration(days: offset));
          final scheduleTime = tz.TZDateTime(
            jakarta,
            targetDay.year,
            targetDay.month,
            targetDay.day,
            9,
            0,
          );
          if (scheduleTime.isAfter(nowJakarta)) {
            final title = offset == 0
                ? 'Tagihan Jatuh Tempo Hari Ini'
                : 'Pengingat Tagihan (H-$offset)';
            final body = prefs.showTitleOnLockscreen
                ? 'Tagihan ${bill.name} perlu ditinjau.'
                : offset == 0
                    ? 'Ada tagihan rutin yang jatuh tempo hari ini.'
                    : 'Ada tagihan rutin yang akan jatuh tempo dalam $offset hari.';
            scheduled.add(
              ScheduledReminderItem(
                id: stableId(310000, '${bill.id}_$offset'),
                title: title,
                body: body,
                scheduledAt: scheduleTime,
                channelId: NotificationService.channelBillId,
                channelName: NotificationService.channelBillName,
                channelDescription: NotificationService.channelBillDesc,
                payload: NotificationPayload(
                  type: 'bill',
                  targetTab: 2,
                  uangSection: 'tagihan',
                  itemId: bill.id,
                ),
              ),
            );
          }
        }
      }
    }

    // 5. Peringatan Batas Anggaran (80% & 100%)
    if (prefs.budgetAlertsEnabled && budgets.isNotEmpty) {
      final monthStart = tz.TZDateTime(jakarta, nowJakarta.year, nowJakarta.month, 1);
      final catMap = {for (final c in categories) c.id: c.name};

      for (final b in budgets) {
        if (b.deletedAt != null || b.amount <= 0) continue;
        final catName = catMap[b.categoryId] ?? 'Kategori';
        final spent = transactions
            .where((t) {
              if (t.deletedAt != null) return false;
              if (t.type != 'expense' || t.status != 'confirmed') return false;
              if (t.categoryId != b.categoryId && t.categoryId != catName) {
                return false;
              }
              final occ = tz.TZDateTime.from(t.occurredAt.toUtc(), jakarta);
              return !occ.isBefore(monthStart);
            })
            .fold<double>(0.0, (acc, t) => acc + t.amount);

        final pct = (spent / b.amount) * 100.0;
        if (pct >= b.notifyAtPercent) {
          budgetAlerts.add(
            BudgetThresholdAlert(
              id: stableId(400000, b.id),
              budgetId: b.id,
              categoryName: catName,
              percentSpent: pct,
              exceeded: pct >= 100.0,
            ),
          );
        }
      }
    }

    // 6. Deteksi Jadwal Bentrok Hari Ini (WIB)
    if (prefs.smartConflictAlertsEnabled) {
      final todayEndJakarta = todayStartJakarta.add(const Duration(days: 1));
      final todayTimedEvents = events.where((e) {
        if (e.deletedAt != null || e.allDay) return false;
        final s = tz.TZDateTime.from(e.startsAt.toUtc(), jakarta);
        final end = tz.TZDateTime.from(e.endsAt.toUtc(), jakarta);
        return s.isBefore(todayEndJakarta) && end.isAfter(todayStartJakarta);
      }).toList()..sort((a, b) => a.startsAt.compareTo(b.startsAt));

      for (var i = 0; i < todayTimedEvents.length; i++) {
        for (var j = i + 1; j < todayTimedEvents.length; j++) {
          final a = todayTimedEvents[i];
          final b = todayTimedEvents[j];
          if (b.startsAt.isBefore(a.endsAt) && a.startsAt.isBefore(b.endsAt)) {
            final overlapStart =
                b.startsAt.isAfter(a.startsAt) ? b.startsAt : a.startsAt;
            scheduleConflicts.add(
              ScheduleConflictAlert(
                id: stableId(450000, '${a.id}_${b.id}'),
                firstEventId: a.id,
                secondEventId: b.id,
                firstTitle: a.title,
                secondTitle: b.title,
                overlapStartUtc: overlapStart.toUtc(),
              ),
            );
          }
        }
      }
    }

    // 7. Deteksi Tugas Macet (doing / revisi > 5 hari tanpa pembaruan)
    if (prefs.stagnantTaskAlertsEnabled) {
      for (final task in tasks) {
        if (task.deletedAt != null) continue;
        if (task.status != 'doing' && task.status != 'revisi') continue;
        final refDate = task.statusChangedAt;
        if (refDate == null) continue;
        final stagnantDuration = nowUtc.toUtc().difference(refDate.toUtc());
        if (stagnantDuration > const Duration(days: 5)) {
          stagnantTasks.add(
            StagnantTaskAlert(
              id: stableId(480000, task.id),
              taskId: task.id,
              title: task.title,
              status: task.status,
              stagnantDays: stagnantDuration.inDays,
            ),
          );
        }
      }
    }

    // 8. Ringkasan Mingguan (Senin 08:00 WIB) dengan hormat privasi layar kunci
    final weeklyDigest = buildWeeklyDigestSummary(
      nowUtc: nowUtc,
      prefs: prefs,
      tasks: tasks,
      bills: bills,
      transactions: transactions,
      stagnantTasksCount: stagnantTasks.length,
      forcePrivacyMask: forcePrivacyMask,
    );

    if (prefs.weeklyDigestEnabled) {
      scheduled.add(
        ScheduledReminderItem(
          id: weeklyDigestId,
          title: weeklyDigest.lockscreenTitle,
          body: weeklyDigest.lockscreenBody,
          scheduledAt: weeklyDigest.scheduledAtWib,
          channelId: NotificationService.channelGeneralId,
          channelName: NotificationService.channelGeneralName,
          channelDescription: NotificationService.channelGeneralDesc,
          payload: const NotificationPayload(type: 'today', targetTab: 0),
          repeatComponents: DateTimeComponents.dayOfWeekAndTime,
        ),
      );
    }

    return ReminderEvaluationResult(
      scheduled: scheduled,
      immediateBillAlerts: billAlerts,
      immediateBudgetAlerts: budgetAlerts,
      scheduleConflicts: scheduleConflicts,
      stagnantTasks: stagnantTasks,
      weeklyDigest: weeklyDigest,
    );
  }

  /// Susun ringkasan mingguan untuk jadwal Senin 08:00 WIB dan kartu di UI.
  static WeeklyDigestSummary buildWeeklyDigestSummary({
    required DateTime nowUtc,
    required OrbitNotificationPrefs prefs,
    required List<LocalTask> tasks,
    required List<LocalRecurringBill> bills,
    required List<LocalTransaction> transactions,
    int? stagnantTasksCount,
    bool? forcePrivacyMask,
  }) {
    NotificationService.ensureTimezonesInitialized();
    final jakarta = NotificationService.jakartaLocation;
    final nowJakarta = tz.TZDateTime.from(nowUtc.toUtc(), jakarta);

    var daysUntilMonday = (DateTime.monday - nowJakarta.weekday + 7) % 7;
    var nextMonday = tz.TZDateTime(
      jakarta,
      nowJakarta.year,
      nowJakarta.month,
      nowJakarta.day,
      8,
      0,
    ).add(Duration(days: daysUntilMonday));
    if (!nextMonday.isAfter(nowJakarta)) {
      nextMonday = nextMonday.add(const Duration(days: 7));
    }

    final sevenDaysAgoUtc = nowUtc.toUtc().subtract(const Duration(days: 7));
    final completedLast7 = tasks.where((t) {
      if (t.deletedAt != null) return false;
      if (t.status != 'done' && t.status != 'selesai') return false;
      final completed = (t.completedAt ?? t.statusChangedAt)?.toUtc();
      return completed != null && !completed.isBefore(sevenDaysAgoUtc);
    }).length;

    final activeTasks = tasks
        .where(
          (t) =>
              t.deletedAt == null &&
              t.status != 'done' &&
              t.status != 'selesai',
        )
        .length;

    final computedStagnant =
        stagnantTasksCount ??
        tasks.where((t) {
          if (t.deletedAt != null) return false;
          if (t.status != 'doing' && t.status != 'revisi') return false;
          final refDate = t.statusChangedAt;
          if (refDate == null) return false;
          return nowUtc.toUtc().difference(refDate.toUtc()) >
              const Duration(days: 5);
        }).length;

    final upcomingBills = bills.where((b) {
      if (b.deletedAt != null || !b.active) return false;
      final due = _computeNextBillDueDate(nowJakarta, b);
      if (due == null) return false;
      final today = tz.TZDateTime(
        jakarta,
        nowJakarta.year,
        nowJakarta.month,
        nowJakarta.day,
      );
      final diff = due.difference(today).inDays;
      return diff >= 0 && diff <= 7;
    }).length;

    var weeklyIncome = 0.0;
    var weeklyExpense = 0.0;
    for (final tx in transactions) {
      if (tx.deletedAt != null) continue;
      if (tx.status != 'confirmed' && tx.status != 'posted') continue;
      if (tx.occurredAt.toUtc().isBefore(sevenDaysAgoUtc)) continue;
      if (tx.type == 'income') {
        weeklyIncome += tx.amount;
      } else if (tx.type == 'expense') {
        weeklyExpense += tx.amount;
      }
    }

    final isMasked =
        forcePrivacyMask ??
        (PrivacyModeController.instance.enabled || !prefs.showTitleOnLockscreen);
    final incomeLabel = isMasked
        ? PrivacyModeController.maskedPlaceholder
        : formatRupiah(weeklyIncome);
    final expenseLabel = isMasked
        ? PrivacyModeController.maskedPlaceholder
        : formatRupiah(weeklyExpense);

    final summaryText = [
      'Ringkasan Mingguan Orbit (Senin 08:00 WIB)',
      '- Tugas selesai (7 hari): $completedLast7',
      '- Tugas aktif: $activeTasks (macet >5 hari: $computedStagnant)',
      '- Tagihan 7 hari ke depan: $upcomingBills',
      '- Pemasukan 7 hari: $incomeLabel',
      '- Pengeluaran 7 hari: $expenseLabel',
    ].join('\n');

    final lockscreenTitle = 'Orbit: Ringkasan Mingguan';
    final lockscreenBody = prefs.showTitleOnLockscreen && !isMasked
        ? '$completedLast7 tugas selesai, pengeluaran 7 hari $expenseLabel, $upcomingBills tagihan dekat.'
        : '$completedLast7 tugas selesai dan $activeTasks tugas aktif. Ketuk untuk melihat ringkasan aman.';

    return WeeklyDigestSummary(
      scheduledAtWib: nextMonday,
      completedTasksLast7Days: completedLast7,
      activeTasksCount: activeTasks,
      stagnantTasksCount: computedStagnant,
      upcomingBillsCount: upcomingBills,
      weeklyIncome: weeklyIncome,
      weeklyExpense: weeklyExpense,
      privacyMasked: isMasked,
      summaryText: summaryText,
      lockscreenTitle: lockscreenTitle,
      lockscreenBody: lockscreenBody,
    );
  }

  static Future<WeeklyDigestSummary> loadCurrentWeeklyDigest(
    AppDatabase db, {
    DateTime? nowUtc,
    bool? forcePrivacyMask,
  }) async {
    final prefs = await OrbitNotificationPrefs.load();
    final tasks = await db.select(db.localTasks).get();
    final bills = await db.select(db.localRecurringBills).get();
    final transactions = await db.select(db.localTransactions).get();
    return buildWeeklyDigestSummary(
      nowUtc: nowUtc ?? DateTime.now().toUtc(),
      prefs: prefs,
      tasks: tasks,
      bills: bills,
      transactions: transactions,
      forcePrivacyMask:
          forcePrivacyMask ?? PrivacyModeController.instance.enabled,
    );
  }

  static tz.TZDateTime? _computeNextBillDueDate(
    tz.TZDateTime nowJakarta,
    LocalRecurringBill bill,
  ) {
    final loc = nowJakarta.location;
    final today = tz.TZDateTime(loc, nowJakarta.year, nowJakarta.month, nowJakarta.day);
    if (bill.scheduleType == 'monthly') {
      final day = bill.scheduleValue.clamp(1, 28);
      var due = tz.TZDateTime(loc, nowJakarta.year, nowJakarta.month, day);
      if (due.isBefore(today)) {
        final nextMonth = nowJakarta.month == 12 ? 1 : nowJakarta.month + 1;
        final nextYear =
            nowJakarta.month == 12 ? nowJakarta.year + 1 : nowJakarta.year;
        due = tz.TZDateTime(loc, nextYear, nextMonth, day);
      }
      return due;
    } else if (bill.scheduleType == 'weekly') {
      final targetWeekday = bill.scheduleValue.clamp(1, 7);
      var delta = targetWeekday - today.weekday;
      if (delta < 0) delta += 7;
      return today.add(Duration(days: delta));
    }
    return null;
  }

  static String _kindLabel(String kind) {
    switch (kind.toLowerCase()) {
      case 'intern':
        return 'Magang';
      case 'freelance':
        return 'Proyek';
      case 'kuliah':
        return 'Kuliah';
      default:
        return 'Kegiatan';
    }
  }

  /// Menjadwalkan ulang semua notifikasi lokal Android berdasarkan Drift DB & preferensi.
  static Future<int> rescheduleAll(AppDatabase db) async {
    try {
      final prefs = await OrbitNotificationPrefs.load();
      final events = await db.select(db.localEvents).get();
      final tasks = await db.select(db.localTasks).get();
      final bills = await db.select(db.localRecurringBills).get();
      final budgets = await db.select(db.localBudgets).get();
      final transactions = await db.select(db.localTransactions).get();
      final categories = await db.select(db.localCategories).get();

      final nowUtc = DateTime.now().toUtc();
      final plan = evaluatePlan(
        nowUtc: nowUtc,
        prefs: prefs,
        events: events,
        tasks: tasks,
        bills: bills,
        budgets: budgets,
        transactions: transactions,
        categories: categories,
      );

      // Reset jadwal sebelumnya agar tidak menumpuk duplikat
      await NotificationService.cancelAll();

      for (final item in plan.scheduled) {
        await NotificationService.scheduleZonedNotification(
          id: item.id,
          title: item.title,
          body: item.body,
          scheduledAt: item.scheduledAt,
          channelId: item.channelId,
          channelName: item.channelName,
          channelDescription: item.channelDescription,
          payload: item.payload,
          matchDateTimeComponents: item.repeatComponents,
        );
      }

      await _dispatchImmediateAlertsOncePerDay(plan, prefs);
      return plan.scheduled.length;
    } catch (e) {
      debugPrint('NotificationSchedulerService.rescheduleAll error: $e');
      return 0;
    }
  }

  static Future<void> _dispatchImmediateAlertsOncePerDay(
    ReminderEvaluationResult plan,
    OrbitNotificationPrefs prefs,
  ) async {
    if (plan.immediateBillAlerts.isEmpty &&
        plan.immediateBudgetAlerts.isEmpty &&
        plan.scheduleConflicts.isEmpty &&
        plan.stagnantTasks.isEmpty) {
      return;
    }

    SharedPreferences? sp;
    try {
      sp = await SharedPreferences.getInstance();
    } catch (_) {}

    final nowJkt = NotificationService.toJakartaTz(DateTime.now());
    final todayKey =
        '${nowJkt.year}-${nowJkt.month.toString().padLeft(2, '0')}-${nowJkt.day.toString().padLeft(2, '0')}';

    for (final alert in plan.immediateBillAlerts) {
      final dedupKey = 'notif_sent_${todayKey}_bill_${alert.id}';
      if (sp?.getBool(dedupKey) == true) continue;
      await BillNotificationService.showBillDueNotification(
        id: alert.id,
        billName: alert.billName,
        amount: alert.amount,
        daysLeft: alert.daysLeft,
        showDetails:
            prefs.showTitleOnLockscreen && !PrivacyModeController.instance.enabled,
        billId: alert.billId,
      );
      await sp?.setBool(dedupKey, true);
    }

    for (final alert in plan.immediateBudgetAlerts) {
      final dedupKey =
          'notif_sent_${todayKey}_budget_${alert.id}_${alert.exceeded ? 'over' : 'warn'}';
      if (sp?.getBool(dedupKey) == true) continue;
      if (alert.exceeded) {
        await BillNotificationService.showBudgetExceededNotification(
          id: alert.id,
          categoryName: alert.categoryName,
          percentSpent: alert.percentSpent,
          showDetails:
              prefs.showTitleOnLockscreen &&
              !PrivacyModeController.instance.enabled,
          budgetId: alert.budgetId,
        );
      } else {
        await BillNotificationService.showBudgetWarningNotification(
          id: alert.id,
          categoryName: alert.categoryName,
          percentSpent: alert.percentSpent,
          showDetails:
              prefs.showTitleOnLockscreen &&
              !PrivacyModeController.instance.enabled,
          budgetId: alert.budgetId,
        );
      }
      await sp?.setBool(dedupKey, true);
    }

    for (final conflict in plan.scheduleConflicts) {
      final dedupKey = 'notif_sent_${todayKey}_conflict_${conflict.id}';
      if (sp?.getBool(dedupKey) == true) continue;
      final body = prefs.showTitleOnLockscreen
          ? 'Bentrok jadwal: "${conflict.firstTitle}" dan "${conflict.secondTitle}".'
          : 'Terdapat 2 agenda yang saling bertumpuk hari ini.';
      await NotificationService.showNotification(
        id: conflict.id,
        title: 'Peringatan Bentrok Jadwal',
        body: body,
        channelId: NotificationService.channelScheduleId,
        channelName: NotificationService.channelScheduleName,
        channelDescription: NotificationService.channelScheduleDesc,
        payload: NotificationPayload(
          type: 'event',
          targetTab: 1,
          agendaMode: 'jadwal',
          itemId: conflict.firstEventId,
        ),
      );
      await sp?.setBool(dedupKey, true);
    }

    for (final stagnant in plan.stagnantTasks) {
      final dedupKey = 'notif_sent_${todayKey}_stagnant_${stagnant.id}';
      if (sp?.getBool(dedupKey) == true) continue;
      final body = prefs.showTitleOnLockscreen
          ? '"${stagnant.title}" berstatus ${stagnant.status} selama ${stagnant.stagnantDays} hari.'
          : 'Ada tugas berstatus ${stagnant.status} yang belum diperbarui >5 hari.';
      await NotificationService.showNotification(
        id: stagnant.id,
        title: 'Pengingat Tugas Macet',
        body: body,
        channelId: NotificationService.channelScheduleId,
        channelName: NotificationService.channelScheduleName,
        channelDescription: NotificationService.channelScheduleDesc,
        payload: NotificationPayload(
          type: 'task',
          targetTab: 1,
          agendaMode: 'tugas',
          itemId: stagnant.taskId,
        ),
      );
      await sp?.setBool(dedupKey, true);
    }
  }
}
