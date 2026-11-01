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
      <header className="md:hidden sticky top-0 z-30 flex items-center justify-between px-4 py-3 border-b border-border bg-card/95 backdrop-blur-sm">
        <div>
          <Link href="/hari-ini" className="font-semibold text-base tracking-tight">
            Orbit
          </Link>
          <div className="text-[10px] text-muted-foreground">Pusat Kendali</div>
        </div>
        <div className="flex items-center gap-2">
          <button
            onClick={toggleTheme}
            type="button"
            aria-label="Ganti Tema"
            className="p-2 text-muted-foreground hover:text-foreground rounded-md transition-colors"
          >
            {isDark ? <Sun className="w-4 h-4" /> : <Moon className="w-4 h-4" />}
          </button>
          <button
            onClick={() => setMobileOpen(!mobileOpen)}
            type="button"
            aria-label="Buka Menu"
            className="p-2 text-muted-foreground hover:text-foreground rounded-md transition-colors"
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
        <div className="h-14 px-4 border-b border-border flex items-center justify-between shrink-0">
          <div>
            <Link href="/hari-ini" className="font-semibold text-sm tracking-tight block">
              Orbit
            </Link>
            <div className="text-[10px] text-muted-foreground -mt-0.5">
              Pusat Kendali Keuangan & Kerja
            </div>
          </div>
          <button
            onClick={() => setMobileOpen(false)}
            className="p-1 text-muted-foreground hover:text-foreground md:hidden"
            aria-label="Tutup Menu"
          >
            <X className="w-4 h-4" />
          </button>
        </div>

        {/* Non-scrollable Navigation List (Compact and fits 100vh) */}
        <nav className="flex-1 flex flex-col justify-center px-2 py-1 space-y-0.5 overflow-hidden">
          {navItems.map((item) => {
            const Icon = item.icon;
            const active = pathname.startsWith(item.href);
            return (
              <Link
                key={item.href}
                href={item.href}
                onClick={() => setMobileOpen(false)}
                className={`flex items-center gap-2.5 px-3 py-1.5 text-xs rounded transition-colors ${
                  active
                    ? 'bg-muted text-foreground font-semibold'
                    : 'text-muted-foreground hover:bg-muted/50 hover:text-foreground'
                }`}
              >
                <Icon className="w-3.5 h-3.5 shrink-0" />
                <span className="truncate">{item.label}</span>
              </Link>
            );
          })}
        </nav>

        {/* Bottom Actions (Always pinned at the bottom) */}
        <div className="p-2.5 border-t border-border space-y-1 shrink-0">
          <button
            onClick={toggleTheme}
            type="button"
            className="w-full flex items-center justify-between px-3 py-1.5 text-xs text-muted-foreground hover:bg-muted/50 hover:text-foreground rounded transition-colors"
          >
            <span className="flex items-center gap-2">
              {isDark ? <Sun className="w-3.5 h-3.5" /> : <Moon className="w-3.5 h-3.5" />}
              <span>{isDark ? 'Mode Terang' : 'Mode Gelap'}</span>
            </span>
          </button>

          <button
            onClick={handleSignOut}
            type="button"
            className="w-full flex items-center gap-2.5 px-3 py-1.5 text-xs text-expense hover:bg-expense/10 rounded transition-colors"
          >
            <LogOut className="w-3.5 h-3.5 shrink-0" />
            <span>Keluar</span>
          </button>
        </div>
      </aside>
    </>
  );
}
