'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';
import { formatDateIndo } from '@/lib/format';
import { parseReceiptOrNotificationText, type ParsedReceiptDraft } from '@/lib/smart-alerts';
import { usePrivacyMode } from '@/lib/privacy-mode';
import { RealtimeStatusBadge, useOrbitRealtime } from '@/lib/use-orbit-realtime';
import type { Database, TransactionSource } from '@/types/database';
import {
  Inbox as InboxIcon,
  Check,
  Trash2,
  Edit3,
  AlertCircle,
  Sparkles,
  Link as LinkIcon,
  FileText,
  Image as ImageIcon,
  ShieldCheck,
  ScanText,
} from 'lucide-react';
import {
  Card,
  CardHeader,
  CardTitle,
  CardContent,
  Button,
  Input,
  Select,
  Textarea,
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
  currency?: string;
};

async function stripImageExifViaCanvas(file: File): Promise<string> {
  const objectUrl = URL.createObjectURL(file);
  try {
    const img = await new Promise<HTMLImageElement>((resolve, reject) => {
      const el = new window.Image();
      el.onload = () => resolve(el);
      el.onerror = () => reject(new Error('Gagal membaca berkas gambar lokal.'));
      el.src = objectUrl;
    });
    const maxDim = 1280;
    const scale = Math.min(1, maxDim / Math.max(img.width || 1, img.height || 1));
    const canvas = document.createElement('canvas');
    canvas.width = Math.max(1, Math.round(img.width * scale));
    canvas.height = Math.max(1, Math.round(img.height * scale));
    const ctx = canvas.getContext('2d');
    if (!ctx) {
      throw new Error('Konteks kanvas 2D tidak tersedia.');
    }
    ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
    return canvas.toDataURL('image/jpeg', 0.85);
  } finally {
    URL.revokeObjectURL(objectUrl);
  }
}

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
  const { formatAmount } = usePrivacyMode();
  const [workspaceId, setWorkspaceId] = useState<string | null>(null);
  const [drafts, setDrafts] = useState<DraftRow[]>([]);
  const [accounts, setAccounts] = useState<Option[]>([]);
  const [categories, setCategories] = useState<Option[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);

  const [rawExtractText, setRawExtractText] = useState('');
  const [parsedPreview, setParsedPreview] = useState<ParsedReceiptDraft | null>(null);
  const [extractAccountId, setExtractAccountId] = useState('');
  const [extractCategoryId, setExtractCategoryId] = useState('');
  const [extractError, setExtractError] = useState<string | null>(null);
  const [extractSuccess, setExtractSuccess] = useState<string | null>(null);
  const [savingExtractedDraft, setSavingExtractedDraft] = useState(false);
  const [sanitizedImagePreview, setSanitizedImagePreview] = useState<string | null>(null);
  const [sanitizedImageName, setSanitizedImageName] = useState<string | null>(null);

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
      setWorkspaceId(wsId);

      const [accRes, catRes, draftRes] = await Promise.all([
        supabase.from('accounts').select('id, name, currency').eq('workspace_id', wsId).is('deleted_at', null),
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

      const accList = (accRes.data || []) as Option[];
      const accMap = new Map(accList.map((a) => [a.id, a.name]));
      const catMap = new Map((catRes.data || []).map((c) => [c.id, c.name]));

      setAccounts(accList);
      if (accList.length > 0 && !extractAccountId) {
        setExtractAccountId(accList[0].id);
      }
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
  }, [supabase, extractAccountId]);

  useEffect(() => {
    loadDrafts();
  }, [loadDrafts]);

  const { status: realtimeStatus } = useOrbitRealtime({
    workspaceId,
    tables: ['transactions'],
    onChange: loadDrafts,
  });

  const handleLoadTextFile = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setExtractError(null);
    setExtractSuccess(null);
    try {
      const content = await file.text();
      setRawExtractText(content);
      const res = parseReceiptOrNotificationText(content);
      if (res.ok) {
        setParsedPreview(res.parsed);
      } else {
        setParsedPreview(null);
        setExtractError(res.error);
      }
    } catch {
      setExtractError('Gagal membaca berkas teks struk/notifikasi.');
    } finally {
      e.target.value = '';
    }
  };

  const handleAttachLocalImage = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setExtractError(null);
    try {
      const cleanDataUrl = await stripImageExifViaCanvas(file);
      setSanitizedImagePreview(cleanDataUrl);
      setSanitizedImageName(file.name);
    } catch (err: unknown) {
      setExtractError(
        err instanceof Error ? err.message : 'Gagal memproses lampiran gambar secara lokal.'
      );
    } finally {
      e.target.value = '';
    }
  };

  const handleAnalyzeExtractText = () => {
    setExtractError(null);
    setExtractSuccess(null);
    const res = parseReceiptOrNotificationText(rawExtractText);
    if (!res.ok) {
      setParsedPreview(null);
      setExtractError(res.error);
      return;
    }
    setParsedPreview(res.parsed);
  };

  const handleSaveExtractedDraft = async () => {
    if (!workspaceId) {
      setExtractError('Workspace belum siap. Muat ulang halaman dan coba lagi.');
      return;
    }
    if (!parsedPreview || !Number.isFinite(parsedPreview.amount) || parsedPreview.amount <= 0) {
      setExtractError('Nominal hasil ekstraksi wajib lebih besar dari 0 sebelum disimpan.');
      return;
    }
    const targetAccId = extractAccountId || accounts[0]?.id;
    if (!targetAccId) {
      setExtractError('Buat minimal 1 rekening di Uang / Akun untuk menyimpan draft.');
      return;
    }

    const targetAccount = accounts.find((a) => a.id === targetAccId);
    setSavingExtractedDraft(true);
    setExtractError(null);
    setExtractSuccess(null);

    try {
      const { error: insertErr } = await supabase.from('transactions').insert({
        workspace_id: workspaceId,
        account_id: targetAccId,
        category_id: extractCategoryId || null,
        type: parsedPreview.type,
        amount: parsedPreview.amount,
        amount_base: parsedPreview.amount,
        currency: targetAccount?.currency || 'IDR',
        merchant: parsedPreview.merchant,
        note: parsedPreview.note,
        occurred_at: parsedPreview.occurredAt,
        source: 'personal',
        status: 'draft',
        draft_state: parsedPreview.needsReview ? 'perlu_dicek' : 'perlu_dilengkapi',
        origin: parsedPreview.origin,
      });

      if (insertErr) {
        throw new Error(insertErr.message);
      }

      setExtractSuccess(
        parsedPreview.needsReview
          ? 'Draft tersimpan ke Inbox dengan label Perlu dicek untuk verifikasi manual.'
          : 'Draft hasil ekstraksi tersimpan ke Inbox dan siap dilengkapi atau dikonfirmasi.'
      );
      setRawExtractText('');
      setParsedPreview(null);
      setSanitizedImagePreview(null);
      setSanitizedImageName(null);
      await loadDrafts();
    } catch (err: unknown) {
      setExtractError(
        err instanceof Error ? err.message : 'Gagal menyimpan draft ke Inbox.'
      );
    } finally {
      setSavingExtractedDraft(false);
    }
  };

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
        <div className="flex items-center gap-2.5 flex-wrap">
          <h1 className="text-2xl font-bold tracking-tight text-foreground">Uang</h1>
          <RealtimeStatusBadge status={realtimeStatus} />
        </div>
        <p className="text-sm text-muted-foreground mt-0.5">
          Inbox draft dari tagihan berulang, impor CSV, ekstraksi teks struk/notifikasi, atau aplikasi pendamping Android sebelum masuk ke saldo riil
        </p>
      </div>

      <MoneySubNav draftCount={drafts.length} />

      {/* Panel Ekstrak Struk & Teks Notifikasi */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <ScanText className="w-4 h-4 text-primary" />
            <span>Ekstrak Struk &amp; Teks Notifikasi</span>
          </CardTitle>
          <StatusBadge variant="neutral">Hasil Masuk ke Draft Inbox</StatusBadge>
        </CardHeader>
        <CardContent className="space-y-4">
          <p className="text-xs text-muted-foreground leading-relaxed">
            Tempel pesan notifikasi bank/e-wallet Indonesia (BCA, Mandiri, BNI, BRI, GoPay, OVO, DANA, ShopeePay) atau teks struk (Alfamart, Indomaret). Catatan: OCR gambar otomatis berjalan offline di Android melalui ML Kit; di Web, ekstraksi teks menghasilkan draft <code className="font-mono text-foreground">status: draft</code> untuk ditinjau.
          </p>

          <Textarea
            rows={4}
            aria-label="Teks struk atau notifikasi transaksi"
            placeholder="Contoh: BCA Mobile: Pembayaran QRIS di Kopi Kenangan sebesar Rp 45.000,00 pada 15/11/2026 09:30 WIB berhasil."
            value={rawExtractText}
            onChange={(e) => setRawExtractText(e.target.value)}
          />

          <div className="flex flex-wrap items-center gap-2.5">
            <Button
              type="button"
              onClick={handleAnalyzeExtractText}
              data-testid="inbox-extract-btn"
            >
              <ScanText className="w-4 h-4" />
              <span>Ekstrak Teks</span>
            </Button>

            <label className="min-h-11 inline-flex items-center gap-2 rounded-md border border-border bg-card px-3.5 text-xs font-medium text-foreground hover:bg-hover cursor-pointer transition-colors">
              <FileText className="w-4 h-4 text-primary" />
              <span>Muat Berkas .txt</span>
              <input
                type="file"
                accept=".txt,text/plain"
                onChange={handleLoadTextFile}
                className="sr-only"
              />
            </label>

            <label className="min-h-11 inline-flex items-center gap-2 rounded-md border border-border bg-card px-3.5 text-xs font-medium text-foreground hover:bg-hover cursor-pointer transition-colors">
              <ImageIcon className="w-4 h-4 text-primary" />
              <span>Lampirkan Foto Struk (Bebas EXIF)</span>
              <input
                type="file"
                accept="image/png,image/jpeg,image/webp"
                onChange={handleAttachLocalImage}
                className="sr-only"
              />
            </label>
          </div>

          {sanitizedImagePreview && (
            <div className="rounded-lg border border-border bg-subtle p-3 flex flex-col sm:flex-row sm:items-center gap-3">
              <img
                src={sanitizedImagePreview}
                alt="Pratinjau lampiran struk yang sudah dibersihkan EXIF"
                className="h-20 w-20 object-cover rounded-md border border-border bg-card shrink-0"
              />
              <div className="space-y-1 text-xs">
                <div className="font-semibold text-foreground flex items-center gap-1.5">
                  <ShieldCheck className="w-4 h-4 text-income" />
                  <span>Lampiran lokal siap ({sanitizedImageName})</span>
                </div>
                <p className="text-muted-foreground">
                  Metadata EXIF/lokasi kamera telah dihapus di browser via kanvas lokal. Salin teks penting dari struk ke kolom di atas untuk ekstraksi otomatis.
                </p>
              </div>
            </div>
          )}

          {extractError && (
            <div
              role="alert"
              className="rounded-md border border-expense-border bg-expense-subtle p-3 text-xs text-expense flex items-center gap-2"
            >
              <AlertCircle className="w-4 h-4 shrink-0" />
              <span>{extractError}</span>
            </div>
          )}

          {extractSuccess && (
            <div
              role="status"
              className="rounded-md border border-income-border bg-income-subtle p-3 text-xs text-income flex items-center gap-2"
            >
              <Check className="w-4 h-4 shrink-0" />
              <span>{extractSuccess}</span>
            </div>
          )}

          {parsedPreview && (
            <div
              data-testid="inbox-extract-preview"
              className="rounded-lg border border-border bg-subtle p-4 space-y-3"
            >
              <div className="flex flex-wrap items-center justify-between gap-2">
                <div className="flex items-center gap-2 flex-wrap">
                  <span className="text-sm font-semibold text-foreground">
                    Pratinjau Draft Terdeteksi
                  </span>
                  {parsedPreview.needsReview ? (
                    <StatusBadge variant="expense">Perlu dicek</StatusBadge>
                  ) : (
                    <StatusBadge variant="warning">Siap ke Inbox Draft</StatusBadge>
                  )}
                  <StatusBadge variant="neutral">
                    {parsedPreview.origin === 'receipt' ? 'Struk' : 'Notifikasi'}
                  </StatusBadge>
                </div>
                <span className="text-xs text-muted-foreground">
                  Keyakinan: <strong className="uppercase">{parsedPreview.confidence}</strong>
                </span>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 text-xs">
                <div className="rounded-md border border-border bg-card p-2.5">
                  <div className="text-muted-foreground">Merchant / Sumber</div>
                  <div className="font-semibold text-foreground mt-0.5 truncate">
                    {parsedPreview.merchant}
                  </div>
                </div>
                <div className="rounded-md border border-border bg-card p-2.5">
                  <div className="text-muted-foreground">Nominal</div>
                  <div
                    className={`font-bold mt-0.5 tabular-nums ${
                      parsedPreview.type === 'expense' ? 'text-expense' : 'text-income'
                    }`}
                  >
                    {parsedPreview.type === 'expense' ? '-' : '+'}
                    {formatAmount(parsedPreview.amount, 'IDR')}
                  </div>
                </div>
                <div className="rounded-md border border-border bg-card p-2.5">
                  <div className="text-muted-foreground">Jenis Transaksi</div>
                  <div className="font-semibold text-foreground mt-0.5">
                    {parsedPreview.type === 'expense' ? 'Pengeluaran' : 'Pemasukan'}
                  </div>
                </div>
                <div className="rounded-md border border-border bg-card p-2.5">
                  <div className="text-muted-foreground">Waktu (WIB)</div>
                  <div className="font-semibold text-foreground mt-0.5 tabular-nums">
                    {formatDateIndo(parsedPreview.occurredAt)}
                  </div>
                </div>
              </div>

              {parsedPreview.reviewReasons.length > 0 && (
                <div className="text-xs text-muted-foreground">
                  Catatan verifikasi: {parsedPreview.reviewReasons.join('; ')}.
                </div>
              )}

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-medium text-foreground mb-1">
                    Rekening Draft
                  </label>
                  <Select
                    value={extractAccountId}
                    onChange={(e) => setExtractAccountId(e.target.value)}
                    aria-label="Pilih rekening tujuan draft"
                  >
                    {accounts.length === 0 ? (
                      <option value="">Belum ada rekening</option>
                    ) : (
                      accounts.map((acc) => (
                        <option key={acc.id} value={acc.id}>
                          {acc.name}
                        </option>
                      ))
                    )}
                  </Select>
                </div>

                <div>
                  <label className="block text-xs font-medium text-foreground mb-1">
                    Kategori Awal (Opsional)
                  </label>
                  <Select
                    value={extractCategoryId}
                    onChange={(e) => setExtractCategoryId(e.target.value)}
                    aria-label="Pilih kategori awal draft"
                  >
                    <option value="">Lengkapi nanti di Inbox</option>
                    {categories
                      .filter((c) => !c.type || c.type === parsedPreview.type)
                      .map((cat) => (
                        <option key={cat.id} value={cat.id}>
                          {cat.name}
                        </option>
                      ))}
                  </Select>
                </div>
              </div>

              <div className="flex flex-wrap justify-end gap-2 pt-1">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => setParsedPreview(null)}
                >
                  Batal
                </Button>
                <Button
                  type="button"
                  disabled={savingExtractedDraft}
                  onClick={handleSaveExtractedDraft}
                  data-testid="inbox-save-draft-btn"
                >
                  {savingExtractedDraft ? 'Menyimpan...' : 'Simpan ke Inbox Draft'}
                </Button>
              </div>
            </div>
          )}
        </CardContent>
      </Card>

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
                className="p-4 flex flex-col sm:flex-row sm:items-center justify-between gap-4 hover:bg-hover transition-colors"
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
                      {formatAmount(Number(d.amount), d.currency)}
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
              <div className="p-3 text-xs rounded-lg bg-expense-subtle text-expense border border-expense-border flex items-center gap-2">
                <AlertCircle className="w-4 h-4 shrink-0" />
                <span>{confirmError}</span>
              </div>
            )}

            <div className="p-3.5 bg-subtle border border-border rounded-lg text-xs space-y-1 tabular-nums">
              <div>
                Merchant / Keterangan:{' '}
                <strong className="text-foreground">
                  {selectedDraft.merchant || selectedDraft.product_name || '-'}
                </strong>
              </div>
              <div>
                Nominal:{' '}
                <strong className="text-foreground">
                  {formatAmount(Number(selectedDraft.amount), selectedDraft.currency)}
                </strong>
              </div>
              <div>Waktu: {formatDateIndo(selectedDraft.occurred_at)}</div>
            </div>

            {matchedIncome && (
              <div className="p-3.5 rounded-lg border border-primary bg-primary-subtle space-y-2">
                <div className="flex items-center gap-2 text-xs font-semibold text-primary">
                  <Sparkles className="w-4 h-4" />
                  <span>Rekomendasi Pencocokan Rencana Ditemukan</span>
                </div>
                <div className="text-xs text-foreground space-y-0.5 tabular-nums">
                  <div className="font-medium">{matchedIncome.title}</div>
                  <div className="text-muted-foreground">
                    Target: {formatAmount(matchedIncome.expected_amount)} | Keyakinan:{' '}
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
