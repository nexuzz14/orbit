'use client';

import React, { useEffect, useMemo, useRef, useState } from 'react';
import Link from 'next/link';
import {
  ArrowUpRight,
  CalendarClock,
  CheckCircle2,
  Coins,
  Flame,
  Pause,
  PieChart,
  Play,
  Plus,
  Receipt,
  RotateCcw,
  Save,
  Target,
  Timer,
  Wallet,
} from 'lucide-react';
import { createClient } from '@/lib/supabase/client';
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Input,
  StatusBadge,
  cn,
} from '@/components/ui';
import type { TaskRecord } from '@/components/tasks/types';

export interface HariIniBudgetItem {
  budget_id: string;
  category_id: string | null;
  category_name: string | null;
  effective_budget_amount: number;
  spent_amount: number;
  percentage_spent: number;
  is_over_budget: boolean;
  is_warning: boolean;
}

export interface HariIniBillItem {
  id: string;
  name: string;
  amount: number;
  currency: string;
  category_id: string;
  account_id: string;
  schedule_type: string;
  schedule_value: number;
  active: boolean;
}

export interface HariIniGoalItem {
  id: string;
  name: string;
  target_amount: number;
  current_amount: number;
  is_completed: boolean;
  target_date: string | null;
}

export function CommandHeroPulseBar({
  doneTasksCount,
  totalTasksCount,
  todayEventsCount,
  todayFocusMinutes,
  draftCount,
  activeBillsCount,
  formatAmount,
  todayNetCashflow,
}: {
  doneTasksCount: number;
  totalTasksCount: number;
  todayEventsCount: number;
  todayFocusMinutes: number;
  draftCount: number;
  activeBillsCount: number;
  formatAmount: (amount: number) => string;
  todayNetCashflow: number;
}) {
  const completionPct =
    totalTasksCount > 0 ? Math.round((doneTasksCount / totalTasksCount) * 100) : 0;
  const radius = 26;
  const circumference = 2 * Math.PI * radius;
  const dashOffset = circumference - (completionPct / 100) * circumference;

  return (
    <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
      {/* 1. Progres Hari Ini Ring */}
      <Card className="bg-gradient-to-br from-card via-card to-primary-subtle/35 border-primary/25">
        <CardContent className="p-4 flex items-center gap-3.5">
          <div className="relative h-16 w-16 shrink-0 flex items-center justify-center">
            <svg className="h-16 w-16 -rotate-90" viewBox="0 0 64 64" aria-hidden="true">
              <circle
                cx="32"
                cy="32"
                r={radius}
                fill="none"
                stroke="currentColor"
                strokeWidth="6"
                className="text-subtle"
              />
              <circle
                cx="32"
                cy="32"
                r={radius}
                fill="none"
                stroke="currentColor"
                strokeWidth="6"
                strokeLinecap="round"
                strokeDasharray={circumference}
                strokeDashoffset={dashOffset}
                className="text-primary transition-all duration-300"
              />
            </svg>
            <span className="absolute text-xs font-bold tabular-nums text-foreground">
              {completionPct}%
            </span>
          </div>
          <div className="min-w-0">
            <div className="text-[11px] font-semibold uppercase tracking-wider text-primary">
              Ritme Hari Ini
            </div>
            <div className="mt-0.5 text-base font-bold text-foreground tabular-nums">
              {doneTasksCount}/{totalTasksCount} Tugas
            </div>
            <Link
              href="/tugas"
              className="mt-0.5 inline-flex items-center gap-1 text-xs font-medium text-muted-foreground hover:text-primary"
            >
              <span>Buka Papan</span>
              <ArrowUpRight className="h-3 w-3" />
            </Link>
          </div>
        </CardContent>
      </Card>

      {/* 2. Fokus & Agenda */}
      <Card>
        <CardContent className="p-4 flex flex-col justify-between h-full">
          <div className="flex items-center justify-between gap-2">
            <span className="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
              Fokus &amp; Agenda
            </span>
            <Flame className="h-4 w-4 text-primary" aria-hidden="true" />
          </div>
          <div className="mt-2 flex items-baseline gap-2">
            <span className="text-xl font-bold tabular-nums text-foreground">
              {todayFocusMinutes} mnt
            </span>
            <span className="text-xs text-muted-foreground tabular-nums">
              &middot; {todayEventsCount} jadwal
            </span>
          </div>
          <Link
            href="/jadwal"
            className="mt-2 inline-flex items-center gap-1 text-xs font-medium text-primary hover:underline"
          >
            <span>Lihat Linimasa</span>
            <ArrowUpRight className="h-3 w-3" />
          </Link>
        </CardContent>
      </Card>

      {/* 3. Arus Kas Bersih Hari Ini */}
      <Card>
        <CardContent className="p-4 flex flex-col justify-between h-full">
          <div className="flex items-center justify-between gap-2">
            <span className="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
              Arus Kas Hari Ini
            </span>
            <Wallet className="h-4 w-4 text-primary" aria-hidden="true" />
          </div>
          <div
            className={cn(
              'mt-2 text-xl font-bold tabular-nums',
              todayNetCashflow >= 0 ? 'text-income' : 'text-expense'
            )}
          >
            {todayNetCashflow >= 0 ? '+' : '-'}
            {formatAmount(Math.abs(todayNetCashflow))}
          </div>
          <Link
            href="/transaksi"
            className="mt-2 inline-flex items-center gap-1 text-xs font-medium text-primary hover:underline"
          >
            <span>Buka Transaksi</span>
            <ArrowUpRight className="h-3 w-3" />
          </Link>
        </CardContent>
      </Card>

      {/* 4. Pintasan Lintas Modul */}
      <Card>
        <CardContent className="p-4 flex flex-col justify-between h-full">
          <div className="flex items-center justify-between gap-2">
            <span className="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
              Antrean &amp; Tagihan
            </span>
            <StatusBadge variant={draftCount > 0 ? 'warning' : 'neutral'}>
              {draftCount} draft
            </StatusBadge>
          </div>
          <div className="mt-2 flex flex-wrap gap-1.5">
            <Link
              href="/inbox"
              className="inline-flex items-center gap-1 rounded-md border border-border bg-subtle/70 px-2.5 py-1 text-xs font-medium text-foreground hover:border-primary/40 hover:text-primary transition-colors"
            >
              <span>Inbox</span>
            </Link>
            <Link
              href="/tagihan"
              className="inline-flex items-center gap-1 rounded-md border border-border bg-subtle/70 px-2.5 py-1 text-xs font-medium text-foreground hover:border-primary/40 hover:text-primary transition-colors"
            >
              <span>Tagihan ({activeBillsCount})</span>
            </Link>
            <Link
              href="/proyek"
              className="inline-flex items-center gap-1 rounded-md border border-border bg-subtle/70 px-2.5 py-1 text-xs font-medium text-foreground hover:border-primary/40 hover:text-primary transition-colors"
            >
              <span>Proyek</span>
            </Link>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}

function formatTimerClock(seconds: number): string {
  const safe = Math.max(0, Math.floor(seconds));
  const hrs = Math.floor(safe / 3600);
  const mins = Math.floor((safe % 3600) / 60);
  const secs = safe % 60;
  if (hrs > 0) {
    return `${String(hrs).padStart(2, '0')}:${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
  }
  return `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
}

export function InteractiveFocusTimerWidget({
  workspaceId,
  activeTasks,
  selectedTaskId,
  onSelectTaskId,
  onLogged,
}: {
  workspaceId: string | null;
  activeTasks: TaskRecord[];
  selectedTaskId: string;
  onSelectTaskId: (id: string) => void;
  onLogged: () => void;
}) {
  const supabase = useMemo(() => createClient(), []);
  const [mode, setMode] = useState<'pomodoro' | 'stopwatch'>('pomodoro');
  const [running, setRunning] = useState(false);
  const [elapsed, setElapsed] = useState(0);
  const [startedIso, setStartedIso] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [feedback, setFeedback] = useState<string | null>(null);
  const lastTickRef = useRef<number | null>(null);

  const POMODORO_LEN = 25 * 60;

  useEffect(() => {
    if (!selectedTaskId && activeTasks.length > 0) {
      onSelectTaskId(activeTasks[0].id);
    }
  }, [activeTasks, selectedTaskId, onSelectTaskId]);

  useEffect(() => {
    if (!running) {
      lastTickRef.current = null;
      return;
    }
    lastTickRef.current = Date.now();
    const timer = window.setInterval(() => {
      const now = Date.now();
      const prev = lastTickRef.current ?? now;
      const delta = Math.max(1, Math.round((now - prev) / 1000));
      lastTickRef.current = now;
      setElapsed((curr) => curr + delta);
    }, 1000);
    return () => window.clearInterval(timer);
  }, [running]);

  const shownSeconds =
    mode === 'pomodoro' ? Math.max(0, POMODORO_LEN - elapsed) : elapsed;
  const progressRatio =
    mode === 'pomodoro' ? Math.min(1, elapsed / POMODORO_LEN) : Math.min(1, (elapsed % 3600) / 3600);

  const handleStartPause = () => {
    setFeedback(null);
    if (!running) {
      if (!startedIso) setStartedIso(new Date().toISOString());
      setRunning(true);
    } else {
      setRunning(false);
    }
  };

  const handleReset = () => {
    setRunning(false);
    setElapsed(0);
    setStartedIso(null);
  };

  const handleSaveSession = async () => {
    if (!workspaceId || !selectedTaskId) {
      setFeedback('Pilih tugas terlebih dahulu untuk menyimpan sesi fokus.');
      return;
    }
    const secondsToSave = elapsed > 0 ? elapsed : 60;
    setRunning(false);
    setSaving(true);
    setFeedback(null);

    const endMs = Date.now();
    const { error } = await supabase.from('task_time_logs').insert({
      workspace_id: workspaceId,
      task_id: selectedTaskId,
      started_at: startedIso || new Date(endMs - secondsToSave * 1000).toISOString(),
      ended_at: new Date(endMs).toISOString(),
      duration_seconds: secondsToSave,
      mode,
      note: 'Sesi fokus dari Dashboard Hari Ini',
    });

    setSaving(false);
    if (error) {
      setFeedback(`Gagal menyimpan log fokus: ${error.message}`);
      return;
    }

    setElapsed(0);
    setStartedIso(null);
    setFeedback(`Tersimpan ${Math.max(1, Math.round(secondsToSave / 60))} mnt ke log waktu tugas.`);
    onLogged();
  };

  return (
    <Card className="border-primary/25 bg-gradient-to-br from-card to-primary-subtle/20">
      <CardHeader className="py-3">
        <div className="flex items-center gap-2">
          <Timer className="h-4 w-4 text-primary" aria-hidden="true" />
          <CardTitle className="text-sm">Focus Timer Tugas</CardTitle>
          {running && (
            <StatusBadge variant="income">Aktif</StatusBadge>
          )}
        </div>
        <div className="inline-flex rounded-md border border-border bg-subtle p-0.5 text-[11px]">
          <button
            type="button"
            onClick={() => {
              setMode('pomodoro');
              handleReset();
            }}
            className={cn(
              'rounded-xs px-2 py-1 font-medium transition-colors',
              mode === 'pomodoro' ? 'bg-card text-primary shadow-card' : 'text-muted-foreground'
            )}
          >
            Pomodoro
          </button>
          <button
            type="button"
            onClick={() => {
              setMode('stopwatch');
              handleReset();
            }}
            className={cn(
              'rounded-xs px-2 py-1 font-medium transition-colors',
              mode === 'stopwatch' ? 'bg-card text-primary shadow-card' : 'text-muted-foreground'
            )}
          >
            Stopwatch
          </button>
        </div>
      </CardHeader>
      <CardContent className="space-y-3">
        <div className="flex items-center justify-between gap-3">
          <div className="text-3xl font-bold tracking-tight tabular-nums text-foreground font-mono">
            {formatTimerClock(shownSeconds)}
          </div>
          <div className="flex items-center gap-1.5">
            <Button
              type="button"
              size="sm"
              variant={running ? 'secondary' : 'primary'}
              onClick={handleStartPause}
              disabled={activeTasks.length === 0}
            >
              {running ? <Pause className="h-3.5 w-3.5" /> : <Play className="h-3.5 w-3.5" />}
              <span>{running ? 'Jeda' : 'Mulai'}</span>
            </Button>
            <Button
              type="button"
              size="sm"
              variant="outline"
              onClick={handleReset}
              aria-label="Reset timer fokus"
              title="Reset timer"
            >
              <RotateCcw className="h-3.5 w-3.5" />
            </Button>
            <Button
              type="button"
              size="sm"
              variant="outline"
              onClick={() => void handleSaveSession()}
              disabled={saving || activeTasks.length === 0 || elapsed === 0}
              title="Simpan ke log waktu tugas"
            >
              <Save className="h-3.5 w-3.5 text-primary" />
              <span className="hidden sm:inline">{saving ? '...' : 'Simpan'}</span>
            </Button>
          </div>
        </div>

        <div className="h-1.5 w-full overflow-hidden rounded-full bg-subtle">
          <div
            className="h-full rounded-full bg-primary transition-all duration-300"
            style={{ width: `${Math.round(progressRatio * 100)}%` }}
          />
        </div>

        {activeTasks.length > 0 ? (
          <select
            aria-label="Pilih tugas untuk fokus"
            value={selectedTaskId}
            onChange={(e) => onSelectTaskId(e.target.value)}
            className="h-10 w-full rounded-md border border-border bg-card px-2.5 text-xs font-medium text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
          >
            {activeTasks.map((t) => (
              <option key={t.id} value={t.id}>
                {t.title} {t.project_name ? `(${t.project_name})` : ''}
              </option>
            ))}
          </select>
        ) : (
          <div className="text-xs text-muted-foreground">
            Tambahkan tugas aktif untuk mulai mencatat waktu fokus.
          </div>
        )}

        {feedback && (
          <div className="rounded-md border border-primary/25 bg-primary-subtle/40 px-2.5 py-1.5 text-xs text-foreground">
            {feedback}
          </div>
        )}
      </CardContent>
    </Card>
  );
}

export function InteractivePlanningPulseWidget({
  workspaceId,
  budgets,
  bills,
  goals,
  formatAmount,
  onMutated,
}: {
  workspaceId: string | null;
  budgets: HariIniBudgetItem[];
  bills: HariIniBillItem[];
  goals: HariIniGoalItem[];
  formatAmount: (amount: number) => string;
  onMutated: () => void;
}) {
  const supabase = useMemo(() => createClient(), []);
  const [tab, setTab] = useState<'bills' | 'budgets' | 'goals'>('bills');
  const [payingBillId, setPayingBillId] = useState<string | null>(null);
  const [topupGoalId, setTopupGoalId] = useState<string | null>(null);
  const [topupAmount, setTopupAmount] = useState('100000');
  const [feedback, setFeedback] = useState<string | null>(null);

  const activeBills = useMemo(() => bills.filter((b) => b.active), [bills]);

  const handlePayBillNow = async (bill: HariIniBillItem) => {
    if (!workspaceId) return;
    setPayingBillId(bill.id);
    setFeedback(null);

    try {
      const { error } = await supabase.from('transactions').insert({
        workspace_id: workspaceId,
        account_id: bill.account_id,
        category_id: bill.category_id,
        type: 'expense',
        status: 'confirmed',
        amount: Number(bill.amount),
        amount_base: Number(bill.amount),
        currency: bill.currency || 'IDR',
        source: 'personal',
        merchant: bill.name,
        note: `Pembayaran tagihan rutin: ${bill.name}`,
        occurred_at: new Date().toISOString(),
        origin: 'manual',
      });
      if (error) throw error;

      setFeedback(`Tagihan "${bill.name}" (${formatAmount(Number(bill.amount))}) tercatat lunas.`);
      window.dispatchEvent(new CustomEvent('orbit:transaction-created'));
      onMutated();
    } catch (err: unknown) {
      setFeedback(err instanceof Error ? err.message : 'Gagal mencatat pembayaran tagihan.');
    } finally {
      setPayingBillId(null);
    }
  };

  const handleTopupGoal = async (goal: HariIniGoalItem) => {
    const val = parseFloat(topupAmount.replace(/[^0-9.]/g, ''));
    if (isNaN(val) || val <= 0) {
      setFeedback('Masukkan nominal top-up yang valid.');
      return;
    }
    setFeedback(null);
    const nextAmount = Number(goal.current_amount || 0) + val;
    const completed = nextAmount >= Number(goal.target_amount || 1);

    const { error } = await supabase
      .from('savings_goals')
      .update({
        current_amount: nextAmount,
        is_completed: completed,
      })
      .eq('id', goal.id);

    if (error) {
      setFeedback(`Gagal top-up tabungan: ${error.message}`);
      return;
    }

    setTopupGoalId(null);
    setFeedback(`+${formatAmount(val)} ditambahkan ke target "${goal.name}".`);
    onMutated();
  };

  return (
    <Card>
      <CardHeader className="py-3">
        <div className="flex items-center gap-2">
          <Coins className="h-4 w-4 text-primary" aria-hidden="true" />
          <CardTitle className="text-sm">Kontrol Tagihan, Anggaran &amp; Tabungan</CardTitle>
        </div>
        <div className="inline-flex rounded-md border border-border bg-subtle p-0.5 text-[11px]">
          <button
            type="button"
            onClick={() => setTab('bills')}
            className={cn(
              'inline-flex items-center gap-1 rounded-xs px-2 py-1 font-medium transition-colors',
              tab === 'bills' ? 'bg-card text-primary shadow-card' : 'text-muted-foreground'
            )}
          >
            <CalendarClock className="h-3 w-3" />
            <span>Tagihan</span>
          </button>
          <button
            type="button"
            onClick={() => setTab('budgets')}
            className={cn(
              'inline-flex items-center gap-1 rounded-xs px-2 py-1 font-medium transition-colors',
              tab === 'budgets' ? 'bg-card text-primary shadow-card' : 'text-muted-foreground'
            )}
          >
            <PieChart className="h-3 w-3" />
            <span>Anggaran</span>
          </button>
          <button
            type="button"
            onClick={() => setTab('goals')}
            className={cn(
              'inline-flex items-center gap-1 rounded-xs px-2 py-1 font-medium transition-colors',
              tab === 'goals' ? 'bg-card text-primary shadow-card' : 'text-muted-foreground'
            )}
          >
            <Target className="h-3 w-3" />
            <span>Tabungan</span>
          </button>
        </div>
      </CardHeader>
      <CardContent className="space-y-3">
        {feedback && (
          <div className="flex items-center justify-between gap-2 rounded-md border border-primary/25 bg-primary-subtle/40 px-3 py-2 text-xs text-foreground">
            <span>{feedback}</span>
            <button
              type="button"
              onClick={() => setFeedback(null)}
              className="font-semibold text-primary underline"
            >
              Tutup
            </button>
          </div>
        )}

        {tab === 'bills' && (
          <div className="space-y-2.5">
            {activeBills.length === 0 ? (
              <div className="flex items-center justify-between rounded-md border border-dashed border-border p-3 text-xs text-muted-foreground">
                <span>Belum ada tagihan rutin aktif.</span>
                <Link href="/tagihan" className="font-semibold text-primary hover:underline">
                  Kelola Tagihan
                </Link>
              </div>
            ) : (
              activeBills.slice(0, 4).map((bill) => (
                <div
                  key={bill.id}
                  className="flex items-center justify-between gap-3 rounded-md border border-border bg-subtle/40 px-3 py-2.5"
                >
                  <div className="min-w-0">
                    <div className="text-xs font-semibold text-foreground truncate">
                      {bill.name}
                    </div>
                    <div className="text-[11px] text-muted-foreground tabular-nums">
                      {formatAmount(Number(bill.amount))} &middot; Tgl {bill.schedule_value}
                    </div>
                  </div>
                  <Button
                    type="button"
                    size="sm"
                    variant="outline"
                    disabled={payingBillId === bill.id}
                    onClick={() => void handlePayBillNow(bill)}
                    className="min-h-9 px-2.5 text-xs shrink-0"
                  >
                    <Receipt className="h-3.5 w-3.5 text-primary" />
                    <span>{payingBillId === bill.id ? 'Memproses...' : 'Bayar'}</span>
                  </Button>
                </div>
              ))
            )}
          </div>
        )}

        {tab === 'budgets' && (
          <div className="space-y-2.5">
            {budgets.length === 0 ? (
              <div className="flex items-center justify-between rounded-md border border-dashed border-border p-3 text-xs text-muted-foreground">
                <span>Belum ada anggaran bulanan.</span>
                <Link href="/anggaran" className="font-semibold text-primary hover:underline">
                  Atur Anggaran
                </Link>
              </div>
            ) : (
              budgets.slice(0, 4).map((b) => {
                const pct = Math.min(100, Math.round(Number(b.percentage_spent || 0)));
                return (
                  <div key={b.budget_id} className="space-y-1.5 rounded-md border border-border p-2.5">
                    <div className="flex items-center justify-between gap-2 text-xs">
                      <span className="font-semibold text-foreground truncate">
                        {b.category_name || 'Kategori'}
                      </span>
                      <span
                        className={cn(
                          'font-semibold tabular-nums',
                          b.is_over_budget
                            ? 'text-expense'
                            : b.is_warning
                            ? 'text-warning'
                            : 'text-muted-foreground'
                        )}
                      >
                        {formatAmount(Number(b.spent_amount || 0))} / {formatAmount(Number(b.effective_budget_amount || 0))}
                      </span>
                    </div>
                    <div className="h-2 w-full overflow-hidden rounded-full bg-subtle">
                      <div
                        className={cn(
                          'h-full rounded-full transition-all duration-300',
                          b.is_over_budget
                            ? 'bg-expense'
                            : b.is_warning
                            ? 'bg-warning'
                            : 'bg-primary'
                        )}
                        style={{ width: `${pct}%` }}
                      />
                    </div>
                  </div>
                );
              })
            )}
          </div>
        )}

        {tab === 'goals' && (
          <div className="space-y-2.5">
            {goals.length === 0 ? (
              <div className="flex items-center justify-between rounded-md border border-dashed border-border p-3 text-xs text-muted-foreground">
                <span>Belum ada target tabungan.</span>
                <Link href="/tabungan" className="font-semibold text-primary hover:underline">
                  Buat Target
                </Link>
              </div>
            ) : (
              goals.slice(0, 4).map((g) => {
                const ratio =
                  Number(g.target_amount) > 0
                    ? Math.min(100, Math.round((Number(g.current_amount) / Number(g.target_amount)) * 100))
                    : 0;
                const isEditingTopup = topupGoalId === g.id;
                return (
                  <div key={g.id} className="space-y-2 rounded-md border border-border p-2.5">
                    <div className="flex items-center justify-between gap-2">
                      <div className="min-w-0">
                        <div className="flex items-center gap-1.5 text-xs font-semibold text-foreground truncate">
                          <span>{g.name}</span>
                          {g.is_completed && (
                            <CheckCircle2 className="h-3.5 w-3.5 text-income shrink-0" />
                          )}
                        </div>
                        <div className="text-[11px] text-muted-foreground tabular-nums">
                          {formatAmount(Number(g.current_amount))} / {formatAmount(Number(g.target_amount))} ({ratio}%)
                        </div>
                      </div>
                      <Button
                        type="button"
                        size="sm"
                        variant="outline"
                        onClick={() => setTopupGoalId(isEditingTopup ? null : g.id)}
                        className="min-h-9 px-2.5 text-xs shrink-0"
                      >
                        <Plus className="h-3.5 w-3.5 text-primary" />
                        <span>Top-up</span>
                      </Button>
                    </div>
                    <div className="h-1.5 w-full overflow-hidden rounded-full bg-subtle">
                      <div
                        className={cn(
                          'h-full rounded-full transition-all duration-300',
                          g.is_completed ? 'bg-income' : 'bg-primary'
                        )}
                        style={{ width: `${ratio}%` }}
                      />
                    </div>
                    {isEditingTopup && (
                      <div className="flex items-center gap-2 pt-1">
                        <Input
                          type="number"
                          min="1000"
                          value={topupAmount}
                          onChange={(e) => setTopupAmount(e.target.value)}
                          placeholder="Nominal top-up"
                          className="h-9 text-xs tabular-nums"
                        />
                        <Button
                          type="button"
                          size="sm"
                          onClick={() => void handleTopupGoal(g)}
                          className="min-h-9 px-3 text-xs shrink-0"
                        >
                          Setor
                        </Button>
                      </div>
                    )}
                  </div>
                );
              })
            )}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
