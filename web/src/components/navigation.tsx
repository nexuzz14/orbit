'use client';

import React, { useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import {
  Briefcase,
  Calendar,
  CalendarClock,
  CalendarDays,
  CheckSquare,
  ChevronDown,
  ChevronLeft,
  ChevronRight,
  Grid,
  Inbox,
  LayoutDashboard,
  LogOut,
  Moon,
  PieChart,
  Plus,
  Receipt,
  Search,
  Shield,
  Sun,
  Tags,
  Target,
  Wallet,
} from 'lucide-react';
import { createClient } from '@/lib/supabase/client';
import { Button, cn, Dialog, Input } from '@/components/ui';
import { TransactionFormModal } from '@/components/transaction-form-modal';

interface NavLinkItem {
  href: string;
  label: string;
  icon: React.ComponentType<{ className?: string }>;
}

interface NavGroup {
  id: 'hari-ini' | 'agenda' | 'uang' | 'lainnya';
  label: string;
  items: NavLinkItem[];
}

const NAV_GROUPS: NavGroup[] = [
  {
    id: 'hari-ini',
    label: 'Hari Ini',
    items: [{ href: '/hari-ini', label: 'Hari Ini', icon: Calendar }],
  },
  {
    id: 'agenda',
    label: 'Agenda',
    items: [
      { href: '/jadwal', label: 'Jadwal', icon: CalendarDays },
      { href: '/tugas', label: 'Tugas', icon: CheckSquare },
    ],
  },
  {
    id: 'uang',
    label: 'Uang',
    items: [
      { href: '/transaksi', label: 'Transaksi', icon: Receipt },
      { href: '/akun', label: 'Akun', icon: Wallet },
      { href: '/ringkasan', label: 'Ringkasan', icon: LayoutDashboard },
      { href: '/inbox', label: 'Inbox', icon: Inbox },
      { href: '/anggaran', label: 'Anggaran', icon: PieChart },
      { href: '/tagihan', label: 'Tagihan', icon: CalendarClock },
      { href: '/tabungan', label: 'Target', icon: Target },
    ],
  },
  {
    id: 'lainnya',
    label: 'Lainnya',
    items: [
      { href: '/proyek', label: 'Kegiatan & Piutang', icon: Briefcase },
      { href: '/kategori', label: 'Kategori & Aturan', icon: Tags },
      { href: '/pengaturan', label: 'Keamanan & Pengaturan', icon: Shield },
    ],
  },
];

export function DashboardShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const supabase = createClient();

  const [isDark, setIsDark] = useState(false);
  const [collapsed, setCollapsed] = useState(false);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchFocused, setSearchFocused] = useState(false);
  const [addMenuOpen, setAddMenuOpen] = useState(false);
  const [txModalOpen, setTxModalOpen] = useState(false);
  const [mobileMoreOpen, setMobileMoreOpen] = useState(false);

  const addMenuRef = useRef<HTMLDivElement>(null);

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

  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (addMenuRef.current && !addMenuRef.current.contains(e.target as Node)) {
        setAddMenuOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const toggleTheme = () => {
    const nextDark = !isDark;
    setIsDark(nextDark);
    document.documentElement.classList.toggle('dark', nextDark);
    localStorage.setItem('orbit_theme', nextDark ? 'dark' : 'light');
  };

  const toggleSidebar = () => {
    const next = !collapsed;
    setCollapsed(next);
    localStorage.setItem('orbit_sidebar_collapsed', String(next));
  };

  const handleSignOut = async () => {
    await supabase.auth.signOut();
    router.push('/login');
    router.refresh();
  };

  const allItems = NAV_GROUPS.flatMap((g) => g.items);
  const filteredSearchItems = searchQuery.trim()
    ? allItems.filter((item) =>
        item.label.toLowerCase().includes(searchQuery.trim().toLowerCase())
      )
    : [];

  const isAgendaActive = pathname.startsWith('/jadwal') || pathname.startsWith('/tugas');
  const isUangActive =
    pathname.startsWith('/transaksi') ||
    pathname.startsWith('/akun') ||
    pathname.startsWith('/ringkasan') ||
    pathname.startsWith('/inbox') ||
    pathname.startsWith('/anggaran') ||
    pathname.startsWith('/tagihan') ||
    pathname.startsWith('/tabungan');
  const isLainnyaActive =
    pathname.startsWith('/proyek') ||
    pathname.startsWith('/kategori') ||
    pathname.startsWith('/pengaturan');

  return (
    <div className="min-h-screen bg-background text-foreground">
      {/* Sidebar Kiri Desktop (4 Grup, Dapat Dilipat) */}
      <aside
        aria-label="Navigasi utama desktop"
        className={cn(
          'hidden md:flex fixed inset-y-0 left-0 z-40 flex-col justify-between border-r border-border bg-card transition-all duration-150 select-none',
          collapsed ? 'w-16' : 'w-64'
        )}
      >
        <div className="flex h-16 items-center justify-between border-b border-border px-3 shrink-0">
          <Link
            href="/hari-ini"
            className={cn(
              'flex items-center gap-2.5 rounded-md focus-visible:ring-2 focus-visible:ring-primary',
              collapsed ? 'mx-auto' : 'px-1'
            )}
          >
            <img
              src="/orbit-icon.png"
              alt="Logo Orbit"
              className="h-8 w-8 rounded-md object-cover border border-border shrink-0"
            />
            {!collapsed && (
              <div className="leading-tight">
                <span className="block text-sm font-bold tracking-tight text-foreground">
                  Orbit
                </span>
                <span className="block text-xs text-muted-foreground">
                  Kerja &amp; Keuangan
                </span>
              </div>
            )}
          </Link>
          {!collapsed && (
            <Button
              variant="ghost"
              size="icon"
              onClick={toggleSidebar}
              aria-label="Lipat sidebar"
              title="Lipat sidebar"
            >
              <ChevronLeft className="h-4 w-4" />
            </Button>
          )}
        </div>

        {collapsed && (
          <div className="flex justify-center border-b border-border py-2 shrink-0">
            <Button
              variant="ghost"
              size="icon"
              onClick={toggleSidebar}
              aria-label="Bentangkan sidebar"
              title="Bentangkan sidebar"
            >
              <ChevronRight className="h-4 w-4" />
            </Button>
          </div>
        )}

        {/* Daftar 4 Grup Navigasi */}
        <nav className="flex-1 overflow-y-auto px-2 py-3 space-y-4">
          {NAV_GROUPS.map((group) => (
            <div key={group.id}>
              {!collapsed && (
                <div className="px-2.5 pb-1 text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                  {group.label}
                </div>
              )}
              <div className="space-y-0.5">
                {group.items.map((item) => {
                  const Icon = item.icon;
                  const active = pathname === item.href || pathname.startsWith(`${item.href}/`);
                  return (
                    <Link
                      key={item.href}
                      href={item.href}
                      title={collapsed ? item.label : undefined}
                      aria-label={collapsed ? item.label : undefined}
                      aria-current={active ? 'page' : undefined}
                      className={cn(
                        'min-h-11 flex items-center gap-3 rounded-md px-2.5 py-2 text-sm font-medium transition-colors duration-150',
                        collapsed ? 'justify-center' : 'justify-start',
                        active
                          ? 'bg-primary-subtle text-primary font-semibold'
                          : 'text-muted-foreground hover:bg-subtle hover:text-foreground'
                      )}
                    >
                      <Icon
                        className={cn(
                          'h-4 w-4 shrink-0',
                          active ? 'text-primary' : 'text-muted-foreground'
                        )}
                      />
                      {!collapsed && <span className="truncate">{item.label}</span>}
                    </Link>
                  );
                })}
              </div>
            </div>
          ))}
        </nav>

        {/* Footer Sidebar */}
        <div className="border-t border-border p-2 space-y-1 shrink-0">
          <button
            type="button"
            onClick={toggleTheme}
            title={isDark ? 'Mode Terang' : 'Mode Gelap'}
            aria-label={isDark ? 'Aktifkan Mode Terang' : 'Aktifkan Mode Gelap'}
            className={cn(
              'min-h-11 w-full flex items-center gap-3 rounded-md px-2.5 py-2 text-sm font-medium text-muted-foreground hover:bg-subtle hover:text-foreground transition-colors duration-150',
              collapsed ? 'justify-center' : 'justify-start'
            )}
          >
            {isDark ? <Sun className="h-4 w-4 shrink-0" /> : <Moon className="h-4 w-4 shrink-0" />}
            {!collapsed && <span>{isDark ? 'Mode Terang' : 'Mode Gelap'}</span>}
          </button>

          <button
            type="button"
            onClick={handleSignOut}
            title="Keluar"
            aria-label="Keluar dari akun"
            className={cn(
              'min-h-11 w-full flex items-center gap-3 rounded-md px-2.5 py-2 text-sm font-medium text-expense hover:bg-expense-subtle transition-colors duration-150',
              collapsed ? 'justify-center' : 'justify-start'
            )}
          >
            <LogOut className="h-4 w-4 shrink-0" />
            {!collapsed && <span>Keluar</span>}
          </button>
        </div>
      </aside>

      {/* Wrapper Konten Utama */}
      <div
        className={cn(
          'flex min-h-screen flex-col transition-all duration-150 pb-20 md:pb-0',
          collapsed ? 'md:pl-16' : 'md:pl-64'
        )}
      >
        {/* Top Bar Global (Pencarian & Menu + Tambah) */}
        <header className="sticky top-0 z-30 flex h-16 items-center justify-between gap-3 border-b border-border bg-card/95 px-4 md:px-8 backdrop-blur-sm">
          <div className="flex items-center gap-3 flex-1 max-w-md">
            <Link href="/hari-ini" className="md:hidden flex items-center gap-2 shrink-0">
              <img
                src="/orbit-icon.png"
                alt="Logo Orbit"
                className="h-8 w-8 rounded-md object-cover border border-border"
              />
            </Link>

            {/* Pencarian Cepat */}
            <div className="relative flex-1">
              <Search
                aria-hidden="true"
                className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground"
              />
              <Input
                type="search"
                aria-label="Cari halaman, transaksi, atau tugas"
                placeholder="Cari menu atau fitur..."
                value={searchQuery}
                onFocus={() => setSearchFocused(true)}
                onBlur={() => setTimeout(() => setSearchFocused(false), 180)}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="pl-9 h-11"
              />
              {searchFocused && filteredSearchItems.length > 0 && (
                <div
                  role="listbox"
                  aria-label="Hasil pencarian navigasi"
                  className="absolute left-0 right-0 top-12 z-50 rounded-md border border-border bg-card p-1 shadow-lg"
                >
                  {filteredSearchItems.map((item) => {
                    const Icon = item.icon;
                    return (
                      <Link
                        key={item.href}
                        href={item.href}
                        onClick={() => setSearchQuery('')}
                        className="min-h-11 flex items-center gap-2.5 rounded-sm px-3 py-2 text-sm text-foreground hover:bg-subtle"
                      >
                        <Icon className="h-4 w-4 text-primary" />
                        <span>{item.label}</span>
                      </Link>
                    );
                  })}
                </div>
              )}
            </div>
          </div>

          {/* Aksi Kanan Top Bar: Menu "+ Tambah" & Toggle Tema */}
          <div className="flex items-center gap-2">
            <div className="relative" ref={addMenuRef}>
              <Button
                variant="primary"
                size="default"
                aria-haspopup="menu"
                aria-expanded={addMenuOpen}
                onClick={() => setAddMenuOpen((prev) => !prev)}
              >
                <Plus className="h-4 w-4" aria-hidden="true" />
                <span>Tambah</span>
                <ChevronDown className="h-3.5 w-3.5" aria-hidden="true" />
              </Button>

              {addMenuOpen && (
                <div
                  role="menu"
                  aria-label="Pilih item untuk ditambahkan"
                  className="absolute right-0 mt-1.5 w-52 rounded-md border border-border bg-card p-1 shadow-lg z-50"
                >
                  <button
                    type="button"
                    role="menuitem"
                    onClick={() => {
                      setAddMenuOpen(false);
                      setTxModalOpen(true);
                    }}
                    className="min-h-11 w-full flex items-center gap-2.5 rounded-sm px-3 py-2 text-left text-sm font-medium text-foreground hover:bg-subtle"
                  >
                    <Receipt className="h-4 w-4 text-primary" />
                    <span>Transaksi Baru</span>
                  </button>
                  <Link
                    href="/tugas"
                    role="menuitem"
                    onClick={() => setAddMenuOpen(false)}
                    className="min-h-11 w-full flex items-center gap-2.5 rounded-sm px-3 py-2 text-sm font-medium text-foreground hover:bg-subtle"
                  >
                    <CheckSquare className="h-4 w-4 text-primary" />
                    <span>Tugas Baru</span>
                  </Link>
                  <Link
                    href="/jadwal"
                    role="menuitem"
                    onClick={() => setAddMenuOpen(false)}
                    className="min-h-11 w-full flex items-center gap-2.5 rounded-sm px-3 py-2 text-sm font-medium text-foreground hover:bg-subtle"
                  >
                    <CalendarDays className="h-4 w-4 text-primary" />
                    <span>Jadwal Baru</span>
                  </Link>
                </div>
              )}
            </div>

            <Button
              variant="outline"
              size="icon"
              onClick={toggleTheme}
              aria-label={isDark ? 'Aktifkan Mode Terang' : 'Aktifkan Mode Gelap'}
              title={isDark ? 'Mode Terang' : 'Mode Gelap'}
            >
              {isDark ? <Sun className="h-4 w-4" /> : <Moon className="h-4 w-4" />}
            </Button>
          </div>
        </header>

        {/* Area Konten Halaman */}
        <main className="flex-1 w-full max-w-6xl mx-auto p-4 md:p-6">
          {children}
        </main>
      </div>

      {/* Bottom Navigation Bar Mobile (< 768px, 4 Tab Seragam dengan App) */}
      <nav
        aria-label="Navigasi bawah mobile"
        className="md:hidden fixed inset-x-0 bottom-0 z-40 flex h-16 items-center justify-around border-t border-border bg-card px-2"
      >
        <Link
          href="/hari-ini"
          aria-current={pathname === '/hari-ini' ? 'page' : undefined}
          className={cn(
            'min-h-11 min-w-16 flex flex-col items-center justify-center gap-1 rounded-md px-3 py-1 text-xs font-medium transition-colors',
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
          aria-current={isAgendaActive ? 'page' : undefined}
          className={cn(
            'min-h-11 min-w-16 flex flex-col items-center justify-center gap-1 rounded-md px-3 py-1 text-xs font-medium transition-colors',
            isAgendaActive
              ? 'text-primary font-semibold'
              : 'text-muted-foreground hover:text-foreground'
          )}
        >
          <CalendarDays className="h-5 w-5" />
          <span>Agenda</span>
        </Link>

        <Link
          href="/transaksi"
          aria-current={isUangActive ? 'page' : undefined}
          className={cn(
            'min-h-11 min-w-16 flex flex-col items-center justify-center gap-1 rounded-md px-3 py-1 text-xs font-medium transition-colors',
            isUangActive
              ? 'text-primary font-semibold'
              : 'text-muted-foreground hover:text-foreground'
          )}
        >
          <Wallet className="h-5 w-5" />
          <span>Uang</span>
        </Link>

        <button
          type="button"
          onClick={() => setMobileMoreOpen(true)}
          aria-expanded={mobileMoreOpen}
          className={cn(
            'min-h-11 min-w-16 flex flex-col items-center justify-center gap-1 rounded-md px-3 py-1 text-xs font-medium transition-colors',
            isLainnyaActive
              ? 'text-primary font-semibold'
              : 'text-muted-foreground hover:text-foreground'
          )}
        >
          <Grid className="h-5 w-5" />
          <span>Lainnya</span>
        </button>
      </nav>

      {/* Sheet Menu "Lainnya" pada Mobile */}
      <Dialog
        open={mobileMoreOpen}
        onClose={() => setMobileMoreOpen(false)}
        title="Menu Lainnya"
        description="Kegiatan, aturan otomatisasi, dan pengaturan akun"
      >
        <div className="space-y-1">
          {NAV_GROUPS.find((g) => g.id === 'lainnya')?.items.map((item) => {
            const Icon = item.icon;
            return (
              <Link
                key={item.href}
                href={item.href}
                onClick={() => setMobileMoreOpen(false)}
                className="min-h-11 flex items-center gap-3 rounded-md px-3 py-2.5 text-sm font-medium text-foreground hover:bg-subtle"
              >
                <Icon className="h-4 w-4 text-primary" />
                <span>{item.label}</span>
              </Link>
            );
          })}
          <div className="border-t border-border pt-2 mt-2">
            <button
              type="button"
              onClick={handleSignOut}
              className="min-h-11 w-full flex items-center gap-3 rounded-md px-3 py-2.5 text-sm font-medium text-expense hover:bg-expense-subtle"
            >
              <LogOut className="h-4 w-4" />
              <span>Keluar dari Akun</span>
            </button>
          </div>
        </div>
      </Dialog>

      {/* Modal Tambah Transaksi Global */}
      <TransactionFormModal
        open={txModalOpen}
        onClose={() => setTxModalOpen(false)}
        onSuccess={() => {
          window.dispatchEvent(new CustomEvent('orbit:transaction-created'));
          router.refresh();
        }}
      />
    </div>
  );
}

export function Navigation() {
  return null;
}
