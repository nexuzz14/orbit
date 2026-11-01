'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';
import { formatCurrency, formatDateIndo } from '@/lib/format';
import type { ActivityKind } from '@/types/database';
import {
  Calendar,
  Clock,
  AlertTriangle,
  CheckCircle2,
  Circle,
  Briefcase,
  GraduationCap,
  Laptop,
  User,
  Plus,
  ArrowRight,
  Wallet,
  Inbox,
  AlertCircle,
  MapPin,
  Check,
  CheckSquare
} from 'lucide-react';
import Link from 'next/link';

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

type ReceivableItem = {
  payment_id: string;
  project_id: string;
  project_name: string;
  client_name: string | null;
  label: string;
  amount: number;
  remaining_amount: number;
  due_date: string | null;
  status: string;
  is_overdue: boolean;
  days_overdue: number;
};

type AccountItem = {
  id: string;
  name: string;
};

const KIND_CONFIG: Record<ActivityKind, { label: string; icon: typeof User; color: string }> = {
  intern: { label: 'Magang', icon: Briefcase, color: 'text-blue-500 bg-blue-500/10' },
  freelance: { label: 'Freelance', icon: Laptop, color: 'text-purple-500 bg-purple-500/10' },
  kuliah: { label: 'Kuliah', icon: GraduationCap, color: 'text-amber-500 bg-amber-500/10' },
  pribadi: { label: 'Pribadi', icon: User, color: 'text-emerald-500 bg-emerald-500/10' },
};

export default function HariIniPage() {
  const supabase = createClient();
  const [loading, setLoading] = useState(true);
  const [workspaceId, setWorkspaceId] = useState<string | null>(null);
  const [selectedKind, setSelectedKind] = useState<ActivityKind | 'all'>('all');

  // Data
  const [agendaItems, setAgendaItems] = useState<AgendaItem[]>([]);
  const [conflicts, setConflicts] = useState<ConflictItem[]>([]);
  const [isHeavyDay, setIsHeavyDay] = useState(false);
  const [receivables, setReceivables] = useState<ReceivableItem[]>([]);
  const [liquidBalance, setLiquidBalance] = useState<number>(0);
  const [draftCount, setDraftCount] = useState<number>(0);
  const [accounts, setAccounts] = useState<AccountItem[]>([]);

  // Dialog milestone confirmation
  const [showMilestoneModal, setShowMilestoneModal] = useState(false);
  const [pendingMilestoneId, setPendingMilestoneId] = useState<string | null>(null);
  const [pendingTaskTitle, setPendingTaskTitle] = useState<string>('');
  const [selectedAccountId, setSelectedAccountId] = useState<string>('');
  const [markingPaid, setMarkingPaid] = useState(false);

  // Quick Add Task modal
  const [showQuickTaskModal, setShowQuickTaskModal] = useState(false);
  const [newTaskTitle, setNewTaskTitle] = useState('');
  const [newTaskKind, setNewTaskKind] = useState<ActivityKind>('pribadi');
  const [newTaskPriority, setNewTaskPriority] = useState<'rendah' | 'sedang' | 'tinggi'>('sedang');
  const [savingTask, setSavingTask] = useState(false);

  const today = new Date();
  const todayStr = today.toISOString().split('T')[0];

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

    // Ambil akun untuk pelunasan
    const { data: accData } = await supabase
      .from('accounts')
      .select('id, name')
      .eq('workspace_id', wsId)
      .is('deleted_at', null)
      .order('sort_order');

    if (accData) {
      setAccounts(accData);
      if (accData.length > 0 && !selectedAccountId) {
        setSelectedAccountId(accData[0].id);
      }
    }

    // 1. Panggil fn_agenda
    const kindFilter = selectedKind === 'all' ? undefined : selectedKind;
    const { data: agendaData, error: agendaError } = await supabase.rpc('fn_agenda', {
      p_workspace_id: wsId,
      p_start_date: todayStr,
      p_end_date: todayStr,
      p_kind: kindFilter,
    });

    if (!agendaError && agendaData) {
      setAgendaItems(agendaData as AgendaItem[]);
    }

    // 2. Panggil fn_detect_conflicts
    const { data: conflictData } = await supabase.rpc('fn_detect_conflicts', {
      p_workspace_id: wsId,
      p_start_date: todayStr,
      p_end_date: todayStr,
    });

    if (conflictData) {
      const actualConflicts = (conflictData as ConflictItem[]).filter((c) => c.event1_id !== null);
      setConflicts(actualConflicts);
      const heavy = (conflictData as ConflictItem[]).some((c) => c.is_heavy_day);
      setIsHeavyDay(heavy);
    }

    // 3. Ambil piutang jatuh tempo / overdue dari v_receivables
    const { data: recData } = await supabase
      .from('v_receivables')
      .select('*')
      .eq('workspace_id', wsId)
      .order('due_date', { ascending: true })
      .limit(3);

    if (recData) {
      setReceivables(recData as ReceivableItem[]);
    }

    // 4. Saldo ringkas dari v_account_balances
    const { data: balData } = await supabase
      .from('v_account_balances')
      .select('balance, is_liquid')
      .eq('workspace_id', wsId);

    if (balData) {
      const liquidTotal = balData
        .filter((b) => b.is_liquid)
        .reduce((sum, b) => sum + Number(b.balance || 0), 0);
      setLiquidBalance(liquidTotal);
    }

    // 5. Hitung draft di Inbox
    const { count: draftCnt } = await supabase
      .from('transactions')
      .select('*', { count: 'exact', head: true })
      .eq('workspace_id', wsId)
      .eq('status', 'draft')
      .is('deleted_at', null);

    setDraftCount(draftCnt || 0);

    setLoading(false);
  }, [supabase, todayStr, selectedKind, selectedAccountId]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  // Toggle status tugas selesai
  const handleToggleTask = async (task: AgendaItem) => {
    const wasDone = task.status === 'done';

    // Optimistic UI update
    setAgendaItems((prev) =>
      prev.map((item) =>
        item.id === task.id
          ? {
              ...item,
              status: wasDone ? 'todo' : 'done',
              checklist_done: wasDone ? item.checklist_done : item.checklist_total,
            }
          : item
      )
    );

    const { data: updatedTask, error } = await supabase.rpc('fn_complete_task', {
      p_task_id: task.id,
    });

    if (error) {
      // Revert optimistic update
      loadData();
      return;
    }

    // Jika tugas baru saja diselesaikan dan memiliki milestone_payment_id, tawarkan pelunasan
    if (!wasDone && updatedTask && updatedTask.milestone_payment_id) {
      setPendingMilestoneId(updatedTask.milestone_payment_id);
      setPendingTaskTitle(task.title);
      setShowMilestoneModal(true);
    }
  };

  // Konfirmasi pelunasan milestone pembayaran
  const handleConfirmMilestonePayment = async () => {
    if (!pendingMilestoneId || !selectedAccountId) return;
    setMarkingPaid(true);

    const { error } = await supabase.rpc('fn_mark_payment_paid', {
      p_payment_id: pendingMilestoneId,
      p_account_id: selectedAccountId,
    });

    setMarkingPaid(false);
    setShowMilestoneModal(false);
    setPendingMilestoneId(null);

    if (!error) {
      loadData();
    }
  };

  // Tambah tugas cepat
  const handleCreateQuickTask = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!workspaceId || !newTaskTitle.trim()) return;

    setSavingTask(true);
    const { error } = await supabase.from('tasks').insert({
      workspace_id: workspaceId,
      title: newTaskTitle.trim(),
      kind: newTaskKind,
      priority: newTaskPriority,
      due_at: new Date().toISOString(),
      due_is_date_only: true,
      status: 'todo',
    });

    setSavingTask(false);
    if (!error) {
      setNewTaskTitle('');
      setShowQuickTaskModal(false);
      loadData();
    }
  };

  // Pisahkan agenda menjadi overdue tasks, today events, today tasks
  const overdueTasks = agendaItems.filter((i) => i.item_type === 'task' && i.is_overdue);
  const scheduledEvents = agendaItems.filter((i) => i.item_type === 'event');
  const todayTasks = agendaItems.filter((i) => i.item_type === 'task' && !i.is_overdue);

  return (
    <div className="space-y-6">
      {/* Header & Filter Jenis */}
      <div className="relative overflow-hidden rounded-2xl border border-indigo-500/20 bg-gradient-to-r from-indigo-500/10 via-sky-500/5 to-purple-500/10 p-5 flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div className="flex items-center gap-3.5">
          <img
            src="/orbit-icon.png"
            alt="Orbit"
            className="w-11 h-11 rounded-xl shadow-md object-cover border border-white/10 hidden sm:block"
          />
          <div>
            <h1 className="text-2xl font-bold tracking-tight">Hari Ini</h1>
            <p className="text-xs font-medium text-muted-foreground mt-0.5">
              {formatDateIndo(todayStr)}
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2 flex-wrap">
          <button
            type="button"
            onClick={() => setShowQuickTaskModal(true)}
            className="flex items-center gap-1.5 px-3.5 py-2 text-xs font-semibold orbit-btn-primary rounded-xl"
          >
            <Plus className="w-3.5 h-3.5" />
            <span>Tambah Tugas</span>
          </button>
          <Link
            href="/jadwal"
            className="flex items-center gap-1.5 px-3.5 py-2 text-xs font-semibold border border-border bg-card/80 text-foreground rounded-xl hover:bg-muted transition-colors"
          >
            <Calendar className="w-3.5 h-3.5 text-indigo-500" />
            <span>Tambah Jadwal</span>
          </Link>
        </div>
      </div>

      {/* Filter Chips per Jenis */}
      <div className="flex items-center gap-1.5 overflow-x-auto pb-1">
        <button
          type="button"
          onClick={() => setSelectedKind('all')}
          className={`px-3.5 py-1.5 rounded-full text-xs font-semibold transition-all ${
            selectedKind === 'all'
              ? 'orbit-btn-primary'
              : 'bg-card border border-border text-muted-foreground hover:text-foreground'
          }`}
        >
          Semua Kegiatan
        </button>
        {(['intern', 'freelance', 'kuliah', 'pribadi'] as ActivityKind[]).map((kind) => {
          const cfg = KIND_CONFIG[kind];
          const Icon = cfg.icon;
          const active = selectedKind === kind;
          return (
            <button
              key={kind}
              type="button"
              onClick={() => setSelectedKind(kind)}
              className={`flex items-center gap-1.5 px-3.5 py-1.5 rounded-full text-xs font-semibold transition-all ${
                active
                  ? 'orbit-btn-primary'
                  : 'bg-card border border-border text-muted-foreground hover:text-foreground'
              }`}
            >
              <Icon className="w-3 h-3" />
              <span>{cfg.label}</span>
            </button>
          );
        })}
      </div>

      {/* Bagian Perhatian: Benturan Jadwal, Hari Padat, Piutang */}
      {(conflicts.length > 0 || isHeavyDay || receivables.length > 0) && (
        <div className="space-y-3">
          {conflicts.map((c, idx) => (
            <div
              key={idx}
              className="p-3.5 rounded-lg border border-red-500/30 bg-red-500/10 text-red-700 dark:text-red-400 text-xs flex items-start gap-2.5"
            >
              <AlertTriangle className="w-4 h-4 shrink-0 mt-0.5 text-red-500" />
              <div>
                <span className="font-semibold">Benturan Jadwal: </span>
                <span>
                  &ldquo;{c.event1_title}&rdquo; dan &ldquo;{c.event2_title}&rdquo; tumpang tindih waktu.
                </span>
              </div>
            </div>
          ))}

          {isHeavyDay && (
            <div className="p-3.5 rounded-lg border border-amber-500/30 bg-amber-500/10 text-amber-700 dark:text-amber-400 text-xs flex items-start gap-2.5">
              <AlertCircle className="w-4 h-4 shrink-0 mt-0.5 text-amber-500" />
              <div>
                <span className="font-semibold">Hari Padat Terjadwal: </span>
                <span>Total durasi kegiatan hari ini mencapai atau melebihi 8 jam. Prioritaskan energi Anda.</span>
              </div>
            </div>
          )}

          {receivables.length > 0 && (
            <div className="p-3.5 rounded-lg border border-border bg-card text-xs space-y-2">
              <div className="font-medium text-foreground flex items-center justify-between">
                <span className="flex items-center gap-1.5">
                  <Wallet className="w-3.5 h-3.5 text-muted-foreground" />
                  Piutang Proyek Mendatang & Terlambat
                </span>
                <Link href="/proyek" className="text-muted-foreground hover:text-foreground inline-flex items-center gap-1">
                  Semua Piutang <ArrowRight className="w-3 h-3" />
                </Link>
              </div>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-2">
                {receivables.map((r) => (
                  <div
                    key={r.payment_id}
                    className="p-2.5 rounded border border-border/60 bg-muted/30 flex items-center justify-between gap-2"
                  >
                    <div>
                      <div className="font-medium text-foreground">{r.label} ({r.project_name})</div>
                      <div className="text-muted-foreground text-[11px]">
                        {formatCurrency(r.amount)} • {r.is_overdue ? `${r.days_overdue} hari lewat tempo` : `Jatuh tempo: ${r.due_date || '-'}`}
                      </div>
                    </div>
                    <button
                      type="button"
                      onClick={() => {
                        setPendingMilestoneId(r.payment_id);
                        setPendingTaskTitle(r.label);
                        setShowMilestoneModal(true);
                      }}
                      className="px-2 py-1 bg-foreground text-background rounded text-[11px] font-medium shrink-0 hover:bg-foreground/90 transition-colors"
                    >
                      Tandai Lunas
                    </button>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}

      {/* Bagian Uang Ringkas */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-3.5">
        <div className="p-4 rounded-xl border border-border bg-card shadow-sm flex flex-col justify-between">
          <div className="text-xs font-medium text-muted-foreground flex items-center justify-between">
            <span>Total Saldo Likuid</span>
            <span className="p-1.5 rounded-lg bg-emerald-500/10 text-emerald-500">
              <Wallet className="w-3.5 h-3.5" />
            </span>
          </div>
          <div className="text-lg font-bold mt-2 tracking-tight tabular-nums">
            {formatCurrency(liquidBalance)}
          </div>
        </div>

        <div className="p-4 rounded-xl border border-border bg-card shadow-sm flex flex-col justify-between">
          <div className="text-xs font-medium text-muted-foreground flex items-center justify-between">
            <span>Draft di Inbox</span>
            <span className="p-1.5 rounded-lg bg-sky-500/10 text-sky-500">
              <Inbox className="w-3.5 h-3.5" />
            </span>
          </div>
          <div className="text-lg font-bold mt-2 tracking-tight">
            {draftCount} transaksi
          </div>
        </div>

        <div className="p-4 rounded-xl border border-border bg-card shadow-sm flex flex-col justify-between">
          <div className="text-xs font-medium text-muted-foreground flex items-center justify-between">
            <span>Jadwal Hari Ini</span>
            <span className="p-1.5 rounded-lg bg-indigo-500/10 text-indigo-500">
              <Calendar className="w-3.5 h-3.5" />
            </span>
          </div>
          <div className="text-lg font-bold mt-2 tracking-tight">
            {scheduledEvents.length} agenda
          </div>
        </div>

        <div className="p-4 rounded-xl border border-border bg-card shadow-sm flex flex-col justify-between">
          <div className="text-xs font-medium text-muted-foreground flex items-center justify-between">
            <span>Tugas Hari Ini</span>
            <span className="p-1.5 rounded-lg bg-purple-500/10 text-purple-500">
              <CheckSquare className="w-3.5 h-3.5" />
            </span>
          </div>
          <div className="text-lg font-bold mt-2 tracking-tight">
            {todayTasks.filter((t) => t.status === 'done').length}/{todayTasks.length + overdueTasks.length} selesai
          </div>
        </div>
      </div>

      {/* Bagian Waktu: Tugas Terlambat, Jadwal Hari Ini, Tugas Hari Ini */}
      <div className="space-y-6">
        {/* Tugas Terlambat (Overdue) - Selalu di atas */}
        {overdueTasks.length > 0 && (
          <div className="space-y-2">
            <div className="text-xs font-semibold text-red-600 dark:text-red-400 flex items-center gap-1.5">
              <AlertTriangle className="w-3.5 h-3.5" />
              Tugas Terlambat ({overdueTasks.length})
            </div>
            <div className="space-y-1.5">
              {overdueTasks.map((task) => (
                <div
                  key={task.id}
                  className="p-3 rounded-lg border border-red-500/30 bg-red-500/5 flex items-start gap-3 transition-colors"
                >
                  <button
                    type="button"
                    onClick={() => handleToggleTask(task)}
                    className="mt-0.5 text-red-500 hover:text-red-700 transition-colors"
                  >
                    {task.status === 'done' ? (
                      <CheckCircle2 className="w-4 h-4" />
                    ) : (
                      <Circle className="w-4 h-4" />
                    )}
                  </button>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center gap-2">
                      <span className="font-medium text-sm text-foreground truncate">
                        {task.title}
                      </span>
                      <span className="text-[10px] px-1.5 py-0.5 rounded font-medium bg-red-500/10 text-red-600 dark:text-red-400">
                        Terlambat
                      </span>
                      <span className={`text-[10px] px-1.5 py-0.5 rounded font-medium ${KIND_CONFIG[task.kind].color}`}>
                        {KIND_CONFIG[task.kind].label}
                      </span>
                    </div>
                    {task.project_name && (
                      <div className="text-xs text-muted-foreground mt-0.5">
                        Proyek: {task.project_name}
                      </div>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Jadwal Hari Ini */}
        <div className="space-y-2">
          <div className="text-xs font-semibold text-foreground flex items-center justify-between">
            <span className="flex items-center gap-1.5">
              <Clock className="w-3.5 h-3.5 text-muted-foreground" />
              Jadwal & Pertemuan
            </span>
            <Link href="/jadwal" className="text-muted-foreground hover:text-foreground text-[11px]">
              Buka Jadwal Lengkap
            </Link>
          </div>

          {loading ? (
            <div className="p-8 text-center text-xs text-muted-foreground border border-border rounded-lg bg-card">
              Memuat agenda...
            </div>
          ) : scheduledEvents.length === 0 ? (
            <div className="p-6 text-center text-xs text-muted-foreground border border-dashed border-border rounded-lg">
              Tidak ada jadwal terjadwal untuk hari ini.
            </div>
          ) : (
            <div className="space-y-2">
              {scheduledEvents.map((evt) => {
                const startTime = evt.starts_at ? new Date(evt.starts_at).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' }) : '-';
                const endTime = evt.ends_at ? new Date(evt.ends_at).toLocaleTimeString('id-ID', { hour: '2-digit', minute: '2-digit' }) : '-';

                return (
                  <div
                    key={evt.id}
                    className="p-3.5 rounded-lg border border-border bg-card flex items-start justify-between gap-3"
                  >
                    <div className="space-y-1">
                      <div className="flex items-center gap-2">
                        <span className="font-medium text-sm text-foreground">
                          {evt.title}
                        </span>
                        <span className={`text-[10px] px-1.5 py-0.5 rounded font-medium ${KIND_CONFIG[evt.kind].color}`}>
                          {KIND_CONFIG[evt.kind].label}
                        </span>
                        {evt.is_recurring && (
                          <span className="text-[10px] px-1.5 py-0.5 rounded font-medium bg-muted text-muted-foreground">
                            Berulang
                          </span>
                        )}
                      </div>

                      <div className="flex items-center gap-3 text-xs text-muted-foreground">
                        <span className="flex items-center gap-1">
                          <Clock className="w-3 h-3" />
                          {evt.all_day ? 'Seharian' : `${startTime} - ${endTime}`}
                        </span>
                        {evt.location && (
                          <span className="flex items-center gap-1 truncate max-w-[200px]">
                            <MapPin className="w-3 h-3" />
                            {evt.location}
                          </span>
                        )}
                        {evt.project_name && (
                          <span>Proyek: {evt.project_name}</span>
                        )}
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* Tugas Hari Ini */}
        <div className="space-y-2">
          <div className="text-xs font-semibold text-foreground flex items-center justify-between">
            <span className="flex items-center gap-1.5">
              <CheckSquare className="w-3.5 h-3.5 text-muted-foreground" />
              Tugas Jatuh Tempo Hari Ini
            </span>
            <Link href="/tugas" className="text-muted-foreground hover:text-foreground text-[11px]">
              Buka Papan Tugas
            </Link>
          </div>

          {loading ? (
            <div className="p-8 text-center text-xs text-muted-foreground border border-border rounded-lg bg-card">
              Memuat tugas...
            </div>
          ) : todayTasks.length === 0 ? (
            <div className="p-6 text-center text-xs text-muted-foreground border border-dashed border-border rounded-lg">
              Semua tugas hari ini telah rampung.
            </div>
          ) : (
            <div className="space-y-1.5">
              {todayTasks.map((task) => {
                const isDone = task.status === 'done';
                return (
                  <div
                    key={task.id}
                    className={`p-3 rounded-lg border transition-colors flex items-start gap-3 ${
                      isDone
                        ? 'border-border/60 bg-muted/20 opacity-70'
                        : 'border-border bg-card'
                    }`}
                  >
                    <button
                      type="button"
                      onClick={() => handleToggleTask(task)}
                      className={`mt-0.5 transition-colors ${
                        isDone ? 'text-emerald-500' : 'text-muted-foreground hover:text-foreground'
                      }`}
                    >
                      {isDone ? (
                        <CheckCircle2 className="w-4 h-4" />
                      ) : (
                        <Circle className="w-4 h-4" />
                      )}
                    </button>

                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <span
                          className={`font-medium text-sm text-foreground truncate ${
                            isDone ? 'line-through text-muted-foreground' : ''
                          }`}
                        >
                          {task.title}
                        </span>
                        <span className={`text-[10px] px-1.5 py-0.5 rounded font-medium ${KIND_CONFIG[task.kind].color}`}>
                          {KIND_CONFIG[task.kind].label}
                        </span>
                        {task.priority === 'tinggi' && (
                          <span className="text-[10px] px-1.5 py-0.5 rounded font-medium bg-red-500/10 text-red-600 dark:text-red-400">
                            Prioritas Tinggi
                          </span>
                        )}
                        {task.milestone_payment_id && (
                          <span className="text-[10px] px-1.5 py-0.5 rounded font-medium bg-purple-500/10 text-purple-600 dark:text-purple-400">
                            Milestone Pembayaran
                          </span>
                        )}
                      </div>

                      <div className="flex items-center gap-3 text-xs text-muted-foreground mt-0.5">
                        {task.project_name && <span>{task.project_name}</span>}
                        {task.checklist_total > 0 && (
                          <span>
                            Checklist: {task.checklist_done}/{task.checklist_total}
                          </span>
                        )}
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>

      {/* Modal Dialog Pelunasan Milestone */}
      {showMilestoneModal && (
        <div className="fixed inset-0 z-50 bg-background/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-card border border-border rounded-lg shadow-lg max-w-md w-full p-6 space-y-4">
            <h3 className="font-semibold text-base text-foreground">
              Konfirmasi Pelunasan Milestone
            </h3>
            <p className="text-sm text-muted-foreground">
              Tugas &ldquo;{pendingTaskTitle}&rdquo; merupakan bagian dari milestone pembayaran freelance.
              Apakah Anda ingin mencatat pembayaran ini sebagai pemasukan lunas sekarang?
            </p>

            <div className="space-y-2">
              <label className="text-xs font-medium text-foreground block">
                Pilih Akun Penerima
              </label>
              <select
                value={selectedAccountId}
                onChange={(e) => setSelectedAccountId(e.target.value)}
                className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
              >
                {accounts.map((acc) => (
                  <option key={acc.id} value={acc.id}>
                    {acc.name}
                  </option>
                ))}
              </select>
            </div>

            <div className="flex justify-end gap-2 pt-2">
              <button
                type="button"
                onClick={() => {
                  setShowMilestoneModal(false);
                  setPendingMilestoneId(null);
                }}
                className="px-3 py-1.5 text-xs font-medium border border-border rounded-md hover:bg-muted text-muted-foreground transition-colors"
              >
                Nanti Saja
              </button>
              <button
                type="button"
                disabled={markingPaid}
                onClick={handleConfirmMilestonePayment}
                className="px-3 py-1.5 text-xs font-medium bg-foreground text-background rounded-md hover:bg-foreground/90 transition-colors disabled:opacity-50"
              >
                {markingPaid ? 'Memproses...' : 'Tandai Lunas'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Modal Tambah Tugas Cepat */}
      {showQuickTaskModal && (
        <div className="fixed inset-0 z-50 bg-background/80 backdrop-blur-sm flex items-center justify-center p-4">
          <form
            onSubmit={handleCreateQuickTask}
            className="bg-card border border-border rounded-lg shadow-lg max-w-md w-full p-6 space-y-4"
          >
            <h3 className="font-semibold text-base text-foreground">
              Tambah Tugas Cepat
            </h3>

            <div className="space-y-3">
              <div>
                <label className="text-xs font-medium text-foreground block mb-1">
                  Judul Tugas
                </label>
                <input
                  type="text"
                  required
                  placeholder="Misal: Review PR #12 atau Beli Buku"
                  value={newTaskTitle}
                  onChange={(e) => setNewTaskTitle(e.target.value)}
                  className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">
                    Jenis Kegiatan
                  </label>
                  <select
                    value={newTaskKind}
                    onChange={(e) => setNewTaskKind(e.target.value as ActivityKind)}
                    className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
                  >
                    <option value="pribadi">Pribadi</option>
                    <option value="intern">Magang</option>
                    <option value="freelance">Freelance</option>
                    <option value="kuliah">Kuliah</option>
                  </select>
                </div>

                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">
                    Prioritas
                  </label>
                  <select
                    value={newTaskPriority}
                    onChange={(e) => setNewTaskPriority(e.target.value as 'rendah' | 'sedang' | 'tinggi')}
                    className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
                  >
                    <option value="rendah">Rendah</option>
                    <option value="sedang">Sedang</option>
                    <option value="tinggi">Tinggi</option>
                  </select>
                </div>
              </div>
            </div>

            <div className="flex justify-end gap-2 pt-2">
              <button
                type="button"
                onClick={() => setShowQuickTaskModal(false)}
                className="px-3 py-1.5 text-xs font-medium border border-border rounded-md hover:bg-muted text-muted-foreground transition-colors"
              >
                Batal
              </button>
              <button
                type="submit"
                disabled={savingTask}
                className="px-3 py-1.5 text-xs font-medium bg-foreground text-background rounded-md hover:bg-foreground/90 transition-colors disabled:opacity-50"
              >
                {savingTask ? 'Menyimpan...' : 'Simpan Tugas'}
              </button>
            </div>
          </form>
        </div>
      )}
    </div>
  );
}
