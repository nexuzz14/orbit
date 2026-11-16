'use client';

import React, { useMemo, useState } from 'react';
import { BarChart3, PieChart } from 'lucide-react';
import { usePrivacyMode } from '@/lib/privacy-mode';
import type { CategoryBreakdownItem, MonthlyCashflowPoint } from '@/lib/finance-v2';
import { Card, CardContent, CardHeader, CardTitle, cn } from '@/components/ui';

function formatCompactIdr(value: number): string {
  const abs = Math.abs(value);
  if (abs >= 1_000_000_000) return `${(value / 1_000_000_000).toFixed(1)}M`;
  if (abs >= 1_000_000) return `${(value / 1_000_000).toFixed(1)}jt`;
  if (abs >= 1_000) return `${Math.round(value / 1_000)}rb`;
  return String(Math.round(value));
}

export function RingkasanCharts({
  monthlySeries,
  expenseBreakdown,
  incomeBreakdown,
  currency = 'IDR',
}: {
  monthlySeries: MonthlyCashflowPoint[];
  expenseBreakdown: CategoryBreakdownItem[];
  incomeBreakdown: CategoryBreakdownItem[];
  currency?: string;
}) {
  const { formatAmount } = usePrivacyMode();
  const [catTab, setCatTab] = useState<'expense' | 'income'>('expense');

  const maxMonthlyVal = useMemo(() => {
    let peak = 1;
    for (const pt of monthlySeries) {
      peak = Math.max(peak, pt.income, pt.expense);
    }
    return peak;
  }, [monthlySeries]);

  const activeCategories = catTab === 'expense' ? expenseBreakdown : incomeBreakdown;
  const maxCatTotal = useMemo(
    () => Math.max(1, ...activeCategories.map((c) => c.total)),
    [activeCategories]
  );

  const svgWidth = 520;
  const svgHeight = 220;
  const padLeft = 52;
  const padRight = 16;
  const padTop = 16;
  const padBottom = 34;
  const plotW = svgWidth - padLeft - padRight;
  const plotH = svgHeight - padTop - padBottom;

  return (
    <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
      {/* Grafik Batang Arus Kas Bulanan */}
      <Card className="print-avoid-break">
        <CardHeader className="pb-2 border-b border-border flex flex-row items-center justify-between gap-2">
          <div className="flex items-center gap-2">
            <BarChart3 className="w-4 h-4 text-primary" />
            <CardTitle className="text-base">Arus Kas Bulanan</CardTitle>
          </div>
          <div className="flex items-center gap-3 text-xs text-muted-foreground">
            <span className="inline-flex items-center gap-1.5">
              <span className="inline-block h-2.5 w-2.5 rounded-sm bg-income" />
              Masuk
            </span>
            <span className="inline-flex items-center gap-1.5">
              <span className="inline-block h-2.5 w-2.5 rounded-sm bg-expense" />
              Keluar
            </span>
          </div>
        </CardHeader>

        <CardContent className="pt-4">
          {monthlySeries.length === 0 ? (
            <div className="py-12 text-center text-xs text-muted-foreground">
              Belum ada riwayat arus kas bulanan untuk ditampilkan.
            </div>
          ) : (
            <div className="space-y-3">
              <svg
                viewBox={`0 0 ${svgWidth} ${svgHeight}`}
                role="img"
                aria-label="Grafik batang arus kas bulanan pemasukan dan pengeluaran"
                className="w-full h-auto overflow-visible"
              >
                {[0, 0.25, 0.5, 0.75, 1].map((ratio) => {
                  const y = padTop + plotH * (1 - ratio);
                  const tickVal = maxMonthlyVal * ratio;
                  return (
                    <g key={ratio}>
                      <line
                        x1={padLeft}
                        y1={y}
                        x2={svgWidth - padRight}
                        y2={y}
                        stroke="var(--border)"
                        strokeDasharray={ratio === 0 ? undefined : '3 3'}
                        strokeWidth={1}
                      />
                      <text
                        x={padLeft - 8}
                        y={y + 4}
                        textAnchor="end"
                        fill="var(--muted-foreground)"
                        fontSize={10}
                      >
                        {formatCompactIdr(tickVal)}
                      </text>
                    </g>
                  );
                })}

                {monthlySeries.map((pt, idx) => {
                  const slotW = plotW / monthlySeries.length;
                  const barW = Math.min(22, Math.max(10, slotW * 0.28));
                  const groupCenterX = padLeft + slotW * idx + slotW / 2;
                  const incH = Math.max(pt.income > 0 ? 3 : 0, (pt.income / maxMonthlyVal) * plotH);
                  const expH = Math.max(pt.expense > 0 ? 3 : 0, (pt.expense / maxMonthlyVal) * plotH);
                  const incY = padTop + plotH - incH;
                  const expY = padTop + plotH - expH;

                  return (
                    <g key={pt.monthKey}>
                      <rect
                        x={groupCenterX - barW - 2}
                        y={incY}
                        width={barW}
                        height={incH}
                        rx={3}
                        fill="var(--income)"
                      >
                        <title>{`${pt.label} Pemasukan: ${formatAmount(pt.income, currency)}`}</title>
                      </rect>
                      <rect
                        x={groupCenterX + 2}
                        y={expY}
                        width={barW}
                        height={expH}
                        rx={3}
                        fill="var(--expense)"
                      >
                        <title>{`${pt.label} Pengeluaran: ${formatAmount(pt.expense, currency)}`}</title>
                      </rect>
                      <text
                        x={groupCenterX}
                        y={svgHeight - 10}
                        textAnchor="middle"
                        fill="var(--muted-foreground)"
                        fontSize={11}
                      >
                        {pt.label}
                      </text>
                    </g>
                  );
                })}
              </svg>

              <div className="grid grid-cols-2 sm:grid-cols-3 gap-2 pt-2 border-t border-border text-xs">
                {monthlySeries.slice(-3).map((pt) => (
                  <div key={pt.monthKey} className="rounded-sm bg-subtle px-2.5 py-1.5">
                    <div className="text-[11px] text-muted-foreground">{pt.label}</div>
                    <div
                      className={cn(
                        'font-semibold tabular-nums mt-0.5',
                        pt.net >= 0 ? 'text-income' : 'text-expense'
                      )}
                    >
                      {pt.net >= 0 ? '+' : ''}
                      {formatAmount(pt.net, currency)}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Grafik Komposisi Kategori */}
      <Card className="print-avoid-break">
        <CardHeader className="pb-2 border-b border-border flex flex-row items-center justify-between gap-2">
          <div className="flex items-center gap-2">
            <PieChart className="w-4 h-4 text-primary" />
            <CardTitle className="text-base">Komposisi Kategori</CardTitle>
          </div>
          <div className="inline-flex rounded-md border border-border bg-subtle p-0.5 print:hidden">
            <button
              type="button"
              onClick={() => setCatTab('expense')}
              className={cn(
                'min-h-11 px-3 rounded-sm text-xs font-medium transition-colors',
                catTab === 'expense'
                  ? 'bg-card text-expense border border-border shadow-card font-semibold'
                  : 'text-muted-foreground hover:text-foreground'
              )}
            >
              Pengeluaran
            </button>
            <button
              type="button"
              onClick={() => setCatTab('income')}
              className={cn(
                'min-h-11 px-3 rounded-sm text-xs font-medium transition-colors',
                catTab === 'income'
                  ? 'bg-card text-income border border-border shadow-card font-semibold'
                  : 'text-muted-foreground hover:text-foreground'
              )}
            >
              Pemasukan
            </button>
          </div>
        </CardHeader>

        <CardContent className="pt-4 space-y-3">
          {activeCategories.length === 0 ? (
            <div className="py-12 text-center text-xs text-muted-foreground">
              Belum ada data kategori untuk tipe {catTab === 'expense' ? 'pengeluaran' : 'pemasukan'}.
            </div>
          ) : (
            <div className="space-y-3">
              {activeCategories.map((cat) => {
                const barWidthPct = Math.max(4, Math.round((cat.total / maxCatTotal) * 100));
                return (
                  <div key={cat.key} className="space-y-1">
                    <div className="flex items-center justify-between gap-2 text-xs">
                      <span className="font-medium text-foreground truncate">{cat.name}</span>
                      <span className="text-muted-foreground tabular-nums shrink-0">
                        <strong className="text-foreground">
                          {formatAmount(cat.total, currency)}
                        </strong>{' '}
                        ({cat.sharePercent.toFixed(1)}%)
                      </span>
                    </div>
                    <svg
                      viewBox="0 0 100 6"
                      preserveAspectRatio="none"
                      aria-hidden="true"
                      className="w-full h-2.5 rounded-sm bg-subtle overflow-hidden"
                    >
                      <rect
                        x={0}
                        y={0}
                        width={barWidthPct}
                        height={6}
                        rx={2}
                        fill={catTab === 'expense' ? 'var(--expense)' : 'var(--income)'}
                      />
                    </svg>
                  </div>
                );
              })}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
