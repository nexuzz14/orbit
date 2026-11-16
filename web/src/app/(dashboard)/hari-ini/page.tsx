'use client';

import React, { useCallback, useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import {
  AlertCircle,
  AlertTriangle,
  ArrowRight,
  BellRing,
  Calendar,
  CalendarPlus,
  CheckCircle2,
  CheckSquare,
  Circle,
  Copy,
  ExternalLink,
  Inbox,
  Mail,
  MapPin,
  Plus,
  Receipt,
  RotateCcw,
  Sparkles,
  Timer,
  Wallet,
} from 'lucide-react';
import { createClient } from '@/lib/supabase/client';
import {
  formatDateIndo,
  getDateKeyInTimezone,
  getGreeting,
} from '@/lib/format';
import {
  buildWeeklyDigestSummary,
  detectSmartAlerts,
  type AlertBillInput,
  type AlertBudgetInput,
  type AlertEventInput,
  type DigestTransactionInput,
} from '@/lib/smart-alerts';
import { usePrivacyMode } from '@/lib/privacy-mode';
import { RealtimeStatusBadge, useOrbitRealtime } from '@/lib/use-orbit-realtime';
import {
  computeAttentionSummary,
  computeTaskProgress,
  getStagnantDays,
  isTaskOverdue,
  isTaskStagnant,
} from '@/lib/task-v2';
import type { ActivityKind, TaskPriority, TaskStatus, TransactionSource } from '@/types/database';
import {
  AttentionBannerCard,
  type AttentionPreviewItem,
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
  ProgressControl,
  Select,
  Skeleton,
  StatusBadge,
  TaskStatusBadge,
} from '@/components/ui';
import { TransactionFormModal, type TransactionPrefill } from '@/components/transaction-form-modal';
import {
  CommandHeroPulseBar,
  InteractiveFocusTimerWidget,
  InteractivePlanningPulseWidget,
  type HariIniBillItem,
  type HariIniBudgetItem,
  type HariIniGoalItem,
} from '@/components/dashboard/hari-ini-command-widgets';
import {
  changeTaskStatusWithRpc,
  mapRawTaskRow,
} from '@/components/tasks/task-actions';
import { RevisionDialog } from '@/components/tasks/revision-dialog';
import { DetailPeek } from '@/components/tasks/detail-peek';
import type {
  PaymentOption,
  ProjectOption,
  TaskRecord,
} from '@/components/tasks/types';

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

const ACTIVE_WORKSPACE_STORAGE_KEY = 'orbit_active_workspace_id';

export default function HariIniPage() {
  const supabase = useMemo(() => createClient(), []);
  const { privacyMode, formatAmount } = usePrivacyMode();

  const [loading, setLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [statusFeedback, setStatusFeedback] = useState<string | null>(null);
  const [workspaceId, setWorkspaceId] = useState<string | null>(null);
  const [selectedKind, setSelectedKind] = useState<ActivityKind | 'all'>('all');

  const [agendaItems, setAgendaItems] = useState<AgendaItem[]>([]);
  const [workspaceTasks, setWorkspaceTasks] = useState<TaskRecord[]>([]);
  const [projects, setProjects] = useState<ProjectOption[]>([]);
  const [payments, setPayments] = useState<PaymentOption[]>([]);
  const [conflicts, setConflicts] = useState<ConflictItem[]>([]);
  const [isHeavyDay, setIsHeavyDay] = useState(false);
  const [receivables, setReceivables] = useState<ReceivableItem[]>([]);
  const [liquidBalance, setLiquidBalance] = useState<number>(0);
  const [todayIncome, setTodayIncome] = useState<number>(0);
  const [todayExpense, setTodayExpense] = useState<number>(0);
  const [draftCount, setDraftCount] = useState<number>(0);
  const [accounts, setAccounts] = useState<AccountItem[]>([]);

  const [peekTaskId, setPeekTaskId] = useState<string | null>(null);
  const [pendingRevision, setPendingRevision] = useState<{
    task: TaskRecord;
    toStatus: TaskStatus;
  } | null>(null);
  const [revisionSubmitting, setRevisionSubmitting] = useState(false);

  const [showMilestoneModal, setShowMilestoneModal] = useState(false);
  const [pendingMilestoneId, setPendingMilestoneId] = useState<string | null>(null);
  const [pendingTaskTitle, setPendingTaskTitle] = useState<string>('');
  const [selectedAccountId, setSelectedAccountId] = useState<string>('');
  const [markingPaid, setMarkingPaid] = useState(false);

  const [showQuickTaskModal, setShowQuickTaskModal] = useState(false);
  const [newTaskTitle, setNewTaskTitle] = useState('');
  const [newTaskKind, setNewTaskKind] = useState<ActivityKind>('pribadi');
  const [newTaskPriority, setNewTaskPriority] = useState<TaskPriority>('sedang');
  const [savingTask, setSavingTask] = useState(false);

  const [showTxModal, setShowTxModal] = useState(false);
  const [txPrefill, setTxPrefill] = useState<TransactionPrefill | null>(null);
  const [focusTaskId, setFocusTaskId] = useState<string>('');
  const [crossFeedback, setCrossFeedback] = useState<string | null>(null);
  const [todayFocusMinutes, setTodayFocusMinutes] = useState<number>(0);
  const [savingsGoals, setSavingsGoals] = useState<HariIniGoalItem[]>([]);
  const [detailedBudgets, setDetailedBudgets] = useState<HariIniBudgetItem[]>([]);
  const [detailedBills, setDetailedBills] = useState<HariIniBillItem[]>([]);

  const [digestBudgets, setDigestBudgets] = useState<AlertBudgetInput[]>([]);
  const [digestBills, setDigestBills] = useState<AlertBillInput[]>([]);
  const [digestTransactions, setDigestTransactions] = useState<DigestTransactionInput[]>([]);
  const [weekEvents, setWeekEvents] = useState<AlertEventInput[]>([]);
  const [digestCopied, setDigestCopied] = useState(false);
  const [browserNotifFeedback, setBrowserNotifFeedback] = useState<string | null>(null);

  const todayStr = useMemo(
    () => getDateKeyInTimezone(new Date(), 'Asia/Jakarta'),
    []
  );

  const loadData = useCallback(async () => {
    setLoading(true);
    setErrorMessage(null);

    try {
      const { data: memberships, error: memberErr } = await supabase
        .from('workspace_members')
        .select('workspace_id');

      if (memberErr && memberErr.code !== 'PGRST116') {
        throw new Error(memberErr.message || 'Gagal memuat workspace.');
      }

      if (!memberships || memberships.length === 0) {
        setAgendaItems([]);
        setWorkspaceTasks([]);
        setLoading(false);
        return;
      }

      const preferredWs =
        typeof window !== 'undefined'
          ? window.localStorage.getItem(ACTIVE_WORKSPACE_STORAGE_KEY)
          : null;
      const wsId =
        memberships.find((m) => m.workspace_id === preferredWs)?.workspace_id ??
        memberships[0].workspace_id;

      setWorkspaceId(wsId);

      const kindFilter = selectedKind === 'all' ? undefined : selectedKind;
      const nowMs = Date.now();
      const past7Iso = new Date(nowMs - 7 * 24 * 60 * 60 * 1000).toISOString();
      const next7Iso = new Date(nowMs + 7 * 24 * 60 * 60 * 1000).toISOString();

      const [
        accRes,
        agendaRes,
        conflictRes,
        recRes,
        balRes,
        todayTxRes,
        draftRes,
        tasksRes,
        projectsRes,
        paymentsRes,
        budgetRes,
        billsRes,
        weekTxRes,
        weekEventsRes,
        goalsRes,
        timeLogsRes,
      ] = await Promise.all([
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
          .gte('occurred_at', `${todayStr}T00:00:00+07:00`)
          .lte('occurred_at', `${todayStr}T23:59:59+07:00`),
        supabase
          .from('transactions')
          .select('*', { count: 'exact', head: true })
          .eq('workspace_id', wsId)
          .eq('status', 'draft')
          .is('deleted_at', null),
        supabase
          .from('tasks')
          .select(
            '*, projects(name), task_checklist_items(id, task_id, text, done, sort_order, created_at, updated_at)'
          )
          .eq('workspace_id', wsId)
          .is('deleted_at', null)
          .order('sort_order', { ascending: true }),
        supabase
          .from('projects')
          .select('id, name, kind')
          .eq('workspace_id', wsId)
          .is('deleted_at', null)
          .order('name', { ascending: true }),
        supabase
          .from('project_payments')
          .select('id, project_id, label, amount')
          .eq('workspace_id', wsId)
          .eq('status', 'expected')
          .is('deleted_at', null),
        supabase
          .from('v_budget_progress')
          .select(
            'budget_id, category_id, category_name, effective_budget_amount, spent_amount, percentage_spent, is_over_budget, is_warning, notify_at_percent'
          )
          .eq('workspace_id', wsId),
        supabase
          .from('recurring_bills')
          .select('id, name, amount, currency, category_id, account_id, active, schedule_type, schedule_value')
          .eq('workspace_id', wsId)
          .is('deleted_at', null),
        supabase
          .from('transactions')
          .select('id, type, amount, occurred_at, status, deleted_at')
          .eq('workspace_id', wsId)
          .eq('status', 'confirmed')
          .is('deleted_at', null)
          .gte('occurred_at', past7Iso),
        supabase
          .from('events')
          .select('id, title, starts_at, ends_at, all_day')
          .eq('workspace_id', wsId)
          .is('deleted_at', null)
          .gte('ends_at', new Date(nowMs - 2 * 60 * 60 * 1000).toISOString())
          .lte('starts_at', next7Iso),
        supabase
          .from('savings_goals')
          .select('id, name, target_amount, current_amount, is_completed, target_date')
          .eq('workspace_id', wsId)
          .is('deleted_at', null)
          .order('created_at', { ascending: false }),
        supabase
          .from('task_time_logs')
          .select('duration_seconds')
          .eq('workspace_id', wsId)
          .is('deleted_at', null)
          .gte('started_at', `${todayStr}T00:00:00+07:00`),
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

      if (!tasksRes.error && tasksRes.data) {
        const mapped = (tasksRes.data as unknown as Record<string, unknown>[]).map(
          mapRawTaskRow
        );
        setWorkspaceTasks(mapped);
      } else {
        setWorkspaceTasks([]);
      }

      if (!projectsRes.error && projectsRes.data) {
        setProjects(
          projectsRes.data.map((p) => ({
            id: p.id,
            name: p.name,
            kind: p.kind,
          }))
        );
      }

      if (!paymentsRes.error && paymentsRes.data) {
        setPayments(
          paymentsRes.data.map((pay) => ({
            id: pay.id,
            project_id: pay.project_id,
            label: pay.label,
            amount: Number(pay.amount),
          }))
        );
      }

      setDigestBudgets(!budgetRes.error && Array.isArray(budgetRes.data) ? (budgetRes.data as AlertBudgetInput[]) : []);
      setDetailedBudgets(!budgetRes.error && Array.isArray(budgetRes.data) ? (budgetRes.data as HariIniBudgetItem[]) : []);
      setDigestBills(!billsRes.error && Array.isArray(billsRes.data) ? (billsRes.data as AlertBillInput[]) : []);
      setDetailedBills(!billsRes.error && Array.isArray(billsRes.data) ? (billsRes.data as HariIniBillItem[]) : []);
      setSavingsGoals(!goalsRes.error && Array.isArray(goalsRes.data) ? (goalsRes.data as HariIniGoalItem[]) : []);
      if (!timeLogsRes.error && Array.isArray(timeLogsRes.data)) {
        const totalSec = timeLogsRes.data.reduce(
          (acc, row) => acc + Math.max(0, Number((row as { duration_seconds?: number }).duration_seconds || 0)),
          0
        );
        setTodayFocusMinutes(Math.round(totalSec / 60));
      } else {
        setTodayFocusMinutes(0);
      }
      setDigestTransactions(
        !weekTxRes.error && Array.isArray(weekTxRes.data)
          ? (weekTxRes.data as DigestTransactionInput[])
          : []
      );
      setWeekEvents(
        !weekEventsRes.error && Array.isArray(weekEventsRes.data)
          ? (weekEventsRes.data as AlertEventInput[])
          : []
      );
    } catch (err) {
      setErrorMessage(
        err instanceof Error ? err.message : 'Gagal memuat ringkasan hari ini.'
      );
    } finally {
      setLoading(false);
    }
  }, [supabase, todayStr, selectedKind, selectedAccountId]);

  useEffect(() => {
    void loadData();
    const onRefresh = () => void loadData();
    window.addEventListener('orbit:transaction-created', onRefresh);
    window.addEventListener('orbit:workspace-changed', onRefresh);
    return () => {
      window.removeEventListener('orbit:transaction-created', onRefresh);
      window.removeEventListener('orbit:workspace-changed', onRefresh);
    };
  }, [loadData]);

  const { status: realtimeStatus } = useOrbitRealtime({
    workspaceId,
    tables: ['tasks', 'transactions', 'events', 'budgets', 'project_payments'],
    onChange: loadData,
  });

  const smartAlerts = useMemo(
    () =>
      detectSmartAlerts({
        events: weekEvents,
        tasks: workspaceTasks,
        budgets: digestBudgets,
        bills: digestBills,
      }),
    [weekEvents, workspaceTasks, digestBudgets, digestBills]
  );

  const weeklyDigest = useMemo(
    () =>
      buildWeeklyDigestSummary({
        tasks: workspaceTasks,
        transactions: digestTransactions,
        events: weekEvents,
        bills: digestBills,
        maskAmounts: privacyMode,
      }),
    [workspaceTasks, digestTransactions, weekEvents, digestBills, privacyMode]
  );

  const handleCopyWeeklyDigest = async () => {
    try {
      await navigator.clipboard.writeText(weeklyDigest.plainText);
      setDigestCopied(true);
      setTimeout(() => setDigestCopied(false), 2000);
    } catch {
      setBrowserNotifFeedback('Gagal menyalin ringkasan ke clipboard.');
    }
  };

  const handleSendBrowserNotification = async () => {
    if (typeof window === 'undefined' || !('Notification' in window)) {
      setBrowserNotifFeedback('Browser ini belum mendukung Web Notification API.');
      return;
    }
    try {
      let permission = Notification.permission;
      if (permission === 'default') {
        permission = await Notification.requestPermission();
      }
      if (permission !== 'granted') {
        setBrowserNotifFeedback(
          'Izin notifikasi browser belum diizinkan. Aktifkan izin notifikasi pada pengaturan situs browser Anda.'
        );
        return;
      }

      const alertHeadline =
        smartAlerts.length > 0
          ? smartAlerts[0].title
          : `${weeklyDigest.next7Days.activeTasksCount} tugas aktif dan ${weeklyDigest.next7Days.upcomingEventsCount} agenda minggu ini.`;

      new Notification('Pengingat Orbit', {
        body: privacyMode
          ? 'Ada pembaruan penting di ruang kerja Anda. Buka Orbit untuk melihat detail.'
          : alertHeadline,
        icon: '/orbit-icon-192.png',
      });
      setBrowserNotifFeedback('Notifikasi uji browser berhasil dikirim.');
    } catch {
      setBrowserNotifFeedback('Gagal menampilkan notifikasi uji di browser ini.');
    }
  };

  const subtasksByParent = useMemo(() => {
    const map = new Map<string, TaskRecord[]>();
    for (const item of workspaceTasks) {
      if (!item.parent_task_id) continue;
      const arr = map.get(item.parent_task_id) ?? [];
      arr.push(item);
      map.set(item.parent_task_id, arr);
    }
    return map;
  }, [workspaceTasks]);

  const kindFilteredWorkspaceTasks = useMemo(() => {
    if (selectedKind === 'all') return workspaceTasks;
    return workspaceTasks.filter((t) => t.kind === selectedKind);
  }, [workspaceTasks, selectedKind]);

  const attentionSummary = useMemo(
    () =>
      computeAttentionSummary({
        tasks: kindFilteredWorkspaceTasks,
        conflictCount: conflicts.length,
      }),
    [kindFilteredWorkspaceTasks, conflicts.length]
  );

  const attentionPreviewItems: AttentionPreviewItem[] = useMemo(() => {
    const out: AttentionPreviewItem[] = [];
    for (const t of kindFilteredWorkspaceTasks) {
      if (t.status === 'done') continue;
      if (t.status === 'revisi') {
        out.push({
          id: `rev-${t.id}`,
          title: t.title,
          badge: `Revisi ${t.revision_count}x`,
          tone: 'warning',
          subtitle: t.latest_revision_note ?? undefined,
          onClick: () => setPeekTaskId(t.id),
        });
      } else if (isTaskOverdue(t)) {
        out.push({
          id: `due-${t.id}`,
          title: t.title,
          badge: 'Terlambat',
          tone: 'expense',
          subtitle: t.project_name ?? undefined,
          onClick: () => setPeekTaskId(t.id),
        });
      } else if (isTaskStagnant(t)) {
        out.push({
          id: `stg-${t.id}`,
          title: t.title,
          badge: `Macet ${getStagnantDays(t)}h`,
          tone: 'warning',
          subtitle: t.project_name ?? undefined,
          onClick: () => setPeekTaskId(t.id),
        });
      }
      if (out.length >= 6) break;
    }
    return out;
  }, [kindFilteredWorkspaceTasks]);

  // Daftar tugas fokus hari ini: gabungan hasil fn_agenda + task terlambat / revisi aktif
  const focusTaskRecords = useMemo(() => {
    const agendaTaskIds = new Set(
      agendaItems.filter((i) => i.item_type === 'task').map((i) => i.id)
    );
    const taskMap = new Map(kindFilteredWorkspaceTasks.map((t) => [t.id, t]));
    const collected: TaskRecord[] = [];
    const seen = new Set<string>();

    // 1. Tugas terlambat atau revisi dari workspaceTasks
    for (const t of kindFilteredWorkspaceTasks) {
      if (t.parent_task_id || t.status === 'done') continue;
      if (t.status === 'revisi' || isTaskOverdue(t)) {
        collected.push(t);
        seen.add(t.id);
      }
    }

    // 2. Tugas hari ini dari agendaItems (enriched dari workspaceTasks jika tersedia)
    for (const item of agendaItems) {
      if (item.item_type !== 'task' || seen.has(item.id)) continue;
      const existing = taskMap.get(item.id);
      if (existing) {
        collected.push(existing);
      } else if (agendaTaskIds.has(item.id)) {
        collected.push(
          mapRawTaskRow({
            id: item.id,
            workspace_id: workspaceId ?? '',
            project_id: item.project_id,
            project_name: item.project_name,
            kind: item.kind,
            title: item.title,
            description: item.description,
            status: item.status,
            priority: item.priority ?? 'sedang',
            due_at: item.due_at,
            due_is_date_only: item.due_is_date_only,
            milestone_payment_id: item.milestone_payment_id,
          })
        );
      }
      seen.add(item.id);
    }

    return collected;
  }, [agendaItems, kindFilteredWorkspaceTasks, workspaceId]);

  const executeStatusTransition = useCallback(
    async (task: TaskRecord, toStatus: TaskStatus, note?: string | null) => {
      setStatusFeedback(null);
      const prevTasks = workspaceTasks;

      setWorkspaceTasks((prev) =>
        prev.map((item) =>
          item.id === task.id
            ? {
                ...item,
                status: toStatus,
                progress_percent: toStatus === 'done' ? 100 : item.progress_percent,
                completed_at:
                  toStatus === 'done'
                    ? item.completed_at || new Date().toISOString()
                    : null,
                revision_count:
                  toStatus === 'revisi' && task.status !== 'revisi'
                    ? item.revision_count + 1
                    : item.revision_count,
                latest_revision_note:
                  toStatus === 'revisi' && note ? note : item.latest_revision_note,
              }
            : item
        )
      );

      const res = await changeTaskStatusWithRpc({
        supabase,
        task,
        toStatus,
        note: note ?? null,
      });

      if (!res.ok) {
        setWorkspaceTasks(prevTasks);
        setStatusFeedback(res.errorMessage ?? 'Gagal mengubah status tugas.');
        return;
      }

      if (res.updatedRow) {
        setWorkspaceTasks((prev) =>
          prev.map((item) => (item.id === task.id ? res.updatedRow! : item))
        );
      }

      if (toStatus === 'done' && task.milestone_payment_id) {
        setPendingMilestoneId(task.milestone_payment_id);
        setPendingTaskTitle(task.title);
        setShowMilestoneModal(true);
      }
    },
    [supabase, workspaceTasks]
  );

  const handleRequestStatusChange = useCallback(
    async (task: TaskRecord, toStatus: TaskStatus) => {
      if (toStatus === 'revisi' && task.status !== 'revisi') {
        setPendingRevision({ task, toStatus });
        return;
      }
      await executeStatusTransition(task, toStatus);
    },
    [executeStatusTransition]
  );

  const handleConfirmRevision = async (note: string) => {
    if (!pendingRevision) return;
    setRevisionSubmitting(true);
    try {
      await executeStatusTransition(pendingRevision.task, pendingRevision.toStatus, note);
      setPendingRevision(null);
    } finally {
      setRevisionSubmitting(false);
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
      void loadData();
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
      due_at: new Date(`${todayStr}T23:59:59+07:00`).toISOString(),
      due_is_date_only: true,
      status: 'todo',
    });

    setSavingTask(false);
    if (!error) {
      setNewTaskTitle('');
      setShowQuickTaskModal(false);
      void loadData();
    }
  };

  const mapKindToTxSource = (kind: ActivityKind): TransactionSource => {
    if (kind === 'intern' || kind === 'freelance' || kind === 'kuliah') return kind;
    return 'personal';
  };

  const handleCreateTaskFromEvent = async (evt: AgendaItem) => {
    if (!workspaceId) return;
    setCrossFeedback(null);
    const { data: created, error } = await supabase
      .from('tasks')
      .insert({
        workspace_id: workspaceId,
        project_id: evt.project_id,
        kind: evt.kind,
        title: `Tindak lanjut: ${evt.title}`,
        priority: 'sedang',
        due_at: evt.ends_at || new Date(`${todayStr}T23:59:59+07:00`).toISOString(),
        due_is_date_only: evt.all_day,
        status: 'todo',
      })
      .select('id')
      .single();

    if (error) {
      setCrossFeedback(`Gagal membuat tugas dari jadwal: ${error.message}`);
      return;
    }

    const eventId = evt.event_id || evt.id;
    if (created?.id && eventId) {
      try {
        await supabase.from('entity_links').insert({
          workspace_id: workspaceId,
          source_type: 'task',
          source_id: created.id,
          target_type: 'event',
          target_id: eventId,
          relation_type: 'derived_from',
        });
      } catch {
        // Abaikan jika entity_links belum tersedia
      }
    }
    setCrossFeedback(`Tugas "Tindak lanjut: ${evt.title}" dibuat dan ditautkan ke jadwal.`);
    void loadData();
  };

  const handleScheduleTaskFocusBlock = async (task: TaskRecord) => {
    if (!workspaceId) return;
    setCrossFeedback(null);

    const baseDate = task.due_at ? getDateKeyInTimezone(task.due_at, 'Asia/Jakarta') : todayStr;
    const nowHour = new Date().getHours();
    const startHour = Math.min(22, Math.max(8, nowHour + 1));
    const durationMins = Math.max(30, Math.min(180, task.estimate_minutes || 60));
    const startsAt = new Date(`${baseDate}T${String(startHour).padStart(2, '0')}:00:00+07:00`);
    const endsAt = new Date(startsAt.getTime() + durationMins * 60 * 1000);

    const { data: createdEvent, error } = await supabase
      .from('events')
      .insert({
        workspace_id: workspaceId,
        project_id: task.project_id,
        kind: task.kind,
        title: `Fokus: ${task.title}`,
        starts_at: startsAt.toISOString(),
        ends_at: endsAt.toISOString(),
        all_day: false,
        timezone: 'Asia/Jakarta',
      })
      .select('id')
      .single();

    if (error) {
      setCrossFeedback(`Gagal menjadwalkan blok fokus: ${error.message}`);
      return;
    }

    if (createdEvent?.id) {
      try {
        await supabase.from('entity_links').insert({
          workspace_id: workspaceId,
          source_type: 'event',
          source_id: createdEvent.id,
          target_type: 'task',
          target_id: task.id,
          relation_type: 'related',
        });
      } catch {
        // Abaikan jika entity_links belum tersedia
      }
    }
    setCrossFeedback(`Blok fokus "${task.title}" (${durationMins} mnt) ditambahkan ke Jadwal.`);
    void loadData();
  };

  const scheduledEvents = agendaItems.filter((i) => i.item_type === 'event');
  const activeWorkspaceTasks = useMemo(
    () => kindFilteredWorkspaceTasks.filter((t) => !t.parent_task_id && t.status !== 'done'),
    [kindFilteredWorkspaceTasks]
  );
  const doneTodayCount = useMemo(
    () => kindFilteredWorkspaceTasks.filter((t) => !t.parent_task_id && t.status === 'done').length,
    [kindFilteredWorkspaceTasks]
  );
  const totalMainTasksCount = useMemo(
    () => kindFilteredWorkspaceTasks.filter((t) => !t.parent_task_id).length,
    [kindFilteredWorkspaceTasks]
  );
  const conflictEventIds = new Set(
    conflicts.flatMap((c) => [c.event1_id, c.event2_id]).filter(Boolean) as string[]
  );
  const activePeekTask = peekTaskId
    ? workspaceTasks.find((t) => t.id === peekTaskId) ?? null
    : null;

  return (
    <div className="space-y-6">
      {/* Header Sapaan & Tanggal */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-border pb-4">
        <div>
          <div className="flex items-center gap-2.5 flex-wrap">
            <p className="text-xs font-semibold uppercase tracking-wider text-primary">
              {formatDateIndo(todayStr)}
            </p>
            <RealtimeStatusBadge status={realtimeStatus} />
          </div>
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
          <Button variant="primary" onClick={() => {
            setTxPrefill(null);
            setShowTxModal(true);
          }}>
            <Receipt className="h-4 w-4" aria-hidden="true" />
            <span>Catat Transaksi</span>
          </Button>
        </div>
      </div>

      {/* Bento Hero Command Pulse Bar (Progress Ring, Focus, Cashflow, Cross-Module Links) */}
      {!loading && !errorMessage && (
        <CommandHeroPulseBar
          doneTasksCount={doneTodayCount}
          totalTasksCount={totalMainTasksCount}
          todayEventsCount={scheduledEvents.length}
          todayFocusMinutes={todayFocusMinutes}
          draftCount={draftCount}
          activeBillsCount={detailedBills.filter((b) => b.active).length}
          formatAmount={formatAmount}
          todayNetCashflow={todayIncome - todayExpense}
        />
      )}

      {crossFeedback && (
        <div
          role="status"
          className="flex items-center justify-between gap-2 rounded-lg border border-primary/30 bg-primary-subtle/40 px-3.5 py-2.5 text-xs text-foreground"
        >
          <span>{crossFeedback}</span>
          <button
            type="button"
            onClick={() => setCrossFeedback(null)}
            className="font-semibold text-primary underline"
          >
            Tutup
          </button>
        </div>
      )}

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
      {errorMessage && <ErrorState message={errorMessage} onRetry={() => void loadData()} />}

      {statusFeedback && (
        <div
          role="alert"
          className="flex items-center justify-between gap-2 rounded-lg border border-expense-border bg-expense-subtle px-3.5 py-2.5 text-xs text-expense"
        >
          <span>{statusFeedback}</span>
          <button
            type="button"
            onClick={() => setStatusFeedback(null)}
            className="font-medium underline"
          >
            Tutup
          </button>
        </div>
      )}

      {/* Attention Banner Card (D.2) */}
      {!loading && !errorMessage && (
        <AttentionBannerCard
          overdueCount={attentionSummary.overdueCount}
          revisiCount={attentionSummary.revisiCount}
          stagnantCount={attentionSummary.stagnantCount}
          conflictCount={attentionSummary.conflictCount}
          items={attentionPreviewItems}
        />
      )}

      {/* Peringatan Detail Benturan Jadwal atau Hari Padat */}
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
                  &ldquo;{c.event1_title}&rdquo; dan &ldquo;{c.event2_title}&rdquo; berada
                  pada jam yang tumpang tindih.
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

      {/* Grid Utama */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Kolom Kiri (7 kolom): Jadwal & Tugas Fokus Hari Ini */}
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
                          timeZone: 'Asia/Jakarta',
                          hour: '2-digit',
                          minute: '2-digit',
                        })
                      : '--:--';
                    const endTime = evt.ends_at
                      ? new Date(evt.ends_at).toLocaleTimeString('id-ID', {
                          timeZone: 'Asia/Jakarta',
                          hour: '2-digit',
                          minute: '2-digit',
                        })
                      : '--:--';
                    const hasConflict = evt.event_id
                      ? conflictEventIds.has(evt.event_id)
                      : false;

                    return (
                      <div
                        key={evt.id}
                        className="flex items-start gap-4 py-3 first:pt-0 last:pb-0"
                      >
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
                            <div className="flex flex-wrap items-center gap-3 text-xs text-muted-foreground">
                              {evt.location && (
                                <span className="inline-flex items-center gap-1">
                                  <MapPin className="h-3.5 w-3.5" aria-hidden="true" />
                                  <span>{evt.location}</span>
                                </span>
                              )}
                              {evt.project_name && (
                                <Link
                                  href={`/proyek`}
                                  className="text-primary hover:underline font-medium"
                                >
                                  Kegiatan: {evt.project_name}
                                </Link>
                              )}
                            </div>
                          <div className="mt-2 flex flex-wrap items-center gap-1.5">
                            <button
                              type="button"
                              onClick={() => void handleCreateTaskFromEvent(evt)}
                              className="inline-flex items-center gap-1 rounded-md border border-border bg-subtle/60 px-2 py-1 text-[11px] font-medium text-foreground hover:border-primary/40 hover:text-primary transition-colors"
                            >
                              <Plus className="h-3 w-3" />
                              <span>Buat Tugas</span>
                            </button>
                            <button
                              type="button"
                              onClick={() => {
                                setTxPrefill({
                                  type: 'expense',
                                  note: `Biaya jadwal: ${evt.title}`,
                                  source: mapKindToTxSource(evt.kind),
                                  projectId: evt.project_id,
                                  linkTarget: { type: 'event', id: evt.event_id || evt.id },
                                });
                                setShowTxModal(true);
                              }}
                              className="inline-flex items-center gap-1 rounded-md border border-border bg-subtle/60 px-2 py-1 text-[11px] font-medium text-foreground hover:border-primary/40 hover:text-primary transition-colors"
                            >
                              <Receipt className="h-3 w-3" />
                              <span>Catat Biaya</span>
                            </button>
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </CardContent>
          </Card>

          {/* 1B. Tugas Fokus & Perhatian Hari Ini (D.2) */}
          <Card>
            <CardHeader>
              <div className="flex items-center gap-2">
                <CheckSquare className="h-4 w-4 text-primary" aria-hidden="true" />
                <CardTitle>Tugas Fokus Hari Ini</CardTitle>
                <StatusBadge
                  variant={attentionSummary.overdueCount > 0 ? 'expense' : 'neutral'}
                >
                  {focusTaskRecords.length}
                </StatusBadge>
              </div>
              <Link
                href="/tugas"
                className="min-h-11 inline-flex items-center gap-1 px-2 text-xs font-medium text-primary hover:underline"
              >
                <span>Buka Papan Tugas</span>
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
              ) : focusTaskRecords.length === 0 ? (
                <EmptyState
                  title="Tidak ada tugas jatuh tempo atau revisi"
                  description="Semua tugas prioritas hari ini aman. Tambah tugas cepat atau buka papan tugas."
                  actionLabel="Tambah Tugas Cepat"
                  onAction={() => setShowQuickTaskModal(true)}
                />
              ) : (
                <div className="divide-y divide-border">
                  {focusTaskRecords.map((task) => {
                    const isDone = task.status === 'done';
                    const overdue = isTaskOverdue(task);
                    const stagnant = isTaskStagnant(task);
                    const subtasks = subtasksByParent.get(task.id) ?? [];
                    const progress = computeTaskProgress({
                      status: task.status,
                      progressPercent: task.progress_percent,
                      checklistItems: task.checklist_items,
                      subtasks,
                    });

                    return (
                      <div
                        key={task.id}
                        className="flex flex-col gap-2 py-3 first:pt-0 last:pb-0 sm:flex-row sm:items-center sm:justify-between"
                      >
                        <div className="flex items-start gap-2 min-w-0 flex-1">
                          <button
                            type="button"
                            onClick={() =>
                              void handleRequestStatusChange(
                                task,
                                isDone ? 'todo' : 'done'
                              )
                            }
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

                          <div className="min-w-0 flex-1 space-y-1">
                            <div className="flex flex-wrap items-center gap-1.5">
                              <button
                                type="button"
                                onClick={() => setPeekTaskId(task.id)}
                                className={cn(
                                  'text-left text-sm font-medium text-foreground hover:text-primary hover:underline truncate max-w-full',
                                  isDone && 'line-through text-muted-foreground'
                                )}
                              >
                                {task.title}
                              </button>
                              <KindBadge kind={task.kind} />
                              <TaskStatusBadge status={task.status} compact />
                              {overdue && !isDone && (
                                <StatusBadge variant="expense">Terlambat</StatusBadge>
                              )}
                              {task.revision_count > 0 && (
                                <StatusBadge variant="warning">
                                  <RotateCcw className="h-3 w-3" strokeWidth={1.75} />
                                  Revisi {task.revision_count}x
                                </StatusBadge>
                              )}
                              {stagnant && (
                                <StatusBadge variant="warning">
                                  Macet {getStagnantDays(task)}h
                                </StatusBadge>
                              )}
                            </div>

                            <div className="flex flex-wrap items-center gap-3 text-xs text-muted-foreground">
                              {task.project_name && <span>{task.project_name}</span>}
                              {task.checklist_items.length > 0 && (
                                <span className="tabular-nums">
                                  Checklist{' '}
                                  {task.checklist_items.filter((c) => c.done).length}/
                                  {task.checklist_items.length}
                                </span>
                              )}
                              <div className="w-24">
                                <ProgressControl value={progress.percent} compact />
                              </div>
                            </div>

                            <div className="mt-1.5 flex flex-wrap items-center gap-1.5">
                              {!isDone && (
                                <button
                                  type="button"
                                  onClick={() => setFocusTaskId(task.id)}
                                  className={cn(
                                    'inline-flex items-center gap-1 rounded-md border px-2 py-0.5 text-[11px] font-medium transition-colors',
                                    focusTaskId === task.id
                                      ? 'border-primary bg-primary-subtle text-primary'
                                      : 'border-border bg-subtle/60 text-muted-foreground hover:border-primary/40 hover:text-primary'
                                  )}
                                >
                                  <Timer className="h-3 w-3" />
                                  <span>{focusTaskId === task.id ? 'Di Timer' : 'Fokus'}</span>
                                </button>
                              )}
                              <button
                                type="button"
                                onClick={() => void handleScheduleTaskFocusBlock(task)}
                                className="inline-flex items-center gap-1 rounded-md border border-border bg-subtle/60 px-2 py-0.5 text-[11px] font-medium text-muted-foreground hover:border-primary/40 hover:text-primary transition-colors"
                              >
                                <CalendarPlus className="h-3 w-3" />
                                <span>Jadwalkan</span>
                              </button>
                              <button
                                type="button"
                                onClick={() => {
                                  setTxPrefill({
                                    type: 'expense',
                                    note: `Biaya tugas: ${task.title}`,
                                    source: mapKindToTxSource(task.kind),
                                    projectId: task.project_id,
                                    linkTarget: { type: 'task', id: task.id },
                                  });
                                  setShowTxModal(true);
                                }}
                                className="inline-flex items-center gap-1 rounded-md border border-border bg-subtle/60 px-2 py-0.5 text-[11px] font-medium text-muted-foreground hover:border-primary/40 hover:text-primary transition-colors"
                              >
                                <Receipt className="h-3 w-3" />
                                <span>Biaya</span>
                              </button>
                            </div>
                          </div>
                        </div>

                        <div className="flex items-center gap-1.5 pl-11 sm:pl-0 shrink-0">
                          <select
                            aria-label={`Ubah status ${task.title}`}
                            value={task.status}
                            onChange={(e) =>
                              void handleRequestStatusChange(
                                task,
                                e.target.value as TaskStatus
                              )
                            }
                            className="h-9 rounded-md border border-border bg-surface px-2 text-xs text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
                          >
                            <option value="todo">Belum dikerjakan</option>
                            <option value="doing">Dikerjakan</option>
                            <option value="revisi">Revisi</option>
                            <option value="done">Selesai</option>
                          </select>
                          <Link
                            href={`/tugas?task=${task.id}`}
                            aria-label={`Buka ${task.title} di Papan Tugas`}
                            title="Buka di Papan Tugas"
                            className="inline-flex h-9 w-9 items-center justify-center rounded-md border border-border text-muted-foreground hover:bg-hover hover:text-foreground"
                          >
                            <ExternalLink className="h-3.5 w-3.5" strokeWidth={1.75} />
                          </Link>
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </CardContent>
          </Card>
        </div>

        {/* Kolom Kanan (5 kolom): Focus Timer, Ringkasan Uang & Perencanaan Interaktif */}
        <div className="lg:col-span-5 space-y-6">
          {!loading && (
            <InteractiveFocusTimerWidget
              workspaceId={workspaceId}
              activeTasks={activeWorkspaceTasks}
              selectedTaskId={focusTaskId}
              onSelectTaskId={setFocusTaskId}
              onLogged={() => void loadData()}
            />
          )}

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
                      {formatAmount(liquidBalance)}
                    </div>
                  </div>

                  {/* Arus Kas Hari Ini */}
                  <div className="grid grid-cols-2 gap-3">
                    <div className="rounded-lg border border-border bg-card p-3.5">
                      <span className="block text-xs font-medium text-muted-foreground">
                        Pemasukan Hari Ini
                      </span>
                      <div className="mt-1 text-base font-bold tabular-nums text-income">
                        +{formatAmount(todayIncome)}
                      </div>
                    </div>
                    <div className="rounded-lg border border-border bg-card p-3.5">
                      <span className="block text-xs font-medium text-muted-foreground">
                        Pengeluaran Hari Ini
                      </span>
                      <div className="mt-1 text-base font-bold tabular-nums text-expense">
                        -{formatAmount(todayExpense)}
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

          {!loading && (
            <InteractivePlanningPulseWidget
              workspaceId={workspaceId}
              budgets={detailedBudgets}
              bills={detailedBills}
              goals={savingsGoals}
              formatAmount={formatAmount}
              onMutated={() => void loadData()}
            />
          )}

          {/* Kartu Piutang Jatuh Tempo */}
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
                        {formatAmount(r.amount)} ·{' '}
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

      {/* Pengingat Cerdas & Ringkasan Mingguan (#6, #12) */}
      {!loading && !errorMessage && (
        <section
          aria-label="Pengingat Cerdas dan Ringkasan Mingguan"
          data-testid="hari-ini-smart-digest"
          className="grid grid-cols-1 lg:grid-cols-12 gap-6"
        >
          <Card className="lg:col-span-5">
            <CardHeader>
              <div className="flex items-center gap-2">
                <BellRing className="h-4 w-4 text-primary" aria-hidden="true" />
                <CardTitle>Pengingat Cerdas</CardTitle>
                <StatusBadge variant={smartAlerts.length > 0 ? 'warning' : 'neutral'}>
                  {smartAlerts.length}
                </StatusBadge>
              </div>
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={handleSendBrowserNotification}
              >
                <BellRing className="h-3.5 w-3.5" aria-hidden="true" />
                <span>Uji Notifikasi</span>
              </Button>
            </CardHeader>
            <CardContent className="space-y-3">
              {browserNotifFeedback && (
                <div className="rounded-md border border-border bg-subtle p-2.5 text-xs text-foreground">
                  {browserNotifFeedback}
                </div>
              )}

              {smartAlerts.length === 0 ? (
                <EmptyState
                  icon={<CheckCircle2 className="h-5 w-5 text-income" />}
                  title="Tidak ada peringatan mendesak"
                  description="Jadwal bebas bentrok, tugas macet nihil, serta anggaran dan tagihan masih aman."
                />
              ) : (
                <div className="space-y-2.5">
                  {smartAlerts.slice(0, 6).map((alert) => (
                    <div
                      key={alert.id}
                      className={cn(
                        'rounded-lg border p-3 flex items-start justify-between gap-3',
                        alert.severity === 'danger'
                          ? 'border-expense-border bg-expense-subtle'
                          : 'border-warning-border bg-warning-subtle'
                      )}
                    >
                      <div className="min-w-0 space-y-0.5">
                        <div className="text-xs font-semibold text-foreground">
                          {alert.title}
                        </div>
                        <div className="text-xs text-muted-foreground">
                          {privacyMode && typeof alert.amount === 'number'
                            ? 'Nominal disembunyikan oleh Mode Privasi.'
                            : alert.description}
                        </div>
                      </div>
                      <Link
                        href={alert.href}
                        className="shrink-0 text-xs font-medium text-primary hover:underline"
                      >
                        {alert.actionLabel}
                      </Link>
                    </div>
                  ))}
                </div>
              )}
            </CardContent>
          </Card>

          <Card className="lg:col-span-7">
            <CardHeader>
              <div className="flex items-center gap-2">
                <Sparkles className="h-4 w-4 text-primary" aria-hidden="true" />
                <CardTitle>Ringkasan Mingguan</CardTitle>
              </div>
              <span className="text-xs text-muted-foreground tabular-nums">
                {weeklyDigest.periodLabel}
              </span>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 text-xs">
                <div className="rounded-lg border border-border bg-subtle p-3.5 space-y-2">
                  <div className="font-semibold text-foreground uppercase tracking-wider text-[11px]">
                    7 Hari Terakhir
                  </div>
                  <div className="flex justify-between">
                    <span className="text-muted-foreground">Tugas Tuntas</span>
                    <strong className="text-foreground tabular-nums">
                      {weeklyDigest.past7Days.completedTasksCount}
                    </strong>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-muted-foreground">Pemasukan</span>
                    <strong className="text-income tabular-nums">
                      +{formatAmount(weeklyDigest.past7Days.incomeTotal)}
                    </strong>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-muted-foreground">Pengeluaran</span>
                    <strong className="text-expense tabular-nums">
                      -{formatAmount(weeklyDigest.past7Days.expenseTotal)}
                    </strong>
                  </div>
                  <div className="flex justify-between border-t border-border pt-1.5">
                    <span className="text-muted-foreground">Rasio Tabungan</span>
                    <strong className="text-primary tabular-nums">
                      {weeklyDigest.past7Days.savingsRatePercent !== null
                        ? `${weeklyDigest.past7Days.savingsRatePercent}%`
                        : '-'}
                    </strong>
                  </div>
                </div>

                <div className="rounded-lg border border-border bg-subtle p-3.5 space-y-2">
                  <div className="font-semibold text-foreground uppercase tracking-wider text-[11px]">
                    7 Hari Ke Depan
                  </div>
                  <div className="flex justify-between">
                    <span className="text-muted-foreground">Tugas Aktif (Terlambat)</span>
                    <strong className="text-foreground tabular-nums">
                      {weeklyDigest.next7Days.activeTasksCount} ({weeklyDigest.next7Days.overdueTasksCount})
                    </strong>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-muted-foreground">Tenggat &lt;= 7 Hari</span>
                    <strong className="text-foreground tabular-nums">
                      {weeklyDigest.next7Days.upcomingDueTasksCount}
                    </strong>
                  </div>
                  <div className="flex justify-between">
                    <span className="text-muted-foreground">Agenda Terjadwal</span>
                    <strong className="text-foreground tabular-nums">
                      {weeklyDigest.next7Days.upcomingEventsCount}
                    </strong>
                  </div>
                  <div className="flex justify-between border-t border-border pt-1.5">
                    <span className="text-muted-foreground">Tagihan Mendatang</span>
                    <strong className="text-warning tabular-nums">
                      {weeklyDigest.next7Days.upcomingBillsCount} (
                      {formatAmount(weeklyDigest.next7Days.upcomingBillsTotal)})
                    </strong>
                  </div>
                </div>
              </div>

              <div className="flex flex-wrap items-center gap-2">
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={handleCopyWeeklyDigest}
                >
                  <Copy className="h-3.5 w-3.5" aria-hidden="true" />
                  <span>{digestCopied ? 'Ringkasan Disalin' : 'Salin Ringkasan'}</span>
                </Button>
                <a
                  href={weeklyDigest.mailtoHref}
                  className="min-h-[36px] inline-flex items-center gap-1.5 rounded-md border border-border bg-card px-3 py-1.5 text-xs font-medium text-foreground hover:bg-hover transition-colors"
                >
                  <Mail className="h-3.5 w-3.5 text-primary" aria-hidden="true" />
                  <span>Kirim Ringkasan Email</span>
                </a>
                <Link
                  href="/pengaturan"
                  className="text-xs font-medium text-primary hover:underline ml-auto"
                >
                  Atur Pengingat
                </Link>
              </div>
            </CardContent>
          </Card>
        </section>
      )}

      {/* Side Peek 480px untuk melihat & mengedit detail tugas langsung dari Hari Ini */}
      {workspaceId && (
        <DetailPeek
          open={Boolean(activePeekTask)}
          task={activePeekTask}
          allTasks={workspaceTasks}
          workspaceId={workspaceId}
          projects={projects}
          payments={payments}
          onClose={() => setPeekTaskId(null)}
          onSelectTask={(nextId) => setPeekTaskId(nextId)}
          onTaskUpdated={(updated) => {
            setWorkspaceTasks((prev) =>
              prev.map((item) => (item.id === updated.id ? updated : item))
            );
          }}
          onTaskCreated={(created) => {
            setWorkspaceTasks((prev) => [...prev, created]);
          }}
          onTaskDeleted={(deletedId) => {
            setWorkspaceTasks((prev) => prev.filter((item) => item.id !== deletedId));
            setPeekTaskId(null);
          }}
          onChangeStatus={(task, toStatus) => handleRequestStatusChange(task, toStatus)}
        />
      )}

      {/* Dialog Revisi Wajib Catatan */}
      <RevisionDialog
        open={Boolean(pendingRevision)}
        task={pendingRevision?.task ?? null}
        submitting={revisionSubmitting}
        onClose={() => {
          if (!revisionSubmitting) {
            setPendingRevision(null);
          }
        }}
        onConfirm={handleConfirmRevision}
      />

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
            <label
              htmlFor="milestone-acc-select"
              className="mb-1.5 block text-xs font-medium text-foreground"
            >
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
              onClick={() => void handleConfirmMilestonePayment()}
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
            <label
              htmlFor="quick-task-title"
              className="mb-1.5 block text-xs font-medium text-foreground"
            >
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
              <label
                htmlFor="quick-task-kind"
                className="mb-1.5 block text-xs font-medium text-foreground"
              >
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
              <label
                htmlFor="quick-task-priority"
                className="mb-1.5 block text-xs font-medium text-foreground"
              >
                Prioritas
              </label>
              <Select
                id="quick-task-priority"
                value={newTaskPriority}
                onChange={(e) => setNewTaskPriority(e.target.value as TaskPriority)}
              >
                <option value="rendah">Rendah</option>
                <option value="sedang">Sedang</option>
                <option value="tinggi">Tinggi</option>
              </Select>
            </div>
          </div>

          <div className="flex justify-end gap-2 border-t border-border pt-3">
            <Button
              type="button"
              variant="outline"
              onClick={() => setShowQuickTaskModal(false)}
            >
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
        onClose={() => {
          setShowTxModal(false);
          setTxPrefill(null);
        }}
        workspaceId={workspaceId}
        initialAccounts={accounts}
        prefill={txPrefill}
        onSuccess={() => void loadData()}
      />
    </div>
  );
}
