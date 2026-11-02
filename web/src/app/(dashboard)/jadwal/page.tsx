'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';
import { formatDateIndo } from '@/lib/format';
import type { ActivityKind, ExceptionAction } from '@/types/database';
import {
  CalendarDays,
  Clock,
  Plus,
  Trash2,
  AlertTriangle,
  MapPin,
  ChevronLeft,
  ChevronRight,
  Repeat,
} from 'lucide-react';
import {
  Card,
  CardContent,
  Button,
  Input,
  Select,
  Dialog,
  SegmentedControl,
  KindBadge,
  StatusBadge,
  Skeleton,
  EmptyState,
  ErrorState,
  AgendaSubNav,
  ACTIVITY_KIND_META,
} from '@/components/ui';

type AgendaItem = {
  id: string;
  item_type: 'event' | 'task';
  kind: ActivityKind;
  title: string;
  description: string | null;
  project_id: string | null;
  project_name: string | null;
  project_color: string | null;
  starts_at: string | null;
  ends_at: string | null;
  all_day: boolean;
  location: string | null;
  status: string;
  priority: string | null;
  due_at: string | null;
  due_is_date_only: boolean;
  is_overdue: boolean;
  checklist_total: number;
  checklist_done: number;
  event_id: string | null;
  is_recurring: boolean;
  milestone_payment_id: string | null;
};

type ConflictItem = {
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
};

type ProjectOption = {
  id: string;
  name: string;
  kind: ActivityKind;
};

const DAYS_OF_WEEK = [
  { id: 1, label: 'Sen' },
  { id: 2, label: 'Sel' },
  { id: 3, label: 'Rab' },
  { id: 4, label: 'Kam' },
  { id: 5, label: 'Jum' },
  { id: 6, label: 'Sab' },
  { id: 7, label: 'Min' },
];

export default function JadwalPage() {
  const supabase = createClient();
  const [workspaceId, setWorkspaceId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);

  const [viewMode, setViewMode] = useState<'day' | 'week'>('week');
  const [filterKind, setFilterKind] = useState<ActivityKind | 'all'>('all');
  const [currentDate, setCurrentDate] = useState<Date>(new Date());

  const [agendaItems, setAgendaItems] = useState<AgendaItem[]>([]);
  const [conflicts, setConflicts] = useState<ConflictItem[]>([]);
  const [heavyDays, setHeavyDays] = useState<Set<string>>(new Set());
  const [projects, setProjects] = useState<ProjectOption[]>([]);

  const [showEventModal, setShowEventModal] = useState(false);

  const [formTitle, setFormTitle] = useState('');
  const [formDescription, setFormDescription] = useState('');
  const [formKind, setFormKind] = useState<ActivityKind>('kuliah');
  const [formProjectId, setFormProjectId] = useState('');
  const [formLocation, setFormLocation] = useState('');
  const [formDate, setFormDate] = useState('');
  const [formStartTime, setFormStartTime] = useState('08:00');
  const [formEndTime, setFormEndTime] = useState('10:00');
  const [formAllDay, setFormAllDay] = useState(false);

  const [formRecurrenceFreq, setFormRecurrenceFreq] = useState<'none' | 'daily' | 'weekly' | 'monthly'>('none');
  const [formByWeekday, setFormByWeekday] = useState<number[]>([1]);
  const [formRecurrenceUntil, setFormRecurrenceUntil] = useState('');

  const [savingEvent, setSavingEvent] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  const [exceptionTarget, setExceptionTarget] = useState<AgendaItem | null>(null);
  const [exceptionAction, setExceptionAction] = useState<ExceptionAction>('skip');
  const [overrideTitle, setOverrideTitle] = useState('');
  const [overrideLocation, setOverrideLocation] = useState('');
  const [savingException, setSavingException] = useState(false);

  const getDateRange = useCallback(() => {
    const start = new Date(currentDate);
    const end = new Date(currentDate);

    if (viewMode === 'week') {
      const day = start.getDay();
      const diffToMonday = day === 0 ? -6 : 1 - day;
      start.setDate(start.getDate() + diffToMonday);
      end.setDate(start.getDate() + 6);
    }

    return {
      startDateStr: start.toISOString().split('T')[0],
      endDateStr: end.toISOString().split('T')[0],
      start,
      end,
    };
  }, [currentDate, viewMode]);

  const loadData = useCallback(async () => {
    setLoading(true);
    setLoadError(null);

    try {
      const { data: memberData, error: memberErr } = await supabase
        .from('workspace_members')
        .select('workspace_id')
        .limit(1)
        .single();

      if (memberErr) throw memberErr;
      if (!memberData) {
        setLoading(false);
        return;
      }

      const wsId = memberData.workspace_id;
      setWorkspaceId(wsId);

      const { data: projData } = await supabase
        .from('projects')
        .select('id, name, kind')
        .eq('workspace_id', wsId)
        .is('deleted_at', null);

      if (projData) {
        setProjects(projData as unknown as ProjectOption[]);
      }

      const { startDateStr, endDateStr } = getDateRange();

      const { data: agendaData, error: agendaErr } = await supabase.rpc('fn_agenda', {
        p_workspace_id: wsId,
        p_start_date: startDateStr,
        p_end_date: endDateStr,
      });

      if (agendaErr) throw agendaErr;
      if (agendaData) {
        setAgendaItems(agendaData as AgendaItem[]);
      }

      const { data: conflictData } = await supabase.rpc('fn_detect_conflicts', {
        p_workspace_id: wsId,
        p_start_date: startDateStr,
        p_end_date: endDateStr,
      });

      if (conflictData) {
        const actualConflicts = (conflictData as ConflictItem[]).filter((c) => c.event1_id !== null);
        setConflicts(actualConflicts);

        const heavySet = new Set<string>();
        (conflictData as ConflictItem[]).forEach((c) => {
          if (c.is_heavy_day) {
            heavySet.add(c.conflict_date);
          }
        });
        setHeavyDays(heavySet);
      }
    } catch (err: unknown) {
      setLoadError(err instanceof Error ? err.message : 'Gagal memuat jadwal kegiatan.');
    } finally {
      setLoading(false);
    }
  }, [supabase, getDateRange]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  const handlePrev = () => {
    const next = new Date(currentDate);
    if (viewMode === 'day') next.setDate(next.getDate() - 1);
    else next.setDate(next.getDate() - 7);
    setCurrentDate(next);
  };

  const handleNext = () => {
    const next = new Date(currentDate);
    if (viewMode === 'day') next.setDate(next.getDate() + 1);
    else next.setDate(next.getDate() + 7);
    setCurrentDate(next);
  };

  const handleToday = () => {
    setCurrentDate(new Date());
  };

  const openCreateModal = () => {
    const todayStr = new Date().toISOString().split('T')[0];
    setFormTitle('');
    setFormDescription('');
    setFormKind('kuliah');
    setFormProjectId('');
    setFormLocation('');
    setFormDate(todayStr);
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

    const startsAt = new Date(`${formDate}T${formStartTime}:00+07:00`).toISOString();
    const endsAt = new Date(`${formDate}T${formEndTime}:00+07:00`).toISOString();

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

    const targetDate = exceptionTarget.starts_at.split('T')[0];
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
    if (!confirm('Hapus jadwal ini? Jika jadwal berulang, seluruh seri jadwal akan terhapus.')) return;
    await supabase.from('events').update({ deleted_at: new Date().toISOString() }).eq('id', eventId);
    loadData();
  };

  const weekDays = (() => {
    const { start } = getDateRange();
    const days = [];
    for (let i = 0; i < 7; i++) {
      const d = new Date(start);
      d.setDate(d.getDate() + i);
      days.push(d);
    }
    return days;
  })();

  const { startDateStr, endDateStr } = getDateRange();

  const filteredAgendaItems = agendaItems.filter((item) =>
    filterKind === 'all' ? true : item.kind === filterKind
  );

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-foreground">Agenda</h1>
          <p className="text-sm text-muted-foreground mt-0.5">
            Jadwal kegiatan berulang, pengecualian per tanggal, dan deteksi benturan waktu
          </p>
        </div>

        <Button onClick={openCreateModal}>
          <Plus className="w-4 h-4" />
          <span>Tambah Jadwal</span>
        </Button>
      </div>

      <AgendaSubNav />

      {/* Bar Filter Jenis Kegiatan & Mode Tampilan */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-3">
        <div className="flex items-center gap-1.5 overflow-x-auto pb-1">
          <button
            type="button"
            onClick={() => setFilterKind('all')}
            className={`min-h-11 px-3.5 py-2 rounded-lg text-xs font-medium transition-colors border ${
              filterKind === 'all'
                ? 'bg-primary text-primary-foreground border-primary'
                : 'bg-card text-muted-foreground border-border hover:text-foreground'
            }`}
          >
            Semua Jenis
          </button>
          {(['intern', 'freelance', 'kuliah', 'pribadi'] as ActivityKind[]).map((k) => (
            <button
              key={k}
              type="button"
              onClick={() => setFilterKind(k)}
              className={`min-h-11 px-3.5 py-2 rounded-lg text-xs font-medium transition-colors border ${
                filterKind === k
                  ? 'bg-primary text-primary-foreground border-primary'
                  : 'bg-card text-muted-foreground border-border hover:text-foreground'
              }`}
            >
              {ACTIVITY_KIND_META[k].label}
            </button>
          ))}
        </div>

        <SegmentedControl
          ariaLabel="Tampilan Jadwal"
          value={viewMode}
          onChange={setViewMode}
          options={[
            { value: 'day', label: 'Hari' },
            { value: 'week', label: 'Minggu' },
          ]}
        />
      </div>

      {/* Navigasi Periode & Peringatan Benturan */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <Button variant="secondary" size="sm" onClick={handlePrev} aria-label="Periode Sebelumnya">
            <ChevronLeft className="w-4 h-4" />
          </Button>
          <Button variant="secondary" size="sm" onClick={handleToday}>
            Hari Ini
          </Button>
          <Button variant="secondary" size="sm" onClick={handleNext} aria-label="Periode Berikutnya">
            <ChevronRight className="w-4 h-4" />
          </Button>

          <span className="text-sm font-semibold text-foreground ml-2 tabular-nums">
            {formatDateIndo(startDateStr)}
            {startDateStr !== endDateStr ? ` - ${formatDateIndo(endDateStr)}` : ''}
          </span>
        </div>

        {conflicts.length > 0 && (
          <StatusBadge variant="expense">
            <AlertTriangle className="w-3.5 h-3.5" />
            <span>{conflicts.length} benturan jadwal terdeteksi</span>
          </StatusBadge>
        )}
      </div>

      {loadError ? (
        <ErrorState message={loadError} onRetry={loadData} />
      ) : loading ? (
        <div className="space-y-3" aria-busy="true" aria-label="Memuat jadwal">
          <Skeleton className="h-24 w-full" />
          <Skeleton className="h-24 w-full" />
          <Skeleton className="h-24 w-full" />
        </div>
      ) : viewMode === 'week' ? (
        <div className="grid grid-cols-1 md:grid-cols-7 gap-3">
          {weekDays.map((dayDate) => {
            const dateStr = dayDate.toISOString().split('T')[0];
            const isToday = dateStr === new Date().toISOString().split('T')[0];
            const isHeavy = heavyDays.has(dateStr);

            const dayEvents = filteredAgendaItems.filter(
              (i) => i.starts_at && i.starts_at.startsWith(dateStr)
            );

            const dayHasConflict = conflicts.some((c) => c.conflict_date === dateStr);

            return (
              <Card
                key={dateStr}
                className={`p-3 flex flex-col space-y-2.5 min-h-[320px] ${
                  isToday ? 'border-primary bg-primary/5' : ''
                }`}
              >
                <div className="flex items-center justify-between pb-2 border-b border-border">
                  <div>
                    <div className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                      {dayDate.toLocaleDateString('id-ID', { weekday: 'short' })}
                    </div>
                    <div className={`text-base font-bold tabular-nums ${isToday ? 'text-primary' : 'text-foreground'}`}>
                      {dayDate.getDate()}
                    </div>
                  </div>

                  <div className="flex items-center gap-1">
                    {dayHasConflict && (
                      <StatusBadge variant="expense">Benturan</StatusBadge>
                    )}
                    {isHeavy && !dayHasConflict && (
                      <StatusBadge variant="warning">Padat</StatusBadge>
                    )}
                  </div>
                </div>

                <div className="space-y-2 flex-1 overflow-y-auto">
                  {dayEvents.length === 0 ? (
                    <div className="text-xs text-muted-foreground pt-4 text-center">
                      Kosong
                    </div>
                  ) : (
                    dayEvents.map((evt) => {
                      const startTime = evt.starts_at
                        ? new Date(evt.starts_at).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })
                        : '-';

                      return (
                        <div
                          key={evt.id}
                          className="p-2.5 rounded-lg border border-border bg-background text-xs space-y-1.5"
                        >
                          <div className="flex items-start justify-between gap-1">
                            <span className="font-semibold text-foreground line-clamp-2">
                              {evt.title}
                            </span>
                            {evt.is_recurring && (
                              <button
                                type="button"
                                title="Pengecualian Kejadian Ini"
                                onClick={() => setExceptionTarget(evt)}
                                className="min-h-8 min-w-8 inline-flex items-center justify-center rounded text-muted-foreground hover:text-foreground hover:bg-muted"
                              >
                                <Repeat className="w-3.5 h-3.5" />
                              </button>
                            )}
                          </div>

                          <div className="text-xs text-muted-foreground tabular-nums">
                            {evt.all_day ? 'Seharian' : startTime}
                          </div>

                          <div className="pt-0.5">
                            <KindBadge kind={evt.kind} />
                          </div>
                        </div>
                      );
                    })
                  )}
                </div>
              </Card>
            );
          })}
        </div>
      ) : filteredAgendaItems.length === 0 ? (
        <EmptyState
          icon={<CalendarDays className="w-5 h-5" />}
          title="Belum ada jadwal pada tanggal ini"
          description="Tambahkan jadwal kegiatan baru untuk mengatur agenda harian atau mingguan Anda."
          actionLabel="Tambah Jadwal"
          onAction={openCreateModal}
        />
      ) : (
        <div className="space-y-3">
          {filteredAgendaItems.map((item) => {
            const dateStr = item.starts_at ? item.starts_at.split('T')[0] : '';
            const startTime = item.starts_at
              ? new Date(item.starts_at).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })
              : '-';
            const endTime = item.ends_at
              ? new Date(item.ends_at).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })
              : '-';

            const hasConflict = conflicts.some(
              (c) => c.conflict_date === dateStr && (c.event1_id === item.event_id || c.event2_id === item.event_id)
            );

            return (
              <Card
                key={item.id}
                className={hasConflict ? 'border-expense/40 bg-expense/5' : ''}
              >
                <CardContent className="p-4 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                  <div className="space-y-1.5 flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="font-semibold text-sm text-foreground">
                        {item.title}
                      </span>
                      <KindBadge kind={item.kind} />
                      {item.is_recurring && (
                        <StatusBadge variant="neutral">
                          <Repeat className="w-3 h-3" />
                          <span>Berulang</span>
                        </StatusBadge>
                      )}
                      {hasConflict && (
                        <StatusBadge variant="expense">Benturan Waktu</StatusBadge>
                      )}
                    </div>

                    <div className="flex items-center gap-4 text-xs text-muted-foreground flex-wrap tabular-nums">
                      <span className="flex items-center gap-1">
                        <Clock className="w-3.5 h-3.5" />
                        {formatDateIndo(dateStr)} • {item.all_day ? 'Seharian' : `${startTime} - ${endTime}`}
                      </span>

                      {item.location && (
                        <span className="flex items-center gap-1">
                          <MapPin className="w-3.5 h-3.5" />
                          {item.location}
                        </span>
                      )}

                      {item.project_name && (
                        <span>Kegiatan: {item.project_name}</span>
                      )}
                    </div>

                    {item.description && (
                      <p className="text-xs text-muted-foreground">
                        {item.description}
                      </p>
                    )}
                  </div>

                  <div className="flex items-center gap-2 shrink-0">
                    {item.is_recurring && (
                      <Button
                        type="button"
                        variant="secondary"
                        size="sm"
                        onClick={() => setExceptionTarget(item)}
                      >
                        Pengecualian
                      </Button>
                    )}
                    <Button
                      type="button"
                      variant="ghost"
                      size="icon"
                      onClick={() => handleDeleteEvent(item)}
                      aria-label={`Hapus ${item.title}`}
                    >
                      <Trash2 className="w-4 h-4 text-muted-foreground hover:text-expense" />
                    </Button>
                  </div>
                </CardContent>
              </Card>
            );
          })}
        </div>
      )}

      {/* Modal Tambah Jadwal */}
      <Dialog
        open={showEventModal}
        onClose={() => setShowEventModal(false)}
        title="Tambah Jadwal Baru"
        description="Catat jadwal satu kali atau jadwal kegiatan berulang."
      >
        <form onSubmit={handleSaveEvent} className="space-y-4">
          {formError && (
            <div className="p-3 rounded-lg bg-expense/10 border border-expense/20 text-expense text-xs">
              {formError}
            </div>
          )}

          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">
              Judul Jadwal
            </label>
            <Input
              type="text"
              required
              placeholder="Misal: Kuliah Sistem Operasi atau Client Sync"
              value={formTitle}
              onChange={(e) => setFormTitle(e.target.value)}
            />
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="text-xs font-medium text-foreground block mb-1.5">
                Jenis Kegiatan
              </label>
              <Select
                value={formKind}
                onChange={(e) => setFormKind(e.target.value as ActivityKind)}
              >
                <option value="kuliah">Kuliah</option>
                <option value="intern">Magang</option>
                <option value="freelance">Freelance</option>
                <option value="pribadi">Pribadi</option>
              </Select>
            </div>

            <div>
              <label className="text-xs font-medium text-foreground block mb-1.5">
                Kegiatan Terkait (Opsional)
              </label>
              <Select
                value={formProjectId}
                onChange={(e) => setFormProjectId(e.target.value)}
              >
                <option value="">(Tanpa Kegiatan)</option>
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
              Lokasi (Opsional)
            </label>
            <Input
              type="text"
              placeholder="Misal: Ruang Lab 3 atau Google Meet"
              value={formLocation}
              onChange={(e) => setFormLocation(e.target.value)}
            />
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
            <div>
              <label className="text-xs font-medium text-foreground block mb-1.5">
                Tanggal
              </label>
              <Input
                type="date"
                required
                value={formDate}
                onChange={(e) => setFormDate(e.target.value)}
              />
            </div>
            <div>
              <label className="text-xs font-medium text-foreground block mb-1.5">
                Jam Mulai
              </label>
              <Input
                type="time"
                required={!formAllDay}
                disabled={formAllDay}
                value={formStartTime}
                onChange={(e) => setFormStartTime(e.target.value)}
              />
            </div>
            <div>
              <label className="text-xs font-medium text-foreground block mb-1.5">
                Jam Selesai
              </label>
              <Input
                type="time"
                required={!formAllDay}
                disabled={formAllDay}
                value={formEndTime}
                onChange={(e) => setFormEndTime(e.target.value)}
              />
            </div>
          </div>

          <div className="p-3.5 rounded-lg border border-border bg-muted/30 space-y-3">
            <div className="flex items-center justify-between gap-2">
              <label className="text-xs font-semibold text-foreground">
                Aturan Berulang
              </label>
              <Select
                value={formRecurrenceFreq}
                onChange={(e) => setFormRecurrenceFreq(e.target.value as 'none' | 'daily' | 'weekly' | 'monthly')}
                className="w-44"
              >
                <option value="none">Tidak Berulang</option>
                <option value="daily">Setiap Hari</option>
                <option value="weekly">Setiap Minggu</option>
                <option value="monthly">Setiap Bulan</option>
              </Select>
            </div>

            {formRecurrenceFreq === 'weekly' && (
              <div className="space-y-1.5">
                <label className="text-xs text-muted-foreground block">
                  Pilih Hari dalam Seminggu:
                </label>
                <div className="flex gap-1.5 flex-wrap">
                  {DAYS_OF_WEEK.map((d) => {
                    const selected = formByWeekday.includes(d.id);
                    return (
                      <button
                        key={d.id}
                        type="button"
                        onClick={() => {
                          if (selected) {
                            setFormByWeekday(formByWeekday.filter((id) => id !== d.id));
                          } else {
                            setFormByWeekday([...formByWeekday, d.id]);
                          }
                        }}
                        className={`min-h-11 min-w-11 px-2.5 rounded-lg text-xs font-medium transition-colors border ${
                          selected
                            ? 'bg-primary text-primary-foreground border-primary'
                            : 'bg-background border-border text-muted-foreground hover:text-foreground'
                        }`}
                      >
                        {d.label}
                      </button>
                    );
                  })}
                </div>
              </div>
            )}

            {formRecurrenceFreq !== 'none' && (
              <div>
                <label className="text-xs text-muted-foreground block mb-1">
                  Berakhir Pada Tanggal (Opsional)
                </label>
                <Input
                  type="date"
                  value={formRecurrenceUntil}
                  onChange={(e) => setFormRecurrenceUntil(e.target.value)}
                />
              </div>
            )}
          </div>

          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">
              Deskripsi / Keterangan
            </label>
            <Input
              type="text"
              placeholder="Catatan tambahan..."
              value={formDescription}
              onChange={(e) => setFormDescription(e.target.value)}
            />
          </div>

          <div className="flex justify-end gap-2 pt-3 border-t border-border">
            <Button
              type="button"
              variant="secondary"
              onClick={() => setShowEventModal(false)}
            >
              Batal
            </Button>
            <Button type="submit" disabled={savingEvent}>
              {savingEvent ? 'Menyimpan...' : 'Simpan Jadwal'}
            </Button>
          </div>
        </form>
      </Dialog>

      {/* Modal Pengecualian Jadwal Berulang */}
      <Dialog
        open={!!exceptionTarget}
        onClose={() => setExceptionTarget(null)}
        title="Pengecualian Jadwal Berulang"
        description={
          exceptionTarget
            ? `Kejadian "${exceptionTarget.title}" pada ${
                exceptionTarget.starts_at ? formatDateIndo(exceptionTarget.starts_at.split('T')[0]) : ''
              }`
            : undefined
        }
      >
        <div className="space-y-4">
          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">
              Tindakan
            </label>
            <Select
              value={exceptionAction}
              onChange={(e) => setExceptionAction(e.target.value as ExceptionAction)}
            >
              <option value="skip">Lewati kejadian ini (Libur / Dibatalkan)</option>
              <option value="override">Ubah khusus tanggal ini (Judul / Lokasi)</option>
            </Select>
          </div>

          {exceptionAction === 'override' && (
            <>
              <div>
                <label className="text-xs font-medium text-foreground block mb-1.5">
                  Judul Baru (Khusus Tanggal Ini)
                </label>
                <Input
                  type="text"
                  placeholder={exceptionTarget?.title || ''}
                  value={overrideTitle}
                  onChange={(e) => setOverrideTitle(e.target.value)}
                />
              </div>
              <div>
                <label className="text-xs font-medium text-foreground block mb-1.5">
                  Lokasi Baru (Khusus Tanggal Ini)
                </label>
                <Input
                  type="text"
                  placeholder="Ruang Lab Baru"
                  value={overrideLocation}
                  onChange={(e) => setOverrideLocation(e.target.value)}
                />
              </div>
            </>
          )}

          <div className="flex justify-end gap-2 pt-3 border-t border-border">
            <Button
              type="button"
              variant="secondary"
              onClick={() => setExceptionTarget(null)}
            >
              Batal
            </Button>
            <Button
              type="button"
              disabled={savingException}
              onClick={handleSaveException}
            >
              {savingException ? 'Menyimpan...' : 'Terapkan Pengecualian'}
            </Button>
          </div>
        </div>
      </Dialog>
    </div>
  );
}
