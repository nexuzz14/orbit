'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';
import { formatCurrency, formatDateIndo } from '@/lib/format';
import type { Database, TransactionSource, TransactionType } from '@/types/database';
import {
  Plus,
  ArrowRightLeft,
  ArrowUpRight,
  ArrowDownLeft,
  Search,
  Filter,
  Trash2,
  RotateCcw,
  Edit2,
  X
} from 'lucide-react';

type TransactionRow = Database['public']['Tables']['transactions']['Row'] & {
  category_name?: string | null;
  account_name?: string | null;
};

type AccountOption = {
  id: string;
  name: string;
  currency: string;
};

type CategoryOption = {
  id: string;
  name: string;
  type: string;
};

export default function TransaksiPage() {
  const supabase = createClient();

  const [transactions, setTransactions] = useState<TransactionRow[]>([]);
  const [accounts, setAccounts] = useState<AccountOption[]>([]);
  const [categories, setCategories] = useState<CategoryOption[]>([]);
  const [workspaceId, setWorkspaceId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [showDeleted, setShowDeleted] = useState(false);

  // Filter states
  const [searchQuery, setSearchQuery] = useState('');
  const [filterAccount, setFilterAccount] = useState<string>('all');
  const [filterType, setFilterType] = useState<string>('all');
  const [filterSource, setFilterSource] = useState<string>('all');

  // Modal / Form state
  const [showModal, setShowModal] = useState(false);
  const [formMode, setFormMode] = useState<'create' | 'edit'>('create');
  const [editingId, setEditingId] = useState<string | null>(null);

  // Form fields
  const [txnType, setTxnType] = useState<TransactionType>('expense');
  const [amount, setAmount] = useState('');
  const [accountId, setAccountId] = useState('');
  const [toAccountId, setToAccountId] = useState('');
  const [categoryId, setCategoryId] = useState('');
  const [source, setSource] = useState<TransactionSource>('personal');
  const [merchant, setMerchant] = useState('');
  const [note, setNote] = useState('');
  const [occurredAt, setOccurredAt] = useState('');
  const [transferFee, setTransferFee] = useState('0');
  const [formError, setFormError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const loadData = useCallback(async () => {
    setLoading(true);

    // Ambil workspace aktif pengguna
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

    // Ambil daftar akun
    const { data: accData } = await supabase
      .from('accounts')
      .select('id, name, currency')
      .eq('workspace_id', wsId)
      .is('deleted_at', null)
      .order('sort_order');

    if (accData) {
      setAccounts(accData);
      if (accData.length > 0 && !accountId) {
        setAccountId(accData[0].id);
        if (accData.length > 1 && !toAccountId) {
          setToAccountId(accData[1].id);
        }
      }
    }

    // Ambil daftar kategori
    const { data: catData } = await supabase
      .from('categories')
      .select('id, name, type')
      .eq('workspace_id', wsId)
      .is('deleted_at', null)
      .order('sort_order');

    if (catData) {
      setCategories(catData);
      if (catData.length > 0 && !categoryId) {
        const defaultCat = catData.find((c) => c.type === 'expense');
        if (defaultCat) setCategoryId(defaultCat.id);
      }
    }

    // Query transaksi
    let query = supabase
      .from('transactions')
      .select('*')
      .eq('workspace_id', wsId)
      .eq('status', 'confirmed')
      .order('occurred_at', { ascending: false });

    if (!showDeleted) {
      query = query.is('deleted_at', null);
    }

    const { data: txns } = await query;

    if (txns && accData && catData) {
      const accMap = new Map(accData.map((a) => [a.id, a.name]));
      const catMap = new Map(catData.map((c) => [c.id, c.name]));

      const enriched: TransactionRow[] = txns.map((t) => ({
        ...t,
        account_name: accMap.get(t.account_id) || 'Akun',
        category_name: t.category_id ? catMap.get(t.category_id) : null,
      }));
      setTransactions(enriched);
    }

    setLoading(false);
  }, [supabase, showDeleted, accountId, toAccountId, categoryId]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  const resetForm = () => {
    setTxnType('expense');
    setAmount('');
    setMerchant('');
    setNote('');
    setTransferFee('0');
    setFormError(null);
    setFormMode('create');
    setEditingId(null);
    const now = new Date();
    now.setMinutes(now.getMinutes() - now.getTimezoneOffset());
    setOccurredAt(now.toISOString().slice(0, 16));
  };

  const openCreateModal = () => {
    resetForm();
    setShowModal(true);
  };

  const openEditModal = (t: TransactionRow) => {
    if (t.type === 'transfer') {
      alert('Transaksi transfer tidak dapat diedit langsung. Silakan hapus dan buat ulang.');
      return;
    }
    setFormMode('edit');
    setEditingId(t.id);
    setTxnType(t.type);
    setAmount(String(t.amount));
    setAccountId(t.account_id);
    setCategoryId(t.category_id || '');
    setSource(t.source || 'personal');
    setMerchant(t.merchant || '');
    setNote(t.note || '');
    const dateObj = new Date(t.occurred_at);
    dateObj.setMinutes(dateObj.getMinutes() - dateObj.getTimezoneOffset());
    setOccurredAt(dateObj.toISOString().slice(0, 16));
    setFormError(null);
    setShowModal(true);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!workspaceId) return;

    setSubmitting(true);
    setFormError(null);

    const numAmount = parseFloat(amount);
    if (isNaN(numAmount) || numAmount <= 0) {
      setFormError('Nominal harus lebih dari 0.');
      setSubmitting(false);
      return;
    }

    const selectedAcc = accounts.find((a) => a.id === accountId);
    if (!selectedAcc) {
      setFormError('Pilih akun yang valid.');
      setSubmitting(false);
      return;
    }

    const occurredIso = occurredAt ? new Date(occurredAt).toISOString() : new Date().toISOString();

    if (txnType === 'transfer') {
      if (accountId === toAccountId) {
        setFormError('Akun tujuan harus berbeda dari akun asal.');
        setSubmitting(false);
        return;
      }

      const numFee = parseFloat(transferFee) || 0;

      const { error } = await supabase.rpc('fn_create_transfer', {
        p_workspace_id: workspaceId,
        p_from_account_id: accountId,
        p_to_account_id: toAccountId,
        p_amount_out: numAmount,
        p_occurred_at: occurredIso,
        p_note: note || undefined,
        p_fee: numFee,
      });

      if (error) {
        setFormError(error.message);
        setSubmitting(false);
        return;
      }
    } else if (formMode === 'create') {
      if (!categoryId) {
        setFormError('Pilih kategori transaksi.');
        setSubmitting(false);
        return;
      }

      const { error } = await supabase.from('transactions').insert({
        workspace_id: workspaceId,
        account_id: accountId,
        category_id: categoryId,
        type: txnType,
        status: 'confirmed',
        amount: numAmount,
        currency: selectedAcc.currency,
        source: source,
        merchant: merchant || null,
        note: note || null,
        occurred_at: occurredIso,
        origin: 'manual',
      });

      if (error) {
        setFormError(error.message);
        setSubmitting(false);
        return;
      }
    } else if (formMode === 'edit' && editingId) {
      const { error } = await supabase
        .from('transactions')
        .update({
          account_id: accountId,
          category_id: categoryId,
          type: txnType,
          amount: numAmount,
          currency: selectedAcc.currency,
          source: source,
          merchant: merchant || null,
          note: note || null,
          occurred_at: occurredIso,
        })
        .eq('id', editingId);

      if (error) {
        setFormError(error.message);
        setSubmitting(false);
        return;
      }
    }

    setSubmitting(false);
    setShowModal(false);
    loadData();
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Hapus transaksi ini? (Dapat dipulihkan dalam 30 hari)')) return;

    const { error } = await supabase.rpc('fn_delete_transaction', {
      p_transaction_id: id,
    });

    if (error) {
      alert(`Gagal menghapus: ${error.message}`);
    } else {
      loadData();
    }
  };

  const handleRestore = async (id: string) => {
    const { error } = await supabase.rpc('fn_restore_transaction', {
      p_transaction_id: id,
    });

    if (error) {
      alert(`Gagal memulihkan: ${error.message}`);
    } else {
      loadData();
    }
  };

  // Filter list
  const filtered = transactions.filter((t) => {
    if (filterAccount !== 'all' && t.account_id !== filterAccount) return false;
    if (filterType !== 'all' && t.type !== filterType) return false;
    if (filterSource !== 'all' && t.source !== filterSource) return false;
    if (searchQuery) {
      const q = searchQuery.toLowerCase();
      const matchMerchant = t.merchant?.toLowerCase().includes(q);
      const matchNote = t.note?.toLowerCase().includes(q);
      const matchCategory = t.category_name?.toLowerCase().includes(q);
      if (!matchMerchant && !matchNote && !matchCategory) return false;
    }
    return true;
  });

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Transaksi</h1>
          <p className="text-sm text-muted-foreground">
            Kelola pengeluaran, pemasukan, dan transfer antar akun
          </p>
        </div>

        <button
          onClick={openCreateModal}
          type="button"
          className="inline-flex items-center gap-2 px-4 py-2 bg-foreground text-background text-sm font-medium rounded-md hover:opacity-90 transition-opacity"
        >
          <Plus className="w-4 h-4" />
          <span>Tambah Transaksi</span>
        </button>
      </div>

      {/* Filter Bar */}
      <div className="p-4 border border-border bg-card rounded-lg flex flex-wrap items-center gap-3">
        <div className="relative flex-1 min-w-[200px]">
          <input
            type="text"
            placeholder="Cari merchant, catatan, kategori..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full px-3 py-2 pl-9 text-sm border border-border rounded bg-background focus:outline-none focus:ring-1 focus:ring-foreground"
          />
          <Search className="w-4 h-4 text-muted-foreground absolute left-3 top-2.5" />
        </div>

        <select
          value={filterAccount}
          onChange={(e) => setFilterAccount(e.target.value)}
          aria-label="Filter berdasarkan akun"
          className="px-3 py-2 text-sm border border-border rounded bg-background focus:outline-none"
        >
          <option value="all">Semua Akun</option>
          {accounts.map((a) => (
            <option key={a.id} value={a.id}>
              {a.name}
            </option>
          ))}
        </select>

        <select
          value={filterType}
          onChange={(e) => setFilterType(e.target.value)}
          aria-label="Filter berdasarkan jenis transaksi"
          className="px-3 py-2 text-sm border border-border rounded bg-background focus:outline-none"
        >
          <option value="all">Semua Jenis</option>
          <option value="expense">Pengeluaran</option>
          <option value="income">Pemasukan</option>
          <option value="transfer">Transfer</option>
        </select>

        <select
          value={filterSource}
          onChange={(e) => setFilterSource(e.target.value)}
          aria-label="Filter berdasarkan sumber kegiatan"
          className="px-3 py-2 text-sm border border-border rounded bg-background focus:outline-none"
        >
          <option value="all">Semua Sumber</option>
          <option value="personal">Personal</option>
          <option value="intern">Intern</option>
          <option value="freelance">Freelance</option>
          <option value="kuliah">Kuliah</option>
        </select>

        <label className="flex items-center gap-2 text-sm text-muted-foreground cursor-pointer select-none ml-auto">
          <input
            type="checkbox"
            checked={showDeleted}
            onChange={(e) => setShowDeleted(e.target.checked)}
            className="rounded border-border text-foreground focus:ring-0"
          />
          <span>Tampilkan Terhapus</span>
        </label>
      </div>

      {/* Transaction List */}
      <div className="border border-border bg-card rounded-lg overflow-hidden">
        {loading ? (
          <div className="p-8 text-center text-sm text-muted-foreground">Memuat data transaksi...</div>
        ) : filtered.length === 0 ? (
          <div className="p-12 text-center">
            <Filter className="w-8 h-8 mx-auto text-muted-foreground mb-3 opacity-50" />
            <p className="text-sm font-medium">Tidak ada transaksi ditemukan</p>
            <p className="text-xs text-muted-foreground mt-1">Coba sesuaikan filter atau tambahkan transaksi baru</p>
          </div>
        ) : (
          <div className="divide-y divide-border">
            {filtered.map((t) => {
              const isExpense = t.type === 'expense' || (t.type === 'transfer' && t.transfer_direction === 'out');
              const isIncome = t.type === 'income' || (t.type === 'transfer' && t.transfer_direction === 'in');
              const isDeleted = !!t.deleted_at;

              return (
                <div
                  key={t.id}
                  className={`p-4 flex items-center justify-between gap-4 transition-colors ${
                    isDeleted ? 'opacity-50 bg-muted/20' : 'hover:bg-muted/30'
                  }`}
                >
                  <div className="flex items-center gap-3">
                    <div
                      className={`w-9 h-9 rounded-full flex items-center justify-center shrink-0 ${
                        t.type === 'transfer'
                          ? 'bg-muted text-foreground'
                          : isExpense
                          ? 'bg-expense/10 text-expense'
                          : 'bg-income/10 text-income'
                      }`}
                    >
                      {t.type === 'transfer' ? (
                        <ArrowRightLeft className="w-4 h-4" />
                      ) : isExpense ? (
                        <ArrowUpRight className="w-4 h-4" />
                      ) : (
                        <ArrowDownLeft className="w-4 h-4" />
                      )}
                    </div>

                    <div>
                      <div className="flex items-center gap-2">
                        <span className="font-medium text-sm">
                          {t.type === 'transfer'
                            ? `Transfer (${t.transfer_direction === 'out' ? 'Keluar' : 'Masuk'})`
                            : t.merchant || t.category_name || 'Transaksi'}
                        </span>
                        {t.source && (
                          <span className="text-[10px] uppercase font-semibold tracking-wider px-1.5 py-0.5 rounded bg-muted text-muted-foreground">
                            {t.source}
                          </span>
                        )}
                        {isDeleted && (
                          <span className="text-[10px] uppercase font-semibold tracking-wider px-1.5 py-0.5 rounded bg-expense/10 text-expense">
                            Terhapus
                          </span>
                        )}
                      </div>

                      <div className="text-xs text-muted-foreground mt-0.5 flex items-center gap-2">
                        <span>{formatDateIndo(t.occurred_at)}</span>
                        <span>•</span>
                        <span>{t.account_name}</span>
                        {t.note && (
                          <>
                            <span>•</span>
                            <span className="truncate max-w-[200px]">{t.note}</span>
                          </>
                        )}
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center gap-4">
                    <div className="text-right">
                      <div
                        className={`text-sm font-semibold tabular-nums ${
                          isExpense ? 'text-expense' : 'text-income'
                        }`}
                      >
                        {isExpense ? '-' : '+'}
                        {formatCurrency(Number(t.amount), t.currency)}
                      </div>
                      {t.category_name && t.type !== 'transfer' && (
                        <div className="text-xs text-muted-foreground">{t.category_name}</div>
                      )}
                    </div>

                    <div className="flex items-center gap-1">
                      {isDeleted ? (
                        <button
                          onClick={() => handleRestore(t.id)}
                          type="button"
                          title="Pulihkan Transaksi"
                          className="p-1.5 text-muted-foreground hover:text-foreground rounded transition-colors"
                        >
                          <RotateCcw className="w-4 h-4" />
                        </button>
                      ) : (
                        <>
                          {t.type !== 'transfer' && (
                            <button
                              onClick={() => openEditModal(t)}
                              type="button"
                              title="Edit Transaksi"
                              className="p-1.5 text-muted-foreground hover:text-foreground rounded transition-colors"
                            >
                              <Edit2 className="w-4 h-4" />
                            </button>
                          )}
                          <button
                            onClick={() => handleDelete(t.id)}
                            type="button"
                            title="Hapus Transaksi"
                            className="p-1.5 text-muted-foreground hover:text-expense rounded transition-colors"
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </>
                      )}
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Modal Form Tambah/Edit */}
      {showModal && (
        <div className="fixed inset-0 z-50 bg-background/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="w-full max-w-lg border border-border bg-card rounded-lg shadow-lg p-6 space-y-4">
            <div className="flex items-center justify-between border-b border-border pb-3">
              <h2 className="text-lg font-semibold">
                {formMode === 'create' ? 'Tambah Transaksi' : 'Edit Transaksi'}
              </h2>
              <button
                onClick={() => setShowModal(false)}
                type="button"
                className="text-muted-foreground hover:text-foreground"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {formError && (
              <div className="p-3 text-sm rounded bg-expense/10 text-expense border border-expense/20">
                {formError}
              </div>
            )}

            <form onSubmit={handleSubmit} className="space-y-4">
              {formMode === 'create' && (
                <div className="grid grid-cols-3 gap-2 p-1 bg-muted rounded-md text-xs font-medium">
                  <button
                    type="button"
                    onClick={() => setTxnType('expense')}
                    className={`py-1.5 rounded transition-colors ${
                      txnType === 'expense' ? 'bg-card text-foreground shadow-sm' : 'text-muted-foreground'
                    }`}
                  >
                    Pengeluaran
                  </button>
                  <button
                    type="button"
                    onClick={() => setTxnType('income')}
                    className={`py-1.5 rounded transition-colors ${
                      txnType === 'income' ? 'bg-card text-foreground shadow-sm' : 'text-muted-foreground'
                    }`}
                  >
                    Pemasukan
                  </button>
                  <button
                    type="button"
                    onClick={() => setTxnType('transfer')}
                    className={`py-1.5 rounded transition-colors ${
                      txnType === 'transfer' ? 'bg-card text-foreground shadow-sm' : 'text-muted-foreground'
                    }`}
                  >
                    Transfer
                  </button>
                </div>
              )}

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-medium mb-1">Nominal (Rp)</label>
                  <input
                    type="number"
                    step="any"
                    required
                    value={amount}
                    onChange={(e) => setAmount(e.target.value)}
                    placeholder="Contoh: 25000"
                    className="w-full px-3 py-2 text-sm border border-border rounded bg-background focus:outline-none focus:ring-1 focus:ring-foreground tabular-nums"
                  />
                </div>

                <div>
                  <label className="block text-xs font-medium mb-1">
                    {txnType === 'transfer' ? 'Akun Asal' : 'Akun'}
                  </label>
                  <select
                    value={accountId}
                    onChange={(e) => setAccountId(e.target.value)}
                    className="w-full px-3 py-2 text-sm border border-border rounded bg-background focus:outline-none"
                  >
                    {accounts.map((a) => (
                      <option key={a.id} value={a.id}>
                        {a.name} ({a.currency})
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              {txnType === 'transfer' ? (
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-xs font-medium mb-1">Akun Tujuan</label>
                    <select
                      value={toAccountId}
                      onChange={(e) => setToAccountId(e.target.value)}
                      className="w-full px-3 py-2 text-sm border border-border rounded bg-background focus:outline-none"
                    >
                      {accounts.map((a) => (
                        <option key={a.id} value={a.id}>
                          {a.name} ({a.currency})
                        </option>
                      ))}
                    </select>
                  </div>

                  <div>
                    <label className="block text-xs font-medium mb-1">Biaya Admin (Bila Ada)</label>
                    <input
                      type="number"
                      step="any"
                      value={transferFee}
                      onChange={(e) => setTransferFee(e.target.value)}
                      placeholder="0"
                      className="w-full px-3 py-2 text-sm border border-border rounded bg-background focus:outline-none tabular-nums"
                    />
                  </div>
                </div>
              ) : (
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-xs font-medium mb-1">Kategori</label>
                    <select
                      value={categoryId}
                      onChange={(e) => setCategoryId(e.target.value)}
                      className="w-full px-3 py-2 text-sm border border-border rounded bg-background focus:outline-none"
                    >
                      {categories
                        .filter((c) => c.type === txnType)
                        .map((c) => (
                          <option key={c.id} value={c.id}>
                            {c.name}
                          </option>
                        ))}
                    </select>
                  </div>

                  <div>
                    <label className="block text-xs font-medium mb-1">Sumber Kegiatan</label>
                    <select
                      value={source}
                      onChange={(e) => setSource(e.target.value as TransactionSource)}
                      className="w-full px-3 py-2 text-sm border border-border rounded bg-background focus:outline-none"
                    >
                      <option value="personal">Personal</option>
                      <option value="intern">Intern</option>
                      <option value="freelance">Freelance</option>
                      <option value="kuliah">Kuliah</option>
                    </select>
                  </div>
                </div>
              )}

              {txnType !== 'transfer' && (
                <div>
                  <label className="block text-xs font-medium mb-1">Merchant / Pihak Kedua</label>
                  <input
                    type="text"
                    value={merchant}
                    onChange={(e) => setMerchant(e.target.value)}
                    placeholder="Contoh: Indomaret, Warung Makan"
                    className="w-full px-3 py-2 text-sm border border-border rounded bg-background focus:outline-none"
                  />
                </div>
              )}

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-medium mb-1">Waktu Kejadian</label>
                  <input
                    type="datetime-local"
                    value={occurredAt}
                    onChange={(e) => setOccurredAt(e.target.value)}
                    className="w-full px-3 py-2 text-sm border border-border rounded bg-background focus:outline-none"
                  />
                </div>

                <div>
                  <label className="block text-xs font-medium mb-1">Catatan</label>
                  <input
                    type="text"
                    value={note}
                    onChange={(e) => setNote(e.target.value)}
                    placeholder="Catatan tambahan..."
                    className="w-full px-3 py-2 text-sm border border-border rounded bg-background focus:outline-none"
                  />
                </div>
              </div>

              <div className="flex items-center justify-end gap-2 pt-4 border-t border-border">
                <button
                  type="button"
                  onClick={() => setShowModal(false)}
                  className="px-4 py-2 text-sm font-medium border border-border rounded hover:bg-muted transition-colors"
                >
                  Batal
                </button>
                <button
                  type="submit"
                  disabled={submitting}
                  className="px-4 py-2 text-sm font-medium bg-foreground text-background rounded hover:opacity-90 transition-opacity disabled:opacity-50"
                >
                  {submitting ? 'Menyimpan...' : 'Simpan Transaksi'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
