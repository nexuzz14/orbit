'use client';

import React from 'react';
import { Lock } from 'lucide-react';
import { cn } from './cn';

export function ProgressControl({
  value,
  lockedByChecklist = false,
  onChange,
  compact = false,
  className,
}: {
  value: number;
  lockedByChecklist?: boolean;
  onChange?: (next: number) => void;
  compact?: boolean;
  className?: string;
}) {
  const clamped = Math.max(0, Math.min(100, Math.round(value)));
  const fillColor =
    clamped >= 100
      ? 'bg-income'
      : clamped > 0
      ? 'bg-primary'
      : 'bg-border-strong';

  if (compact) {
    return (
      <div className={cn('flex items-center gap-2', className)}>
        <div className="h-1.5 flex-1 overflow-hidden rounded-full bg-subtle">
          <div
            className={cn('h-full rounded-full transition-all duration-150', fillColor)}
            style={{ width: `${clamped}%` }}
          />
        </div>
        <span className="text-xs font-medium text-muted-foreground tabular-nums w-8 text-right">
          {clamped}%
        </span>
      </div>
    );
  }

  return (
    <div className={cn('space-y-1.5 w-full', className)}>
      <div className="flex items-center justify-between gap-2">
        <div className="h-2 flex-1 overflow-hidden rounded-full bg-subtle">
          <div
            className={cn('h-full rounded-full transition-all duration-150', fillColor)}
            style={{ width: `${clamped}%` }}
          />
        </div>
        <span className="text-xs font-semibold text-foreground tabular-nums">{clamped}%</span>
        {lockedByChecklist && (
          <span
            title="Progres dihitung otomatis dari checklist/subtugas"
            className="inline-flex items-center gap-1 text-[11px] text-muted-foreground"
          >
            <Lock className="h-3 w-3" aria-hidden="true" />
            Otomatis
          </span>
        )}
      </div>
      {!lockedByChecklist && onChange && (
        <input
          type="range"
          min={0}
          max={100}
          step={5}
          value={clamped}
          aria-label="Atur persentase progres"
          onChange={(e) => onChange(Number(e.target.value))}
          className="h-6 w-full cursor-pointer accent-primary"
        />
      )}
    </div>
  );
}
