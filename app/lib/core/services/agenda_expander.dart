import 'dart:convert';
import 'package:orbit_app/core/database/database.dart';

class LocalEventExceptionItem {
  final String id;
  final String eventId;
  final DateTime originalDate;
  final String action; // 'skip' or 'override'
  final DateTime? overrideStartsAt;
  final DateTime? overrideEndsAt;
  final String? overrideTitle;
  final String? overrideLocation;

  LocalEventExceptionItem({
    required this.id,
    required this.eventId,
    required this.originalDate,
    required this.action,
    this.overrideStartsAt,
    this.overrideEndsAt,
    this.overrideTitle,
    this.overrideLocation,
  });
}

class LocalAgendaItem {
  final String id;
  final String itemType; // 'event' or 'task'
  final String kind;
  final String title;
  final String? description;
  final String? projectId;
  final String? projectName;
  final String? projectColor;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool allDay;
  final String? location;
  final String status;
  final String? priority;
  final DateTime? dueAt;
  final bool dueIsDateOnly;
  final bool isOverdue;
  final int checklistTotal;
  final int checklistDone;
  final String? eventId;
  final bool isRecurring;
  final String? milestonePaymentId;

  LocalAgendaItem({
    required this.id,
    required this.itemType,
    required this.kind,
    required this.title,
    this.description,
    this.projectId,
    this.projectName,
    this.projectColor,
    this.startsAt,
    this.endsAt,
    this.allDay = false,
    this.location,
    required this.status,
    this.priority,
    this.dueAt,
    this.dueIsDateOnly = false,
    this.isOverdue = false,
    this.checklistTotal = 0,
    this.checklistDone = 0,
    this.eventId,
    this.isRecurring = false,
    this.milestonePaymentId,
  });
}

class AgendaExpander {
  static Duration _timeZoneOffset(String timezone, DateTime fallback) {
    if (timezone == 'Asia/Jakarta' || timezone == 'Asia/Pontianak') {
      return const Duration(hours: 7);
    } else if (timezone == 'Asia/Makassar') {
      return const Duration(hours: 8);
    } else if (timezone == 'Asia/Jayapura') {
      return const Duration(hours: 9);
    }
    return fallback.timeZoneOffset;
  }

  static List<LocalAgendaItem> expandEvents({
    required List<LocalEvent> events,
    required List<LocalEventExceptionItem> exceptions,
    required DateTime startDate,
    required DateTime endDate,
    String? kindFilter,
  }) {
    final startDay = DateTime.utc(startDate.year, startDate.month, startDate.day);
    final endDay = DateTime.utc(endDate.year, endDate.month, endDate.day);
    final results = <LocalAgendaItem>[];

    // Lookup exceptions berdasarkan event_id:YYYY-MM-DD
    final excMap = <String, LocalEventExceptionItem>{};
    for (final exc in exceptions) {
      final dStr = '${exc.originalDate.year.toString().padLeft(4, '0')}-${exc.originalDate.month.toString().padLeft(2, '0')}-${exc.originalDate.day.toString().padLeft(2, '0')}';
      excMap['${exc.eventId}:$dStr'] = exc;
    }

    for (final event in events) {
      if (kindFilter != null && event.kind != kindFilter) {
        continue;
      }

      final tzOffset = _timeZoneOffset(event.timezone, event.startsAt);
      final wallClockStart = event.startsAt.toUtc().add(tzOffset);
      final wallClockEnd = event.endsAt.toUtc().add(tzOffset);
      final evStartDate = DateTime.utc(wallClockStart.year, wallClockStart.month, wallClockStart.day);
      final evEndDate = DateTime.utc(wallClockEnd.year, wallClockEnd.month, wallClockEnd.day);

      if (event.recurrence == null || event.recurrence!.isEmpty) {
        // 1. Non-recurring event
        if (evStartDate.isBefore(endDay.add(const Duration(days: 1))) &&
            evEndDate.isAfter(startDay.subtract(const Duration(days: 1)))) {
          results.add(LocalAgendaItem(
            id: event.id,
            itemType: 'event',
            kind: event.kind,
            title: event.title,
            description: event.description,
            projectId: event.projectId,
            startsAt: event.startsAt,
            endsAt: event.endsAt,
            allDay: event.allDay,
            location: event.location,
            status: 'scheduled',
            eventId: event.id,
            isRecurring: false,
          ));
        }
      } else {
        // 2. Recurring event
        Map<String, dynamic> r;
        try {
          r = jsonDecode(event.recurrence!) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }

        final freq = r['freq'] as String?;
        final byWeekday = (r['byweekday'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList();
        final untilStr = r['until'] as String?;
        DateTime? untilDate;
        if (untilStr != null) {
          final u = DateTime.tryParse(untilStr);
          if (u != null) {
            untilDate = DateTime.utc(u.year, u.month, u.day);
          }
        }

        final duration = event.endsAt.difference(event.startsAt);

        // Loop hari kalender dari max(startDay, evStartDate) ke endDay
        var curr = startDay.isBefore(evStartDate) ? evStartDate : startDay;
        while (!curr.isAfter(endDay)) {
          if (untilDate != null && curr.isAfter(untilDate)) {
            break;
          }

          bool matches = false;
          if (freq == 'daily') {
            matches = true;
          } else if (freq == 'weekly') {
            final isoDow = curr.weekday; // 1 = Monday ... 7 = Sunday
            if (byWeekday == null || byWeekday.isEmpty) {
              matches = (isoDow == wallClockStart.weekday);
            } else {
              matches = byWeekday.contains(isoDow) || byWeekday.contains(isoDow % 7);
            }
          } else if (freq == 'monthly') {
            matches = (curr.day == wallClockStart.day);
          }

          if (matches) {
            final dStr = '${curr.year.toString().padLeft(4, '0')}-${curr.month.toString().padLeft(2, '0')}-${curr.day.toString().padLeft(2, '0')}';
            final exc = excMap['${event.id}:$dStr'];

            if (exc != null && exc.action == 'skip') {
              curr = curr.add(const Duration(days: 1));
              continue;
            }

            final instanceStartsAt = exc?.overrideStartsAt ??
                DateTime.utc(
                  curr.year,
                  curr.month,
                  curr.day,
                  wallClockStart.hour,
                  wallClockStart.minute,
                  wallClockStart.second,
                ).subtract(tzOffset);

            final instanceEndsAt = exc?.overrideEndsAt ?? instanceStartsAt.add(duration);

            results.add(LocalAgendaItem(
              id: '${event.id}_$dStr',
              itemType: 'event',
              kind: event.kind,
              title: exc?.overrideTitle ?? event.title,
              description: event.description,
              projectId: event.projectId,
              startsAt: instanceStartsAt,
              endsAt: instanceEndsAt,
              allDay: event.allDay,
              location: exc?.overrideLocation ?? event.location,
              status: 'scheduled',
              eventId: event.id,
              isRecurring: true,
            ));
          }

          curr = curr.add(const Duration(days: 1));
        }
      }
    }

    results.sort((a, b) {
      final aTime = a.startsAt ?? DateTime(1970);
      final bTime = b.startsAt ?? DateTime(1970);
      return aTime.compareTo(bTime);
    });

    return results;
  }
}
