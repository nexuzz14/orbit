'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';
import { formatCurrency, formatDateIndo } from '@/lib/format';
import type { ActivityKind, ProjectStatus, FeeMode } from '@/types/database';
import {
  Briefcase,
  Laptop,
  GraduationCap,
  User,
  Plus,
  Trash2,
  Edit2,
  DollarSign,
  TrendingUp,
  Clock,
  CheckCircle2,
  AlertCircle,
  X
} from 'lucide-react';

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

const KIND_CONFIG: Record<ActivityKind, { label: string; icon: typeof User; color: string }> = {
  intern: { label: 'Magang', icon: Briefcase, color: 'text-blue-500 bg-blue-500/10' },
  freelance: { label: 'Freelance', icon: Laptop, color: 'text-purple-500 bg-purple-500/10' },
  kuliah: { label: 'Kuliah', icon: GraduationCap, color: 'text-amber-500 bg-amber-500/10' },
  pribadi: { label: 'Pribadi', icon: User, color: 'text-emerald-500 bg-emerald-500/10' },
};

export default function ProyekPage() {
  const supabase = createClient();
  const [workspaceId, setWorkspaceId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  // View tab: 'projects' or 'finances'
  const [activeTab, setActiveTab] = useState<'projects' | 'finances'>('projects');
  const [filterKind, setFilterKind] = useState<ActivityKind | 'all'>('all');

  // Data
  const [projects, setProjects] = useState<ProjectRow[]>([]);
  const [profitData, setProfitData] = useState<ProjectProfitRow[]>([]);
  const [receivables, setReceivables] = useState<ReceivableRow[]>([]);
  const [accounts, setAccounts] = useState<AccountItem[]>([]);

  // Project Modal
  const [showProjectModal, setShowProjectModal] = useState(false);
  const [modalMode, setModalMode] = useState<'create' | 'edit'>('create');
  const [editingProjectId, setEditingProjectId] = useState<string | null>(null);

  // Form states
  const [formKind, setFormKind] = useState<ActivityKind>('freelance');
  const [formName, setFormName] = useState('');
  const [formDescription, setFormDescription] = useState('');
  const [formStatus, setFormStatus] = useState<ProjectStatus>('berjalan');
  const [formStartedOn, setFormStartedOn] = useState('');
  const [formDeadline, setFormDeadline] = useState('');
  const [formColor, setFormColor] = useState('#6366f1');

  // Freelance fields
  const [formClientName, setFormClientName] = useState('');
  const [formContractValue, setFormContractValue] = useState('');
  const [formCurrency, setFormCurrency] = useState('IDR');
  const [formFeePercent, setFormFeePercent] = useState('0');
  const [formFeeMode, setFormFeeMode] = useState<FeeMode>('expense_transaction');

  // Kuliah fields
  const [formSemester, setFormSemester] = useState('1');
  const [formCourseCode, setFormCourseCode] = useState('');
  const [formCredits, setFormCredits] = useState('3');

  // Intern fields
  const [formStipendAmount, setFormStipendAmount] = useState('');
  const [formStipendDay, setFormStipendDay] = useState('25');

  const [savingProject, setSavingProject] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  // Milestone Payments Modal
  const [selectedProjectForPayments, setSelectedProjectForPayments] = useState<ProjectRow | null>(null);
  const [projectPayments, setProjectPayments] = useState<PaymentRow[]>([]);
  const [showAddMilestoneModal, setShowAddMilestoneModal] = useState(false);
  const [milestoneLabel, setMilestoneLabel] = useState('');
  const [milestoneAmount, setMilestoneAmount] = useState('');
  const [milestoneDueDate, setMilestoneDueDate] = useState('');
  const [savingMilestone, setSavingMilestone] = useState(false);

  // Pelunasan
  const [payingMilestoneId, setPayingMilestoneId] = useState<string | null>(null);
  const [payAccountId, setPayAccountId] = useState('');
  const [processingPayment, setProcessingPayment] = useState(false);

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

    // 1. Ambil akun
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

    // 2. Ambil proyek
    const { data: projData } = await supabase
      .from('projects')
      .select('*')
      .eq('workspace_id', wsId)
      .is('deleted_at', null)
      .order('created_at', { ascending: false });

    if (projData) {
      setProjects(projData as unknown as ProjectRow[]);
    }

    // 3. Ambil profit per proyek
    const { data: profitRows } = await supabase
      .from('v_project_profit')
      .select('*')
      .eq('workspace_id', wsId);

    if (profitRows) {
      setProfitData(profitRows as unknown as ProjectProfitRow[]);
    }

    // 4. Ambil piutang
    const { data: recRows } = await supabase
      .from('v_receivables')
      .select('*')
      .eq('workspace_id', wsId)
      .order('due_date', { ascending: true });

    if (recRows) {
      setReceivables(recRows as unknown as ReceivableRow[]);
    }

    setLoading(false);
  }, [supabase, payAccountId]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  // Load milestone payments for a selected project
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

  // Reset form
  const resetForm = () => {
    setFormKind('freelance');
    setFormName('');
    setFormDescription('');
    setFormStatus('berjalan');
    setFormStartedOn('');
    setFormDeadline('');
    setFormColor('#6366f1');
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
    setFormColor(proj.color || '#6366f1');

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

  // Simpan proyek (Create / Edit)
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
      // Reset specific fields depending on kind
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

  // Hapus proyek (Soft delete)
  const handleDeleteProject = async (projId: string) => {
    if (!confirm('Apakah Anda yakin ingin menghapus proyek ini?')) return;
    await supabase.from('projects').update({ deleted_at: new Date().toISOString() }).eq('id', projId);
    loadData();
  };

  // Tambah milestone payment
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

  // Tandai lunas pembayaran milestone
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

  // Batalkan status lunas (atomik membatalkan transaksi)
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
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Proyek & Kegiatan</h1>
          <p className="text-sm text-muted-foreground mt-0.5">
            Kelola kegiatan magang, freelance, perkuliahan, dan proyek pribadi.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={openCreateModal}
            className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium bg-foreground text-background rounded-md hover:bg-foreground/90 transition-colors"
          >
            <Plus className="w-3.5 h-3.5" />
            <span>Tambah Kegiatan</span>
          </button>
        </div>
      </div>

      {/* Tabs Navigasi: Daftar Proyek vs Piutang & Keuangan */}
      <div className="flex items-center justify-between border-b border-border pb-2">
        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={() => setActiveTab('projects')}
            className={`px-3 py-1.5 text-xs font-medium rounded-md transition-colors ${
              activeTab === 'projects'
                ? 'bg-muted text-foreground'
                : 'text-muted-foreground hover:text-foreground'
            }`}
          >
            Daftar Kegiatan ({projects.length})
          </button>
          <button
            type="button"
            onClick={() => setActiveTab('finances')}
            className={`px-3 py-1.5 text-xs font-medium rounded-md transition-colors ${
              activeTab === 'finances'
                ? 'bg-muted text-foreground'
                : 'text-muted-foreground hover:text-foreground'
            }`}
          >
            Piutang & Profit Freelance
          </button>
        </div>

        {activeTab === 'projects' && (
          <div className="flex items-center gap-1">
            <button
              type="button"
              onClick={() => setFilterKind('all')}
              className={`px-2.5 py-1 text-xs rounded-full transition-colors ${
                filterKind === 'all'
                  ? 'bg-foreground text-background font-medium'
                  : 'text-muted-foreground hover:text-foreground'
              }`}
            >
              Semua
            </button>
            {(['intern', 'freelance', 'kuliah', 'pribadi'] as ActivityKind[]).map((k) => (
              <button
                key={k}
                type="button"
                onClick={() => setFilterKind(k)}
                className={`px-2.5 py-1 text-xs rounded-full transition-colors ${
                  filterKind === k
                    ? 'bg-foreground text-background font-medium'
                    : 'text-muted-foreground hover:text-foreground'
                }`}
              >
                {KIND_CONFIG[k].label}
              </button>
            ))}
          </div>
        )}
      </div>

      {/* Konten Tab: Daftar Proyek */}
      {activeTab === 'projects' && (
        <div>
          {loading ? (
            <div className="p-8 text-center text-xs text-muted-foreground border border-border rounded-lg bg-card">
              Memuat kegiatan...
            </div>
          ) : filteredProjects.length === 0 ? (
            <div className="p-8 text-center text-xs text-muted-foreground border border-dashed border-border rounded-lg">
              Belum ada kegiatan yang terdaftar. Klik &ldquo;Tambah Kegiatan&rdquo; untuk memulai.
            </div>
          ) : (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {filteredProjects.map((p) => {
                const cfg = KIND_CONFIG[p.kind];
                const Icon = cfg.icon;
                const profitInfo = profitData.find((pr) => pr.project_id === p.id);

                return (
                  <div
                    key={p.id}
                    className="p-4 rounded-lg border border-border bg-card flex flex-col justify-between space-y-4 shadow-sm"
                  >
                    <div className="space-y-2">
                      <div className="flex items-center justify-between">
                        <span className={`flex items-center gap-1.5 px-2 py-0.5 rounded text-[11px] font-medium ${cfg.color}`}>
                          <Icon className="w-3 h-3" />
                          {cfg.label}
                        </span>
                        <div className="flex items-center gap-1">
                          <button
                            type="button"
                            onClick={() => openEditModal(p)}
                            className="p-1 text-muted-foreground hover:text-foreground transition-colors"
                          >
                            <Edit2 className="w-3.5 h-3.5" />
                          </button>
                          <button
                            type="button"
                            onClick={() => handleDeleteProject(p.id)}
                            className="p-1 text-muted-foreground hover:text-expense transition-colors"
                          >
                            <Trash2 className="w-3.5 h-3.5" />
                          </button>
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

                      {/* Detail Khusus Jenis */}
                      {p.kind === 'freelance' && (
                        <div className="p-2.5 rounded bg-muted/40 border border-border/60 text-xs space-y-1">
                          <div className="flex justify-between">
                            <span className="text-muted-foreground">Nilai Kontrak:</span>
                            <span className="font-medium text-foreground">
                              {p.contract_value ? formatCurrency(p.contract_value) : '-'}
                            </span>
                          </div>
                          {profitInfo && (
                            <>
                              <div className="flex justify-between">
                                <span className="text-muted-foreground">Dibayar:</span>
                                <span className="font-medium text-emerald-600 dark:text-emerald-400">
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
                        <div className="p-2.5 rounded bg-muted/40 border border-border/60 text-xs space-y-1">
                          <div className="flex justify-between">
                            <span className="text-muted-foreground">Semester:</span>
                            <span className="font-medium text-foreground">{p.semester || '-'}</span>
                          </div>
                          <div className="flex justify-between">
                            <span className="text-muted-foreground">Kode & SKS:</span>
                            <span className="font-medium text-foreground">
                              {p.course_code || '-'} ({p.credits || 0} SKS)
                            </span>
                          </div>
                        </div>
                      )}

                      {p.kind === 'intern' && (
                        <div className="p-2.5 rounded bg-muted/40 border border-border/60 text-xs space-y-1">
                          <div className="flex justify-between">
                            <span className="text-muted-foreground">Uang Saku:</span>
                            <span className="font-medium text-foreground">
                              {p.stipend_amount ? formatCurrency(p.stipend_amount) : '-'}
                            </span>
                          </div>
                          <div className="flex justify-between">
                            <span className="text-muted-foreground">Tanggal Cair:</span>
                            <span className="font-medium text-foreground">
                              Tgl {p.stipend_day || 25} setiap bulan
                            </span>
                          </div>
                        </div>
                      )}
                    </div>

                    {/* Footer Card */}
                    <div className="pt-2 border-t border-border flex items-center justify-between text-xs">
                      <span className="text-muted-foreground">
                        {p.deadline ? `Tenggat: ${formatDateIndo(p.deadline)}` : 'Tanpa tenggat'}
                      </span>
                      {p.kind === 'freelance' && (
                        <button
                          type="button"
                          onClick={() => openPaymentsModal(p)}
                          className="font-medium text-purple-600 dark:text-purple-400 hover:underline"
                        >
                          Milestone Pembayaran
                        </button>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      )}

      {/* Konten Tab: Piutang & Profit Freelance */}
      {activeTab === 'finances' && (
        <div className="space-y-6">
          {/* Piutang Belum Lunas */}
          <div className="space-y-3">
            <h2 className="text-base font-semibold text-foreground flex items-center gap-2">
              <Clock className="w-4 h-4 text-muted-foreground" />
              Daftar Piutang Jatuh Tempo & Terlambat
            </h2>

            {receivables.length === 0 ? (
              <div className="p-6 text-center text-xs text-muted-foreground border border-dashed border-border rounded-lg">
                Tidak ada piutang aktif yang tertunda. Semua pembayaran termin telah lunas.
              </div>
            ) : (
              <div className="border border-border rounded-lg overflow-hidden bg-card">
                <table className="w-full text-xs text-left">
                  <thead className="bg-muted/50 border-b border-border text-muted-foreground font-medium">
                    <tr>
                      <th className="px-4 py-2.5">Proyek & Klien</th>
                      <th className="px-4 py-2.5">Label Pembayaran</th>
                      <th className="px-4 py-2.5">Nominal Sisa</th>
                      <th className="px-4 py-2.5">Jatuh Tempo</th>
                      <th className="px-4 py-2.5">Status</th>
                      <th className="px-4 py-2.5 text-right">Aksi</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-border">
                    {receivables.map((r) => (
                      <tr key={r.payment_id} className="hover:bg-muted/30">
                        <td className="px-4 py-3 font-medium text-foreground">
                          {r.project_name}
                          {r.client_name && (
                            <div className="text-[11px] text-muted-foreground">{r.client_name}</div>
                          )}
                        </td>
                        <td className="px-4 py-3">{r.label}</td>
                        <td className="px-4 py-3 font-semibold text-foreground">
                          {formatCurrency(r.remaining_amount)}
                        </td>
                        <td className="px-4 py-3 text-muted-foreground">
                          {r.due_date ? formatDateIndo(r.due_date) : '-'}
                        </td>
                        <td className="px-4 py-3">
                          {r.is_overdue ? (
                            <span className="px-2 py-0.5 rounded text-[10px] font-medium bg-red-500/10 text-red-600 dark:text-red-400">
                              {r.days_overdue} hari lewat tempo
                            </span>
                          ) : (
                            <span className="px-2 py-0.5 rounded text-[10px] font-medium bg-amber-500/10 text-amber-600 dark:text-amber-400">
                              Tertunda
                            </span>
                          )}
                        </td>
                        <td className="px-4 py-3 text-right">
                          <button
                            type="button"
                            onClick={() => setPayingMilestoneId(r.payment_id)}
                            className="px-2.5 py-1 text-xs font-medium bg-foreground text-background rounded hover:bg-foreground/90 transition-colors"
                          >
                            Tandai Lunas
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>

          {/* Laporan Profit Per Proyek Freelance */}
          <div className="space-y-3">
            <h2 className="text-base font-semibold text-foreground flex items-center gap-2">
              <TrendingUp className="w-4 h-4 text-muted-foreground" />
              Laporan Profitabilitas Proyek Freelance
            </h2>

            {profitData.length === 0 ? (
              <div className="p-6 text-center text-xs text-muted-foreground border border-dashed border-border rounded-lg">
                Belum ada data profitabilitas proyek freelance.
              </div>
            ) : (
              <div className="border border-border rounded-lg overflow-hidden bg-card">
                <table className="w-full text-xs text-left">
                  <thead className="bg-muted/50 border-b border-border text-muted-foreground font-medium">
                    <tr>
                      <th className="px-4 py-2.5">Proyek</th>
                      <th className="px-4 py-2.5">Nilai Kontrak</th>
                      <th className="px-4 py-2.5">Total Diterima</th>
                      <th className="px-4 py-2.5">Pengeluaran & Potongan</th>
                      <th className="px-4 py-2.5">Profit Bersih</th>
                      <th className="px-4 py-2.5">Margin %</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-border">
                    {profitData
                      .filter((p) => p.kind === 'freelance')
                      .map((p) => (
                        <tr key={p.project_id} className="hover:bg-muted/30">
                          <td className="px-4 py-3 font-medium text-foreground">
                            {p.project_name}
                            {p.client_name && (
                              <div className="text-[11px] text-muted-foreground">{p.client_name}</div>
                            )}
                          </td>
                          <td className="px-4 py-3">
                            {p.contract_value ? formatCurrency(p.contract_value) : '-'}
                          </td>
                          <td className="px-4 py-3 font-medium text-emerald-600 dark:text-emerald-400">
                            {formatCurrency(p.total_paid)}
                          </td>
                          <td className="px-4 py-3 text-expense">
                            {formatCurrency(Number(p.total_expense) + Number(p.platform_fee_deducted))}
                          </td>
                          <td className="px-4 py-3 font-semibold text-foreground">
                            {formatCurrency(p.net_profit)}
                          </td>
                          <td className="px-4 py-3 font-medium">
                            {p.margin_percent}%
                          </td>
                        </tr>
                      ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Modal Tambah / Edit Proyek */}
      {showProjectModal && (
        <div className="fixed inset-0 z-50 bg-background/80 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
          <form
            onSubmit={handleSaveProject}
            className="bg-card border border-border rounded-lg shadow-lg max-w-lg w-full p-6 space-y-4 my-8"
          >
            <div className="flex items-center justify-between">
              <h3 className="font-semibold text-base text-foreground">
                {modalMode === 'create' ? 'Tambah Kegiatan Baru' : 'Edit Kegiatan'}
              </h3>
              <button
                type="button"
                onClick={() => setShowProjectModal(false)}
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
                  Nama Kegiatan / Proyek
                </label>
                <input
                  type="text"
                  required
                  placeholder="Misal: Redesign Mobile App atau Magang Frontend"
                  value={formName}
                  onChange={(e) => setFormName(e.target.value)}
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
                    disabled={modalMode === 'edit'}
                    onChange={(e) => setFormKind(e.target.value as ActivityKind)}
                    className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground disabled:opacity-50"
                  >
                    <option value="freelance">Freelance</option>
                    <option value="intern">Magang</option>
                    <option value="kuliah">Kuliah</option>
                    <option value="pribadi">Pribadi</option>
                  </select>
                </div>

                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">
                    Status
                  </label>
                  <select
                    value={formStatus}
                    onChange={(e) => setFormStatus(e.target.value as ProjectStatus)}
                    className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
                  >
                    <option value="draft">Draft</option>
                    <option value="berjalan">Berjalan</option>
                    <option value="selesai">Selesai</option>
                    <option value="dibatalkan">Dibatalkan</option>
                  </select>
                </div>
              </div>

              {/* Form Khusus Freelance */}
              {formKind === 'freelance' && (
                <div className="p-3 rounded-lg border border-purple-500/30 bg-purple-500/5 space-y-3">
                  <div className="text-xs font-semibold text-purple-600 dark:text-purple-400">
                    Parameter Proyek Freelance
                  </div>

                  <div>
                    <label className="text-xs font-medium text-foreground block mb-1">
                      Nama Klien
                    </label>
                    <input
                      type="text"
                      placeholder="Misal: PT Teknologi Cemerlang"
                      value={formClientName}
                      onChange={(e) => setFormClientName(e.target.value)}
                      className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
                    />
                  </div>

                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="text-xs font-medium text-foreground block mb-1">
                        Nilai Kontrak (IDR)
                      </label>
                      <input
                        type="number"
                        min="0"
                        step="any"
                        placeholder="10000000"
                        value={formContractValue}
                        onChange={(e) => setFormContractValue(e.target.value)}
                        className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
                      />
                    </div>

                    <div>
                      <label className="text-xs font-medium text-foreground block mb-1">
                        Potongan Platform (%)
                      </label>
                      <input
                        type="number"
                        min="0"
                        max="100"
                        step="any"
                        placeholder="10"
                        value={formFeePercent}
                        onChange={(e) => setFormFeePercent(e.target.value)}
                        className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
                      />
                    </div>
                  </div>

                  <div>
                    <label className="text-xs font-medium text-foreground block mb-1">
                      Metode Potongan Platform
                    </label>
                    <select
                      value={formFeeMode}
                      onChange={(e) => setFormFeeMode(e.target.value as FeeMode)}
                      className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
                    >
                      <option value="expense_transaction">
                        Catat otomatis sebagai transaksi pengeluaran
                      </option>
                      <option value="profit_deduction">
                        Pengurang di profit tanpa transaksi
                      </option>
                    </select>
                  </div>
                </div>
              )}

              {/* Form Khusus Kuliah */}
              {formKind === 'kuliah' && (
                <div className="p-3 rounded-lg border border-amber-500/30 bg-amber-500/5 space-y-3">
                  <div className="text-xs font-semibold text-amber-600 dark:text-amber-400">
                    Parameter Mata Kuliah
                  </div>

                  <div className="grid grid-cols-3 gap-2">
                    <div>
                      <label className="text-xs font-medium text-foreground block mb-1">
                        Semester
                      </label>
                      <input
                        type="number"
                        min="1"
                        max="20"
                        value={formSemester}
                        onChange={(e) => setFormSemester(e.target.value)}
                        className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
                      />
                    </div>
                    <div>
                      <label className="text-xs font-medium text-foreground block mb-1">
                        Kode MK
                      </label>
                      <input
                        type="text"
                        placeholder="CS101"
                        value={formCourseCode}
                        onChange={(e) => setFormCourseCode(e.target.value)}
                        className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
                      />
                    </div>
                    <div>
                      <label className="text-xs font-medium text-foreground block mb-1">
                        SKS
                      </label>
                      <input
                        type="number"
                        min="0"
                        max="30"
                        value={formCredits}
                        onChange={(e) => setFormCredits(e.target.value)}
                        className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
                      />
                    </div>
                  </div>
                </div>
              )}

              {/* Form Khusus Magang */}
              {formKind === 'intern' && (
                <div className="p-3 rounded-lg border border-blue-500/30 bg-blue-500/5 space-y-3">
                  <div className="text-xs font-semibold text-blue-600 dark:text-blue-400">
                    Parameter Magang
                  </div>

                  <div>
                    <label className="text-xs font-medium text-foreground block mb-1">
                      Nama Instansi / Perusahaan
                    </label>
                    <input
                      type="text"
                      placeholder="Misal: Startup XYZ"
                      value={formClientName}
                      onChange={(e) => setFormClientName(e.target.value)}
                      className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
                    />
                  </div>

                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="text-xs font-medium text-foreground block mb-1">
                        Uang Saku per Bulan (IDR)
                      </label>
                      <input
                        type="number"
                        min="0"
                        step="any"
                        placeholder="3500000"
                        value={formStipendAmount}
                        onChange={(e) => setFormStipendAmount(e.target.value)}
                        className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
                      />
                    </div>
                    <div>
                      <label className="text-xs font-medium text-foreground block mb-1">
                        Tanggal Cair Tiap Bulan
                      </label>
                      <input
                        type="number"
                        min="1"
                        max="31"
                        value={formStipendDay}
                        onChange={(e) => setFormStipendDay(e.target.value)}
                        className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
                      />
                    </div>
                  </div>
                </div>
              )}

              {/* Tanggal & Deskripsi */}
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">
                    Tanggal Mulai
                  </label>
                  <input
                    type="date"
                    value={formStartedOn}
                    onChange={(e) => setFormStartedOn(e.target.value)}
                    className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
                  />
                </div>
                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">
                    Tenggat / Selesai
                  </label>
                  <input
                    type="date"
                    value={formDeadline}
                    onChange={(e) => setFormDeadline(e.target.value)}
                    className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
                  />
                </div>
              </div>

              <div>
                <label className="text-xs font-medium text-foreground block mb-1">
                  Deskripsi / Catatan Tambahan
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
                onClick={() => setShowProjectModal(false)}
                className="px-3 py-1.5 text-xs font-medium border border-border rounded-md hover:bg-muted text-muted-foreground transition-colors"
              >
                Batal
              </button>
              <button
                type="submit"
                disabled={savingProject}
                className="px-3 py-1.5 text-xs font-medium bg-foreground text-background rounded-md hover:bg-foreground/90 transition-colors disabled:opacity-50"
              >
                {savingProject ? 'Menyimpan...' : 'Simpan Kegiatan'}
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Modal Milestone Pembayaran Proyek */}
      {selectedProjectForPayments && (
        <div className="fixed inset-0 z-50 bg-background/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-card border border-border rounded-lg shadow-lg max-w-xl w-full p-6 space-y-4">
            <div className="flex items-center justify-between">
              <div>
                <h3 className="font-semibold text-base text-foreground">
                  Milestone Pembayaran: {selectedProjectForPayments.name}
                </h3>
                <p className="text-xs text-muted-foreground mt-0.5">
                  Nilai Kontrak: {selectedProjectForPayments.contract_value ? formatCurrency(selectedProjectForPayments.contract_value) : '-'}
                </p>
              </div>
              <button
                type="button"
                onClick={() => setSelectedProjectForPayments(null)}
                className="text-muted-foreground hover:text-foreground"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            <div className="flex justify-end">
              <button
                type="button"
                onClick={() => setShowAddMilestoneModal(true)}
                className="flex items-center gap-1 px-2.5 py-1 text-xs font-medium bg-foreground text-background rounded hover:bg-foreground/90 transition-colors"
              >
                <Plus className="w-3.5 h-3.5" />
                <span>Tambah Termin / Milestone</span>
              </button>
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
                    className="p-3 rounded-lg border border-border bg-muted/20 flex items-center justify-between gap-3 text-xs"
                  >
                    <div>
                      <div className="font-medium text-foreground">{pm.label}</div>
                      <div className="text-muted-foreground text-[11px]">
                        Nominal: {formatCurrency(pm.amount)} • Tenggat: {pm.due_date ? formatDateIndo(pm.due_date) : '-'}
                      </div>
                    </div>

                    <div className="flex items-center gap-2">
                      {pm.status === 'paid' ? (
                        <>
                          <span className="flex items-center gap-1 text-emerald-600 dark:text-emerald-400 font-medium">
                            <CheckCircle2 className="w-3.5 h-3.5" /> Lunas
                          </span>
                          <button
                            type="button"
                            disabled={processingPayment}
                            onClick={() => handleCancelPaymentPaid(pm.id)}
                            className="text-muted-foreground hover:text-expense underline text-[11px]"
                          >
                            Batal Lunas
                          </button>
                        </>
                      ) : (
                        <button
                          type="button"
                          onClick={() => setPayingMilestoneId(pm.id)}
                          className="px-2 py-1 bg-foreground text-background rounded text-[11px] font-medium hover:bg-foreground/90 transition-colors"
                        >
                          Tandai Lunas
                        </button>
                      )}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}

      {/* Modal Tambah Milestone */}
      {showAddMilestoneModal && (
        <div className="fixed inset-0 z-50 bg-background/80 backdrop-blur-sm flex items-center justify-center p-4">
          <form
            onSubmit={handleAddMilestone}
            className="bg-card border border-border rounded-lg shadow-lg max-w-sm w-full p-6 space-y-4"
          >
            <h3 className="font-semibold text-base text-foreground">
              Tambah Milestone Pembayaran
            </h3>

            <div className="space-y-3">
              <div>
                <label className="text-xs font-medium text-foreground block mb-1">
                  Label Termin
                </label>
                <input
                  type="text"
                  required
                  placeholder="Misal: DP 50% atau Termin 2"
                  value={milestoneLabel}
                  onChange={(e) => setMilestoneLabel(e.target.value)}
                  className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
                />
              </div>

              <div>
                <label className="text-xs font-medium text-foreground block mb-1">
                  Nominal (IDR)
                </label>
                <input
                  type="number"
                  min="0"
                  step="any"
                  required
                  placeholder="5000000"
                  value={milestoneAmount}
                  onChange={(e) => setMilestoneAmount(e.target.value)}
                  className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
                />
              </div>

              <div>
                <label className="text-xs font-medium text-foreground block mb-1">
                  Tanggal Jatuh Tempo
                </label>
                <input
                  type="date"
                  value={milestoneDueDate}
                  onChange={(e) => setMilestoneDueDate(e.target.value)}
                  className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
                />
              </div>
            </div>

            <div className="flex justify-end gap-2 pt-2">
              <button
                type="button"
                onClick={() => setShowAddMilestoneModal(false)}
                className="px-3 py-1.5 text-xs font-medium border border-border rounded-md hover:bg-muted text-muted-foreground transition-colors"
              >
                Batal
              </button>
              <button
                type="submit"
                disabled={savingMilestone}
                className="px-3 py-1.5 text-xs font-medium bg-foreground text-background rounded-md hover:bg-foreground/90 transition-colors disabled:opacity-50"
              >
                {savingMilestone ? 'Menyimpan...' : 'Simpan Milestone'}
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Modal Dialog Pelunasan Cepat dengan Pemilihan Akun */}
      {payingMilestoneId && (
        <div className="fixed inset-0 z-50 bg-background/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-card border border-border rounded-lg shadow-lg max-w-sm w-full p-6 space-y-4">
            <h3 className="font-semibold text-base text-foreground">
              Konfirmasi Akun Penerima
            </h3>
            <p className="text-xs text-muted-foreground">
              Pilih akun tujuan pemasukan dana saat menandai pembayaran ini lunas.
            </p>

            <div className="space-y-2">
              <label className="text-xs font-medium text-foreground block">
                Akun Kas / Rekening
              </label>
              <select
                value={payAccountId}
                onChange={(e) => setPayAccountId(e.target.value)}
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
                onClick={() => setPayingMilestoneId(null)}
                className="px-3 py-1.5 text-xs font-medium border border-border rounded-md hover:bg-muted text-muted-foreground transition-colors"
              >
                Batal
              </button>
              <button
                type="button"
                disabled={processingPayment}
                onClick={() => handleMarkPaymentPaid(payingMilestoneId)}
                className="px-3 py-1.5 text-xs font-medium bg-foreground text-background rounded-md hover:bg-foreground/90 transition-colors disabled:opacity-50"
              >
                {processingPayment ? 'Memproses...' : 'Tandai Lunas'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
