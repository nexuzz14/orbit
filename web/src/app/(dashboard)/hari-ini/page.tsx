'use client';

import React, { useCallback, useEffect, useState } from 'react';
import Link from 'next/link';
import {
  AlertCircle,
  AlertTriangle,
  ArrowRight,
  Calendar,
  CheckCircle2,
  CheckSquare,
  Circle,
  Clock,
  Inbox,
  MapPin,
  Plus,
  Receipt,
  Wallet,
} from 'lucide-react';
import { createClient } from '@/lib/supabase/client';
import { formatCurrency, formatDateIndo, getGreeting } from '@/lib/format';
import type { ActivityKind } from '@/types/database';
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  cn,
  Dialog,
  EmptyState,
  ErrorState,
  Input,
  KindBadge,
  Select,
  Skeleton,
  StatusBadge,
} from '@/components/ui';
import { TransactionFormModal } from '@/components/transaction-form-modal';

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
  currency: string;
};


export default function HariIniPage() {
  const supabase = createClient();
  const [loading, setLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [workspaceId, setWorkspaceId] = useState<string | null>(null);
  const [selectedKind, setSelectedKind] = useState<ActivityKind | 'all'>('all');

  const [agendaItems, setAgendaItems] = useState<AgendaItem[]>([]);
  const [conflicts, setConflicts] = useState<ConflictItem[]>([]);
  const [isHeavyDay, setIsHeavyDay] = useState(false);
  const [receivables, setReceivables] = useState<ReceivableItem[]>([]);
  const [liquidBalance, setLiquidBalance] = useState<number>(0);
  const [todayIncome, setTodayIncome] = useState<number>(0);
  const [todayExpense, setTodayExpense] = useState<number>(0);
  const [draftCount, setDraftCount] = useState<number>(0);
  const [accounts, setAccounts] = useState<AccountItem[]>([]);

  const [showMilestoneModal, setShowMilestoneModal] = useState(false);
  const [pendingMilestoneId, setPendingMilestoneId] = useState<string | null>(null);
  const [pendingTaskTitle, setPendingTaskTitle] = useState<string>('');
  const [selectedAccountId, setSelectedAccountId] = useState<string>('');
  const [markingPaid, setMarkingPaid] = useState(false);

  const [showQuickTaskModal, setShowQuickTaskModal] = useState(false);
  const [newTaskTitle, setNewTaskTitle] = useState('');
  const [newTaskKind, setNewTaskKind] = useState<ActivityKind>('pribadi');
  const [newTaskPriority, setNewTaskPriority] = useState<'rendah' | 'sedang' | 'tinggi'>('sedang');
  const [savingTask, setSavingTask] = useState(false);

  const [showTxModal, setShowTxModal] = useState(false);

  const today = new Date();
  const todayStr = today.toISOString().split('T')[0];

  const loadData = useCallback(async () => {
    setLoading(true);
    setErrorMessage(null);

    try {
      const { data: memberData, error: memberErr } = await supabase
        .from('workspace_members')
        .select('workspace_id')
        .limit(1)
        .single();

      if (memberErr && memberErr.code !== 'PGRST116') {
        throw new Error(memberErr.message || 'Gagal memuat workspace.');
      }

      if (!memberData) {
        setAgendaItems([]);
        setLoading(false);
        return;
      }

      const wsId = memberData.workspace_id;
      setWorkspaceId(wsId);

      const kindFilter = selectedKind === 'all' ? undefined : selectedKind;

      const [accRes, agendaRes, conflictRes, recRes, balRes, todayTxRes, draftRes] =
        await Promise.all([
          supabase
            .from('accounts')
            .select('id, name, currency')
            .eq('workspace_id', wsId)
            .is('deleted_at', null)
            .order('sort_order'),
          supabase.rpc('fn_agenda', {
            p_workspace_id: wsId,
            p_start_date: todayStr,
            p_end_date: todayStr,
            p_kind: kindFilter,
          }),
          supabase.rpc('fn_detect_conflicts', {
            p_workspace_id: wsId,
            p_start_date: todayStr,
            p_end_date: todayStr,
          }),
          supabase
            .from('v_receivables')
            .select('*')
            .eq('workspace_id', wsId)
            .order('due_date', { ascending: true })
            .limit(3),
          supabase
            .from('v_account_balances')
            .select('balance, is_liquid')
            .eq('workspace_id', wsId),
          supabase
            .from('transactions')
            .select('type, amount, occurred_at, status')
            .eq('workspace_id', wsId)
            .eq('status', 'confirmed')
            .is('deleted_at', null)
            .gte('occurred_at', `${todayStr}T00:00:00.000Z`)
            .lte('occurred_at', `${todayStr}T23:59:59.999Z`),
          supabase
            .from('transactions')
            .select('*', { count: 'exact', head: true })
            .eq('workspace_id', wsId)
            .eq('status', 'draft')
            .is('deleted_at', null),
        ]);

      if (accRes.error) throw new Error(accRes.error.message);

      if (accRes.data) {
        setAccounts(accRes.data as AccountItem[]);
        if (accRes.data.length > 0 && !selectedAccountId) {
          setSelectedAccountId(accRes.data[0].id);
        }
      }

      if (agendaRes.data) {
        setAgendaItems(agendaRes.data as AgendaItem[]);
      } else {
        setAgendaItems([]);
      }

      if (conflictRes.data) {
        const list = conflictRes.data as ConflictItem[];
        setConflicts(list.filter((c) => c.event1_id !== null));
        setIsHeavyDay(list.some((c) => c.is_heavy_day));
      } else {
        setConflicts([]);
        setIsHeavyDay(false);
      }

      if (recRes.data) {
        setReceivables(recRes.data as ReceivableItem[]);
      }

      if (balRes.data) {
        const liquidTotal = balRes.data
          .filter((b) => b.is_liquid)
          .reduce((sum, b) => sum + Number(b.balance || 0), 0);
        setLiquidBalance(liquidTotal);
      }

      if (todayTxRes.data) {
        let inc = 0;
        let exp = 0;
        for (const t of todayTxRes.data) {
          if (t.type === 'income') inc += Number(t.amount || 0);
          if (t.type === 'expense') exp += Number(t.amount || 0);
        }
        setTodayIncome(inc);
        setTodayExpense(exp);
      }

      setDraftCount(draftRes.count || 0);
    } catch (err: any) {
      setErrorMessage(err?.message || 'Gagal memuat ringkasan hari ini.');
    } finally {
      setLoading(false);
    }
  }, [supabase, todayStr, selectedKind, selectedAccountId]);

  useEffect(() => {
    loadData();
    const onTxCreated = () => loadData();
    window.addEventListener('orbit:transaction-created', onTxCreated);
    return () => window.removeEventListener('orbit:transaction-created', onTxCreated);
  }, [loadData]);

  const handleToggleTask = async (task: AgendaItem) => {
    const wasDone = task.status === 'done';

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
      loadData();
      return;
    }

    if (!wasDone && updatedTask && updatedTask.milestone_payment_id) {
      setPendingMilestoneId(updatedTask.milestone_payment_id);
      setPendingTaskTitle(task.title);
      setShowMilestoneModal(true);
    }
  };

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

  const overdueTasks = agendaItems.filter((i) => i.item_type === 'task' && i.is_overdue);
  const scheduledEvents = agendaItems.filter((i) => i.item_type === 'event');
  const todayTasks = agendaItems.filter((i) => i.item_type === 'task' && !i.is_overdue);
  const conflictEventIds = new Set(
    conflicts.flatMap((c) => [c.event1_id, c.event2_id]).filter(Boolean) as string[]
  );

  return (
    <div className="space-y-6">
      {/* Header Sapaan & Tanggal */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-border pb-4">
        <div>
          <p className="text-xs font-semibold uppercase tracking-wider text-primary">
            {formatDateIndo(todayStr)}
          </p>
          <h1 className="mt-1 text-2xl font-bold tracking-tight text-foreground">
            {getGreeting()}
          </h1>
          <p className="mt-0.5 text-sm text-muted-foreground">
            Fokus jadwal, tugas prioritas, dan posisi uang Anda hari ini.
          </p>
        </div>

        <div className="flex items-center gap-2 flex-wrap">
          <Button variant="outline" onClick={() => setShowQuickTaskModal(true)}>
            <Plus className="h-4 w-4" aria-hidden="true" />
            <span>Tambah Tugas</span>
          </Button>
          <Button variant="primary" onClick={() => setShowTxModal(true)}>
            <Receipt className="h-4 w-4" aria-hidden="true" />
            <span>Catat Transaksi</span>
          </Button>
        </div>
      </div>

      {/* Filter Chip Jenis Kegiatan */}
      <div
        role="group"
        aria-label="Filter berdasarkan jenis kegiatan"
        className="flex items-center gap-2 overflow-x-auto pb-1"
      >
        {(
          [
            { value: 'all', label: 'Semua Kegiatan' },
            { value: 'intern', label: 'Intern' },
            { value: 'freelance', label: 'Freelance' },
            { value: 'kuliah', label: 'Kuliah' },
            { value: 'pribadi', label: 'Pribadi' },
          ] as const
        ).map((item) => {
          const active = selectedKind === item.value;
          return (
            <button
              key={item.value}
              type="button"
              aria-pressed={active}
              onClick={() => setSelectedKind(item.value)}
              className={cn(
                'min-h-11 shrink-0 rounded-md border px-3.5 py-2 text-xs font-medium transition-colors duration-150',
                active
                  ? 'border-primary bg-primary-subtle text-primary font-semibold'
                  : 'border-border bg-card text-muted-foreground hover:bg-subtle hover:text-foreground'
              )}
            >
              {item.label}
            </button>
          );
        })}
      </div>

      {/* State Error */}
      {errorMessage && <ErrorState message={errorMessage} onRetry={loadData} />}

      {/* Peringatan Benturan Jadwal atau Hari Padat */}
      {!loading && !errorMessage && (conflicts.length > 0 || isHeavyDay) && (
        <div className="space-y-2" role="region" aria-label="Peringatan jadwal">
          {conflicts.map((c, idx) => (
            <div
              key={idx}
              className="flex items-start gap-3 rounded-lg border border-expense-border bg-expense-subtle p-3.5 text-xs text-expense"
            >
              <AlertTriangle className="h-4 w-4 shrink-0 mt-0.5" aria-hidden="true" />
              <div>
                <span className="font-semibold">Benturan Jadwal: </span>
                <span>
                  &ldquo;{c.event1_title}&rdquo; dan &ldquo;{c.event2_title}&rdquo; berada pada jam yang tumpang tindih.
                </span>
              </div>
            </div>
          ))}

          {isHeavyDay && (
            <div className="flex items-start gap-3 rounded-lg border border-warning-border bg-warning-subtle p-3.5 text-xs text-warning">
              <AlertCircle className="h-4 w-4 shrink-0 mt-0.5" aria-hidden="true" />
              <div>
                <span className="font-semibold">Hari Padat Terjadwal: </span>
                <span>Total durasi kegiatan hari ini mencapai 8 jam atau lebih.</span>
              </div>
            </div>
          )}
        </div>
      )}

      {/* Urutan PRD M10c: 1. Jadwal & Tugas Hari Ini, 2. Ringkasan Uang Hari Itu */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Kolom Kiri (7 kolom): Jadwal & Tugas Hari Ini */}
        <div className="lg:col-span-7 space-y-6">
          {/* 1A. Jadwal Hari Ini */}
          <Card>
            <CardHeader>
              <div className="flex items-center gap-2">
                <Calendar className="h-4 w-4 text-primary" aria-hidden="true" />
                <CardTitle>Jadwal Hari Ini</CardTitle>
                <StatusBadge variant="neutral">{scheduledEvents.length}</StatusBadge>
              </div>
              <Link
                href="/jadwal"
                className="min-h-11 inline-flex items-center gap-1 px-2 text-xs font-medium text-primary hover:underline"
              >
                <span>Buka Jadwal</span>
                <ArrowRight className="h-3.5 w-3.5" aria-hidden="true" />
              </Link>
            </CardHeader>
            <CardContent>
              {loading ? (
                <div className="space-y-3">
                  <Skeleton className="h-16 w-full" />
                  <Skeleton className="h-16 w-full" />
                </div>
              ) : scheduledEvents.length === 0 ? (
                <EmptyState
                  title="Belum ada jadwal hari ini"
                  description="Tambahkan pertemuan, kuliah, atau sesi fokus agar hari Anda terstruktur."
                  actionLabel="Tambah Jadwal"
                  onAction={() => {
                    window.location.href = '/jadwal';
                  }}
                />
              ) : (
                <div className="divide-y divide-border">
                  {scheduledEvents.map((evt) => {
                    const startTime = evt.starts_at
                      ? new Date(evt.starts_at).toLocaleTimeString('id-ID', {
                          hour: '2-digit',
                          minute: '2-digit',
                        })
                      : '--:--';
                    const endTime = evt.ends_at
                      ? new Date(evt.ends_at).toLocaleTimeString('id-ID', {
                          hour: '2-digit',
                          minute: '2-digit',
                        })
                      : '--:--';
                    const hasConflict = evt.event_id ? conflictEventIds.has(evt.event_id) : false;

                    return (
                      <div key={evt.id} className="flex items-start gap-4 py-3 first:pt-0 last:pb-0">
                        <div className="w-24 shrink-0 pt-0.5 text-xs font-semibold tabular-nums text-muted-foreground">
                          {evt.all_day ? 'Seharian' : `${startTime} - ${endTime}`}
                        </div>
                        <div className="flex-1 min-w-0">
                          <div className="flex flex-wrap items-center gap-2">
                            <span className="text-sm font-semibold text-foreground">
                              {evt.title}
                            </span>
                            <KindBadge kind={evt.kind} />
                            {hasConflict && (
                              <StatusBadge variant="expense">Benturan Waktu</StatusBadge>
                            )}
                          </div>
                          {(evt.location || evt.project_name) && (
                            <div className="mt-1 flex flex-wrap items-center gap-3 text-xs text-muted-foreground">
                              {evt.location && (
                                <span className="inline-flex items-center gap-1">
                                  <MapPin className="h-3.5 w-3.5" aria-hidden="true" />
                                  <span>{evt.location}</span>
                                </span>
                              )}
                              {evt.project_name && <span>Kegiatan: {evt.project_name}</span>}
                            </div>
                          )}
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </CardContent>
          </Card>

          {/* 1B. Tugas Terlambat & Tugas Hari Ini */}
          <Card>
            <CardHeader>
              <div className="flex items-center gap-2">
                <CheckSquare className="h-4 w-4 text-primary" aria-hidden="true" />
                <CardTitle>Tugas Hari Ini</CardTitle>
                <StatusBadge variant={overdueTasks.length > 0 ? 'expense' : 'neutral'}>
                  {todayTasks.length + overdueTasks.length}
                </StatusBadge>
              </div>
              <Link
                href="/tugas"
                className="min-h-11 inline-flex items-center gap-1 px-2 text-xs font-medium text-primary hover:underline"
              >
                <span>Semua Tugas</span>
                <ArrowRight className="h-3.5 w-3.5" aria-hidden="true" />
              </Link>
            </CardHeader>
            <CardContent>
              {loading ? (
                <div className="space-y-3">
                  <Skeleton className="h-14 w-full" />
                  <Skeleton className="h-14 w-full" />
                  <Skeleton className="h-14 w-full" />
                </div>
              ) : overdueTasks.length === 0 && todayTasks.length === 0 ? (
                <EmptyState
                  title="Tidak ada tugas yang jatuh tempo"
                  description="Semua tugas hari ini telah selesai atau belum ada tugas baru."
                  actionLabel="Tambah Tugas Cepat"
                  onAction={() => setShowQuickTaskModal(true)}
                />
              ) : (
                <div className="divide-y divide-border">
                  {[...overdueTasks, ...todayTasks].map((task) => {
                    const isDone = task.status === 'done';
                    return (
                      <div
                        key={task.id}
                        className="flex items-center justify-between gap-3 py-2.5 first:pt-0 last:pb-0"
                      >
                        <div className="flex items-center gap-2 min-w-0 flex-1">
                          <button
                            type="button"
                            onClick={() => handleToggleTask(task)}
                            aria-label={
                              isDone
                                ? `Tandai tugas ${task.title} belum selesai`
                                : `Tandai tugas ${task.title} selesai`
                            }
                            className="h-11 w-11 shrink-0 inline-flex items-center justify-center rounded-md text-muted-foreground hover:bg-subtle hover:text-primary transition-colors"
                          >
                            {isDone ? (
                              <CheckCircle2 className="h-5 w-5 text-income" />
                            ) : (
                              <Circle className="h-5 w-5" />
                            )}
                          </button>

                          <div className="min-w-0 flex-1">
                            <div className="flex flex-wrap items-center gap-2">
                              <span
                                className={cn(
                                  'text-sm font-medium text-foreground truncate',
                                  isDone && 'line-through text-muted-foreground'
                                )}
                              >
                                {task.title}
                              </span>
                              <KindBadge kind={task.kind} />
                              {task.is_overdue && !isDone && (
                                <StatusBadge variant="expense">Terlambat</StatusBadge>
                              )}
                              {task.priority === 'tinggi' && (
                                <StatusBadge variant="warning">Prioritas Tinggi</StatusBadge>
                              )}
                            </div>
                            {(task.project_name || task.checklist_total > 0) && (
                              <div className="mt-0.5 flex items-center gap-3 text-xs text-muted-foreground">
                                {task.project_name && <span>{task.project_name}</span>}
                                {task.checklist_total > 0 && (
                                  <span className="tabular-nums">
                                    Checklist {task.checklist_done}/{task.checklist_total}
                                  </span>
                                )}
                              </div>
                            )}
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </CardContent>
          </Card>
        </div>

        {/* Kolom Kanan (5 kolom): Ringkasan Uang Hari Itu */}
        <div className="lg:col-span-5 space-y-6">
          <Card>
            <CardHeader>
              <div className="flex items-center gap-2">
                <Wallet className="h-4 w-4 text-primary" aria-hidden="true" />
                <CardTitle>Ringkasan Uang Hari Ini</CardTitle>
              </div>
              <Link
                href="/transaksi"
                className="min-h-11 inline-flex items-center gap-1 px-2 text-xs font-medium text-primary hover:underline"
              >
                <span>Buka Uang</span>
                <ArrowRight className="h-3.5 w-3.5" aria-hidden="true" />
              </Link>
            </CardHeader>
            <CardContent className="space-y-4">
              {loading ? (
                <div className="space-y-3">
                  <Skeleton className="h-20 w-full" />
                  <div className="grid grid-cols-2 gap-3">
                    <Skeleton className="h-16 w-full" />
                    <Skeleton className="h-16 w-full" />
                  </div>
                </div>
              ) : (
                <>
                  {/* Saldo Likuid Utama */}
                  <div className="rounded-lg border border-border bg-subtle/50 p-4">
                    <span className="block text-xs font-medium text-muted-foreground">
                      Total Saldo Likuid Tersedia
                    </span>
                    <div className="mt-1 text-2xl font-bold tabular-nums text-foreground">
                      {formatCurrency(liquidBalance)}
                    </div>
                  </div>

                  {/* Arus Kas Hari Ini */}
                  <div className="grid grid-cols-2 gap-3">
                    <div className="rounded-lg border border-border bg-card p-3.5">
                      <span className="block text-xs font-medium text-muted-foreground">
                        Pemasukan Hari Ini
                      </span>
                      <div className="mt-1 text-base font-bold tabular-nums text-income">
                        +{formatCurrency(todayIncome)}
                      </div>
                    </div>
                    <div className="rounded-lg border border-border bg-card p-3.5">
                      <span className="block text-xs font-medium text-muted-foreground">
                        Pengeluaran Hari Ini
                      </span>
                      <div className="mt-1 text-base font-bold tabular-nums text-expense">
                        -{formatCurrency(todayExpense)}
                      </div>
                    </div>
                  </div>

                  {/* Pintasan Draft Inbox */}
                  <Link
                    href="/inbox"
                    className="min-h-11 flex items-center justify-between rounded-lg border border-border bg-card px-4 py-3 text-sm hover:bg-subtle transition-colors"
                  >
                    <span className="flex items-center gap-2.5 font-medium text-foreground">
                      <Inbox className="h-4 w-4 text-primary" aria-hidden="true" />
                      <span>Draft Menunggu di Inbox</span>
                    </span>
                    <StatusBadge variant={draftCount > 0 ? 'warning' : 'neutral'}>
                      {draftCount} draft
                    </StatusBadge>
                  </Link>
                </>
              )}
            </CardContent>
          </Card>

          {/* Kartu Piutang Jatuh Tempo (Bila Ada) */}
          {!loading && receivables.length > 0 && (
            <Card>
              <CardHeader>
                <CardTitle>Piutang Klien</CardTitle>
                <Link
                  href="/proyek"
                  className="min-h-11 inline-flex items-center gap-1 px-2 text-xs font-medium text-primary hover:underline"
                >
                  <span>Kelola</span>
                  <ArrowRight className="h-3.5 w-3.5" aria-hidden="true" />
                </Link>
              </CardHeader>
              <CardContent className="space-y-3">
                {receivables.map((r) => (
                  <div
                    key={r.payment_id}
                    className="flex items-center justify-between gap-3 rounded-md border border-border p-3"
                  >
                    <div className="min-w-0">
                      <div className="text-sm font-medium text-foreground truncate">
                        {r.label} ({r.project_name})
                      </div>
                      <div className="mt-0.5 text-xs text-muted-foreground tabular-nums">
                        {formatCurrency(r.amount)} •{' '}
                        {r.is_overdue
                          ? `${r.days_overdue} hari lewat tenggat`
                          : `Tenggat: ${r.due_date || '-'}`}
                      </div>
                    </div>
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => {
                        setPendingMilestoneId(r.payment_id);
                        setPendingTaskTitle(r.label);
                        setShowMilestoneModal(true);
                      }}
                    >
                      Tandai Lunas
                    </Button>
                  </div>
                ))}
              </CardContent>
            </Card>
          )}
        </div>
      </div>

      {/* Dialog Konfirmasi Pelunasan Milestone */}
      <Dialog
        open={showMilestoneModal}
        onClose={() => {
          setShowMilestoneModal(false);
          setPendingMilestoneId(null);
        }}
        title="Konfirmasi Pelunasan Milestone"
        description={`Catat pembayaran "${pendingTaskTitle}" sebagai pemasukan lunas.`}
      >
        <div className="space-y-4">
          <div>
            <label htmlFor="milestone-acc-select" className="mb-1.5 block text-xs font-medium text-foreground">
              Pilih Akun Penerima
            </label>
            <Select
              id="milestone-acc-select"
              value={selectedAccountId}
              onChange={(e) => setSelectedAccountId(e.target.value)}
            >
              {accounts.map((acc) => (
                <option key={acc.id} value={acc.id}>
                  {acc.name}
                </option>
              ))}
            </Select>
          </div>
          <div className="flex justify-end gap-2 border-t border-border pt-3">
            <Button
              variant="outline"
              onClick={() => {
                setShowMilestoneModal(false);
                setPendingMilestoneId(null);
              }}
            >
              Nanti Saja
            </Button>
            <Button
              variant="primary"
              disabled={markingPaid}
              onClick={handleConfirmMilestonePayment}
            >
              {markingPaid ? 'Memproses...' : 'Tandai Lunas'}
            </Button>
          </div>
        </div>
      </Dialog>

      {/* Dialog Tambah Tugas Cepat */}
      <Dialog
        open={showQuickTaskModal}
        onClose={() => setShowQuickTaskModal(false)}
        title="Tambah Tugas Hari Ini"
        description="Buat tugas cepat dengan tenggat hari ini"
      >
        <form onSubmit={handleCreateQuickTask} className="space-y-4">
          <div>
            <label htmlFor="quick-task-title" className="mb-1.5 block text-xs font-medium text-foreground">
              Judul Tugas
            </label>
            <Input
              id="quick-task-title"
              type="text"
              required
              autoFocus
              placeholder="Contoh: Kirim revisi desain UI"
              value={newTaskTitle}
              onChange={(e) => setNewTaskTitle(e.target.value)}
            />
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label htmlFor="quick-task-kind" className="mb-1.5 block text-xs font-medium text-foreground">
                Jenis Kegiatan
              </label>
              <Select
                id="quick-task-kind"
                value={newTaskKind}
                onChange={(e) => setNewTaskKind(e.target.value as ActivityKind)}
              >
                <option value="pribadi">Pribadi</option>
                <option value="intern">Intern</option>
                <option value="freelance">Freelance</option>
                <option value="kuliah">Kuliah</option>
              </Select>
            </div>
            <div>
              <label htmlFor="quick-task-priority" className="mb-1.5 block text-xs font-medium text-foreground">
                Prioritas
              </label>
              <Select
                id="quick-task-priority"
                value={newTaskPriority}
                onChange={(e) => setNewTaskPriority(e.target.value as 'rendah' | 'sedang' | 'tinggi')}
              >
                <option value="rendah">Rendah</option>
                <option value="sedang">Sedang</option>
                <option value="tinggi">Tinggi</option>
              </Select>
            </div>
          </div>

          <div className="flex justify-end gap-2 border-t border-border pt-3">
            <Button variant="outline" onClick={() => setShowQuickTaskModal(false)}>
              Batal
            </Button>
            <Button type="submit" variant="primary" disabled={savingTask}>
              {savingTask ? 'Menyimpan...' : 'Simpan Tugas'}
            </Button>
          </div>
        </form>
      </Dialog>

      {/* Modal Tambah Transaksi Mobile-First */}
      <TransactionFormModal
        open={showTxModal}
        onClose={() => setShowTxModal(false)}
        workspaceId={workspaceId}
        initialAccounts={accounts}
        onSuccess={loadData}
      />
    </div>
  );
}
