'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import {
  Sun,
  Moon,
  LogOut,
  Calendar,
  CalendarDays,
  CheckSquare,
  Briefcase,
  Receipt,
  Wallet,
  Tags,
  LayoutDashboard,
  Inbox,
  Shield,
  PieChart,
  CalendarClock,
  Target,
  Menu,
  X,
} from 'lucide-react';
import { useEffect, useState } from 'react';
import { createClient } from '@/lib/supabase/client';

export function Navigation() {
  const pathname = usePathname();
  const router = useRouter();
  const [isDark, setIsDark] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);
  const supabase = createClient();

  useEffect(() => {
    const isDarkMode =
      localStorage.getItem('orbit_theme') === 'dark' ||
      (!localStorage.getItem('orbit_theme') &&
        window.matchMedia('(prefers-color-scheme: dark)').matches);
    setIsDark(isDarkMode);
    if (isDarkMode) {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
  }, []);

  const toggleTheme = () => {
    const nextDark = !isDark;
    setIsDark(nextDark);
    if (nextDark) {
      document.documentElement.classList.add('dark');
      localStorage.setItem('orbit_theme', 'dark');
    } else {
      document.documentElement.classList.remove('dark');
      localStorage.setItem('orbit_theme', 'light');
    }
  };

  const handleSignOut = async () => {
    await supabase.auth.signOut();
    router.push('/login');
    router.refresh();
  };

  const navItems = [
    { href: '/hari-ini', label: 'Hari Ini', icon: Calendar },
    { href: '/jadwal', label: 'Jadwal', icon: CalendarDays },
    { href: '/tugas', label: 'Tugas', icon: CheckSquare },
    { href: '/proyek', label: 'Proyek & Kerja', icon: Briefcase },
    { href: '/transaksi', label: 'Transaksi', icon: Receipt },
    { href: '/anggaran', label: 'Anggaran', icon: PieChart },
    { href: '/tagihan', label: 'Tagihan Rutin', icon: CalendarClock },
    { href: '/tabungan', label: 'Tabungan & Split', icon: Target },
    { href: '/akun', label: 'Akun', icon: Wallet },
    { href: '/kategori', label: 'Kategori', icon: Tags },
    { href: '/ringkasan', label: 'Ringkasan', icon: LayoutDashboard },
    { href: '/inbox', label: 'Inbox', icon: Inbox },
    { href: '/pengaturan', label: 'Keamanan & Sesi', icon: Shield },
  ];

  return (
    <>
      {/* Mobile Top Header */}
      <header className="md:hidden sticky top-0 z-30 flex items-center justify-between px-4 py-3 border-b border-border bg-card/95 backdrop-blur-md">
        <Link href="/hari-ini" className="flex items-center gap-2.5">
          <img
            src="/orbit-icon.png"
            alt="Orbit"
            className="w-8 h-8 rounded-lg shadow-md object-cover"
          />
          <div>
            <div className="font-extrabold text-sm tracking-wider leading-none">
              <span className="orbit-gradient-text">ORBIT</span>
            </div>
            <div className="text-[10px] text-muted-foreground mt-0.5">
              Productivity &amp; Finance
            </div>
          </div>
        </Link>
        <div className="flex items-center gap-1.5">
          <button
            onClick={toggleTheme}
            type="button"
            aria-label="Ganti Tema"
            className="p-2 text-muted-foreground hover:text-foreground rounded-lg transition-colors"
          >
            {isDark ? <Sun className="w-4 h-4 text-amber-400" /> : <Moon className="w-4 h-4 text-indigo-500" />}
          </button>
          <button
            onClick={() => setMobileOpen(!mobileOpen)}
            type="button"
            aria-label="Buka Menu"
            className="p-2 text-muted-foreground hover:text-foreground rounded-lg transition-colors"
          >
            {mobileOpen ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
          </button>
        </div>
      </header>

      {/* Mobile Backdrop */}
      {mobileOpen && (
        <div
          onClick={() => setMobileOpen(false)}
          className="fixed inset-0 bg-black/60 z-40 md:hidden backdrop-blur-sm"
        />
      )}

      {/* Locked Fixed Sidebar */}
      <aside
        className={`orbit-sidebar-fixed border-r border-border bg-card ${
          mobileOpen ? 'sidebar-open' : 'sidebar-closed'
        }`}
        style={{
          position: 'fixed',
          top: 0,
          bottom: 0,
          left: 0,
          width: '16rem',
          height: '100vh',
          zIndex: 40,
        }}
      >
        {/* Top Orbit Brand Header */}
        <div className="h-16 px-4 border-b border-border/80 flex items-center justify-between shrink-0 bg-gradient-to-r from-sky-500/10 via-indigo-500/10 to-purple-500/10">
          <Link href="/hari-ini" className="flex items-center gap-3 group">
            <div className="relative">
              <div className="absolute -inset-0.5 rounded-xl bg-gradient-to-r from-sky-400 via-indigo-500 to-purple-500 opacity-70 blur-sm group-hover:opacity-100 transition-opacity" />
              <img
                src="/orbit-icon.png"
                alt="Orbit"
                className="relative w-9 h-9 rounded-xl shadow-md object-cover border border-white/20"
              />
            </div>
            <div>
              <span className="font-extrabold text-base tracking-wider block leading-none">
                <span className="orbit-gradient-text">ORBIT</span>
              </span>
              <span className="text-[10px] font-semibold uppercase tracking-widest text-muted-foreground block mt-1">
                Control Center
              </span>
            </div>
          </Link>
          <button
            onClick={() => setMobileOpen(false)}
            className="p-1 text-muted-foreground hover:text-foreground md:hidden"
            aria-label="Tutup Menu"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Non-scrollable Navigation List (Compact and fits 100vh) */}
        <nav className="flex-1 flex flex-col justify-center px-3 py-1 space-y-0.5 overflow-hidden">
          {navItems.map((item) => {
            const Icon = item.icon;
            const active = pathname.startsWith(item.href);
            return (
              <Link
                key={item.href}
                href={item.href}
                onClick={() => setMobileOpen(false)}
                className={`flex items-center justify-between px-3 py-1.5 text-xs rounded-xl transition-all ${
                  active
                    ? 'orbit-gradient-bg text-white font-semibold shadow-md shadow-indigo-500/25'
                    : 'text-muted-foreground hover:bg-muted/70 hover:text-foreground'
                }`}
              >
                <span className="flex items-center gap-2.5 truncate">
                  <Icon
                    className={`w-3.5 h-3.5 shrink-0 ${
                      active ? 'text-white' : 'text-muted-foreground'
                    }`}
                  />
                  <span className="truncate">{item.label}</span>
                </span>
                {active && (
                  <span className="w-1.5 h-1.5 rounded-full bg-white shrink-0" />
                )}
              </Link>
            );
          })}
        </nav>

        {/* Bottom Actions (Always pinned at the bottom) */}
        <div className="p-3 border-t border-border/80 space-y-1 shrink-0 bg-muted/20">
          <button
            onClick={toggleTheme}
            type="button"
            className="w-full flex items-center justify-between px-3 py-1.5 text-xs font-medium text-muted-foreground hover:bg-muted/70 hover:text-foreground rounded-xl transition-colors"
          >
            <span className="flex items-center gap-2">
              {isDark ? (
                <Sun className="w-3.5 h-3.5 text-amber-400" />
              ) : (
                <Moon className="w-3.5 h-3.5 text-indigo-500" />
              )}
              <span>{isDark ? 'Mode Terang' : 'Mode Gelap'}</span>
            </span>
          </button>

          <button
            onClick={handleSignOut}
            type="button"
            className="w-full flex items-center gap-2.5 px-3 py-1.5 text-xs text-red-500 hover:bg-red-500/10 rounded-xl transition-colors font-semibold"
          >
            <LogOut className="w-3.5 h-3.5 shrink-0" />
            <span>Keluar</span>
          </button>
        </div>
      </aside>
    </>
  );
}
