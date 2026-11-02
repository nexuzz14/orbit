'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';
import { formatCurrency } from '@/lib/format';
import type { RecurringBill, Category, Account } from '@/types/database';
import {
  CalendarClock,
  Plus,
  Edit2,
  Trash2,
  CheckCircle2,
  RefreshCw,
  X,
  Play,
  Clock,
} from 'lucide-react';
import {
  Card,
  CardHeader,
  CardTitle,
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

interface ExtendedRecurringBill extends RecurringBill {
  category?: { name: string } | null;
  account?: { name: string } | null;
}

export default function TagihanPage() {
  const supabase = createClient();
  const [bills, setBills] = useState<ExtendedRecurringBill[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [workspaceId, setWorkspaceId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [generating, setGenerating] = useState(false);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);

  const [showModal, setShowModal] = useState(false);
  const [formMode, setFormMode] = useState<'create' | 'edit'>('create');
  const [editingId, setEditingId] = useState<string | null>(null);

  const [name, setName] = useState('');
  const [amount, setAmount] = useState('');
  const [categoryId, setCategoryId] = useState('');
  const [accountId, setAccountId] = useState('');
  const [scheduleType, setScheduleType] = useState<'monthly' | 'weekly' | 'yearly'>('monthly');
  const [scheduleValue, setScheduleValue] = useState('1');
  const [remindDaysBefore, setRemindDaysBefore] = useState('3');
  const [active, setActive] = useState(true);
  const [autoCreateDraft, setAutoCreateDraft] = useState(true);
  const [formError, setFormError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  const loadData = useCallback(async () => {
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

      const { data: billsData, error: billsErr } = await supabase
        .from('recurring_bills')
        .select(`
          *,
          category:categories(name),
          account:accounts(name)
        `)
        .eq('workspace_id', memberData.workspace_id)
        .is('deleted_at', null)
        .order('schedule_value', { ascending: true });

      if (billsErr) throw billsErr;
      if (billsData) {
        setBills(billsData as unknown as ExtendedRecurringBill[]);
      }

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

      const { data: accData } = await supabase
        .from('accounts')
        .select('*')
        .eq('workspace_id', memberData.workspace_id)
        .is('deleted_at', null)
        .eq('archived', false)
        .order('name');

      if (accData) {
        setAccounts(accData);
        if (accData.length > 0 && !accountId) {
          setAccountId(accData[0].id);
        }
      }
    } catch (err: unknown) {
      setLoadError(err instanceof Error ? err.message : 'Gagal memuat daftar tagihan rutin.');
    } finally {
      setLoading(false);
    }
  }, [supabase, categoryId, accountId]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  const openCreateModal = () => {
    setName('');
    setAmount('');
    if (categories.length > 0) setCategoryId(categories[0].id);
    if (accounts.length > 0) setAccountId(accounts[0].id);
    setScheduleType('monthly');
    setScheduleValue('1');
    setRemindDaysBefore('3');
    setActive(true);
    setAutoCreateDraft(true);
    setFormError(null);
    setFormMode('create');
    setEditingId(null);
    setShowModal(true);
  };

  const openEditModal = (bill: ExtendedRecurringBill) => {
    setEditingId(bill.id);
    setName(bill.name);
    setAmount(bill.amount?.toString() || '0');
    setCategoryId(bill.category_id || (categories[0]?.id || ''));
    setAccountId(bill.account_id || (accounts[0]?.id || ''));
    setScheduleType((bill.schedule_type as 'monthly' | 'weekly' | 'yearly') || 'monthly');
    setScheduleValue(bill.schedule_value?.toString() || '1');
    setRemindDaysBefore(bill.remind_days_before?.[0]?.toString() || '3');
    setActive(bill.active);
    setAutoCreateDraft(bill.auto_create_draft);
    setFormError(null);
    setFormMode('edit');
    setShowModal(true);
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!workspaceId) return;

    const numAmount = parseFloat(amount.replace(/[^0-9.]/g, ''));
    if (isNaN(numAmount) || numAmount <= 0) {
      setFormError('Nominal tagihan harus lebih besar dari 0.');
      return;
    }

    if (!categoryId) {
      setFormError('Pilih kategori pengeluaran.');
      return;
    }

    if (!accountId) {
      setFormError('Pilih rekening sumber pembayaran.');
      return;
    }

    const numVal = parseInt(scheduleValue, 10);
    if (isNaN(numVal) || numVal < 1 || numVal > 31) {
      setFormError('Nilai jadwal harus bernilai antara 1 sampai 31.');
      return;
    }

    const numReminder = parseInt(remindDaysBefore, 10);
    const remindArray = isNaN(numReminder) ? [3, 0] : [numReminder, 0];

    setSubmitting(true);
    setFormError(null);

    try {
      const payload = {
        workspace_id: workspaceId,
        name: name.trim(),
        amount: numAmount,
        category_id: categoryId,
        account_id: accountId,
        schedule_type: scheduleType,
        schedule_value: numVal,
        remind_days_before: remindArray,
        active,
        auto_create_draft: autoCreateDraft,
      };

      if (formMode === 'create') {
        const { error } = await supabase.from('recurring_bills').insert(payload);
        if (error) throw error;
      } else if (editingId) {
        const { error } = await supabase
          .from('recurring_bills')
          .update(payload)
          .eq('id', editingId);
        if (error) throw error;
      }

      setShowModal(false);
      await loadData();
    } catch (err: unknown) {
      setFormError(err instanceof Error ? err.message : 'Gagal menyimpan tagihan rutin.');
    } finally {
      setSubmitting(false);
    }
  };

  const handleDelete = async (billId: string) => {
    if (!window.confirm('Hapus konfigurasi tagihan rutin ini?')) return;

    const { error } = await supabase
      .from('recurring_bills')
      .update({ deleted_at: new Date().toISOString() })
      .eq('id', billId);

    if (error) {
      alert(`Gagal menghapus: ${error.message}`);
    } else {
      await loadData();
    }
  };

  const handleGenerateDrafts = async () => {
    setGenerating(true);
    setStatusMessage(null);
    try {
      const todayStr = new Date().toISOString().slice(0, 10);
      const { data, error } = await supabase.rpc('fn_generate_due_bill_drafts', {
        p_target_date: todayStr,
      });

      if (error) throw error;

      const count = typeof data === 'number' ? data : 0;
      if (count > 0) {
        setStatusMessage(`${count} draft transaksi tagihan berhasil dibuat dan dikirim ke Inbox.`);
      } else {
        setStatusMessage('Tidak ada tagihan yang jatuh tempo untuk diproses hari ini.');
      }
    } catch (err: unknown) {
      setStatusMessage(err instanceof Error ? `Error: ${err.message}` : 'Gagal memproses tagihan.');
    } finally {
      setGenerating(false);
    }
  };

  const activeBills = bills.filter((b) => b.active);
  const totalMonthlyCommitment = activeBills.reduce((acc, b) => {
    if (b.schedule_type === 'monthly') return acc + Number(b.amount);
    if (b.schedule_type === 'weekly') return acc + Number(b.amount) * 4;
    if (b.schedule_type === 'yearly') return acc + Number(b.amount) / 12;
    return acc + Number(b.amount);
  }, 0);

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-foreground">Uang</h1>
          <p className="text-sm text-muted-foreground mt-0.5">
            Otomatisasi pengingat dan pembuatan draft transaksi untuk pengeluaran berulang
          </p>
        </div>

        <div className="flex items-center gap-2 flex-wrap">
          <Button
            onClick={handleGenerateDrafts}
            disabled={generating}
            type="button"
            variant="secondary"
          >
            <Play className="w-4 h-4 text-primary" />
            <span>{generating ? 'Memproses...' : 'Proses Tagihan Hari Ini'}</span>
          </Button>

          <Button onClick={openCreateModal} type="button">
            <Plus className="w-4 h-4" />
            <span>Tambah Tagihan</span>
          </Button>
        </div>
      </div>

      <MoneySubNav />

      {statusMessage && (
        <div
          role="status"
          className="p-3.5 text-xs bg-muted border border-border rounded-lg flex items-center justify-between"
        >
          <span className="flex items-center gap-2">
            <CheckCircle2 className="w-4 h-4 text-primary" />
            <span>{statusMessage}</span>
          </span>
          <button
            onClick={() => setStatusMessage(null)}
            type="button"
            className="text-muted-foreground hover:text-foreground p-1"
            aria-label="Tutup pesan"
          >
            <X className="w-4 h-4" />
          </button>
        </div>
      )}

      {/* Ringkasan Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Card>
          <CardContent className="p-4">
            <div className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">
              Tagihan Aktif
            </div>
            <div className="text-2xl font-bold mt-1 tracking-tight text-foreground tabular-nums">
              {activeBills.length}{' '}
              <span className="text-xs font-normal text-muted-foreground">
                dari {bills.length} total
              </span>
            </div>
            <div className="text-xs text-muted-foreground mt-1">
              Terjadwal untuk pengingat & auto-draft
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-4">
            <div className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">
              Estimasi Komitmen Bulanan
            </div>
            <div className="text-2xl font-bold mt-1 tracking-tight text-expense tabular-nums">
              {formatCurrency(totalMonthlyCommitment)}
            </div>
            <div className="text-xs text-muted-foreground mt-1">
              Total biaya berulang yang harus dialokasikan
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardContent className="p-4 flex flex-col justify-center">
            <div className="text-xs font-semibold text-muted-foreground uppercase tracking-wider">
              Sistem Pengingat
            </div>
            <div className="flex items-center gap-2 mt-1.5 text-xs text-muted-foreground">
              <Clock className="w-4 h-4 text-primary shrink-0" />
              <span>Pengingat H-3 dan pembuatan draft di Inbox</span>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Daftar Tagihan */}
      {loadError ? (
        <ErrorState message={loadError} onRetry={loadData} />
      ) : loading ? (
        <div className="space-y-3" aria-busy="true">
          <Skeleton className="h-20 w-full" />
          <Skeleton className="h-20 w-full" />
        </div>
      ) : bills.length === 0 ? (
        <EmptyState
          icon={<CalendarClock className="w-5 h-5" />}
          title="Belum ada tagihan rutin terdaftar"
          description="Daftarkan langganan, internet, listrik, atau sewa agar tagihan otomatis diingatkan."
          actionLabel="Tambah Tagihan"
          onAction={openCreateModal}
        />
      ) : (
        <Card className="overflow-hidden">
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <CalendarClock className="w-4 h-4 text-primary" />
              <span>Daftar Tagihan Berulang</span>
            </CardTitle>
            <Button variant="ghost" size="sm" onClick={() => loadData()}>
              <RefreshCw className="w-3.5 h-3.5" />
              <span>Muat Ulang</span>
            </Button>
          </CardHeader>

          <div className="divide-y divide-border">
            {bills.map((bill) => {
              const freqLabel =
                bill.schedule_type === 'monthly'
                  ? `Bulanan (tgl ${bill.schedule_value})`
                  : bill.schedule_type === 'weekly'
                  ? `Mingguan (hari ${bill.schedule_value})`
                  : 'Tahunan';

              const remindDays = bill.remind_days_before?.[0] ?? 3;

              return (
                <div
                  key={bill.id}
                  className={`p-4 flex flex-col sm:flex-row justify-between sm:items-center gap-3 hover:bg-muted/20 transition-colors ${
                    !bill.active ? 'opacity-60' : ''
                  }`}
                >
                  <div className="space-y-1.5">
                    <div className="flex items-center gap-2 flex-wrap">
                      <span className="font-semibold text-sm text-foreground">{bill.name}</span>
                      <StatusBadge variant="neutral">{freqLabel}</StatusBadge>
                      {!bill.active && (
                        <StatusBadge variant="warning">Nonaktif</StatusBadge>
                      )}
                    </div>
                    <div className="flex items-center gap-3 text-xs text-muted-foreground flex-wrap tabular-nums">
                      <span>Kategori: {bill.category?.name || 'Tanpa Kategori'}</span>
                      <span>•</span>
                      <span>Rekening: {bill.account?.name || 'Belum dipilih'}</span>
                      <span>•</span>
                      <span>Pengingat: H-{remindDays}</span>
                    </div>
                  </div>

                  <div className="flex items-center justify-between sm:justify-end gap-4">
                    <div className="text-right">
                      <div className="text-base font-bold tabular-nums text-expense">
                        -{formatCurrency(bill.amount)}
                      </div>
                    </div>

                    <div className="flex items-center gap-1 pl-2 border-l border-border">
                      <Button
                        onClick={() => openEditModal(bill)}
                        type="button"
                        variant="ghost"
                        size="icon"
                        aria-label={`Ubah ${bill.name}`}
                      >
                        <Edit2 className="w-4 h-4" />
                      </Button>
                      <Button
                        onClick={() => handleDelete(bill.id)}
                        type="button"
                        variant="ghost"
                        size="icon"
                        aria-label={`Hapus ${bill.name}`}
                      >
                        <Trash2 className="w-4 h-4 text-muted-foreground hover:text-expense" />
                      </Button>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        </Card>
      )}

      {/* Modal Form */}
      <Dialog
        open={showModal}
        onClose={() => setShowModal(false)}
        title={formMode === 'create' ? 'Tambah Tagihan Rutin' : 'Ubah Tagihan Rutin'}
      >
        <form onSubmit={handleSave} className="space-y-4">
          {formError && (
            <div className="p-3 text-xs bg-expense/10 text-expense border border-expense/20 rounded-lg">
              {formError}
            </div>
          )}

          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">Nama Tagihan</label>
            <Input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="Contoh: Langganan Internet IndiHome"
              required
            />
          </div>

          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">Nominal (IDR)</label>
            <Input
              type="number"
              step="any"
              min="0"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              placeholder="Contoh: 350000"
              className="tabular-nums"
              required
            />
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="text-xs font-medium text-foreground block mb-1.5">Kategori</label>
              <Select
                value={categoryId}
                onChange={(e) => setCategoryId(e.target.value)}
                required
              >
                <option value="">Pilih Kategori</option>
                {categories.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
              </Select>
            </div>

            <div>
              <label className="text-xs font-medium text-foreground block mb-1.5">Rekening Sumber</label>
              <Select
                value={accountId}
                onChange={(e) => setAccountId(e.target.value)}
                required
              >
                <option value="">Pilih Rekening</option>
                {accounts.map((a) => (
                  <option key={a.id} value={a.id}>
                    {a.name}
                  </option>
                ))}
              </Select>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="text-xs font-medium text-foreground block mb-1.5">Frekuensi</label>
              <Select
                value={scheduleType}
                onChange={(e) =>
                  setScheduleType(e.target.value as 'monthly' | 'weekly' | 'yearly')
                }
              >
                <option value="monthly">Bulanan</option>
                <option value="weekly">Mingguan</option>
                <option value="yearly">Tahunan</option>
              </Select>
            </div>

            <div>
              <label className="text-xs font-medium text-foreground block mb-1.5">
                {scheduleType === 'monthly'
                  ? 'Tanggal Jatuh Tempo (1-31)'
                  : scheduleType === 'weekly'
                  ? 'Hari (1=Senin..7=Minggu)'
                  : 'Tanggal/Bulan'}
              </label>
              <Input
                type="number"
                min="1"
                max="31"
                value={scheduleValue}
                onChange={(e) => setScheduleValue(e.target.value)}
                className="tabular-nums"
                required
              />
            </div>
          </div>

          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">
              Ingatkan Sebelumnya (Hari)
            </label>
            <Input
              type="number"
              min="0"
              max="30"
              value={remindDaysBefore}
              onChange={(e) => setRemindDaysBefore(e.target.value)}
              placeholder="3"
              className="tabular-nums"
              required
            />
          </div>

          <div className="space-y-1 pt-1">
            <label className="flex items-center gap-2.5 cursor-pointer min-h-11">
              <input
                type="checkbox"
                checked={active}
                onChange={(e) => setActive(e.target.checked)}
                className="w-4 h-4 rounded border-border text-primary"
              />
              <span className="text-xs font-medium text-foreground">Tagihan aktif</span>
            </label>

            <label className="flex items-center gap-2.5 cursor-pointer min-h-11">
              <input
                type="checkbox"
                checked={autoCreateDraft}
                onChange={(e) => setAutoCreateDraft(e.target.checked)}
                className="w-4 h-4 rounded border-border text-primary"
              />
              <span className="text-xs font-medium text-foreground">
                Otomatis buat draft transaksi ke Inbox saat jatuh tempo
              </span>
            </label>
          </div>

          <div className="flex justify-end gap-2 pt-3 border-t border-border">
            <Button
              type="button"
              variant="secondary"
              onClick={() => setShowModal(false)}
            >
              Batal
            </Button>
            <Button type="submit" disabled={submitting}>
              {submitting ? 'Menyimpan...' : 'Simpan'}
            </Button>
          </div>
        </form>
      </Dialog>
    </div>
  );
}
