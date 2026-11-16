export interface IcsExportEvent {
  id: string;
  uid?: string | null;
  title: string;
  description?: string | null;
  location?: string | null;
  starts_at: string;
  ends_at?: string | null;
  all_day?: boolean | null;
}

export interface ParsedIcsEvent {
  uid: string | null;
  title: string;
  description: string | null;
  location: string | null;
  starts_at: string;
  ends_at: string;
  all_day: boolean;
}

export interface CalendarGridInputItem {
  id: string;
  item_type: 'event' | 'task';
  title: string;
  kind: string;
  starts_at: string | null;
  ends_at: string | null;
  all_day: boolean;
  location?: string | null;
  status?: string | null;
  priority?: string | null;
}

export interface CalendarGridCell {
  dateKey: string;
  dayOfMonth: number;
  inCurrentMonth: boolean;
  isToday: boolean;
  items: CalendarGridInputItem[];
  eventCount: number;
  taskCount: number;
}

export interface TimelineBlock {
  item: CalendarGridInputItem;
  startMinutes: number;
  endMinutes: number;
  durationMinutes: number;
  topPercent: number;
  heightPercent: number;
  lane: number;
  laneCount: number;
  hasConflict: boolean;
}

export interface TimelineConflictPair {
  firstId: string;
  firstTitle: string;
  secondId: string;
  secondTitle: string;
  overlapStartMinutes: number;
  overlapEndMinutes: number;
}

export interface TimelineDayResult {
  dateKey: string;
  allDayItems: CalendarGridInputItem[];
  blocks: TimelineBlock[];
  conflicts: TimelineConflictPair[];
}

const WIB_OFFSET_MS = 7 * 60 * 60 * 1000;

function pad2(n: number): string {
  return String(n).padStart(2, '0');
}

/**
 * Mengembalikan string tanggal YYYY-MM-DD pada zona waktu WIB (Asia/Jakarta).
 */
export function toWibDateKey(input: string | Date): string {
  const date = typeof input === 'string' ? new Date(input) : input;
  if (Number.isNaN(date.getTime())) {
    return new Date(Date.now() + WIB_OFFSET_MS).toISOString().slice(0, 10);
  }
  const shifted = new Date(date.getTime() + WIB_OFFSET_MS);
  return shifted.toISOString().slice(0, 10);
}

/**
 * Mengembalikan total menit sejak 00:00 WIB pada tanggal tersebut.
 */
export function toWibMinutes(input: string | Date): number {
  const date = typeof input === 'string' ? new Date(input) : input;
  if (Number.isNaN(date.getTime())) return 0;
  const shifted = new Date(date.getTime() + WIB_OFFSET_MS);
  return shifted.getUTCHours() * 60 + shifted.getUTCMinutes();
}

/**
 * Format jam WIB HH:mm.
 */
export function formatWibTime(input: string | Date): string {
  const date = typeof input === 'string' ? new Date(input) : input;
  if (Number.isNaN(date.getTime())) return '--:--';
  const shifted = new Date(date.getTime() + WIB_OFFSET_MS);
  return `${pad2(shifted.getUTCHours())}:${pad2(shifted.getUTCMinutes())}`;
}

export function escapeIcsText(value: string): string {
  return value
    .replace(/\\/g, '\\\\')
    .replace(/\r\n/g, '\n')
    .replace(/\r/g, '\n')
    .replace(/\n/g, '\\n')
    .replace(/;/g, '\\;')
    .replace(/,/g, '\\,');
}

export function unescapeIcsText(value: string): string {
  return value
    .replace(/\\n/gi, '\n')
    .replace(/\\,/g, ',')
    .replace(/\\;/g, ';')
    .replace(/\\\\/g, '\\');
}

export function formatIcsDateTimeUtc(input: string | Date): string {
  const date = typeof input === 'string' ? new Date(input) : input;
  const iso = date.toISOString();
  // YYYY-MM-DDTHH:mm:ss.sssZ -> YYYYMMDDTHHMMSSZ
  return iso.replace(/[-:]/g, '').replace(/\.\d{3}Z$/, 'Z');
}

export function formatIcsDateWib(input: string | Date): string {
  return toWibDateKey(input).replace(/-/g, '');
}

function addDaysToDateKey(dateKey: string, deltaDays: number): string {
  const [y, m, d] = dateKey.split('-').map(Number);
  const dt = new Date(Date.UTC(y, m - 1, d + deltaDays));
  return dt.toISOString().slice(0, 10);
}

/**
 * Menghasilkan konten file .ics standar RFC 5545 dari daftar jadwal.
 */
export function exportEventsToIcs(
  events: IcsExportEvent[],
  options?: { calendarName?: string; now?: Date }
): string {
  const now = options?.now ?? new Date();
  const dtstamp = formatIcsDateTimeUtc(now);
  const calName = options?.calendarName?.trim() || 'Orbit Agenda';

  const lines: string[] = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Orbit//Agenda v2//ID',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    `X-WR-CALNAME:${escapeIcsText(calName)}`,
    'X-WR-TIMEZONE:Asia/Jakarta',
  ];

  for (const ev of events) {
    if (!ev.starts_at) continue;
    const startDateObj = new Date(ev.starts_at);
    if (Number.isNaN(startDateObj.getTime())) continue;

    const uid = (ev.uid && ev.uid.trim()) || `${ev.id}@orbit.local`;
    lines.push('BEGIN:VEVENT');
    lines.push(`UID:${escapeIcsText(uid)}`);
    lines.push(`DTSTAMP:${dtstamp}`);

    if (ev.all_day) {
      const startKey = toWibDateKey(startDateObj);
      let endKey = ev.ends_at ? toWibDateKey(ev.ends_at) : startKey;
      if (endKey <= startKey) {
        endKey = addDaysToDateKey(startKey, 1);
      } else {
        // DTEND pada VALUE=DATE bersifat eksklusif menurut RFC 5545
        endKey = addDaysToDateKey(endKey, 1);
      }
      lines.push(`DTSTART;VALUE=DATE:${startKey.replace(/-/g, '')}`);
      lines.push(`DTEND;VALUE=DATE:${endKey.replace(/-/g, '')}`);
    } else {
      const endDateObj =
        ev.ends_at && !Number.isNaN(new Date(ev.ends_at).getTime())
          ? new Date(ev.ends_at)
          : new Date(startDateObj.getTime() + 60 * 60 * 1000);
      lines.push(`DTSTART:${formatIcsDateTimeUtc(startDateObj)}`);
      lines.push(`DTEND:${formatIcsDateTimeUtc(endDateObj)}`);
    }

    lines.push(`SUMMARY:${escapeIcsText(ev.title || 'Tanpa Judul')}`);
    if (ev.description && ev.description.trim()) {
      lines.push(`DESCRIPTION:${escapeIcsText(ev.description.trim())}`);
    }
    if (ev.location && ev.location.trim()) {
      lines.push(`LOCATION:${escapeIcsText(ev.location.trim())}`);
    }
    lines.push('END:VEVENT');
  }

  lines.push('END:VCALENDAR');
  return `${lines.join('\r\n')}\r\n`;
}

function parseIcsDateValue(rawValue: string, params: string): { iso: string; allDay: boolean; dateKey: string } | null {
  const val = rawValue.trim();
  const upperParams = params.toUpperCase();

  // Format VALUE=DATE: YYYYMMDD
  if (upperParams.includes('VALUE=DATE') || /^\d{8}$/.test(val)) {
    const m = /^(\d{4})(\d{2})(\d{2})$/.exec(val);
    if (!m) return null;
    const dateKey = `${m[1]}-${m[2]}-${m[3]}`;
    const dt = new Date(`${dateKey}T00:00:00+07:00`);
    if (Number.isNaN(dt.getTime())) return null;
    return { iso: dt.toISOString(), allDay: true, dateKey };
  }

  // Format YYYYMMDDTHHMMSSZ atau YYYYMMDDTHHMMSS
  const m = /^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z)?$/i.exec(val);
  if (!m) {
    const fallback = new Date(val);
    if (Number.isNaN(fallback.getTime())) return null;
    return { iso: fallback.toISOString(), allDay: false, dateKey: toWibDateKey(fallback) };
  }

  const [, yr, mo, dy, hr, mn, sc, zFlag] = m;
  if (zFlag) {
    const dt = new Date(`${yr}-${mo}-${dy}T${hr}:${mn}:${sc}Z`);
    if (Number.isNaN(dt.getTime())) return null;
    return { iso: dt.toISOString(), allDay: false, dateKey: toWibDateKey(dt) };
  }

  // TZID atau floating time: perlakukan dalam WIB Asia/Jakarta jika TZID tidak menentukan offset lain
  const dt = new Date(`${yr}-${mo}-${dy}T${hr}:${mn}:${sc}+07:00`);
  if (Number.isNaN(dt.getTime())) return null;
  return { iso: dt.toISOString(), allDay: false, dateKey: `${yr}-${mo}-${dy}` };
}

/**
 * Mem-parse isi file .ics RFC 5545 menjadi daftar acara siap simpan ke tabel `events`.
 */
export function parseIcsContent(icsText: string): ParsedIcsEvent[] {
  if (!icsText || !icsText.trim()) return [];

  // Unfold baris lanjutan sesuai RFC 5545 (CRLF/LF diikuti spasi atau tab)
  const unfolded = icsText.replace(/\r\n/g, '\n').replace(/\r/g, '\n').replace(/\n[ \t]/g, '');
  const lines = unfolded.split('\n');

  const events: ParsedIcsEvent[] = [];
  let inEvent = false;
  let current: Record<string, { params: string; value: string }> = {};

  for (const rawLine of lines) {
    const line = rawLine.trim();
    if (!line) continue;

    if (line.toUpperCase() === 'BEGIN:VEVENT') {
      inEvent = true;
      current = {};
      continue;
    }

    if (line.toUpperCase() === 'END:VEVENT') {
      if (inEvent && current.DTSTART) {
        const parsedStart = parseIcsDateValue(current.DTSTART.value, current.DTSTART.params);
        if (parsedStart) {
          const allDay = parsedStart.allDay;
          let startsAt = parsedStart.iso;
          let endsAt: string;

          if (current.DTEND) {
            const parsedEnd = parseIcsDateValue(current.DTEND.value, current.DTEND.params);
            if (parsedEnd) {
              if (allDay) {
                // DTEND VALUE=DATE bersifat eksklusif pada RFC 5545
                const inclusiveEndKey =
                  parsedEnd.dateKey > parsedStart.dateKey
                    ? addDaysToDateKey(parsedEnd.dateKey, -1)
                    : parsedStart.dateKey;
                endsAt = new Date(`${inclusiveEndKey}T23:59:59+07:00`).toISOString();
                startsAt = new Date(`${parsedStart.dateKey}T00:00:00+07:00`).toISOString();
              } else {
                endsAt = parsedEnd.iso;
              }
            } else {
              endsAt = allDay
                ? new Date(`${parsedStart.dateKey}T23:59:59+07:00`).toISOString()
                : new Date(new Date(startsAt).getTime() + 60 * 60 * 1000).toISOString();
            }
          } else {
            endsAt = allDay
              ? new Date(`${parsedStart.dateKey}T23:59:59+07:00`).toISOString()
              : new Date(new Date(startsAt).getTime() + 60 * 60 * 1000).toISOString();
          }

          if (new Date(endsAt).getTime() < new Date(startsAt).getTime()) {
            endsAt = new Date(new Date(startsAt).getTime() + 60 * 60 * 1000).toISOString();
          }

          events.push({
            uid: current.UID ? unescapeIcsText(current.UID.value.trim()) : null,
            title: current.SUMMARY
              ? unescapeIcsText(current.SUMMARY.value.trim()) || 'Acara Impor'
              : 'Acara Impor',
            description: current.DESCRIPTION
              ? unescapeIcsText(current.DESCRIPTION.value).trim() || null
              : null,
            location: current.LOCATION
              ? unescapeIcsText(current.LOCATION.value).trim() || null
              : null,
            starts_at: startsAt,
            ends_at: endsAt,
            all_day: allDay,
          });
        }
      }
      inEvent = false;
      current = {};
      continue;
    }

    if (!inEvent) continue;

    const colonIdx = line.indexOf(':');
    if (colonIdx <= 0) continue;

    const keyAndParams = line.slice(0, colonIdx);
    const value = line.slice(colonIdx + 1);
    const semiIdx = keyAndParams.indexOf(';');
    const propName = (semiIdx >= 0 ? keyAndParams.slice(0, semiIdx) : keyAndParams).toUpperCase();
    const params = semiIdx >= 0 ? keyAndParams.slice(semiIdx + 1) : '';

    current[propName] = { params, value };
  }

  return events;
}

/**
 * Membangun grid kalender bulanan 7 kolom (Senin - Minggu) beserta agenda per tanggal.
 */
export function buildMonthlyCalendarGrid(
  year: number,
  monthIndex0: number,
  items: CalendarGridInputItem[],
  todayKey = toWibDateKey(new Date())
): CalendarGridCell[] {
  const firstOfMonth = new Date(Date.UTC(year, monthIndex0, 1));
  const lastOfMonth = new Date(Date.UTC(year, monthIndex0 + 1, 0));

  // JS getUTCDay(): 0 = Min, 1 = Sen ... 6 = Sab -> ubah ke Senin=0 .. Minggu=6
  const startOffset = (firstOfMonth.getUTCDay() + 6) % 7;
  const totalDaysInMonth = lastOfMonth.getUTCDate();
  const totalCells = Math.ceil((startOffset + totalDaysInMonth) / 7) * 7;

  const byDate = new Map<string, CalendarGridInputItem[]>();
  for (const item of items) {
    if (!item.starts_at) continue;
    const key = toWibDateKey(item.starts_at);
    const existing = byDate.get(key) ?? [];
    existing.push(item);
    byDate.set(key, existing);
  }

  const cells: CalendarGridCell[] = [];
  for (let i = 0; i < totalCells; i++) {
    const cellDate = new Date(Date.UTC(year, monthIndex0, 1 - startOffset + i));
    const dateKey = cellDate.toISOString().slice(0, 10);
    const cellItems = [...(byDate.get(dateKey) ?? [])].sort((a, b) => {
      if (a.all_day !== b.all_day) return a.all_day ? -1 : 1;
      const ta = a.starts_at ? new Date(a.starts_at).getTime() : 0;
      const tb = b.starts_at ? new Date(b.starts_at).getTime() : 0;
      return ta - tb;
    });

    const eventCount = cellItems.filter((it) => it.item_type === 'event').length;
    const taskCount = cellItems.filter((it) => it.item_type === 'task').length;

    cells.push({
      dateKey,
      dayOfMonth: cellDate.getUTCDate(),
      inCurrentMonth: cellDate.getUTCMonth() === monthIndex0 && cellDate.getUTCFullYear() === year,
      isToday: dateKey === todayKey,
      items: cellItems,
      eventCount,
      taskCount,
    });
  }

  return cells;
}

/**
 * Mengelompokkan agenda pada tanggal tertentu ke blok jam linimasa beserta deteksi benturan waktu.
 */
export function buildTimelineSlots(
  items: CalendarGridInputItem[],
  dateKey: string,
  startHour = 6,
  endHour = 23
): TimelineDayResult {
  const dayStartMin = startHour * 60;
  const dayEndMin = (endHour + 1) * 60;
  const totalSpan = Math.max(60, dayEndMin - dayStartMin);

  const dayItems = items.filter((item) => {
    if (!item.starts_at) return false;
    return toWibDateKey(item.starts_at) === dateKey;
  });

  const allDayItems: CalendarGridInputItem[] = [];
  const rawTimed: Array<{
    item: CalendarGridInputItem;
    startMinutes: number;
    endMinutes: number;
  }> = [];

  for (const item of dayItems) {
    if (item.all_day || item.item_type === 'task') {
      if (item.all_day) {
        allDayItems.push(item);
        continue;
      }
    }

    if (!item.starts_at) continue;
    const startMinRaw = toWibMinutes(item.starts_at);
    let endMinRaw = item.ends_at ? toWibMinutes(item.ends_at) : startMinRaw + 45;
    if (item.ends_at && toWibDateKey(item.ends_at) > dateKey) {
      endMinRaw = dayEndMin;
    }
    if (endMinRaw <= startMinRaw) {
      endMinRaw = startMinRaw + 30;
    }

    const clampedStart = Math.max(dayStartMin, Math.min(dayEndMin - 15, startMinRaw));
    const clampedEnd = Math.min(dayEndMin, Math.max(clampedStart + 30, endMinRaw));

    rawTimed.push({
      item,
      startMinutes: clampedStart,
      endMinutes: clampedEnd,
    });
  }

  rawTimed.sort((a, b) => a.startMinutes - b.startMinutes || a.endMinutes - b.endMinutes);

  const conflicts: TimelineConflictPair[] = [];
  const conflictSet = new Set<string>();

  for (let i = 0; i < rawTimed.length; i++) {
    for (let j = i + 1; j < rawTimed.length; j++) {
      const a = rawTimed[i];
      const b = rawTimed[j];
      if (b.startMinutes < a.endMinutes) {
        conflictSet.add(a.item.id);
        conflictSet.add(b.item.id);
        conflicts.push({
          firstId: a.item.id,
          firstTitle: a.item.title,
          secondId: b.item.id,
          secondTitle: b.item.title,
          overlapStartMinutes: Math.max(a.startMinutes, b.startMinutes),
          overlapEndMinutes: Math.min(a.endMinutes, b.endMinutes),
        });
      }
    }
  }

  // Hitung lane paralel agar blok yang bentrok tidak saling menutupi
  const laneEndTimes: number[] = [];
  const tempBlocks: Array<{
    item: CalendarGridInputItem;
    startMinutes: number;
    endMinutes: number;
    lane: number;
  }> = [];

  for (const entry of rawTimed) {
    let assignedLane = -1;
    for (let l = 0; l < laneEndTimes.length; l++) {
      if (laneEndTimes[l] <= entry.startMinutes) {
        assignedLane = l;
        laneEndTimes[l] = entry.endMinutes;
        break;
      }
    }
    if (assignedLane === -1) {
      assignedLane = laneEndTimes.length;
      laneEndTimes.push(entry.endMinutes);
    }
    tempBlocks.push({ ...entry, lane: assignedLane });
  }

  const blocks: TimelineBlock[] = tempBlocks.map((entry) => {
    let maxConcurrentLane = entry.lane;
    for (const other of tempBlocks) {
      if (other.startMinutes < entry.endMinutes && entry.startMinutes < other.endMinutes) {
        maxConcurrentLane = Math.max(maxConcurrentLane, other.lane);
      }
    }
    const laneCount = maxConcurrentLane + 1;
    const durationMinutes = Math.max(30, entry.endMinutes - entry.startMinutes);
    return {
      item: entry.item,
      startMinutes: entry.startMinutes,
      endMinutes: entry.endMinutes,
      durationMinutes,
      topPercent: ((entry.startMinutes - dayStartMin) / totalSpan) * 100,
      heightPercent: (durationMinutes / totalSpan) * 100,
      lane: entry.lane,
      laneCount,
      hasConflict: conflictSet.has(entry.item.id),
    };
  });

  return {
    dateKey,
    allDayItems,
    blocks,
    conflicts,
  };
}
