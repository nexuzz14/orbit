'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';
import { formatCurrency, formatDateIndo } from '@/lib/format';
import type { Database, AccountType, AccountVisibility } from '@/types/database';
import { Wallet, Plus, Edit2, Archive, CheckCircle2, Lock, X } from 'lucide-react';

type AccountBalanceRow = Database['public']['Views']['v_account_balances']['Row'];

export default function AkunPage() {
  const supabase = createClient();
  const [accounts, setAccounts] = useState<AccountBalanceRow[]>([]);
  const [workspaceId, setWorkspaceId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  // Modal / Form state
  const [showModal, setShowModal] = useState(false);
  const [formMode, setFormMode] = useState<'create' | 'edit'>('create');
  const [editingId, setEditingId] = useState<string | null>(null);

  const [name, setName] = useState('');
  const [type, setType] = useState<AccountType>('bank');
  const [currency, setCurrency] = useState('IDR');
  const [initialBalance, setInitialBalance] = useState('0');
  const [isLiquid, setIsLiquid] = useState(true);
  const [visibility, setVisibility] = useState<AccountVisibility>('shared');
  const [formError, setFormError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const loadAccounts = useCallback(async () => {
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

    const { data } = await supabase
      .from('v_account_balances')
      .select('*')
      .order('sort_order');

    if (data) {
      setAccounts(data);
    }
    setLoading(false);
  }, [supabase]);

  useEffect(() => {
    loadAccounts();
  }, [loadAccounts]);

  const openCreateModal = () => {
    setName('');
    setType('bank');
    setCurrency('IDR');
    setInitialBalance('0');
    setIsLiquid(true);
    setVisibility('shared');
    setFormError(null);
    setFormMode('create');
    setEditingId(null);
    setShowModal(true);
  };

  const openEditModal = (acc: AccountBalanceRow) => {
    setName(acc.name);
    setType(acc.type);
    setCurrency(acc.currency);
    setInitialBalance(String(acc.initial_balance));
    setIsLiquid(acc.is_liquid);
    setVisibility(acc.visibility);
    setFormError(null);
    setFormMode('edit');
    setEditingId(acc.account_id);
    setShowModal(true);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!workspaceId) return;

    setSubmitting(true);
    setFormError(null);

    const numInit = parseFloat(initialBalance) || 0;

    if (formMode === 'create') {
      const { error } = await supabase.from('accounts').insert({
        workspace_id: workspaceId,
        name: name.trim(),
        type,
        currency: currency.toUpperCase().trim(),
        initial_balance: numInit,
        is_liquid: isLiquid,
        visibility,
      });

      if (error) {
        setFormError(error.message);
        setSubmitting(false);
        return;
      }
    } else if (formMode === 'edit' && editingId) {
      const { error } = await supabase
        .from('accounts')
        .update({
          name: name.trim(),
          type,
          currency: currency.toUpperCase().trim(),
          initial_balance: numInit,
          is_liquid: isLiquid,
          visibility,
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
    loadAccounts();
  };

  const toggleArchive = async (id: string, currentArchived: boolean) => {
    const { error } = await supabase
      .from('accounts')
      .update({ archived: !currentArchived })
      .eq('id', id);

    if (error) {
      alert(`Gagal mengubah status arsip: ${error.message}`);
    } else {
      loadAccounts();
    }
  };

  const totalLiquid = accounts
    .filter((a) => a.is_liquid && !a.archived && a.currency === 'IDR')
    .reduce((sum, a) => sum + Number(a.balance), 0);

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Akun & Dompet</h1>
          <p className="text-sm text-muted-foreground">
            Daftar saldo riil dihitung dari saldo awal dan seluruh transaksi terkonfirmasi
          </p>
        </div>

        <button
          onClick={openCreateModal}
          type="button"
          className="inline-flex items-center gap-2 px-4 py-2 bg-foreground text-background text-sm font-medium rounded-md hover:opacity-90 transition-opacity"
        >
          <Plus className="w-4 h-4" />
          <span>Tambah Akun</span>
        </button>
      </div>

      {/* Saldo Likuid Card */}
      <div className="p-5 bg-card border border-border rounded-lg flex items-center justify-between">
        <div>
          <div className="text-xs text-muted-foreground uppercase font-medium tracking-wider">
            Total Saldo Likuid (IDR)
          </div>
          <div className="text-2xl font-semibold tabular-nums mt-1">
            {formatCurrency(totalLiquid, 'IDR')}
          </div>
        </div>
        <div className="w-10 h-10 rounded-full bg-muted flex items-center justify-center text-foreground">
          <Wallet className="w-5 h-5" />
        </div>
      </div>

      {/* Daftar Akun */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        {loading ? (
          <div className="col-span-full p-8 text-center text-sm text-muted-foreground">
            Memuat daftar akun...
          </div>
        ) : accounts.length === 0 ? (
          <div className="col-span-full p-8 text-center text-sm text-muted-foreground border border-border bg-card rounded-lg">
            Belum ada akun terdaftar
          </div>
        ) : (
          accounts.map((a) => (
            <div
              key={a.account_id}
              className={`p-5 border border-border bg-card rounded-lg flex flex-col justify-between space-y-4 ${
                a.archived ? 'opacity-60 bg-muted/20' : ''
              }`}
            >
              <div>
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <span className="font-semibold text-base">{a.name}</span>
                    {a.visibility === 'private' && (
                      <span title="Akun Privat (Hanya Anda yang melihat)">
                        <Lock className="w-3.5 h-3.5 text-muted-foreground" />
                      </span>
                    )}
                  </div>
                  <span className="text-[10px] font-semibold uppercase tracking-wider px-2 py-0.5 rounded bg-muted text-muted-foreground">
                    {a.type}
                  </span>
                </div>

                <div className="text-xs text-muted-foreground mt-1">
                  Mata Uang: {a.currency} • {a.is_liquid ? 'Likuid' : 'Non-Likuid'}
                </div>

                <div className="mt-4">
                  <div className="text-xs text-muted-foreground">Saldo Saat Ini</div>
                  <div className="text-xl font-semibold tabular-nums mt-0.5">
                    {formatCurrency(Number(a.balance), a.currency)}
                  </div>
                </div>
              </div>

              <div className="pt-3 border-t border-border flex items-center justify-between text-xs text-muted-foreground">
                <div>
                  {a.last_txn_at ? `Txn: ${formatDateIndo(a.last_txn_at)}` : 'Belum ada transaksi'}
                </div>

                <div className="flex items-center gap-2">
                  <button
                    onClick={() => openEditModal(a)}
                    type="button"
                    title="Edit Akun"
                    className="p-1 hover:text-foreground transition-colors"
                  >
                    <Edit2 className="w-4 h-4" />
                  </button>
                  <button
                    onClick={() => toggleArchive(a.account_id, a.archived)}
                    type="button"
                    title={a.archived ? 'Buka Arsip' : 'Arsipkan'}
                    className="p-1 hover:text-foreground transition-colors"
                  >
                    {a.archived ? (
                      <CheckCircle2 className="w-4 h-4 text-income" />
                    ) : (
                      <Archive className="w-4 h-4" />
                    )}
                  </button>
                </div>
              </div>
            </div>
          ))
        )}
      </div>

      {/* Modal Form Akun */}
      {showModal && (
        <div className="fixed inset-0 z-50 bg-background/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="w-full max-w-md border border-border bg-card rounded-lg shadow-lg p-6 space-y-4">
            <div className="flex items-center justify-between border-b border-border pb-3">
              <h2 className="text-lg font-semibold">
                {formMode === 'create' ? 'Tambah Akun Baru' : 'Edit Akun'}
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
              <div>
                <label className="block text-xs font-medium mb-1">Nama Akun</label>
                <input
                  type="text"
                  required
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="Contoh: BCA Utama, Dompet Saku, GoPay"
                  className="w-full px-3 py-2 text-sm border border-border rounded bg-background focus:outline-none focus:ring-1 focus:ring-foreground"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-medium mb-1">Jenis</label>
                  <select
                    value={type}
                    onChange={(e) => setType(e.target.value as AccountType)}
                    className="w-full px-3 py-2 text-sm border border-border rounded bg-background focus:outline-none"
                  >
                    <option value="bank">Bank</option>
                    <option value="cash">Cash / Tunai</option>
                    <option value="e_wallet">E-Wallet</option>
                    <option value="credit_card">Kartu Kredit</option>
                    <option value="savings">Tabungan</option>
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-medium mb-1">Mata Uang</label>
                  <input
                    type="text"
                    required
                    maxLength={3}
                    value={currency}
                    onChange={(e) => setCurrency(e.target.value.toUpperCase())}
                    placeholder="IDR"
                    className="w-full px-3 py-2 text-sm border border-border rounded bg-background focus:outline-none"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-medium mb-1">Saldo Awal (Rp)</label>
                <input
                  type="number"
                  step="any"
                  value={initialBalance}
                  onChange={(e) => setInitialBalance(e.target.value)}
                  placeholder="0"
                  className="w-full px-3 py-2 text-sm border border-border rounded bg-background focus:outline-none tabular-nums"
                />
                <p className="text-[11px] text-muted-foreground mt-1">
                  Saldo riil dihitung otomatis: Saldo Awal + Transaksi Terkonfirmasi.
                </p>
              </div>

              <div className="grid grid-cols-2 gap-3 pt-2">
                <label className="flex items-center gap-2 text-xs cursor-pointer select-none">
                  <input
                    type="checkbox"
                    checked={isLiquid}
                    onChange={(e) => setIsLiquid(e.target.checked)}
                    className="rounded border-border"
                  />
                  <span>Akun Likuid (Siap Pakai)</span>
                </label>

                <label className="flex items-center gap-2 text-xs cursor-pointer select-none">
                  <input
                    type="checkbox"
                    checked={visibility === 'private'}
                    onChange={(e) => setVisibility(e.target.checked ? 'private' : 'shared')}
                    className="rounded border-border"
                  />
                  <span>Akun Privat</span>
                </label>
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
                  {submitting ? 'Menyimpan...' : 'Simpan Akun'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
