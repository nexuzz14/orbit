'use client';

import React from 'react';
import { cn } from './cn';

export function PropertyChip({
  icon,
  label,
  onClick,
  tone = 'neutral',
  className,
}: {
  icon?: React.ReactNode;
  label: string;
  onClick?: () => void;
  tone?: 'neutral' | 'primary' | 'warning' | 'expense' | 'income';
  className?: string;
}) {
  const tones: Record<string, string> = {
    neutral: 'bg-subtle text-foreground border-border hover:bg-hover',
    primary: 'bg-primary-subtle text-primary border-primary hover:opacity-90',
    warning: 'bg-warning-subtle text-warning border-warning-border hover:opacity-90',
    expense: 'bg-expense-subtle text-expense border-expense-border hover:opacity-90',
    income: 'bg-income-subtle text-income border-income-border hover:opacity-90',
  };

  if (onClick) {
    return (
      <button
        type="button"
        onClick={onClick}
        className={cn(
          'inline-flex min-h-8 items-center gap-1.5 rounded-sm border px-2.5 py-1 text-xs font-medium transition-colors duration-150 tabular-nums',
          tones[tone],
          className
        )}
      >
        {icon}
        <span>{label}</span>
      </button>
    );
  }

  return (
    <span
      className={cn(
        'inline-flex items-center gap-1.5 rounded-sm border px-2 py-0.5 text-xs font-medium tabular-nums',
        tones[tone],
        className
      )}
    >
      {icon}
      <span>{label}</span>
    </span>
  );
}

export function PropertyRow({
  label,
  children,
  className,
}: {
  label: string;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div
      className={cn(
        'grid grid-cols-[88px_minmax(0,1fr)] sm:grid-cols-[120px_minmax(0,1fr)] items-center gap-2.5 sm:gap-3 py-1.5 text-sm border-b border-border/60 last:border-b-0 min-w-0',
        className
      )}
    >
      <span className="text-xs font-medium text-muted-foreground truncate">{label}</span>
      <div className="min-w-0 flex items-center gap-2 flex-wrap">{children}</div>
    </div>
  );
}

export function BlockContainer({
  title,
  action,
  children,
  className,
}: {
  title?: string;
  action?: React.ReactNode;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <section
      className={cn('rounded-md border border-border bg-card overflow-hidden', className)}
    >
      {(title || action) && (
        <div className="flex items-center justify-between gap-2 px-3.5 py-2.5 border-b border-border bg-sidebar/70">
          {title ? <h3 className="text-xs font-semibold uppercase tracking-wide text-muted-foreground">{title}</h3> : <span />}
          {action}
        </div>
      )}
      <div className="p-3.5">{children}</div>
    </section>
  );
}
