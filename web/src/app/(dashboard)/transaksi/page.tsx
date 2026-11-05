'use client';

import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
  ArrowDownLeft,
  ArrowRightLeft,
  ArrowUpRight,
  Edit2,
  Plus,
  RotateCcw,
  Search,
  Trash2,
} from 'lucide-react';
import { createClient } from '@/lib/supabase/client';
import {
  formatCurrency,
  formatDateIndo,
  formatTransactionGroupDate,
  getDateKeyInTimezone,
} from '@/lib/format';
import type { Database } from '@/types/database';
import {
  Button,
  Card,
  cn,
  EmptyState,
  ErrorState,
  Input,
  KindBadge,
  MoneySubNav,
  Select,
  Skeleton,
  StatusBadge,
} from '@/components/ui';
import {
  type AccountOption,
  type CategoryOption,
  type EditableTransaction,
  TransactionFormModal,
} from '@/components/transaction-form-modal';

type TransactionRow = Database['public']['Tables']['transactions']['Row'] & {
  category_name?: string | null;
  account_name?: string | null;
};

interface DailyTransactionGroup {
  dateKey: string;
  subtotalNet: number;
  items: TransactionRow[];
}

export default function TransaksiPage() {
  const supabase = createClient();

  const [transactions, setTransactions] = useState<TransactionRow[]>([]);
  const [accounts, setAccounts] = useState<AccountOption[]>([]);
  const [categories, setCategories] = useState<CategoryOption[]>([]);
  const [workspaceId, setWorkspaceId] = useState<string | null>(null);
  const [draftCount, setDraftCount] = useState<number>(0);

  const [loading, setLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [showDeleted, setShowDeleted] = useState(false);

  const [searchQuery, setSearchQuery] = useState('');
  const [filterAccount, setFilterAccount] = useState<string>('all');
  const [filterType, setFilterType] = useState<string>('all');
  const [filterSource, setFilterSource] = useState<string>('all');

  const [showModal, setShowModal] = useState(false);
  const [editingTx, setEditingTx] = useState<EditableTransaction | null>(null);

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
        setTransactions([]);
        setLoading(false);
        return;
      }

      const wsId = memberData.workspace_id;
      setWorkspaceId(wsId);

      let txQuery = supabase
        .from('transactions')
        .select('*')
        .eq('workspace_id', wsId)
        .order('occurred_at', { ascending: false });

      if (!showDeleted) {
        txQuery = txQuery.is('deleted_at', null);
      }

      const [accRes, catRes, txRes] = await Promise.all([
        supabase
          .from('accounts')
          .select('id, name, currency')
          .eq('workspace_id', wsId)
          .is('deleted_at', null)
          .order('sort_order'),
        supabase
          .from('categories')
          .select('id, name, type')
          .eq('workspace_id', wsId)
          .is('deleted_at', null)
          .order('sort_order'),
        txQuery,
      ]);

      if (accRes.error) throw new Error(accRes.error.message);
      if (catRes.error) throw new Error(catRes.error.message);
      if (txRes.error) throw new Error(txRes.error.message);

      const accList = (accRes.data || []) as AccountOption[];
      const catList = (catRes.data || []) as CategoryOption[];
      setAccounts(accList);
      setCategories(catList);

      const accMap = new Map(accList.map((a) => [a.id, a.name]));
      const catMap = new Map(catList.map((c) => [c.id, c.name]));

      const rawTxns = (txRes.data || []) as TransactionRow[];
      const enriched: TransactionRow[] = rawTxns.map((t) => ({
        ...t,
        account_name: accMap.get(t.account_id) || 'Akun Utama',
        category_name: t.category_id ? catMap.get(t.category_id) : null,
      }));

      setTransactions(enriched);
      setDraftCount(enriched.filter((t) => t.status === 'draft' && !t.deleted_at).length);
    } catch (err: any) {
      setErrorMessage(err?.message || 'Gagal memuat daftar transaksi.');
    } finally {
      setLoading(false);
    }
  }, [supabase, showDeleted]);

  useEffect(() => {
    loadData();
    const onTxCreated = () => loadData();
    window.addEventListener('orbit:transaction-created', onTxCreated);
    return () => window.removeEventListener('orbit:transaction-created', onTxCreated);
  }, [loadData]);

  const handleDelete = async (id: string) => {
    const { error } = await supabase.rpc('fn_delete_transaction', {
      p_transaction_id: id,
    });
    if (error) {
      setErrorMessage(`Gagal menghapus transaksi: ${error.message}`);
    } else {
      loadData();
    }
  };

  const handleRestore = async (id: string) => {
    const { error } = await supabase.rpc('fn_restore_transaction', {
      p_transaction_id: id,
    });
    if (error) {
      setErrorMessage(`Gagal memulihkan transaksi: ${error.message}`);
    } else {
      loadData();
    }
  };

  const filtered = useMemo(() => {
    return transactions.filter((t) => {
      if (filterAccount !== 'all' && t.account_id !== filterAccount) return false;
      if (filterType !== 'all' && t.type !== filterType) return false;
      if (filterSource !== 'all' && t.source !== filterSource) return false;
      if (searchQuery.trim()) {
        const q = searchQuery.trim().toLowerCase();
        const matchMerchant = t.merchant?.toLowerCase().includes(q);
        const matchNote = t.note?.toLowerCase().includes(q);
        const matchCategory = t.category_name?.toLowerCase().includes(q);
        if (!matchMerchant && !matchNote && !matchCategory) return false;
      }
      return true;
    });
  }, [transactions, filterAccount, filterType, filterSource, searchQuery]);

  // Kelompokkan transaksi per hari beserta subtotal harian
  const groupedByDay = useMemo<DailyTransactionGroup[]>(() => {
    const map = new Map<string, DailyTransactionGroup>();

    for (const t of filtered) {
      const dateStr = getDateKeyInTimezone(
        t.occurred_at || (t as any).tx_date || new Date()
      );
      if (!map.has(dateStr)) {
        map.set(dateStr, { dateKey: dateStr, subtotalNet: 0, items: [] });
      }
      const group = map.get(dateStr)!;
      group.items.push(t);

      const rawAmount = Number(t.amount ?? (t as any).amount_minor ?? 0);
      const isExp =
        t.type === 'expense' || (t.type === 'transfer' && t.transfer_direction === 'out');
      const isInc =
        t.type === 'income' || (t.type === 'transfer' && t.transfer_direction === 'in');

      if (!t.deleted_at) {
        if (isInc) group.subtotalNet += rawAmount;
        else if (isExp) group.subtotalNet -= rawAmount;
      }
    }

    return Array.from(map.values()).sort((a, b) => b.dateKey.localeCompare(a.dateKey));
  }, [filtered]);

  return (
    <div className="space-y-6">
      {/* Header & Tombol Tambah Transaksi */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-border pb-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-foreground">Uang</h1>
          <p className="mt-0.5 text-sm text-muted-foreground">
            Kelola transaksi harian, akun, dan perencanaan arus kas.
          </p>
        </div>

        <Button
          variant="primary"
          onClick={() => {
            setEditingTx(null);
            setShowModal(true);
          }}
        >
          <Plus className="h-4 w-4" aria-hidden="true" />
          <span>Tambah Transaksi</span>
        </Button>
      </div>

      {/* Sub-navigasi Grup Uang (Transaksi | Akun | Ringkasan + Pintasan Inbox, Anggaran, Tagihan, Target) */}
      <MoneySubNav draftCount={draftCount} />

      {/* Bar Pencarian & Filter */}
      <Card className="p-4">
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-3 items-center">
          <div className="relative sm:col-span-2">
            <Search
              aria-hidden="true"
              className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground"
            />
            <Input
              type="search"
              aria-label="Cari transaksi berdasarkan merchant, catatan, atau kategori"
              placeholder="Cari merchant, catatan, kategori..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-9"
            />
          </div>

          <Select
            value={filterAccount}
            onChange={(e) => setFilterAccount(e.target.value)}
            aria-label="Filter berdasarkan akun"
          >
            <option value="all">Semua Akun</option>
            {accounts.map((a) => (
              <option key={a.id} value={a.id}>
                {a.name}
              </option>
            ))}
          </Select>

          <Select
            value={filterType}
            onChange={(e) => setFilterType(e.target.value)}
            aria-label="Filter berdasarkan jenis transaksi"
          >
            <option value="all">Semua Jenis</option>
            <option value="expense">Pengeluaran</option>
            <option value="income">Pemasukan</option>
            <option value="transfer">Transfer</option>
          </Select>

          <Select
            value={filterSource}
            onChange={(e) => setFilterSource(e.target.value)}
            aria-label="Filter berdasarkan jenis kegiatan"
          >
            <option value="all">Semua Kegiatan</option>
            <option value="personal">Pribadi</option>
            <option value="intern">Intern</option>
            <option value="freelance">Freelance</option>
            <option value="kuliah">Kuliah</option>
          </Select>
        </div>

        <div className="mt-3 flex items-center justify-between border-t border-border pt-3">
          <span className="text-xs text-muted-foreground tabular-nums">
            Menampilkan {filtered.length} transaksi
          </span>
          <label className="min-h-11 inline-flex items-center gap-2 text-xs font-medium text-muted-foreground cursor-pointer select-none">
            <input
              type="checkbox"
              checked={showDeleted}
              onChange={(e) => setShowDeleted(e.target.checked)}
              className="h-4 w-4 rounded border-border accent-primary"
            />
            <span>Tampilkan Transaksi Terhapus</span>
          </label>
        </div>
      </Card>

      {/* State Error */}
      {errorMessage && <ErrorState message={errorMessage} onRetry={loadData} />}

      {/* Daftar Transaksi Dikelompokkan per Hari */}
      {loading ? (
        <div className="space-y-4">
          <Card className="p-4 space-y-3">
            <Skeleton className="h-6 w-48" />
            <Skeleton className="h-16 w-full" />
            <Skeleton className="h-16 w-full" />
          </Card>
          <Card className="p-4 space-y-3">
            <Skeleton className="h-6 w-48" />
            <Skeleton className="h-16 w-full" />
          </Card>
        </div>
      ) : groupedByDay.length === 0 ? (
        <EmptyState
          title="Belum ada transaksi tercatat"
          description="Catat pemasukan atau pengeluaran pertama Anda agar saldo dan ringkasan harian terpantau."
          actionLabel="Tambah Transaksi"
          onAction={() => {
            setEditingTx(null);
            setShowModal(true);
          }}
        />
      ) : (
        <div className="space-y-4">
          {groupedByDay.map((group) => {
            const isPositive = group.subtotalNet >= 0;
            return (
              <Card key={group.dateKey} className="overflow-hidden">
                {/* Header Hari & Subtotal Harian */}
                <div className="flex items-center justify-between border-b border-border bg-subtle/60 px-4 py-2.5">
                  <span className="text-xs font-semibold text-foreground">
                    {formatTransactionGroupDate(group.dateKey)}
                  </span>
                  <span
                    className={cn(
                      'text-xs font-semibold tabular-nums text-right',
                      group.subtotalNet === 0
                        ? 'text-muted-foreground'
                        : isPositive
                        ? 'text-income'
                        : 'text-expense'
                    )}
                  >
                    Subtotal: {isPositive ? '+' : '-'}
                    {formatCurrency(Math.abs(group.subtotalNet))}
                  </span>
                </div>

                {/* Daftar Baris Transaksi */}
                <div className="divide-y divide-border">
                  {group.items.map((t) => {
                    const isExpense =
                      t.type === 'expense' ||
                      (t.type === 'transfer' && t.transfer_direction === 'out');
                    const isDeleted = Boolean(t.deleted_at);
                    const isDraft = t.status === 'draft';
                    const rawAmount = Number(t.amount ?? (t as any).amount_minor ?? 0);

                    return (
                      <div
                        key={t.id}
                        className={cn(
                          'flex items-center justify-between gap-3 px-4 py-3 transition-colors duration-150',
                          isDeleted ? 'opacity-50 bg-subtle/30' : 'hover:bg-subtle/40'
                        )}
                      >
                        <div className="flex items-center gap-3 min-w-0 flex-1">
                          <div
                            aria-hidden="true"
                            className={cn(
                              'flex h-10 w-10 shrink-0 items-center justify-center rounded-md border',
                              t.type === 'transfer'
                                ? 'border-border bg-subtle text-foreground'
                                : isExpense
                                ? 'border-expense-border bg-expense-subtle text-expense'
                                : 'border-income-border bg-income-subtle text-income'
                            )}
                          >
                            {t.type === 'transfer' ? (
                              <ArrowRightLeft className="h-4 w-4" />
                            ) : isExpense ? (
                              <ArrowUpRight className="h-4 w-4" />
                            ) : (
                              <ArrowDownLeft className="h-4 w-4" />
                            )}
                          </div>

                          <div className="min-w-0 flex-1">
                            <div className="flex flex-wrap items-center gap-2">
                              <span className="text-sm font-semibold text-foreground truncate">
                                {t.type === 'transfer'
                                  ? `Transfer (${t.transfer_direction === 'out' ? 'Keluar' : 'Masuk'})`
                                  : t.merchant || t.category_name || 'Transaksi'}
                              </span>
                              {t.source && <KindBadge kind={t.source} />}
                              {isDraft && (
                                <StatusBadge variant="warning">Draft</StatusBadge>
                              )}
                              {isDeleted && (
                                <StatusBadge variant="expense">Terhapus</StatusBadge>
                              )}
                            </div>

                            <div className="mt-0.5 flex flex-wrap items-center gap-2 text-xs text-muted-foreground">
                              <span>{t.account_name}</span>
                              {t.category_name && t.type !== 'transfer' && (
                                <>
                                  <span>•</span>
                                  <span>{t.category_name}</span>
                                </>
                              )}
                              {t.note && (
                                <>
                                  <span>•</span>
                                  <span className="truncate max-w-xs">{t.note}</span>
                                </>
                              )}
                            </div>
                          </div>
                        </div>

                        {/* Nominal Rata Kanan (Tabular Nums) & Aksi 44px */}
                        <div className="flex items-center gap-2 shrink-0">
                          <div className="text-right">
                            <div
                              className={cn(
                                'text-sm font-bold tabular-nums text-right',
                                isExpense ? 'text-expense' : 'text-income'
                              )}
                            >
                              {isExpense ? '-' : '+'}
                              {formatCurrency(rawAmount, t.currency || 'IDR')}
                            </div>
                          </div>

                          <div className="flex items-center">
                            {isDeleted ? (
                              <Button
                                variant="ghost"
                                size="icon"
                                onClick={() => handleRestore(t.id)}
                                aria-label="Pulihkan transaksi"
                                title="Pulihkan transaksi"
                              >
                                <RotateCcw className="h-4 w-4" />
                              </Button>
                            ) : (
                              <>
                                {t.type !== 'transfer' && (
                                  <Button
                                    variant="ghost"
                                    size="icon"
                                    onClick={() => {
                                      setEditingTx({
                                        id: t.id,
                                        type: t.type,
                                        amount: rawAmount,
                                        account_id: t.account_id,
                                        category_id: t.category_id,
                                        source: t.source,
                                        merchant: t.merchant,
                                        note: t.note,
                                        occurred_at:
                                          t.occurred_at || new Date().toISOString(),
                                      });
                                      setShowModal(true);
                                    }}
                                    aria-label={`Edit transaksi ${t.merchant || ''}`}
                                    title="Edit transaksi"
                                  >
                                    <Edit2 className="h-4 w-4" />
                                  </Button>
                                )}
                                <Button
                                  variant="ghost"
                                  size="icon"
                                  onClick={() => handleDelete(t.id)}
                                  aria-label={`Hapus transaksi ${t.merchant || ''}`}
                                  title="Hapus transaksi"
                                  className="text-muted-foreground hover:text-expense"
                                >
                                  <Trash2 className="h-4 w-4" />
                                </Button>
                              </>
                            )}
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              </Card>
            );
          })}
        </div>
      )}

      {/* Modal Tambah / Edit Transaksi Mobile-First */}
      <TransactionFormModal
        open={showModal}
        onClose={() => {
          setShowModal(false);
          setEditingTx(null);
        }}
        workspaceId={workspaceId}
        initialAccounts={accounts}
        initialCategories={categories}
        editingTransaction={editingTx}
        onSuccess={loadData}
      />
    </div>
  );
}
