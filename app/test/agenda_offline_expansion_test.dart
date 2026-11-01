import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_app/core/database/database.dart';
import 'package:orbit_app/core/services/agenda_expander.dart';

void main() {
  test('Uji Paritas Ekspansi Agenda Offline dengan Kasus Bersama (Fase 2)', () async {
    // Baca file fixture bersama
    final fixtureFile = File('../packages/test_fixtures/agenda_cases.json');
    final fixtureJson = jsonDecode(await fixtureFile.readAsString()) as Map<String, dynamic>;

    final testRange = fixtureJson['test_range'] as Map<String, dynamic>;
    final startDate = DateTime.parse(testRange['start_date'] as String);
    final endDate = DateTime.parse(testRange['end_date'] as String);

    final rawEvents = fixtureJson['events'] as List<dynamic>;
    final events = rawEvents.map((e) {
      final m = e as Map<String, dynamic>;
      return LocalEvent(
        id: m['id'] as String,
        workspaceId: 'w1',
        kind: m['kind'] as String,
        title: m['title'] as String,
        startsAt: DateTime.parse(m['starts_at'] as String),
        endsAt: DateTime.parse(m['ends_at'] as String),
        allDay: false,
        timezone: m['timezone'] as String? ?? 'Asia/Jakarta',
        recurrence: m['recurrence'] != null ? jsonEncode(m['recurrence']) : null,
      );
    }).toList();

    final rawExceptions = fixtureJson['exceptions'] as List<dynamic>;
    final exceptions = rawExceptions.map((ex) {
      final m = ex as Map<String, dynamic>;
      return LocalEventExceptionItem(
        id: 'exc_${m['original_date']}',
        eventId: m['event_id'] as String,
        originalDate: DateTime.parse(m['original_date'] as String),
        action: m['action'] as String,
        overrideStartsAt: m['override_starts_at'] != null ? DateTime.parse(m['override_starts_at'] as String) : null,
        overrideEndsAt: m['override_ends_at'] != null ? DateTime.parse(m['override_ends_at'] as String) : null,
        overrideTitle: m['override_title'] as String?,
        overrideLocation: m['override_location'] as String?,
      );
    }).toList();

    // Jalankan ekspansi offline
    final expanded = AgendaExpander.expandEvents(
      events: events,
      exceptions: exceptions,
      startDate: startDate,
      endDate: endDate,
    );

    final expectedOccurrences = fixtureJson['expected_occurrences'] as List<dynamic>;

    // 1. Jumlah item hasil ekspansi harus identik dengan ekspektasi
    expect(expanded.length, equals(expectedOccurrences.length));

    // 2. Setiap item yang diekspansi harus cocok secara urutan tanggal dan judul
    for (int i = 0; i < expectedOccurrences.length; i++) {
      final exp = expectedOccurrences[i] as Map<String, dynamic>;
      final actual = expanded[i];

      expect(actual.eventId, equals(exp['event_id']));
      expect(actual.title, equals(exp['title']));
      expect(actual.kind, equals(exp['kind']));

      final localTime = actual.startsAt!.toUtc().add(const Duration(hours: 7));
      final actualDateStr = '${localTime.year.toString().padLeft(4, '0')}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')}';
      expect(actualDateStr, equals(exp['date']));

      if (exp.containsKey('location')) {
        expect(actual.location, equals(exp['location']));
      }
    }
  });
}
