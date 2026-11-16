'use client';

import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  AlertTriangle,
  Calendar as CalendarIcon,
  CalendarPlus,
  ChevronLeft,
  ChevronRight,
  Clock,
  Download,
  ExternalLink,
  ListChecks,
  MapPin,
  Plus,
  RefreshCw,
  Repeat,
  Trash2,
  Upload,
  XCircle,
} from 'lucide-react';
import { createClient } from '@/lib/supabase/client';
import { formatDateIndo, formatDateOnly } from '@/lib/format';
import { RealtimeStatusBadge, useOrbitRealtime } from '@/lib/use-orbit-realtime';
import {
  buildMonthlyCalendarGrid,
  buildTimelineSlots,
  exportEventsToIcs,
  formatWibTime,
  parseIcsContent,
  toWibDateKey,
  type CalendarGridInputItem,
  type ParsedIcsEvent,
} from '@/lib/calendar-sync';
import { isSchemaFeatureUnavailable } from '@/components/tasks/task-actions';
import {
  AgendaSubNav,
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Dialog,
  EmptyState,
  ErrorState,
  Input,
  KindBadge,
  Select,
  Skeleton,
  StatusBadge,
  Textarea,
  ViewSwitcher,
  cn,
  type ActivityKind,
} from '@/components/ui';

type AgendaViewMode = 'list' | 'calendar' | 'timeline';
type ExceptionAction = 'skip' | 'override';
type EventKind = 'kuliah' | 'freelance' | 'intern' | 'pribadi';

interface AgendaItem {
  id: string;
  item_type: 'event' | 'task';
  title: string;
  kind: ActivityKind;
  starts_at: string | null;
  ends_at: string | null;
  all_day: boolean;
  location: string | null;
  status: string | null;
  priority: string | null;
  is_recurring: boolean;
  event_id: string | null;
}

interface ConflictItem {
  conflict_date: string;
  event1_id: string | null;
  event1_title: string | null;
  event1_starts_at: string | null;
  event1_ends_at: string | null;
  event2_id: string | null;
  event2_title: string | null;
  event2_starts_at: string | null;
  event2_ends_at: string | null;
  is_heavy_day: boolean;
}

interface RawEventRow {
  id: string;
  title: string;
  description: string | null;
  location: string | null;
  starts_at: string;
  ends_at: string;
  all_day: boolean;
  external_provider?: string | null;
  external_event_id?: string | null;
}

interface ProjectOption {
  id: string;
  name: string;
  kind: ActivityKind;
}

interface GoogleStatusPayload {
  configured: boolean;
  connected: boolean;
  message: string;
}

const WEEKDAY_HEADERS = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
const WEEKDAYS = [
  { val: 1, label: 'Sen' },
  { val: 2, label: 'Sel' },
  { val: 3, label: 'Rab' },
  { val: 4, label: 'Kam' },
  { val: 5, label: 'Jum' },
  { val: 6, label: 'Sab' },
  { val: 0, label: 'Min' },
];

const TIMELINE_HOURS = Array.from({ length: 18 }, (_, i) => i + 6); // 06:00 - 23:00

function formatMinutesLabel(minutes: number): string {
  const hr = Math.floor(minutes / 60);
  const mn = minutes % 60;
  return `${String(hr).padStart(2, '0')}:${String(mn).padStart(2, '0')}`;
}

export default function JadwalPage() {
  const supabase = useMemo(() => createClient(), []);
  const [workspaceId, setWorkspaceId] = useState<string | null>(null);

  const [viewMode, setViewMode] = useState<AgendaViewMode>('list');
  const [currentDate, setCurrentDate] = useState<Date>(() => new Date());
  const [selectedDateKey, setSelectedDateKey] = useState<string>(() => toWibDateKey(new Date()));
  const [filterKind, setFilterKind] = useState<'all' | ActivityKind>('all');

  const [agendaItems, setAgendaItems] = useState<AgendaItem[]>([]);
  const [conflicts, setConflicts] = useState<ConflictItem[]>([]);
  const [rawEvents, setRawEvents] = useState<RawEventRow[]>([]);
  const [projects, setProjects] = useState<ProjectOption[]>([]);

  const [googleStatus, setGoogleStatus] = useState<GoogleStatusPayload | null>(null);
  const [calendarLastSyncedAt, setCalendarLastSyncedAt] = useState<string | null>(null);
  const [syncMessage, setSyncMessage] = useState<string | null>(null);
  const [syncingGoogle, setSyncingGoogle] = useState(false);

  const [loading, setLoading] = useState(true);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  // Modal Tambah Event
  const [showEventModal, setShowEventModal] = useState(false);
  const [formTitle, setFormTitle] = useState('');
  const [formDescription, setFormDescription] = useState('');
  const [formKind, setFormKind] = useState<EventKind>('kuliah');
  const [formProjectId, setFormProjectId] = useState('');
  const [formLocation, setFormLocation] = useState('');
  const [formDate, setFormDate] = useState('');
  const [formStartTime, setFormStartTime] = useState('08:00');
  const [formEndTime, setFormEndTime] = useState('10:00');
  const [formAllDay, setFormAllDay] = useState(false);
  const [formRecurrenceFreq, setFormRecurrenceFreq] = useState<'none' | 'daily' | 'weekly'>('none');
  const [formByWeekday, setFormByWeekday] = useState<number[]>([1]);
  const [formRecurrenceUntil, setFormRecurrenceUntil] = useState('');
  const [savingEvent, setSavingEvent] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  // Modal Pengecualian (Override / Cancel)
  const [exceptionTarget, setExceptionTarget] = useState<AgendaItem | null>(null);
  const [exceptionAction, setExceptionAction] = useState<ExceptionAction>('override');
  const [overrideTitle, setOverrideTitle] = useState('');
  const [overrideLocation, setOverrideLocation] = useState('');
  const [savingException, setSavingException] = useState(false);

  // Modal Impor .ics
  const [showIcsModal, setShowIcsModal] = useState(false);
  const [icsText, setIcsText] = useState('');
  const [icsDefaultKind, setIcsDefaultKind] = useState<EventKind>('pribadi');
  const [parsedIcsEvents, setParsedIcsEvents] = useState<ParsedIcsEvent[]>([]);
  const [importingIcs, setImportingIcs] = useState(false);
  const [icsError, setIcsError] = useState<string | null>(null);

  const getFetchDateRange = useCallback(() => {
    const base = new Date(currentDate);
    if (viewMode === 'calendar') {
      const year = base.getFullYear();
      const month = base.getMonth();
      const firstOfMonth = new Date(Date.UTC(year, month, 1));
      const startOffset = (firstOfMonth.getUTCDay() + 6) % 7;
      const gridStart = new Date(Date.UTC(year, month, 1 - startOffset));
      const gridEnd = new Date(gridStart);
      gridEnd.setUTCDate(gridStart.getUTCDate() + 41);
      return {
        start: gridStart,
        end: gridEnd,
        startDateStr: gridStart.toISOString().slice(0, 10),
        endDateStr: gridEnd.toISOString().slice(0, 10),
      };
    }

    if (viewMode === 'timeline') {
      return {
        start: new Date(`${selectedDateKey}T00:00:00Z`),
        end: new Date(`${selectedDateKey}T23:59:59Z`),
        startDateStr: selectedDateKey,
        endDateStr: selectedDateKey,
      };
    }

    // Mode Daftar: rentang mingguan (Senin - Minggu)
    const start = new Date(base);
    const day = start.getDay();
    const diffToMonday = day === 0 ? -6 : 1 - day;
    start.setDate(start.getDate() + diffToMonday);
    const end = new Date(start);
    end.setDate(start.getDate() + 6);
    return {
      start,
      end,
      startDateStr: toWibDateKey(start),
      endDateStr: toWibDateKey(end),
    };
  }, [currentDate, viewMode, selectedDateKey]);

  const loadGoogleAndConnectionStatus = useCallback(async () => {
    try {
      const res = await fetch('/api/calendar/google/status');
      if (res.ok) {
        const json = (await res.json()) as GoogleStatusPayload;
        setGoogleStatus(json);
      }
    } catch {
      setGoogleStatus({
        configured: false,
        connected: false,
        message: 'Tidak dapat memeriksa status server OAuth Google Calendar.',
      });
    }

    if (!workspaceId) return;
    try {
      const connRes = await supabase
        .from('calendar_connections')
        .select('last_synced_at, enabled')
        .eq('workspace_id', workspaceId)
        .eq('provider', 'google')
        .maybeSingle();

      if (!connRes.error && connRes.data?.last_synced_at) {
        setCalendarLastSyncedAt(connRes.data.last_synced_at);
      } else if (connRes.error && isSchemaFeatureUnavailable(connRes.error)) {
        setCalendarLastSyncedAt(null);
      }
    } catch {
      // Abaikan bila tabel belum dimigrasi
    }
  }, [supabase, workspaceId]);

  const loadData = useCallback(async () => {
    if (!workspaceId) return;
    setLoading(true);
    setErrorMsg(null);

    try {
      const { startDateStr, endDateStr } = getFetchDateRange();

      const [agendaRes, conflictRes, projRes, eventsRes] = await Promise.all([
        supabase.rpc('fn_agenda', {
          p_workspace_id: workspaceId,
          p_start_date: startDateStr,
          p_end_date: endDateStr,
        }),
        supabase.rpc('fn_detect_conflicts', {
          p_workspace_id: workspaceId,
          p_start_date: startDateStr,
          p_end_date: endDateStr,
        }),
        supabase
          .from('projects')
          .select('id, name, kind')
          .eq('workspace_id', workspaceId)
          .is('deleted_at', null)
          .eq('archived', false)
          .order('name'),
        supabase
          .from('events')
          .select('id, title, description, location, starts_at, ends_at, all_day')
          .eq('workspace_id', workspaceId)
          .is('deleted_at', null)
          .order('starts_at', { ascending: true })
          .limit(300),
      ]);

      if (agendaRes.error) {
        setErrorMsg(agendaRes.error.message);
      } else {
        setAgendaItems((agendaRes.data as AgendaItem[]) ?? []);
      }

      if (!conflictRes.error && conflictRes.data) {
        const list = conflictRes.data as ConflictItem[];
        setConflicts(list.filter((c) => c.event1_id !== null && c.event2_id !== null));
      } else {
        setConflicts([]);
      }

      setProjects((projRes.data as ProjectOption[]) ?? []);
      setRawEvents((eventsRes.data as RawEventRow[]) ?? []);
    } catch (err) {
      setErrorMsg(err instanceof Error ? err.message : 'Gagal memuat data jadwal.');
    } finally {
      setLoading(false);
    }
  }, [workspaceId, supabase, getFetchDateRange]);

  useEffect(() => {
    let active = true;
    async function resolveWorkspace() {
      const storedWsId =
        typeof window !== 'undefined'
          ? window.localStorage.getItem('orbit_active_workspace_id')
          : null;
      let member: { workspace_id: string } | null = null;
      if (storedWsId) {
        const res = await supabase
          .from('workspace_members')
          .select('workspace_id')
          .eq('workspace_id', storedWsId)
          .limit(1);
        member = res.data?.[0] ?? null;
      }
      if (!member?.workspace_id) {
        const fallback = await supabase
          .from('workspace_members')
          .select('workspace_id')
          .limit(1);
        member = fallback.data?.[0] ?? null;
      }
      if (!active) return;
      if (member?.workspace_id) {
        setWorkspaceId(member.workspace_id);
      } else {
        setLoading(false);
      }
    }
    resolveWorkspace();
    return () => {
      active = false;
    };
  }, [supabase]);

  useEffect(() => {
    if (workspaceId) {
      loadData();
      loadGoogleAndConnectionStatus();
    }
  }, [workspaceId, loadData, loadGoogleAndConnectionStatus]);

  const { status: realtimeStatus } = useOrbitRealtime({
    workspaceId,
    tables: ['events', 'tasks'],
    onChange: loadData,
  });

  const navigatePeriod = (dir: -1 | 1) => {
    if (viewMode === 'calendar') {
      const next = new Date(currentDate);
      next.setMonth(next.getMonth() + dir);
      setCurrentDate(next);
      return;
    }

    if (viewMode === 'timeline') {
      const dt = new Date(`${selectedDateKey}T12:00:00+07:00`);
      dt.setDate(dt.getDate() + dir);
      const nextKey = toWibDateKey(dt);
      setSelectedDateKey(nextKey);
      setCurrentDate(dt);
      return;
    }

    const next = new Date(currentDate);
    next.setDate(next.getDate() + dir * 7);
    setCurrentDate(next);
  };

  const goToday = () => {
    const now = new Date();
    const todayKey = toWibDateKey(now);
    setCurrentDate(now);
    setSelectedDateKey(todayKey);
  };

  const openCreateModal = (prefillDateKey?: string) => {
    const targetKey = prefillDateKey || selectedDateKey || toWibDateKey(new Date());
    setFormTitle('');
    setFormDescription('');
    setFormKind('kuliah');
    setFormProjectId('');
    setFormLocation('');
    setFormDate(targetKey);
    setFormStartTime('08:00');
    setFormEndTime('10:00');
    setFormAllDay(false);
    setFormRecurrenceFreq('none');
    setFormByWeekday([1]);
    setFormRecurrenceUntil('');
    setFormError(null);
    setShowEventModal(true);
  };

  const handleSaveEvent = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!workspaceId || !formTitle.trim()) return;

    setSavingEvent(true);
    setFormError(null);

    const startsAt = formAllDay
      ? new Date(`${formDate}T00:00:00+07:00`).toISOString()
      : new Date(`${formDate}T${formStartTime}:00+07:00`).toISOString();
    const endsAt = formAllDay
      ? new Date(`${formDate}T23:59:59+07:00`).toISOString()
      : new Date(`${formDate}T${formEndTime}:00+07:00`).toISOString();

    let recurrenceJson = null;
    if (formRecurrenceFreq !== 'none') {
      recurrenceJson = {
        freq: formRecurrenceFreq,
        byweekday: formRecurrenceFreq === 'weekly' ? formByWeekday : undefined,
        until: formRecurrenceUntil || undefined,
      };
    }

    const payload = {
      workspace_id: workspaceId,
      title: formTitle.trim(),
      description: formDescription.trim() || null,
      kind: formKind,
      project_id: formProjectId || null,
      location: formLocation.trim() || null,
      starts_at: startsAt,
      ends_at: endsAt,
      all_day: formAllDay,
      timezone: 'Asia/Jakarta',
      recurrence: recurrenceJson,
    };

    const { error } = await supabase.from('events').insert(payload);

    setSavingEvent(false);
    if (error) {
      setFormError(error.message);
      return;
    }

    setShowEventModal(false);
    loadData();
  };

  const handleSaveException = async () => {
    if (!exceptionTarget || !exceptionTarget.starts_at) return;
    setSavingException(true);

    const targetDate = toWibDateKey(exceptionTarget.starts_at);
    const eventId = exceptionTarget.event_id || exceptionTarget.id;

    const payload: {
      event_id: string;
      original_date: string;
      action: ExceptionAction;
      override_title?: string | null;
      override_location?: string | null;
    } = {
      event_id: eventId,
      original_date: targetDate,
      action: exceptionAction,
    };

    if (exceptionAction === 'override') {
      payload.override_title = overrideTitle.trim() || null;
      payload.override_location = overrideLocation.trim() || null;
    }

    const { error } = await supabase.from('event_exceptions').insert(payload);

    setSavingException(false);
    setExceptionTarget(null);

    if (!error) {
      loadData();
    }
  };

  const handleDeleteEvent = async (item: AgendaItem) => {
    const eventId = item.event_id || item.id;
    if (!confirm('Hapus jadwal ini? Jika jadwal berulang, seluruh seri jadwal akan terhapus.')) {
      return;
    }
    await supabase.from('events').update({ deleted_at: new Date().toISOString() }).eq('id', eventId);
    loadData();
  };

  const handleExportIcs = () => {
    const sourceEvents =
      rawEvents.length > 0
        ? rawEvents
        : agendaItems
            .filter((it) => it.item_type === 'event' && it.starts_at)
            .map((it) => ({
              id: it.event_id || it.id,
              title: it.title,
              description: null,
              location: it.location,
              starts_at: it.starts_at!,
              ends_at: it.ends_at,
              all_day: it.all_day,
            }));

    const content = exportEventsToIcs(sourceEvents, { calendarName: 'Orbit Agenda' });
    const blob = new Blob([content], { type: 'text/calendar;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `orbit-agenda-${toWibDateKey(new Date())}.ics`;
    document.body.appendChild(link);
    link.click();
    link.remove();
    URL.revokeObjectURL(url);
    setSyncMessage(`Berhasil mengekspor ${sourceEvents.length} jadwal ke file .ics.`);
  };

  const handleIcsTextChange = (text: string) => {
    setIcsText(text);
    setIcsError(null);
    if (!text.trim()) {
      setParsedIcsEvents([]);
      return;
    }
    const parsed = parseIcsContent(text);
    setParsedIcsEvents(parsed);
    if (parsed.length === 0) {
      setIcsError('Tidak ditemukan blok VEVENT valid di teks .ics tersebut.');
    }
  };

  const handleIcsFileUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const text = await file.text();
    handleIcsTextChange(text);
  };

  const handleCommitIcsImport = async () => {
    if (!workspaceId || parsedIcsEvents.length === 0) return;
    setImportingIcs(true);
    setIcsError(null);

    const payload = parsedIcsEvents.map((ev) => ({
      workspace_id: workspaceId,
      title: ev.title.slice(0, 200),
      description: ev.description,
      location: ev.location,
      kind: icsDefaultKind,
      starts_at: ev.starts_at,
      ends_at: ev.ends_at,
      all_day: ev.all_day,
      timezone: 'Asia/Jakarta',
    }));

    const { error } = await supabase.from('events').insert(payload);
    setImportingIcs(false);

    if (error) {
      setIcsError(error.message);
      return;
    }

    setSyncMessage(`Berhasil mengimpor ${payload.length} acara dari file .ics ke Orbit.`);
    setShowIcsModal(false);
    setIcsText('');
    setParsedIcsEvents([]);
    loadData();
  };

  const handleSyncGoogleNow = async () => {
    if (!workspaceId) return;
    setSyncingGoogle(true);
    setSyncMessage(null);
    try {
      const res = await fetch('/api/calendar/google/sync', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ workspace_id: workspaceId }),
      });
      const data = (await res.json()) as {
        ok?: boolean;
        message?: string;
        last_synced_at?: string;
      };
      setSyncMessage(data.message || 'Status sinkronisasi Google Calendar diterima.');
      if (data.last_synced_at) {
        setCalendarLastSyncedAt(data.last_synced_at);
      }
      if (res.ok && data.ok) {
        loadData();
      }
    } catch {
      setSyncMessage('Gagal menghubungi endpoint sinkronisasi Google Calendar.');
    } finally {
      setSyncingGoogle(false);
    }
  };

  const filteredAgendaItems = useMemo(
    () =>
      agendaItems.filter((item) => (filterKind === 'all' ? true : item.kind === filterKind)),
    [agendaItems, filterKind]
  );

  const gridItems: CalendarGridInputItem[] = useMemo(
    () =>
      filteredAgendaItems.map((it) => ({
        id: it.id,
        item_type: it.item_type,
        title: it.title,
        kind: it.kind,
        starts_at: it.starts_at,
        ends_at: it.ends_at,
        all_day: it.all_day,
        location: it.location,
        status: it.status,
        priority: it.priority,
      })),
    [filteredAgendaItems]
  );

  const calendarCells = useMemo(
    () =>
      buildMonthlyCalendarGrid(
        currentDate.getFullYear(),
        currentDate.getMonth(),
        gridItems,
        toWibDateKey(new Date())
      ),
    [currentDate, gridItems]
  );

  const selectedDayItems = useMemo(
    () =>
      filteredAgendaItems
        .filter((it) => it.starts_at && toWibDateKey(it.starts_at) === selectedDateKey)
        .sort((a, b) => {
          if (a.all_day !== b.all_day) return a.all_day ? -1 : 1;
          return new Date(a.starts_at!).getTime() - new Date(b.starts_at!).getTime();
        }),
    [filteredAgendaItems, selectedDateKey]
  );

  const timelineData = useMemo(
    () => buildTimelineSlots(gridItems, selectedDateKey, 6, 23),
    [gridItems, selectedDateKey]
  );

  const weekDays = useMemo(() => {
    const { start } = getFetchDateRange();
    return Array.from({ length: 7 }, (_, i) => {
      const d = new Date(start);
      d.setDate(d.getDate() + i);
      return d;
    });
  }, [getFetchDateRange]);

  const { startDateStr, endDateStr } = getFetchDateRange();
  const currentMonthLabel = new Intl.DateTimeFormat('id-ID', {
    month: 'long',
    year: 'numeric',
  }).format(currentDate);

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2.5 flex-wrap">
            <h1 className="text-2xl font-bold tracking-tight text-foreground">Agenda</h1>
            <RealtimeStatusBadge status={realtimeStatus} />
          </div>
          <p className="text-sm text-muted-foreground mt-0.5">
            Tampilan Daftar, Kalender Bulanan, Linimasa Jam, serta impor/ekspor .ics dan sinkronisasi Google Calendar
          </p>
        </div>

        <Button onClick={() => openCreateModal()}>
          <Plus className="w-4 h-4" />
          <span>Tambah Jadwal</span>
        </Button>
      </div>

      <AgendaSubNav />

      {/* Switcher Tampilan v2 + Navigasi Periode */}
      <ViewSwitcher<AgendaViewMode>
        ariaLabel="Pilih tampilan agenda"
        value={viewMode}
        onChange={setViewMode}
        options={[
          { value: 'list', label: 'Daftar', badge: filteredAgendaItems.length },
          { value: 'calendar', label: 'Kalender' },
          { value: 'timeline', label: 'Linimasa' },
        ]}
        rightSlot={
          <div className="flex flex-wrap items-center gap-2">
            <Button variant="secondary" size="icon" onClick={() => navigatePeriod(-1)} aria-label="Periode sebelumnya">
              <ChevronLeft className="w-4 h-4" />
            </Button>
            <Button variant="secondary" onClick={goToday}>
              Hari Ini
            </Button>
            <Button variant="secondary" size="icon" onClick={() => navigatePeriod(1)} aria-label="Periode berikutnya">
              <ChevronRight className="w-4 h-4" />
            </Button>
          </div>
        }
      />

      {/* Bar Filter Kategori & Keterangan Periode */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-3 bg-card p-3.5 rounded-lg border border-border">
        <div className="text-sm font-semibold text-foreground tabular-nums">
          {viewMode === 'calendar' && <span className="capitalize">{currentMonthLabel}</span>}
          {viewMode === 'timeline' && (
            <span>Linimasa Harian: {formatDateOnly(selectedDateKey)}</span>
          )}
          {viewMode === 'list' && (
            <span>
              {formatDateOnly(startDateStr)} - {formatDateOnly(endDateStr)}
            </span>
          )}
        </div>

        <div className="flex items-center gap-2 overflow-x-auto pb-1 sm:pb-0">
          {(
            [
              { val: 'all', label: 'Semua' },
              { val: 'kuliah', label: 'Kuliah' },
              { val: 'intern', label: 'Magang' },
              { val: 'freelance', label: 'Freelance' },
              { val: 'pribadi', label: 'Pribadi' },
            ] as const
          ).map((f) => (
            <button
              key={f.val}
              type="button"
              onClick={() => setFilterKind(f.val)}
              className={cn(
                'min-h-11 px-3.5 rounded-md text-xs font-medium border transition-colors shrink-0',
                filterKind === f.val
                  ? 'bg-primary text-primary-foreground border-primary'
                  : 'bg-subtle text-muted-foreground border-border hover:text-foreground hover:bg-hover'
              )}
            >
              {f.label}
            </button>
          ))}
        </div>
      </div>

      {/* Panel Sinkronisasi Google Calendar & .ics */}
      <Card>
        <CardContent className="p-4 flex flex-col lg:flex-row lg:items-center justify-between gap-4">
          <div className="space-y-1.5">
            <div className="flex flex-wrap items-center gap-2">
              <h2 className="text-sm font-semibold text-foreground">
                Sinkronisasi Kalender &amp; Berkas .ics
              </h2>
              {googleStatus?.configured ? (
                googleStatus.connected ? (
                  <StatusBadge variant="income">Google Terhubung</StatusBadge>
                ) : (
                  <StatusBadge variant="neutral">OAuth Siap Dihubungkan</StatusBadge>
                )
              ) : (
                <StatusBadge variant="warning">OAuth Belum Terkonfigurasi</StatusBadge>
              )}
              {calendarLastSyncedAt && (
                <span className="text-xs text-muted-foreground tabular-nums">
                  Terakhir sinkron: {formatDateIndo(calendarLastSyncedAt)}
                </span>
              )}
            </div>
            <p className="text-xs text-muted-foreground max-w-2xl">
              {googleStatus?.message ||
                'Memeriksa konfigurasi server Google Calendar OAuth. Ekspor dan impor file .ics standar RFC 5545 selalu aktif secara lokal.'}
            </p>
            {syncMessage && (
              <p className="text-xs font-medium text-primary" role="status">
                {syncMessage}
              </p>
            )}
          </div>

          <div className="flex flex-wrap items-center gap-2 shrink-0">
            <Button variant="secondary" onClick={handleExportIcs}>
              <Download className="w-4 h-4" />
              <span>Ekspor .ics</span>
            </Button>
            <Button
              variant="secondary"
              onClick={() => {
                setIcsError(null);
                setShowIcsModal(true);
              }}
            >
              <Upload className="w-4 h-4" />
              <span>Impor .ics</span>
            </Button>
            {googleStatus?.configured && !googleStatus.connected && workspaceId && (
              <a
                href={`/api/calendar/google/auth?workspace_id=${encodeURIComponent(workspaceId)}`}
                className="min-h-11 inline-flex items-center justify-center gap-2 rounded-md border border-primary bg-primary px-4 py-2 text-sm font-medium text-primary-foreground transition-colors hover:opacity-90"
              >
                <ExternalLink className="w-4 h-4" />
                <span>Hubungkan Google</span>
              </a>
            )}
            {googleStatus?.configured && googleStatus.connected && (
              <Button onClick={handleSyncGoogleNow} disabled={syncingGoogle}>
                <RefreshCw className={cn('w-4 h-4', syncingGoogle && 'animate-spin')} />
                <span>{syncingGoogle ? 'Menyinkronkan...' : 'Sinkron Sekarang'}</span>
              </Button>
            )}
          </div>
        </CardContent>
      </Card>

      {/* Banner Deteksi Benturan */}
      {conflicts.length > 0 && (
        <div
          role="alert"
          className="rounded-lg border border-expense-border bg-expense-subtle p-4 space-y-2"
        >
          <div className="flex items-center gap-2 text-expense font-semibold text-sm">
            <AlertTriangle className="w-4 h-4 shrink-0" />
            <span className="tabular-nums">
              {conflicts.length} Benturan Jadwal Terdeteksi pada Periode Ini
            </span>
          </div>
          <div className="space-y-1.5 pl-6">
            {conflicts.map((c, idx) => (
              <div key={idx} className="text-xs text-foreground">
                <span className="font-semibold tabular-nums">{formatDateOnly(c.conflict_date)}:</span>{' '}
                <span className="font-medium text-expense">{c.event1_title || 'Acara 1'}</span>{' '}
                bertabrakan dengan{' '}
                <span className="font-medium text-expense">{c.event2_title || 'Acara 2'}</span> (
                <span className="tabular-nums">
                  {c.event1_starts_at ? formatWibTime(c.event1_starts_at) : '--:--'} &amp;{' '}
                  {c.event2_starts_at ? formatWibTime(c.event2_starts_at) : '--:--'}
                </span>
                )
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Konten Utama Berdasarkan ViewMode */}
      {loading ? (
        <div className="space-y-4">
          <Skeleton className="h-32 w-full" />
          <Skeleton className="h-32 w-full" />
        </div>
      ) : errorMsg ? (
        <ErrorState message={errorMsg} onRetry={loadData} />
      ) : viewMode === 'calendar' ? (
        /* ================= TAMPILAN KALENDER BULANAN ================= */
        <div className="grid grid-cols-1 xl:grid-cols-12 gap-4 items-start">
          <Card className="xl:col-span-8 overflow-hidden">
            <div className="grid grid-cols-7 border-b border-border bg-subtle">
              {WEEKDAY_HEADERS.map((dayName) => (
                <div
                  key={dayName}
                  className="py-2.5 text-center text-xs font-semibold text-muted-foreground"
                >
                  {dayName}
                </div>
              ))}
            </div>

            <div className="grid grid-cols-7">
              {calendarCells.map((cell) => {
                const isSelected = cell.dateKey === selectedDateKey;
                return (
                  <button
                    key={cell.dateKey}
                    type="button"
                    onClick={() => setSelectedDateKey(cell.dateKey)}
                    aria-label={`Pilih tanggal ${cell.dateKey}`}
                    aria-pressed={isSelected}
                    className={cn(
                      'min-h-[88px] sm:min-h-[104px] border-r border-b border-border p-1.5 text-left flex flex-col gap-1 transition-colors hover:bg-hover focus-visible:z-10',
                      !cell.inCurrentMonth && 'bg-subtle/60 text-muted-foreground',
                      isSelected && 'bg-primary-subtle ring-1 ring-inset ring-primary'
                    )}
                  >
                    <div className="flex items-center justify-between gap-1 w-full">
                      <span
                        className={cn(
                          'inline-flex h-6 min-w-6 items-center justify-center rounded-sm px-1 text-xs font-semibold tabular-nums',
                          cell.isToday
                            ? 'bg-primary text-primary-foreground'
                            : cell.inCurrentMonth
                            ? 'text-foreground'
                            : 'text-muted-foreground'
                        )}
                      >
                        {cell.dayOfMonth}
                      </span>
                      {cell.items.length > 0 && (
                        <span className="text-[10px] font-medium text-muted-foreground tabular-nums">
                          {cell.items.length}
                        </span>
                      )}
                    </div>

                    <div className="space-y-1 w-full overflow-hidden">
                      {cell.items.slice(0, 2).map((item) => (
                        <div
                          key={item.id}
                          className={cn(
                            'truncate rounded-sm px-1.5 py-0.5 text-[11px] font-medium border',
                            item.item_type === 'task'
                              ? 'border-warning-border bg-warning-subtle text-warning'
                              : 'border-primary bg-primary-subtle text-primary'
                          )}
                        >
                          {item.item_type === 'task' ? 'Tenggat: ' : ''}
                          {item.title}
                        </div>
                      ))}
                      {cell.items.length > 2 && (
                        <div className="text-[10px] font-medium text-muted-foreground px-1 tabular-nums">
                          +{cell.items.length - 2} lainnya
                        </div>
                      )}
                    </div>
                  </button>
                );
              })}
            </div>
          </Card>

          {/* Panel Detail Tanggal Terpilih */}
          <Card className="xl:col-span-4">
            <CardHeader className="pb-3 border-b border-border flex flex-row items-center justify-between gap-2">
              <div>
                <CardTitle className="text-base tabular-nums">
                  {formatDateOnly(selectedDateKey)}
                </CardTitle>
                <p className="text-xs text-muted-foreground mt-0.5 tabular-nums">
                  {selectedDayItems.length} item terjadwal
                </p>
              </div>
              <Button variant="secondary" size="sm" onClick={() => openCreateModal(selectedDateKey)}>
                <Plus className="w-4 h-4" />
                <span>Jadwal</span>
              </Button>
            </CardHeader>
            <CardContent className="p-4 space-y-3">
              {selectedDayItems.length === 0 ? (
                <p className="text-xs text-muted-foreground py-4 text-center">
                  Belum ada jadwal atau tenggat tugas pada tanggal ini.
                </p>
              ) : (
                selectedDayItems.map((item) => (
                  <div
                    key={item.id}
                    className="rounded-md border border-border bg-subtle/50 p-3 space-y-1.5"
                  >
                    <div className="flex items-start justify-between gap-2">
                      <span className="text-sm font-medium text-foreground">{item.title}</span>
                      <KindBadge kind={item.kind} />
                    </div>
                    <div className="flex flex-wrap items-center gap-2 text-xs text-muted-foreground tabular-nums">
                      <span>
                        {item.item_type === 'task'
                          ? 'Tenggat Tugas'
                          : item.all_day
                          ? 'Seharian'
                          : `${formatWibTime(item.starts_at!)} - ${formatWibTime(item.ends_at!)}`}
                      </span>
                      {item.location && (
                        <span className="inline-flex items-center gap-1">
                          <MapPin className="w-3.5 h-3.5" />
                          {item.location}
                        </span>
                      )}
                    </div>
                  </div>
                ))
              )}
              <Button
                variant="ghost"
                className="w-full"
                onClick={() => setViewMode('timeline')}
              >
                <Clock className="w-4 h-4" />
                <span>Buka di Linimasa Jam</span>
              </Button>
            </CardContent>
          </Card>
        </div>
      ) : viewMode === 'timeline' ? (
        /* ================= TAMPILAN LINIMASA HARIAN (06:00 - 23:00) ================= */
        <Card>
          <CardHeader className="border-b border-border pb-3 flex flex-col sm:flex-row sm:items-center justify-between gap-2">
            <div>
              <CardTitle className="text-base tabular-nums">
                Linimasa {formatDateOnly(selectedDateKey)}
              </CardTitle>
              <p className="text-xs text-muted-foreground mt-0.5 tabular-nums">
                Slot 06:00 - 23:00 WIB ({timelineData.blocks.length} blok waktu,{' '}
                {timelineData.conflicts.length} benturan)
              </p>
            </div>
            <div className="flex items-center gap-2">
              <Button variant="secondary" size="sm" onClick={() => openCreateModal(selectedDateKey)}>
                <Plus className="w-4 h-4" />
                <span>Tambah di Tanggal Ini</span>
              </Button>
            </div>
          </CardHeader>

          <CardContent className="p-4 space-y-4">
            {timelineData.allDayItems.length > 0 && (
              <div className="rounded-md border border-border bg-subtle p-3 space-y-2">
                <div className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">
                  Agenda Seharian
                </div>
                <div className="flex flex-wrap gap-2">
                  {timelineData.allDayItems.map((ev) => (
                    <div
                      key={ev.id}
                      className="inline-flex items-center gap-2 rounded-sm border border-border bg-card px-2.5 py-1.5 text-xs font-medium text-foreground"
                    >
                      <span>{ev.title}</span>
                      <KindBadge kind={ev.kind as ActivityKind} />
                    </div>
                  ))}
                </div>
              </div>
            )}

            {timelineData.conflicts.length > 0 && (
              <div
                role="alert"
                className="rounded-md border border-expense-border bg-expense-subtle p-3 text-xs text-expense space-y-1"
              >
                <div className="font-semibold flex items-center gap-1.5">
                  <AlertTriangle className="w-4 h-4" />
                  <span>Sorotan Benturan Linimasa Hari Ini</span>
                </div>
                {timelineData.conflicts.map((cf, i) => (
                  <p key={i} className="text-foreground tabular-nums">
                    {cf.firstTitle} &amp; {cf.secondTitle} bertabrakan pukul{' '}
                    {formatMinutesLabel(cf.overlapStartMinutes)} -{' '}
                    {formatMinutesLabel(cf.overlapEndMinutes)} WIB
                  </p>
                ))}
              </div>
            )}

            <div className="relative flex rounded-md border border-border bg-card overflow-x-auto">
              {/* Kolom Jam */}
              <div className="w-16 shrink-0 border-r border-border bg-subtle/60">
                {TIMELINE_HOURS.map((hr) => (
                  <div
                    key={hr}
                    className="h-14 border-b border-border/60 px-2 pt-1 text-[11px] font-medium text-muted-foreground tabular-nums"
                  >
                    {String(hr).padStart(2, '0')}:00
                  </div>
                ))}
              </div>

              {/* Kanvas Blok Linimasa */}
              <div className="relative flex-1 min-w-[320px] h-[1008px]">
                {TIMELINE_HOURS.map((hr) => (
                  <div key={hr} className="h-14 border-b border-border/50" />
                ))}

                {timelineData.blocks.length === 0 ? (
                  <div className="absolute inset-0 flex items-center justify-center p-6 pointer-events-none">
                    <div className="rounded-md border border-dashed border-border bg-subtle/80 px-4 py-3 text-xs text-muted-foreground text-center">
                      Belum ada blok jam terjadwal pada tanggal ini.
                    </div>
                  </div>
                ) : (
                  timelineData.blocks.map((block) => {
                    const widthPct = 100 / block.laneCount;
                    const leftPct = block.lane * widthPct;
                    return (
                      <div
                        key={block.item.id}
                        style={{
                          top: `${block.topPercent}%`,
                          height: `${block.heightPercent}%`,
                          left: `calc(${leftPct}% + 4px)`,
                          width: `calc(${widthPct}% - 8px)`,
                        }}
                        className={cn(
                          'absolute rounded-md border p-2 text-xs overflow-hidden shadow-card flex flex-col justify-between',
                          block.hasConflict
                            ? 'border-expense-border bg-expense-subtle text-foreground'
                            : block.item.item_type === 'task'
                            ? 'border-warning-border bg-warning-subtle text-foreground'
                            : 'border-primary bg-primary-subtle text-foreground'
                        )}
                      >
                        <div className="flex items-start justify-between gap-1.5 min-w-0">
                          <span className="font-semibold truncate">{block.item.title}</span>
                          {block.hasConflict && (
                            <StatusBadge variant="expense">Bentrok</StatusBadge>
                          )}
                        </div>
                        <div className="flex flex-wrap items-center gap-2 text-[11px] text-muted-foreground tabular-nums">
                          <span>
                            {formatMinutesLabel(block.startMinutes)} -{' '}
                            {formatMinutesLabel(block.endMinutes)} ({block.durationMinutes} mnt)
                          </span>
                          {block.item.location && (
                            <span className="truncate">{block.item.location}</span>
                          )}
                        </div>
                      </div>
                    );
                  })
                )}
              </div>
            </div>
          </CardContent>
        </Card>
      ) : (
        /* ================= TAMPILAN DAFTAR MINGGUAN ================= */
        <div className="space-y-4">
          {weekDays.map((dayDate) => {
            const dateStr = toWibDateKey(dayDate);
            const dayName = new Intl.DateTimeFormat('id-ID', { weekday: 'long' }).format(dayDate);
            const isToday = toWibDateKey(new Date()) === dateStr;

            const dayItems = filteredAgendaItems
              .filter((it) => it.starts_at && toWibDateKey(it.starts_at) === dateStr)
              .sort((a, b) => {
                if (a.all_day && !b.all_day) return -1;
                if (!a.all_day && b.all_day) return 1;
                return new Date(a.starts_at!).getTime() - new Date(b.starts_at!).getTime();
              });

            const dayConflicts = conflicts.filter((c) => c.conflict_date === dateStr);
            const conflictIds = new Set<string>();
            dayConflicts.forEach((c) => {
              if (c.event1_id) conflictIds.add(c.event1_id);
              if (c.event2_id) conflictIds.add(c.event2_id);
            });

            return (
              <Card key={dateStr} className={cn(isToday && 'border-primary')}>
                <div
                  className={cn(
                    'flex items-center justify-between px-4 py-2.5 border-b border-border bg-subtle/60 rounded-t-lg',
                    isToday && 'bg-primary-subtle'
                  )}
                >
                  <div className="flex items-center gap-2.5">
                    <CalendarIcon
                      className={cn(
                        'w-4 h-4',
                        isToday ? 'text-primary' : 'text-muted-foreground'
                      )}
                    />
                    <span
                      className={cn(
                        'text-sm font-semibold capitalize',
                        isToday ? 'text-primary' : 'text-foreground'
                      )}
                    >
                      {dayName}, {formatDateOnly(dateStr)}
                    </span>
                    {isToday && <StatusBadge variant="income">Hari Ini</StatusBadge>}
                  </div>
                  <span className="text-xs text-muted-foreground tabular-nums">
                    {dayItems.length} item
                  </span>
                </div>

                {dayItems.length === 0 ? (
                  <div className="px-4 py-3 text-xs text-muted-foreground italic">
                    Tidak ada jadwal atau tenggat pada hari ini.
                  </div>
                ) : (
                  <div className="divide-y divide-border">
                    {dayItems.map((item) => {
                      const rawEventId = item.event_id || item.id;
                      const isConflicting = conflictIds.has(rawEventId);

                      return (
                        <div
                          key={item.id}
                          className={cn(
                            'p-4 flex flex-col sm:flex-row sm:items-center justify-between gap-3 transition-colors hover:bg-hover',
                            isConflicting && 'bg-expense-subtle'
                          )}
                        >
                          <div className="flex items-start gap-3 min-w-0">
                            <div className="w-24 shrink-0 text-xs font-medium text-muted-foreground tabular-nums pt-0.5">
                              {item.item_type === 'task' ? (
                                <span className="inline-flex items-center gap-1 text-warning font-semibold">
                                  <ListChecks className="w-3.5 h-3.5" />
                                  Tenggat
                                </span>
                              ) : item.all_day ? (
                                <span className="text-primary font-semibold">Seharian</span>
                              ) : (
                                `${formatWibTime(item.starts_at!)} - ${formatWibTime(item.ends_at!)}`
                              )}
                            </div>

                            <div className="min-w-0 flex-1 space-y-1">
                              <div className="flex items-center gap-2 flex-wrap">
                                <span
                                  className={cn(
                                    'text-sm font-medium text-foreground',
                                    isConflicting && 'text-expense font-semibold'
                                  )}
                                >
                                  {item.title}
                                </span>
                                <KindBadge kind={item.kind} />
                                {item.is_recurring && (
                                  <span className="inline-flex items-center gap-1 rounded-sm border border-border bg-subtle px-1.5 py-0.5 text-[11px] text-muted-foreground">
                                    <Repeat className="w-3 h-3" />
                                    Berulang
                                  </span>
                                )}
                                {isConflicting && (
                                  <StatusBadge variant="expense">Bentrok</StatusBadge>
                                )}
                              </div>

                              {item.location && (
                                <div className="flex items-center gap-1 text-xs text-muted-foreground">
                                  <MapPin className="w-3.5 h-3.5" />
                                  <span>{item.location}</span>
                                </div>
                              )}
                            </div>
                          </div>

                          {item.item_type === 'event' && (
                            <div className="flex items-center gap-1.5 shrink-0">
                              {item.is_recurring && (
                                <Button
                                  variant="secondary"
                                  size="sm"
                                  onClick={() => {
                                    setExceptionTarget(item);
                                    setExceptionAction('override');
                                    setOverrideTitle(item.title);
                                    setOverrideLocation(item.location || '');
                                  }}
                                >
                                  Ubah Sesi Ini
                                </Button>
                              )}
                              <Button
                                variant="ghost"
                                size="icon"
                                onClick={() => handleDeleteEvent(item)}
                                aria-label="Hapus jadwal"
                                className="text-muted-foreground hover:text-expense"
                              >
                                <Trash2 className="w-4 h-4" />
                              </Button>
                            </div>
                          )}
                        </div>
                      );
                    })}
                  </div>
                )}
              </Card>
            );
          })}

          {filteredAgendaItems.length === 0 && (
            <EmptyState
              icon={<CalendarPlus className="w-8 h-8" />}
              title="Jadwal minggu ini kosong"
              description="Tambahkan jadwal kuliah, shift kerja, rapat proyek, atau impor berkas .ics Anda."
              actionLabel="Tambah Jadwal Pertama"
              onAction={() => openCreateModal()}
            />
          )}
        </div>
      )}

      {/* Modal Tambah Jadwal Baru */}
      <Dialog
        open={showEventModal}
        onClose={() => setShowEventModal(false)}
        title="Tambah Jadwal Baru"
        description="Buat agenda satu kali atau berulang secara otomatis."
      >
        <form onSubmit={handleSaveEvent} className="space-y-4">
          {formError && (
            <div className="p-3 text-xs bg-expense-subtle text-expense border border-expense-border rounded-md">
              {formError}
            </div>
          )}

          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">
              Nama Jadwal <span className="text-expense">*</span>
            </label>
            <Input
              value={formTitle}
              onChange={(e) => setFormTitle(e.target.value)}
              placeholder="Contoh: Kuliah Pemrograman Web"
              required
            />
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="text-xs font-medium text-foreground block mb-1.5">Kategori</label>
              <Select
                value={formKind}
                onChange={(e) => setFormKind(e.target.value as EventKind)}
              >
                <option value="kuliah">Kuliah</option>
                <option value="intern">Magang</option>
                <option value="freelance">Freelance</option>
                <option value="pribadi">Pribadi</option>
              </Select>
            </div>

            <div>
              <label className="text-xs font-medium text-foreground block mb-1.5">
                Terkait Proyek / Kegiatan
              </label>
              <Select value={formProjectId} onChange={(e) => setFormProjectId(e.target.value)}>
                <option value="">(Tidak ada)</option>
                {projects.map((p) => (
                  <option key={p.id} value={p.id}>
                    {p.name}
                  </option>
                ))}
              </Select>
            </div>
          </div>

          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">
              Lokasi / Tautan Rapat
            </label>
            <Input
              value={formLocation}
              onChange={(e) => setFormLocation(e.target.value)}
              placeholder="Contoh: Ruang B204 atau Google Meet"
            />
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
            <div>
              <label className="text-xs font-medium text-foreground block mb-1.5">Tanggal</label>
              <Input
                type="date"
                value={formDate}
                onChange={(e) => setFormDate(e.target.value)}
                required
              />
            </div>

            {!formAllDay && (
              <>
                <div>
                  <label className="text-xs font-medium text-foreground block mb-1.5">
                    Jam Mulai
                  </label>
                  <Input
                    type="time"
                    value={formStartTime}
                    onChange={(e) => setFormStartTime(e.target.value)}
                    required
                  />
                </div>
                <div>
                  <label className="text-xs font-medium text-foreground block mb-1.5">
                    Jam Selesai
                  </label>
                  <Input
                    type="time"
                    value={formEndTime}
                    onChange={(e) => setFormEndTime(e.target.value)}
                    required
                  />
                </div>
              </>
            )}
          </div>

          <label className="min-h-11 flex items-center gap-2 text-xs font-medium text-foreground cursor-pointer select-none">
            <input
              type="checkbox"
              checked={formAllDay}
              onChange={(e) => setFormAllDay(e.target.checked)}
              className="rounded border-border text-primary w-4 h-4"
            />
            Acara sepanjang hari (All Day)
          </label>

          <div className="pt-2 border-t border-border space-y-3">
            <label className="text-xs font-medium text-foreground block">Perulangan Jadwal</label>
            <Select
              value={formRecurrenceFreq}
              onChange={(e) => setFormRecurrenceFreq(e.target.value as 'none' | 'daily' | 'weekly')}
            >
              <option value="none">Tidak Berulang (Sekali)</option>
              <option value="daily">Setiap Hari</option>
              <option value="weekly">Setiap Minggu (Pilih Hari)</option>
            </Select>

            {formRecurrenceFreq === 'weekly' && (
              <div>
                <span className="text-xs text-muted-foreground block mb-1.5">
                  Pilih Hari Pengulangan:
                </span>
                <div className="flex flex-wrap gap-1.5">
                  {WEEKDAYS.map((wd) => {
                    const active = formByWeekday.includes(wd.val);
                    return (
                      <button
                        key={wd.val}
                        type="button"
                        onClick={() =>
                          setFormByWeekday((prev) =>
                            active ? prev.filter((x) => x !== wd.val) : [...prev, wd.val]
                          )
                        }
                        className={cn(
                          'min-h-11 px-3 rounded-md text-xs font-medium border transition-colors',
                          active
                            ? 'bg-primary text-primary-foreground border-primary'
                            : 'bg-subtle text-muted-foreground border-border hover:text-foreground'
                        )}
                      >
                        {wd.label}
                      </button>
                    );
                  })}
                </div>
              </div>
            )}

            {formRecurrenceFreq !== 'none' && (
              <div>
                <label className="text-xs font-medium text-foreground block mb-1.5">
                  Berulang Sampai Tanggal (Opsional)
                </label>
                <Input
                  type="date"
                  value={formRecurrenceUntil}
                  onChange={(e) => setFormRecurrenceUntil(e.target.value)}
                />
              </div>
            )}
          </div>

          <div className="flex justify-end gap-2 pt-3 border-t border-border">
            <Button type="button" variant="secondary" onClick={() => setShowEventModal(false)}>
              Batal
            </Button>
            <Button type="submit" disabled={savingEvent}>
              {savingEvent ? 'Menyimpan...' : 'Simpan Jadwal'}
            </Button>
          </div>
        </form>
      </Dialog>

      {/* Modal Ubah / Batalkan Sesi Berulang */}
      <Dialog
        open={!!exceptionTarget}
        onClose={() => setExceptionTarget(null)}
        title="Pengecualian Sesi Jadwal"
        description={
          exceptionTarget
            ? `Sesi tanggal ${formatDateOnly(exceptionTarget.starts_at || '')}`
            : ''
        }
      >
        <div className="space-y-4">
          <div className="grid grid-cols-2 gap-2">
            <button
              type="button"
              onClick={() => setExceptionAction('override')}
              className={cn(
                'min-h-11 rounded-md border text-xs font-medium flex items-center justify-center gap-1.5 transition-colors',
                exceptionAction === 'override'
                  ? 'border-primary bg-primary-subtle text-primary'
                  : 'border-border bg-subtle text-muted-foreground'
              )}
            >
              <Clock className="w-4 h-4" />
              <span>Ubah Sesi Ini</span>
            </button>
            <button
              type="button"
              onClick={() => setExceptionAction('skip')}
              className={cn(
                'min-h-11 rounded-md border text-xs font-medium flex items-center justify-center gap-1.5 transition-colors',
                exceptionAction === 'skip'
                  ? 'border-expense-border bg-expense-subtle text-expense'
                  : 'border-border bg-subtle text-muted-foreground'
              )}
            >
              <XCircle className="w-4 h-4" />
              <span>Batalkan Sesi Ini</span>
            </button>
          </div>

          {exceptionAction === 'override' ? (
            <div className="space-y-3">
              <div>
                <label className="text-xs font-medium text-foreground block mb-1.5">
                  Judul Pengganti (Opsional)
                </label>
                <Input
                  value={overrideTitle}
                  onChange={(e) => setOverrideTitle(e.target.value)}
                />
              </div>
              <div>
                <label className="text-xs font-medium text-foreground block mb-1.5">
                  Lokasi Pengganti (Opsional)
                </label>
                <Input
                  value={overrideLocation}
                  onChange={(e) => setOverrideLocation(e.target.value)}
                  placeholder="Contoh: Diganti Zoom / Ruang Baru"
                />
              </div>
            </div>
          ) : (
            <div className="p-3 rounded-md bg-expense-subtle border border-expense-border text-xs text-expense">
              Hanya sesi pada tanggal ini yang akan dihapus dari kalender. Jadwal di minggu lainnya
              tetap berjalan seperti biasa.
            </div>
          )}

          <div className="flex justify-end gap-2 pt-3 border-t border-border">
            <Button type="button" variant="secondary" onClick={() => setExceptionTarget(null)}>
              Batal
            </Button>
            <Button type="button" onClick={handleSaveException} disabled={savingException}>
              {savingException ? 'Menyimpan...' : 'Terapkan'}
            </Button>
          </div>
        </div>
      </Dialog>

      {/* Modal Impor .ics RFC 5545 */}
      <Dialog
        open={showIcsModal}
        onClose={() => setShowIcsModal(false)}
        title="Impor Jadwal dari Berkas .ics"
        description="Unggah file .ics dari Google Calendar, Apple Calendar, atau jadwal kuliah Anda."
      >
        <div className="space-y-4">
          {icsError && (
            <div className="p-3 text-xs bg-expense-subtle text-expense border border-expense-border rounded-md">
              {icsError}
            </div>
          )}

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="text-xs font-medium text-foreground block mb-1.5">
                Pilih Berkas .ics
              </label>
              <Input
                type="file"
                accept=".ics,text/calendar"
                onChange={handleIcsFileUpload}
              />
            </div>

            <div>
              <label className="text-xs font-medium text-foreground block mb-1.5">
                Kategori Default
              </label>
              <Select
                value={icsDefaultKind}
                onChange={(e) => setIcsDefaultKind(e.target.value as EventKind)}
              >
                <option value="pribadi">Pribadi</option>
                <option value="kuliah">Kuliah</option>
                <option value="intern">Magang</option>
                <option value="freelance">Freelance</option>
              </Select>
            </div>
          </div>

          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">
              Atau Tempel Isi Teks VCALENDAR (.ics)
            </label>
            <Textarea
              value={icsText}
              onChange={(e) => handleIcsTextChange(e.target.value)}
              placeholder={'BEGIN:VCALENDAR\nBEGIN:VEVENT\nSUMMARY:Contoh Rapat\nDTSTART:20261116T020000Z\nDTEND:20261116T030000Z\nEND:VEVENT\nEND:VCALENDAR'}
              rows={5}
            />
          </div>

          {parsedIcsEvents.length > 0 && (
            <div className="rounded-md border border-border bg-subtle p-3 space-y-2 max-h-48 overflow-y-auto">
              <div className="text-xs font-semibold text-foreground tabular-nums">
                Pratinjau: {parsedIcsEvents.length} acara siap diimpor
              </div>
              {parsedIcsEvents.slice(0, 8).map((ev, idx) => (
                <div
                  key={idx}
                  className="text-xs text-foreground border-b border-border/60 pb-1.5 last:border-b-0 last:pb-0 flex items-center justify-between gap-2"
                >
                  <span className="truncate font-medium">{ev.title}</span>
                  <span className="text-muted-foreground shrink-0 tabular-nums">
                    {formatDateOnly(ev.starts_at)}
                  </span>
                </div>
              ))}
            </div>
          )}

          <div className="flex justify-end gap-2 pt-3 border-t border-border">
            <Button type="button" variant="secondary" onClick={() => setShowIcsModal(false)}>
              Batal
            </Button>
            <Button
              type="button"
              onClick={handleCommitIcsImport}
              disabled={importingIcs || parsedIcsEvents.length === 0}
            >
              {importingIcs
                ? 'Mengimpor...'
                : `Impor ${parsedIcsEvents.length || 0} Acara`}
            </Button>
          </div>
        </div>
      </Dialog>
    </div>
  );
}
