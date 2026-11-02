'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';
import { formatCurrency, formatDateOnly } from '@/lib/format';
import type { Database } from '@/types/database';
import { TrendingUp, TrendingDown, Scale, Calendar, BarChart3 } from 'lucide-react';
import {
  Card,
  CardHeader,
  CardTitle,
  CardContent,
  KindBadge,
  Skeleton,
  EmptyState,
  ErrorState,
  MoneySubNav,
} from '@/components/ui';

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
  const [loadError, setLoadError] = useState<string | null>(null);

  const loadData = useCallback(async () => {
    setLoading(true);
    setLoadError(null);

    try {
      const { data: sumData, error: sumErr } = await supabase
        .from('v_monthly_summary')
        .select('*')
        .order('month_start', { ascending: false });

      if (sumErr) throw sumErr;
      if (sumData) {
        setSummaries(sumData);
      }

      const { data: catData, error: catErr } = await supabase
        .from('v_monthly_category_summary')
        .select('category_name, type, total, txn_count')
        .order('total', { ascending: false });

      if (catErr) throw catErr;
      if (catData) {
        setCategorySummaries(catData as CategorySummaryRow[]);
      }
    } catch (err: unknown) {
      setLoadError(err instanceof Error ? err.message : 'Gagal memuat ringkasan keuangan.');
    } finally {
      setLoading(false);
    }
  }, [supabase]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  const currentTotal = summaries.find((s) => s.is_total);
  const currentSources = summaries.filter((s) => !s.is_total && s.month_start === currentTotal?.month_start);

  const expenseCategories = categorySummaries.filter((c) => c.type === 'expense');
  const incomeCategories = categorySummaries.filter((c) => c.type === 'income');

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold tracking-tight text-foreground">Uang</h1>
        <p className="text-sm text-muted-foreground mt-0.5">
          Ringkasan arus kas bulanan dan komposisi per sumber kegiatan
        </p>
      </div>

      <MoneySubNav />

      {loadError ? (
        <ErrorState message={loadError} onRetry={loadData} />
      ) : loading ? (
        <div className="space-y-4" aria-busy="true">
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <Skeleton className="h-28 w-full" />
            <Skeleton className="h-28 w-full" />
            <Skeleton className="h-28 w-full" />
          </div>
          <Skeleton className="h-48 w-full" />
        </div>
      ) : summaries.length === 0 && categorySummaries.length === 0 ? (
        <EmptyState
          icon={<BarChart3 className="w-5 h-5" />}
          title="Belum ada ringkasan transaksi"
          description="Catat transaksi pemasukan atau pengeluaran untuk melihat laporan arus kas bulanan."
          actionLabel="Muat Ulang"
          onAction={loadData}
        />
      ) : (
        <>
          {currentTotal && (
            <Card>
              <CardContent className="p-3.5 flex items-center gap-2 text-xs text-muted-foreground">
                <Calendar className="w-4 h-4 text-primary" />
                <span>
                  Periode Siklus:{' '}
                  <strong className="text-foreground tabular-nums">
                    {formatDateOnly(currentTotal.month_start ?? '')} - {formatDateOnly(currentTotal.month_end ?? '')}
                  </strong>
                </span>
              </CardContent>
            </Card>
          )}

          {/* KPI Cards */}
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <Card>
              <CardContent className="p-5 space-y-2">
                <div className="flex items-center justify-between text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                  <span>Total Pemasukan</span>
                  <TrendingUp className="w-4 h-4 text-income" />
                </div>
                <div className="text-2xl font-bold tabular-nums text-income">
                  +{formatCurrency(currentTotal?.income || 0, currentTotal?.currency ?? 'IDR')}
                </div>
                <div className="text-xs text-muted-foreground tabular-nums">
                  {currentTotal?.txn_count || 0} transaksi terkonfirmasi
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardContent className="p-5 space-y-2">
                <div className="flex items-center justify-between text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                  <span>Total Pengeluaran</span>
                  <TrendingDown className="w-4 h-4 text-expense" />
                </div>
                <div className="text-2xl font-bold tabular-nums text-expense">
                  -{formatCurrency(currentTotal?.expense || 0, currentTotal?.currency ?? 'IDR')}
                </div>
                <div className="text-xs text-muted-foreground">
                  Tidak termasuk transfer antar akun
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardContent className="p-5 space-y-2">
                <div className="flex items-center justify-between text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                  <span>Selisih Bersih (Net)</span>
                  <Scale className="w-4 h-4 text-primary" />
                </div>
                <div
                  className={`text-2xl font-bold tabular-nums ${
                    (currentTotal?.net || 0) >= 0 ? 'text-income' : 'text-expense'
                  }`}
                >
                  {(currentTotal?.net || 0) >= 0 ? '+' : ''}
                  {formatCurrency(currentTotal?.net || 0, currentTotal?.currency ?? 'IDR')}
                </div>
                <div className="text-xs text-muted-foreground">
                  Pemasukan dikurangi pengeluaran
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Rincian per Sumber Kegiatan */}
          <Card className="overflow-hidden">
            <CardHeader>
              <CardTitle>Rincian per Sumber Kegiatan</CardTitle>
            </CardHeader>
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border bg-muted/40 text-left text-xs uppercase tracking-wider text-muted-foreground">
                    <th className="p-3.5 font-semibold">Sumber Kegiatan</th>
                    <th className="p-3.5 font-semibold text-right">Pemasukan</th>
                    <th className="p-3.5 font-semibold text-right">Pengeluaran</th>
                    <th className="p-3.5 font-semibold text-right">Selisih</th>
                    <th className="p-3.5 font-semibold text-right">Jumlah Txn</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-border">
                  {currentSources.length === 0 ? (
                    <tr>
                      <td colSpan={5} className="p-6 text-center text-xs text-muted-foreground">
                        Belum ada data untuk periode ini
                      </td>
                    </tr>
                  ) : (
                    currentSources.map((s) => (
                      <tr key={s.source} className="hover:bg-muted/20">
                        <td className="p-3.5">
                          <KindBadge kind={s.source || 'pribadi'} />
                        </td>
                        <td className="p-3.5 text-right tabular-nums text-income font-medium">
                          +{formatCurrency(Number(s.income ?? 0), s.currency ?? 'IDR')}
                        </td>
                        <td className="p-3.5 text-right tabular-nums text-expense font-medium">
                          -{formatCurrency(Number(s.expense ?? 0), s.currency ?? 'IDR')}
                        </td>
                        <td
                          className={`p-3.5 text-right tabular-nums font-semibold ${
                            Number(s.net ?? 0) >= 0 ? 'text-income' : 'text-expense'
                          }`}
                        >
                          {Number(s.net ?? 0) >= 0 ? '+' : ''}
                          {formatCurrency(Number(s.net ?? 0), s.currency ?? 'IDR')}
                        </td>
                        <td className="p-3.5 text-right text-xs text-muted-foreground tabular-nums">
                          {s.txn_count}
                        </td>
                      </tr>
                    ))
                  )}
                </tbody>
              </table>
            </div>
          </Card>

          {/* Komposisi Kategori */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-6">
            <Card className="overflow-hidden">
              <CardHeader>
                <CardTitle>Pengeluaran per Kategori</CardTitle>
              </CardHeader>
              <div className="divide-y divide-border">
                {expenseCategories.length === 0 ? (
                  <div className="p-6 text-center text-xs text-muted-foreground">
                    Belum ada pengeluaran tercatat
                  </div>
                ) : (
                  expenseCategories.map((c, idx) => (
                    <div key={idx} className="p-3.5 flex items-center justify-between text-sm">
                      <span className="font-medium text-foreground">{c.category_name || 'Tanpa Kategori'}</span>
                      <div className="text-right">
                        <div className="tabular-nums font-semibold text-expense">
                          -{formatCurrency(Number(c.total))}
                        </div>
                        <div className="text-xs text-muted-foreground tabular-nums">{c.txn_count} transaksi</div>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </Card>

            <Card className="overflow-hidden">
              <CardHeader>
                <CardTitle>Pemasukan per Kategori</CardTitle>
              </CardHeader>
              <div className="divide-y divide-border">
                {incomeCategories.length === 0 ? (
                  <div className="p-6 text-center text-xs text-muted-foreground">
                    Belum ada pemasukan tercatat
                  </div>
                ) : (
                  incomeCategories.map((c, idx) => (
                    <div key={idx} className="p-3.5 flex items-center justify-between text-sm">
                      <span className="font-medium text-foreground">{c.category_name || 'Tanpa Kategori'}</span>
                      <div className="text-right">
                        <div className="tabular-nums font-semibold text-income">
                          +{formatCurrency(Number(c.total))}
                        </div>
                        <div className="text-xs text-muted-foreground tabular-nums">{c.txn_count} transaksi</div>
                      </div>
                    </div>
                  ))
                )}
              </div>
            </Card>
          </div>
        </>
      )}
    </div>
  );
}
