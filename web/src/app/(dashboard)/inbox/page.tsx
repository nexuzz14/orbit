'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';
import { formatCurrency, formatDateIndo } from '@/lib/format';
import type { Database, TransactionSource } from '@/types/database';
import { Inbox as InboxIcon, Check, Trash2, Edit3, X, AlertCircle } from 'lucide-react';

type DraftRow = Database['public']['Tables']['transactions']['Row'] & {
  account_name?: string | null;
  category_name?: string | null;
};

type Option = {
  id: string;
  name: string;
  type?: string;
};

export default function InboxPage() {
  const supabase = createClient();
  const [drafts, setDrafts] = useState<DraftRow[]>([]);
  const [accounts, setAccounts] = useState<Option[]>([]);
  const [categories, setCategories] = useState<Option[]>([]);
  const [loading, setLoading] = useState(true);

  // Modal untuk melengkapi draft sebelum konfirmasi
  const [selectedDraft, setSelectedDraft] = useState<DraftRow | null>(null);
  const [selectedCategory, setSelectedCategory] = useState<string>('');
  const [selectedSource, setSelectedSource] = useState<TransactionSource>('personal');
  const [confirmError, setConfirmError] = useState<string | null>(null);
  const [processing, setProcessing] = useState(false);

  const loadDrafts = useCallback(async () => {
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

    const wsId = memberData.workspace_id;

    const [accRes, catRes, draftRes] = await Promise.all([
      supabase.from('accounts').select('id, name').eq('workspace_id', wsId).is('deleted_at', null),
      supabase.from('categories').select('id, name, type').eq('workspace_id', wsId).is('deleted_at', null),
      supabase
        .from('transactions')
        .select('*')
        .eq('workspace_id', wsId)
        .eq('status', 'draft')
        .is('deleted_at', null)
        .order('occurred_at', { ascending: false }),
    ]);

    const accMap = new Map((accRes.data || []).map((a) => [a.id, a.name]));
    const catMap = new Map((catRes.data || []).map((c) => [c.id, c.name]));

    setAccounts(accRes.data || []);
    setCategories(catRes.data || []);

    const enriched: DraftRow[] = (draftRes.data || []).map((d) => ({
      ...d,
      account_name: accMap.get(d.account_id) || 'Akun',
      category_name: d.category_id ? catMap.get(d.category_id) : null,
    }));

    setDrafts(enriched);
    setLoading(false);
  }, [supabase]);

  useEffect(() => {
    loadDrafts();
  }, [loadDrafts]);

  const handleQuickConfirm = async (draft: DraftRow) => {
    if (!draft.category_id || !draft.source) {
      openCompleteModal(draft);
      return;
    }

    setProcessing(true);
    const { error } = await supabase.rpc('fn_confirm_draft', {
      p_transaction_id: draft.id,
      p_category_id: draft.category_id,
      p_source: draft.source,
    });

    if (error) {
      alert(`Gagal mengonfirmasi draft: ${error.message}`);
    } else {
      loadDrafts();
    }
    setProcessing(false);
  };

  const openCompleteModal = (draft: DraftRow) => {
    setSelectedDraft(draft);
    setSelectedCategory(draft.category_id || '');
    setSelectedSource(draft.source || (draft.type === 'expense' ? 'personal' : 'intern'));
    setConfirmError(null);
  };

  const handleCompleteSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedDraft) return;

    if (!selectedCategory) {
      setConfirmError('Pilih kategori transaksi.');
      return;
    }

    setProcessing(true);
    setConfirmError(null);

    const { error } = await supabase.rpc('fn_confirm_draft', {
      p_transaction_id: selectedDraft.id,
      p_category_id: selectedCategory,
      p_source: selectedSource,
    });

    if (error) {
      setConfirmError(error.message);
      setProcessing(false);
      return;
    }

    setProcessing(false);
    setSelectedDraft(null);
    loadDrafts();
  };

  const handleReject = async (id: string) => {
    if (!confirm('Tolak dan hapus draft ini?')) return;

    const { error } = await supabase.rpc('fn_delete_transaction', {
      p_transaction_id: id,
    });

    if (error) {
      alert(`Gagal menolak draft: ${error.message}`);
    } else {
      loadDrafts();
    }
  };

  const getDraftBadge = (state: string | null) => {
    switch (state) {
      case 'baru':
        return (
          <span className="text-[10px] font-semibold uppercase tracking-wider px-2 py-0.5 rounded bg-muted text-foreground">
            Baru
          </span>
        );
      case 'perlu_dilengkapi':
        return (
          <span className="text-[10px] font-semibold uppercase tracking-wider px-2 py-0.5 rounded bg-warning/10 text-warning">
            Perlu Dilengkapi
          </span>
        );
      case 'perlu_dicek':
        return (
          <span className="text-[10px] font-semibold uppercase tracking-wider px-2 py-0.5 rounded bg-expense/10 text-expense">
            Perlu Dicek
          </span>
        );
      default:
        return null;
    }
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Inbox Draft</h1>
        <p className="text-sm text-muted-foreground">
          Transaksi dari jalur otomatis menunggu verifikasi dan konfirmasi Anda sebelum masuk ke saldo
        </p>
      </div>

      <div className="border border-border bg-card rounded-lg overflow-hidden">
        {loading ? (
          <div className="p-8 text-center text-sm text-muted-foreground">Memuat antrean draft...</div>
        ) : drafts.length === 0 ? (
          <div className="p-12 text-center">
            <InboxIcon className="w-8 h-8 mx-auto text-muted-foreground mb-3 opacity-50" />
            <p className="text-sm font-medium">Kotak Masuk Bersih</p>
            <p className="text-xs text-muted-foreground mt-1">
              Tidak ada draft yang menunggu konfirmasi saat ini
            </p>
          </div>
        ) : (
          <div className="divide-y divide-border">
            {drafts.map((d) => {
              const isExpense = d.type === 'expense';
              const isComplete = !!d.category_id && !!d.source;

              return (
                <div
                  key={d.id}
                  className="p-4 flex flex-col sm:flex-row sm:items-center justify-between gap-4 hover:bg-muted/20 transition-colors"
                >
                  <div className="space-y-1">
                    <div className="flex items-center gap-2">
                      <span className="font-medium text-sm">
                        {d.merchant || d.product_name || 'Draft Transaksi'}
                      </span>
                      {getDraftBadge(d.draft_state)}
                      <span className="text-[10px] uppercase font-mono px-1.5 py-0.5 rounded bg-muted text-muted-foreground">
                        {d.origin}
                      </span>
                    </div>

                    <div className="text-xs text-muted-foreground flex items-center gap-2 flex-wrap">
                      <span>{formatDateIndo(d.occurred_at)}</span>
                      <span>•</span>
                      <span>{d.account_name}</span>
                      {d.category_name && (
                        <>
                          <span>•</span>
                          <span>{d.category_name}</span>
                        </>
                      )}
                      {d.source && (
                        <>
                          <span>•</span>
                          <span className="uppercase">{d.source}</span>
                        </>
                      )}
                    </div>
                  </div>

                  <div className="flex items-center justify-between sm:justify-end gap-4">
                    <div className="text-right">
                      <div
                        className={`text-sm font-semibold tabular-nums ${
                          isExpense ? 'text-expense' : 'text-income'
                        }`}
                      >
                        {isExpense ? '-' : '+'}
                        {formatCurrency(Number(d.amount), d.currency)}
                      </div>
                      <div className="text-[11px] text-muted-foreground uppercase">{d.type}</div>
                    </div>

                    <div className="flex items-center gap-1">
                      {isComplete ? (
                        <button
                          onClick={() => handleQuickConfirm(d)}
                          disabled={processing}
                          type="button"
                          title="Konfirmasi Langsung"
                          className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-foreground text-background text-xs font-medium rounded hover:opacity-90 transition-opacity"
                        >
                          <Check className="w-3.5 h-3.5" />
                          <span>Konfirmasi</span>
                        </button>
                      ) : (
                        <button
                          onClick={() => openCompleteModal(d)}
                          disabled={processing}
                          type="button"
                          className="inline-flex items-center gap-1.5 px-3 py-1.5 border border-border text-xs font-medium rounded hover:bg-muted transition-colors"
                        >
                          <Edit3 className="w-3.5 h-3.5" />
                          <span>Lengkapi</span>
                        </button>
                      )}

                      <button
                        onClick={() => handleReject(d.id)}
                        disabled={processing}
                        type="button"
                        title="Tolak Draft"
                        className="p-1.5 text-muted-foreground hover:text-expense rounded transition-colors"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Modal Lengkapi Draft */}
      {selectedDraft && (
        <div className="fixed inset-0 z-50 bg-background/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="w-full max-w-md border border-border bg-card rounded-lg shadow-lg p-6 space-y-4">
            <div className="flex items-center justify-between border-b border-border pb-3">
              <h2 className="text-lg font-semibold">Lengkapi & Konfirmasi Draft</h2>
              <button
                onClick={() => setSelectedDraft(null)}
                type="button"
                className="text-muted-foreground hover:text-foreground"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {confirmError && (
              <div className="p-3 text-sm rounded bg-expense/10 text-expense border border-expense/20 flex items-center gap-2">
                <AlertCircle className="w-4 h-4 shrink-0" />
                <span>{confirmError}</span>
              </div>
            )}

            <div className="p-3 bg-muted rounded-md text-xs space-y-1">
              <div>
                Merchant/Keterangan:{' '}
                <strong>{selectedDraft.merchant || selectedDraft.product_name || '-'}</strong>
              </div>
              <div>
                Nominal:{' '}
                <strong>{formatCurrency(Number(selectedDraft.amount), selectedDraft.currency)}</strong>
              </div>
              <div>Waktu: {formatDateIndo(selectedDraft.occurred_at)}</div>
            </div>

            <form onSubmit={handleCompleteSubmit} className="space-y-4">
              <div>
                <label className="block text-xs font-medium mb-1">Pilih Kategori</label>
                <select
                  value={selectedCategory}
                  onChange={(e) => setSelectedCategory(e.target.value)}
                  className="w-full px-3 py-2 text-sm border border-border rounded bg-background focus:outline-none"
                >
                  <option value="">Pilih Kategori...</option>
                  {categories
                    .filter((c) => c.type === selectedDraft.type)
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
                  value={selectedSource}
                  onChange={(e) => setSelectedSource(e.target.value as TransactionSource)}
                  className="w-full px-3 py-2 text-sm border border-border rounded bg-background focus:outline-none"
                >
                  <option value="personal">Personal</option>
                  <option value="intern">Intern</option>
                  <option value="freelance">Freelance</option>
                  <option value="kuliah">Kuliah</option>
                </select>
              </div>

              <div className="flex items-center justify-end gap-2 pt-4 border-t border-border">
                <button
                  type="button"
                  onClick={() => setSelectedDraft(null)}
                  className="px-4 py-2 text-sm font-medium border border-border rounded hover:bg-muted transition-colors"
                >
                  Batal
                </button>
                <button
                  type="submit"
                  disabled={processing}
                  className="px-4 py-2 text-sm font-medium bg-foreground text-background rounded hover:opacity-90 transition-opacity disabled:opacity-50"
                >
                  {processing ? 'Menyimpan...' : 'Konfirmasi Sekarang'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
