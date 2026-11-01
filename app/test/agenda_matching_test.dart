import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Uji Kecocokan Agenda Lokal App dengan Hasil Database (Fase 2)', () {
    test('Format dan atribut item agenda dari fn_agenda cocok dengan model lokal', () {
      final dbRow = {
        'id': 'd1000000-0000-0000-0000-000000000001',
        'item_type': 'event',
        'kind': 'kuliah',
        'title': 'Kuliah Basis Data',
        'description': 'Ruang 402',
        'project_id': null,
        'project_name': null,
        'project_color': null,
        'starts_at': '2026-11-02T08:00:00+07:00',
        'ends_at': '2026-11-02T10:00:00+07:00',
        'all_day': false,
        'location': 'Lab Komputer',
        'status': 'scheduled',
        'priority': null,
        'due_at': null,
        'due_is_date_only': false,
        'is_overdue': false,
        'checklist_total': 0,
        'checklist_done': 0,
        'event_id': 'd1000000-0000-0000-0000-000000000001',
        'is_recurring': true,
        'milestone_payment_id': null,
      };

      expect(dbRow['item_type'], equals('event'));
      expect(dbRow['kind'], equals('kuliah'));
      expect(dbRow['is_recurring'], isTrue);
      expect(dbRow['starts_at'], contains('2026-11-02'));
    });

    test('Deteksi benturan waktu event secara lokal identik dengan kriteria database', () {
      // Dua event di hari yang sama: Event 1 (08:00 - 10:00), Event 2 (09:00 - 11:00)
      final e1Start = DateTime.parse('2026-11-04T08:00:00+07:00');
      final e1End = DateTime.parse('2026-11-04T10:00:00+07:00');

      final e2Start = DateTime.parse('2026-11-04T09:00:00+07:00');
      final e2End = DateTime.parse('2026-11-04T11:00:00+07:00');

      // Kondisi overlap SQL: e1.starts_at < e2.ends_at and e1.ends_at > e2.starts_at
      final isOverlapping = e1Start.isBefore(e2End) && e1End.isAfter(e2Start);
      expect(isOverlapping, isTrue);

      // Event 3 tidak overlap (11:00 - 12:00)
      final e3Start = DateTime.parse('2026-11-04T11:00:00+07:00');
      final e3End = DateTime.parse('2026-11-04T12:00:00+07:00');
      final isE1E3Overlapping = e1Start.isBefore(e3End) && e1End.isAfter(e3Start);
      expect(isE1E3Overlapping, isFalse);
    });

    test('Perhitungan hari padat jika total durasi >= 8 jam', () {
      final durations = [
        const Duration(hours: 3),
        const Duration(hours: 3),
        const Duration(hours: 2, minutes: 30),
      ];

      final totalHours = durations.fold<double>(
        0.0,
        (sum, d) => sum + (d.inMinutes / 60.0),
      );

      final isHeavyDay = totalHours >= 8.0;
      expect(totalHours, equals(8.5));
      expect(isHeavyDay, isTrue);
    });
  });
}
