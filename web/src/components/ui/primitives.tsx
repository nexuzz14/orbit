'use client';

import React, { useEffect } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { AlertCircle, Inbox, PiggyBank, Receipt, RefreshCw, Target, X } from 'lucide-react';
import { clsx } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: Array<string | undefined | null | false>) {
  return twMerge(clsx(inputs));
}

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

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'outline' | 'ghost' | 'destructive';
  size?: 'default' | 'sm' | 'icon';
}

export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant = 'primary', size = 'default', type = 'button', ...props }, ref) => {
    const variantStyles: Record<NonNullable<ButtonProps['variant']>, string> = {
      primary: 'bg-primary text-primary-foreground hover:opacity-90 border border-transparent',
      secondary: 'bg-subtle text-foreground hover:bg-border/60 border border-border',
      outline: 'bg-card text-foreground hover:bg-subtle border border-border',
      ghost: 'bg-transparent text-foreground hover:bg-subtle border border-transparent',
      destructive: 'bg-expense-subtle text-expense hover:opacity-90 border border-expense-border',
    };

    const sizeStyles: Record<NonNullable<ButtonProps['size']>, string> = {
      default: 'min-h-11 px-4 py-2.5 text-sm font-medium',
      sm: 'min-h-11 px-3 py-2 text-xs font-medium',
      icon: 'h-11 w-11 p-0',
    };

    return (
      <button
        ref={ref}
        type={type}
        className={cn(
          'inline-flex items-center justify-center gap-2 rounded-md transition-colors duration-150 disabled:opacity-50 disabled:pointer-events-none select-none',
          variantStyles[variant],
          sizeStyles[size],
          className
        )}
        {...props}
      />
    );
  }
);
Button.displayName = 'Button';

export const Input = React.forwardRef<
  HTMLInputElement,
  React.InputHTMLAttributes<HTMLInputElement>
>(({ className, ...props }, ref) => (
  <input
    ref={ref}
    className={cn(
      'h-11 w-full rounded-md border border-border bg-card px-3 py-2 text-sm text-foreground placeholder:text-muted-foreground transition-colors duration-150 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary disabled:opacity-50',
      className
    )}
    {...props}
  />
));
Input.displayName = 'Input';

export const Select = React.forwardRef<
  HTMLSelectElement,
  React.SelectHTMLAttributes<HTMLSelectElement>
>(({ className, children, ...props }, ref) => (
  <select
    ref={ref}
    className={cn(
      'h-11 w-full rounded-md border border-border bg-card px-3 py-2 text-sm text-foreground transition-colors duration-150 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary disabled:opacity-50',
      className
    )}
    {...props}
  >
    {children}
  </select>
));
Select.displayName = 'Select';

export function Card({ className, children, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn('rounded-lg border border-border bg-card text-card-foreground shadow-card', className)}
      {...props}
    >
      {children}
    </div>
  );
}

export function CardHeader({ className, children, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div className={cn('flex items-center justify-between gap-2 px-4 py-3.5 border-b border-border', className)} {...props}>
      {children}
    </div>
  );
}

export function CardTitle({ className, children, ...props }: React.HTMLAttributes<HTMLHeadingElement>) {
  return (
    <h2 className={cn('text-base font-semibold text-foreground leading-snug', className)} {...props}>
      {children}
    </h2>
  );
}

export function CardContent({ className, children, ...props }: React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div className={cn('p-4', className)} {...props}>
      {children}
    </div>
  );
}

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
        'inline-flex items-center rounded-sm border px-2 py-0.5 text-xs font-medium leading-4',
        styles[variant],
        className
      )}
    >
      {children}
    </span>
  );
}

export function SegmentedControl<T extends string>({
  options,
  value,
  onChange,
  ariaLabel,
  fullWidth,
  className,
}: {
  options: Array<{ value: T; label: string }>;
  value: T;
  onChange: (next: T) => void;
  ariaLabel: string;
  fullWidth?: boolean;
  className?: string;
}) {
  return (
    <div
      role="tablist"
      aria-label={ariaLabel}
      className={cn(
        'inline-flex items-center rounded-md bg-subtle p-1 border border-border',
        fullWidth && 'flex w-full',
        className
      )}
    >
      {options.map((opt) => {
        const active = opt.value === value;
        return (
          <button
            key={opt.value}
            type="button"
            role="tab"
            aria-selected={active}
            onClick={() => onChange(opt.value)}
            className={cn(
              'min-h-11 flex-1 rounded-sm px-3.5 py-1.5 text-sm font-medium transition-colors duration-150',
              active
                ? 'bg-card text-primary shadow-card border border-border'
                : 'text-muted-foreground hover:text-foreground'
            )}
          >
            {opt.label}
          </button>
        );
      })}
    </div>
  );
}

export function Skeleton({ className }: { className?: string }) {
  return <div aria-hidden="true" className={cn('animate-pulse rounded-md bg-subtle', className)} />;
}

export function EmptyState({
  title,
  description,
  actionLabel,
  onAction,
  icon,
}: {
  title: string;
  description: string;
  actionLabel?: string;
  onAction?: () => void;
  icon?: React.ReactNode;
}) {
  return (
    <div className="flex flex-col items-center justify-center rounded-lg border border-dashed border-border bg-card px-6 py-10 text-center">
      {icon && <div className="mb-3 text-muted-foreground">{icon}</div>}
      <h3 className="text-sm font-semibold text-foreground">{title}</h3>
      <p className="mt-1 max-w-sm text-xs text-muted-foreground">{description}</p>
      {actionLabel && onAction && (
        <Button variant="primary" size="default" onClick={onAction} className="mt-4">
          {actionLabel}
        </Button>
      )}
    </div>
  );
}

export function ErrorState({
  message = 'Tidak dapat memuat data. Periksa koneksi Anda dan coba kembali.',
  onRetry,
}: {
  message?: string;
  onRetry: () => void;
}) {
  return (
    <div
      role="alert"
      className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4 rounded-lg border border-expense-border bg-expense-subtle p-4"
    >
      <div className="flex items-start gap-3">
        <AlertCircle className="h-5 w-5 text-expense shrink-0 mt-0.5" aria-hidden="true" />
        <div>
          <h3 className="text-sm font-semibold text-expense">Gagal Memuat Data</h3>
          <p className="mt-0.5 text-xs text-foreground/90">{message}</p>
        </div>
      </div>
      <Button variant="outline" size="default" onClick={onRetry} className="shrink-0">
        <RefreshCw className="h-4 w-4" aria-hidden="true" />
        <span>Coba Lagi</span>
      </Button>
    </div>
  );
}

export function Dialog({
  open,
  onClose,
  title,
  description,
  children,
}: {
  open: boolean;
  onClose: () => void;
  title: string;
  description?: string;
  children: React.ReactNode;
}) {
  useEffect(() => {
    if (!open) return;
    const handleKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', handleKey);
    return () => window.removeEventListener('keydown', handleKey);
  }, [open, onClose]);

  if (!open) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-slate-950/60 p-0 sm:p-4"
      role="dialog"
      aria-modal="true"
      aria-label={title}
    >
      <div className="w-full max-w-lg rounded-t-lg sm:rounded-lg border border-border bg-card shadow-lg max-h-[92dvh] flex flex-col">
        <div className="flex items-center justify-between border-b border-border px-4 py-3">
          <div>
            <h2 className="text-base font-semibold text-foreground">{title}</h2>
            {description && <p className="text-xs text-muted-foreground mt-0.5">{description}</p>}
          </div>
          <Button variant="ghost" size="icon" onClick={onClose} aria-label="Tutup dialog">
            <X className="h-5 w-5" />
          </Button>
        </div>
        <div className="overflow-y-auto p-4">{children}</div>
      </div>
    </div>
  );
}

export function MoneySubNav({ draftCount = 0 }: { draftCount?: number }) {
  const pathname = usePathname();

  const mainTabs = [
    { href: '/transaksi', label: 'Transaksi' },
    { href: '/akun', label: 'Akun' },
    { href: '/ringkasan', label: 'Ringkasan' },
  ];

  const shortcuts = [
    { href: '/inbox', label: 'Inbox', icon: Inbox, badge: draftCount },
    { href: '/anggaran', label: 'Anggaran', icon: PiggyBank },
    { href: '/tagihan', label: 'Tagihan', icon: Receipt },
    { href: '/tabungan', label: 'Target', icon: Target },
  ];

  return (
    <div className="space-y-3">
      <div
        role="navigation"
        aria-label="Sub-navigasi Uang"
        className="inline-flex w-full sm:w-auto items-center rounded-md bg-subtle p-1 border border-border"
      >
        {mainTabs.map((t) => {
          const active = pathname === t.href || pathname.startsWith(`${t.href}/`);
          return (
            <Link
              key={t.href}
              href={t.href}
              className={cn(
                'min-h-11 flex-1 sm:flex-initial inline-flex items-center justify-center rounded-sm px-4 py-2 text-sm font-medium transition-colors duration-150',
                active
                  ? 'bg-card text-primary shadow-card border border-border'
                  : 'text-muted-foreground hover:text-foreground'
              )}
            >
              {t.label}
            </Link>
          );
        })}
      </div>

      <div className="flex items-center gap-2 overflow-x-auto pb-1" role="navigation" aria-label="Pintasan Uang">
        {shortcuts.map((s) => {
          const Icon = s.icon;
          const active = pathname === s.href;
          return (
            <Link
              key={s.href}
              href={s.href}
              className={cn(
                'min-h-11 inline-flex items-center gap-2 rounded-md border px-3.5 py-2 text-xs font-medium shrink-0 transition-colors duration-150',
                active
                  ? 'border-primary bg-primary-subtle text-primary'
                  : 'border-border bg-card text-foreground hover:bg-subtle'
              )}
            >
              <Icon className="h-4 w-4 shrink-0" aria-hidden="true" />
              <span>{s.label}</span>
              {typeof s.badge === 'number' && s.badge > 0 && (
                <span className="inline-flex items-center justify-center rounded-sm bg-warning-subtle border border-warning-border px-1.5 py-0.5 text-xs font-semibold text-warning tabular-nums">
                  {s.badge}
                </span>
              )}
            </Link>
          );
        })}
      </div>
    </div>
  );
}

export function AgendaSubNav() {
  const pathname = usePathname();
  const tabs = [
    { href: '/jadwal', label: 'Jadwal' },
    { href: '/tugas', label: 'Tugas' },
  ];

  return (
    <div
      role="navigation"
      aria-label="Sub-navigasi Agenda"
      className="inline-flex w-full sm:w-auto items-center rounded-md bg-subtle p-1 border border-border"
    >
      {tabs.map((t) => {
        const active = pathname === t.href || pathname.startsWith(`${t.href}/`);
        return (
          <Link
            key={t.href}
            href={t.href}
            className={cn(
              'min-h-11 flex-1 sm:flex-initial inline-flex items-center justify-center rounded-sm px-5 py-2 text-sm font-medium transition-colors duration-150',
              active
                ? 'bg-card text-primary shadow-card border border-border'
                : 'text-muted-foreground hover:text-foreground'
            )}
          >
            {t.label}
          </Link>
        );
      })}
    </div>
  );
}

export function LainnyaSubNav() {
  const pathname = usePathname();
  const tabs = [
    { href: '/proyek', label: 'Kegiatan & Piutang' },
    { href: '/kategori', label: 'Kategori & Aturan' },
    { href: '/pengaturan', label: 'Keamanan & Pengaturan' },
  ];

  return (
    <div
      role="navigation"
      aria-label="Sub-navigasi Lainnya"
      className="inline-flex w-full sm:w-auto items-center rounded-md bg-subtle p-1 border border-border overflow-x-auto"
    >
      {tabs.map((t) => {
        const active = pathname === t.href || pathname.startsWith(`${t.href}/`);
        return (
          <Link
            key={t.href}
            href={t.href}
            className={cn(
              'min-h-11 flex-1 sm:flex-initial shrink-0 inline-flex items-center justify-center rounded-sm px-4 py-2 text-sm font-medium transition-colors duration-150',
              active
                ? 'bg-card text-primary shadow-card border border-border'
                : 'text-muted-foreground hover:text-foreground'
            )}
          >
            {t.label}
          </Link>
        );
      })}
    </div>
  );
}

