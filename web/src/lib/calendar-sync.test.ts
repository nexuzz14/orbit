import test from 'node:test';
import assert from 'node:assert/strict';
import {
  buildMonthlyCalendarGrid,
  buildTimelineSlots,
  exportEventsToIcs,
  parseIcsContent,
} from './calendar-sync';

test('Ekspor dan impor ulang .ics menjaga judul, deskripsi, lokasi, dan status seharian', () => {
  const ics = exportEventsToIcs(
    [
      {
        id: 'ev-1',
        title: 'Kuliah Struktur Data; Kelas A, Lab 2',
        description: 'Bawa laptop\ndan catatan modul 4',
        location: 'Gedung C, Ruang 301',
        starts_at: '2026-11-16T01:00:00Z',
        ends_at: '2026-11-16T03:00:00Z',
        all_day: false,
      },
      {
        id: 'ev-2',
        title: 'Libur Nasional',
        description: null,
        location: null,
        starts_at: '2026-11-17T00:00:00+07:00',
        ends_at: '2026-11-17T23:59:59+07:00',
        all_day: true,
      },
    ],
    { now: new Date('2026-11-15T00:00:00Z') }
  );

  assert.ok(ics.includes('BEGIN:VCALENDAR'));
  assert.ok(ics.includes('DTSTART;VALUE=DATE:20261117'));
  assert.ok(ics.includes('DTEND;VALUE=DATE:20261118'));

  const parsed = parseIcsContent(ics);
  assert.equal(parsed.length, 2);

  assert.equal(parsed[0].uid, 'ev-1@orbit.local');
  assert.equal(parsed[0].title, 'Kuliah Struktur Data; Kelas A, Lab 2');
  assert.equal(parsed[0].description, 'Bawa laptop\ndan catatan modul 4');
  assert.equal(parsed[0].location, 'Gedung C, Ruang 301');
  assert.equal(parsed[0].all_day, false);
  assert.equal(parsed[0].starts_at, '2026-11-16T01:00:00.000Z');
  assert.equal(parsed[0].ends_at, '2026-11-16T03:00:00.000Z');

  assert.equal(parsed[1].title, 'Libur Nasional');
  assert.equal(parsed[1].all_day, true);
});

test('Parser .ics mendukung baris terlipat (folded lines) dan TZID=Asia/Jakarta', () => {
  const sampleIcs = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'BEGIN:VEVENT',
    'UID:custom-wib-99@example.com',
    'SUMMARY:Rapat Proyek ',
    ' Klien Enterprise',
    'DTSTART;TZID=Asia/Jakarta:20261120T090000',
    'DTEND;TZID=Asia/Jakarta:20261120T103000',
    'END:VEVENT',
    'END:VCALENDAR',
  ].join('\r\n');

  const parsed = parseIcsContent(sampleIcs);
  assert.equal(parsed.length, 1);
  assert.equal(parsed[0].title, 'Rapat Proyek Klien Enterprise');
  assert.equal(parsed[0].starts_at, '2026-11-20T02:00:00.000Z');
  assert.equal(parsed[0].ends_at, '2026-11-20T03:30:00.000Z');
  assert.equal(parsed[0].all_day, false);
});

test('Grid kalender bulanan dimulai Senin dan mengelompokkan event + tugas per tanggal WIB', () => {
  // November 2026: 1 Nov 2026 adalah Minggu -> offset Senin = 6
  const cells = buildMonthlyCalendarGrid(
    2026,
    10,
    [
      {
        id: 'e1',
        item_type: 'event',
        title: 'Standup Pagi',
        kind: 'freelance',
        starts_at: '2026-11-02T09:00:00+07:00',
        ends_at: '2026-11-02T09:30:00+07:00',
        all_day: false,
      },
      {
        id: 't1',
        item_type: 'task',
        title: 'Kirim Proposal',
        kind: 'freelance',
        starts_at: '2026-11-02T17:00:00+07:00',
        ends_at: null,
        all_day: false,
        status: 'todo',
      },
    ],
    '2026-11-02'
  );

  assert.equal(cells.length, 42);
  assert.equal(cells[0].dateKey, '2026-10-26');
  assert.equal(cells[0].inCurrentMonth, false);

  const nov2 = cells.find((c) => c.dateKey === '2026-11-02');
  assert.ok(nov2);
  assert.equal(nov2.isToday, true);
  assert.equal(nov2.inCurrentMonth, true);
  assert.equal(nov2.eventCount, 1);
  assert.equal(nov2.taskCount, 1);
  assert.equal(nov2.items.length, 2);
});

test('Linimasa mendeteksi slot bentrok dan membagi lane paralel', () => {
  const result = buildTimelineSlots(
    [
      {
        id: 'a1',
        item_type: 'event',
        title: 'Kuliah Pagi',
        kind: 'kuliah',
        starts_at: '2026-11-16T08:00:00+07:00',
        ends_at: '2026-11-16T10:00:00+07:00',
        all_day: false,
      },
      {
        id: 'a2',
        item_type: 'event',
        title: 'Sync Magang',
        kind: 'intern',
        starts_at: '2026-11-16T09:00:00+07:00',
        ends_at: '2026-11-16T10:30:00+07:00',
        all_day: false,
      },
      {
        id: 'a3',
        item_type: 'event',
        title: 'Ulang Tahun Klien',
        kind: 'personal',
        starts_at: '2026-11-16T00:00:00+07:00',
        ends_at: '2026-11-16T23:59:59+07:00',
        all_day: true,
      },
    ],
    '2026-11-16',
    6,
    23
  );

  assert.equal(result.allDayItems.length, 1);
  assert.equal(result.blocks.length, 2);
  assert.equal(result.conflicts.length, 1);
  assert.equal(result.blocks[0].hasConflict, true);
  assert.equal(result.blocks[1].hasConflict, true);
  assert.equal(result.blocks[0].laneCount, 2);
  assert.notEqual(result.blocks[0].lane, result.blocks[1].lane);
});
