'use client';

import React, { useEffect, useState } from 'react';
import { createClient } from '@/lib/supabase/client';
import { Button, cn, Dialog, Input, SegmentedControl } from '@/components/ui';
import type { TransactionSource, TransactionType } from '@/types/database';

export interface AccountOption {
  id: string;
  name: string;
  currency: string;
}

export interface CategoryOption {
  id: string;
  name: string;
  type: string;
}

export interface EditableTransaction {
  id: string;
  type: TransactionType;
  amount: number;
  account_id: string;
  category_id: string | null;
  source: TransactionSource | null;
  merchant: string | null;
  note: string | null;
  occurred_at: string;
}

interface TransactionFormModalProps {
  open: boolean;
  onClose: () => void;
  onSuccess?: () => void;
  initialAccounts?: AccountOption[];
  initialCategories?: CategoryOption[];
  workspaceId?: string | null;
  editingTransaction?: EditableTransaction | null;
}

export function TransactionFormModal({
  open,
  onClose,
  onSuccess,
  initialAccounts,
  initialCategories,
  workspaceId: propWorkspaceId,
  editingTransaction,
}: TransactionFormModalProps) {
  const supabase = createClient();
  const todayIso = new Date().toISOString().slice(0, 10);

  const [workspaceId, setWorkspaceId] = useState<string | null>(propWorkspaceId || null);
  const [type, setType] = useState<TransactionType>('expense');
  const [amountStr, setAmountStr] = useState('');
  const [accountId, setAccountId] = useState('');
  const [toAccountId, setToAccountId] = useState('');
  const [categoryId, setCategoryId] = useState('');
  const [source, setSource] = useState<TransactionSource>('personal');
  const [txDate, setTxDate] = useState(todayIso);
  const [merchant, setMerchant] = useState('');
  const [note, setNote] = useState('');
  const [showOptional, setShowOptional] = useState(false);

  const [accounts, setAccounts] = useState<AccountOption[]>(initialAccounts || []);
  const [categories, setCategories] = useState<CategoryOption[]>(initialCategories || []);
  const [submitting, setSubmitting] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  useEffect(() => {
    if (propWorkspaceId) setWorkspaceId(propWorkspaceId);
  }, [propWorkspaceId]);

  useEffect(() => {
    if (initialAccounts && initialAccounts.length > 0) setAccounts(initialAccounts);
    if (initialCategories && initialCategories.length > 0) setCategories(initialCategories);
  }, [initialAccounts, initialCategories]);

  useEffect(() => {
    if (!open) return;
    setErrorMsg(null);

    if (editingTransaction) {
      setType(editingTransaction.type);
      setAmountStr(String(editingTransaction.amount));
      setAccountId(editingTransaction.account_id);
      setCategoryId(editingTransaction.category_id || '');
      setSource(editingTransaction.source || 'personal');
      setMerchant(editingTransaction.merchant || '');
      setNote(editingTransaction.note || '');
      setTxDate(editingTransaction.occurred_at.slice(0, 10));
      setShowOptional(Boolean(editingTransaction.merchant || editingTransaction.note));
    } else {
      setType('expense');
      setAmountStr('');
      setMerchant('');
      setNote('');
      setSource('personal');
      setTxDate(new Date().toISOString().slice(0, 10));
      setShowOptional(false);
    }

    async function loadMetadataIfNeeded() {
      let wsId = propWorkspaceId || workspaceId;
      if (!wsId) {
        const { data: memberData } = await supabase
          .from('workspace_members')
          .select('workspace_id')
          .limit(1)
          .single();
        if (memberData) {
          wsId = memberData.workspace_id;
          setWorkspaceId(wsId);
        }
      }
      if (!wsId) return;

      if (accounts.length === 0 || categories.length === 0) {
        const [accRes, catRes] = await Promise.all([
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
        ]);
        if (accRes.data) setAccounts(accRes.data as AccountOption[]);
        if (catRes.data) setCategories(catRes.data as CategoryOption[]);
      }
    }

    loadMetadataIfNeeded();
  }, [open, editingTransaction, propWorkspaceId, workspaceId, accounts.length, categories.length, supabase]);

  useEffect(() => {
    if (accounts.length > 0 && !accountId) {
      setAccountId(accounts[0].id);
      if (accounts.length > 1) setToAccountId(accounts[1].id);
    }
  }, [accounts, accountId]);

  const filteredCategories = categories.filter(
    (c) => c.type === (type === 'income' ? 'income' : 'expense')
  );

  useEffect(() => {
    if (type !== 'transfer') {
      const currentValid = filteredCategories.some((c) => c.id === categoryId);
      if (!currentValid && filteredCategories.length > 0) {
        setCategoryId(filteredCategories[0].id);
      }
    }
  }, [type, filteredCategories, categoryId]);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setErrorMsg(null);

    const numAmount = parseFloat(amountStr);
    if (isNaN(numAmount) || numAmount <= 0) {
      setErrorMsg('Nominal harus lebih dari Rp0.');
      return;
    }

    const selectedAcc = accounts.find((a) => a.id === accountId) || accounts[0];
    if (!selectedAcc) {
      setErrorMsg('Pilih akun terlebih dahulu.');
      return;
    }

    if (!workspaceId) {
      setErrorMsg('Workspace belum dimuat. Coba lagi.');
      return;
    }

    setSubmitting(true);
    try {
      const occurredIso = txDate ? new Date(`${txDate}T12:00:00`).toISOString() : new Date().toISOString();

      if (type === 'transfer') {
        if (accountId === toAccountId) {
          throw new Error('Akun tujuan harus berbeda dari akun asal.');
        }
        const { error } = await supabase.rpc('fn_create_transfer', {
          p_workspace_id: workspaceId,
          p_from_account_id: accountId,
          p_to_account_id: toAccountId,
          p_amount_out: numAmount,
          p_occurred_at: occurredIso,
          p_note: note.trim() || undefined,
          p_fee: 0,
        });
        if (error) throw error;
      } else if (editingTransaction) {
        const { error } = await supabase
          .from('transactions')
          .update({
            account_id: selectedAcc.id,
            category_id: categoryId || null,
            type,
            amount: numAmount,
            currency: selectedAcc.currency,
            source,
            merchant: merchant.trim() || null,
            note: note.trim() || null,
            occurred_at: occurredIso,
          })
          .eq('id', editingTransaction.id);
        if (error) throw error;
      } else {
        if (!categoryId) {
          throw new Error('Pilih kategori transaksi.');
        }
        const { error } = await supabase.from('transactions').insert({
          workspace_id: workspaceId,
          account_id: selectedAcc.id,
          category_id: categoryId,
          type,
          status: 'confirmed',
          amount: numAmount,
          amount_base: numAmount,
          currency: selectedAcc.currency,
          source,
          merchant: merchant.trim() || null,
          note: note.trim() || null,
          occurred_at: occurredIso,
          origin: 'manual',
        });
        if (error) throw error;
      }

      onSuccess?.();
      onClose();
    } catch (err: any) {
      setErrorMsg(err?.message || 'Gagal menyimpan transaksi.');
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <Dialog
      open={open}
      onClose={onClose}
      title={editingTransaction ? 'Edit Transaksi' : 'Tambah Transaksi'}
      description="Catat transaksi cepat maksimal dalam 4 interaksi"
    >
      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        {errorMsg && (
          <div
            role="alert"
            className="rounded-md border border-expense-border bg-expense-subtle px-3 py-2 text-xs font-medium text-expense"
          >
            {errorMsg}
          </div>
        )}

        {/* 1. Nominal Besar di Atas */}
        <div className="rounded-lg border border-border bg-subtle/60 p-4">
          <label htmlFor="tx-amount-input" className="block text-xs font-medium text-muted-foreground">
            Nominal ({accounts.find((a) => a.id === accountId)?.currency || 'IDR'})
          </label>
          <div className="mt-1 flex items-baseline gap-2">
            <span className="text-lg font-semibold text-muted-foreground">Rp</span>
            <input
              id="tx-amount-input"
              type="number"
              inputMode="decimal"
              step="any"
              min="1"
              required
              autoFocus
              placeholder="0"
              value={amountStr}
              onChange={(e) => setAmountStr(e.target.value)}
              className="w-full bg-transparent text-3xl font-bold tabular-nums text-foreground placeholder:text-muted-foreground/50 focus:outline-none"
            />
          </div>
        </div>

        {/* 2. Jenis Transaksi (Segmented) */}
        {!editingTransaction && (
          <div>
            <span className="mb-1.5 block text-xs font-medium text-muted-foreground">Jenis Transaksi</span>
            <SegmentedControl
              ariaLabel="Pilih jenis transaksi"
              value={type}
              onChange={(val) => setType(val)}
              className="w-full"
              options={[
                { value: 'expense', label: 'Pengeluaran' },
                { value: 'income', label: 'Pemasukan' },
                { value: 'transfer', label: 'Transfer' },
              ]}
            />
          </div>
        )}

        {/* 3. Akun Sebagai Chip yang Bisa Di-scroll */}
        <div>
          <span className="mb-1.5 block text-xs font-medium text-muted-foreground">
            {type === 'transfer' ? 'Dari Akun' : 'Akun'}
          </span>
          <div
            role="radiogroup"
            aria-label="Pilih akun"
            className="flex items-center gap-2 overflow-x-auto pb-1"
          >
            {accounts.map((acc) => {
              const selected = acc.id === accountId;
              return (
                <button
                  key={acc.id}
                  type="button"
                  role="radio"
                  aria-checked={selected}
                  onClick={() => setAccountId(acc.id)}
                  className={cn(
                    'min-h-11 shrink-0 rounded-md border px-3.5 py-2 text-xs font-medium transition-colors duration-150',
                    selected
                      ? 'border-primary bg-primary-subtle text-primary font-semibold'
                      : 'border-border bg-card text-foreground hover:bg-subtle'
                  )}
                >
                  {acc.name}
                </button>
              );
            })}
          </div>
        </div>

        {/* 4. Kategori (atau Akun Tujuan) Sebagai Chip yang Bisa Di-scroll */}
        {type === 'transfer' ? (
          <div>
            <span className="mb-1.5 block text-xs font-medium text-muted-foreground">Ke Akun Tujuan</span>
            <div
              role="radiogroup"
              aria-label="Pilih akun tujuan"
              className="flex items-center gap-2 overflow-x-auto pb-1"
            >
              {accounts
                .filter((a) => a.id !== accountId)
                .map((acc) => {
                  const selected = acc.id === toAccountId;
                  return (
                    <button
                      key={acc.id}
                      type="button"
                      role="radio"
                      aria-checked={selected}
                      onClick={() => setToAccountId(acc.id)}
                      className={cn(
                        'min-h-11 shrink-0 rounded-md border px-3.5 py-2 text-xs font-medium transition-colors duration-150',
                        selected
                          ? 'border-primary bg-primary-subtle text-primary font-semibold'
                          : 'border-border bg-card text-foreground hover:bg-subtle'
                      )}
                    >
                      {acc.name}
                    </button>
                  );
                })}
            </div>
          </div>
        ) : (
          <div>
            <span className="mb-1.5 block text-xs font-medium text-muted-foreground">Kategori</span>
            <div
              role="radiogroup"
              aria-label="Pilih kategori"
              className="flex items-center gap-2 overflow-x-auto pb-1"
            >
              {filteredCategories.map((cat) => {
                const selected = cat.id === categoryId;
                return (
                  <button
                    key={cat.id}
                    type="button"
                    role="radio"
                    aria-checked={selected}
                    onClick={() => setCategoryId(cat.id)}
                    className={cn(
                      'min-h-11 shrink-0 rounded-md border px-3.5 py-2 text-xs font-medium transition-colors duration-150',
                      selected
                        ? 'border-primary bg-primary-subtle text-primary font-semibold'
                        : 'border-border bg-card text-foreground hover:bg-subtle'
                    )}
                  >
                    {cat.name}
                  </button>
                );
              })}
            </div>
          </div>
        )}

        {/* Baris Tanggal Default Hari Ini & Rincian Opsional */}
        <div className="flex items-center justify-between border-t border-border pt-2">
          <div className="text-xs text-muted-foreground">
            Tanggal: <span className="font-medium text-foreground tabular-nums">{txDate}</span>
          </div>
          <button
            type="button"
            onClick={() => setShowOptional((v) => !v)}
            className="min-h-11 px-2 text-xs font-medium text-primary hover:underline"
          >
            {showOptional ? 'Sembunyikan Rincian' : 'Ubah Tanggal / Catatan'}
          </button>
        </div>

        {showOptional && (
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 rounded-md border border-border bg-subtle/40 p-3">
            <div>
              <label htmlFor="tx-date-input" className="mb-1 block text-xs font-medium text-muted-foreground">
                Tanggal
              </label>
              <Input
                id="tx-date-input"
                type="date"
                value={txDate}
                onChange={(e) => setTxDate(e.target.value)}
              />
            </div>
            <div>
              <label htmlFor="tx-source-select" className="mb-1 block text-xs font-medium text-muted-foreground">
                Jenis Kegiatan
              </label>
              <select
                id="tx-source-select"
                value={source}
                onChange={(e) => setSource(e.target.value as TransactionSource)}
                className="h-11 w-full rounded-md border border-border bg-card px-3 py-2 text-sm text-foreground"
              >
                <option value="personal">Pribadi</option>
                <option value="intern">Intern</option>
                <option value="freelance">Freelance</option>
                <option value="kuliah">Kuliah</option>
              </select>
            </div>
            <div>
              <label htmlFor="tx-merchant-input" className="mb-1 block text-xs font-medium text-muted-foreground">
                Merchant / Pihak Kedua
              </label>
              <Input
                id="tx-merchant-input"
                type="text"
                placeholder="Contoh: Kopi Kenangan"
                value={merchant}
                onChange={(e) => setMerchant(e.target.value)}
              />
            </div>
            <div>
              <label htmlFor="tx-note-input" className="mb-1 block text-xs font-medium text-muted-foreground">
                Catatan
              </label>
              <Input
                id="tx-note-input"
                type="text"
                placeholder="Catatan singkat..."
                value={note}
                onChange={(e) => setNote(e.target.value)}
              />
            </div>
          </div>
        )}

        {/* Tombol Simpan Selalu Terlihat */}
        <div className="sticky bottom-0 flex items-center justify-end gap-2 border-t border-border bg-card pt-3">
          <Button variant="outline" onClick={onClose}>
            Batal
          </Button>
          <Button type="submit" variant="primary" disabled={submitting} className="min-w-36">
            {submitting ? 'Menyimpan...' : 'Simpan Transaksi'}
          </Button>
        </div>
      </form>
    </Dialog>
  );
}
