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
  Edit2,
  AlertTriangle,
  AlertCircle,
  MapPin,
  ChevronLeft,
  ChevronRight,
  User,
  Briefcase,
  Laptop,
  GraduationCap,
  X,
  Repeat
} from 'lucide-react';

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

const KIND_CONFIG: Record<ActivityKind, { label: string; icon: typeof User; color: string }> = {
  intern: { label: 'Magang', icon: Briefcase, color: 'text-blue-500 bg-blue-500/10' },
  freelance: { label: 'Freelance', icon: Laptop, color: 'text-purple-500 bg-purple-500/10' },
  kuliah: { label: 'Kuliah', icon: GraduationCap, color: 'text-amber-500 bg-amber-500/10' },
  pribadi: { label: 'Pribadi', icon: User, color: 'text-emerald-500 bg-emerald-500/10' },
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

  // View: 'day', 'week', 'agenda'
  const [viewMode, setViewMode] = useState<'day' | 'week' | 'agenda'>('week');

  // Tanggal acuan (anchor date)
  const [currentDate, setCurrentDate] = useState<Date>(new Date());

  // Data
  const [agendaItems, setAgendaItems] = useState<AgendaItem[]>([]);
  const [conflicts, setConflicts] = useState<ConflictItem[]>([]);
  const [heavyDays, setHeavyDays] = useState<Set<string>>(new Set());
  const [projects, setProjects] = useState<ProjectOption[]>([]);

  // Modal Tambah Event
  const [showEventModal, setShowEventModal] = useState(false);
  const [modalMode, setModalMode] = useState<'create' | 'edit'>('create');
  const [editingEventId, setEditingEventId] = useState<string | null>(null);

  // Form Event
  const [formTitle, setFormTitle] = useState('');
  const [formDescription, setFormDescription] = useState('');
  const [formKind, setFormKind] = useState<ActivityKind>('kuliah');
  const [formProjectId, setFormProjectId] = useState('');
  const [formLocation, setFormLocation] = useState('');
  const [formDate, setFormDate] = useState('');
  const [formStartTime, setFormStartTime] = useState('08:00');
  const [formEndTime, setFormEndTime] = useState('10:00');
  const [formAllDay, setFormAllDay] = useState(false);

  // Recurrence
  const [formRecurrenceFreq, setFormRecurrenceFreq] = useState<'none' | 'daily' | 'weekly' | 'monthly'>('none');
  const [formByWeekday, setFormByWeekday] = useState<number[]>([1]);
  const [formRecurrenceUntil, setFormRecurrenceUntil] = useState('');

  const [savingEvent, setSavingEvent] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  // Exception Modal
  const [exceptionTarget, setExceptionTarget] = useState<AgendaItem | null>(null);
  const [exceptionAction, setExceptionAction] = useState<ExceptionAction>('skip');
  const [overrideTitle, setOverrideTitle] = useState('');
  const [overrideLocation, setOverrideLocation] = useState('');
  const [savingException, setSavingException] = useState(false);

  // Hitung rentang tanggal berdasarkan viewMode
  const getDateRange = useCallback(() => {
    const start = new Date(currentDate);
    const end = new Date(currentDate);

    if (viewMode === 'day') {
      // Sama antara start dan end
    } else if (viewMode === 'week') {
      // Ambil Senin minggu ini sampai Minggu
      const day = start.getDay(); // 0 is Sunday, 1 is Monday
      const diffToMonday = day === 0 ? -6 : 1 - day;
      start.setDate(start.getDate() + diffToMonday);
      end.setDate(start.getDate() + 6);
    } else if (viewMode === 'agenda') {
      // 14 hari ke depan
      end.setDate(start.getDate() + 14);
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

    const { data: memberData } = await supabase
      .from('workspace_members')
      .select('workspace_id')
      .limit(1)
      .single();

    if (!memberData) {
      setLoading(false);
      return;
    }

    const wsId = memberData.workspace_id;
    setWorkspaceId(wsId);

    // Ambil proyek
    const { data: projData } = await supabase
      .from('projects')
      .select('id, name, kind')
      .eq('workspace_id', wsId)
      .is('deleted_at', null);

    if (projData) {
      setProjects(projData as unknown as ProjectOption[]);
    }

    const { startDateStr, endDateStr } = getDateRange();

    // 1. Panggil fn_agenda
    const { data: agendaData } = await supabase.rpc('fn_agenda', {
      p_workspace_id: wsId,
      p_start_date: startDateStr,
      p_end_date: endDateStr,
    });

    if (agendaData) {
      setAgendaItems(agendaData as AgendaItem[]);
    }

    // 2. Panggil fn_detect_conflicts
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

    setLoading(false);
  }, [supabase, getDateRange]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  // Navigasi prev / next
  const handlePrev = () => {
    const next = new Date(currentDate);
    if (viewMode === 'day') next.setDate(next.getDate() - 1);
    else if (viewMode === 'week') next.setDate(next.getDate() - 7);
    else next.setDate(next.getDate() - 14);
    setCurrentDate(next);
  };

  const handleNext = () => {
    const next = new Date(currentDate);
    if (viewMode === 'day') next.setDate(next.getDate() + 1);
    else if (viewMode === 'week') next.setDate(next.getDate() + 7);
    else next.setDate(next.getDate() + 14);
    setCurrentDate(next);
  };

  const handleToday = () => {
    setCurrentDate(new Date());
  };

  // Reset & buka form event
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
    setModalMode('create');
    setShowEventModal(true);
  };

  // Simpan Event
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

  // Simpan Pengecualian Jadwal (Skip atau Override)
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

  // Hapus event asal (soft delete)
  const handleDeleteEvent = async (item: AgendaItem) => {
    const eventId = item.event_id || item.id;
    if (!confirm('Hapus jadwal ini? Jika jadwal berulang, seluruh seri jadwal akan terhapus.')) return;
    await supabase.from('events').update({ deleted_at: new Date().toISOString() }).eq('id', eventId);
    loadData();
  };

  // Menyiapkan 7 hari untuk week view
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

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Jadwal</h1>
          <p className="text-sm text-muted-foreground mt-0.5">
            Jadwal kegiatan berulang, pengecualian per tanggal, dan deteksi benturan waktu.
          </p>
        </div>

        <div className="flex items-center gap-2">
          {/* View mode toggle */}
          <div className="flex items-center border border-border rounded-md p-0.5 bg-card text-xs">
            <button
              type="button"
              onClick={() => setViewMode('day')}
              className={`px-2.5 py-1 rounded transition-colors ${
                viewMode === 'day' ? 'bg-muted text-foreground font-medium' : 'text-muted-foreground hover:text-foreground'
              }`}
            >
              Hari
            </button>
            <button
              type="button"
              onClick={() => setViewMode('week')}
              className={`px-2.5 py-1 rounded transition-colors ${
                viewMode === 'week' ? 'bg-muted text-foreground font-medium' : 'text-muted-foreground hover:text-foreground'
              }`}
            >
              Minggu
            </button>
            <button
              type="button"
              onClick={() => setViewMode('agenda')}
              className={`px-2.5 py-1 rounded transition-colors ${
                viewMode === 'agenda' ? 'bg-muted text-foreground font-medium' : 'text-muted-foreground hover:text-foreground'
              }`}
            >
              Agenda
            </button>
          </div>

          <button
            type="button"
            onClick={openCreateModal}
            className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium bg-foreground text-background rounded-md hover:bg-foreground/90 transition-colors"
          >
            <Plus className="w-3.5 h-3.5" />
            <span>Tambah Jadwal</span>
          </button>
        </div>
      </div>

      {/* Navigasi Periode & Peringatan Benturan */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-3">
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={handlePrev}
            className="p-1.5 rounded-md border border-border bg-card text-muted-foreground hover:text-foreground"
          >
            <ChevronLeft className="w-4 h-4" />
          </button>
          <button
            type="button"
            onClick={handleToday}
            className="px-2.5 py-1 text-xs border border-border rounded-md bg-card text-foreground hover:bg-muted font-medium"
          >
            Hari Ini
          </button>
          <button
            type="button"
            onClick={handleNext}
            className="p-1.5 rounded-md border border-border bg-card text-muted-foreground hover:text-foreground"
          >
            <ChevronRight className="w-4 h-4" />
          </button>

          <span className="text-sm font-medium text-foreground ml-2">
            {formatDateIndo(startDateStr)} {startDateStr !== endDateStr ? ` – ${formatDateIndo(endDateStr)}` : ''}
          </span>
        </div>

        {conflicts.length > 0 && (
          <div className="flex items-center gap-1.5 text-xs text-red-600 dark:text-red-400 font-medium">
            <AlertTriangle className="w-4 h-4 shrink-0" />
            <span>{conflicts.length} benturan jadwal terdeteksi pada periode ini</span>
          </div>
        )}
      </div>

      {/* Tampilan Minggu: Grid 7 Hari */}
      {viewMode === 'week' && (
        <div className="grid grid-cols-1 md:grid-cols-7 gap-2">
          {weekDays.map((dayDate) => {
            const dateStr = dayDate.toISOString().split('T')[0];
            const isToday = dateStr === new Date().toISOString().split('T')[0];
            const isHeavy = heavyDays.has(dateStr);

            // Filter event pada hari ini
            const dayEvents = agendaItems.filter(
              (i) => i.starts_at && i.starts_at.startsWith(dateStr)
            );

            // Deteksi jika ada konflik pada hari ini
            const dayHasConflict = conflicts.some((c) => c.conflict_date === dateStr);

            return (
              <div
                key={dateStr}
                className={`p-2.5 rounded-lg border flex flex-col space-y-2 min-h-[350px] transition-colors ${
                  isToday
                    ? 'border-foreground/30 bg-muted/20'
                    : 'border-border bg-card'
                }`}
              >
                <div className="flex items-center justify-between pb-1.5 border-b border-border/60">
                  <div>
                    <div className="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
                      {dayDate.toLocaleDateString('id-ID', { weekday: 'short' })}
                    </div>
                    <div className={`text-sm font-bold ${isToday ? 'text-foreground' : 'text-foreground/80'}`}>
                      {dayDate.getDate()}
                    </div>
                  </div>

                  <div className="flex items-center gap-1">
                    {dayHasConflict && (
                      <span title="Benturan Jadwal">
                        <AlertTriangle className="w-3.5 h-3.5 text-red-500" />
                      </span>
                    )}
                    {isHeavy && (
                      <span
                        title="Hari Padat (durasi >= 8 jam)"
                        className="w-2 h-2 rounded-full bg-amber-500"
                      />
                    )}
                  </div>
                </div>

                {/* Event list */}
                <div className="space-y-1.5 flex-1 overflow-y-auto">
                  {dayEvents.length === 0 ? (
                    <div className="text-[10px] text-muted-foreground/50 pt-2 text-center">
                      -
                    </div>
                  ) : (
                    dayEvents.map((evt) => {
                      const cfg = KIND_CONFIG[evt.kind];
                      const startTime = evt.starts_at
                        ? new Date(evt.starts_at).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' })
                        : '-';

                      return (
                        <div
                          key={evt.id}
                          className="p-2 rounded border border-border/80 bg-background text-[11px] space-y-1 shadow-2xs"
                        >
                          <div className="flex items-center justify-between">
                            <span className="font-semibold text-foreground truncate max-w-[90px]">
                              {evt.title}
                            </span>
                            {evt.is_recurring && (
                              <button
                                type="button"
                                title="Pengecualian / Ubah Kejadian Ini"
                                onClick={() => setExceptionTarget(evt)}
                                className="text-muted-foreground hover:text-foreground"
                              >
                                <Repeat className="w-2.5 h-2.5" />
                              </button>
                            )}
                          </div>

                          <div className="text-[10px] text-muted-foreground flex items-center justify-between">
                            <span>{evt.all_day ? 'Seharian' : startTime}</span>
                            <span className={`px-1 rounded text-[9px] font-medium ${cfg.color}`}>
                              {cfg.label}
                            </span>
                          </div>
                        </div>
                      );
                    })
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Tampilan Hari atau Agenda: List View */}
      {(viewMode === 'day' || viewMode === 'agenda') && (
        <div className="space-y-3">
          {loading ? (
            <div className="p-8 text-center text-xs text-muted-foreground border border-border rounded-lg bg-card">
              Memuat jadwal...
            </div>
          ) : agendaItems.length === 0 ? (
            <div className="p-8 text-center text-xs text-muted-foreground border border-dashed border-border rounded-lg">
              Tidak ada kegiatan terjadwal pada rentang ini.
            </div>
          ) : (
            agendaItems.map((item) => {
              const cfg = KIND_CONFIG[item.kind];
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
                <div
                  key={item.id}
                  className={`p-3.5 rounded-lg border transition-colors flex items-start justify-between gap-3 ${
                    hasConflict
                      ? 'border-red-500/40 bg-red-500/5'
                      : 'border-border bg-card'
                  }`}
                >
                  <div className="space-y-1 flex-1 min-w-0">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="font-semibold text-sm text-foreground">
                        {item.title}
                      </span>
                      <span className={`text-[10px] px-1.5 py-0.5 rounded font-medium ${cfg.color}`}>
                        {cfg.label}
                      </span>
                      {item.is_recurring && (
                        <span className="text-[10px] px-1.5 py-0.5 rounded font-medium bg-muted text-muted-foreground flex items-center gap-1">
                          <Repeat className="w-2.5 h-2.5" /> Berulang
                        </span>
                      )}
                      {hasConflict && (
                        <span className="text-[10px] px-1.5 py-0.5 rounded font-medium bg-red-500/10 text-red-600 dark:text-red-400">
                          Benturan Waktu
                        </span>
                      )}
                    </div>

                    <div className="flex items-center gap-4 text-xs text-muted-foreground">
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
                        <span>Proyek: {item.project_name}</span>
                      )}
                    </div>

                    {item.description && (
                      <p className="text-xs text-muted-foreground mt-1">
                        {item.description}
                      </p>
                    )}
                  </div>

                  <div className="flex items-center gap-2 shrink-0">
                    {item.is_recurring && (
                      <button
                        type="button"
                        onClick={() => setExceptionTarget(item)}
                        className="px-2 py-1 text-xs border border-border rounded hover:bg-muted text-muted-foreground transition-colors"
                      >
                        Pengecualian
                      </button>
                    )}
                    <button
                      type="button"
                      onClick={() => handleDeleteEvent(item)}
                      className="p-1 text-muted-foreground hover:text-expense transition-colors"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </div>
              );
            })
          )}
        </div>
      )}

      {/* Modal Tambah Jadwal */}
      {showEventModal && (
        <div className="fixed inset-0 z-50 bg-background/80 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
          <form
            onSubmit={handleSaveEvent}
            className="bg-card border border-border rounded-lg shadow-lg max-w-lg w-full p-6 space-y-4 my-8"
          >
            <div className="flex items-center justify-between">
              <h3 className="font-semibold text-base text-foreground">
                Tambah Jadwal Baru
              </h3>
              <button
                type="button"
                onClick={() => setShowEventModal(false)}
                className="text-muted-foreground hover:text-foreground"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            {formError && (
              <div className="p-3 rounded bg-red-500/10 border border-red-500/20 text-red-600 dark:text-red-400 text-xs">
                {formError}
              </div>
            )}

            <div className="space-y-3">
              <div>
                <label className="text-xs font-medium text-foreground block mb-1">
                  Judul Jadwal
                </label>
                <input
                  type="text"
                  required
                  placeholder="Misal: Kuliah Sistem Operasi atau Client Sync"
                  value={formTitle}
                  onChange={(e) => setFormTitle(e.target.value)}
                  className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">
                    Jenis Kegiatan
                  </label>
                  <select
                    value={formKind}
                    onChange={(e) => setFormKind(e.target.value as ActivityKind)}
                    className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
                  >
                    <option value="kuliah">Kuliah</option>
                    <option value="intern">Magang</option>
                    <option value="freelance">Freelance</option>
                    <option value="pribadi">Pribadi</option>
                  </select>
                </div>

                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">
                    Proyek Terkait (Opsional)
                  </label>
                  <select
                    value={formProjectId}
                    onChange={(e) => setFormProjectId(e.target.value)}
                    className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
                  >
                    <option value="">(Tanpa Proyek)</option>
                    {projects.map((p) => (
                      <option key={p.id} value={p.id}>
                        {p.name}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              <div>
                <label className="text-xs font-medium text-foreground block mb-1">
                  Lokasi (Opsional)
                </label>
                <input
                  type="text"
                  placeholder="Misal: Ruang Lab 3 atau Google Meet"
                  value={formLocation}
                  onChange={(e) => setFormLocation(e.target.value)}
                  className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
                />
              </div>

              <div className="grid grid-cols-3 gap-2">
                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">
                    Tanggal
                  </label>
                  <input
                    type="date"
                    required
                    value={formDate}
                    onChange={(e) => setFormDate(e.target.value)}
                    className="w-full text-sm rounded-md border border-border bg-background px-2.5 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
                  />
                </div>
                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">
                    Jam Mulai
                  </label>
                  <input
                    type="time"
                    required={!formAllDay}
                    disabled={formAllDay}
                    value={formStartTime}
                    onChange={(e) => setFormStartTime(e.target.value)}
                    className="w-full text-sm rounded-md border border-border bg-background px-2.5 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground disabled:opacity-50"
                  />
                </div>
                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">
                    Jam Selesai
                  </label>
                  <input
                    type="time"
                    required={!formAllDay}
                    disabled={formAllDay}
                    value={formEndTime}
                    onChange={(e) => setFormEndTime(e.target.value)}
                    className="w-full text-sm rounded-md border border-border bg-background px-2.5 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground disabled:opacity-50"
                  />
                </div>
              </div>

              {/* Aturan Berulang */}
              <div className="p-3 rounded-lg border border-border bg-muted/20 space-y-3">
                <div className="flex items-center justify-between">
                  <label className="text-xs font-semibold text-foreground">
                    Aturan Berulang
                  </label>
                  <select
                    value={formRecurrenceFreq}
                    onChange={(e) => setFormRecurrenceFreq(e.target.value as 'none' | 'daily' | 'weekly' | 'monthly')}
                    className="text-xs rounded border border-border bg-background px-2 py-1 text-foreground"
                  >
                    <option value="none">Tidak Berulang</option>
                    <option value="daily">Setiap Hari</option>
                    <option value="weekly">Setiap Minggu</option>
                    <option value="monthly">Setiap Bulan</option>
                  </select>
                </div>

                {formRecurrenceFreq === 'weekly' && (
                  <div className="space-y-1.5">
                    <label className="text-[11px] text-muted-foreground block">
                      Pilih Hari dalam Seminggu:
                    </label>
                    <div className="flex gap-1.5">
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
                            className={`w-8 h-8 rounded text-xs font-medium transition-colors ${
                              selected
                                ? 'bg-foreground text-background'
                                : 'bg-muted border border-border text-muted-foreground hover:text-foreground'
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
                    <label className="text-[11px] text-muted-foreground block mb-1">
                      Berakhir Pada Tanggal (Opsional)
                    </label>
                    <input
                      type="date"
                      value={formRecurrenceUntil}
                      onChange={(e) => setFormRecurrenceUntil(e.target.value)}
                      className="w-full text-xs rounded border border-border bg-background px-2.5 py-1.5 text-foreground"
                    />
                  </div>
                )}
              </div>

              <div>
                <label className="text-xs font-medium text-foreground block mb-1">
                  Deskripsi / Keterangan
                </label>
                <textarea
                  rows={2}
                  value={formDescription}
                  onChange={(e) => setFormDescription(e.target.value)}
                  className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
                />
              </div>
            </div>

            <div className="flex justify-end gap-2 pt-2 border-t border-border">
              <button
                type="button"
                onClick={() => setShowEventModal(false)}
                className="px-3 py-1.5 text-xs font-medium border border-border rounded-md hover:bg-muted text-muted-foreground transition-colors"
              >
                Batal
              </button>
              <button
                type="submit"
                disabled={savingEvent}
                className="px-3 py-1.5 text-xs font-medium bg-foreground text-background rounded-md hover:bg-foreground/90 transition-colors disabled:opacity-50"
              >
                {savingEvent ? 'Menyimpan...' : 'Simpan Jadwal'}
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Modal Pengecualian Jadwal Berulang */}
      {exceptionTarget && (
        <div className="fixed inset-0 z-50 bg-background/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-card border border-border rounded-lg shadow-lg max-w-sm w-full p-6 space-y-4">
            <h3 className="font-semibold text-base text-foreground">
              Pengecualian Jadwal
            </h3>
            <p className="text-xs text-muted-foreground">
              Kejadian: &ldquo;{exceptionTarget.title}&rdquo; pada {exceptionTarget.starts_at ? formatDateIndo(exceptionTarget.starts_at.split('T')[0]) : ''}.
            </p>

            <div className="space-y-3">
              <div>
                <label className="text-xs font-medium text-foreground block mb-1">
                  Tindakan
                </label>
                <select
                  value={exceptionAction}
                  onChange={(e) => setExceptionAction(e.target.value as ExceptionAction)}
                  className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground"
                >
                  <option value="skip">Lewati kejadian ini (Libur / Dibatalkan)</option>
                  <option value="override">Ubah khusus tanggal ini (Jam / Ruang / Judul)</option>
                </select>
              </div>

              {exceptionAction === 'override' && (
                <>
                  <div>
                    <label className="text-xs font-medium text-foreground block mb-1">
                      Judul Baru (Khusus Tanggal Ini)
                    </label>
                    <input
                      type="text"
                      placeholder={exceptionTarget.title}
                      value={overrideTitle}
                      onChange={(e) => setOverrideTitle(e.target.value)}
                      className="w-full text-xs rounded border border-border bg-background px-2.5 py-1.5 text-foreground"
                    />
                  </div>
                  <div>
                    <label className="text-xs font-medium text-foreground block mb-1">
                      Lokasi Baru (Khusus Tanggal Ini)
                    </label>
                    <input
                      type="text"
                      placeholder="Ruang Lab Baru"
                      value={overrideLocation}
                      onChange={(e) => setOverrideLocation(e.target.value)}
                      className="w-full text-xs rounded border border-border bg-background px-2.5 py-1.5 text-foreground"
                    />
                  </div>
                </>
              )}
            </div>

            <div className="flex justify-end gap-2 pt-2">
              <button
                type="button"
                onClick={() => setExceptionTarget(null)}
                className="px-3 py-1.5 text-xs font-medium border border-border rounded-md hover:bg-muted text-muted-foreground transition-colors"
              >
                Batal
              </button>
              <button
                type="button"
                disabled={savingException}
                onClick={handleSaveException}
                className="px-3 py-1.5 text-xs font-medium bg-foreground text-background rounded-md hover:bg-foreground/90 transition-colors disabled:opacity-50"
              >
                {savingException ? 'Menyimpan...' : 'Terapkan Pengecualian'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
