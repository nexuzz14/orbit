import 'package:drift/drift.dart';
import 'package:orbit_app/core/database/database.dart';

class IcsParsedEvent {
  final String uid;
  final String title;
  final String? description;
  final String? location;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool allDay;
  final String timezone;
  final String? recurrence;
  final String kind;
  final String externalProvider;

  const IcsParsedEvent({
    required this.uid,
    required this.title,
    this.description,
    this.location,
    required this.startsAt,
    required this.endsAt,
    required this.allDay,
    this.timezone = 'Asia/Jakarta',
    this.recurrence,
    this.kind = 'pribadi',
    this.externalProvider = 'google',
  });

  String get externalEventId => uid;

  LocalEventsCompanion toLocalEventCompanion({
    required String id,
    required String workspaceId,
    String? kindOverride,
    String? projectId,
  }) {
    final normalizedKind = _normalizeKind(kindOverride ?? kind);
    return LocalEventsCompanion.insert(
      id: id,
      workspaceId: workspaceId,
      projectId: Value(projectId),
      kind: normalizedKind,
      title: title,
      description: Value(description),
      location: Value(location),
      startsAt: startsAt,
      endsAt: endsAt,
      allDay: Value(allDay),
      timezone: Value(timezone),
      recurrence: Value(recurrence),
      externalProvider: Value(externalProvider),
      externalEventId: Value(uid),
      lastSyncedAt: Value(DateTime.now().toUtc()),
    );
  }

  Map<String, dynamic> toSyncPayload({
    required String id,
    required String workspaceId,
    String? kindOverride,
    String? projectId,
  }) {
    final normalizedKind = _normalizeKind(kindOverride ?? kind);
    return {
      'id': id,
      'workspace_id': workspaceId,
      if (projectId != null) 'project_id': projectId,
      'kind': normalizedKind,
      'title': title,
      'description': description,
      'location': location,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'all_day': allDay,
      'timezone': timezone,
      'recurrence': recurrence,
      'external_provider': externalProvider,
      'external_event_id': uid,
      'last_synced_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  static String _normalizeKind(String value) {
    switch (value.toLowerCase().trim()) {
      case 'intern':
      case 'freelance':
      case 'kuliah':
      case 'pribadi':
        return value.toLowerCase().trim();
      case 'personal':
        return 'pribadi';
      default:
        return 'pribadi';
    }
  }
}

class IcsCalendarService {
  const IcsCalendarService._();

  static const String sampleGoogleCalendarIcs =
      'BEGIN:VCALENDAR\r\n'
      'VERSION:2.0\r\n'
      'PRODID:-//Google Inc//Google Calendar 70.9054//EN\r\n'
      'BEGIN:VEVENT\r\n'
      'UID:sample-sync-sprint@google.com\r\n'
      'DTSTAMP:20261115T010000Z\r\n'
      'DTSTART:20261116T030000Z\r\n'
      'DTEND:20261116T040000Z\r\n'
      'SUMMARY:Sinkronisasi Sprint Klien\r\n'
      'DESCRIPTION:Review deliverable minggu kedua bersama tim\r\n'
      'LOCATION:Google Meet\r\n'
      'END:VEVENT\r\n'
      'BEGIN:VEVENT\r\n'
      'UID:sample-allday-deadline@google.com\r\n'
      'DTSTAMP:20261115T010000Z\r\n'
      'DTSTART;VALUE=DATE:20261118\r\n'
      'DTEND;VALUE=DATE:20261119\r\n'
      'SUMMARY:Pengumpulan Tugas Akhir Bab 3\r\n'
      'DESCRIPTION:Unggah draf ke portal akademik\r\n'
      'END:VEVENT\r\n'
      'END:VCALENDAR\r\n';

  /// Mengekspor daftar [LocalEvent] aktif menjadi string iCalendar RFC 5545 valid.
  static String exportEventsToIcs(
    List<LocalEvent> events, {
    String prodId = '-//Orbit//Orbit Calendar 2.0//ID',
    String calendarName = 'Orbit Agenda',
    DateTime? nowOverride,
  }) {
    final activeEvents =
        events.where((e) => e.deletedAt == null).toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final stamp = _formatUtcTimestamp((nowOverride ?? DateTime.now()).toUtc());
    final lines = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:${_escapeText(prodId)}',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'X-WR-CALNAME:${_escapeText(calendarName)}',
    ];

    for (final event in activeEvents) {
      final uid = (event.externalEventId != null &&
              event.externalEventId!.trim().isNotEmpty)
          ? event.externalEventId!.trim()
          : '${event.id}@orbit.app';
      lines.add('BEGIN:VEVENT');
      lines.add('UID:$uid');
      lines.add('DTSTAMP:$stamp');
      if (event.allDay) {
        final startDate = DateTime(
          event.startsAt.year,
          event.startsAt.month,
          event.startsAt.day,
        );
        var endDate = DateTime(
          event.endsAt.year,
          event.endsAt.month,
          event.endsAt.day,
        );
        if (!endDate.isAfter(startDate)) {
          endDate = startDate.add(const Duration(days: 1));
        } else {
          // RFC 5545 VALUE=DATE menggunakan DTEND eksklusif.
          // Jika endsAt berakhir pada hari yang sama (mis. 23:59), majukan 1 hari.
          endDate = endDate.add(const Duration(days: 1));
        }
        lines.add('DTSTART;VALUE=DATE:${_formatDateOnly(startDate)}');
        lines.add('DTEND;VALUE=DATE:${_formatDateOnly(endDate)}');
      } else {
        final startUtc = event.startsAt.toUtc();
        final rawEndUtc = event.endsAt.toUtc();
        final endUtc = rawEndUtc.isAfter(startUtc)
            ? rawEndUtc
            : startUtc.add(const Duration(hours: 1));
        lines.add('DTSTART:${_formatUtcTimestamp(startUtc)}');
        lines.add('DTEND:${_formatUtcTimestamp(endUtc)}');
      }
      lines.add('SUMMARY:${_escapeText(event.title)}');
      if (event.description != null && event.description!.trim().isNotEmpty) {
        lines.add('DESCRIPTION:${_escapeText(event.description!.trim())}');
      }
      if (event.location != null && event.location!.trim().isNotEmpty) {
        lines.add('LOCATION:${_escapeText(event.location!.trim())}');
      }
      if (event.recurrence != null && event.recurrence!.trim().isNotEmpty) {
        final rrule = event.recurrence!.trim();
        lines.add(rrule.startsWith('RRULE:') ? rrule : 'RRULE:$rrule');
      }
      lines.add('X-ORBIT-KIND:${event.kind}');
      lines.add('END:VEVENT');
    }

    lines.add('END:VCALENDAR');
    final folded = <String>[];
    for (final line in lines) {
      folded.addAll(_foldLine(line));
    }
    return '${folded.join('\r\n')}\r\n';
  }

  /// Mem-parse string `.ics` RFC 5545 menjadi daftar [IcsParsedEvent] siap simpan ke Drift.
  static List<IcsParsedEvent> parseIcsEvents(
    String rawIcs, {
    required String workspaceId,
  }) {
    if (rawIcs.trim().isEmpty) return const [];
    final unfolded = _unfoldLines(rawIcs);
    final results = <IcsParsedEvent>[];

    bool inEvent = false;
    Map<String, _IcsProperty> props = {};

    for (final rawLine in unfolded) {
      final line = rawLine.trimRight();
      if (line.isEmpty) continue;
      final upper = line.toUpperCase();
      if (upper == 'BEGIN:VEVENT') {
        inEvent = true;
        props = {};
        continue;
      }
      if (upper == 'END:VEVENT') {
        if (inEvent) {
          final parsed = _buildEventFromProps(props, results.length);
          if (parsed != null) {
            results.add(parsed);
          }
        }
        inEvent = false;
        props = {};
        continue;
      }
      if (!inEvent) continue;

      final prop = _parseProperty(line);
      if (prop != null) {
        props[prop.name] = prop;
      }
    }

    return results;
  }

  static IcsParsedEvent? _buildEventFromProps(
    Map<String, _IcsProperty> props,
    int index,
  ) {
    final dtStartProp = props['DTSTART'];
    if (dtStartProp == null) return null;

    final startParsed = _parseIcsDate(dtStartProp);
    if (startParsed == null) return null;

    final dtEndProp = props['DTEND'];
    DateTime endsAt;
    if (dtEndProp != null) {
      final endParsed = _parseIcsDate(dtEndProp);
      if (endParsed != null) {
        if (startParsed.allDay && endParsed.allDay) {
          // DTEND pada VALUE=DATE bersifat eksklusif menurut RFC 5545.
          final inclusiveEndDay = endParsed.dateTime.subtract(
            const Duration(days: 1),
          );
          final safeEndDay = inclusiveEndDay.isBefore(startParsed.dateTime)
              ? startParsed.dateTime
              : inclusiveEndDay;
          endsAt = DateTime(
            safeEndDay.year,
            safeEndDay.month,
            safeEndDay.day,
            23,
            59,
            59,
          );
        } else {
          endsAt = endParsed.dateTime;
        }
      } else {
        endsAt = startParsed.allDay
            ? DateTime(
                startParsed.dateTime.year,
                startParsed.dateTime.month,
                startParsed.dateTime.day,
                23,
                59,
                59,
              )
            : startParsed.dateTime.add(const Duration(hours: 1));
      }
    } else {
      endsAt = startParsed.allDay
          ? DateTime(
              startParsed.dateTime.year,
              startParsed.dateTime.month,
              startParsed.dateTime.day,
              23,
              59,
              59,
            )
          : startParsed.dateTime.add(const Duration(hours: 1));
    }

    final rawSummary = props['SUMMARY']?.value;
    final title = (rawSummary != null && _unescapeText(rawSummary).trim().isNotEmpty)
        ? _unescapeText(rawSummary).trim()
        : 'Acara Kalender';

    final rawDesc = props['DESCRIPTION']?.value;
    final description = (rawDesc != null && _unescapeText(rawDesc).trim().isNotEmpty)
        ? _unescapeText(rawDesc).trim()
        : null;

    final rawLoc = props['LOCATION']?.value;
    final location = (rawLoc != null && _unescapeText(rawLoc).trim().isNotEmpty)
        ? _unescapeText(rawLoc).trim()
        : null;

    final rawUid = props['UID']?.value.trim();
    final uid = (rawUid != null && rawUid.isNotEmpty)
        ? rawUid
        : 'ics-${startParsed.dateTime.millisecondsSinceEpoch}-$index@google.com';

    final tzid = dtStartProp.params['TZID'];
    final timezone = (tzid != null && tzid.isNotEmpty) ? tzid : 'Asia/Jakarta';
    final recurrence = props['RRULE']?.value.trim();
    final orbitKind = props['X-ORBIT-KIND']?.value.trim() ?? 'pribadi';

    return IcsParsedEvent(
      uid: uid,
      title: title,
      description: description,
      location: location,
      startsAt: startParsed.dateTime,
      endsAt: endsAt,
      allDay: startParsed.allDay,
      timezone: timezone,
      recurrence: (recurrence != null && recurrence.isNotEmpty) ? recurrence : null,
      kind: IcsParsedEvent._normalizeKind(orbitKind),
      externalProvider: 'google',
    );
  }

  static List<String> _unfoldLines(String raw) {
    final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rawLines = normalized.split('\n');
    final unfolded = <String>[];
    for (final line in rawLines) {
      if ((line.startsWith(' ') || line.startsWith('\t')) &&
          unfolded.isNotEmpty) {
        unfolded[unfolded.length - 1] =
            '${unfolded.last}${line.substring(1)}';
      } else {
        unfolded.add(line);
      }
    }
    return unfolded;
  }

  static List<String> _foldLine(String line) {
    const maxLen = 75;
    if (line.length <= maxLen) return [line];
    final out = <String>[line.substring(0, maxLen)];
    var offset = maxLen;
    while (offset < line.length) {
      final end = (offset + (maxLen - 1)) < line.length
          ? offset + (maxLen - 1)
          : line.length;
      out.add(' ${line.substring(offset, end)}');
      offset = end;
    }
    return out;
  }

  static _IcsProperty? _parseProperty(String line) {
    final colonIndex = line.indexOf(':');
    if (colonIndex <= 0) return null;
    final left = line.substring(0, colonIndex);
    final value = line.substring(colonIndex + 1);
    final parts = left.split(';');
    final name = parts.first.trim().toUpperCase();
    final params = <String, String>{};
    for (var i = 1; i < parts.length; i++) {
      final eq = parts[i].indexOf('=');
      if (eq > 0) {
        final k = parts[i].substring(0, eq).trim().toUpperCase();
        final v = parts[i].substring(eq + 1).trim();
        params[k] = v;
      }
    }
    return _IcsProperty(name: name, params: params, value: value);
  }

  static _ParsedIcsDate? _parseIcsDate(_IcsProperty prop) {
    final val = prop.value.trim();
    if (val.isEmpty) return null;
    final valueParam = prop.params['VALUE']?.toUpperCase();

    // Format tanggal penuh YYYYMMDD (all-day)
    if (valueParam == 'DATE' || RegExp(r'^\d{8}$').hasMatch(val)) {
      final digits = val.replaceAll('-', '');
      if (digits.length < 8) return null;
      final year = int.tryParse(digits.substring(0, 4));
      final month = int.tryParse(digits.substring(4, 6));
      final day = int.tryParse(digits.substring(6, 8));
      if (year == null || month == null || day == null) return null;
      return _ParsedIcsDate(
        dateTime: DateTime(year, month, day),
        allDay: true,
      );
    }

    // Format datetime RFC 5545: YYYYMMDDTHHMMSS(Z)
    final match = RegExp(
      r'^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z?)$',
      caseSensitive: false,
    ).firstMatch(val);
    if (match != null) {
      final year = int.parse(match.group(1)!);
      final month = int.parse(match.group(2)!);
      final day = int.parse(match.group(3)!);
      final hour = int.parse(match.group(4)!);
      final minute = int.parse(match.group(5)!);
      final second = int.parse(match.group(6)!);
      final isUtc = match.group(7)!.toUpperCase() == 'Z';
      final dt = isUtc
          ? DateTime.utc(year, month, day, hour, minute, second).toLocal()
          : DateTime(year, month, day, hour, minute, second);
      return _ParsedIcsDate(dateTime: dt, allDay: false);
    }

    final iso = DateTime.tryParse(val);
    if (iso != null) {
      return _ParsedIcsDate(
        dateTime: iso.isUtc ? iso.toLocal() : iso,
        allDay: false,
      );
    }
    return null;
  }

  static String _formatDateOnly(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y$m$d';
  }

  static String _formatUtcTimestamp(DateTime utc) {
    final u = utc.isUtc ? utc : utc.toUtc();
    final y = u.year.toString().padLeft(4, '0');
    final m = u.month.toString().padLeft(2, '0');
    final d = u.day.toString().padLeft(2, '0');
    final hh = u.hour.toString().padLeft(2, '0');
    final mm = u.minute.toString().padLeft(2, '0');
    final ss = u.second.toString().padLeft(2, '0');
    return '$y$m${d}T$hh$mm${ss}Z';
  }

  static String _escapeText(String input) {
    return input
        .replaceAll('\\', '\\\\')
        .replaceAll('\r\n', '\\n')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\n')
        .replaceAll(';', '\\;')
        .replaceAll(',', '\\,');
  }

  static String _unescapeText(String input) {
    final out = StringBuffer();
    var i = 0;
    while (i < input.length) {
      final ch = input[i];
      if (ch == '\\' && i + 1 < input.length) {
        final next = input[i + 1];
        if (next == 'n' || next == 'N') {
          out.write('\n');
          i += 2;
          continue;
        }
        if (next == ',' || next == ';' || next == '\\') {
          out.write(next);
          i += 2;
          continue;
        }
      }
      out.write(ch);
      i++;
    }
    return out.toString();
  }
}

class _IcsProperty {
  final String name;
  final Map<String, String> params;
  final String value;

  const _IcsProperty({
    required this.name,
    required this.params,
    required this.value,
  });
}

class _ParsedIcsDate {
  final DateTime dateTime;
  final bool allDay;

  const _ParsedIcsDate({
    required this.dateTime,
    required this.allDay,
  });
}
