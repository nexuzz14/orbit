'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';
import { formatCurrency, formatDateOnly } from '@/lib/format';
import type { Database } from '@/types/database';
import { TrendingUp, TrendingDown, Scale, Calendar } from 'lucide-react';

type MonthlySummaryRow = Database['public']['Views']['v_monthly_summary']['Row'];

type CategorySummaryRow = {
  category_name: string | null;
  type: string;
  total: number;
  txn_count: number;
};

export default function RingkasanPage() {
  const supabase = createClient();
  const [summaries, setSummaries] = useState<MonthlySummaryRow[]>([]);
  const [categorySummaries, setCategorySummaries] = useState<CategorySummaryRow[]>([]);
  const [loading, setLoading] = useState(true);

  const loadData = useCallback(async () => {
    setLoading(true);

    // Ambil ringkasan bulanan
    const { data: sumData } = await supabase
      .from('v_monthly_summary')
      .select('*')
      .order('month_start', { ascending: false });

    if (sumData) {
      setSummaries(sumData);
    }

    // Ambil komposisi kategori
    const { data: catData } = await supabase
      .from('v_monthly_category_summary')
      .select('category_name, type, total, txn_count')
      .order('total', { ascending: false });

    if (catData) {
      setCategorySummaries(catData as CategorySummaryRow[]);
    }

    setLoading(false);
  }, [supabase]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  // Total summary untuk siklus berjalan (baris pertama dengan is_total = true)
  const currentTotal = summaries.find((s) => s.is_total);
  const currentSources = summaries.filter((s) => !s.is_total && s.month_start === currentTotal?.month_start);

  const expenseCategories = categorySummaries.filter((c) => c.type === 'expense');
  const incomeCategories = categorySummaries.filter((c) => c.type === 'income');

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Ringkasan Bulanan</h1>
        <p className="text-sm text-muted-foreground">
          Arus kas per siklus bulan dan rincian per sumber kegiatan
        </p>
      </div>

      {loading ? (
        <div className="p-8 text-center text-sm text-muted-foreground">Memuat data ringkasan...</div>
      ) : (
        <>
          {/* Header Periode */}
          {currentTotal && (
            <div className="flex items-center gap-2 text-sm text-muted-foreground bg-card border border-border p-3 rounded-lg">
              <Calendar className="w-4 h-4" />
              <span>
                Periode Siklus:{' '}
                <strong className="text-foreground">
                  {formatDateOnly(currentTotal.month_start)} – {formatDateOnly(currentTotal.month_end)}
                </strong>
              </span>
            </div>
          )}

          {/* Cards Total */}
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <div className="p-5 bg-card border border-border rounded-lg space-y-2">
              <div className="flex items-center justify-between text-sm text-muted-foreground">
                <span>Total Pemasukan</span>
                <TrendingUp className="w-4 h-4 text-income" />
              </div>
              <div className="text-2xl font-semibold tabular-nums text-income">
                {formatCurrency(currentTotal?.income || 0, currentTotal?.currency)}
              </div>
              <div className="text-xs text-muted-foreground">
                {currentTotal?.txn_count || 0} transaksi terkonfirmasi
              </div>
            </div>

            <div className="p-5 bg-card border border-border rounded-lg space-y-2">
              <div className="flex items-center justify-between text-sm text-muted-foreground">
                <span>Total Pengeluaran</span>
                <TrendingDown className="w-4 h-4 text-expense" />
              </div>
              <div className="text-2xl font-semibold tabular-nums text-expense">
                {formatCurrency(currentTotal?.expense || 0, currentTotal?.currency)}
              </div>
              <div className="text-xs text-muted-foreground">Tidak termasuk transfer antar akun</div>
            </div>

            <div className="p-5 bg-card border border-border rounded-lg space-y-2">
              <div className="flex items-center justify-between text-sm text-muted-foreground">
                <span>Selisih Bersih (Net)</span>
                <Scale className="w-4 h-4 text-foreground" />
              </div>
              <div
                className={`text-2xl font-semibold tabular-nums ${
                  (currentTotal?.net || 0) >= 0 ? 'text-income' : 'text-expense'
                }`}
              >
                {formatCurrency(currentTotal?.net || 0, currentTotal?.currency)}
              </div>
              <div className="text-xs text-muted-foreground">Pemasukan dikurangi pengeluaran</div>
            </div>
          </div>

          {/* Rincian per Sumber Kegiatan */}
          <div className="space-y-3">
            <h2 className="text-base font-semibold">Rincian per Sumber Kegiatan</h2>
            <div className="border border-border bg-card rounded-lg overflow-hidden">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border bg-muted/40 text-left text-xs uppercase tracking-wider text-muted-foreground">
                    <th className="p-3 font-medium">Sumber</th>
                    <th className="p-3 font-medium text-right">Pemasukan</th>
                    <th className="p-3 font-medium text-right">Pengeluaran</th>
                    <th className="p-3 font-medium text-right">Selisih</th>
                    <th className="p-3 font-medium text-right">Jumlah Txn</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {currentSources.length === 0 ? (
                    <tr>
                      <td colSpan={5} className="p-4 text-center text-xs text-muted-foreground">
                        Belum ada data untuk periode ini
                      </td>
                    </tr>
                  ) : (
                    currentSources.map((s) => (
                      <tr key={s.source} className="hover:bg-muted/20">
                        <td className="p-3 font-medium uppercase text-xs tracking-wider">
                          {s.source}
                        </td>
                        <td className="p-3 text-right tabular-nums text-income">
                          {formatCurrency(Number(s.income), s.currency)}
                        </td>
                        <td className="p-3 text-right tabular-nums text-expense">
                          {formatCurrency(Number(s.expense), s.currency)}
                        </td>
                        <td
                          className={`p-3 text-right tabular-nums font-medium ${
                            Number(s.net) >= 0 ? 'text-income' : 'text-expense'
                          }`}
                        >
                          {formatCurrency(Number(s.net), s.currency)}
                        </td>
                        <td className="p-3 text-right text-xs text-muted-foreground tabular-nums">
                          {s.txn_count}
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </div>

          {/* Komposisi Kategori */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
            <div className="space-y-3">
              <h2 className="text-base font-semibold">Pengeluaran per Kategori</h2>
              <div className="border border-border bg-card rounded-lg divide-y divide-border">
                {expenseCategories.length === 0 ? (
                  <div className="p-4 text-center text-xs text-muted-foreground">
                    Belum ada pengeluaran
                  </div>
                ) : (
                  expenseCategories.map((c, idx) => (
                    <div key={idx} className="p-3 flex items-center justify-between text-sm">
                      <span className="font-medium">{c.category_name || 'Tanpa Kategori'}</span>
                      <div className="text-right">
                        <div className="tabular-nums font-semibold text-expense">
                          {formatCurrency(Number(c.total))}
                        </div>
                        <div className="text-[11px] text-muted-foreground">{c.txn_count} transaksi</div>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>

            <div className="space-y-3">
              <h2 className="text-base font-semibold">Pemasukan per Kategori</h2>
              <div className="border border-border bg-card rounded-lg divide-y divide-border">
                {incomeCategories.length === 0 ? (
                  <div className="p-4 text-center text-xs text-muted-foreground">
                    Belum ada pemasukan
                  </div>
                ) : (
                  incomeCategories.map((c, idx) => (
                    <div key={idx} className="p-3 flex items-center justify-between text-sm">
                      <span className="font-medium">{c.category_name || 'Tanpa Kategori'}</span>
                      <div className="text-right">
                        <div className="tabular-nums font-semibold text-income">
                          {formatCurrency(Number(c.total))}
                        </div>
                        <div className="text-[11px] text-muted-foreground">{c.txn_count} transaksi</div>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </div>
          </div>
        </>
      )}
    </div>
  );
}
