'use client';

import React, { useEffect } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { Inbox, PiggyBank, Receipt, Target, X } from 'lucide-react';
import { cn } from './cn';

export { cn } from './cn';
export {
  ACTIVITY_KIND_META,
  TASK_STATUS_META,
  KindBadge,
  StatusBadge,
  TaskStatusBadge,
  type ActivityKind,
  type TaskWorkflowStatus,
} from './status-badge';
export { PropertyChip, PropertyRow, BlockContainer } from './property-chip';
export { ProgressControl } from './progress-control';
export { Skeleton, EmptyState, ErrorState } from './state-views';
export {
  AttentionBannerCard,
  type AttentionBannerCardProps,
  type AttentionPreviewItem,
} from './attention-card';

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

export const Textarea = React.forwardRef<
  HTMLTextAreaElement,
  React.TextareaHTMLAttributes<HTMLTextAreaElement>
>(({ className, ...props }, ref) => (
  <textarea
    ref={ref}
    className={cn(
      'min-h-[88px] w-full rounded-md border border-border bg-card px-3 py-2 text-sm text-foreground placeholder:text-muted-foreground transition-colors duration-150 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary disabled:opacity-50',
      className,
    )}
    {...props}
  />
));
Textarea.displayName = 'Textarea';

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

export interface ViewSwitcherOption<T extends string> {
  value: T;
  label: string;
  badge?: string | number;
}

export function ViewSwitcher<T extends string>({
  options,
  value,
  onChange,
  ariaLabel = 'Pilih tampilan',
  rightSlot,
  className,
}: {
  options: Array<ViewSwitcherOption<T>>;
  value: T;
  onChange: (value: T) => void;
  ariaLabel?: string;
  rightSlot?: React.ReactNode;
  className?: string;
}) {
  return (
    <div
      className={cn(
        'flex flex-col sm:flex-row sm:items-center justify-between gap-2.5 print:hidden',
        className
      )}
    >
      <div
        role="tablist"
        aria-label={ariaLabel}
        className="inline-flex w-full sm:w-auto items-center rounded-md bg-subtle p-1 border border-border overflow-x-auto"
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
                'min-h-11 shrink-0 flex-1 sm:flex-initial inline-flex items-center justify-center gap-1.5 rounded-sm px-3.5 py-2 text-sm font-medium transition-colors duration-150',
                active
                  ? 'bg-card text-primary shadow-card border border-border font-semibold'
                  : 'text-muted-foreground hover:text-foreground'
              )}
            >
              <span>{opt.label}</span>
              {opt.badge !== undefined && (
                <span className="rounded-sm bg-subtle border border-border px-1.5 py-0.5 text-[11px] font-semibold text-foreground tabular-nums">
                  {opt.badge}
                </span>
              )}
            </button>
          );
        })}
      </div>
      {rightSlot && <div className="flex flex-wrap items-center gap-2">{rightSlot}</div>}
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

  const phase3Items = [
    { href: '/anggaran', label: 'Anggaran', icon: PiggyBank },
    { href: '/tagihan', label: 'Tagihan', icon: Receipt },
    { href: '/tabungan', label: 'Target', icon: Target },
  ];

  return (
    <div className="space-y-3 print:hidden">
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

      <div
        className="flex items-center gap-2 overflow-x-auto pb-1 [mask-image:linear-gradient(to_right,black_calc(100%-24px),transparent)] sm:[mask-image:none]"
        role="navigation"
        aria-label="Pintasan Uang"
      >
        <Link
          href="/inbox"
          className={cn(
            'min-h-11 inline-flex items-center gap-2 rounded-md border px-3.5 py-2 text-xs font-medium shrink-0 transition-colors duration-150',
            pathname === '/inbox'
              ? 'border-primary bg-primary-subtle text-primary'
              : 'border-border bg-card text-foreground hover:bg-subtle'
          )}
        >
          <Inbox className="h-4 w-4 shrink-0" aria-hidden="true" />
          <span>Inbox</span>
          {typeof draftCount === 'number' && draftCount > 0 && (
            <span className="inline-flex items-center justify-center rounded-sm bg-warning-subtle border border-warning-border px-1.5 py-0.5 text-xs font-semibold text-warning tabular-nums">
              {draftCount}
            </span>
          )}
        </Link>

        {phase3Items.map((item) => {
          const Icon = item.icon;
          const active = pathname === item.href || pathname.startsWith(`${item.href}/`);
          return (
            <Link
              key={item.href}
              href={item.href}
              className={cn(
                'min-h-11 inline-flex items-center gap-2 rounded-md border px-3.5 py-2 text-xs font-medium shrink-0 transition-colors duration-150',
                active
                  ? 'border-primary bg-primary-subtle text-primary'
                  : 'border-border bg-card text-foreground hover:bg-subtle'
              )}
            >
              <Icon className="h-4 w-4 shrink-0" aria-hidden="true" />
              <span>{item.label}</span>
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
      className="print:hidden inline-flex w-full sm:w-auto items-center rounded-md bg-subtle p-1 border border-border"
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
      className="print:hidden inline-flex w-full sm:w-auto items-center rounded-md bg-subtle p-1 border border-border overflow-x-auto [mask-image:linear-gradient(to_right,black_calc(100%-24px),transparent)] sm:[mask-image:none]"
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

