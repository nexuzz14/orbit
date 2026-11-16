'use client';

import { useEffect, useState, useCallback, useMemo } from 'react';
import { createClient } from '@/lib/supabase/client';
import { formatDateIndo } from '@/lib/format';
import { exportProjectReportToCsv } from '@/lib/finance-v2';
import { usePrivacyMode } from '@/lib/privacy-mode';
import { RealtimeStatusBadge, useOrbitRealtime } from '@/lib/use-orbit-realtime';
import type { ActivityKind, ProjectStatus, FeeMode } from '@/types/database';
import {
  AlertTriangle,
  Briefcase,
  CalendarRange,
  CheckCircle2,
  Clock,
  Download,
  Edit2,
  Layers,
  Plus,
  Printer,
  Trash2,
  TrendingUp,
  Users,
} from 'lucide-react';
import {
  Card,
  CardHeader,
  CardTitle,
  CardContent,
  Button,
  Input,
  Select,
  Dialog,
  KindBadge,
  StatusBadge,
  Skeleton,
  EmptyState,
  ErrorState,
  LainnyaSubNav,
  ViewSwitcher,
  ACTIVITY_KIND_META,
  cn,
} from '@/components/ui';

type ProjectRow = {
  id: string;
  workspace_id: string;
  kind: ActivityKind;
  name: string;
  description: string | null;
  status: ProjectStatus;
  started_on: string | null;
  deadline: string | null;
  color: string | null;
  tags: string[];
  client_name: string | null;
  contract_value: number | null;
  currency: string | null;
  platform_fee_percent: number | null;
  fee_mode: FeeMode | null;
  semester: number | null;
  course_code: string | null;
  credits: number | null;
  stipend_amount: number | null;
  stipend_day: number | null;
};

type PaymentRow = {
  id: string;
  project_id: string;
  label: string;
  amount: number;
  due_date: string | null;
  status: 'pending' | 'partial' | 'paid' | 'overdue';
  paid_amount: number;
  paid_at: string | null;
  account_id: string | null;
};

type ProjectProfitRow = {
  project_id: string;
  project_name: string;
  kind: ActivityKind;
  client_name: string | null;
  status: ProjectStatus;
  contract_value: number | null;
  currency: string | null;
  total_invoiced: number;
  total_paid: number;
  total_expense: number;
  platform_fee_deducted: number;
  net_profit: number;
  margin_percent: number;
  remaining_invoiced: number;
};

type ReceivableRow = {
  payment_id: string;
  project_id: string;
  project_name: string;
  client_name: string | null;
  label: string;
  amount: number;
  paid_amount: number;
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

type ProjectTaskItem = {
  id: string;
  title: string;
  project_id: string | null;
  status: string;
  due_at: string | null;
  estimate_minutes: number | null;
  progress_percent: number;
  assignee_id: string | null;
  created_at: string;
};

type ProjectTransactionItem = {
  id: string;
  project_id: string | null;
  type: 'income' | 'expense' | 'transfer';
  amount_base: number;
  status: string;
};

type WorkspaceMemberProfile = {
  user_id: string;
  role: string;
  display_name: string;
};

type ProyekTab = 'projects' | 'gantt' | 'workload' | 'finances';

export default function ProyekPage() {
  const supabase = createClient();
  const { formatAmount } = usePrivacyMode();
  const [workspaceId, setWorkspaceId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);

  const [activeTab, setActiveTab] = useState<ProyekTab>('projects');
  const [filterKind, setFilterKind] = useState<ActivityKind | 'all'>('all');
  const [ganttZoom, setGanttZoom] = useState<'week' | 'month'>('month');

  const [projects, setProjects] = useState<ProjectRow[]>([]);
  const [profitData, setProfitData] = useState<ProjectProfitRow[]>([]);
  const [receivables, setReceivables] = useState<ReceivableRow[]>([]);
  const [accounts, setAccounts] = useState<AccountItem[]>([]);
  const [projectTasks, setProjectTasks] = useState<ProjectTaskItem[]>([]);
  const [allPayments, setAllPayments] = useState<PaymentRow[]>([]);
  const [projectTransactions, setProjectTransactions] = useState<ProjectTransactionItem[]>([]);
  const [members, setMembers] = useState<WorkspaceMemberProfile[]>([]);

  const [showProjectModal, setShowProjectModal] = useState(false);
  const [modalMode, setModalMode] = useState<'create' | 'edit'>('create');
  const [editingProjectId, setEditingProjectId] = useState<string | null>(null);

  const [formKind, setFormKind] = useState<ActivityKind>('freelance');
  const [formName, setFormName] = useState('');
  const [formDescription, setFormDescription] = useState('');
  const [formStatus, setFormStatus] = useState<ProjectStatus>('berjalan');
  const [formStartedOn, setFormStartedOn] = useState('');
  const [formDeadline, setFormDeadline] = useState('');
  const [formColor, setFormColor] = useState('#0284c7');

  const [formClientName, setFormClientName] = useState('');
  const [formContractValue, setFormContractValue] = useState('');
  const [formCurrency, setFormCurrency] = useState('IDR');
  const [formFeePercent, setFormFeePercent] = useState('0');
  const [formFeeMode, setFormFeeMode] = useState<FeeMode>('expense_transaction');

  const [formSemester, setFormSemester] = useState('1');
  const [formCourseCode, setFormCourseCode] = useState('');
  const [formCredits, setFormCredits] = useState('3');

  const [formStipendAmount, setFormStipendAmount] = useState('');
  const [formStipendDay, setFormStipendDay] = useState('25');

  const [savingProject, setSavingProject] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  const [selectedProjectForPayments, setSelectedProjectForPayments] = useState<ProjectRow | null>(null);
  const [projectPayments, setProjectPayments] = useState<PaymentRow[]>([]);
  const [showAddMilestoneModal, setShowAddMilestoneModal] = useState(false);
  const [milestoneLabel, setMilestoneLabel] = useState('');
  const [milestoneAmount, setMilestoneAmount] = useState('');
  const [milestoneDueDate, setMilestoneDueDate] = useState('');
  const [savingMilestone, setSavingMilestone] = useState(false);

  const [payingMilestoneId, setPayingMilestoneId] = useState<string | null>(null);
  const [payAccountId, setPayAccountId] = useState('');
  const [processingPayment, setProcessingPayment] = useState(false);

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

      const { data: accData } = await supabase
        .from('accounts')
        .select('id, name')
        .eq('workspace_id', wsId)
        .is('deleted_at', null)
        .order('sort_order');

      if (accData) {
        setAccounts(accData);
        if (accData.length > 0 && !payAccountId) {
          setPayAccountId(accData[0].id);
        }
      }

      const { data: projData, error: projErr } = await supabase
        .from('projects')
        .select('*')
        .eq('workspace_id', wsId)
        .is('deleted_at', null)
        .order('created_at', { ascending: false });

      if (projErr) throw projErr;
      if (projData) {
        setProjects(projData as unknown as ProjectRow[]);
      }

      const { data: profitRows } = await supabase
        .from('v_project_profit')
        .select('*')
        .eq('workspace_id', wsId);

      if (profitRows) {
        setProfitData(profitRows as unknown as ProjectProfitRow[]);
      }

      const { data: recRows } = await supabase
        .from('v_receivables')
        .select('*')
        .eq('workspace_id', wsId)
        .order('due_date', { ascending: true });

      if (recRows) {
        setReceivables(recRows as unknown as ReceivableRow[]);
      }

      const [tasksRes, paymentsRes, txRes, membersRes] = await Promise.all([
        supabase
          .from('tasks')
          .select('id, title, project_id, status, due_at, estimate_minutes, progress_percent, assignee_id, created_at')
          .eq('workspace_id', wsId)
          .is('deleted_at', null),
        supabase
          .from('project_payments')
          .select('id, project_id, label, amount, due_date, status, paid_amount, paid_at, account_id')
          .eq('workspace_id', wsId)
          .is('deleted_at', null),
        supabase
          .from('transactions')
          .select('id, project_id, type, amount_base, status')
          .eq('workspace_id', wsId)
          .not('project_id', 'is', null)
          .is('deleted_at', null),
        supabase
          .from('workspace_members')
          .select('user_id, role')
          .eq('workspace_id', wsId),
      ]);

      setProjectTasks((tasksRes.data as unknown as ProjectTaskItem[]) ?? []);
      setAllPayments((paymentsRes.data as unknown as PaymentRow[]) ?? []);
      setProjectTransactions((txRes.data as unknown as ProjectTransactionItem[]) ?? []);

      const memberRows = (membersRes.data as Array<{ user_id: string; role: string }>) ?? [];
      if (memberRows.length > 0) {
        const { data: profData } = await supabase
          .from('profiles')
          .select('id, display_name')
          .in(
            'id',
            memberRows.map((m) => m.user_id)
          );
        const nameMap = new Map<string, string>();
        for (const prof of profData ?? []) {
          if (prof.display_name) nameMap.set(prof.id, prof.display_name);
        }
        setMembers(
          memberRows.map((m) => ({
            user_id: m.user_id,
            role: m.role,
            display_name: nameMap.get(m.user_id) || `Anggota ${m.user_id.slice(0, 6)}`,
          }))
        );
      } else {
        setMembers([]);
      }
    } catch (err: unknown) {
      setLoadError(err instanceof Error ? err.message : 'Gagal memuat daftar kegiatan dan piutang.');
    } finally {
      setLoading(false);
    }
  }, [supabase, payAccountId]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  const { status: realtimeStatus } = useOrbitRealtime({
    workspaceId,
    tables: ['tasks', 'project_payments', 'transactions'],
    onChange: loadData,
  });

  const loadProjectPayments = async (projId: string) => {
    const { data } = await supabase
      .from('project_payments')
      .select('*')
      .eq('project_id', projId)
      .is('deleted_at', null)
      .order('due_date', { ascending: true });

    if (data) {
      setProjectPayments(data as unknown as PaymentRow[]);
    }
  };

  const openPaymentsModal = (proj: ProjectRow) => {
    setSelectedProjectForPayments(proj);
    loadProjectPayments(proj.id);
  };

  const resetForm = () => {
    setFormKind('freelance');
    setFormName('');
    setFormDescription('');
    setFormStatus('berjalan');
    setFormStartedOn('');
    setFormDeadline('');
    setFormColor('#0284c7');
    setFormClientName('');
    setFormContractValue('');
    setFormCurrency('IDR');
    setFormFeePercent('0');
    setFormFeeMode('expense_transaction');
    setFormSemester('1');
    setFormCourseCode('');
    setFormCredits('3');
    setFormStipendAmount('');
    setFormStipendDay('25');
    setFormError(null);
  };

  const openCreateModal = () => {
    resetForm();
    setModalMode('create');
    setShowProjectModal(true);
  };

  const openEditModal = (proj: ProjectRow) => {
    setModalMode('edit');
    setEditingProjectId(proj.id);
    setFormKind(proj.kind);
    setFormName(proj.name);
    setFormDescription(proj.description || '');
    setFormStatus(proj.status);
    setFormStartedOn(proj.started_on || '');
    setFormDeadline(proj.deadline || '');
    setFormColor(proj.color || '#0284c7');

    setFormClientName(proj.client_name || '');
    setFormContractValue(proj.contract_value ? String(proj.contract_value) : '');
    setFormCurrency(proj.currency || 'IDR');
    setFormFeePercent(proj.platform_fee_percent ? String(proj.platform_fee_percent) : '0');
    setFormFeeMode(proj.fee_mode || 'expense_transaction');

    setFormSemester(proj.semester ? String(proj.semester) : '1');
    setFormCourseCode(proj.course_code || '');
    setFormCredits(proj.credits ? String(proj.credits) : '3');

    setFormStipendAmount(proj.stipend_amount ? String(proj.stipend_amount) : '');
    setFormStipendDay(proj.stipend_day ? String(proj.stipend_day) : '25');

    setFormError(null);
    setShowProjectModal(true);
  };

  const handleSaveProject = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!workspaceId) return;
    setFormError(null);
    setSavingProject(true);

    const baseData = {
      name: formName.trim(),
      kind: formKind,
      description: formDescription.trim() || null,
      status: formStatus,
      started_on: formStartedOn || null,
      deadline: formDeadline || null,
      color: formColor,
      client_name: null as string | null,
      contract_value: null as number | null,
      currency: null as string | null,
      platform_fee_percent: null as number | null,
      fee_mode: null as FeeMode | null,
      semester: null as number | null,
      course_code: null as string | null,
      credits: null as number | null,
      stipend_amount: null as number | null,
      stipend_day: null as number | null,
    };

    if (formKind === 'freelance') {
      const val = parseFloat(formContractValue);
      if (isNaN(val) || val < 0) {
        setFormError('Nilai kontrak proyek freelance harus berupa angka non-negatif.');
        setSavingProject(false);
        return;
      }
      baseData.client_name = formClientName.trim() || null;
      baseData.contract_value = val;
      baseData.currency = formCurrency;
      const fee = parseFloat(formFeePercent);
      baseData.platform_fee_percent = isNaN(fee) ? 0 : fee;
      baseData.fee_mode = formFeeMode;
    } else if (formKind === 'kuliah') {
      baseData.semester = parseInt(formSemester, 10) || null;
      baseData.course_code = formCourseCode.trim() || null;
      baseData.credits = parseInt(formCredits, 10) || null;
    } else if (formKind === 'intern') {
      baseData.client_name = formClientName.trim() || null;
      if (formStipendAmount) {
        const stipend = parseFloat(formStipendAmount);
        if (!isNaN(stipend) && stipend > 0) {
          baseData.stipend_amount = stipend;
          baseData.stipend_day = parseInt(formStipendDay, 10) || 25;
        }
      }
    }

    if (modalMode === 'create') {
      const { error } = await supabase.from('projects').insert({
        workspace_id: workspaceId,
        ...baseData,
      });

      if (error) {
        setFormError(error.message);
        setSavingProject(false);
        return;
      }
    } else if (modalMode === 'edit' && editingProjectId) {
      const { error } = await supabase
        .from('projects')
        .update(baseData)
        .eq('id', editingProjectId);

      if (error) {
        setFormError(error.message);
        setSavingProject(false);
        return;
      }
    }

    setSavingProject(false);
    setShowProjectModal(false);
    loadData();
  };

  const handleDeleteProject = async (projId: string) => {
    if (!confirm('Apakah Anda yakin ingin menghapus kegiatan ini?')) return;
    await supabase.from('projects').update({ deleted_at: new Date().toISOString() }).eq('id', projId);
    loadData();
  };

  const handleAddMilestone = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!workspaceId || !selectedProjectForPayments) return;

    const amt = parseFloat(milestoneAmount);
    if (isNaN(amt) || amt <= 0) {
      alert('Nominal harus lebih besar dari 0.');
      return;
    }

    setSavingMilestone(true);
    const { error } = await supabase.from('project_payments').insert({
      workspace_id: workspaceId,
      project_id: selectedProjectForPayments.id,
      label: milestoneLabel.trim(),
      amount: amt,
      due_date: milestoneDueDate || null,
      status: 'pending',
    });

    setSavingMilestone(false);
    if (!error) {
      setMilestoneLabel('');
      setMilestoneAmount('');
      setMilestoneDueDate('');
      setShowAddMilestoneModal(false);
      loadProjectPayments(selectedProjectForPayments.id);
      loadData();
    }
  };

  const handleMarkPaymentPaid = async (paymentId: string) => {
    if (!payAccountId) {
      alert('Pilih akun penerima terlebih dahulu.');
      return;
    }
    setProcessingPayment(true);
    const { error } = await supabase.rpc('fn_mark_payment_paid', {
      p_payment_id: paymentId,
      p_account_id: payAccountId,
    });
    setProcessingPayment(false);
    setPayingMilestoneId(null);
    if (!error) {
      if (selectedProjectForPayments) {
        loadProjectPayments(selectedProjectForPayments.id);
      }
      loadData();
    }
  };

  const handleCancelPaymentPaid = async (paymentId: string) => {
    if (!confirm('Batalkan status lunas? Transaksi pemasukan terkait akan dibatalkan.')) return;
    setProcessingPayment(true);
    const { error } = await supabase.rpc('fn_mark_payment_paid', {
      p_payment_id: paymentId,
      p_account_id: undefined,
    });
    setProcessingPayment(false);
    if (!error) {
      if (selectedProjectForPayments) {
        loadProjectPayments(selectedProjectForPayments.id);
      }
      loadData();
    }
  };

  const filteredProjects = useMemo(
    () => projects.filter((p) => (filterKind === 'all' ? true : p.kind === filterKind)),
    [projects, filterKind]
  );

  const taskStatsByProject = useMemo(() => {
    const map = new Map<
      string,
      { total: number; done: number; activeEstimateMin: number; tasks: ProjectTaskItem[] }
    >();
    for (const t of projectTasks) {
      if (!t.project_id) continue;
      const cur = map.get(t.project_id) ?? {
        total: 0,
        done: 0,
        activeEstimateMin: 0,
        tasks: [],
      };
      cur.total += 1;
      if (t.status === 'done') {
        cur.done += 1;
      } else {
        cur.activeEstimateMin += Number(t.estimate_minutes ?? 0);
      }
      cur.tasks.push(t);
      map.set(t.project_id, cur);
    }
    return map;
  }, [projectTasks]);

  const ganttRange = useMemo(() => {
    const now = new Date();
    if (ganttZoom === 'week') {
      const start = new Date(now.getTime() - 3 * 86400_000);
      const end = new Date(now.getTime() + 27 * 86400_000);
      return { start, end, totalMs: Math.max(86400_000, end.getTime() - start.getTime()) };
    }

    let minMs = now.getTime() - 14 * 86400_000;
    let maxMs = now.getTime() + 60 * 86400_000;
    for (const p of projects) {
      if (p.started_on) minMs = Math.min(minMs, new Date(p.started_on).getTime());
      if (p.deadline) maxMs = Math.max(maxMs, new Date(p.deadline).getTime());
    }
    const start = new Date(minMs);
    const end = new Date(Math.max(maxMs, minMs + 30 * 86400_000));
    return { start, end, totalMs: Math.max(86400_000, end.getTime() - start.getTime()) };
  }, [projects, ganttZoom]);

  const workloadByAssignee = useMemo(() => {
    const memberMap = new Map(members.map((m) => [m.user_id, m]));
    const nowMs = Date.now();
    const weekHorizonMs = nowMs + 7 * 86400_000;

    type AssigneeBucket = {
      key: string;
      label: string;
      role: string;
      activeTasks: number;
      doneTasks: number;
      totalEstimateMin: number;
      weeklyEstimateMin: number;
      dailyBuckets: Map<string, number>;
    };

    const buckets = new Map<string, AssigneeBucket>();
    for (const m of members) {
      buckets.set(m.user_id, {
        key: m.user_id,
        label: m.display_name,
        role: m.role,
        activeTasks: 0,
        doneTasks: 0,
        totalEstimateMin: 0,
        weeklyEstimateMin: 0,
        dailyBuckets: new Map(),
      });
    }

    for (const t of projectTasks) {
      const key = t.assignee_id || 'unassigned';
      let bucket = buckets.get(key);
      if (!bucket) {
        const mem = t.assignee_id ? memberMap.get(t.assignee_id) : undefined;
        bucket = {
          key,
          label: mem?.display_name || (t.assignee_id ? `Anggota ${t.assignee_id.slice(0, 6)}` : 'Belum Ditugaskan'),
          role: mem?.role || '-',
          activeTasks: 0,
          doneTasks: 0,
          totalEstimateMin: 0,
          weeklyEstimateMin: 0,
          dailyBuckets: new Map(),
        };
        buckets.set(key, bucket);
      }

      if (t.status === 'done') {
        bucket.doneTasks += 1;
        continue;
      }

      const est = Number(t.estimate_minutes ?? 0);
      bucket.activeTasks += 1;
      bucket.totalEstimateMin += est;

      if (t.due_at) {
        const dueMs = new Date(t.due_at).getTime();
        if (dueMs <= weekHorizonMs) {
          bucket.weeklyEstimateMin += est;
        }
        const dayKey = t.due_at.slice(0, 10);
        bucket.dailyBuckets.set(dayKey, (bucket.dailyBuckets.get(dayKey) ?? 0) + est);
      } else {
        bucket.weeklyEstimateMin += est;
      }
    }

    return Array.from(buckets.values())
      .map((b) => {
        const peakDailyMin = Math.max(0, ...Array.from(b.dailyBuckets.values()));
        const isOverloaded = b.weeklyEstimateMin > 40 * 60 || peakDailyMin > 8 * 60;
        const isHeavy = !isOverloaded && (b.weeklyEstimateMin > 25 * 60 || peakDailyMin > 6 * 60);
        return {
          ...b,
          peakDailyMin,
          isOverloaded,
          isHeavy,
        };
      })
      .sort((a, b) => b.totalEstimateMin - a.totalEstimateMin || b.activeTasks - a.activeTasks);
  }, [projectTasks, members]);

  const projectFinancialReports = useMemo(() => {
    const profitMap = new Map(profitData.map((pr) => [pr.project_id, pr]));

    return projects.map((p) => {
      const vp = profitMap.get(p.id);
      const pPayments = allPayments.filter((pm) => pm.project_id === p.id);
      const pTxns = projectTransactions.filter((tx) => tx.project_id === p.id && tx.status === 'confirmed');

      const paymentInvoiced = pPayments.reduce((acc, pm) => acc + Number(pm.amount || 0), 0);
      const paymentPaid = pPayments.reduce((acc, pm) => acc + Number(pm.paid_amount || 0), 0);
      const txIncome = pTxns
        .filter((tx) => tx.type === 'income')
        .reduce((acc, tx) => acc + Number(tx.amount_base || 0), 0);
      const txExpense = pTxns
        .filter((tx) => tx.type === 'expense')
        .reduce((acc, tx) => acc + Number(tx.amount_base || 0), 0);

      const contractValue = Number(vp?.contract_value ?? p.contract_value ?? 0);
      const totalInvoiced = Number(vp?.total_invoiced ?? paymentInvoiced);
      const totalPaid = Number(vp?.total_paid ?? (paymentPaid > 0 ? paymentPaid : txIncome));
      const remainingInvoiced = Number(
        vp?.remaining_invoiced ?? Math.max(0, totalInvoiced - totalPaid)
      );
      const totalExpense =
        Number(vp?.total_expense ?? txExpense) + Number(vp?.platform_fee_deducted ?? 0);
      const netProfit = vp ? Number(vp.net_profit) : totalPaid - totalExpense;
      const marginPercent =
        vp?.margin_percent !== undefined && vp?.margin_percent !== null
          ? Number(vp.margin_percent)
          : totalPaid > 0
          ? Math.round((netProfit / totalPaid) * 1000) / 10
          : 0;

      return {
        project_id: p.id,
        project_name: p.name,
        kind: p.kind,
        client_name: p.client_name,
        status: p.status,
        currency: p.currency || vp?.currency || 'IDR',
        contract_value: contractValue,
        total_invoiced: totalInvoiced,
        total_paid: totalPaid,
        remaining_invoiced: remainingInvoiced,
        total_expense: totalExpense,
        net_profit: netProfit,
        margin_percent: marginPercent,
      };
    });
  }, [projects, profitData, allPayments, projectTransactions]);

  const handleExportProjectReportCsv = () => {
    const csv = exportProjectReportToCsv(
      projectFinancialReports.map((r) => ({
        project_name: r.project_name,
        kind: ACTIVITY_KIND_META[r.kind]?.label || r.kind,
        client_name: r.client_name,
        status: r.status,
        currency: r.currency,
        contract_value: r.contract_value,
        total_invoiced: r.total_invoiced,
        total_paid: r.total_paid,
        remaining_invoiced: r.remaining_invoiced,
        total_expense: r.total_expense,
        net_profit: r.net_profit,
        margin_percent: r.margin_percent,
      }))
    );
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `orbit-laporan-proyek-${new Date().toISOString().slice(0, 10)}.csv`;
    document.body.appendChild(link);
    link.click();
    link.remove();
    URL.revokeObjectURL(url);
  };

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2.5 flex-wrap">
            <h1 className="text-2xl font-bold tracking-tight text-foreground">Lainnya</h1>
            <RealtimeStatusBadge status={realtimeStatus} />
          </div>
          <p className="text-sm text-muted-foreground mt-0.5">
            Daftar kegiatan, linimasa Gantt, beban kerja anggota, serta laporan margin &amp; piutang
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2 print:hidden">
          {activeTab === 'finances' && (
            <>
              <Button
                variant="secondary"
                onClick={handleExportProjectReportCsv}
                disabled={projectFinancialReports.length === 0}
              >
                <Download className="w-4 h-4" />
                <span>Ekspor CSV</span>
              </Button>
              <Button variant="secondary" onClick={() => window.print()}>
                <Printer className="w-4 h-4" />
                <span>Cetak PDF</span>
              </Button>
            </>
          )}
          <Button onClick={openCreateModal}>
            <Plus className="w-4 h-4" />
            <span>Tambah Kegiatan</span>
          </Button>
        </div>
      </div>

      <LainnyaSubNav />

      <ViewSwitcher<ProyekTab>
        ariaLabel="Sub-menu Proyek dan Kegiatan"
        value={activeTab}
        onChange={setActiveTab}
        options={[
          { value: 'projects', label: 'Daftar Proyek', badge: projects.length },
          { value: 'gantt', label: 'Linimasa Gantt' },
          { value: 'workload', label: 'Beban Kerja' },
          { value: 'finances', label: 'Laporan & Piutang', badge: receivables.length },
        ]}
        rightSlot={
          activeTab === 'gantt' ? (
            <div className="inline-flex rounded-md border border-border bg-subtle p-0.5">
              <button
                type="button"
                onClick={() => setGanttZoom('week')}
                className={cn(
                  'min-h-11 px-3 rounded-sm text-xs font-medium transition-colors',
                  ganttZoom === 'week'
                    ? 'bg-card text-primary border border-border shadow-card font-semibold'
                    : 'text-muted-foreground hover:text-foreground'
                )}
              >
                Mingguan (30H)
              </button>
              <button
                type="button"
                onClick={() => setGanttZoom('month')}
                className={cn(
                  'min-h-11 px-3 rounded-sm text-xs font-medium transition-colors',
                  ganttZoom === 'month'
                    ? 'bg-card text-primary border border-border shadow-card font-semibold'
                    : 'text-muted-foreground hover:text-foreground'
                )}
              >
                Bulanan
              </button>
            </div>
          ) : undefined
        }
      />

      {activeTab === 'projects' && (
        <div className="flex items-center gap-1.5 overflow-x-auto pb-1 print:hidden">
          <button
            type="button"
            onClick={() => setFilterKind('all')}
            className={cn(
              'min-h-11 px-3.5 py-2 rounded-md text-xs font-medium transition-colors border shrink-0',
              filterKind === 'all'
                ? 'bg-primary text-primary-foreground border-primary'
                : 'bg-card text-muted-foreground border-border hover:text-foreground hover:bg-hover'
            )}
          >
            Semua
          </button>
          {(['intern', 'freelance', 'kuliah', 'pribadi'] as ActivityKind[]).map((k) => (
            <button
              key={k}
              type="button"
              onClick={() => setFilterKind(k)}
              className={cn(
                'min-h-11 px-3.5 py-2 rounded-md text-xs font-medium transition-colors border shrink-0',
                filterKind === k
                  ? 'bg-primary text-primary-foreground border-primary'
                  : 'bg-card text-muted-foreground border-border hover:text-foreground hover:bg-hover'
              )}
            >
              {ACTIVITY_KIND_META[k].label}
            </button>
          ))}
        </div>
      )}

      {loadError ? (
        <ErrorState message={loadError} onRetry={loadData} />
      ) : loading ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4" aria-busy="true">
          <Skeleton className="h-48 w-full" />
          <Skeleton className="h-48 w-full" />
          <Skeleton className="h-48 w-full" />
        </div>
      ) : activeTab === 'projects' ? (
        filteredProjects.length === 0 ? (
          <EmptyState
            icon={<Briefcase className="w-5 h-5" />}
            title="Belum ada kegiatan terdaftar"
            description="Tambahkan proyek freelance, magang, atau mata kuliah untuk menghubungkan jadwal, tugas, dan transaksi."
            actionLabel="Tambah Kegiatan"
            onAction={openCreateModal}
          />
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {filteredProjects.map((p) => {
              const profitInfo = profitData.find((pr) => pr.project_id === p.id);
              const tStat = taskStatsByProject.get(p.id);
              const taskDonePct =
                tStat && tStat.total > 0 ? Math.round((tStat.done / tStat.total) * 100) : 0;
              const contractPct =
                p.contract_value && p.contract_value > 0 && profitInfo
                  ? Math.min(100, Math.round((profitInfo.total_paid / p.contract_value) * 100))
                  : null;

              return (
                <Card key={p.id} className="flex flex-col justify-between">
                  <CardContent className="p-5 flex flex-col justify-between h-full space-y-4">
                    <div className="space-y-3">
                      <div className="flex items-center justify-between gap-2">
                        <KindBadge kind={p.kind} />
                        <div className="flex items-center gap-1">
                          <Button
                            type="button"
                            variant="ghost"
                            size="icon"
                            onClick={() => openEditModal(p)}
                            aria-label={`Ubah ${p.name}`}
                          >
                            <Edit2 className="w-4 h-4" />
                          </Button>
                          <Button
                            type="button"
                            variant="ghost"
                            size="icon"
                            onClick={() => handleDeleteProject(p.id)}
                            aria-label={`Hapus ${p.name}`}
                          >
                            <Trash2 className="w-4 h-4 text-muted-foreground hover:text-expense" />
                          </Button>
                        </div>
                      </div>

                      <div>
                        <h3 className="font-semibold text-base text-foreground tracking-tight">
                          {p.name}
                        </h3>
                        {p.client_name && (
                          <div className="text-xs text-muted-foreground mt-0.5">
                            {p.kind === 'intern' ? 'Instansi' : 'Klien'}: {p.client_name}
                          </div>
                        )}
                        {p.description && (
                          <p className="text-xs text-muted-foreground mt-1 line-clamp-2">
                            {p.description}
                          </p>
                        )}
                      </div>

                      {/* Progress Tugas Proyek */}
                      <div className="rounded-md bg-subtle border border-border p-3 space-y-1.5 text-xs">
                        <div className="flex items-center justify-between">
                          <span className="text-muted-foreground">Progres Tugas</span>
                          <span className="font-semibold text-foreground tabular-nums">
                            {tStat ? `${tStat.done}/${tStat.total} (${taskDonePct}%)` : '0/0'}
                          </span>
                        </div>
                        <div className="h-2 w-full rounded-full bg-card border border-border overflow-hidden">
                          <div
                            className="h-full bg-primary transition-all duration-150"
                            style={{ width: `${taskDonePct}%` }}
                          />
                        </div>
                      </div>

                      {p.kind === 'freelance' && (
                        <div className="p-3 rounded-md bg-subtle border border-border text-xs space-y-1.5 tabular-nums">
                          <div className="flex justify-between">
                            <span className="text-muted-foreground">Nilai Kontrak:</span>
                            <span className="font-semibold text-foreground">
                              {p.contract_value ? formatAmount(p.contract_value) : '-'}
                            </span>
                          </div>
                          {profitInfo && (
                            <>
                              <div className="flex justify-between">
                                <span className="text-muted-foreground">Dibayar:</span>
                                <span className="font-semibold text-income">
                                  {formatAmount(profitInfo.total_paid)}
                                </span>
                              </div>
                              <div className="flex justify-between">
                                <span className="text-muted-foreground">Profit Bersih:</span>
                                <span className="font-semibold text-foreground">
                                  {formatAmount(profitInfo.net_profit)} ({profitInfo.margin_percent}%)
                                </span>
                              </div>
                              {contractPct !== null && (
                                <div className="h-1.5 w-full rounded-full bg-card border border-border overflow-hidden">
                                  <div
                                    className="h-full bg-income"
                                    style={{ width: `${contractPct}%` }}
                                  />
                                </div>
                              )}
                            </>
                          )}
                        </div>
                      )}

                      {p.kind === 'kuliah' && (
                        <div className="p-3 rounded-md bg-subtle border border-border text-xs space-y-1 tabular-nums">
                          <div className="flex justify-between">
                            <span className="text-muted-foreground">Semester:</span>
                            <span className="font-semibold text-foreground">{p.semester || '-'}</span>
                          </div>
                          <div className="flex justify-between">
                            <span className="text-muted-foreground">Kode &amp; SKS:</span>
                            <span className="font-semibold text-foreground">
                              {p.course_code || '-'} ({p.credits || 0} SKS)
                            </span>
                          </div>
                        </div>
                      )}

                      {p.kind === 'intern' && (
                        <div className="p-3 rounded-md bg-subtle border border-border text-xs space-y-1 tabular-nums">
                          <div className="flex justify-between">
                            <span className="text-muted-foreground">Uang Saku:</span>
                            <span className="font-semibold text-foreground">
                              {p.stipend_amount ? formatAmount(p.stipend_amount) : '-'}
                            </span>
                          </div>
                          <div className="flex justify-between">
                            <span className="text-muted-foreground">Tanggal Cair:</span>
                            <span className="font-semibold text-foreground">
                              Tgl {p.stipend_day || 25} setiap bulan
                            </span>
                          </div>
                        </div>
                      )}
                    </div>

                    <div className="pt-3 border-t border-border flex items-center justify-between text-xs">
                      <span className="text-muted-foreground tabular-nums">
                        {p.deadline ? `Tenggat: ${formatDateIndo(p.deadline)}` : 'Tanpa tenggat'}
                      </span>
                      {p.kind === 'freelance' && (
                        <Button
                          type="button"
                          variant="ghost"
                          size="sm"
                          onClick={() => openPaymentsModal(p)}
                        >
                          Milestone Pembayaran
                        </Button>
                      )}
                    </div>
                  </CardContent>
                </Card>
              );
            })}
          </div>
        )
      ) : activeTab === 'gantt' ? (
        /* ================= LINIMASA GANTT HORIZONTAL ================= */
        projects.length === 0 ? (
          <EmptyState
            icon={<CalendarRange className="w-5 h-5" />}
            title="Belum ada jadwal proyek untuk Gantt"
            description="Buat proyek dengan tanggal mulai dan tenggat untuk memantau timeline horizontal."
            actionLabel="Tambah Kegiatan"
            onAction={openCreateModal}
          />
        ) : (
          <Card className="overflow-hidden">
            <CardHeader className="border-b border-border flex flex-col sm:flex-row sm:items-center justify-between gap-2">
              <div>
                <CardTitle className="flex items-center gap-2">
                  <CalendarRange className="w-4 h-4 text-primary" />
                  <span>Linimasa Gantt Proyek &amp; Tenggat Tugas</span>
                </CardTitle>
                <p className="text-xs text-muted-foreground mt-0.5 tabular-nums">
                  Rentang tampil: {formatDateIndo(ganttRange.start.toISOString())} -{' '}
                  {formatDateIndo(ganttRange.end.toISOString())}
                </p>
              </div>
              <span className="text-xs text-muted-foreground tabular-nums">
                {projects.length} proyek aktif
              </span>
            </CardHeader>

            <div className="overflow-x-auto">
              <div className="min-w-[680px] divide-y divide-border">
                {/* Header Skala Waktu */}
                <div className="grid grid-cols-12 bg-subtle border-b border-border text-[11px] font-semibold text-muted-foreground px-4 py-2.5">
                  <div className="col-span-4">Kegiatan / Proyek</div>
                  <div className="col-span-8 flex justify-between tabular-nums">
                    <span>{formatDateIndo(ganttRange.start.toISOString())}</span>
                    <span>
                      {formatDateIndo(
                        new Date(
                          ganttRange.start.getTime() + ganttRange.totalMs * 0.5
                        ).toISOString()
                      )}
                    </span>
                    <span>{formatDateIndo(ganttRange.end.toISOString())}</span>
                  </div>
                </div>

                {projects.map((p) => {
                  const startMs = p.started_on
                    ? new Date(p.started_on).getTime()
                    : ganttRange.start.getTime();
                  const endMs = p.deadline
                    ? new Date(p.deadline).getTime()
                    : startMs + 14 * 86400_000;

                  const clampedStart = Math.max(ganttRange.start.getTime(), startMs);
                  const clampedEnd = Math.min(
                    ganttRange.end.getTime(),
                    Math.max(clampedStart + 2 * 86400_000, endMs)
                  );
                  const leftPct =
                    ((clampedStart - ganttRange.start.getTime()) / ganttRange.totalMs) * 100;
                  const widthPct = Math.max(
                    4,
                    ((clampedEnd - clampedStart) / ganttRange.totalMs) * 100
                  );

                  const pTasks = (taskStatsByProject.get(p.id)?.tasks ?? []).filter(
                    (t) => t.due_at
                  );

                  return (
                    <div key={p.id} className="grid grid-cols-12 items-center px-4 py-3.5 hover:bg-hover gap-3">
                      <div className="col-span-4 space-y-1 min-w-0">
                        <div className="flex items-center gap-2">
                          <span className="font-semibold text-sm text-foreground truncate">
                            {p.name}
                          </span>
                          <KindBadge kind={p.kind} />
                        </div>
                        <div className="text-[11px] text-muted-foreground tabular-nums">
                          {p.started_on ? formatDateIndo(p.started_on) : 'Mulai fleksibel'} -&gt;{' '}
                          {p.deadline ? formatDateIndo(p.deadline) : 'Tanpa tenggat'}
                        </div>
                      </div>

                      <div className="col-span-8 space-y-1.5">
                        <div className="relative h-9 w-full rounded-md bg-subtle border border-border overflow-hidden">
                          <div
                            style={{
                              left: `${Math.max(0, Math.min(96, leftPct))}%`,
                              width: `${Math.min(100 - Math.max(0, leftPct), widthPct)}%`,
                            }}
                            className="absolute top-1 h-5 rounded-sm bg-primary text-primary-foreground px-2 flex items-center text-[11px] font-medium truncate"
                          >
                            {p.status}
                          </div>

                          {pTasks.map((t) => {
                            const tMs = new Date(t.due_at!).getTime();
                            if (tMs < ganttRange.start.getTime() || tMs > ganttRange.end.getTime()) {
                              return null;
                            }
                            const tLeft =
                              ((tMs - ganttRange.start.getTime()) / ganttRange.totalMs) * 100;
                            return (
                              <div
                                key={t.id}
                                style={{ left: `${Math.max(1.5, Math.min(98.5, tLeft))}%` }}
                                title={`Tugas: ${t.title} (${formatDateIndo(t.due_at!)})`}
                                className={cn(
                                  'absolute bottom-0.5 z-10 -translate-x-1/2 h-2.5 w-2.5 rounded-full border border-card',
                                  t.status === 'done' ? 'bg-income' : 'bg-warning'
                                )}
                              />
                            );
                          })}
                        </div>

                        {pTasks.length > 0 && (
                          <div className="flex flex-wrap gap-1.5">
                            {pTasks.slice(0, 4).map((t) => (
                              <span
                                key={t.id}
                                className="inline-flex items-center gap-1 rounded-sm border border-border bg-card px-2 py-0.5 text-[11px] text-muted-foreground tabular-nums"
                              >
                                <span
                                  className={cn(
                                    'h-1.5 w-1.5 rounded-full',
                                    t.status === 'done' ? 'bg-income' : 'bg-warning'
                                  )}
                                />
                                <span className="truncate max-w-[140px]">{t.title}</span>
                                <span>({formatDateIndo(t.due_at!)})</span>
                              </span>
                            ))}
                          </div>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          </Card>
        )
      ) : activeTab === 'workload' ? (
        /* ================= PETA BEBAN KERJA (WORKLOAD) ================= */
        <div className="space-y-6">
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <Card>
              <CardContent className="p-4">
                <div className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">
                  Total Estimasi Tugas Aktif
                </div>
                <div className="text-2xl font-bold text-foreground tabular-nums mt-1">
                  {Math.round(
                    (projectTasks
                      .filter((t) => t.status !== 'done')
                      .reduce((acc, t) => acc + Number(t.estimate_minutes ?? 0), 0) /
                      60) *
                      10
                  ) / 10}{' '}
                  jam
                </div>
                <div className="text-xs text-muted-foreground mt-0.5 tabular-nums">
                  Dari {projectTasks.filter((t) => t.status !== 'done').length} tugas aktif
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardContent className="p-4">
                <div className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">
                  Batas Kapasitas Sehat
                </div>
                <div className="text-2xl font-bold text-foreground tabular-nums mt-1">
                  8 jam/hari · 40 jam/mgg
                </div>
                <div className="text-xs text-muted-foreground mt-0.5">
                  Penanda beban tinggi muncul otomatis
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardContent className="p-4">
                <div className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">
                  Penanggung Jawab Over-Capacity
                </div>
                <div
                  className={cn(
                    'text-2xl font-bold tabular-nums mt-1',
                    workloadByAssignee.some((w) => w.isOverloaded)
                      ? 'text-expense'
                      : 'text-income'
                  )}
                >
                  {workloadByAssignee.filter((w) => w.isOverloaded).length}
                </div>
                <div className="text-xs text-muted-foreground mt-0.5">
                  Anggota melebihi 40 jam/minggu atau 8 jam/hari
                </div>
              </CardContent>
            </Card>
          </div>

          <Card className="overflow-hidden">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Users className="w-4 h-4 text-primary" />
                <span>Matriks Beban Kerja per Penanggung Jawab</span>
              </CardTitle>
            </CardHeader>
            {workloadByAssignee.length === 0 ? (
              <div className="p-8 text-center text-xs text-muted-foreground">
                Belum ada tugas dengan estimasi waktu pada ruang kerja ini.
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-xs text-left">
                  <thead className="bg-subtle border-b border-border text-muted-foreground font-semibold uppercase tracking-wider">
                    <tr>
                      <th className="px-4 py-3">Penanggung Jawab</th>
                      <th className="px-4 py-3 text-right">Tugas Aktif</th>
                      <th className="px-4 py-3 text-right">Selesai</th>
                      <th className="px-4 py-3 text-right">Total Estimasi</th>
                      <th className="px-4 py-3 text-right">Beban 7 Hari / Puncak Harian</th>
                      <th className="px-4 py-3 text-right">Status Kapasitas</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-border tabular-nums">
                    {workloadByAssignee.map((w) => {
                      const totalHours = Math.round((w.totalEstimateMin / 60) * 10) / 10;
                      const weeklyHours = Math.round((w.weeklyEstimateMin / 60) * 10) / 10;
                      const peakDailyHours = Math.round((w.peakDailyMin / 60) * 10) / 10;
                      return (
                        <tr key={w.key} className="hover:bg-hover">
                          <td className="px-4 py-3 font-medium text-foreground">
                            <div>{w.label}</div>
                            {w.role !== '-' && (
                              <div className="text-[11px] text-muted-foreground capitalize">
                                Peran: {w.role}
                              </div>
                            )}
                          </td>
                          <td className="px-4 py-3 text-right font-semibold">{w.activeTasks}</td>
                          <td className="px-4 py-3 text-right text-muted-foreground">{w.doneTasks}</td>
                          <td className="px-4 py-3 text-right font-semibold">{totalHours} jam</td>
                          <td className="px-4 py-3 text-right">
                            {weeklyHours} jam / {peakDailyHours} jam
                          </td>
                          <td className="px-4 py-3 text-right">
                            {w.isOverloaded ? (
                              <StatusBadge variant="expense">
                                <AlertTriangle className="w-3 h-3" />
                                <span>Beban Tinggi</span>
                              </StatusBadge>
                            ) : w.isHeavy ? (
                              <StatusBadge variant="warning">Padat</StatusBadge>
                            ) : (
                              <StatusBadge variant="income">Seimbang</StatusBadge>
                            )}
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </Card>

          <Card className="overflow-hidden">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Layers className="w-4 h-4 text-primary" />
                <span>Distribusi Jam &amp; Tugas per Proyek</span>
              </CardTitle>
            </CardHeader>
            <div className="divide-y divide-border">
              {projects.map((p) => {
                const stat = taskStatsByProject.get(p.id) ?? {
                  total: 0,
                  done: 0,
                  activeEstimateMin: 0,
                };
                const estHours = Math.round((stat.activeEstimateMin / 60) * 10) / 10;
                const activeCount = stat.total - stat.done;
                const barPct = Math.min(100, Math.round((estHours / 40) * 100));
                return (
                  <div key={p.id} className="p-4 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                    <div className="space-y-1 min-w-0">
                      <div className="flex items-center gap-2">
                        <span className="font-semibold text-sm text-foreground truncate">
                          {p.name}
                        </span>
                        <KindBadge kind={p.kind} />
                      </div>
                      <div className="text-xs text-muted-foreground tabular-nums">
                        {activeCount} tugas aktif · {stat.done} selesai · Estimasi tersisa {estHours} jam
                      </div>
                    </div>
                    <div className="w-full sm:w-56 space-y-1">
                      <div className="h-2.5 w-full rounded-full bg-subtle border border-border overflow-hidden">
                        <div
                          className={cn(
                            'h-full transition-all duration-150',
                            estHours > 40 ? 'bg-expense' : 'bg-primary'
                          )}
                          style={{ width: `${Math.max(estHours > 0 ? 6 : 0, barPct)}%` }}
                        />
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          </Card>
        </div>
      ) : (
        /* ================= LAPORAN PROYEK, MARGIN & PIUTANG ================= */
        <div className="space-y-6">
          <Card className="overflow-hidden print-avoid-break">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Clock className="w-4 h-4 text-primary" />
                <span>Daftar Piutang Jatuh Tempo &amp; Terlambat</span>
              </CardTitle>
            </CardHeader>

            {receivables.length === 0 ? (
              <div className="p-8 text-center text-xs text-muted-foreground">
                Tidak ada piutang aktif yang tertunda. Semua pembayaran termin telah lunas.
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-xs text-left">
                  <thead className="bg-subtle border-b border-border text-muted-foreground font-semibold uppercase tracking-wider">
                    <tr>
                      <th className="px-4 py-3">Kegiatan &amp; Klien</th>
                      <th className="px-4 py-3">Label Pembayaran</th>
                      <th className="px-4 py-3 text-right">Nominal Sisa</th>
                      <th className="px-4 py-3">Jatuh Tempo</th>
                      <th className="px-4 py-3">Status</th>
                      <th className="px-4 py-3 text-right print:hidden">Aksi</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-border">
                    {receivables.map((r) => (
                      <tr key={r.payment_id} className="hover:bg-hover">
                        <td className="px-4 py-3 font-medium text-foreground">
                          {r.project_name}
                          {r.client_name && (
                            <div className="text-xs text-muted-foreground">{r.client_name}</div>
                          )}
                        </td>
                        <td className="px-4 py-3">{r.label}</td>
                        <td className="px-4 py-3 font-bold text-foreground text-right tabular-nums">
                          {formatAmount(r.remaining_amount)}
                        </td>
                        <td className="px-4 py-3 text-muted-foreground tabular-nums">
                          {r.due_date ? formatDateIndo(r.due_date) : '-'}
                        </td>
                        <td className="px-4 py-3">
                          {r.is_overdue ? (
                            <StatusBadge variant="expense">
                              {r.days_overdue} hari lewat tempo
                            </StatusBadge>
                          ) : (
                            <StatusBadge variant="warning">Tertunda</StatusBadge>
                          )}
                        </td>
                        <td className="px-4 py-3 text-right print:hidden">
                          <Button
                            type="button"
                            size="sm"
                            onClick={() => setPayingMilestoneId(r.payment_id)}
                          >
                            Tandai Lunas
                          </Button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </Card>

          <Card className="overflow-hidden print-avoid-break">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <TrendingUp className="w-4 h-4 text-primary" />
                <span>Laporan Keuangan Proyek, Sisa Tagihan &amp; Margin Bersih</span>
              </CardTitle>
            </CardHeader>

            {projectFinancialReports.length === 0 ? (
              <div className="p-8 text-center text-xs text-muted-foreground">
                Belum ada data laporan keuangan proyek.
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-xs text-left">
                  <thead className="bg-subtle border-b border-border text-muted-foreground font-semibold uppercase tracking-wider">
                    <tr>
                      <th className="px-4 py-3">Proyek</th>
                      <th className="px-4 py-3 text-right">Kontrak</th>
                      <th className="px-4 py-3 text-right">Masuk</th>
                      <th className="px-4 py-3 text-right">Sisa Tagihan</th>
                      <th className="px-4 py-3 text-right">Pengeluaran</th>
                      <th className="px-4 py-3 text-right">Margin Bersih</th>
                      <th className="px-4 py-3 text-right">Margin %</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-border tabular-nums">
                    {projectFinancialReports.map((p) => (
                      <tr key={p.project_id} className="hover:bg-hover">
                        <td className="px-4 py-3 font-medium text-foreground">
                          <div className="flex items-center gap-2">
                            <span>{p.project_name}</span>
                            <KindBadge kind={p.kind} />
                          </div>
                          {p.client_name && (
                            <div className="text-xs text-muted-foreground mt-0.5">
                              {p.client_name}
                            </div>
                          )}
                        </td>
                        <td className="px-4 py-3 text-right">
                          {p.contract_value ? formatAmount(p.contract_value, p.currency) : '-'}
                        </td>
                        <td className="px-4 py-3 text-right font-semibold text-income">
                          {formatAmount(p.total_paid, p.currency)}
                        </td>
                        <td className="px-4 py-3 text-right text-warning font-medium">
                          {formatAmount(p.remaining_invoiced, p.currency)}
                        </td>
                        <td className="px-4 py-3 text-right text-expense">
                          {formatAmount(p.total_expense, p.currency)}
                        </td>
                        <td
                          className={cn(
                            'px-4 py-3 text-right font-bold',
                            p.net_profit >= 0 ? 'text-foreground' : 'text-expense'
                          )}
                        >
                          {formatAmount(p.net_profit, p.currency)}
                        </td>
                        <td className="px-4 py-3 text-right font-medium">{p.margin_percent}%</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </Card>
        </div>
      )}

      {/* Modal Tambah / Edit Kegiatan */}
      <Dialog
        open={showProjectModal}
        onClose={() => setShowProjectModal(false)}
        title={modalMode === 'create' ? 'Tambah Kegiatan Baru' : 'Ubah Kegiatan'}
      >
        <form onSubmit={handleSaveProject} className="space-y-4">
          {formError && (
            <div className="p-3 rounded-lg bg-expense-subtle border border-expense-border text-expense text-xs">
              {formError}
            </div>
          )}

          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">
              Nama Kegiatan / Proyek
            </label>
            <Input
              type="text"
              required
              placeholder="Misal: Redesign Mobile App atau Magang Frontend"
              value={formName}
              onChange={(e) => setFormName(e.target.value)}
            />
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="text-xs font-medium text-foreground block mb-1.5">
                Jenis Kegiatan
              </label>
              <Select
                value={formKind}
                disabled={modalMode === 'edit'}
                onChange={(e) => setFormKind(e.target.value as ActivityKind)}
              >
                <option value="freelance">Freelance</option>
                <option value="intern">Magang</option>
                <option value="kuliah">Kuliah</option>
                <option value="pribadi">Pribadi</option>
              </Select>
            </div>

            <div>
              <label className="text-xs font-medium text-foreground block mb-1.5">
                Status
              </label>
              <Select
                value={formStatus}
                onChange={(e) => setFormStatus(e.target.value as ProjectStatus)}
              >
                <option value="draft">Draft</option>
                <option value="berjalan">Berjalan</option>
                <option value="selesai">Selesai</option>
                <option value="dibatalkan">Dibatalkan</option>
              </Select>
            </div>
          </div>

          {formKind === 'freelance' && (
            <div className="p-3.5 rounded-lg border border-border bg-muted/30 space-y-3">
              <div className="text-xs font-semibold text-foreground">
                Parameter Proyek Freelance
              </div>

              <div>
                <label className="text-xs font-medium text-foreground block mb-1.5">
                  Nama Klien
                </label>
                <Input
                  type="text"
                  placeholder="Misal: PT Teknologi Cemerlang"
                  value={formClientName}
                  onChange={(e) => setFormClientName(e.target.value)}
                />
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-medium text-foreground block mb-1.5">
                    Nilai Kontrak (IDR)
                  </label>
                  <Input
                    type="number"
                    min="0"
                    step="any"
                    placeholder="10000000"
                    value={formContractValue}
                    onChange={(e) => setFormContractValue(e.target.value)}
                    className="tabular-nums"
                  />
                </div>

                <div>
                  <label className="text-xs font-medium text-foreground block mb-1.5">
                    Potongan Platform (%)
                  </label>
                  <Input
                    type="number"
                    min="0"
                    max="100"
                    step="any"
                    placeholder="10"
                    value={formFeePercent}
                    onChange={(e) => setFormFeePercent(e.target.value)}
                    className="tabular-nums"
                  />
                </div>
              </div>

              <div>
                <label className="text-xs font-medium text-foreground block mb-1.5">
                  Metode Potongan Platform
                </label>
                <Select
                  value={formFeeMode}
                  onChange={(e) => setFormFeeMode(e.target.value as FeeMode)}
                >
                  <option value="expense_transaction">
                    Catat otomatis sebagai transaksi pengeluaran
                  </option>
                  <option value="profit_deduction">
                    Pengurang di profit tanpa transaksi
                  </option>
                </Select>
              </div>
            </div>
          )}

          {formKind === 'kuliah' && (
            <div className="p-3.5 rounded-lg border border-border bg-muted/30 space-y-3">
              <div className="text-xs font-semibold text-foreground">
                Parameter Mata Kuliah
              </div>

              <div className="grid grid-cols-3 gap-2">
                <div>
                  <label className="text-xs font-medium text-foreground block mb-1.5">
                    Semester
                  </label>
                  <Input
                    type="number"
                    min="1"
                    max="20"
                    value={formSemester}
                    onChange={(e) => setFormSemester(e.target.value)}
                    className="tabular-nums"
                  />
                </div>
                <div>
                  <label className="text-xs font-medium text-foreground block mb-1.5">
                    Kode MK
                  </label>
                  <Input
                    type="text"
                    placeholder="CS101"
                    value={formCourseCode}
                    onChange={(e) => setFormCourseCode(e.target.value)}
                  />
                </div>
                <div>
                  <label className="text-xs font-medium text-foreground block mb-1.5">
                    SKS
                  </label>
                  <Input
                    type="number"
                    min="0"
                    max="30"
                    value={formCredits}
                    onChange={(e) => setFormCredits(e.target.value)}
                    className="tabular-nums"
                  />
                </div>
              </div>
            </div>
          )}

          {formKind === 'intern' && (
            <div className="p-3.5 rounded-lg border border-border bg-muted/30 space-y-3">
              <div className="text-xs font-semibold text-foreground">
                Parameter Magang
              </div>

              <div>
                <label className="text-xs font-medium text-foreground block mb-1.5">
                  Nama Instansi / Perusahaan
                </label>
                <Input
                  type="text"
                  placeholder="Misal: Startup XYZ"
                  value={formClientName}
                  onChange={(e) => setFormClientName(e.target.value)}
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-medium text-foreground block mb-1.5">
                    Uang Saku per Bulan (IDR)
                  </label>
                  <Input
                    type="number"
                    min="0"
                    step="any"
                    placeholder="3500000"
                    value={formStipendAmount}
                    onChange={(e) => setFormStipendAmount(e.target.value)}
                    className="tabular-nums"
                  />
                </div>
                <div>
                  <label className="text-xs font-medium text-foreground block mb-1.5">
                    Tanggal Cair Tiap Bulan
                  </label>
                  <Input
                    type="number"
                    min="1"
                    max="31"
                    value={formStipendDay}
                    onChange={(e) => setFormStipendDay(e.target.value)}
                    className="tabular-nums"
                  />
                </div>
              </div>
            </div>
          )}

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="text-xs font-medium text-foreground block mb-1.5">
                Tanggal Mulai
              </label>
              <Input
                type="date"
                value={formStartedOn}
                onChange={(e) => setFormStartedOn(e.target.value)}
              />
            </div>
            <div>
              <label className="text-xs font-medium text-foreground block mb-1.5">
                Tenggat / Selesai
              </label>
              <Input
                type="date"
                value={formDeadline}
                onChange={(e) => setFormDeadline(e.target.value)}
              />
            </div>
          </div>

          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">
              Deskripsi / Catatan Tambahan
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
              onClick={() => setShowProjectModal(false)}
            >
              Batal
            </Button>
            <Button type="submit" disabled={savingProject}>
              {savingProject ? 'Menyimpan...' : 'Simpan Kegiatan'}
            </Button>
          </div>
        </form>
      </Dialog>

      {/* Modal Milestone Pembayaran */}
      <Dialog
        open={!!selectedProjectForPayments}
        onClose={() => setSelectedProjectForPayments(null)}
        title={`Milestone Pembayaran: ${selectedProjectForPayments?.name || ''}`}
        description={
          selectedProjectForPayments?.contract_value
            ? `Nilai Kontrak: ${formatAmount(selectedProjectForPayments.contract_value)}`
            : undefined
        }
      >
        <div className="space-y-4">
          <div className="flex justify-end">
            <Button
              type="button"
              size="sm"
              onClick={() => setShowAddMilestoneModal(true)}
            >
              <Plus className="w-4 h-4" />
              <span>Tambah Termin / Milestone</span>
            </Button>
          </div>

          {projectPayments.length === 0 ? (
            <div className="p-6 text-center text-xs text-muted-foreground border border-dashed border-border rounded-lg">
              Belum ada milestone pembayaran. Tambahkan termin DP atau pelunasan.
            </div>
          ) : (
            <div className="space-y-2 max-h-72 overflow-y-auto">
              {projectPayments.map((pm) => (
                <div
                  key={pm.id}
                  className="p-3.5 rounded-lg border border-border bg-muted/20 flex items-center justify-between gap-3 text-xs"
                >
                  <div>
                    <div className="font-semibold text-foreground">{pm.label}</div>
                    <div className="text-muted-foreground tabular-nums mt-0.5">
                      Nominal: {formatAmount(pm.amount)} • Tenggat: {pm.due_date ? formatDateIndo(pm.due_date) : '-'}
                    </div>
                  </div>

                  <div className="flex items-center gap-2">
                    {pm.status === 'paid' ? (
                      <>
                        <StatusBadge variant="income">
                          <CheckCircle2 className="w-3 h-3" />
                          <span>Lunas</span>
                        </StatusBadge>
                        <Button
                          type="button"
                          variant="ghost"
                          size="sm"
                          disabled={processingPayment}
                          onClick={() => handleCancelPaymentPaid(pm.id)}
                        >
                          Batal Lunas
                        </Button>
                      </>
                    ) : (
                      <Button
                        type="button"
                        size="sm"
                        onClick={() => setPayingMilestoneId(pm.id)}
                      >
                        Tandai Lunas
                      </Button>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      </Dialog>

      {/* Modal Tambah Milestone */}
      <Dialog
        open={showAddMilestoneModal}
        onClose={() => setShowAddMilestoneModal(false)}
        title="Tambah Milestone Pembayaran"
      >
        <form onSubmit={handleAddMilestone} className="space-y-4">
          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">
              Label Termin
            </label>
            <Input
              type="text"
              required
              placeholder="Misal: DP 50% atau Termin 2"
              value={milestoneLabel}
              onChange={(e) => setMilestoneLabel(e.target.value)}
            />
          </div>

          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">
              Nominal (IDR)
            </label>
            <Input
              type="number"
              min="0"
              step="any"
              required
              placeholder="5000000"
              value={milestoneAmount}
              onChange={(e) => setMilestoneAmount(e.target.value)}
              className="tabular-nums"
            />
          </div>

          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">
              Tanggal Jatuh Tempo
            </label>
            <Input
              type="date"
              value={milestoneDueDate}
              onChange={(e) => setMilestoneDueDate(e.target.value)}
            />
          </div>

          <div className="flex justify-end gap-2 pt-3 border-t border-border">
            <Button
              type="button"
              variant="secondary"
              onClick={() => setShowAddMilestoneModal(false)}
            >
              Batal
            </Button>
            <Button type="submit" disabled={savingMilestone}>
              {savingMilestone ? 'Menyimpan...' : 'Simpan Milestone'}
            </Button>
          </div>
        </form>
      </Dialog>

      {/* Modal Dialog Pelunasan */}
      <Dialog
        open={!!payingMilestoneId}
        onClose={() => setPayingMilestoneId(null)}
        title="Konfirmasi Akun Penerima"
        description="Pilih akun tujuan pemasukan dana saat menandai pembayaran ini lunas."
      >
        <div className="space-y-4">
          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">
              Akun Kas / Rekening
            </label>
            <Select
              value={payAccountId}
              onChange={(e) => setPayAccountId(e.target.value)}
            >
              {accounts.map((acc) => (
                <option key={acc.id} value={acc.id}>
                  {acc.name}
                </option>
              ))}
            </Select>
          </div>

          <div className="flex justify-end gap-2 pt-3 border-t border-border">
            <Button
              type="button"
              variant="secondary"
              onClick={() => setPayingMilestoneId(null)}
            >
              Batal
            </Button>
            <Button
              type="button"
              disabled={processingPayment}
              onClick={() => payingMilestoneId && handleMarkPaymentPaid(payingMilestoneId)}
            >
              {processingPayment ? 'Memproses...' : 'Tandai Lunas'}
            </Button>
          </div>
        </div>
      </Dialog>
    </div>
  );
}
