'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';
import { formatCurrency, formatDateIndo } from '@/lib/format';
import type { Database, TransactionSource } from '@/types/database';
import {
  Inbox as InboxIcon,
  Check,
  Trash2,
  Edit3,
  AlertCircle,
  Sparkles,
  Link as LinkIcon,
} from 'lucide-react';
import {
  Card,
  Button,
  Select,
  Dialog,
  KindBadge,
  StatusBadge,
  Skeleton,
  EmptyState,
  ErrorState,
  MoneySubNav,
} from '@/components/ui';

type DraftRow = Database['public']['Tables']['transactions']['Row'] & {
  account_name?: string | null;
  category_name?: string | null;
};

type Option = {
  id: string;
  name: string;
  type?: string;
};

interface MatchedExpectedIncome {
  expected_income_id: string;
  title: string;
  expected_amount: number;
  expected_date: string;
  source: string;
  confidence: 'exact' | 'high' | 'medium';
  days_difference: number;
  amount_difference: number;
}

export default function InboxPage() {
  const supabase = createClient();
  const [drafts, setDrafts] = useState<DraftRow[]>([]);
  const [, setAccounts] = useState<Option[]>([]);
  const [categories, setCategories] = useState<Option[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);

  const [selectedDraft, setSelectedDraft] = useState<DraftRow | null>(null);
  const [selectedCategory, setSelectedCategory] = useState<string>('');
  const [selectedSource, setSelectedSource] = useState<TransactionSource>('personal');
  const [confirmError, setConfirmError] = useState<string | null>(null);
  const [processing, setProcessing] = useState(false);

  const [matchedIncome, setMatchedIncome] = useState<MatchedExpectedIncome | null>(null);

  const loadDrafts = useCallback(async () => {
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

      if (draftRes.error) throw draftRes.error;

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
    } catch (err: unknown) {
      setLoadError(err instanceof Error ? err.message : 'Gagal memuat antrean draft.');
    } finally {
      setLoading(false);
    }
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

  const openCompleteModal = async (draft: DraftRow) => {
    setSelectedDraft(draft);
    setSelectedCategory(draft.category_id || '');
    setSelectedSource(draft.source || (draft.type === 'expense' ? 'personal' : 'intern'));
    setConfirmError(null);
    setMatchedIncome(null);

    if (draft.type === 'income') {
      const { data: matchData } = await supabase.rpc('fn_match_expected_income', {
        p_draft_id: draft.id,
      });

      if (matchData && Array.isArray(matchData) && matchData.length > 0) {
        const topMatch = matchData[0] as unknown as MatchedExpectedIncome;
        setMatchedIncome(topMatch);
        if (topMatch.source) {
          setSelectedSource(topMatch.source as TransactionSource);
        }
      }
    }
  };

  const handleConfirmWithExpectedIncome = async () => {
    if (!selectedDraft || !matchedIncome) return;

    setProcessing(true);
    setConfirmError(null);

    try {
      const { error } = await supabase.rpc('fn_confirm_expected_income', {
        p_expected_income_id: matchedIncome.expected_income_id,
        p_draft_id: selectedDraft.id,
        p_account_id: selectedDraft.account_id,
      });

      if (error) throw error;

      setSelectedDraft(null);
      setMatchedIncome(null);
      await loadDrafts();
    } catch (err: unknown) {
      setConfirmError(err instanceof Error ? err.message : 'Gagal mencocokkan rencana pemasukan.');
    } finally {
      setProcessing(false);
    }
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
        return <StatusBadge variant="neutral">Baru</StatusBadge>;
      case 'perlu_dilengkapi':
        return <StatusBadge variant="warning">Perlu Dilengkapi</StatusBadge>;
      case 'perlu_dicek':
        return <StatusBadge variant="expense">Perlu Dicek</StatusBadge>;
      default:
        return <StatusBadge variant="warning">Draft</StatusBadge>;
    }
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight text-foreground">Uang</h1>
        <p className="text-sm text-muted-foreground mt-0.5">
          Inbox draft dari jalur otomatis menunggu konfirmasi Anda sebelum masuk ke saldo riil
        </p>
      </div>

      <MoneySubNav draftCount={drafts.length} />

      {loadError ? (
        <ErrorState message={loadError} onRetry={loadDrafts} />
      ) : loading ? (
        <div className="space-y-3" aria-busy="true">
          <Skeleton className="h-20 w-full" />
          <Skeleton className="h-20 w-full" />
        </div>
      ) : drafts.length === 0 ? (
        <EmptyState
          icon={<InboxIcon className="w-5 h-5" />}
          title="Kotak masuk draft bersih"
          description="Tidak ada draft transaksi otomatis yang menunggu konfirmasi saat ini."
          actionLabel="Muat Ulang"
          onAction={loadDrafts}
        />
      ) : (
        <Card className="overflow-hidden divide-y divide-border">
          {drafts.map((d) => {
            const isExpense = d.type === 'expense';
            const isComplete = !!d.category_id && !!d.source;

            return (
              <div
                key={d.id}
                className="p-4 flex flex-col sm:flex-row sm:items-center justify-between gap-4 hover:bg-muted/20 transition-colors"
              >
                <div className="space-y-1.5">
                  <div className="flex items-center gap-2 flex-wrap">
                    <span className="font-semibold text-sm text-foreground">
                      {d.merchant || d.product_name || 'Draft Transaksi'}
                    </span>
                    {getDraftBadge(d.draft_state)}
                    <StatusBadge variant="neutral">{d.origin}</StatusBadge>
                    {d.source && <KindBadge kind={d.source} />}
                  </div>

                  <div className="text-xs text-muted-foreground flex items-center gap-2 flex-wrap tabular-nums">
                    <span>{formatDateIndo(d.occurred_at)}</span>
                    <span>•</span>
                    <span>{d.account_name}</span>
                    {d.category_name && (
                      <>
                        <span>•</span>
                        <span>{d.category_name}</span>
                      </>
                    )}
                  </div>
                </div>

                <div className="flex items-center justify-between sm:justify-end gap-4">
                  <div className="text-right">
                    <div
                      className={`text-sm font-bold tabular-nums ${
                        isExpense ? 'text-expense' : 'text-income'
                      }`}
                    >
                      {isExpense ? '-' : '+'}
                      {formatCurrency(Number(d.amount), d.currency)}
                    </div>
                    <div className="text-xs text-muted-foreground uppercase">{d.type}</div>
                  </div>

                  <div className="flex items-center gap-1.5">
                    {isComplete ? (
                      <Button
                        onClick={() => handleQuickConfirm(d)}
                        disabled={processing}
                        type="button"
                        size="sm"
                      >
                        <Check className="w-4 h-4" />
                        <span>Konfirmasi</span>
                      </Button>
                    ) : (
                      <Button
                        onClick={() => openCompleteModal(d)}
                        disabled={processing}
                        type="button"
                        variant="secondary"
                        size="sm"
                      >
                        <Edit3 className="w-4 h-4" />
                        <span>Lengkapi</span>
                      </Button>
                    )}

                    <Button
                      onClick={() => handleReject(d.id)}
                      disabled={processing}
                      type="button"
                      variant="ghost"
                      size="icon"
                      aria-label="Tolak Draft"
                    >
                      <Trash2 className="w-4 h-4 text-muted-foreground hover:text-expense" />
                    </Button>
                  </div>
                </div>
              </div>
            );
          })}
        </Card>
      )}

      {/* Modal Lengkapi Draft */}
      <Dialog
        open={!!selectedDraft}
        onClose={() => setSelectedDraft(null)}
        title="Lengkapi & Konfirmasi Draft"
      >
        {selectedDraft && (
          <div className="space-y-4">
            {confirmError && (
              <div className="p-3 text-xs rounded-lg bg-expense/10 text-expense border border-expense/20 flex items-center gap-2">
                <AlertCircle className="w-4 h-4 shrink-0" />
                <span>{confirmError}</span>
              </div>
            )}

            <div className="p-3.5 bg-muted/50 border border-border rounded-lg text-xs space-y-1 tabular-nums">
              <div>
                Merchant / Keterangan:{' '}
                <strong className="text-foreground">
                  {selectedDraft.merchant || selectedDraft.product_name || '-'}
                </strong>
              </div>
              <div>
                Nominal:{' '}
                <strong className="text-foreground">
                  {formatCurrency(Number(selectedDraft.amount), selectedDraft.currency)}
                </strong>
              </div>
              <div>Waktu: {formatDateIndo(selectedDraft.occurred_at)}</div>
            </div>

            {matchedIncome && (
              <div className="p-3.5 rounded-lg border border-primary/30 bg-primary/5 space-y-2">
                <div className="flex items-center gap-2 text-xs font-semibold text-primary">
                  <Sparkles className="w-4 h-4" />
                  <span>Rekomendasi Pencocokan Rencana Ditemukan</span>
                </div>
                <div className="text-xs text-foreground space-y-0.5 tabular-nums">
                  <div className="font-medium">{matchedIncome.title}</div>
                  <div className="text-muted-foreground">
                    Target: {formatCurrency(matchedIncome.expected_amount)} | Keyakinan:{' '}
                    <span className="font-semibold uppercase">{matchedIncome.confidence}</span>
                  </div>
                </div>
                <Button
                  onClick={handleConfirmWithExpectedIncome}
                  disabled={processing}
                  type="button"
                  size="sm"
                  className="w-full"
                >
                  <LinkIcon className="w-4 h-4" />
                  <span>Konfirmasi & Tautkan ke Rencana Ini</span>
                </Button>
              </div>
            )}

            <form onSubmit={handleCompleteSubmit} className="space-y-4">
              <div>
                <label className="block text-xs font-medium text-foreground mb-1.5">Pilih Kategori</label>
                <Select
                  value={selectedCategory}
                  onChange={(e) => setSelectedCategory(e.target.value)}
                >
                  <option value="">Pilih Kategori...</option>
                  {categories
                    .filter((c) => c.type === selectedDraft.type)
                    .map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.name}
                      </option>
                    ))}
                </Select>
              </div>

              <div>
                <label className="block text-xs font-medium text-foreground mb-1.5">Sumber Kegiatan</label>
                <Select
                  value={selectedSource}
                  onChange={(e) => setSelectedSource(e.target.value as TransactionSource)}
                >
                  <option value="personal">Pribadi</option>
                  <option value="intern">Magang</option>
                  <option value="freelance">Freelance</option>
                  <option value="kuliah">Kuliah</option>
                </Select>
              </div>

              <div className="flex items-center justify-end gap-2 pt-3 border-t border-border">
                <Button
                  type="button"
                  variant="secondary"
                  onClick={() => setSelectedDraft(null)}
                >
                  Batal
                </Button>
                <Button type="submit" disabled={processing}>
                  {processing ? 'Menyimpan...' : 'Konfirmasi Sekarang'}
                </Button>
              </div>
            </form>
          </div>
        )}
      </Dialog>
    </div>
  );
}
