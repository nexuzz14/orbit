'use client';

import React, { useMemo, useState } from 'react';
import { FileSpreadsheet, Upload } from 'lucide-react';
import { createClient } from '@/lib/supabase/client';
import { formatCurrency, formatDateOnly } from '@/lib/format';
import {
  parseBankMutationCsv,
  type ParsedBankMutationRow,
  type ParsedMutationType,
} from '@/lib/finance-v2';
import {
  Button,
  Dialog,
  Input,
  Select,
  StatusBadge,
  Textarea,
} from '@/components/ui';

type TransactionSource = 'intern' | 'freelance' | 'kuliah' | 'personal';

export interface CsvImportAccountOption {
  id: string;
  name: string;
  currency: string;
}

export interface CsvImportCategoryOption {
  id: string;
  name: string;
  type: string;
}

export function CsvImportModal({
  open,
  onClose,
  workspaceId,
  accounts,
  categories,
  onImported,
}: {
  open: boolean;
  onClose: () => void;
  workspaceId: string;
  accounts: CsvImportAccountOption[];
  categories: CsvImportCategoryOption[];
  onImported: (importedCount: number) => void;
}) {
  const supabase = useMemo(() => createClient(), []);

  const [csvText, setCsvText] = useState('');
  const [accountId, setAccountId] = useState(() => accounts[0]?.id ?? '');
  const [defaultSource, setDefaultSource] = useState<TransactionSource>('personal');
  const [targetStatus, setTargetStatus] = useState<'confirmed' | 'draft'>('confirmed');
  const [incomeCategoryId, setIncomeCategoryId] = useState('');
  const [expenseCategoryId, setExpenseCategoryId] = useState('');
  const [typeOverrides, setTypeOverrides] = useState<Record<number, ParsedMutationType>>({});
  const [excludedRows, setExcludedRows] = useState<Record<number, boolean>>({});
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const selectedAccount = useMemo(
    () => accounts.find((a) => a.id === accountId) ?? accounts[0] ?? null,
    [accounts, accountId]
  );

  const incomeCategories = useMemo(
    () => categories.filter((c) => c.type === 'income'),
    [categories]
  );
  const expenseCategories = useMemo(
    () => categories.filter((c) => c.type === 'expense'),
    [categories]
  );

  const parsedResult = useMemo(() => {
    if (!csvText.trim()) return null;
    return parseBankMutationCsv(csvText);
  }, [csvText]);

  const activeRows: ParsedBankMutationRow[] = useMemo(() => {
    if (!parsedResult) return [];
    return parsedResult.rows
      .filter((row) => !excludedRows[row.rowNumber])
      .map((row) => ({
        ...row,
        type: typeOverrides[row.rowNumber] ?? row.type,
      }));
  }, [parsedResult, excludedRows, typeOverrides]);

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setError(null);
    const content = await file.text();
    setCsvText(content);
    setExcludedRows({});
    setTypeOverrides({});
  };

  const handleCommitImport = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!workspaceId) return;
    const effectiveAccountId = accountId || accounts[0]?.id;
    if (!effectiveAccountId) {
      setError('Pilih akun tujuan terlebih dahulu (buat akun di tab Akun jika belum ada).');
      return;
    }
    if (activeRows.length === 0) {
      setError('Tidak ada baris mutasi valid untuk diimpor.');
      return;
    }

    setSaving(true);
    setError(null);

    const currency = selectedAccount?.currency || 'IDR';
    const fallbackIncomeCat = incomeCategoryId || incomeCategories[0]?.id || null;
    const fallbackExpenseCat = expenseCategoryId || expenseCategories[0]?.id || null;

    const payload = activeRows.map((row) => ({
      workspace_id: workspaceId,
      account_id: effectiveAccountId,
      category_id: row.type === 'income' ? fallbackIncomeCat : fallbackExpenseCat,
      type: row.type,
      amount: row.amount,
      amount_base: row.amount,
      currency,
      fx_rate: 1,
      merchant: row.merchant,
      note: row.description !== row.merchant ? row.description.slice(0, 500) : null,
      occurred_at: row.occurredAt,
      origin: 'statement' as const,
      source: defaultSource,
      status: targetStatus,
    }));

    const { error: insertError } = await supabase.from('transactions').insert(payload);
    setSaving(false);

    if (insertError) {
      setError(insertError.message);
      return;
    }

    const count = payload.length;
    setCsvText('');
    setExcludedRows({});
    setTypeOverrides({});
    onImported(count);
    onClose();
  };

  return (
    <Dialog
      open={open}
      onClose={onClose}
      title="Impor Mutasi Rekening (CSV)"
      description="Mendukung format CSV pemisah koma (,) atau titik koma (;) dengan deteksi otomatis Debit/Kredit."
    >
      <form onSubmit={handleCommitImport} className="space-y-4">
        {error && (
          <div className="rounded-md border border-expense-border bg-expense-subtle p-3 text-xs text-expense">
            {error}
          </div>
        )}

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">
              Unggah File CSV Mutasi
            </label>
            <Input type="file" accept=".csv,text/csv,text/plain" onChange={handleFileChange} />
          </div>

          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">
              Akun Tujuan <span className="text-expense">*</span>
            </label>
            <Select
              value={accountId || accounts[0]?.id || ''}
              onChange={(e) => setAccountId(e.target.value)}
              required
            >
              {accounts.length === 0 ? (
                <option value="">(Belum ada akun)</option>
              ) : (
                accounts.map((acc) => (
                  <option key={acc.id} value={acc.id}>
                    {acc.name} ({acc.currency})
                  </option>
                ))
              )}
            </Select>
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">
              Sumber Aktivitas
            </label>
            <Select
              value={defaultSource}
              onChange={(e) => setDefaultSource(e.target.value as TransactionSource)}
            >
              <option value="personal">Pribadi</option>
              <option value="freelance">Freelance</option>
              <option value="intern">Magang</option>
              <option value="kuliah">Kuliah</option>
            </Select>
          </div>

          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">
              Status Hasil Impor
            </label>
            <Select
              value={targetStatus}
              onChange={(e) => setTargetStatus(e.target.value as 'confirmed' | 'draft')}
            >
              <option value="confirmed">Terkonfirmasi Langsung</option>
              <option value="draft">Draft (Periksa di Inbox)</option>
            </Select>
          </div>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">
              Kategori Pemasukan Default
            </label>
            <Select value={incomeCategoryId} onChange={(e) => setIncomeCategoryId(e.target.value)}>
              <option value="">Otomatis / Tanpa Kategori</option>
              {incomeCategories.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </Select>
          </div>
          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">
              Kategori Pengeluaran Default
            </label>
            <Select value={expenseCategoryId} onChange={(e) => setExpenseCategoryId(e.target.value)}>
              <option value="">Otomatis / Tanpa Kategori</option>
              {expenseCategories.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </Select>
          </div>
        </div>

        <div>
          <label className="text-xs font-medium text-foreground block mb-1.5">
            Atau Tempel Data CSV Mutasi
          </label>
          <Textarea
            value={csvText}
            onChange={(e) => {
              setCsvText(e.target.value);
              setExcludedRows({});
              setTypeOverrides({});
            }}
            rows={4}
            placeholder={'Tanggal;Keterangan;Debit;Kredit;Saldo\n15/11/2026;Warung Kopi;35.000;0;1.500.000\n16/11/2026;Transfer Klien;0;2.000.000;3.500.000'}
          />
        </div>

        {parsedResult && (
          <div className="rounded-md border border-border bg-subtle p-3 space-y-2.5">
            <div className="flex flex-wrap items-center justify-between gap-2 text-xs">
              <div className="flex items-center gap-1.5 font-semibold text-foreground">
                <FileSpreadsheet className="w-4 h-4 text-primary" />
                <span className="tabular-nums">
                  {activeRows.length} baris siap diimpor (pemisah &quot;{parsedResult.delimiter}&quot;)
                </span>
              </div>
              {parsedResult.skippedRows.length > 0 && (
                <span className="text-muted-foreground tabular-nums">
                  {parsedResult.skippedRows.length} baris dilewati
                </span>
              )}
            </div>

            {parsedResult.rows.length > 0 && (
              <div className="max-h-52 overflow-y-auto divide-y divide-border rounded-sm border border-border bg-card">
                {parsedResult.rows.slice(0, 25).map((row) => {
                  const isExcluded = Boolean(excludedRows[row.rowNumber]);
                  const effectiveType = typeOverrides[row.rowNumber] ?? row.type;
                  return (
                    <div
                      key={row.rowNumber}
                      className="flex flex-wrap items-center justify-between gap-2 px-3 py-2 text-xs"
                    >
                      <label className="flex items-center gap-2 min-w-0 flex-1 cursor-pointer">
                        <input
                          type="checkbox"
                          checked={!isExcluded}
                          onChange={(e) =>
                            setExcludedRows((prev) => ({
                              ...prev,
                              [row.rowNumber]: !e.target.checked,
                            }))
                          }
                          className="h-4 w-4 rounded border-border text-primary"
                        />
                        <div className="min-w-0">
                          <div className="font-medium text-foreground truncate">{row.merchant}</div>
                          <div className="text-[11px] text-muted-foreground tabular-nums">
                            {formatDateOnly(row.occurredDate)}
                          </div>
                        </div>
                      </label>

                      <div className="flex items-center gap-2 shrink-0">
                        <button
                          type="button"
                          onClick={() =>
                            setTypeOverrides((prev) => ({
                              ...prev,
                              [row.rowNumber]: effectiveType === 'income' ? 'expense' : 'income',
                            }))
                          }
                          className="min-h-11 px-2 rounded-sm hover:bg-hover"
                          title="Klik untuk tukar Pemasukan/Pengeluaran"
                        >
                          <StatusBadge variant={effectiveType === 'income' ? 'income' : 'expense'}>
                            {effectiveType === 'income' ? 'Masuk' : 'Keluar'}
                          </StatusBadge>
                        </button>
                        <span className="font-semibold text-foreground tabular-nums">
                          {formatCurrency(row.amount, selectedAccount?.currency || 'IDR')}
                        </span>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </div>
        )}

        <div className="flex justify-end gap-2 pt-3 border-t border-border">
          <Button type="button" variant="secondary" onClick={onClose}>
            Batal
          </Button>
          <Button type="submit" disabled={saving || activeRows.length === 0}>
            <Upload className="w-4 h-4" />
            <span>{saving ? 'Mengimpor...' : `Impor ${activeRows.length} Transaksi`}</span>
          </Button>
        </div>
      </form>
    </Dialog>
  );
}
