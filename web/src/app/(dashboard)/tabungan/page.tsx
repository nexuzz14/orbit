'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';
import { formatCurrency, formatDateIndo } from '@/lib/format';
import type {
  SavingsGoal,
  IncomeSplitRule,
  SavingsAllocation,
  TransactionSource,
} from '@/types/database';
import {
  Target,
  Plus,
  Edit2,
  Trash2,
  CheckCircle2,
  RefreshCw,
  X,
  Layers,
  ArrowRightLeft,
  History,
  Coins
} from 'lucide-react';

interface ExtendedSplitRule extends IncomeSplitRule {
  goal?: { name: string } | null;
}

interface ExtendedAllocation extends SavingsAllocation {
  goal?: { name: string } | null;
  transaction?: {
    description: string | null;
    amount: number;
    occurred_at: string;
  } | null;
}

export default function TabunganPage() {
  const supabase = createClient();
  const [activeTab, setActiveTab] = useState<'goals' | 'rules' | 'history'>('goals');
  const [workspaceId, setWorkspaceId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  // Goals state
  const [goals, setGoals] = useState<SavingsGoal[]>([]);
  const [showGoalModal, setShowGoalModal] = useState(false);
  const [goalMode, setGoalMode] = useState<'create' | 'edit'>('create');
  const [editingGoalId, setEditingGoalId] = useState<string | null>(null);
  const [goalName, setGoalName] = useState('');
  const [goalTargetAmount, setGoalTargetAmount] = useState('');
  const [goalCurrentAmount, setGoalCurrentAmount] = useState('0');
  const [goalTargetDate, setGoalTargetDate] = useState('');
  const [goalNotes, setGoalNotes] = useState('');
  const [goalError, setGoalError] = useState<string | null>(null);

  // Manual Deposit Modal
  const [showDepositModal, setShowDepositModal] = useState(false);
  const [depositingGoal, setDepositingGoal] = useState<SavingsGoal | null>(null);
  const [depositAmount, setDepositAmount] = useState('');
  const [depositError, setDepositError] = useState<string | null>(null);

  // Split Rules state
  const [rules, setRules] = useState<ExtendedSplitRule[]>([]);
  const [showRuleModal, setShowRuleModal] = useState(false);
  const [ruleMode, setRuleMode] = useState<'create' | 'edit'>('create');
  const [editingRuleId, setEditingRuleId] = useState<string | null>(null);
  const [ruleSource, setRuleSource] = useState<TransactionSource>('freelance');
  const [ruleGoalId, setRuleGoalId] = useState('');
  const [ruleSplitType, setRuleSplitType] = useState<'percentage' | 'fixed_amount'>('percentage');
  const [ruleSplitValue, setRuleSplitValue] = useState('20');
  const [rulePriority, setRulePriority] = useState('1');
  const [ruleActive, setRuleActive] = useState(true);
  const [ruleError, setRuleError] = useState<string | null>(null);

  // Allocations history
  const [allocations, setAllocations] = useState<ExtendedAllocation[]>([]);

  const [submitting, setSubmitting] = useState(false);

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

    setWorkspaceId(memberData.workspace_id);

    // Fetch savings goals
    const { data: goalsData } = await supabase
      .from('savings_goals')
      .select('*')
      .eq('workspace_id', memberData.workspace_id)
      .is('deleted_at', null)
      .order('created_at', { ascending: false });

    if (goalsData) {
      setGoals(goalsData);
      if (goalsData.length > 0 && !ruleGoalId) {
        setRuleGoalId(goalsData[0].id);
      }
    }

    // Fetch income split rules
    const { data: rulesData } = await supabase
      .from('income_split_rules')
      .select(`
        *,
        goal:savings_goals(name)
      `)
      .eq('workspace_id', memberData.workspace_id)
      .is('deleted_at', null)
      .order('priority', { ascending: true });

    if (rulesData) {
      setRules(rulesData as unknown as ExtendedSplitRule[]);
    }

    // Fetch allocations history
    const { data: allocData } = await supabase
      .from('savings_allocations')
      .select(`
        *,
        goal:savings_goals(name),
        transaction:transactions(description, amount, occurred_at)
      `)
      .eq('workspace_id', memberData.workspace_id)
      .is('deleted_at', null)
      .order('created_at', { ascending: false })
      .limit(50);

    if (allocData) {
      setAllocations(allocData as unknown as ExtendedAllocation[]);
    }

    setLoading(false);
  }, [supabase, ruleGoalId]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  // Goal handlers
  const openCreateGoal = () => {
    setGoalName('');
    setGoalTargetAmount('');
    setGoalCurrentAmount('0');
    setGoalTargetDate('');
    setGoalNotes('');
    setGoalError(null);
    setGoalMode('create');
    setEditingGoalId(null);
    setShowGoalModal(true);
  };

  const openEditGoal = (goal: SavingsGoal) => {
    setEditingGoalId(goal.id);
    setGoalName(goal.name);
    setGoalTargetAmount(goal.target_amount.toString());
    setGoalCurrentAmount(goal.current_amount.toString());
    setGoalTargetDate(goal.target_date || '');
    setGoalNotes(goal.notes || '');
    setGoalError(null);
    setGoalMode('edit');
    setShowGoalModal(true);
  };

  const handleSaveGoal = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!workspaceId) return;

    const numTarget = parseFloat(goalTargetAmount.replace(/[^0-9.]/g, ''));
    if (isNaN(numTarget) || numTarget <= 0) {
      setGoalError('Target nominal tabungan harus lebih besar dari 0.');
      return;
    }

    const numCurrent = parseFloat(goalCurrentAmount.replace(/[^0-9.]/g, '') || '0');

    setSubmitting(true);
    setGoalError(null);

    try {
      const payload = {
        workspace_id: workspaceId,
        name: goalName.trim(),
        target_amount: numTarget,
        current_amount: numCurrent,
        target_date: goalTargetDate || null,
        notes: goalNotes.trim() || null,
        is_completed: numCurrent >= numTarget,
      };

      if (goalMode === 'create') {
        const { error } = await supabase.from('savings_goals').insert(payload);
        if (error) throw error;
      } else if (editingGoalId) {
        const { error } = await supabase
          .from('savings_goals')
          .update(payload)
          .eq('id', editingGoalId);
        if (error) throw error;
      }

      setShowGoalModal(false);
      await loadData();
    } catch (err: unknown) {
      setGoalError(err instanceof Error ? err.message : 'Gagal menyimpan target tabungan.');
    } finally {
      setSubmitting(false);
    }
  };

  const handleDeleteGoal = async (goalId: string) => {
    const confirmDelete = window.confirm('Hapus target tabungan ini? Aturan split terkait akan terhapus.');
    if (!confirmDelete) return;

    const { error } = await supabase
      .from('savings_goals')
      .update({ deleted_at: new Date().toISOString() })
      .eq('id', goalId);

    if (error) {
      alert(`Gagal menghapus: ${error.message}`);
    } else {
      await loadData();
    }
  };

  const openDepositModal = (goal: SavingsGoal) => {
    setDepositingGoal(goal);
    setDepositAmount('');
    setDepositError(null);
    setShowDepositModal(true);
  };

  const handleManualDeposit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!depositingGoal) return;

    const numAdd = parseFloat(depositAmount.replace(/[^0-9.]/g, ''));
    if (isNaN(numAdd) || numAdd <= 0) {
      setDepositError('Nominal setor harus lebih dari 0.');
      return;
    }

    setSubmitting(true);
    setDepositError(null);

    try {
      const newTotal = Number(depositingGoal.current_amount) + numAdd;
      const isCompleted = newTotal >= Number(depositingGoal.target_amount);

      const { error } = await supabase
        .from('savings_goals')
        .update({
          current_amount: newTotal,
          is_completed: isCompleted,
        })
        .eq('id', depositingGoal.id);

      if (error) throw error;

      setShowDepositModal(false);
      await loadData();
    } catch (err: unknown) {
      setDepositError(err instanceof Error ? err.message : 'Gagal menambah setoran.');
    } finally {
      setSubmitting(false);
    }
  };

  // Rule handlers
  const openCreateRule = () => {
    if (goals.length > 0) setRuleGoalId(goals[0].id);
    setRuleSource('freelance');
    setRuleSplitType('percentage');
    setRuleSplitValue('20');
    setRulePriority('1');
    setRuleActive(true);
    setRuleError(null);
    setRuleMode('create');
    setEditingRuleId(null);
    setShowRuleModal(true);
  };

  const openEditRule = (rule: ExtendedSplitRule) => {
    setEditingRuleId(rule.id);
    setRuleSource(rule.source);
    setRuleGoalId(rule.goal_id);
    setRuleSplitType(rule.split_type as 'percentage' | 'fixed_amount');
    setRuleSplitValue(rule.split_value.toString());
    setRulePriority(rule.priority.toString());
    setRuleActive(rule.active);
    setRuleError(null);
    setRuleMode('edit');
    setShowRuleModal(true);
  };

  const handleSaveRule = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!workspaceId) return;

    const numVal = parseFloat(ruleSplitValue);
    if (isNaN(numVal) || numVal <= 0) {
      setRuleError('Nilai split harus lebih dari 0.');
      return;
    }
    if (ruleSplitType === 'percentage' && numVal > 100) {
      setRuleError('Persentase split tidak boleh melebihi 100%.');
      return;
    }

    const numPriority = parseInt(rulePriority, 10);

    setSubmitting(true);
    setRuleError(null);

    try {
      const payload = {
        workspace_id: workspaceId,
        source: ruleSource,
        goal_id: ruleGoalId,
        split_type: ruleSplitType,
        split_value: numVal,
        priority: numPriority,
        active: ruleActive,
      };

      if (ruleMode === 'create') {
        const { error } = await supabase.from('income_split_rules').insert(payload);
        if (error) throw error;
      } else if (editingRuleId) {
        const { error } = await supabase
          .from('income_split_rules')
          .update(payload)
          .eq('id', editingRuleId);
        if (error) throw error;
      }

      setShowRuleModal(false);
      await loadData();
    } catch (err: unknown) {
      setRuleError(err instanceof Error ? err.message : 'Gagal menyimpan aturan split.');
    } finally {
      setSubmitting(false);
    }
  };

  const handleDeleteRule = async (ruleId: string) => {
    const confirmDelete = window.confirm('Hapus aturan split pemasukan ini?');
    if (!confirmDelete) return;

    const { error } = await supabase
      .from('income_split_rules')
      .update({ deleted_at: new Date().toISOString() })
      .eq('id', ruleId);

    if (error) {
      alert(`Gagal menghapus: ${error.message}`);
    } else {
      await loadData();
    }
  };

  const totalTarget = goals.reduce((acc, g) => acc + Number(g.target_amount), 0);
  const totalSaved = goals.reduce((acc, g) => acc + Number(g.current_amount), 0);
  const completedGoalsCount = goals.filter((g) => g.is_completed).length;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Tabungan & Auto-Split</h1>
          <p className="text-sm text-muted-foreground mt-1">
            Target masa depan dan alokasi otomatis dari setiap pemasukan yang dikonfirmasi.
          </p>
        </div>

        <div className="flex items-center gap-2">
          {activeTab === 'goals' && (
            <button
              onClick={openCreateGoal}
              type="button"
              className="flex items-center gap-2 bg-primary text-primary-foreground px-4 py-2 rounded-md text-sm font-medium hover:bg-primary/90 transition-colors"
            >
              <Plus className="w-4 h-4" />
              <span>Target Baru</span>
            </button>
          )}

          {activeTab === 'rules' && (
            <button
              onClick={openCreateRule}
              type="button"
              disabled={goals.length === 0}
              className="flex items-center gap-2 bg-primary text-primary-foreground px-4 py-2 rounded-md text-sm font-medium hover:bg-primary/90 transition-colors disabled:opacity-50"
            >
              <Plus className="w-4 h-4" />
              <span>Aturan Baru</span>
            </button>
          )}
        </div>
      </div>

      {/* Tabs */}
      <div className="flex border-b border-border space-x-6 text-sm font-medium">
        <button
          onClick={() => setActiveTab('goals')}
          className={`pb-3 flex items-center gap-2 transition-colors relative ${
            activeTab === 'goals'
              ? 'text-primary border-b-2 border-primary font-semibold'
              : 'text-muted-foreground hover:text-foreground'
          }`}
        >
          <Target className="w-4 h-4" />
          <span>Target Tabungan ({goals.length})</span>
        </button>

        <button
          onClick={() => setActiveTab('rules')}
          className={`pb-3 flex items-center gap-2 transition-colors relative ${
            activeTab === 'rules'
              ? 'text-primary border-b-2 border-primary font-semibold'
              : 'text-muted-foreground hover:text-foreground'
          }`}
        >
          <ArrowRightLeft className="w-4 h-4" />
          <span>Aturan Auto-Split ({rules.length})</span>
        </button>

        <button
          onClick={() => setActiveTab('history')}
          className={`pb-3 flex items-center gap-2 transition-colors relative ${
            activeTab === 'history'
              ? 'text-primary border-b-2 border-primary font-semibold'
              : 'text-muted-foreground hover:text-foreground'
          }`}
        >
          <History className="w-4 h-4" />
          <span>Riwayat Alokasi ({allocations.length})</span>
        </button>
      </div>

      {/* Tab 1: Savings Goals */}
      {activeTab === 'goals' && (
        <div className="space-y-6">
          {/* Ringkasan Cards */}
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="p-4 rounded-lg border border-border bg-card">
              <div className="text-xs font-medium text-muted-foreground uppercase">
                Total Terkumpul
              </div>
              <div className="text-2xl font-bold mt-1 tracking-tight text-income">
                {formatCurrency(totalSaved)}
              </div>
              <div className="text-xs text-muted-foreground mt-1">
                Dari target total {formatCurrency(totalTarget)}
              </div>
            </div>

            <div className="p-4 rounded-lg border border-border bg-card">
              <div className="text-xs font-medium text-muted-foreground uppercase">
                Kemajuan Keseluruhan
              </div>
              <div className="text-2xl font-bold mt-1 tracking-tight text-foreground">
                {totalTarget > 0 ? `${Math.round((totalSaved / totalTarget) * 100)}%` : '0%'}
              </div>
              <div className="text-xs text-muted-foreground mt-1">
                {completedGoalsCount} dari {goals.length} target tercapai
              </div>
            </div>

            <div className="p-4 rounded-lg border border-border bg-card flex flex-col justify-center">
              <div className="text-xs font-medium text-muted-foreground uppercase">
                Alokasi Otomatis
              </div>
              <div className="flex items-center gap-2 mt-1.5 text-xs text-muted-foreground">
                <Coins className="w-4 h-4 text-primary" />
                <span>Auto-split virtual membagi pemasukan saat dikonfirmasi</span>
              </div>
            </div>
          </div>

          {/* Goals List */}
          <div className="bg-card border border-border rounded-lg overflow-hidden">
            <div className="p-4 border-b border-border flex justify-between items-center">
              <h2 className="font-medium text-sm flex items-center gap-2">
                <Target className="w-4 h-4 text-primary" />
                <span>Daftar Target Keuangan</span>
              </h2>
              <button
                onClick={() => loadData()}
                type="button"
                className="text-xs text-muted-foreground hover:text-foreground flex items-center gap-1"
              >
                <RefreshCw className="w-3 h-3" />
                <span>Muat Ulang</span>
              </button>
            </div>

            {loading ? (
              <div className="p-8 text-center text-sm text-muted-foreground">Memuat target...</div>
            ) : goals.length === 0 ? (
              <div className="p-8 text-center">
                <Layers className="w-8 h-8 text-muted-foreground mx-auto mb-2 opacity-50" />
                <div className="text-sm font-medium">Belum ada target tabungan</div>
                <p className="text-xs text-muted-foreground mt-1 max-w-sm mx-auto">
                  Tentukan target dana darurat, laptop baru, atau liburan untuk mulai menabung.
                </p>
                <button
                  onClick={openCreateGoal}
                  type="button"
                  className="mt-4 inline-flex items-center gap-2 bg-primary text-primary-foreground px-3 py-1.5 rounded-md text-xs font-medium"
                >
                  <Plus className="w-3.5 h-3.5" />
                  <span>Buat Target Pertama</span>
                </button>
              </div>
            ) : (
              <div className="divide-y divide-border">
                {goals.map((goal) => {
                  const targetNum = Number(goal.target_amount);
                  const currentNum = Number(goal.current_amount);
                  const pct =
                    targetNum > 0 ? Math.min(Math.round((currentNum / targetNum) * 100), 100) : 0;

                  return (
                    <div key={goal.id} className="p-4 space-y-3 hover:bg-muted/30 transition-colors">
                      <div className="flex flex-col sm:flex-row justify-between sm:items-center gap-2">
                        <div className="space-y-1">
                          <div className="flex items-center gap-2">
                            <span className="font-semibold text-sm tracking-tight">{goal.name}</span>
                            {goal.is_completed ? (
                              <span className="text-[11px] px-2 py-0.5 rounded-full font-medium bg-income/10 text-income border border-income/20 flex items-center gap-1">
                                <CheckCircle2 className="w-3 h-3" />
                                <span>Tercapai</span>
                              </span>
                            ) : (
                              <span className="text-[11px] px-2 py-0.5 rounded-full font-medium bg-muted text-muted-foreground">
                                Sedang Berjalan
                              </span>
                            )}
                          </div>
                          {goal.target_date && (
                            <div className="text-xs text-muted-foreground">
                              Target selesai: {formatDateIndo(goal.target_date)}
                            </div>
                          )}
                          {goal.notes && (
                            <div className="text-xs text-muted-foreground italic">{goal.notes}</div>
                          )}
                        </div>

                        <div className="flex items-center gap-3">
                          <div className="text-right">
                            <div className="text-sm font-bold tracking-tight text-income">
                              {formatCurrency(currentNum)}{' '}
                              <span className="text-xs font-normal text-muted-foreground">
                                / {formatCurrency(targetNum)}
                              </span>
                            </div>
                            <div className="text-xs text-muted-foreground">{pct}% terkumpul</div>
                          </div>

                          <div className="flex items-center gap-1 pl-2 border-l border-border">
                            <button
                              onClick={() => openDepositModal(goal)}
                              type="button"
                              className="px-2.5 py-1 text-xs bg-muted hover:bg-muted/80 text-foreground font-medium rounded border border-border transition-colors flex items-center gap-1"
                              title="Setor Manual"
                            >
                              <Coins className="w-3 h-3 text-primary" />
                              <span>Setor</span>
                            </button>
                            <button
                              onClick={() => openEditGoal(goal)}
                              type="button"
                              className="p-1.5 text-muted-foreground hover:text-foreground rounded transition-colors"
                              title="Ubah Target"
                            >
                              <Edit2 className="w-3.5 h-3.5" />
                            </button>
                            <button
                              onClick={() => handleDeleteGoal(goal.id)}
                              type="button"
                              className="p-1.5 text-muted-foreground hover:text-expense rounded transition-colors"
                              title="Hapus Target"
                            >
                              <Trash2 className="w-3.5 h-3.5" />
                            </button>
                          </div>
                        </div>
                      </div>

                      {/* Progress Bar */}
                      <div className="w-full bg-muted rounded-full h-2 overflow-hidden">
                        <div
                          className={`h-full transition-all duration-300 ${
                            goal.is_completed ? 'bg-income' : 'bg-primary'
                          }`}
                          style={{ width: `${pct}%` }}
                        />
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        </div>
      )}

      {/* Tab 2: Split Rules */}
      {activeTab === 'rules' && (
        <div className="space-y-4">
          <div className="p-4 rounded-lg border border-border bg-card">
            <div className="text-sm font-semibold tracking-tight">Aturan Auto-Split Pemasukan</div>
            <p className="text-xs text-muted-foreground mt-1">
              Saat transaksi pemasukan dikonfirmasi (misalnya uang magang atau termin freelance),
              sistem otomatis mendistribusikan porsi pemasukan ke target tabungan secara virtual.
            </p>
          </div>

          <div className="bg-card border border-border rounded-lg overflow-hidden">
            <div className="p-4 border-b border-border flex justify-between items-center">
              <h2 className="font-medium text-sm flex items-center gap-2">
                <ArrowRightLeft className="w-4 h-4 text-primary" />
                <span>Daftar Aturan Pembagian</span>
              </h2>
              <button
                onClick={() => loadData()}
                type="button"
                className="text-xs text-muted-foreground hover:text-foreground flex items-center gap-1"
              >
                <RefreshCw className="w-3 h-3" />
                <span>Muat Ulang</span>
              </button>
            </div>

            {loading ? (
              <div className="p-8 text-center text-sm text-muted-foreground">Memuat aturan...</div>
            ) : rules.length === 0 ? (
              <div className="p-8 text-center">
                <Layers className="w-8 h-8 text-muted-foreground mx-auto mb-2 opacity-50" />
                <div className="text-sm font-medium">Belum ada aturan auto-split</div>
                <p className="text-xs text-muted-foreground mt-1 max-w-sm mx-auto">
                  Contoh: potong 20% dari setiap pemasukan freelance ke target &quot;Dana Darurat&quot;.
                </p>
                <button
                  onClick={openCreateRule}
                  disabled={goals.length === 0}
                  type="button"
                  className="mt-4 inline-flex items-center gap-2 bg-primary text-primary-foreground px-3 py-1.5 rounded-md text-xs font-medium disabled:opacity-50"
                >
                  <Plus className="w-3.5 h-3.5" />
                  <span>Buat Aturan Pertama</span>
                </button>
              </div>
            ) : (
              <div className="divide-y divide-border">
                {rules.map((rule) => {
                  const sourceLabels: Record<TransactionSource, string> = {
                    intern: 'Magang',
                    freelance: 'Freelance',
                    kuliah: 'Akademik/Beasiswa',
                    personal: 'Pribadi/Lainnya',
                  };

                  return (
                    <div
                      key={rule.id}
                      className={`p-4 flex flex-col sm:flex-row justify-between sm:items-center gap-3 hover:bg-muted/30 transition-colors ${
                        !rule.active ? 'opacity-60' : ''
                      }`}
                    >
                      <div className="space-y-1">
                        <div className="flex items-center gap-2">
                          <span className="text-xs px-2 py-0.5 rounded-full font-medium bg-primary/10 text-primary">
                            Sumber: {sourceLabels[rule.source] || rule.source}
                          </span>
                          <span className="text-xs text-muted-foreground">ke</span>
                          <span className="font-semibold text-sm">
                            {rule.goal?.name || 'Target Tidak Ditemukan'}
                          </span>
                          {!rule.active && (
                            <span className="text-[11px] px-2 py-0.5 rounded-full bg-muted text-muted-foreground">
                              Nonaktif
                            </span>
                          )}
                        </div>
                        <div className="text-xs text-muted-foreground">
                          Prioritas: {rule.priority} | Alokasi:{' '}
                          {rule.split_type === 'percentage'
                            ? `${rule.split_value}% dari pemasukan`
                            : formatCurrency(rule.split_value)}
                        </div>
                      </div>

                      <div className="flex items-center gap-1 pl-2 border-l border-border">
                        <button
                          onClick={() => openEditRule(rule)}
                          type="button"
                          className="p-1.5 text-muted-foreground hover:text-foreground rounded transition-colors"
                          title="Ubah Aturan"
                        >
                          <Edit2 className="w-3.5 h-3.5" />
                        </button>
                        <button
                          onClick={() => handleDeleteRule(rule.id)}
                          type="button"
                          className="p-1.5 text-muted-foreground hover:text-expense rounded transition-colors"
                          title="Hapus Aturan"
                        >
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        </div>
      )}

      {/* Tab 3: History */}
      {activeTab === 'history' && (
        <div className="bg-card border border-border rounded-lg overflow-hidden">
          <div className="p-4 border-b border-border flex justify-between items-center">
            <h2 className="font-medium text-sm flex items-center gap-2">
              <History className="w-4 h-4 text-primary" />
              <span>Riwayat Alokasi Virtual Auto-Split</span>
            </h2>
            <button
              onClick={() => loadData()}
              type="button"
              className="text-xs text-muted-foreground hover:text-foreground flex items-center gap-1"
            >
              <RefreshCw className="w-3 h-3" />
              <span>Muat Ulang</span>
            </button>
          </div>

          {loading ? (
            <div className="p-8 text-center text-sm text-muted-foreground">Memuat riwayat...</div>
          ) : allocations.length === 0 ? (
            <div className="p-8 text-center text-sm text-muted-foreground">
              Belum ada alokasi virtual yang tercatat. Alokasi akan muncul otomatis saat pemasukan
              dikonfirmasi.
            </div>
          ) : (
            <div className="divide-y divide-border">
              {allocations.map((alloc) => (
                <div key={alloc.id} className="p-4 flex justify-between items-center hover:bg-muted/30">
                  <div className="space-y-1">
                    <div className="font-medium text-sm">
                      {alloc.goal?.name || 'Target Tabungan'}
                    </div>
                    <div className="text-xs text-muted-foreground">
                      Dari transaksi: {alloc.transaction?.description || 'Pemasukan'} (
                      {alloc.transaction?.occurred_at
                        ? formatDateIndo(alloc.transaction.occurred_at)
                        : '-'}
                      )
                    </div>
                    {alloc.note && (
                      <div className="text-xs text-muted-foreground italic">{alloc.note}</div>
                    )}
                  </div>
                  <div className="text-right font-bold text-sm text-income">
                    +{formatCurrency(alloc.amount)}
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>
      )}

      {/* Modal Target Tabungan */}
      {showGoalModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="bg-card border border-border rounded-lg max-w-md w-full p-6 space-y-4">
            <div className="flex justify-between items-center">
              <h3 className="font-semibold text-lg tracking-tight">
                {goalMode === 'create' ? 'Tambah Target Tabungan' : 'Ubah Target Tabungan'}
              </h3>
              <button
                onClick={() => setShowGoalModal(false)}
                type="button"
                className="text-muted-foreground hover:text-foreground"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {goalError && (
              <div className="p-3 text-xs bg-expense/10 text-expense border border-expense/20 rounded-md">
                {goalError}
              </div>
            )}

            <form onSubmit={handleSaveGoal} className="space-y-4">
              <div className="space-y-1">
                <label className="text-xs font-medium text-muted-foreground">Nama Target</label>
                <input
                  type="text"
                  value={goalName}
                  onChange={(e) => setGoalName(e.target.value)}
                  placeholder="Contoh: Dana Darurat 6 Bulan"
                  className="w-full px-3 py-2 text-sm bg-background border border-input rounded-md focus:outline-none focus:ring-1 focus:ring-ring"
                  required
                />
              </div>

              <div className="space-y-1">
                <label className="text-xs font-medium text-muted-foreground">Target Nominal (IDR)</label>
                <input
                  type="number"
                  step="any"
                  min="0"
                  value={goalTargetAmount}
                  onChange={(e) => setGoalTargetAmount(e.target.value)}
                  placeholder="Contoh: 10000000"
                  className="w-full px-3 py-2 text-sm bg-background border border-input rounded-md focus:outline-none focus:ring-1 focus:ring-ring"
                  required
                />
              </div>

              <div className="space-y-1">
                <label className="text-xs font-medium text-muted-foreground">Saldo Awal Terkumpul (IDR)</label>
                <input
                  type="number"
                  step="any"
                  min="0"
                  value={goalCurrentAmount}
                  onChange={(e) => setGoalCurrentAmount(e.target.value)}
                  className="w-full px-3 py-2 text-sm bg-background border border-input rounded-md focus:outline-none focus:ring-1 focus:ring-ring"
                />
              </div>

              <div className="space-y-1">
                <label className="text-xs font-medium text-muted-foreground">Target Tanggal (Opsional)</label>
                <input
                  type="date"
                  value={goalTargetDate}
                  onChange={(e) => setGoalTargetDate(e.target.value)}
                  className="w-full px-3 py-2 text-sm bg-background border border-input rounded-md focus:outline-none focus:ring-1 focus:ring-ring"
                />
              </div>

              <div className="space-y-1">
                <label className="text-xs font-medium text-muted-foreground">Catatan</label>
                <input
                  type="text"
                  value={goalNotes}
                  onChange={(e) => setGoalNotes(e.target.value)}
                  placeholder="Catatan tujuan atau prioritas"
                  className="w-full px-3 py-2 text-sm bg-background border border-input rounded-md focus:outline-none focus:ring-1 focus:ring-ring"
                />
              </div>

              <div className="flex justify-end gap-2 pt-4 border-t border-border">
                <button
                  type="button"
                  onClick={() => setShowGoalModal(false)}
                  className="px-4 py-2 text-sm text-muted-foreground hover:text-foreground rounded-md transition-colors"
                >
                  Batal
                </button>
                <button
                  type="submit"
                  disabled={submitting}
                  className="px-4 py-2 text-sm bg-primary text-primary-foreground font-medium rounded-md hover:bg-primary/90 transition-colors disabled:opacity-50"
                >
                  {submitting ? 'Menyimpan...' : 'Simpan Target'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal Setor Manual */}
      {showDepositModal && depositingGoal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="bg-card border border-border rounded-lg max-w-sm w-full p-6 space-y-4">
            <div className="flex justify-between items-center">
              <h3 className="font-semibold text-lg tracking-tight">Setor ke Tabungan</h3>
              <button
                onClick={() => setShowDepositModal(false)}
                type="button"
                className="text-muted-foreground hover:text-foreground"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="text-xs text-muted-foreground">
              Target: <span className="font-semibold text-foreground">{depositingGoal.name}</span>
              <br />
              Saat ini: {formatCurrency(depositingGoal.current_amount)} /{' '}
              {formatCurrency(depositingGoal.target_amount)}
            </div>

            {depositError && (
              <div className="p-3 text-xs bg-expense/10 text-expense border border-expense/20 rounded-md">
                {depositError}
              </div>
            )}

            <form onSubmit={handleManualDeposit} className="space-y-4">
              <div className="space-y-1">
                <label className="text-xs font-medium text-muted-foreground">Nominal Setoran (IDR)</label>
                <input
                  type="number"
                  step="any"
                  min="0"
                  value={depositAmount}
                  onChange={(e) => setDepositAmount(e.target.value)}
                  placeholder="Contoh: 500000"
                  className="w-full px-3 py-2 text-sm bg-background border border-input rounded-md focus:outline-none focus:ring-1 focus:ring-ring"
                  required
                  autoFocus
                />
              </div>

              <div className="flex justify-end gap-2 pt-4 border-t border-border">
                <button
                  type="button"
                  onClick={() => setShowDepositModal(false)}
                  className="px-4 py-2 text-sm text-muted-foreground hover:text-foreground rounded-md transition-colors"
                >
                  Batal
                </button>
                <button
                  type="submit"
                  disabled={submitting}
                  className="px-4 py-2 text-sm bg-primary text-primary-foreground font-medium rounded-md hover:bg-primary/90 transition-colors disabled:opacity-50"
                >
                  {submitting ? 'Menyetor...' : 'Tambahkan Setoran'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Modal Aturan Auto-Split */}
      {showRuleModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="bg-card border border-border rounded-lg max-w-md w-full p-6 space-y-4">
            <div className="flex justify-between items-center">
              <h3 className="font-semibold text-lg tracking-tight">
                {ruleMode === 'create' ? 'Tambah Aturan Auto-Split' : 'Ubah Aturan Auto-Split'}
              </h3>
              <button
                onClick={() => setShowRuleModal(false)}
                type="button"
                className="text-muted-foreground hover:text-foreground"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {ruleError && (
              <div className="p-3 text-xs bg-expense/10 text-expense border border-expense/20 rounded-md">
                {ruleError}
              </div>
            )}

            <form onSubmit={handleSaveRule} className="space-y-4">
              <div className="space-y-1">
                <label className="text-xs font-medium text-muted-foreground">Sumber Pemasukan</label>
                <select
                  value={ruleSource}
                  onChange={(e) => setRuleSource(e.target.value as TransactionSource)}
                  className="w-full px-3 py-2 text-sm bg-background border border-input rounded-md focus:outline-none focus:ring-1 focus:ring-ring"
                >
                  <option value="freelance">Freelance</option>
                  <option value="intern">Magang</option>
                  <option value="kuliah">Akademik / Beasiswa</option>
                  <option value="personal">Pribadi / Lainnya</option>
                </select>
              </div>

              <div className="space-y-1">
                <label className="text-xs font-medium text-muted-foreground">Target Tabungan</label>
                <select
                  value={ruleGoalId}
                  onChange={(e) => setRuleGoalId(e.target.value)}
                  className="w-full px-3 py-2 text-sm bg-background border border-input rounded-md focus:outline-none focus:ring-1 focus:ring-ring"
                  required
                >
                  {goals.map((g) => (
                    <option key={g.id} value={g.id}>
                      {g.name}
                    </option>
                  ))}
                </select>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-1">
                  <label className="text-xs font-medium text-muted-foreground">Tipe Pembagian</label>
                  <select
                    value={ruleSplitType}
                    onChange={(e) =>
                      setRuleSplitType(e.target.value as 'percentage' | 'fixed_amount')
                    }
                    className="w-full px-3 py-2 text-sm bg-background border border-input rounded-md focus:outline-none focus:ring-1 focus:ring-ring"
                  >
                    <option value="percentage">Persentase (%)</option>
                    <option value="fixed_amount">Nominal Tetap (IDR)</option>
                  </select>
                </div>

                <div className="space-y-1">
                  <label className="text-xs font-medium text-muted-foreground">
                    {ruleSplitType === 'percentage' ? 'Persen (%)' : 'Nominal (IDR)'}
                  </label>
                  <input
                    type="number"
                    step="any"
                    min="1"
                    value={ruleSplitValue}
                    onChange={(e) => setRuleSplitValue(e.target.value)}
                    placeholder={ruleSplitType === 'percentage' ? '20' : '100000'}
                    className="w-full px-3 py-2 text-sm bg-background border border-input rounded-md focus:outline-none focus:ring-1 focus:ring-ring"
                    required
                  />
                </div>
              </div>

              <div className="space-y-1">
                <label className="text-xs font-medium text-muted-foreground">Prioritas (Urutan)</label>
                <input
                  type="number"
                  min="1"
                  max="100"
                  value={rulePriority}
                  onChange={(e) => setRulePriority(e.target.value)}
                  className="w-full px-3 py-2 text-sm bg-background border border-input rounded-md focus:outline-none focus:ring-1 focus:ring-ring"
                  required
                />
              </div>

              <div className="flex items-center gap-2 pt-1">
                <input
                  type="checkbox"
                  id="ruleActive"
                  checked={ruleActive}
                  onChange={(e) => setRuleActive(e.target.checked)}
                  className="rounded border-input text-primary focus:ring-ring"
                />
                <label htmlFor="ruleActive" className="text-xs font-medium cursor-pointer">
                  Aturan aktif dijalankan saat konfirmasi pemasukan
                </label>
              </div>

              <div className="flex justify-end gap-2 pt-4 border-t border-border">
                <button
                  type="button"
                  onClick={() => setShowRuleModal(false)}
                  className="px-4 py-2 text-sm text-muted-foreground hover:text-foreground rounded-md transition-colors"
                >
                  Batal
                </button>
                <button
                  type="submit"
                  disabled={submitting}
                  className="px-4 py-2 text-sm bg-primary text-primary-foreground font-medium rounded-md hover:bg-primary/90 transition-colors disabled:opacity-50"
                >
                  {submitting ? 'Menyimpan...' : 'Simpan Aturan'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
