'use client';

import React from 'react';
import { cn } from './cn';

export type ActivityKind = 'intern' | 'freelance' | 'kuliah' | 'pribadi' | 'personal';

export const ACTIVITY_KIND_META: Record<
  ActivityKind,
  { label: string; style: React.CSSProperties }
> = {
  intern: {
    label: 'Intern',
    style: {
      color: 'var(--kind-intern-fg)',
      backgroundColor: 'var(--kind-intern-bg)',
      borderColor: 'var(--kind-intern-border)',
    },
  },
  freelance: {
    label: 'Freelance',
    style: {
      color: 'var(--kind-freelance-fg)',
      backgroundColor: 'var(--kind-freelance-bg)',
      borderColor: 'var(--kind-freelance-border)',
    },
  },
  kuliah: {
    label: 'Kuliah',
    style: {
      color: 'var(--kind-kuliah-fg)',
      backgroundColor: 'var(--kind-kuliah-bg)',
      borderColor: 'var(--kind-kuliah-border)',
    },
  },
  pribadi: {
    label: 'Pribadi',
    style: {
      color: 'var(--kind-pribadi-fg)',
      backgroundColor: 'var(--kind-pribadi-bg)',
      borderColor: 'var(--kind-pribadi-border)',
    },
  },
  personal: {
    label: 'Pribadi',
    style: {
      color: 'var(--kind-pribadi-fg)',
      backgroundColor: 'var(--kind-pribadi-bg)',
      borderColor: 'var(--kind-pribadi-border)',
    },
  },
};

export type TaskWorkflowStatus = 'todo' | 'doing' | 'revisi' | 'done';

export const TASK_STATUS_META: Record<
  TaskWorkflowStatus,
  { label: string; shortLabel: string; style: React.CSSProperties }
> = {
  todo: {
    label: 'Belum dikerjakan',
    shortLabel: 'Belum',
    style: {
      color: 'var(--status-todo-fg)',
      backgroundColor: 'var(--status-todo-bg)',
      borderColor: 'var(--status-todo-border)',
    },
  },
  doing: {
    label: 'Dikerjakan',
    shortLabel: 'Dikerjakan',
    style: {
      color: 'var(--status-doing-fg)',
      backgroundColor: 'var(--status-doing-bg)',
      borderColor: 'var(--status-doing-border)',
    },
  },
  revisi: {
    label: 'Revisi',
    shortLabel: 'Revisi',
    style: {
      color: 'var(--status-revisi-fg)',
      backgroundColor: 'var(--status-revisi-bg)',
      borderColor: 'var(--status-revisi-border)',
    },
  },
  done: {
    label: 'Selesai',
    shortLabel: 'Selesai',
    style: {
      color: 'var(--status-done-fg)',
      backgroundColor: 'var(--status-done-bg)',
      borderColor: 'var(--status-done-border)',
    },
  },
};

export function KindBadge({ kind, className }: { kind?: string | null; className?: string }) {
  const normalized = (kind?.toLowerCase() || 'pribadi') as ActivityKind;
  const meta = ACTIVITY_KIND_META[normalized] || ACTIVITY_KIND_META.pribadi;
  return (
    <span
      style={meta.style}
      className={cn(
        'inline-flex items-center gap-1.5 rounded-sm border px-2 py-0.5 text-xs font-medium leading-4',
        className
      )}
    >
      <span
        aria-hidden="true"
        className="h-1.5 w-1.5 rounded-full"
        style={{ backgroundColor: meta.style.color }}
      />
      <span>{meta.label}</span>
    </span>
  );
}

export function StatusBadge({
  variant = 'neutral',
  children,
  className,
}: {
  variant?: 'neutral' | 'income' | 'expense' | 'warning';
  children: React.ReactNode;
  className?: string;
}) {
  const styles: Record<string, string> = {
    neutral: 'bg-subtle text-muted-foreground border-border',
    income: 'bg-income-subtle text-income border-income-border',
    expense: 'bg-expense-subtle text-expense border-expense-border',
    warning: 'bg-warning-subtle text-warning border-warning-border',
  };
  return (
    <span
      className={cn(
        'inline-flex items-center rounded-sm border px-2 py-0.5 text-xs font-medium leading-4 tabular-nums',
        styles[variant],
        className
      )}
    >
      {children}
    </span>
  );
}

export function TaskStatusBadge({
  status,
  compact = false,
  className,
}: {
  status: string;
  compact?: boolean;
  className?: string;
}) {
  const key = (status in TASK_STATUS_META ? status : 'todo') as TaskWorkflowStatus;
  const meta = TASK_STATUS_META[key];
  return (
    <span
      style={meta.style}
      className={cn(
        'inline-flex items-center gap-1.5 rounded-xs border px-2 py-0.5 text-xs font-semibold leading-4',
        className
      )}
    >
      <span
        aria-hidden="true"
        className="h-1.5 w-1.5 rounded-full"
        style={{ backgroundColor: meta.style.color }}
      />
      <span>{compact ? meta.shortLabel : meta.label}</span>
    </span>
  );
}
