'use client';

import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import Image from 'next/image';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import {
  BarChart3,
  Bookmark,
  Briefcase,
  Calendar,
  CalendarClock,
  CalendarDays,
  CheckSquare,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  ChevronsUpDown,
  Eye,
  EyeOff,
  Folder,
  Inbox,
  Lock,
  LogOut,
  Menu,
  Moon,
  Palette,
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
  Check,
} from 'lucide-react';
import { createClient } from '@/lib/supabase/client';
import { getSavedViewHref } from '@/lib/task-v2';
import { PrivacyProvider, usePrivacyMode } from '@/lib/privacy-mode';
import { ORBIT_ACCENTS, ThemeAccentProvider, useThemeAccent } from '@/lib/theme-accent';
import { Button, cn, KindBadge } from '@/components/ui';
import { TransactionFormModal, type TransactionPrefill } from '@/components/transaction-form-modal';
import { CommandPalette } from '@/components/command-palette';

interface WorkspaceOption {
  id: string;
  name: string;
  type?: string;
}

interface SidebarSavedView {
  id: string;
  name: string;
  scope: string;
  is_pinned: boolean;
}

interface SidebarProject {
  id: string;
  name: string;
  kind: string;
  color: string | null;
}

interface NavItem {
  href: string;
  label: string;
  icon: React.ComponentType<{ className?: string }>;
  matchHrefs?: string[];
  badgeCount?: number;
}

const PRIMARY_NAV: NavItem[] = [
  { href: '/hari-ini', label: 'Hari Ini', icon: Calendar, matchHrefs: ['/hari-ini'] },
  { href: '/jadwal', label: 'Agenda & Jadwal', icon: CalendarDays, matchHrefs: ['/jadwal'] },
  { href: '/tugas', label: 'Tugas & Papan', icon: CheckSquare, matchHrefs: ['/tugas'] },
];

const FINANCE_NAV: NavItem[] = [
  { href: '/transaksi', label: 'Transaksi', icon: Receipt, matchHrefs: ['/transaksi'] },
  { href: '/anggaran', label: 'Anggaran', icon: PieChart, matchHrefs: ['/anggaran'] },
  { href: '/tagihan', label: 'Tagihan', icon: CalendarClock, matchHrefs: ['/tagihan'] },
  { href: '/tabungan', label: 'Tabungan', icon: Target, matchHrefs: ['/tabungan'] },
  { href: '/akun', label: 'Akun', icon: Wallet, matchHrefs: ['/akun'] },
  { href: '/ringkasan', label: 'Ringkasan', icon: BarChart3, matchHrefs: ['/ringkasan'] },
];

const ROUTE_TITLES: Array<{ prefix: string; title: string }> = [
  { prefix: '/hari-ini', title: 'Hari Ini' },
  { prefix: '/jadwal', title: 'Agenda & Jadwal' },
  { prefix: '/tugas', title: 'Tugas & Papan' },
  { prefix: '/transaksi', title: 'Keuangan / Transaksi' },
  { prefix: '/anggaran', title: 'Keuangan / Anggaran' },
  { prefix: '/tagihan', title: 'Keuangan / Tagihan' },
  { prefix: '/tabungan', title: 'Keuangan / Tabungan' },
  { prefix: '/akun', title: 'Keuangan / Akun' },
  { prefix: '/ringkasan', title: 'Keuangan / Ringkasan' },
  { prefix: '/proyek', title: 'Kegiatan & Proyek' },
  { prefix: '/inbox', title: 'Inbox Draft' },
  { prefix: '/kategori', title: 'Kategori & Aturan' },
  { prefix: '/pengaturan', title: 'Pengaturan' },
];

function DashboardShellContent({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const supabase = useMemo(() => createClient(), []);
  const { privacyMode, formatAmount, togglePrivacyMode, hasPin, lockSessionNow } = usePrivacyMode();
  const { accent, setAccent } = useThemeAccent();

  const [isDark, setIsDark] = useState(false);
  const [collapsed, setCollapsed] = useState(false);
  const [financeOpen, setFinanceOpen] = useState(true);
  const [mobileDrawerOpen, setMobileDrawerOpen] = useState(false);
  const [commandOpen, setCommandOpen] = useState(false);
  const [addMenuOpen, setAddMenuOpen] = useState(false);
  const [accentMenuOpen, setAccentMenuOpen] = useState(false);
  const [txModalOpen, setTxModalOpen] = useState(false);
  const [txPrefill, setTxPrefill] = useState<TransactionPrefill | null>(null);
  const [wsMenuOpen, setWsMenuOpen] = useState(false);

  const [workspaces, setWorkspaces] = useState<WorkspaceOption[]>([]);
  const [activeWorkspaceId, setActiveWorkspaceId] = useState<string | null>(null);
  const [savedViews, setSavedViews] = useState<SidebarSavedView[]>([]);
  const [projects, setProjects] = useState<SidebarProject[]>([]);
  const [draftCount, setDraftCount] = useState(0);
  const [sidebarLiquidBalance, setSidebarLiquidBalance] = useState<number | null>(null);
  const [sidebarActiveTasks, setSidebarActiveTasks] = useState<number | null>(null);

  const addMenuRef = useRef<HTMLDivElement>(null);
  const accentMenuRef = useRef<HTMLDivElement>(null);
  const wsMenuRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const savedTheme = localStorage.getItem('orbit_theme');
    const isDarkMode =
      savedTheme === 'dark' ||
      (!savedTheme && window.matchMedia('(prefers-color-scheme: dark)').matches);
    setIsDark(isDarkMode);
    document.documentElement.classList.toggle('dark', isDarkMode);

    const savedCollapsed = localStorage.getItem('orbit_sidebar_collapsed') === 'true';
    setCollapsed(savedCollapsed);
  }, []);

  // Global Ctrl+K / Cmd+K listener
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        setCommandOpen((prev) => !prev);
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      const target = e.target as Node;
      if (addMenuRef.current && !addMenuRef.current.contains(target)) {
        setAddMenuOpen(false);
      }
      if (accentMenuRef.current && !accentMenuRef.current.contains(target)) {
        setAccentMenuOpen(false);
      }
      if (wsMenuRef.current && !wsMenuRef.current.contains(target)) {
        setWsMenuOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  useEffect(() => {
    const onOpenTxModal = (e: Event) => {
      const detail = (e as CustomEvent<{ prefill?: TransactionPrefill }>).detail;
      setTxPrefill(detail?.prefill ?? null);
      setTxModalOpen(true);
    };
    window.addEventListener('orbit:open-new-transaction', onOpenTxModal);
    return () => window.removeEventListener('orbit:open-new-transaction', onOpenTxModal);
  }, []);

  // Close mobile drawer on route change
  useEffect(() => {
    setMobileDrawerOpen(false);
  }, [pathname]);

  const loadWorkspaceContext = useCallback(async () => {
    try {
      const { data: memberRows, error: memberErr } = await supabase
        .from('workspace_members')
        .select('workspace_id, workspaces(id, name, type)')
        .limit(10);

      let wsList: WorkspaceOption[] = [];
      if (!memberErr && Array.isArray(memberRows)) {
        wsList = memberRows
          .map((row) => {
            const r = row as unknown as {
              workspace_id: string;
              workspaces?: { id: string; name: string; type?: string } | null;
            };
            return {
              id: r.workspace_id,
              name: r.workspaces?.name || 'Orbit / Pribadi',
              type: r.workspaces?.type,
            };
          })
          .filter((w) => Boolean(w.id));
      } else if (!memberErr && memberRows && !Array.isArray(memberRows)) {
        const singleRow = memberRows as unknown as { workspace_id?: string };
        if (singleRow.workspace_id) {
          wsList = [{ id: singleRow.workspace_id, name: 'Orbit / Pribadi' }];
        }
      }

      if (wsList.length === 0) {
        const { data: singleMember } = await supabase
          .from('workspace_members')
          .select('workspace_id')
          .limit(1)
          .maybeSingle();
        if (singleMember?.workspace_id) {
          wsList = [{ id: singleMember.workspace_id, name: 'Orbit / Pribadi' }];
        }
      }

      if (wsList.length === 0) return;

      setWorkspaces(wsList);
      const savedWsId = localStorage.getItem('orbit_active_workspace_id');
      const resolvedWs =
        wsList.find((w) => w.id === savedWsId)?.id || wsList[0].id;
      setActiveWorkspaceId(resolvedWs);

      const [viewsRes, projRes, draftRes, balRes, activeTasksRes] = await Promise.all([
        supabase
          .from('saved_views')
          .select('id, name, scope, is_pinned')
          .eq('workspace_id', resolvedWs)
          .is('deleted_at', null)
          .order('is_pinned', { ascending: false })
          .order('sort_order', { ascending: true })
          .limit(8),
        supabase
          .from('projects')
          .select('id, name, kind, color')
          .eq('workspace_id', resolvedWs)
          .is('deleted_at', null)
          .eq('archived', false)
          .order('updated_at', { ascending: false })
          .limit(5),
        supabase
          .from('transactions')
          .select('*', { count: 'exact', head: true })
          .eq('workspace_id', resolvedWs)
          .eq('status', 'draft')
          .is('deleted_at', null),
        supabase
          .from('v_account_balances')
          .select('balance, is_liquid')
          .eq('workspace_id', resolvedWs),
        supabase
          .from('tasks')
          .select('*', { count: 'exact', head: true })
          .eq('workspace_id', resolvedWs)
          .neq('status', 'done')
          .is('deleted_at', null),
      ]);

      if (!viewsRes.error && Array.isArray(viewsRes.data)) {
        const pinnedOrTop = viewsRes.data as SidebarSavedView[];
        const pinned = pinnedOrTop.filter((v) => v.is_pinned);
        setSavedViews(pinned.length > 0 ? pinned : pinnedOrTop.slice(0, 4));
      } else {
        setSavedViews([]);
      }

      if (!projRes.error && Array.isArray(projRes.data)) {
        setProjects(projRes.data as SidebarProject[]);
      }

      if (!draftRes.error && typeof draftRes.count === 'number') {
        setDraftCount(draftRes.count);
      }

      if (!balRes.error && Array.isArray(balRes.data)) {
        const total = balRes.data
          .filter((b) => (b as { is_liquid?: boolean }).is_liquid)
          .reduce((sum, b) => sum + Number((b as { balance?: number }).balance || 0), 0);
        setSidebarLiquidBalance(total);
      }

      if (!activeTasksRes.error && typeof activeTasksRes.count === 'number') {
        setSidebarActiveTasks(activeTasksRes.count);
      }
    } catch {
      // Abaikan kegagalan metadata sidebar agar halaman utama tetap dapat dirender
    }
  }, [supabase]);

  useEffect(() => {
    loadWorkspaceContext();
    const refreshSidebar = () => {
      loadWorkspaceContext();
    };
    window.addEventListener('orbit:saved-views-updated', refreshSidebar);
    window.addEventListener('orbit:transaction-created', refreshSidebar);
    window.addEventListener('orbit:projects-updated', refreshSidebar);
    return () => {
      window.removeEventListener('orbit:saved-views-updated', refreshSidebar);
      window.removeEventListener('orbit:transaction-created', refreshSidebar);
      window.removeEventListener('orbit:projects-updated', refreshSidebar);
    };
  }, [loadWorkspaceContext]);

  const toggleTheme = useCallback(() => {
    setIsDark((prev) => {
      const nextDark = !prev;
      document.documentElement.classList.toggle('dark', nextDark);
      localStorage.setItem('orbit_theme', nextDark ? 'dark' : 'light');
      return nextDark;
    });
  }, []);

  const toggleSidebar = () => {
    const next = !collapsed;
    setCollapsed(next);
    localStorage.setItem('orbit_sidebar_collapsed', String(next));
  };

  const handleSelectWorkspace = (wsId: string) => {
    setActiveWorkspaceId(wsId);
    localStorage.setItem('orbit_active_workspace_id', wsId);
    setWsMenuOpen(false);
    window.dispatchEvent(new CustomEvent('orbit:workspace-changed', { detail: { workspaceId: wsId } }));
    loadWorkspaceContext();
    router.refresh();
  };

  const handleSignOut = async () => {
    await supabase.auth.signOut();
    router.push('/login');
    router.refresh();
  };

  const activeWorkspace = workspaces.find((w) => w.id === activeWorkspaceId);
  const workspaceLabel = activeWorkspace?.name || 'Orbit / Pribadi';

  const isPathActive = (item: NavItem) => {
    if (item.matchHrefs) {
      return item.matchHrefs.some((h) => pathname === h || pathname.startsWith(`${h}/`));
    }
    return pathname === item.href || pathname.startsWith(`${item.href}/`);
  };

  const isFinanceActive = FINANCE_NAV.some((item) => isPathActive(item));
  const currentRouteTitle =
    ROUTE_TITLES.find((r) => pathname === r.prefix || pathname.startsWith(`${r.prefix}/`))?.title ||
    'Orbit';

  const managementNav: NavItem[] = [
    { href: '/inbox', label: 'Inbox Draft', icon: Inbox, matchHrefs: ['/inbox'], badgeCount: draftCount },
    { href: '/kategori', label: 'Kategori & Aturan', icon: Tags, matchHrefs: ['/kategori'] },
    { href: '/pengaturan', label: 'Pengaturan', icon: Settings, matchHrefs: ['/pengaturan'] },
  ];

  const renderSidebarBody = (isCompact: boolean, isMobileDrawer = false) => (
    <div className="flex h-full flex-col justify-between bg-sidebar text-foreground">
      {/* Header Workspace Switcher */}
      <div className="shrink-0 border-b border-border px-2.5 py-2 space-y-2">
        <div className="flex items-center justify-between gap-1.5 min-h-11">
          <div className="relative flex-1 min-w-0" ref={!isMobileDrawer ? wsMenuRef : undefined}>
            {workspaces.length > 1 && !isCompact ? (
              <button
                type="button"
                onClick={() => setWsMenuOpen((prev) => !prev)}
                className="min-h-11 w-full flex items-center justify-between gap-2 rounded-md px-1.5 py-1 text-left hover:bg-hover transition-colors"
                aria-expanded={wsMenuOpen}
                aria-label="Pilih workspace"
              >
                <div className="flex items-center gap-2 min-w-0">
                  <Image
                    src="/orbit-icon.png"
                    alt="Logo Orbit"
                    width={28}
                    height={28}
                    className="h-7 w-7 rounded-md border border-border object-cover shrink-0"
                  />
                  <div className="min-w-0 leading-tight">
                    <span className="block truncate text-xs font-bold tracking-tight text-foreground">
                      {workspaceLabel}
                    </span>
                    <span className="block truncate text-[11px] text-muted-foreground">
                      Workspace Orbit
                    </span>
                  </div>
                </div>
                <ChevronsUpDown className="h-3.5 w-3.5 shrink-0 text-muted-foreground" />
              </button>
            ) : (
              <Link
                href="/hari-ini"
                className={cn(
                  'min-h-11 flex items-center gap-2 rounded-md px-1.5 py-1',
                  isCompact ? 'justify-center px-0' : ''
                )}
              >
                <Image
                  src="/orbit-icon.png"
                  alt="Logo Orbit"
                  width={28}
                  height={28}
                  className="h-7 w-7 rounded-md border border-border object-cover shrink-0"
                />
                {!isCompact && (
                  <div className="min-w-0 leading-tight">
                    <span className="block truncate text-xs font-bold tracking-tight text-foreground">
                      {workspaceLabel}
                    </span>
                    <span className="block truncate text-[11px] text-muted-foreground">
                      Kerja &amp; Keuangan
                    </span>
                  </div>
                )}
              </Link>
            )}

            {wsMenuOpen && workspaces.length > 1 && !isCompact && (
              <div
                role="menu"
                aria-label="Daftar workspace"
                className="absolute left-0 right-0 top-12 z-50 rounded-md border border-border bg-card p-1 shadow-peek"
              >
                {workspaces.map((ws) => (
                  <button
                    key={ws.id}
                    type="button"
                    role="menuitem"
                    onClick={() => handleSelectWorkspace(ws.id)}
                    className={cn(
                      'min-h-11 w-full flex items-center justify-between rounded-sm px-2.5 py-1.5 text-xs font-medium text-left',
                      ws.id === activeWorkspaceId
                        ? 'bg-primary-subtle text-primary font-semibold'
                        : 'text-foreground hover:bg-hover'
                    )}
                  >
                    <span className="truncate">{ws.name}</span>
                  </button>
                ))}
              </div>
            )}
          </div>

          {!isMobileDrawer && !isCompact && (
            <button
              type="button"
              onClick={toggleSidebar}
              aria-label="Lipat sidebar"
              title="Lipat sidebar"
              className="inline-flex h-11 w-9 shrink-0 items-center justify-center rounded-md text-muted-foreground hover:bg-hover hover:text-foreground transition-colors"
            >
              <ChevronLeft className="h-4 w-4" />
            </button>
          )}
          {isMobileDrawer && (
            <button
              type="button"
              onClick={() => setMobileDrawerOpen(false)}
              aria-label="Tutup menu navigasi"
              className="inline-flex h-11 w-11 shrink-0 items-center justify-center rounded-md text-muted-foreground hover:bg-hover hover:text-foreground"
            >
              <X className="h-5 w-5" />
            </button>
          )}
        </div>

        {!isMobileDrawer && isCompact && (
          <button
            type="button"
            onClick={toggleSidebar}
            aria-label="Bentangkan sidebar"
            title="Bentangkan sidebar"
            className="min-h-11 w-full flex items-center justify-center rounded-md text-muted-foreground hover:bg-hover hover:text-foreground transition-colors"
          >
            <ChevronRight className="h-4 w-4" />
          </button>
        )}

        {/* Tombol Shortcut Command Palette */}
        <button
          type="button"
          onClick={() => {
            setMobileDrawerOpen(false);
            setCommandOpen(true);
          }}
          title={isCompact ? 'Cari atau Lompat (Ctrl+K)' : undefined}
          aria-label="Cari atau Lompat (Ctrl+K)"
          className={cn(
            'min-h-11 w-full flex items-center rounded-md border border-border bg-card px-2.5 text-xs text-muted-foreground hover:bg-hover hover:text-foreground transition-colors',
            isCompact ? 'justify-center px-0' : 'justify-between gap-2'
          )}
        >
          <span className="flex items-center gap-2 min-w-0">
            <Search className="h-3.5 w-3.5 shrink-0" aria-hidden="true" />
            {!isCompact && <span className="truncate">Cari atau Lompat...</span>}
          </span>
          {!isCompact && (
            <kbd className="rounded-xs border border-border bg-subtle px-1.5 py-0.5 font-mono text-[10px] font-medium text-muted-foreground">
              Ctrl+K
            </kbd>
          )}
        </button>
      </div>

      {/* Daftar Navigasi Scrollable */}
      <nav aria-label="Menu workspace" className="flex-1 overflow-y-auto px-2 py-2.5 space-y-4">
        {/* Live Workspace Pulse Widget (Cross-Module Sync) */}
        {!isCompact && (sidebarLiquidBalance !== null || sidebarActiveTasks !== null) && (
          <div className="mx-1 rounded-xl border border-primary/25 bg-gradient-to-br from-primary-subtle/55 via-card to-card p-2.5 space-y-2 shadow-card">
            <div className="flex items-center justify-between text-[10px] font-bold uppercase tracking-wider text-primary">
              <span>Live Pulse</span>
              <span className="inline-flex h-1.5 w-1.5 rounded-full bg-income" />
            </div>
            {sidebarLiquidBalance !== null && (
              <Link
                href="/akun"
                className="block rounded-md px-1.5 py-1 hover:bg-hover transition-colors"
              >
                <span className="block text-[10px] text-muted-foreground">Saldo Likuid</span>
                <span className="block text-xs font-bold tabular-nums text-foreground truncate">
                  {formatAmount(sidebarLiquidBalance)}
                </span>
              </Link>
            )}
            <div className="grid grid-cols-2 gap-1.5 pt-0.5">
              <Link
                href="/tugas"
                className="rounded-md border border-border bg-card/80 px-2 py-1 hover:border-primary/40 transition-colors"
              >
                <span className="block text-[10px] text-muted-foreground">Tugas</span>
                <span className="text-xs font-bold tabular-nums text-foreground">
                  {sidebarActiveTasks ?? 0} aktif
                </span>
              </Link>
              <Link
                href="/inbox"
                className="rounded-md border border-border bg-card/80 px-2 py-1 hover:border-primary/40 transition-colors"
              >
                <span className="block text-[10px] text-muted-foreground">Inbox</span>
                <span className="text-xs font-bold tabular-nums text-foreground">
                  {draftCount} draft
                </span>
              </Link>
            </div>
          </div>
        )}

        {/* 1. Utama */}
        <div className="space-y-0.5">
          {!isCompact && (
            <div className="px-2 pb-1 text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
              Utama
            </div>
          )}
          {PRIMARY_NAV.map((item) => {
            const Icon = item.icon;
            const active = isPathActive(item);
            return (
              <Link
                key={item.href}
                href={item.href}
                title={isCompact ? item.label : undefined}
                aria-label={isCompact ? item.label : undefined}
                aria-current={active ? 'page' : undefined}
                className={cn(
                  'min-h-[44px] flex items-center gap-2.5 rounded-md px-2.5 py-2 text-sm font-medium transition-all duration-150',
                  isCompact ? 'justify-center px-0' : 'justify-start',
                  active
                    ? 'border-l-2 border-primary bg-gradient-to-r from-primary-subtle to-primary-subtle/35 text-primary font-semibold'
                    : 'text-muted-foreground hover:bg-hover hover:text-foreground'
                )}
              >
                <Icon className={cn('h-4 w-4 shrink-0', active ? 'text-primary' : 'text-muted-foreground')} />
                {!isCompact && <span className="truncate">{item.label}</span>}
              </Link>
            );
          })}
        </div>

        {/* 2. Keuangan */}
        <div className="space-y-0.5">
          {!isCompact ? (
            <button
              type="button"
              onClick={() => setFinanceOpen((prev) => !prev)}
              aria-expanded={financeOpen}
              className="min-h-8 w-full flex items-center justify-between px-2 py-1 text-[11px] font-semibold uppercase tracking-wider text-muted-foreground hover:text-foreground"
            >
              <span>Keuangan</span>
              <ChevronDown
                className={cn(
                  'h-3.5 w-3.5 transition-transform duration-150',
                  financeOpen ? 'rotate-0' : '-rotate-90'
                )}
              />
            </button>
          ) : (
            <div className="h-px bg-border mx-1 my-1" />
          )}

          {(isCompact || financeOpen) && (
            <div className="space-y-0.5">
              {FINANCE_NAV.map((item) => {
                const Icon = item.icon;
                const active = isPathActive(item);
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    title={isCompact ? item.label : undefined}
                    aria-label={isCompact ? item.label : undefined}
                    aria-current={active ? 'page' : undefined}
                    className={cn(
                      'min-h-[44px] flex items-center gap-2.5 rounded-sm px-2.5 py-2 text-sm font-medium transition-colors duration-150',
                      isCompact ? 'justify-center px-0' : 'justify-start',
                      active
                        ? 'bg-primary-subtle text-primary font-semibold'
                        : 'text-muted-foreground hover:bg-hover hover:text-foreground'
                    )}
                  >
                    <Icon className={cn('h-4 w-4 shrink-0', active ? 'text-primary' : 'text-muted-foreground')} />
                    {!isCompact && <span className="truncate">{item.label}</span>}
                  </Link>
                );
              })}
            </div>
          )}
        </div>

        {/* 3. Saved Views */}
        {!isCompact && (
          <div className="space-y-0.5">
            <div className="flex items-center justify-between px-2 pb-1">
              <span className="text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
                Saved Views
              </span>
              <Link
                href="/tugas"
                className="text-[11px] font-medium text-primary hover:underline"
              >
                Kelola
              </Link>
            </div>
            {savedViews.length === 0 ? (
              <div className="px-2.5 py-1.5 text-xs text-muted-foreground">
                Belum ada view disematkan
              </div>
            ) : (
              savedViews.map((view) => (
                <Link
                  key={view.id}
                  href={getSavedViewHref(view)}
                  className="min-h-[44px] flex items-center gap-2.5 rounded-sm px-2.5 py-2 text-xs font-medium text-muted-foreground hover:bg-hover hover:text-foreground transition-colors"
                >
                  <Bookmark className="h-3.5 w-3.5 shrink-0 text-primary" aria-hidden="true" />
                  <span className="truncate">{view.name}</span>
                </Link>
              ))
            )}
          </div>
        )}

        {/* 4. Kegiatan */}
        <div className="space-y-0.5">
          {!isCompact && (
            <div className="px-2 pb-1 text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
              Kegiatan
            </div>
          )}
          <Link
            href="/proyek"
            title={isCompact ? 'Semua Kegiatan & Proyek' : undefined}
            aria-label={isCompact ? 'Semua Kegiatan & Proyek' : undefined}
            aria-current={pathname.startsWith('/proyek') ? 'page' : undefined}
            className={cn(
              'min-h-[44px] flex items-center gap-2.5 rounded-sm px-2.5 py-2 text-sm font-medium transition-colors duration-150',
              isCompact ? 'justify-center px-0' : 'justify-start',
              pathname.startsWith('/proyek')
                ? 'bg-primary-subtle text-primary font-semibold'
                : 'text-muted-foreground hover:bg-hover hover:text-foreground'
            )}
          >
            <Briefcase
              className={cn(
                'h-4 w-4 shrink-0',
                pathname.startsWith('/proyek') ? 'text-primary' : 'text-muted-foreground'
              )}
            />
            {!isCompact && <span className="truncate">Semua Kegiatan</span>}
          </Link>

          {!isCompact &&
            projects.map((proj) => (
              <Link
                key={proj.id}
                href={`/tugas?project=${proj.id}`}
                className="min-h-[44px] flex items-center justify-between gap-2 rounded-sm px-2.5 py-1.5 text-xs font-medium text-muted-foreground hover:bg-hover hover:text-foreground transition-colors"
              >
                <span className="flex items-center gap-2 min-w-0">
                  <Folder className="h-3.5 w-3.5 shrink-0 text-muted-foreground" aria-hidden="true" />
                  <span className="truncate">{proj.name}</span>
                </span>
                <KindBadge kind={proj.kind} className="shrink-0" />
              </Link>
            ))}
        </div>

        {/* 5. Pengelolaan */}
        <div className="space-y-0.5">
          {!isCompact && (
            <div className="px-2 pb-1 text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
              Pengelolaan
            </div>
          )}
          {managementNav.map((item) => {
            const Icon = item.icon;
            const active = isPathActive(item);
            return (
              <Link
                key={item.href}
                href={item.href}
                title={isCompact ? item.label : undefined}
                aria-label={isCompact ? item.label : undefined}
                aria-current={active ? 'page' : undefined}
                className={cn(
                  'min-h-[44px] flex items-center justify-between gap-2 rounded-sm px-2.5 py-2 text-sm font-medium transition-colors duration-150',
                  isCompact ? 'justify-center px-0' : '',
                  active
                    ? 'bg-primary-subtle text-primary font-semibold'
                    : 'text-muted-foreground hover:bg-hover hover:text-foreground'
                )}
              >
                <span className="flex items-center gap-2.5 min-w-0">
                  <Icon className={cn('h-4 w-4 shrink-0', active ? 'text-primary' : 'text-muted-foreground')} />
                  {!isCompact && <span className="truncate">{item.label}</span>}
                </span>
                {!isCompact && typeof item.badgeCount === 'number' && item.badgeCount > 0 && (
                  <span className="rounded-xs border border-warning-border bg-warning-subtle px-1.5 py-0.5 text-[11px] font-semibold text-warning tabular-nums">
                    {item.badgeCount}
                  </span>
                )}
              </Link>
            );
          })}
        </div>
      </nav>

      {/* Footer Sticky */}
      <div className="shrink-0 border-t border-border p-2 space-y-1">
        <button
          type="button"
          onClick={togglePrivacyMode}
          aria-pressed={privacyMode}
          title={privacyMode ? 'Tampilkan Nominal' : 'Sembunyikan Nominal'}
          aria-label={privacyMode ? 'Nonaktifkan Mode Privasi Nominal' : 'Aktifkan Mode Privasi Nominal'}
          className={cn(
            'min-h-[44px] w-full flex items-center gap-2.5 rounded-sm px-2.5 py-2 text-sm font-medium transition-colors',
            privacyMode
              ? 'bg-primary-subtle text-primary'
              : 'text-muted-foreground hover:bg-hover hover:text-foreground',
            isCompact ? 'justify-center px-0' : 'justify-start'
          )}
        >
          {privacyMode ? (
            <EyeOff className="h-4 w-4 shrink-0" />
          ) : (
            <Eye className="h-4 w-4 shrink-0" />
          )}
          {!isCompact && (
            <span>{privacyMode ? 'Mode Privasi: Aktif' : 'Mode Privasi'}</span>
          )}
        </button>

        {hasPin && (
          <button
            type="button"
            onClick={lockSessionNow}
            title="Kunci Sesi"
            aria-label="Kunci Sesi Sekarang"
            className={cn(
              'min-h-[44px] w-full flex items-center gap-2.5 rounded-sm px-2.5 py-2 text-sm font-medium text-muted-foreground hover:bg-hover hover:text-foreground transition-colors',
              isCompact ? 'justify-center px-0' : 'justify-start'
            )}
          >
            <Lock className="h-4 w-4 shrink-0" />
            {!isCompact && <span>Kunci Sesi</span>}
          </button>
        )}

        <button
          type="button"
          onClick={toggleTheme}
          title={isDark ? 'Mode Terang' : 'Mode Gelap'}
          aria-label={isDark ? 'Aktifkan Mode Terang' : 'Aktifkan Mode Gelap'}
          className={cn(
            'min-h-[44px] w-full flex items-center gap-2.5 rounded-sm px-2.5 py-2 text-sm font-medium text-muted-foreground hover:bg-hover hover:text-foreground transition-colors',
            isCompact ? 'justify-center px-0' : 'justify-start'
          )}
        >
          {isDark ? <Sun className="h-4 w-4 shrink-0" /> : <Moon className="h-4 w-4 shrink-0" />}
          {!isCompact && <span>{isDark ? 'Mode Terang' : 'Mode Gelap'}</span>}
        </button>

        <button
          type="button"
          onClick={handleSignOut}
          title="Keluar"
          aria-label="Keluar dari akun"
          className={cn(
            'min-h-[44px] w-full flex items-center gap-2.5 rounded-sm px-2.5 py-2 text-sm font-medium text-expense hover:bg-expense-subtle transition-colors',
            isCompact ? 'justify-center px-0' : 'justify-start'
          )}
        >
          <LogOut className="h-4 w-4 shrink-0" />
          {!isCompact && <span>Keluar</span>}
        </button>
      </div>
    </div>
  );

  return (
    <div className="min-h-screen bg-background text-foreground">
      {/* Sidebar Desktop Collapsible (240px / 56px) */}
      <aside
        aria-label="Navigasi utama desktop"
        className={cn(
          'print:hidden hidden md:flex fixed inset-y-0 left-0 z-40 flex-col border-r border-border bg-sidebar transition-all duration-150 select-none',
          collapsed ? 'w-14' : 'w-60'
        )}
      >
        {renderSidebarBody(collapsed, false)}
      </aside>

      {/* Mobile Drawer (< 768px) */}
      {mobileDrawerOpen && (
        <div
          className="print:hidden md:hidden fixed inset-0 z-50 flex bg-slate-950/60"
          role="dialog"
          aria-modal="true"
          aria-label="Menu workspace mobile"
          onMouseDown={(e) => {
            if (e.target === e.currentTarget) setMobileDrawerOpen(false);
          }}
        >
          <div className="h-full w-72 max-w-[85vw] border-r border-border bg-sidebar shadow-peek">
            {renderSidebarBody(false, true)}
          </div>
        </div>
      )}

      {/* Main Content Wrapper */}
      <div
        className={cn(
          'flex min-h-screen flex-col transition-all duration-150 pb-20 md:pb-0 print:pl-0 print:pb-0',
          collapsed ? 'md:pl-14' : 'md:pl-60'
        )}
      >
        {/* Top Bar Tipis 48px (Glass Command Center) */}
        <header className="print:hidden sticky top-0 z-30 flex h-12 items-center justify-between gap-3 border-b border-border orbit-glass px-3 md:px-6">
          <div className="flex items-center gap-2 min-w-0">
            <button
              type="button"
              onClick={() => setMobileDrawerOpen(true)}
              aria-label="Buka menu workspace"
              className="md:hidden inline-flex h-11 w-11 shrink-0 items-center justify-center rounded-md text-foreground hover:bg-hover"
            >
              <Menu className="h-5 w-5" />
            </button>
            <Link
              href="/hari-ini"
              aria-label="Ke halaman Hari Ini"
              className="md:hidden inline-flex h-11 w-11 items-center justify-center rounded-md shrink-0 hover:bg-hover transition-colors"
            >
              <Image
                src="/orbit-icon.png"
                alt="Logo Orbit"
                width={26}
                height={26}
                className="h-6 w-6 rounded-sm border border-border object-cover"
              />
            </Link>
            <span className="truncate text-sm font-semibold text-foreground">
              {currentRouteTitle}
            </span>
          </div>

          <div className="flex items-center gap-1.5 shrink-0">
            <button
              type="button"
              onClick={() => setCommandOpen(true)}
              aria-label="Buka pencarian cepat (Ctrl+K)"
              className="min-h-[44px] min-w-[44px] inline-flex items-center justify-center gap-2 rounded-md border border-border bg-card px-2.5 text-xs font-medium text-muted-foreground hover:bg-hover hover:text-foreground transition-colors"
            >
              <Search className="h-4 w-4 shrink-0" aria-hidden="true" />
              <span className="hidden sm:inline">Cari</span>
              <kbd className="hidden md:inline rounded-xs border border-border bg-subtle px-1.5 py-0.5 font-mono text-[10px]">
                Ctrl+K
              </kbd>
            </button>

            <div className="relative shrink-0" ref={addMenuRef}>
              <Button
                variant="primary"
                size="sm"
                aria-label="Menu tambah cepat"
                aria-haspopup="menu"
                aria-expanded={addMenuOpen}
                onClick={() => setAddMenuOpen((prev) => !prev)}
                className="min-h-[44px] min-w-[44px] px-3"
              >
                <Plus className="h-4 w-4" aria-hidden="true" />
                <span className="hidden sm:inline">Tambah</span>
                <ChevronDown className="hidden sm:inline h-3.5 w-3.5" aria-hidden="true" />
              </Button>

              {addMenuOpen && (
                <div
                  role="menu"
                  aria-label="Pilih item untuk ditambahkan"
                  className="absolute right-0 mt-1.5 w-52 rounded-md border border-border bg-card p-1 shadow-peek z-50"
                >
                  <button
                    type="button"
                    role="menuitem"
                    onClick={() => {
                      setAddMenuOpen(false);
                      if (pathname === '/tugas') {
                        window.dispatchEvent(new CustomEvent('orbit:open-new-task'));
                      } else {
                        router.push('/tugas?new=1');
                      }
                    }}
                    className="min-h-[44px] w-full flex items-center gap-2.5 rounded-sm px-3 py-2 text-left text-sm font-medium text-foreground hover:bg-hover"
                  >
                    <CheckSquare className="h-4 w-4 text-primary" />
                    <span>Tugas Baru</span>
                  </button>
                  <button
                    type="button"
                    role="menuitem"
                    onClick={() => {
                      setAddMenuOpen(false);
                      setTxModalOpen(true);
                    }}
                    className="min-h-[44px] w-full flex items-center gap-2.5 rounded-sm px-3 py-2 text-left text-sm font-medium text-foreground hover:bg-hover"
                  >
                    <Receipt className="h-4 w-4 text-primary" />
                    <span>Transaksi Baru</span>
                  </button>
                  <Link
                    href="/jadwal"
                    role="menuitem"
                    onClick={() => setAddMenuOpen(false)}
                    className="min-h-[44px] w-full flex items-center gap-2.5 rounded-sm px-3 py-2 text-sm font-medium text-foreground hover:bg-hover"
                  >
                    <CalendarDays className="h-4 w-4 text-primary" />
                    <span>Jadwal Baru</span>
                  </Link>
                </div>
              )}
            </div>

            <button
              type="button"
              onClick={togglePrivacyMode}
              data-testid="privacy-mode-toggle"
              aria-pressed={privacyMode}
              aria-label={
                privacyMode
                  ? 'Nonaktifkan Mode Privasi Nominal'
                  : 'Aktifkan Mode Privasi Nominal'
              }
              title={privacyMode ? 'Tampilkan Nominal' : 'Mode Privasi Nominal'}
              className={cn(
                'inline-flex h-11 w-11 items-center justify-center rounded-md border transition-colors',
                privacyMode
                  ? 'border-primary bg-primary-subtle text-primary'
                  : 'border-border bg-card text-muted-foreground hover:bg-hover hover:text-foreground'
              )}
            >
              {privacyMode ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
            </button>

            <div className="relative shrink-0" ref={accentMenuRef}>
              <button
                type="button"
                onClick={() => setAccentMenuOpen((prev) => !prev)}
                aria-label="Pilih tema aksen interaktif"
                aria-expanded={accentMenuOpen}
                title="Tema Aksen Orbit"
                className="inline-flex h-11 items-center justify-center gap-2 rounded-md border border-primary/30 bg-primary-subtle/45 px-3 text-xs font-semibold text-foreground hover:bg-primary-subtle/75 transition-colors"
              >
                <span
                  className="h-3 w-3 rounded-full ring-2 ring-primary/30"
                  style={{
                    backgroundColor: isDark
                      ? ORBIT_ACCENTS.find((a) => a.id === accent)?.swatchDark
                      : ORBIT_ACCENTS.find((a) => a.id === accent)?.swatchLight,
                  }}
                />
                <span className="hidden lg:inline">
                  {ORBIT_ACCENTS.find((a) => a.id === accent)?.label || 'Tema'}
                </span>
                <Palette className="h-3.5 w-3.5 text-primary" />
              </button>

              {accentMenuOpen && (
                <div
                  role="menu"
                  aria-label="Pilih warna aksen tema"
                  className="absolute right-0 mt-1.5 w-48 rounded-lg border border-border bg-card p-1.5 shadow-peek z-50"
                >
                  <div className="px-2 py-1 text-[11px] font-semibold uppercase tracking-wider text-muted-foreground">
                    Tema Aksen
                  </div>
                  {ORBIT_ACCENTS.map((item) => {
                    const active = item.id === accent;
                    return (
                      <button
                        key={item.id}
                        type="button"
                        role="menuitemradio"
                        aria-checked={active}
                        onClick={() => {
                          setAccent(item.id);
                          setAccentMenuOpen(false);
                        }}
                        className={cn(
                          'min-h-[40px] w-full flex items-center justify-between gap-2 rounded-md px-2.5 py-1.5 text-xs font-medium transition-colors',
                          active ? 'bg-primary-subtle text-primary font-semibold' : 'text-foreground hover:bg-hover'
                        )}
                      >
                        <span className="flex items-center gap-2">
                          <span
                            className="h-3.5 w-3.5 rounded-full border border-black/10"
                            style={{ backgroundColor: isDark ? item.swatchDark : item.swatchLight }}
                          />
                          <span>{item.label}</span>
                        </span>
                        {active && <Check className="h-3.5 w-3.5 text-primary" />}
                      </button>
                    );
                  })}
                </div>
              )}
            </div>

            <button
              type="button"
              onClick={toggleTheme}
              aria-label={isDark ? 'Aktifkan Mode Terang' : 'Aktifkan Mode Gelap'}
              title={isDark ? 'Mode Terang' : 'Mode Gelap'}
              className="hidden sm:inline-flex h-11 w-11 items-center justify-center rounded-md border border-border bg-card text-muted-foreground hover:bg-hover hover:text-foreground transition-colors"
            >
              {isDark ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
            </button>
          </div>
        </header>

        {/* Area Konten Halaman */}
        <main className="flex-1 w-full max-w-6xl mx-auto p-4 md:p-6 print:max-w-none print:p-0">
          {children}
        </main>
      </div>

      {/* Bottom Navigation Bar Mobile (< 768px): 4 Tab (Hari Ini, Agenda, Tugas, Uang) */}
      <nav
        aria-label="Navigasi bawah mobile"
        className="print:hidden md:hidden fixed inset-x-0 bottom-0 z-40 flex h-16 items-center justify-around border-t border-border orbit-glass px-1"
      >
        <Link
          href="/hari-ini"
          aria-current={pathname === '/hari-ini' ? 'page' : undefined}
          className={cn(
            'min-h-[44px] flex-1 flex flex-col items-center justify-center gap-0.5 rounded-md px-2 py-1 text-[11px] font-medium transition-colors',
            pathname === '/hari-ini'
              ? 'text-primary font-semibold'
              : 'text-muted-foreground hover:text-foreground'
          )}
        >
          <Calendar className="h-5 w-5" />
          <span>Hari Ini</span>
        </Link>

        <Link
          href="/jadwal"
          aria-current={pathname.startsWith('/jadwal') ? 'page' : undefined}
          className={cn(
            'min-h-[44px] flex-1 flex flex-col items-center justify-center gap-0.5 rounded-md px-2 py-1 text-[11px] font-medium transition-colors',
            pathname.startsWith('/jadwal')
              ? 'text-primary font-semibold'
              : 'text-muted-foreground hover:text-foreground'
          )}
        >
          <CalendarDays className="h-5 w-5" />
          <span>Agenda</span>
        </Link>

        <Link
          href="/tugas"
          aria-current={pathname.startsWith('/tugas') ? 'page' : undefined}
          className={cn(
            'min-h-[44px] flex-1 flex flex-col items-center justify-center gap-0.5 rounded-md px-2 py-1 text-[11px] font-medium transition-colors',
            pathname.startsWith('/tugas')
              ? 'text-primary font-semibold'
              : 'text-muted-foreground hover:text-foreground'
          )}
        >
          <CheckSquare className="h-5 w-5" />
          <span>Tugas</span>
        </Link>

        <Link
          href="/transaksi"
          aria-current={isFinanceActive ? 'page' : undefined}
          className={cn(
            'min-h-[44px] flex-1 flex flex-col items-center justify-center gap-0.5 rounded-md px-2 py-1 text-[11px] font-medium transition-colors',
            isFinanceActive
              ? 'text-primary font-semibold'
              : 'text-muted-foreground hover:text-foreground'
          )}
        >
          <Wallet className="h-5 w-5" />
          <span>Uang</span>
        </Link>
      </nav>

      {/* Command Palette Global (Ctrl+K) */}
      <CommandPalette
        open={commandOpen}
        onOpenChange={setCommandOpen}
        workspaceId={activeWorkspaceId}
        isDark={isDark}
        onToggleTheme={toggleTheme}
        onOpenNewTransaction={() => setTxModalOpen(true)}
      />

      {/* Modal Tambah Transaksi Global */}
      <TransactionFormModal
        open={txModalOpen}
        onClose={() => {
          setTxModalOpen(false);
          setTxPrefill(null);
        }}
        workspaceId={activeWorkspaceId}
        prefill={txPrefill}
        onSuccess={() => {
          window.dispatchEvent(new CustomEvent('orbit:transaction-created'));
          router.refresh();
        }}
      />
    </div>
  );
}

export function DashboardShell({ children }: { children: React.ReactNode }) {
  return (
    <ThemeAccentProvider>
      <PrivacyProvider>
        <DashboardShellContent>{children}</DashboardShellContent>
      </PrivacyProvider>
    </ThemeAccentProvider>
  );
}

export function Navigation() {
  return null;
}
