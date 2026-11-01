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
  Layers
} from 'lucide-react';

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
  const [generating, setGenerating] = useState(false);
  const [statusMessage, setStatusMessage] = useState<string | null>(null);

  // Modal / Form state
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

    // Fetch recurring bills with joins
    const { data: billsData } = await supabase
      .from('recurring_bills')
      .select(`
        *,
        category:categories(name),
        account:accounts(name)
      `)
      .eq('workspace_id', memberData.workspace_id)
      .is('deleted_at', null)
      .order('schedule_value', { ascending: true });

    if (billsData) {
      setBills(billsData as unknown as ExtendedRecurringBill[]);
    }

    // Fetch active expense categories
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

    // Fetch active accounts
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

    setLoading(false);
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
    const confirmDelete = window.confirm('Hapus konfigurasi tagihan rutin ini?');
    if (!confirmDelete) return;

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
      {/* Header */}
      <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Tagihan Rutin</h1>
          <p className="text-sm text-muted-foreground mt-1">
            Otomatisasi pengingat dan pembuatan draft transaksi untuk pengeluaran berulang.
          </p>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={handleGenerateDrafts}
            disabled={generating}
            type="button"
            className="flex items-center gap-2 bg-muted text-foreground hover:bg-muted/80 px-3.5 py-2 rounded-md text-sm font-medium border border-border transition-colors disabled:opacity-50"
            title="Periksa dan buat draft transaksi untuk tagihan yang jatuh tempo hari ini"
          >
            <Play className="w-3.5 h-3.5 text-primary" />
            <span>{generating ? 'Memproses...' : 'Proses Tagihan Hari Ini'}</span>
          </button>

          <button
            onClick={openCreateModal}
            type="button"
            className="flex items-center gap-2 bg-primary text-primary-foreground px-4 py-2 rounded-md text-sm font-medium hover:bg-primary/90 transition-colors"
          >
            <Plus className="w-4 h-4" />
            <span>Tambah Tagihan</span>
          </button>
        </div>
      </div>

      {/* Status banner */}
      {statusMessage && (
        <div className="p-3 text-xs bg-muted border border-border rounded-md flex items-center justify-between">
          <span className="flex items-center gap-2">
            <CheckCircle2 className="w-4 h-4 text-primary" />
            <span>{statusMessage}</span>
          </span>
          <button
            onClick={() => setStatusMessage(null)}
            type="button"
            className="text-muted-foreground hover:text-foreground"
          >
            <X className="w-4 h-4" />
          </button>
        </div>
      )}

      {/* Ringkasan Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="p-4 rounded-lg border border-border bg-card">
          <div className="text-xs font-medium text-muted-foreground uppercase">Tagihan Aktif</div>
          <div className="text-2xl font-bold mt-1 tracking-tight text-foreground">
            {activeBills.length}{' '}
            <span className="text-xs font-normal text-muted-foreground">
              dari {bills.length} total
            </span>
          </div>
          <div className="text-xs text-muted-foreground mt-1">
            Terjadwal untuk pengingat & auto-draft
          </div>
        </div>

        <div className="p-4 rounded-lg border border-border bg-card">
          <div className="text-xs font-medium text-muted-foreground uppercase">
            Estimasi Komitmen Bulanan
          </div>
          <div className="text-2xl font-bold mt-1 tracking-tight text-expense">
            {formatCurrency(totalMonthlyCommitment)}
          </div>
          <div className="text-xs text-muted-foreground mt-1">
            Total biaya berulang yang harus dialokasikan
          </div>
        </div>

        <div className="p-4 rounded-lg border border-border bg-card flex flex-col justify-center">
          <div className="text-xs font-medium text-muted-foreground uppercase">Sistem Pengingat</div>
          <div className="flex items-center gap-2 mt-1.5 text-xs text-muted-foreground">
            <Clock className="w-4 h-4 text-primary" />
            <span>Pengingat lokal H-3 dan pembuatan draft idempoten di Inbox</span>
          </div>
        </div>
      </div>

      {/* Daftar Tagihan */}
      <div className="bg-card border border-border rounded-lg overflow-hidden">
        <div className="p-4 border-b border-border flex justify-between items-center">
          <h2 className="font-medium text-sm flex items-center gap-2">
            <CalendarClock className="w-4 h-4 text-primary" />
            <span>Daftar Tagihan Berulang</span>
          </h2>
          <button
            onClick={() => loadData()}
            type="button"
            className="text-xs text-muted-foreground hover:text-foreground flex items-center gap-1"
          >
            <RefreshCw className="w-3 h-3" />
            <span>Muat Ulang</span>
          </button>
        </div>

        {loading ? (
          <div className="p-8 text-center text-sm text-muted-foreground">Memuat tagihan...</div>
        ) : bills.length === 0 ? (
          <div className="p-8 text-center">
            <Layers className="w-8 h-8 text-muted-foreground mx-auto mb-2 opacity-50" />
            <div className="text-sm font-medium">Belum ada tagihan rutin terdaftar</div>
            <p className="text-xs text-muted-foreground mt-1 max-w-sm mx-auto">
              Daftarkan langganan, internet, listrik, atau sewa agar tagihan otomatis diingatkan.
            </p>
            <button
              onClick={openCreateModal}
              type="button"
              className="mt-4 inline-flex items-center gap-2 bg-primary text-primary-foreground px-3 py-1.5 rounded-md text-xs font-medium"
            >
              <Plus className="w-3.5 h-3.5" />
              <span>Daftarkan Tagihan Pertama</span>
            </button>
          </div>
        ) : (
          <div className="divide-y divide-border">
            {bills.map((bill) => {
              const freqLabel =
                bill.schedule_type === 'monthly'
                  ? `Bulanan (tgl ${bill.schedule_value})`
                  : bill.schedule_type === 'weekly'
                  ? `Mingguan (hari ${bill.schedule_value})`
                  : `Tahunan`;

              const remindDays = bill.remind_days_before?.[0] ?? 3;

              return (
                <div
                  key={bill.id}
                  className={`p-4 flex flex-col sm:flex-row justify-between sm:items-center gap-3 hover:bg-muted/30 transition-colors ${
                    !bill.active ? 'opacity-60' : ''
                  }`}
                >
                  <div className="space-y-1">
                    <div className="flex items-center gap-2">
                      <span className="font-semibold text-sm tracking-tight">{bill.name}</span>
                      <span className="text-[11px] px-2 py-0.5 rounded-full font-medium bg-muted text-muted-foreground">
                        {freqLabel}
                      </span>
                      {!bill.active && (
                        <span className="text-[11px] px-2 py-0.5 rounded-full font-medium bg-muted text-muted-foreground">
                          Nonaktif
                        </span>
                      )}
                    </div>
                    <div className="flex items-center gap-3 text-xs text-muted-foreground">
                      <span>Kategori: {bill.category?.name || 'Tanpa Kategori'}</span>
                      <span>Rekening: {bill.account?.name || 'Belum dipilih'}</span>
                      <span>Pengingat: H-{remindDays}</span>
                    </div>
                  </div>

                  <div className="flex items-center gap-4">
                    <div className="text-right">
                      <div className="text-base font-bold tracking-tight text-expense">
                        {formatCurrency(bill.amount)}
                      </div>
                    </div>

                    <div className="flex items-center gap-1 pl-2 border-l border-border">
                      <button
                        onClick={() => openEditModal(bill)}
                        type="button"
                        className="p-1.5 text-muted-foreground hover:text-foreground rounded transition-colors"
                        title="Ubah Tagihan"
                      >
                        <Edit2 className="w-3.5 h-3.5" />
                      </button>
                      <button
                        onClick={() => handleDelete(bill.id)}
                        type="button"
                        className="p-1.5 text-muted-foreground hover:text-expense rounded transition-colors"
                        title="Hapus Tagihan"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    </div>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Modal Form */}
      {showModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="bg-card border border-border rounded-lg max-w-md w-full p-6 space-y-4 max-h-[90vh] overflow-y-auto">
            <div className="flex justify-between items-center">
              <h3 className="font-semibold text-lg tracking-tight">
                {formMode === 'create' ? 'Tambah Tagihan Rutin' : 'Ubah Tagihan Rutin'}
              </h3>
              <button
                onClick={() => setShowModal(false)}
                type="button"
                className="text-muted-foreground hover:text-foreground"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {formError && (
              <div className="p-3 text-xs bg-expense/10 text-expense border border-expense/20 rounded-md">
                {formError}
              </div>
            )}

            <form onSubmit={handleSave} className="space-y-4">
              <div className="space-y-1">
                <label className="text-xs font-medium text-muted-foreground">Nama Tagihan</label>
                <input
                  type="text"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="Contoh: Langganan Internet IndiHome"
                  className="w-full px-3 py-2 text-sm bg-background border border-input rounded-md focus:outline-none focus:ring-1 focus:ring-ring"
                  required
                />
              </div>

              <div className="space-y-1">
                <label className="text-xs font-medium text-muted-foreground">Nominal (IDR)</label>
                <input
                  type="number"
                  step="any"
                  min="0"
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                  placeholder="Contoh: 350000"
                  className="w-full px-3 py-2 text-sm bg-background border border-input rounded-md focus:outline-none focus:ring-1 focus:ring-ring"
                  required
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-1">
                  <label className="text-xs font-medium text-muted-foreground">Kategori</label>
                  <select
                    value={categoryId}
                    onChange={(e) => setCategoryId(e.target.value)}
                    className="w-full px-3 py-2 text-sm bg-background border border-input rounded-md focus:outline-none focus:ring-1 focus:ring-ring"
                    required
                  >
                    <option value="">Pilih Kategori</option>
                    {categories.map((c) => (
                      <option key={c.id} value={c.id}>
                        {c.name}
                      </option>
                    ))}
                  </select>
                </div>

                <div className="space-y-1">
                  <label className="text-xs font-medium text-muted-foreground">Rekening Sumber</label>
                  <select
                    value={accountId}
                    onChange={(e) => setAccountId(e.target.value)}
                    className="w-full px-3 py-2 text-sm bg-background border border-input rounded-md focus:outline-none focus:ring-1 focus:ring-ring"
                    required
                  >
                    <option value="">Pilih Rekening</option>
                    {accounts.map((a) => (
                      <option key={a.id} value={a.id}>
                        {a.name}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-1">
                  <label className="text-xs font-medium text-muted-foreground">Frekuensi</label>
                  <select
                    value={scheduleType}
                    onChange={(e) =>
                      setScheduleType(e.target.value as 'monthly' | 'weekly' | 'yearly')
                    }
                    className="w-full px-3 py-2 text-sm bg-background border border-input rounded-md focus:outline-none focus:ring-1 focus:ring-ring"
                  >
                    <option value="monthly">Bulanan</option>
                    <option value="weekly">Mingguan</option>
                    <option value="yearly">Tahunan</option>
                  </select>
                </div>

                <div className="space-y-1">
                  <label className="text-xs font-medium text-muted-foreground">
                    {scheduleType === 'monthly'
                      ? 'Tanggal Jatuh Tempo (1-31)'
                      : scheduleType === 'weekly'
                      ? 'Hari (1=Senin..7=Minggu)'
                      : 'Tanggal/Bulan'}
                  </label>
                  <input
                    type="number"
                    min="1"
                    max="31"
                    value={scheduleValue}
                    onChange={(e) => setScheduleValue(e.target.value)}
                    className="w-full px-3 py-2 text-sm bg-background border border-input rounded-md focus:outline-none focus:ring-1 focus:ring-ring"
                    required
                  />
                </div>
              </div>

              <div className="space-y-1">
                <label className="text-xs font-medium text-muted-foreground">
                  Ingatkan Sebelumnya (Hari)
                </label>
                <input
                  type="number"
                  min="0"
                  max="30"
                  value={remindDaysBefore}
                  onChange={(e) => setRemindDaysBefore(e.target.value)}
                  placeholder="3"
                  className="w-full px-3 py-2 text-sm bg-background border border-input rounded-md focus:outline-none focus:ring-1 focus:ring-ring"
                  required
                />
                <span className="text-[11px] text-muted-foreground">
                  Default 3 memunculkan pengingat lokal H-3 dan hari-H.
                </span>
              </div>

              <div className="space-y-2 pt-1">
                <label className="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={active}
                    onChange={(e) => setActive(e.target.checked)}
                    className="rounded border-input text-primary focus:ring-ring"
                  />
                  <span className="text-xs font-medium">Tagihan aktif</span>
                </label>

                <label className="flex items-center gap-2 cursor-pointer">
                  <input
                    type="checkbox"
                    checked={autoCreateDraft}
                    onChange={(e) => setAutoCreateDraft(e.target.checked)}
                    className="rounded border-input text-primary focus:ring-ring"
                  />
                  <span className="text-xs font-medium">
                    Otomatis buat draft transaksi ke Inbox saat jatuh tempo
                  </span>
                </label>
              </div>

              <div className="flex justify-end gap-2 pt-4 border-t border-border">
                <button
                  type="button"
                  onClick={() => setShowModal(false)}
                  className="px-4 py-2 text-sm text-muted-foreground hover:text-foreground rounded-md transition-colors"
                >
                  Batal
                </button>
                <button
                  type="submit"
                  disabled={submitting}
                  className="px-4 py-2 text-sm bg-primary text-primary-foreground font-medium rounded-md hover:bg-primary/90 transition-colors disabled:opacity-50"
                >
                  {submitting ? 'Menyimpan...' : 'Simpan'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
