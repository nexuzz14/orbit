'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';
import { formatCurrency, formatDateIndo } from '@/lib/format';
import type { Database, AccountType, AccountVisibility } from '@/types/database';
import { Wallet, Plus, Edit2, Archive, CheckCircle2, Lock } from 'lucide-react';
import {
  Card,
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

type AccountBalanceRow = Database['public']['Views']['v_account_balances']['Row'];

export default function AkunPage() {
  const supabase = createClient();
  const [accounts, setAccounts] = useState<AccountBalanceRow[]>([]);
  const [workspaceId, setWorkspaceId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);

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

      const { data, error } = await supabase
        .from('v_account_balances')
        .select('*')
        .order('sort_order');

      if (error) throw error;
      if (data) {
        setAccounts(data);
      }
    } catch (err: unknown) {
      setLoadError(err instanceof Error ? err.message : 'Gagal memuat daftar akun.');
    } finally {
      setLoading(false);
    }
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
    setName(acc.name ?? '');
    setType(acc.type ?? 'cash');
    setCurrency(acc.currency ?? 'IDR');
    setInitialBalance(String(acc.initial_balance ?? 0));
    setIsLiquid(acc.is_liquid ?? true);
    setVisibility(acc.visibility ?? 'shared');
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
          <h1 className="text-2xl font-bold tracking-tight text-foreground">Uang</h1>
          <p className="text-sm text-muted-foreground mt-0.5">
            Daftar akun dan dompet beserta saldo riil dari transaksi terkonfirmasi
          </p>
        </div>

        <Button onClick={openCreateModal}>
          <Plus className="w-4 h-4" />
          <span>Tambah Akun</span>
        </Button>
      </div>

      <MoneySubNav />

      {/* Saldo Likuid Card */}
      <Card>
        <CardContent className="p-5 flex items-center justify-between">
          <div>
            <div className="text-xs text-muted-foreground uppercase font-semibold tracking-wider">
              Total Saldo Likuid (IDR)
            </div>
            <div className="text-2xl font-bold tabular-nums mt-1 text-foreground">
              {formatCurrency(totalLiquid, 'IDR')}
            </div>
          </div>
          <div className="w-11 h-11 rounded-xl bg-primary/10 flex items-center justify-center text-primary">
            <Wallet className="w-5 h-5" />
          </div>
        </CardContent>
      </Card>

      {/* Daftar Akun */}
      {loadError ? (
        <ErrorState message={loadError} onRetry={loadAccounts} />
      ) : loading ? (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4" aria-busy="true">
          <Skeleton className="h-44 w-full" />
          <Skeleton className="h-44 w-full" />
          <Skeleton className="h-44 w-full" />
        </div>
      ) : accounts.length === 0 ? (
        <EmptyState
          icon={<Wallet className="w-5 h-5" />}
          title="Belum ada akun terdaftar"
          description="Tambahkan rekening bank, dompet tunai, atau e-wallet untuk mulai mencatat transaksi."
          actionLabel="Tambah Akun"
          onAction={openCreateModal}
        />
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {accounts.map((a) => (
            <Card
              key={a.account_id}
              className={`flex flex-col justify-between ${
                a.archived ? 'opacity-60 bg-muted/20' : ''
              }`}
            >
              <CardContent className="p-5 flex flex-col justify-between h-full space-y-4">
                <div>
                  <div className="flex items-center justify-between gap-2">
                    <div className="flex items-center gap-2">
                      <span className="font-semibold text-base text-foreground">{a.name}</span>
                      {a.visibility === 'private' && (
                        <span title="Akun Privat">
                          <Lock className="w-3.5 h-3.5 text-muted-foreground" />
                        </span>
                      )}
                    </div>
                    <StatusBadge variant="neutral">{a.type}</StatusBadge>
                  </div>

                  <div className="text-xs text-muted-foreground mt-1">
                    Mata Uang: {a.currency} • {a.is_liquid ? 'Likuid' : 'Non-Likuid'}
                  </div>

                  <div className="mt-4">
                    <div className="text-xs text-muted-foreground">Saldo Saat Ini</div>
                    <div className="text-xl font-bold tabular-nums mt-0.5 text-foreground">
                      {formatCurrency(Number(a.balance ?? 0), a.currency ?? 'IDR')}
                    </div>
                  </div>
                </div>

                <div className="pt-3 border-t border-border flex items-center justify-between text-xs text-muted-foreground">
                  <div className="tabular-nums">
                    {a.last_txn_at ? `Txn: ${formatDateIndo(a.last_txn_at)}` : 'Belum ada transaksi'}
                  </div>

                  <div className="flex items-center gap-1">
                    <Button
                      onClick={() => openEditModal(a)}
                      type="button"
                      variant="ghost"
                      size="icon"
                      aria-label={`Ubah ${a.name}`}
                    >
                      <Edit2 className="w-4 h-4" />
                    </Button>
                    <Button
                      onClick={() => toggleArchive(a.account_id ?? '', a.archived ?? false)}
                      type="button"
                      variant="ghost"
                      size="icon"
                      aria-label={a.archived ? `Buka Arsip ${a.name}` : `Arsipkan ${a.name}`}
                    >
                      {a.archived ? (
                        <CheckCircle2 className="w-4 h-4 text-income" />
                      ) : (
                        <Archive className="w-4 h-4" />
                      )}
                    </Button>
                  </div>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}

      {/* Modal Form Akun */}
      <Dialog
        open={showModal}
        onClose={() => setShowModal(false)}
        title={formMode === 'create' ? 'Tambah Akun Baru' : 'Ubah Akun'}
      >
        <form onSubmit={handleSubmit} className="space-y-4">
          {formError && (
            <div className="p-3 text-xs rounded-lg bg-expense/10 text-expense border border-expense/20">
              {formError}
            </div>
          )}

          <div>
            <label className="block text-xs font-medium text-foreground mb-1.5">Nama Akun</label>
            <Input
              type="text"
              required
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Contoh: BCA Utama, Dompet Saku, GoPay"
            />
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-medium text-foreground mb-1.5">Jenis</label>
              <Select
                value={type}
                onChange={(e) => setType(e.target.value as AccountType)}
              >
                <option value="bank">Bank</option>
                <option value="cash">Cash / Tunai</option>
                <option value="e_wallet">E-Wallet</option>
                <option value="credit_card">Kartu Kredit</option>
                <option value="savings">Tabungan</option>
              </Select>
            </div>

            <div>
              <label className="block text-xs font-medium text-foreground mb-1.5">Mata Uang</label>
              <Input
                type="text"
                required
                maxLength={3}
                value={currency}
                onChange={(e) => setCurrency(e.target.value.toUpperCase())}
                placeholder="IDR"
              />
            </div>
          </div>

          <div>
            <label className="block text-xs font-medium text-foreground mb-1.5">Saldo Awal (Rp)</label>
            <Input
              type="number"
              step="any"
              value={initialBalance}
              onChange={(e) => setInitialBalance(e.target.value)}
              placeholder="0"
              className="tabular-nums"
            />
            <p className="text-xs text-muted-foreground mt-1">
              Saldo riil dihitung otomatis: Saldo Awal + Transaksi Terkonfirmasi.
            </p>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-1">
            <label className="flex items-center gap-2.5 text-xs font-medium cursor-pointer select-none min-h-11">
              <input
                type="checkbox"
                checked={isLiquid}
                onChange={(e) => setIsLiquid(e.target.checked)}
                className="w-4 h-4 rounded border-border text-primary"
              />
              <span>Akun Likuid (Siap Pakai)</span>
            </label>

            <label className="flex items-center gap-2.5 text-xs font-medium cursor-pointer select-none min-h-11">
              <input
                type="checkbox"
                checked={visibility === 'private'}
                onChange={(e) => setVisibility(e.target.checked ? 'private' : 'shared')}
                className="w-4 h-4 rounded border-border text-primary"
              />
              <span>Akun Privat</span>
            </label>
          </div>

          <div className="flex items-center justify-end gap-2 pt-3 border-t border-border">
            <Button
              type="button"
              variant="secondary"
              onClick={() => setShowModal(false)}
            >
              Batal
            </Button>
            <Button type="submit" disabled={submitting}>
              {submitting ? 'Menyimpan...' : 'Simpan Akun'}
            </Button>
          </div>
        </form>
      </Dialog>
    </div>
  );
}
