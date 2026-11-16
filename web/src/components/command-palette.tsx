'use client';

import React, { useEffect, useMemo, useRef, useState } from 'react';
import { usePathname, useRouter } from 'next/navigation';
import { Command } from 'cmdk';
import {
  BarChart3,
  Briefcase,
  Calendar,
  CalendarClock,
  CalendarDays,
  CheckSquare,
  CornerDownLeft,
  Inbox,
  Kanban,
  Loader2,
  Moon,
  PieChart,
  Plus,
  Receipt,
  Search,
  Settings,
  Sun,
  Tags,
  Target,
  Wallet,
  X,
} from 'lucide-react';
import { createClient } from '@/lib/supabase/client';
import { cn, KindBadge, StatusBadge, TaskStatusBadge } from '@/components/ui';

export interface GlobalSearchResult {
  entity_type: 'task' | 'project' | 'event' | 'transaction' | string;
  entity_id: string;
  title: string;
  subtitle: string;
  status_label: string;
  kind: string;
}

interface CommandPaletteProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  workspaceId: string | null;
  isDark: boolean;
  onToggleTheme: () => void;
  onOpenNewTransaction: () => void;
}

interface NavShortcutItem {
  id: string;
  label: string;
  href: string;
  keywords: string;
  icon: React.ComponentType<{ className?: string }>;
}

const NAV_SHORTCUTS: NavShortcutItem[] = [
  { id: 'nav-hari-ini', label: 'Hari Ini', href: '/hari-ini', keywords: 'today ringkasan fokus', icon: Calendar },
  { id: 'nav-jadwal', label: 'Agenda & Jadwal', href: '/jadwal', keywords: 'kalender acara event', icon: CalendarDays },
  { id: 'nav-tugas', label: 'Tugas & Papan', href: '/tugas', keywords: 'task kanban daftar checklist', icon: CheckSquare },
  { id: 'nav-transaksi', label: 'Transaksi Keuangan', href: '/transaksi', keywords: 'uang pengeluaran pemasukan', icon: Receipt },
  { id: 'nav-anggaran', label: 'Anggaran', href: '/anggaran', keywords: 'budget batas pengeluaran', icon: PieChart },
  { id: 'nav-tagihan', label: 'Tagihan Rutin', href: '/tagihan', keywords: 'bill langganan cicilan', icon: CalendarClock },
  { id: 'nav-tabungan', label: 'Target Tabungan', href: '/tabungan', keywords: 'savings goal dana darurat', icon: Target },
  { id: 'nav-akun', label: 'Akun & Saldo', href: '/akun', keywords: 'dompet bank ewallet', icon: Wallet },
  { id: 'nav-ringkasan', label: 'Ringkasan Keuangan', href: '/ringkasan', keywords: 'laporan cashflow grafik', icon: BarChart3 },
  { id: 'nav-proyek', label: 'Kegiatan & Proyek', href: '/proyek', keywords: 'project client piutang termin', icon: Briefcase },
  { id: 'nav-inbox', label: 'Inbox Draft', href: '/inbox', keywords: 'notifikasi draft otomatis', icon: Inbox },
  { id: 'nav-kategori', label: 'Kategori & Aturan', href: '/kategori', keywords: 'rules auto kategori', icon: Tags },
  { id: 'nav-pengaturan', label: 'Pengaturan', href: '/pengaturan', keywords: 'profil keamanan mfa sesi', icon: Settings },
];

const ENTITY_TYPE_LABEL: Record<string, string> = {
  task: 'Tugas',
  project: 'Kegiatan',
  event: 'Jadwal',
  transaction: 'Transaksi',
};

export function CommandPalette({
  open,
  onOpenChange,
  workspaceId,
  isDark,
  onToggleTheme,
  onOpenNewTransaction,
}: CommandPaletteProps) {
  const supabase = useMemo(() => createClient(), []);
  const router = useRouter();
  const pathname = usePathname();
  const inputRef = useRef<HTMLInputElement>(null);

  const [query, setQuery] = useState('');
  const [searching, setSearching] = useState(false);
  const [results, setResults] = useState<GlobalSearchResult[]>([]);
  const [searchError, setSearchError] = useState<string | null>(null);

  useEffect(() => {
    if (!open) {
      setQuery('');
      setResults([]);
      setSearchError(null);
      return;
    }
    const timer = window.setTimeout(() => {
      inputRef.current?.focus();
    }, 10);
    return () => window.clearTimeout(timer);
  }, [open]);

  useEffect(() => {
    if (!open) return;
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.preventDefault();
        onOpenChange(false);
      }
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [open, onOpenChange]);

  useEffect(() => {
    if (!open) return;
    const trimmed = query.trim();
    if (!trimmed || !workspaceId) {
      setResults([]);
      setSearching(false);
      setSearchError(null);
      return;
    }

    let cancelled = false;
    setSearching(true);
    setSearchError(null);

    const timer = window.setTimeout(async () => {
      try {
        const { data, error } = await supabase.rpc('fn_global_search', {
          p_workspace_id: workspaceId,
          p_query: trimmed,
          p_limit: 20,
        });

        if (cancelled) return;

        if (!error && Array.isArray(data)) {
          setResults(data as GlobalSearchResult[]);
          setSearching(false);
          return;
        }

        // Fallback gracefully if fn_global_search is not yet deployed in cloud
        const fallbackResults: GlobalSearchResult[] = [];
        const pattern = `%${trimmed}%`;
        const [taskRes, projRes, evtRes] = await Promise.all([
          supabase
            .from('tasks')
            .select('id, title, status, kind')
            .eq('workspace_id', workspaceId)
            .is('deleted_at', null)
            .ilike('title', pattern)
            .limit(6),
          supabase
            .from('projects')
            .select('id, name, status, kind, client_name')
            .eq('workspace_id', workspaceId)
            .is('deleted_at', null)
            .ilike('name', pattern)
            .limit(5),
          supabase
            .from('events')
            .select('id, title, kind, location')
            .eq('workspace_id', workspaceId)
            .is('deleted_at', null)
            .ilike('title', pattern)
            .limit(5),
        ]);

        if (cancelled) return;

        for (const t of taskRes.data ?? []) {
          fallbackResults.push({
            entity_type: 'task',
            entity_id: t.id,
            title: t.title,
            subtitle: 'Tugas workspace',
            status_label: t.status,
            kind: t.kind,
          });
        }
        for (const p of projRes.data ?? []) {
          fallbackResults.push({
            entity_type: 'project',
            entity_id: p.id,
            title: p.name,
            subtitle: p.client_name || `Kegiatan ${p.kind}`,
            status_label: p.status,
            kind: p.kind,
          });
        }
        for (const ev of evtRes.data ?? []) {
          fallbackResults.push({
            entity_type: 'event',
            entity_id: ev.id,
            title: ev.title,
            subtitle: ev.location || 'Jadwal',
            status_label: 'scheduled',
            kind: ev.kind,
          });
        }

        setResults(fallbackResults);
        if (error && fallbackResults.length === 0) {
          setSearchError(error.message);
        }
      } catch (err: unknown) {
        if (!cancelled) {
          setSearchError(err instanceof Error ? err.message : 'Gagal mencari data.');
        }
      } finally {
        if (!cancelled) setSearching(false);
      }
    }, 220);

    return () => {
      cancelled = true;
      window.clearTimeout(timer);
    };
  }, [open, query, workspaceId, supabase]);

  const trimmedQuery = query.trim().toLowerCase();

  const quickActions = useMemo(() => {
    const base = [
      {
        id: 'action-hari-ini',
        label: 'Ke Hari Ini',
        hint: 'Ringkasan fokus hari ini',
        icon: Calendar,
        run: () => router.push('/hari-ini'),
      },
      {
        id: 'action-kanban',
        label: 'Buka Papan Kanban Tugas',
        hint: 'Lihat kolom Belum, Dikerjakan, Revisi, Selesai',
        icon: Kanban,
        run: () => {
          router.push('/tugas?viewMode=board');
          window.dispatchEvent(new CustomEvent('orbit:tasks-view-mode', { detail: { mode: 'board' } }));
        },
      },
      {
        id: 'action-new-task',
        label: 'Buat Tugas Baru',
        hint: 'Tambah tugas atau pakai template',
        icon: Plus,
        run: () => {
          if (pathname === '/tugas') {
            window.dispatchEvent(new CustomEvent('orbit:open-new-task'));
          } else {
            router.push('/tugas?new=1');
          }
        },
      },
      {
        id: 'action-new-tx',
        label: 'Buat Transaksi',
        hint: 'Catat pemasukan, pengeluaran, atau transfer',
        icon: Receipt,
        run: () => onOpenNewTransaction(),
      },
      {
        id: 'action-toggle-theme',
        label: isDark ? 'Toggle Tema Gelap/Terang (Aktif: Gelap)' : 'Toggle Tema Gelap/Terang (Aktif: Terang)',
        hint: isDark ? 'Beralih ke mode terang' : 'Beralih ke mode gelap',
        icon: isDark ? Sun : Moon,
        run: () => onToggleTheme(),
      },
    ];

    if (!trimmedQuery) return base;
    return base.filter(
      (a) =>
        a.label.toLowerCase().includes(trimmedQuery) ||
        a.hint.toLowerCase().includes(trimmedQuery)
    );
  }, [isDark, onOpenNewTransaction, onToggleTheme, pathname, router, trimmedQuery]);

  const filteredNavShortcuts = useMemo(() => {
    if (!trimmedQuery) return NAV_SHORTCUTS.slice(0, 6);
    return NAV_SHORTCUTS.filter(
      (item) =>
        item.label.toLowerCase().includes(trimmedQuery) ||
        item.keywords.toLowerCase().includes(trimmedQuery) ||
        item.href.toLowerCase().includes(trimmedQuery)
    );
  }, [trimmedQuery]);

  const handleSelectSearchResult = (item: GlobalSearchResult) => {
    onOpenChange(false);
    if (item.entity_type === 'task') {
      if (pathname === '/tugas') {
        router.replace(`/tugas?task=${item.entity_id}`);
        window.dispatchEvent(
          new CustomEvent('orbit:open-task-peek', { detail: { taskId: item.entity_id } })
        );
      } else {
        router.push(`/tugas?task=${item.entity_id}`);
      }
      return;
    }
    if (item.entity_type === 'project') {
      router.push(`/proyek?project=${item.entity_id}`);
      return;
    }
    if (item.entity_type === 'event') {
      router.push(`/jadwal?event=${item.entity_id}`);
      return;
    }
    if (item.entity_type === 'transaction') {
      router.push(`/transaksi?tx=${item.entity_id}`);
    }
  };

  if (!open) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex items-start justify-center bg-slate-950/60 p-3 pt-12 sm:p-6 sm:pt-20"
      role="dialog"
      aria-modal="true"
      aria-label="Command Palette Orbit"
      onMouseDown={(e) => {
        if (e.target === e.currentTarget) onOpenChange(false);
      }}
    >
      <div className="w-full max-w-xl overflow-hidden rounded-lg border border-border bg-card shadow-peek">
        <Command label="Pencarian cepat dan aksi Orbit" shouldFilter={false} loop>
          <div className="flex items-center gap-2 border-b border-border px-3">
            <Search className="h-4 w-4 shrink-0 text-muted-foreground" aria-hidden="true" />
            <Command.Input
              ref={inputRef}
              value={query}
              onValueChange={setQuery}
              placeholder="Cari tugas, proyek, jadwal, transaksi, atau perintah..."
              className="h-12 w-full bg-transparent text-sm text-foreground placeholder:text-muted-foreground focus:outline-none"
            />
            {searching && (
              <Loader2 className="h-4 w-4 shrink-0 animate-spin text-primary" aria-hidden="true" />
            )}
            <button
              type="button"
              onClick={() => onOpenChange(false)}
              aria-label="Tutup pencarian cepat"
              className="inline-flex h-10 w-10 shrink-0 items-center justify-center rounded-md text-muted-foreground hover:bg-subtle hover:text-foreground"
            >
              <X className="h-4 w-4" />
            </button>
          </div>

          <Command.List className="max-h-[65dvh] overflow-y-auto p-2 space-y-2">
            {trimmedQuery && !searching && results.length === 0 && quickActions.length === 0 && filteredNavShortcuts.length === 0 && (
              <Command.Empty className="py-8 text-center text-xs text-muted-foreground">
                Tidak ada hasil untuk &ldquo;{query.trim()}&rdquo;.
              </Command.Empty>
            )}

            {searchError && (
              <div className="rounded-md border border-warning-border bg-warning-subtle px-3 py-2 text-xs text-warning">
                Pencarian global database: {searchError}
              </div>
            )}

            {trimmedQuery && results.length > 0 && (
              <Command.Group
                heading="Hasil Pencarian Workspace"
                className="[&_[cmdk-group-heading]]:px-2 [&_[cmdk-group-heading]]:py-1.5 [&_[cmdk-group-heading]]:text-[11px] [&_[cmdk-group-heading]]:font-semibold [&_[cmdk-group-heading]]:uppercase [&_[cmdk-group-heading]]:tracking-wider [&_[cmdk-group-heading]]:text-muted-foreground"
              >
                {results.map((item) => {
                  const Icon =
                    item.entity_type === 'task'
                      ? CheckSquare
                      : item.entity_type === 'project'
                      ? Briefcase
                      : item.entity_type === 'event'
                      ? CalendarDays
                      : Receipt;
                  const typeLabel = ENTITY_TYPE_LABEL[item.entity_type] || item.entity_type;

                  return (
                    <Command.Item
                      key={`${item.entity_type}-${item.entity_id}`}
                      value={`${item.entity_type}-${item.entity_id}-${item.title}`}
                      onSelect={() => handleSelectSearchResult(item)}
                      className={cn(
                        'min-h-11 flex cursor-pointer items-center justify-between gap-3 rounded-md px-2.5 py-2 text-sm text-foreground',
                        'aria-selected:bg-subtle data-[selected=true]:bg-subtle'
                      )}
                    >
                      <div className="flex items-center gap-2.5 min-w-0 flex-1">
                        <Icon className="h-4 w-4 shrink-0 text-primary" aria-hidden="true" />
                        <div className="min-w-0 flex-1">
                          <div className="truncate font-medium">{item.title}</div>
                          <div className="truncate text-xs text-muted-foreground tabular-nums">
                            {typeLabel} &middot; {item.subtitle}
                          </div>
                        </div>
                      </div>
                      <div className="flex items-center gap-1.5 shrink-0">
                        {item.entity_type === 'task' ? (
                          <TaskStatusBadge status={item.status_label} compact />
                        ) : (
                          <StatusBadge variant="neutral">{item.status_label}</StatusBadge>
                        )}
                        {(item.kind === 'intern' ||
                          item.kind === 'freelance' ||
                          item.kind === 'kuliah' ||
                          item.kind === 'pribadi') && <KindBadge kind={item.kind} />}
                      </div>
                    </Command.Item>
                  );
                })}
              </Command.Group>
            )}

            {quickActions.length > 0 && (
              <Command.Group
                heading="Aksi Cepat"
                className="[&_[cmdk-group-heading]]:px-2 [&_[cmdk-group-heading]]:py-1.5 [&_[cmdk-group-heading]]:text-[11px] [&_[cmdk-group-heading]]:font-semibold [&_[cmdk-group-heading]]:uppercase [&_[cmdk-group-heading]]:tracking-wider [&_[cmdk-group-heading]]:text-muted-foreground"
              >
                {quickActions.map((act) => {
                  const Icon = act.icon;
                  return (
                    <Command.Item
                      key={act.id}
                      value={act.id}
                      onSelect={() => {
                        onOpenChange(false);
                        act.run();
                      }}
                      className={cn(
                        'min-h-11 flex cursor-pointer items-center justify-between gap-3 rounded-md px-2.5 py-2 text-sm text-foreground',
                        'aria-selected:bg-subtle data-[selected=true]:bg-subtle'
                      )}
                    >
                      <div className="flex items-center gap-2.5 min-w-0">
                        <Icon className="h-4 w-4 shrink-0 text-primary" aria-hidden="true" />
                        <div className="min-w-0">
                          <div className="font-medium truncate">{act.label}</div>
                          <div className="text-xs text-muted-foreground truncate">{act.hint}</div>
                        </div>
                      </div>
                      <CornerDownLeft className="h-3.5 w-3.5 shrink-0 text-muted-foreground" aria-hidden="true" />
                    </Command.Item>
                  );
                })}
              </Command.Group>
            )}

            {filteredNavShortcuts.length > 0 && (
              <>
                <Command.Separator className="my-1 h-px bg-border" />
                <Command.Group
                  heading="Lompat ke Halaman"
                  className="[&_[cmdk-group-heading]]:px-2 [&_[cmdk-group-heading]]:py-1.5 [&_[cmdk-group-heading]]:text-[11px] [&_[cmdk-group-heading]]:font-semibold [&_[cmdk-group-heading]]:uppercase [&_[cmdk-group-heading]]:tracking-wider [&_[cmdk-group-heading]]:text-muted-foreground"
                >
                  {filteredNavShortcuts.map((nav) => {
                    const Icon = nav.icon;
                    return (
                      <Command.Item
                        key={nav.id}
                        value={nav.id}
                        onSelect={() => {
                          onOpenChange(false);
                          router.push(nav.href);
                        }}
                        className={cn(
                          'min-h-11 flex cursor-pointer items-center justify-between gap-3 rounded-md px-2.5 py-2 text-sm text-foreground',
                          'aria-selected:bg-subtle data-[selected=true]:bg-subtle'
                        )}
                      >
                        <div className="flex items-center gap-2.5 min-w-0">
                          <Icon className="h-4 w-4 shrink-0 text-muted-foreground" aria-hidden="true" />
                          <span className="truncate font-medium">{nav.label}</span>
                        </div>
                        <span className="font-mono text-[11px] text-muted-foreground">{nav.href}</span>
                      </Command.Item>
                    );
                  })}
                </Command.Group>
              </>
            )}
          </Command.List>

          <div className="flex items-center justify-between border-t border-border bg-sidebar/60 px-3 py-2 text-[11px] text-muted-foreground">
            <span>Gunakan panah atas/bawah dan Enter untuk memilih</span>
            <span className="font-mono">Ctrl+K / Esc</span>
          </div>
        </Command>
      </div>
    </div>
  );
}
