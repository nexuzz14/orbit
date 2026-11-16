'use client';

import React from 'react';
import Link from 'next/link';
import { AlertTriangle, CalendarX2, Clock, RotateCcw } from 'lucide-react';
import { cn } from './cn';
import { StatusBadge } from './status-badge';

export interface AttentionPreviewItem {
  id: string;
  title: string;
  badge: string;
  tone: 'expense' | 'warning';
  subtitle?: string;
  onClick?: () => void;
  href?: string;
}

export interface AttentionBannerCardProps {
  overdueCount: number;
  revisiCount: number;
  stagnantCount: number;
  conflictCount: number;
  title?: string;
  subtitle?: string;
  onSelectMetric?: (metric: 'overdue' | 'revisi' | 'stagnant' | 'conflict') => void;
  hrefs?: {
    overdue?: string;
    revisi?: string;
    stagnant?: string;
    conflict?: string;
  };
  items?: AttentionPreviewItem[];
  className?: string;
}

export function AttentionBannerCard({
  overdueCount,
  revisiCount,
  stagnantCount,
  conflictCount,
  title = 'Perlu Perhatian',
  subtitle = 'Ringkasan tugas terlambat, revisi aktif, macet > 5 hari, dan jadwal bentrok.',
  onSelectMetric,
  hrefs,
  items = [],
  className,
}: AttentionBannerCardProps) {
  const total = overdueCount + revisiCount + stagnantCount + conflictCount;

  const metrics: Array<{
    key: 'overdue' | 'revisi' | 'stagnant' | 'conflict';
    label: string;
    count: number;
    tone: 'expense' | 'warning' | 'neutral';
    icon: React.ComponentType<{ className?: string }>;
    href?: string;
  }> = [
    {
      key: 'overdue',
      label: 'Terlambat',
      count: overdueCount,
      tone: overdueCount > 0 ? 'expense' : 'neutral',
      icon: AlertTriangle,
      href: hrefs?.overdue ?? '/tugas?attention=overdue',
    },
    {
      key: 'revisi',
      label: 'Perlu Revisi',
      count: revisiCount,
      tone: revisiCount > 0 ? 'warning' : 'neutral',
      icon: RotateCcw,
      href: hrefs?.revisi ?? '/tugas?attention=revisi',
    },
    {
      key: 'stagnant',
      label: 'Macet > 5 hari',
      count: stagnantCount,
      tone: stagnantCount > 0 ? 'warning' : 'neutral',
      icon: Clock,
      href: hrefs?.stagnant ?? '/tugas?attention=stagnant',
    },
    {
      key: 'conflict',
      label: 'Jadwal Bentrok',
      count: conflictCount,
      tone: conflictCount > 0 ? 'expense' : 'neutral',
      icon: CalendarX2,
      href: hrefs?.conflict ?? '/jadwal',
    },
  ];

  const toneClasses: Record<'expense' | 'warning' | 'neutral', string> = {
    expense: 'border-expense-border bg-expense-subtle text-expense',
    warning: 'border-warning-border bg-warning-subtle text-warning',
    neutral: 'border-border bg-subtle text-muted-foreground',
  };

  return (
    <section
      aria-label={title}
      className={cn(
        'rounded-lg border border-border bg-card p-4 space-y-3',
        className
      )}
    >
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
        <div>
          <div className="flex items-center gap-2">
            <h2 className="text-sm font-semibold text-foreground">{title}</h2>
            <StatusBadge variant={total > 0 ? 'warning' : 'income'}>
              {total > 0 ? `${total} perhatian` : 'Semua terkendali'}
            </StatusBadge>
          </div>
          <p className="text-xs text-muted-foreground mt-0.5">{subtitle}</p>
        </div>
      </div>

      <div className="grid grid-cols-2 sm:grid-cols-4 gap-2.5">
        {metrics.map((m) => {
          const Icon = m.icon;
          const cardContent = (
            <>
              <div className="flex items-center justify-between gap-2">
                <span className="text-xs font-medium">{m.label}</span>
                <Icon className="h-3.5 w-3.5 shrink-0" aria-hidden="true" />
              </div>
              <div className="mt-1 text-xl font-bold tabular-nums text-foreground">
                {m.count}
              </div>
            </>
          );

          const baseClass = cn(
            'min-h-11 flex flex-col justify-between rounded-md border px-3 py-2.5 text-left transition-colors duration-150 hover:opacity-90',
            toneClasses[m.tone]
          );

          if (onSelectMetric) {
            return (
              <button
                key={m.key}
                type="button"
                onClick={() => onSelectMetric(m.key)}
                className={baseClass}
              >
                {cardContent}
              </button>
            );
          }

          return (
            <Link key={m.key} href={m.href || '/tugas'} className={baseClass}>
              {cardContent}
            </Link>
          );
        })}
      </div>

      {items.length > 0 && (
        <div className="divide-y divide-border rounded-md border border-border bg-background/60">
          {items.slice(0, 4).map((item) => {
            const inner = (
              <div className="min-h-11 flex items-center justify-between gap-3 px-3 py-2 text-xs hover:bg-hover transition-colors">
                <div className="min-w-0 flex-1">
                  <div className="font-medium text-foreground truncate">{item.title}</div>
                  {item.subtitle && (
                    <div className="text-[11px] text-muted-foreground truncate">{item.subtitle}</div>
                  )}
                </div>
                <StatusBadge variant={item.tone}>{item.badge}</StatusBadge>
              </div>
            );

            if (item.onClick) {
              return (
                <button
                  key={item.id}
                  type="button"
                  onClick={item.onClick}
                  className="w-full text-left block"
                >
                  {inner}
                </button>
              );
            }

            return (
              <Link key={item.id} href={item.href || '/tugas'} className="block">
                {inner}
              </Link>
            );
          })}
        </div>
      )}
    </section>
  );
}
