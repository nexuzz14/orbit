'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';
import { formatCurrency, formatDateIndo } from '@/lib/format';
import type { ActivityKind, ProjectStatus, FeeMode } from '@/types/database';
import {
  Briefcase,
  Plus,
  Trash2,
  Edit2,
  TrendingUp,
  Clock,
  CheckCircle2,
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
  SegmentedControl,
  KindBadge,
  StatusBadge,
  Skeleton,
  EmptyState,
  ErrorState,
  LainnyaSubNav,
  ACTIVITY_KIND_META,
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

export default function ProyekPage() {
  const supabase = createClient();
  const [workspaceId, setWorkspaceId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);

  const [activeTab, setActiveTab] = useState<'projects' | 'finances'>('projects');
  const [filterKind, setFilterKind] = useState<ActivityKind | 'all'>('all');

  const [projects, setProjects] = useState<ProjectRow[]>([]);
  const [profitData, setProfitData] = useState<ProjectProfitRow[]>([]);
  const [receivables, setReceivables] = useState<ReceivableRow[]>([]);
  const [accounts, setAccounts] = useState<AccountItem[]>([]);

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
    } catch (err: unknown) {
      setLoadError(err instanceof Error ? err.message : 'Gagal memuat daftar kegiatan dan piutang.');
    } finally {
      setLoading(false);
    }
  }, [supabase, payAccountId]);

  useEffect(() => {
    loadData();
  }, [loadData]);

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

  const filteredProjects = projects.filter((p) =>
    filterKind === 'all' ? true : p.kind === filterKind
  );

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-foreground">Lainnya</h1>
          <p className="text-sm text-muted-foreground mt-0.5">
            Kelola kegiatan magang, proyek freelance, mata kuliah, dan piutang
          </p>
        </div>

        <Button onClick={openCreateModal}>
          <Plus className="w-4 h-4" />
          <span>Tambah Kegiatan</span>
        </Button>
      </div>

      <LainnyaSubNav />

      <div className="flex flex-col md:flex-row md:items-center justify-between gap-3">
        <SegmentedControl
          ariaLabel="Sub-menu Kegiatan & Piutang"
          value={activeTab}
          onChange={setActiveTab}
          options={[
            { value: 'projects', label: `Kegiatan (${projects.length})` },
            { value: 'finances', label: `Piutang & Profit (${receivables.length})` },
          ]}
        />

        {activeTab === 'projects' && (
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
              Semua
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
        )}
      </div>

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

                      {p.kind === 'freelance' && (
                        <div className="p-3 rounded-lg bg-muted/40 border border-border text-xs space-y-1 tabular-nums">
                          <div className="flex justify-between">
                            <span className="text-muted-foreground">Nilai Kontrak:</span>
                            <span className="font-semibold text-foreground">
                              {p.contract_value ? formatCurrency(p.contract_value) : '-'}
                            </span>
                          </div>
                          {profitInfo && (
                            <>
                              <div className="flex justify-between">
                                <span className="text-muted-foreground">Dibayar:</span>
                                <span className="font-semibold text-income">
                                  {formatCurrency(profitInfo.total_paid)}
                                </span>
                              </div>
                              <div className="flex justify-between">
                                <span className="text-muted-foreground">Profit Bersih:</span>
                                <span className="font-semibold text-foreground">
                                  {formatCurrency(profitInfo.net_profit)} ({profitInfo.margin_percent}%)
                                </span>
                              </div>
                            </>
                          )}
                        </div>
                      )}

                      {p.kind === 'kuliah' && (
                        <div className="p-3 rounded-lg bg-muted/40 border border-border text-xs space-y-1 tabular-nums">
                          <div className="flex justify-between">
                            <span className="text-muted-foreground">Semester:</span>
                            <span className="font-semibold text-foreground">{p.semester || '-'}</span>
                          </div>
                          <div className="flex justify-between">
                            <span className="text-muted-foreground">Kode & SKS:</span>
                            <span className="font-semibold text-foreground">
                              {p.course_code || '-'} ({p.credits || 0} SKS)
                            </span>
                          </div>
                        </div>
                      )}

                      {p.kind === 'intern' && (
                        <div className="p-3 rounded-lg bg-muted/40 border border-border text-xs space-y-1 tabular-nums">
                          <div className="flex justify-between">
                            <span className="text-muted-foreground">Uang Saku:</span>
                            <span className="font-semibold text-foreground">
                              {p.stipend_amount ? formatCurrency(p.stipend_amount) : '-'}
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
      ) : (
        <div className="space-y-6">
          <Card className="overflow-hidden">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Clock className="w-4 h-4 text-primary" />
                <span>Daftar Piutang Jatuh Tempo & Terlambat</span>
              </CardTitle>
            </CardHeader>

            {receivables.length === 0 ? (
              <div className="p-8 text-center text-xs text-muted-foreground">
                Tidak ada piutang aktif yang tertunda. Semua pembayaran termin telah lunas.
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-xs text-left">
                  <thead className="bg-muted/40 border-b border-border text-muted-foreground font-semibold uppercase tracking-wider">
                    <tr>
                      <th className="px-4 py-3">Kegiatan & Klien</th>
                      <th className="px-4 py-3">Label Pembayaran</th>
                      <th className="px-4 py-3 text-right">Nominal Sisa</th>
                      <th className="px-4 py-3">Jatuh Tempo</th>
                      <th className="px-4 py-3">Status</th>
                      <th className="px-4 py-3 text-right">Aksi</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-border">
                    {receivables.map((r) => (
                      <tr key={r.payment_id} className="hover:bg-muted/20">
                        <td className="px-4 py-3 font-medium text-foreground">
                          {r.project_name}
                          {r.client_name && (
                            <div className="text-xs text-muted-foreground">{r.client_name}</div>
                          )}
                        </td>
                        <td className="px-4 py-3">{r.label}</td>
                        <td className="px-4 py-3 font-bold text-foreground text-right tabular-nums">
                          {formatCurrency(r.remaining_amount)}
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
                        <td className="px-4 py-3 text-right">
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

          <Card className="overflow-hidden">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <TrendingUp className="w-4 h-4 text-primary" />
                <span>Laporan Profitabilitas Proyek Freelance</span>
              </CardTitle>
            </CardHeader>

            {profitData.filter((p) => p.kind === 'freelance').length === 0 ? (
              <div className="p-8 text-center text-xs text-muted-foreground">
                Belum ada data profitabilitas proyek freelance.
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full text-xs text-left">
                  <thead className="bg-muted/40 border-b border-border text-muted-foreground font-semibold uppercase tracking-wider">
                    <tr>
                      <th className="px-4 py-3">Proyek</th>
                      <th className="px-4 py-3 text-right">Nilai Kontrak</th>
                      <th className="px-4 py-3 text-right">Total Diterima</th>
                      <th className="px-4 py-3 text-right">Pengeluaran & Potongan</th>
                      <th className="px-4 py-3 text-right">Profit Bersih</th>
                      <th className="px-4 py-3 text-right">Margin %</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-border tabular-nums">
                    {profitData
                      .filter((p) => p.kind === 'freelance')
                      .map((p) => (
                        <tr key={p.project_id} className="hover:bg-muted/20">
                          <td className="px-4 py-3 font-medium text-foreground">
                            {p.project_name}
                            {p.client_name && (
                              <div className="text-xs text-muted-foreground">{p.client_name}</div>
                            )}
                          </td>
                          <td className="px-4 py-3 text-right">
                            {p.contract_value ? formatCurrency(p.contract_value) : '-'}
                          </td>
                          <td className="px-4 py-3 text-right font-semibold text-income">
                            {formatCurrency(p.total_paid)}
                          </td>
                          <td className="px-4 py-3 text-right text-expense">
                            {formatCurrency(Number(p.total_expense) + Number(p.platform_fee_deducted))}
                          </td>
                          <td className="px-4 py-3 text-right font-bold text-foreground">
                            {formatCurrency(p.net_profit)}
                          </td>
                          <td className="px-4 py-3 text-right font-medium">
                            {p.margin_percent}%
                          </td>
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
            <div className="p-3 rounded-lg bg-expense/10 border border-expense/20 text-expense text-xs">
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
            ? `Nilai Kontrak: ${formatCurrency(selectedProjectForPayments.contract_value)}`
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
                      Nominal: {formatCurrency(pm.amount)} • Tenggat: {pm.due_date ? formatDateIndo(pm.due_date) : '-'}
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
