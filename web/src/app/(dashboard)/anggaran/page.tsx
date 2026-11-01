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
  X,
  Layers
} from 'lucide-react';

export default function AnggaranPage() {
  const supabase = createClient();
  const [budgets, setBudgets] = useState<BudgetProgress[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [workspaceId, setWorkspaceId] = useState<string | null>(null);
  const [monthStartDay, setMonthStartDay] = useState<number>(1);
  const [loading, setLoading] = useState(true);

  // Modal / Form state
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

    // Get current user profile for month_start_day
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

    // Fetch budget progress view
    const { data: budgetData } = await supabase
      .from('v_budget_progress')
      .select('*')
      .order('category_name');

    if (budgetData) {
      setBudgets(budgetData);
    }

    // Fetch active expense categories
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

    setLoading(false);
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
      setFormError('Ambang batas peringatan harus antara 1 sampai 100% (contoh: 80 untuk 80%).');
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
    const confirmDelete = window.confirm('Hapus anggaran ini?');
    if (!confirmDelete) return;

    const { error } = await supabase.from('budgets').delete().eq('id', budgetId);
    if (error) {
      alert(`Gagal menghapus: ${error.message}`);
    } else {
      await loadData();
    }
  };

  // Calculations
  const totalBase = budgets.reduce((acc, b) => acc + (b.base_budget_amount || 0), 0);
  const totalEffective = budgets.reduce((acc, b) => acc + (b.effective_budget_amount || 0), 0);
  const totalSpent = budgets.reduce((acc, b) => acc + (b.spent_amount || 0), 0);
  const totalRemaining = budgets.reduce((acc, b) => acc + (b.remaining_amount || 0), 0);
  const warningCount = budgets.filter((b) => b.is_warning && !b.is_over_budget).length;
  const overBudgetCount = budgets.filter((b) => b.is_over_budget).length;

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Anggaran Keuangan</h1>
          <p className="text-sm text-muted-foreground mt-1">
            Pantau batas pengeluaran bulanan (siklus tanggal {monthStartDay} setiap bulan).
          </p>
        </div>

        <button
          onClick={openCreateModal}
          type="button"
          className="flex items-center gap-2 bg-primary text-primary-foreground px-4 py-2 rounded-md text-sm font-medium hover:bg-primary/90 transition-colors"
        >
          <Plus className="w-4 h-4" />
          <span>Tambah Anggaran</span>
        </button>
      </div>

      {/* Ringkasan Cards */}
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="p-4 rounded-lg border border-border bg-card">
          <div className="text-xs font-medium text-muted-foreground uppercase">Anggaran Efektif</div>
          <div className="text-2xl font-bold mt-1 tracking-tight text-foreground">
            {formatCurrency(totalEffective)}
          </div>
          {totalEffective !== totalBase && (
            <div className="text-xs text-muted-foreground mt-1">
              Dasar: {formatCurrency(totalBase)}
            </div>
          )}
        </div>

        <div className="p-4 rounded-lg border border-border bg-card">
          <div className="text-xs font-medium text-muted-foreground uppercase">Total Terpakai</div>
          <div className="text-2xl font-bold mt-1 tracking-tight text-expense">
            {formatCurrency(totalSpent)}
          </div>
          <div className="text-xs text-muted-foreground mt-1">
            {totalEffective > 0
              ? `${Math.round((totalSpent / totalEffective) * 100)}% dari batas`
              : '0%'}
          </div>
        </div>

        <div className="p-4 rounded-lg border border-border bg-card">
          <div className="text-xs font-medium text-muted-foreground uppercase">Sisa Anggaran</div>
          <div
            className={`text-2xl font-bold mt-1 tracking-tight ${
              totalRemaining < 0 ? 'text-expense' : 'text-income'
            }`}
          >
            {formatCurrency(totalRemaining)}
          </div>
          <div className="text-xs text-muted-foreground mt-1">
            {totalRemaining < 0 ? 'Defisit anggaran' : 'Saldo tersedia'}
          </div>
        </div>

        <div className="p-4 rounded-lg border border-border bg-card flex flex-col justify-center">
          <div className="text-xs font-medium text-muted-foreground uppercase">Status Peringatan</div>
          <div className="flex items-center gap-3 mt-2 text-sm">
            <span className="flex items-center gap-1 text-amber-500 font-medium">
              <AlertTriangle className="w-4 h-4" />
              <span>{warningCount} Waspada</span>
            </span>
            <span className="flex items-center gap-1 text-expense font-medium">
              <AlertTriangle className="w-4 h-4" />
              <span>{overBudgetCount} Over</span>
            </span>
          </div>
        </div>
      </div>

      {/* Daftar Anggaran */}
      <div className="bg-card border border-border rounded-lg overflow-hidden">
        <div className="p-4 border-b border-border flex justify-between items-center">
          <h2 className="font-medium text-sm flex items-center gap-2">
            <PieChart className="w-4 h-4 text-primary" />
            <span>Daftar Anggaran Kategori</span>
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
          <div className="p-8 text-center text-sm text-muted-foreground">Memuat anggaran...</div>
        ) : budgets.length === 0 ? (
          <div className="p-8 text-center">
            <Layers className="w-8 h-8 text-muted-foreground mx-auto mb-2 opacity-50" />
            <div className="text-sm font-medium">Belum ada anggaran bulanan</div>
            <p className="text-xs text-muted-foreground mt-1 max-w-sm mx-auto">
              Tentukan batas pengeluaran per kategori untuk mengontrol keuangan bulanan Anda.
            </p>
            <button
              onClick={openCreateModal}
              type="button"
              className="mt-4 inline-flex items-center gap-2 bg-primary text-primary-foreground px-3 py-1.5 rounded-md text-xs font-medium"
            >
              <Plus className="w-3.5 h-3.5" />
              <span>Buat Anggaran Pertama</span>
            </button>
          </div>
        ) : (
          <div className="divide-y divide-border">
            {budgets.map((b) => {
              const pct = Math.min(Math.round(b.percentage_spent || 0), 100);
              const isOver = b.is_over_budget;
              const isWarn = b.is_warning && !isOver;

              let barColor = 'bg-primary';
              let badgeText = 'Aman';
              let badgeClass = 'bg-muted text-muted-foreground';

              if (isOver) {
                barColor = 'bg-expense';
                badgeText = 'Melebihi Anggaran';
                badgeClass = 'bg-expense/10 text-expense border border-expense/20';
              } else if (isWarn) {
                barColor = 'bg-amber-500';
                badgeText = 'Peringatan';
                badgeClass = 'bg-amber-500/10 text-amber-500 border border-amber-500/20';
              }

              return (
                <div key={b.budget_id} className="p-4 space-y-3 hover:bg-muted/30 transition-colors">
                  <div className="flex flex-col sm:flex-row justify-between sm:items-center gap-2">
                    <div className="flex items-center gap-2">
                      <span className="font-semibold text-sm tracking-tight">{b.category_name}</span>
                      <span className={`text-[11px] px-2 py-0.5 rounded-full font-medium ${badgeClass}`}>
                        {badgeText}
                      </span>
                      {b.rollover && (
                        <span className="text-[11px] px-2 py-0.5 rounded-full font-medium bg-blue-500/10 text-blue-500 border border-blue-500/20">
                          Rollover Aktif
                        </span>
                      )}
                    </div>

                    <div className="flex items-center gap-3">
                      <div className="text-right">
                        <div className="text-sm font-bold tracking-tight">
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
                        <button
                          onClick={() => openEditModal(b)}
                          type="button"
                          className="p-1.5 text-muted-foreground hover:text-foreground rounded transition-colors"
                          title="Ubah Anggaran"
                        >
                          <Edit2 className="w-3.5 h-3.5" />
                        </button>
                        <button
                          onClick={() => handleDelete(b.budget_id)}
                          type="button"
                          className="p-1.5 text-muted-foreground hover:text-expense rounded transition-colors"
                          title="Hapus Anggaran"
                        >
                          <Trash2 className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    </div>
                  </div>

                  {/* Progress Bar */}
                  <div className="space-y-1">
                    <div className="w-full bg-muted rounded-full h-2 overflow-hidden">
                      <div
                        className={`h-full transition-all duration-300 ${barColor}`}
                        style={{ width: `${pct}%` }}
                      />
                    </div>
                    <div className="flex justify-between items-center text-[11px] text-muted-foreground">
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
        )}
      </div>

      {/* Modal Form */}
      {showModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="bg-card border border-border rounded-lg max-w-md w-full p-6 space-y-4">
            <div className="flex justify-between items-center">
              <h3 className="font-semibold text-lg tracking-tight">
                {formMode === 'create' ? 'Tambah Anggaran Bulanan' : 'Ubah Anggaran'}
              </h3>
              <button
                onClick={() => setShowModal(false)}
                type="button"
                className="text-muted-foreground hover:text-foreground"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {formError && (
              <div className="p-3 text-xs bg-expense/10 text-expense border border-expense/20 rounded-md">
                {formError}
              </div>
            )}

            <form onSubmit={handleSave} className="space-y-4">
              <div className="space-y-1">
                <label className="text-xs font-medium text-muted-foreground">Kategori Pengeluaran</label>
                <select
                  value={categoryId}
                  onChange={(e) => setCategoryId(e.target.value)}
                  disabled={formMode === 'edit'}
                  className="w-full px-3 py-2 text-sm bg-background border border-input rounded-md focus:outline-none focus:ring-1 focus:ring-ring disabled:opacity-50"
                  required
                >
                  {categories.map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.name}
                    </option>
                  ))}
                </select>
              </div>

              <div className="space-y-1">
                <label className="text-xs font-medium text-muted-foreground">Batas Anggaran Dasar (IDR)</label>
                <input
                  type="number"
                  step="any"
                  min="0"
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                  placeholder="Contoh: 1500000"
                  className="w-full px-3 py-2 text-sm bg-background border border-input rounded-md focus:outline-none focus:ring-1 focus:ring-ring"
                  required
                />
              </div>

              <div className="space-y-1">
                <label className="text-xs font-medium text-muted-foreground">Ambang Peringatan (%)</label>
                <input
                  type="number"
                  step="1"
                  min="1"
                  max="100"
                  value={alertThreshold}
                  onChange={(e) => setAlertThreshold(e.target.value)}
                  placeholder="80"
                  className="w-full px-3 py-2 text-sm bg-background border border-input rounded-md focus:outline-none focus:ring-1 focus:ring-ring"
                  required
                />
                <span className="text-[11px] text-muted-foreground">
                  Default 80% memicu peringatan saat pengeluaran mencapai 80%.
                </span>
              </div>

              <div className="flex items-center gap-2 pt-1">
                <input
                  type="checkbox"
                  id="rollover"
                  checked={rolloverEnabled}
                  onChange={(e) => setRolloverEnabled(e.target.checked)}
                  className="rounded border-input text-primary focus:ring-ring"
                />
                <label htmlFor="rollover" className="text-xs font-medium cursor-pointer">
                  Aktifkan Rollover (sisa saldo bulan lalu ditambahkan ke anggaran bulan ini)
                </label>
              </div>

              <div className="flex justify-end gap-2 pt-4 border-t border-border">
                <button
                  type="button"
                  onClick={() => setShowModal(false)}
                  className="px-4 py-2 text-sm text-muted-foreground hover:text-foreground rounded-md transition-colors"
                >
                  Batal
                </button>
                <button
                  type="submit"
                  disabled={submitting}
                  className="px-4 py-2 text-sm bg-primary text-primary-foreground font-medium rounded-md hover:bg-primary/90 transition-colors disabled:opacity-50"
                >
                  {submitting ? 'Menyimpan...' : 'Simpan'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
