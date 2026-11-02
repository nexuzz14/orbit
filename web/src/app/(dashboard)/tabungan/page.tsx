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
  ArrowRightLeft,
  History,
  Coins,
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
  MoneySubNav,
} from '@/components/ui';

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
  const [loadError, setLoadError] = useState<string | null>(null);

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

  const [showDepositModal, setShowDepositModal] = useState(false);
  const [depositingGoal, setDepositingGoal] = useState<SavingsGoal | null>(null);
  const [depositAmount, setDepositAmount] = useState('');
  const [depositError, setDepositError] = useState<string | null>(null);

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

  const [allocations, setAllocations] = useState<ExtendedAllocation[]>([]);
  const [submitting, setSubmitting] = useState(false);

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

      setWorkspaceId(memberData.workspace_id);

      const { data: goalsData, error: goalsErr } = await supabase
        .from('savings_goals')
        .select('*')
        .eq('workspace_id', memberData.workspace_id)
        .is('deleted_at', null)
        .order('created_at', { ascending: false });

      if (goalsErr) throw goalsErr;
      if (goalsData) {
        setGoals(goalsData);
        if (goalsData.length > 0 && !ruleGoalId) {
          setRuleGoalId(goalsData[0].id);
        }
      }

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
    } catch (err: unknown) {
      setLoadError(err instanceof Error ? err.message : 'Gagal memuat data target tabungan.');
    } finally {
      setLoading(false);
    }
  }, [supabase, ruleGoalId]);

  useEffect(() => {
    loadData();
  }, [loadData]);

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
    if (!window.confirm('Hapus target tabungan ini? Aturan split terkait akan terhapus.')) return;

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
    if (!window.confirm('Hapus aturan split pemasukan ini?')) return;

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
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-foreground">Uang</h1>
          <p className="text-sm text-muted-foreground mt-0.5">
            Target keuangan dan alokasi otomatis dari setiap pemasukan yang dikonfirmasi
          </p>
        </div>

        <div className="flex items-center gap-2">
          {activeTab === 'goals' && (
            <Button onClick={openCreateGoal} type="button">
              <Plus className="w-4 h-4" />
              <span>Target Baru</span>
            </Button>
          )}

          {activeTab === 'rules' && (
            <Button onClick={openCreateRule} type="button" disabled={goals.length === 0}>
              <Plus className="w-4 h-4" />
              <span>Aturan Baru</span>
            </Button>
          )}
        </div>
      </div>

      <MoneySubNav />

      <div className="flex items-center justify-between">
        <SegmentedControl
          ariaLabel="Sub-menu Target & Tabungan"
          value={activeTab}
          onChange={setActiveTab}
          options={[
            { value: 'goals', label: `Target Tabungan (${goals.length})` },
            { value: 'rules', label: `Aturan Auto-Split (${rules.length})` },
            { value: 'history', label: `Riwayat Alokasi (${allocations.length})` },
          ]}
        />
      </div>

      {loadError ? (
        <ErrorState message={loadError} onRetry={loadData} />
      ) : loading ? (
        <div className="space-y-3" aria-busy="true">
          <Skeleton className="h-24 w-full" />
          <Skeleton className="h-24 w-full" />
        </div>
      ) : activeTab === 'goals' ? (
        <div className="space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <Card>
              <CardContent className="p-4">
                <div className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">
                  Total Terkumpul
                </div>
                <div className="text-2xl font-bold mt-1 tracking-tight text-income tabular-nums">
                  {formatCurrency(totalSaved)}
                </div>
                <div className="text-xs text-muted-foreground mt-1 tabular-nums">
                  Dari target total {formatCurrency(totalTarget)}
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardContent className="p-4">
                <div className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">
                  Kemajuan Keseluruhan
                </div>
                <div className="text-2xl font-bold mt-1 tracking-tight text-foreground tabular-nums">
                  {totalTarget > 0 ? `${Math.round((totalSaved / totalTarget) * 100)}%` : '0%'}
                </div>
                <div className="text-xs text-muted-foreground mt-1 tabular-nums">
                  {completedGoalsCount} dari {goals.length} target tercapai
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardContent className="p-4 flex flex-col justify-center">
                <div className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">
                  Alokasi Otomatis
                </div>
                <div className="flex items-center gap-2 mt-1.5 text-xs text-muted-foreground">
                  <Coins className="w-4 h-4 text-primary shrink-0" />
                  <span>Auto-split membagi pemasukan saat dikonfirmasi</span>
                </div>
              </CardContent>
            </Card>
          </div>

          {goals.length === 0 ? (
            <EmptyState
              icon={<Target className="w-5 h-5" />}
              title="Belum ada target tabungan"
              description="Tentukan target dana darurat, perangkat kerja, atau pendidikan untuk mulai menabung."
              actionLabel="Target Baru"
              onAction={openCreateGoal}
            />
          ) : (
            <Card className="overflow-hidden">
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <Target className="w-4 h-4 text-primary" />
                  <span>Daftar Target Keuangan</span>
                </CardTitle>
                <Button variant="ghost" size="sm" onClick={() => loadData()}>
                  <RefreshCw className="w-3.5 h-3.5" />
                  <span>Muat Ulang</span>
                </Button>
              </CardHeader>

              <div className="divide-y divide-border">
                {goals.map((goal) => {
                  const targetNum = Number(goal.target_amount);
                  const currentNum = Number(goal.current_amount);
                  const pct =
                    targetNum > 0 ? Math.min(Math.round((currentNum / targetNum) * 100), 100) : 0;

                  return (
                    <div key={goal.id} className="p-4 space-y-3 hover:bg-muted/20 transition-colors">
                      <div className="flex flex-col sm:flex-row justify-between sm:items-center gap-2">
                        <div className="space-y-1">
                          <div className="flex items-center gap-2 flex-wrap">
                            <span className="font-semibold text-sm text-foreground">{goal.name}</span>
                            {goal.is_completed ? (
                              <StatusBadge variant="income">
                                <CheckCircle2 className="w-3 h-3" />
                                <span>Tercapai</span>
                              </StatusBadge>
                            ) : (
                              <StatusBadge variant="neutral">Sedang Berjalan</StatusBadge>
                            )}
                          </div>
                          {goal.target_date && (
                            <div className="text-xs text-muted-foreground tabular-nums">
                              Target selesai: {formatDateIndo(goal.target_date)}
                            </div>
                          )}
                          {goal.notes && (
                            <div className="text-xs text-muted-foreground">{goal.notes}</div>
                          )}
                        </div>

                        <div className="flex items-center gap-3">
                          <div className="text-right tabular-nums">
                            <div className="text-sm font-bold text-income">
                              {formatCurrency(currentNum)}{' '}
                              <span className="text-xs font-normal text-muted-foreground">
                                / {formatCurrency(targetNum)}
                              </span>
                            </div>
                            <div className="text-xs text-muted-foreground">{pct}% terkumpul</div>
                          </div>

                          <div className="flex items-center gap-1 pl-2 border-l border-border">
                            <Button
                              onClick={() => openDepositModal(goal)}
                              type="button"
                              variant="secondary"
                              size="sm"
                            >
                              <Coins className="w-3.5 h-3.5 text-primary" />
                              <span>Setor</span>
                            </Button>
                            <Button
                              onClick={() => openEditGoal(goal)}
                              type="button"
                              variant="ghost"
                              size="icon"
                              aria-label={`Ubah ${goal.name}`}
                            >
                              <Edit2 className="w-4 h-4" />
                            </Button>
                            <Button
                              onClick={() => handleDeleteGoal(goal.id)}
                              type="button"
                              variant="ghost"
                              size="icon"
                              aria-label={`Hapus ${goal.name}`}
                            >
                              <Trash2 className="w-4 h-4 text-muted-foreground hover:text-expense" />
                            </Button>
                          </div>
                        </div>
                      </div>

                      <div className="w-full bg-muted rounded-full h-2 overflow-hidden">
                        <div
                          className={`h-full transition-all duration-200 ${
                            goal.is_completed ? 'bg-income' : 'bg-primary'
                          }`}
                          style={{ width: `${pct}%` }}
                        />
                      </div>
                    </div>
                  );
                })}
              </div>
            </Card>
          )}
        </div>
      ) : activeTab === 'rules' ? (
        rules.length === 0 ? (
          <EmptyState
            icon={<ArrowRightLeft className="w-5 h-5" />}
            title="Belum ada aturan auto-split"
            description="Buat aturan untuk mengalokasikan persentase pemasukan otomatis ke target tabungan Anda."
            actionLabel="Aturan Baru"
            onAction={openCreateRule}
          />
        ) : (
          <Card className="overflow-hidden">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <ArrowRightLeft className="w-4 h-4 text-primary" />
                <span>Daftar Aturan Pembagian</span>
              </CardTitle>
            </CardHeader>

            <div className="divide-y divide-border">
              {rules.map((rule) => (
                <div
                  key={rule.id}
                  className={`p-4 flex flex-col sm:flex-row justify-between sm:items-center gap-3 hover:bg-muted/20 transition-colors ${
                    !rule.active ? 'opacity-60' : ''
                  }`}
                >
                  <div className="space-y-1.5">
                    <div className="flex items-center gap-2 flex-wrap">
                      <KindBadge kind={rule.source} />
                      <span className="text-xs text-muted-foreground">ke</span>
                      <span className="font-semibold text-sm text-foreground">
                        {rule.goal?.name || 'Target Tidak Ditemukan'}
                      </span>
                      {!rule.active && <StatusBadge variant="warning">Nonaktif</StatusBadge>}
                    </div>
                    <div className="text-xs text-muted-foreground tabular-nums">
                      Prioritas: {rule.priority} • Alokasi:{' '}
                      {rule.split_type === 'percentage'
                        ? `${rule.split_value}% dari pemasukan`
                        : formatCurrency(rule.split_value)}
                    </div>
                  </div>

                  <div className="flex items-center gap-1 pl-2 border-l border-border">
                    <Button
                      onClick={() => openEditRule(rule)}
                      type="button"
                      variant="ghost"
                      size="icon"
                      aria-label="Ubah Aturan"
                    >
                      <Edit2 className="w-4 h-4" />
                    </Button>
                    <Button
                      onClick={() => handleDeleteRule(rule.id)}
                      type="button"
                      variant="ghost"
                      size="icon"
                      aria-label="Hapus Aturan"
                    >
                      <Trash2 className="w-4 h-4 text-muted-foreground hover:text-expense" />
                    </Button>
                  </div>
                </div>
              ))}
            </div>
          </Card>
        )
      ) : allocations.length === 0 ? (
        <EmptyState
          icon={<History className="w-5 h-5" />}
          title="Belum ada riwayat alokasi"
          description="Alokasi otomatis akan tercatat saat pemasukan yang cocok dengan aturan dikonfirmasi."
        />
      ) : (
        <Card className="overflow-hidden">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <History className="w-4 h-4 text-primary" />
              <span>Riwayat Alokasi Auto-Split</span>
            </CardTitle>
          </CardHeader>
          <div className="divide-y divide-border">
            {allocations.map((alloc) => (
              <div key={alloc.id} className="p-4 flex justify-between items-center hover:bg-muted/20">
                <div className="space-y-1">
                  <div className="font-semibold text-sm text-foreground">
                    {alloc.goal?.name || 'Target Tabungan'}
                  </div>
                  <div className="text-xs text-muted-foreground tabular-nums">
                    Dari transaksi: {alloc.transaction?.description || 'Pemasukan'} (
                    {alloc.transaction?.occurred_at
                      ? formatDateIndo(alloc.transaction.occurred_at)
                      : '-'}
                    )
                  </div>
                </div>
                <div className="text-right font-bold text-sm text-income tabular-nums">
                  +{formatCurrency(alloc.amount)}
                </div>
              </div>
            ))}
          </div>
        </Card>
      )}

      {/* Modal Target Tabungan */}
      <Dialog
        open={showGoalModal}
        onClose={() => setShowGoalModal(false)}
        title={goalMode === 'create' ? 'Tambah Target Tabungan' : 'Ubah Target Tabungan'}
      >
        <form onSubmit={handleSaveGoal} className="space-y-4">
          {goalError && (
            <div className="p-3 text-xs bg-expense/10 text-expense border border-expense/20 rounded-lg">
              {goalError}
            </div>
          )}

          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">Nama Target</label>
            <Input
              type="text"
              value={goalName}
              onChange={(e) => setGoalName(e.target.value)}
              placeholder="Contoh: Dana Darurat 6 Bulan"
              required
            />
          </div>

          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">
              Target Nominal (IDR)
            </label>
            <Input
              type="number"
              step="any"
              min="0"
              value={goalTargetAmount}
              onChange={(e) => setGoalTargetAmount(e.target.value)}
              placeholder="Contoh: 10000000"
              className="tabular-nums"
              required
            />
          </div>

          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">
              Saldo Awal Terkumpul (IDR)
            </label>
            <Input
              type="number"
              step="any"
              min="0"
              value={goalCurrentAmount}
              onChange={(e) => setGoalCurrentAmount(e.target.value)}
              className="tabular-nums"
            />
          </div>

          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">
              Target Tanggal (Opsional)
            </label>
            <Input
              type="date"
              value={goalTargetDate}
              onChange={(e) => setGoalTargetDate(e.target.value)}
            />
          </div>

          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">Catatan</label>
            <Input
              type="text"
              value={goalNotes}
              onChange={(e) => setGoalNotes(e.target.value)}
              placeholder="Catatan tujuan atau prioritas"
            />
          </div>

          <div className="flex justify-end gap-2 pt-3 border-t border-border">
            <Button
              type="button"
              variant="secondary"
              onClick={() => setShowGoalModal(false)}
            >
              Batal
            </Button>
            <Button type="submit" disabled={submitting}>
              {submitting ? 'Menyimpan...' : 'Simpan Target'}
            </Button>
          </div>
        </form>
      </Dialog>

      {/* Modal Setor Manual */}
      <Dialog
        open={showDepositModal}
        onClose={() => setShowDepositModal(false)}
        title="Setor ke Tabungan"
        description={
          depositingGoal
            ? `${depositingGoal.name} (${formatCurrency(depositingGoal.current_amount)} / ${formatCurrency(depositingGoal.target_amount)})`
            : undefined
        }
      >
        <form onSubmit={handleManualDeposit} className="space-y-4">
          {depositError && (
            <div className="p-3 text-xs bg-expense/10 text-expense border border-expense/20 rounded-lg">
              {depositError}
            </div>
          )}

          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">
              Nominal Setoran (IDR)
            </label>
            <Input
              type="number"
              step="any"
              min="0"
              value={depositAmount}
              onChange={(e) => setDepositAmount(e.target.value)}
              placeholder="Contoh: 500000"
              className="tabular-nums"
              required
            />
          </div>

          <div className="flex justify-end gap-2 pt-3 border-t border-border">
            <Button
              type="button"
              variant="secondary"
              onClick={() => setShowDepositModal(false)}
            >
              Batal
            </Button>
            <Button type="submit" disabled={submitting}>
              {submitting ? 'Menyetor...' : 'Tambahkan Setoran'}
            </Button>
          </div>
        </form>
      </Dialog>

      {/* Modal Aturan Auto-Split */}
      <Dialog
        open={showRuleModal}
        onClose={() => setShowRuleModal(false)}
        title={ruleMode === 'create' ? 'Tambah Aturan Auto-Split' : 'Ubah Aturan Auto-Split'}
      >
        <form onSubmit={handleSaveRule} className="space-y-4">
          {ruleError && (
            <div className="p-3 text-xs bg-expense/10 text-expense border border-expense/20 rounded-lg">
              {ruleError}
            </div>
          )}

          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">
              Sumber Pemasukan
            </label>
            <Select
              value={ruleSource}
              onChange={(e) => setRuleSource(e.target.value as TransactionSource)}
            >
              <option value="freelance">Freelance</option>
              <option value="intern">Magang</option>
              <option value="kuliah">Kuliah / Beasiswa</option>
              <option value="personal">Pribadi</option>
            </Select>
          </div>

          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">
              Target Tabungan
            </label>
            <Select
              value={ruleGoalId}
              onChange={(e) => setRuleGoalId(e.target.value)}
              required
            >
              {goals.map((g) => (
                <option key={g.id} value={g.id}>
                  {g.name}
                </option>
              ))}
            </Select>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="text-xs font-medium text-foreground block mb-1.5">
                Tipe Pembagian
              </label>
              <Select
                value={ruleSplitType}
                onChange={(e) =>
                  setRuleSplitType(e.target.value as 'percentage' | 'fixed_amount')
                }
              >
                <option value="percentage">Persentase (%)</option>
                <option value="fixed_amount">Nominal Tetap (IDR)</option>
              </Select>
            </div>

            <div>
              <label className="text-xs font-medium text-foreground block mb-1.5">
                {ruleSplitType === 'percentage' ? 'Persen (%)' : 'Nominal (IDR)'}
              </label>
              <Input
                type="number"
                step="any"
                min="1"
                value={ruleSplitValue}
                onChange={(e) => setRuleSplitValue(e.target.value)}
                placeholder={ruleSplitType === 'percentage' ? '20' : '100000'}
                className="tabular-nums"
                required
              />
            </div>
          </div>

          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">
              Prioritas (Urutan)
            </label>
            <Input
              type="number"
              min="1"
              max="100"
              value={rulePriority}
              onChange={(e) => setRulePriority(e.target.value)}
              className="tabular-nums"
              required
            />
          </div>

          <label className="flex items-center gap-2.5 pt-1 cursor-pointer min-h-11">
            <input
              type="checkbox"
              id="ruleActive"
              checked={ruleActive}
              onChange={(e) => setRuleActive(e.target.checked)}
              className="w-4 h-4 rounded border-border text-primary"
            />
            <span className="text-xs font-medium text-foreground">
              Aturan aktif dijalankan saat konfirmasi pemasukan
            </span>
          </label>

          <div className="flex justify-end gap-2 pt-3 border-t border-border">
            <Button
              type="button"
              variant="secondary"
              onClick={() => setShowRuleModal(false)}
            >
              Batal
            </Button>
            <Button type="submit" disabled={submitting}>
              {submitting ? 'Menyimpan...' : 'Simpan Aturan'}
            </Button>
          </div>
        </form>
      </Dialog>
    </div>
  );
}
