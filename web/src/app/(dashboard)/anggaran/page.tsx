'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';
import { formatCurrency } from '@/lib/format';
import type { BudgetProgress, Category } from '@/types/database';
import {
  PieChart,
  Plus,
  Edit2,
  Trash2,
  AlertTriangle,
  RefreshCw,
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
  StatusBadge,
  Skeleton,
  EmptyState,
  ErrorState,
  MoneySubNav,
} from '@/components/ui';

export default function AnggaranPage() {
  const supabase = createClient();
  const [budgets, setBudgets] = useState<BudgetProgress[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [workspaceId, setWorkspaceId] = useState<string | null>(null);
  const [monthStartDay, setMonthStartDay] = useState<number>(1);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);

  const [showModal, setShowModal] = useState(false);
  const [formMode, setFormMode] = useState<'create' | 'edit'>('create');
  const [editingId, setEditingId] = useState<string | null>(null);

  const [categoryId, setCategoryId] = useState('');
  const [amount, setAmount] = useState('');
  const [rolloverEnabled, setRolloverEnabled] = useState(false);
  const [alertThreshold, setAlertThreshold] = useState('80');
  const [formError, setFormError] = useState<string | null>(null);
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

      const { data: authUser } = await supabase.auth.getUser();
      if (authUser?.user) {
        const { data: profile } = await supabase
          .from('profiles')
          .select('month_start_day')
          .eq('id', authUser.user.id)
          .single();
        if (profile?.month_start_day) {
          setMonthStartDay(profile.month_start_day);
        }
      }

      const { data: budgetData, error: budgetErr } = await supabase
        .from('v_budget_progress')
        .select('*')
        .order('category_name');

      if (budgetErr) throw budgetErr;
      if (budgetData) {
        setBudgets(budgetData);
      }

      const { data: catData } = await supabase
        .from('categories')
        .select('*')
        .eq('workspace_id', memberData.workspace_id)
        .eq('type', 'expense')
        .is('deleted_at', null)
        .eq('archived', false)
        .order('name');

      if (catData) {
        setCategories(catData);
        if (catData.length > 0 && !categoryId) {
          setCategoryId(catData[0].id);
        }
      }
    } catch (err: unknown) {
      setLoadError(err instanceof Error ? err.message : 'Gagal memuat anggaran keuangan.');
    } finally {
      setLoading(false);
    }
  }, [supabase, categoryId]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  const openCreateModal = () => {
    if (categories.length > 0) {
      const budgetedCatIds = new Set(budgets.map((b) => b.category_id));
      const unbudgeted = categories.find((c) => !budgetedCatIds.has(c.id));
      setCategoryId(unbudgeted ? unbudgeted.id : categories[0].id);
    }
    setAmount('');
    setRolloverEnabled(false);
    setAlertThreshold('80');
    setFormError(null);
    setFormMode('create');
    setEditingId(null);
    setShowModal(true);
  };

  const openEditModal = (budget: BudgetProgress) => {
    setEditingId(budget.budget_id);
    setCategoryId(budget.category_id || '');
    setAmount(budget.base_budget_amount?.toString() || '0');
    setRolloverEnabled(Boolean(budget.rollover));
    setAlertThreshold(budget.notify_at_percent?.toString() || '80');
    setFormError(null);
    setFormMode('edit');
    setShowModal(true);
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!workspaceId) return;

    const numAmount = parseFloat(amount.replace(/[^0-9.]/g, ''));
    if (isNaN(numAmount) || numAmount <= 0) {
      setFormError('Nominal anggaran harus lebih besar dari 0.');
      return;
    }

    if (!categoryId) {
      setFormError('Pilih kategori pengeluaran.');
      return;
    }

    const numThreshold = parseFloat(alertThreshold);
    if (isNaN(numThreshold) || numThreshold <= 0 || numThreshold > 100) {
      setFormError('Ambang batas peringatan harus antara 1 sampai 100%.');
      return;
    }

    setSubmitting(true);
    setFormError(null);

    try {
      if (formMode === 'create') {
        const { error } = await supabase.from('budgets').insert({
          workspace_id: workspaceId,
          category_id: categoryId,
          period: 'monthly',
          amount: numAmount,
          rollover: rolloverEnabled,
          notify_at_percent: numThreshold,
        });

        if (error) {
          if (error.code === '23505') {
            throw new Error('Kategori ini sudah memiliki anggaran aktif untuk periode bulanan.');
          }
          throw error;
        }
      } else if (editingId) {
        const { error } = await supabase
          .from('budgets')
          .update({
            amount: numAmount,
            rollover: rolloverEnabled,
            notify_at_percent: numThreshold,
          })
          .eq('id', editingId);

        if (error) throw error;
      }

      setShowModal(false);
      await loadData();
    } catch (err: unknown) {
      setFormError(err instanceof Error ? err.message : 'Gagal menyimpan anggaran.');
    } finally {
      setSubmitting(false);
    }
  };

  const handleDelete = async (budgetId: string | null) => {
    if (!budgetId) return;
    if (!window.confirm('Hapus anggaran ini?')) return;

    const { error } = await supabase.from('budgets').delete().eq('id', budgetId);
    if (error) {
      alert(`Gagal menghapus: ${error.message}`);
    } else {
      await loadData();
    }
  };

  const totalBase = budgets.reduce((acc, b) => acc + (b.base_budget_amount || 0), 0);
  const totalEffective = budgets.reduce((acc, b) => acc + (b.effective_budget_amount || 0), 0);
  const totalSpent = budgets.reduce((acc, b) => acc + (b.spent_amount || 0), 0);
  const totalRemaining = budgets.reduce((acc, b) => acc + (b.remaining_amount || 0), 0);
  const warningCount = budgets.filter((b) => b.is_warning && !b.is_over_budget).length;
  const overBudgetCount = budgets.filter((b) => b.is_over_budget).length;

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-foreground">Uang</h1>
          <p className="text-sm text-muted-foreground mt-0.5">
            Pantau batas pengeluaran bulanan (siklus tanggal {monthStartDay} setiap bulan)
          </p>
        </div>

        <Button onClick={openCreateModal}>
          <Plus className="w-4 h-4" />
          <span>Tambah Anggaran</span>
        </Button>
      </div>

      <MoneySubNav />

      {/* Ringkasan Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <Card>
          <CardContent className="p-4">
            <div className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">
              Anggaran Efektif
            </div>
            <div className="text-2xl font-bold mt-1 tracking-tight text-foreground tabular-nums">
              {formatCurrency(totalEffective)}
            </div>
            {totalEffective !== totalBase && (
              <div className="text-xs text-muted-foreground mt-1 tabular-nums">
                Dasar: {formatCurrency(totalBase)}
              </div>
            )}
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-4">
            <div className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">
              Total Terpakai
            </div>
            <div className="text-2xl font-bold mt-1 tracking-tight text-expense tabular-nums">
              {formatCurrency(totalSpent)}
            </div>
            <div className="text-xs text-muted-foreground mt-1 tabular-nums">
              {totalEffective > 0
                ? `${Math.round((totalSpent / totalEffective) * 100)}% dari batas`
                : '0%'}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-4">
            <div className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">
              Sisa Anggaran
            </div>
            <div
              className={`text-2xl font-bold mt-1 tracking-tight tabular-nums ${
                totalRemaining < 0 ? 'text-expense' : 'text-income'
              }`}
            >
              {formatCurrency(totalRemaining)}
            </div>
            <div className="text-xs text-muted-foreground mt-1">
              {totalRemaining < 0 ? 'Defisit anggaran' : 'Saldo tersedia'}
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-4 flex flex-col justify-center">
            <div className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">
              Status Peringatan
            </div>
            <div className="flex items-center gap-2 mt-2 flex-wrap">
              <StatusBadge variant="warning">
                <AlertTriangle className="w-3 h-3" />
                <span>{warningCount} Waspada</span>
              </StatusBadge>
              <StatusBadge variant="expense">
                <AlertTriangle className="w-3 h-3" />
                <span>{overBudgetCount} Over</span>
              </StatusBadge>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Daftar Anggaran */}
      {loadError ? (
        <ErrorState message={loadError} onRetry={loadData} />
      ) : loading ? (
        <div className="space-y-3" aria-busy="true">
          <Skeleton className="h-24 w-full" />
          <Skeleton className="h-24 w-full" />
        </div>
      ) : budgets.length === 0 ? (
        <EmptyState
          icon={<PieChart className="w-5 h-5" />}
          title="Belum ada anggaran bulanan"
          description="Tentukan batas pengeluaran per kategori untuk mengontrol pengeluaran bulanan Anda."
          actionLabel="Tambah Anggaran"
          onAction={openCreateModal}
        />
      ) : (
        <Card className="overflow-hidden">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <PieChart className="w-4 h-4 text-primary" />
              <span>Daftar Anggaran Kategori</span>
            </CardTitle>
            <Button variant="ghost" size="sm" onClick={() => loadData()}>
              <RefreshCw className="w-3.5 h-3.5" />
              <span>Muat Ulang</span>
            </Button>
          </CardHeader>

          <div className="divide-y divide-border">
            {budgets.map((b) => {
              const pct = Math.min(Math.round(b.percentage_spent || 0), 100);
              const isOver = b.is_over_budget;
              const isWarn = b.is_warning && !isOver;

              let barColor = 'bg-primary';
              let badgeText = 'Aman';
              let badgeVariant: 'neutral' | 'warning' | 'expense' = 'neutral';

              if (isOver) {
                barColor = 'bg-expense';
                badgeText = 'Melebihi Anggaran';
                badgeVariant = 'expense';
              } else if (isWarn) {
                barColor = 'bg-warning';
                badgeText = 'Peringatan';
                badgeVariant = 'warning';
              }

              return (
                <div key={b.budget_id} className="p-4 space-y-3 hover:bg-muted/20 transition-colors">
                  <div className="flex flex-col sm:flex-row justify-between sm:items-center gap-2">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="font-semibold text-sm text-foreground">{b.category_name}</span>
                      <StatusBadge variant={badgeVariant}>{badgeText}</StatusBadge>
                      {b.rollover && (
                        <StatusBadge variant="neutral">Rollover Aktif</StatusBadge>
                      )}
                    </div>

                    <div className="flex items-center gap-3">
                      <div className="text-right tabular-nums">
                        <div className="text-sm font-bold text-foreground">
                          {formatCurrency(b.spent_amount || 0)}{' '}
                          <span className="text-xs font-normal text-muted-foreground">
                            / {formatCurrency(b.effective_budget_amount || 0)}
                          </span>
                        </div>
                        <div className="text-xs text-muted-foreground">
                          Sisa: {formatCurrency(b.remaining_amount || 0)}
                        </div>
                      </div>

                      <div className="flex items-center gap-1 pl-2 border-l border-border">
                        <Button
                          onClick={() => openEditModal(b)}
                          type="button"
                          variant="ghost"
                          size="icon"
                          aria-label={`Ubah anggaran ${b.category_name}`}
                        >
                          <Edit2 className="w-4 h-4" />
                        </Button>
                        <Button
                          onClick={() => handleDelete(b.budget_id)}
                          type="button"
                          variant="ghost"
                          size="icon"
                          aria-label={`Hapus anggaran ${b.category_name}`}
                        >
                          <Trash2 className="w-4 h-4 text-muted-foreground hover:text-expense" />
                        </Button>
                      </div>
                    </div>
                  </div>

                  <div className="space-y-1">
                    <div className="w-full bg-muted rounded-full h-2 overflow-hidden">
                      <div
                        className={`h-full transition-all duration-200 ${barColor}`}
                        style={{ width: `${pct}%` }}
                      />
                    </div>
                    <div className="flex justify-between items-center text-xs text-muted-foreground tabular-nums">
                      <span>{b.percentage_spent?.toFixed(1) || '0.0'}% terpakai</span>
                      {b.rollover_amount && b.rollover_amount > 0 ? (
                        <span>Termasuk sisa bulan lalu: +{formatCurrency(b.rollover_amount)}</span>
                      ) : null}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </Card>
      )}

      {/* Modal Form */}
      <Dialog
        open={showModal}
        onClose={() => setShowModal(false)}
        title={formMode === 'create' ? 'Tambah Anggaran Bulanan' : 'Ubah Anggaran'}
      >
        <form onSubmit={handleSave} className="space-y-4">
          {formError && (
            <div className="p-3 text-xs bg-expense/10 text-expense border border-expense/20 rounded-lg">
              {formError}
            </div>
          )}

          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">
              Kategori Pengeluaran
            </label>
            <Select
              value={categoryId}
              onChange={(e) => setCategoryId(e.target.value)}
              disabled={formMode === 'edit'}
              required
            >
              {categories.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </Select>
          </div>

          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">
              Batas Anggaran Dasar (IDR)
            </label>
            <Input
              type="number"
              step="any"
              min="0"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder="Contoh: 1500000"
              className="tabular-nums"
              required
            />
          </div>

          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">
              Ambang Peringatan (%)
            </label>
            <Input
              type="number"
              step="1"
              min="1"
              max="100"
              value={alertThreshold}
              onChange={(e) => setAlertThreshold(e.target.value)}
              placeholder="80"
              className="tabular-nums"
              required
            />
            <span className="text-xs text-muted-foreground block mt-1">
              Default 80% memicu peringatan saat pengeluaran mencapai 80%.
            </span>
          </div>

          <label className="flex items-center gap-2.5 pt-1 cursor-pointer min-h-11">
            <input
              type="checkbox"
              id="rollover"
              checked={rolloverEnabled}
              onChange={(e) => setRolloverEnabled(e.target.checked)}
              className="w-4 h-4 rounded border-border text-primary"
            />
            <span className="text-xs font-medium text-foreground">
              Aktifkan Rollover (sisa saldo bulan lalu ditambahkan ke bulan ini)
            </span>
          </label>

          <div className="flex justify-end gap-2 pt-3 border-t border-border">
            <Button
              type="button"
              variant="secondary"
              onClick={() => setShowModal(false)}
            >
              Batal
            </Button>
            <Button type="submit" disabled={submitting}>
              {submitting ? 'Menyimpan...' : 'Simpan'}
            </Button>
          </div>
        </form>
      </Dialog>
    </div>
  );
}
