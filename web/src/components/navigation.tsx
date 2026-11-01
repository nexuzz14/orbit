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
      {/* Mobile Top Bar */}
      <header className="md:hidden flex items-center justify-between px-4 py-3 border-b border-border bg-card shrink-0 z-20">
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
          className="fixed inset-0 bg-black/50 z-30 md:hidden backdrop-blur-sm"
        />
      )}

      {/* Sidebar Navigation */}
      <aside
        className={`
          fixed md:static inset-y-0 left-0 z-40 w-64 border-r border-border bg-card
          flex flex-col justify-between shrink-0 select-none overflow-y-auto
          transition-transform duration-200 ease-in-out
          ${mobileOpen ? 'translate-x-0' : '-translate-x-full md:translate-x-0'}
          h-full
        `}
      >
        <div>
          <div className="p-6 border-b border-border hidden md:block">
            <Link href="/hari-ini" className="font-semibold text-lg tracking-tight">
              Orbit
            </Link>
            <div className="text-xs text-muted-foreground mt-1">
              Pusat Kendali Keuangan & Kerja
            </div>
          </div>

          <div className="p-4 border-b border-border flex items-center justify-between md:hidden">
            <span className="font-semibold text-sm">Menu Navigasi</span>
            <button
              onClick={() => setMobileOpen(false)}
              className="p-1 text-muted-foreground hover:text-foreground"
            >
              <X className="w-4 h-4" />
            </button>
          </div>

          <nav className="p-4 space-y-1">
            {navItems.map((item) => {
              const Icon = item.icon;
              const active = pathname.startsWith(item.href);
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  onClick={() => setMobileOpen(false)}
                  className={`flex items-center gap-3 px-3 py-2 text-sm rounded-md transition-colors ${
                    active
                      ? 'bg-muted text-foreground font-medium'
                      : 'text-muted-foreground hover:bg-muted/50 hover:text-foreground'
                  }`}
                >
                  <Icon className="w-4 h-4" />
                  <span>{item.label}</span>
                </Link>
              );
            })}
          </nav>
        </div>

        <div className="p-4 border-t border-border space-y-2">
          <button
            onClick={toggleTheme}
            type="button"
            className="w-full flex items-center justify-between px-3 py-2 text-sm text-muted-foreground hover:bg-muted/50 hover:text-foreground rounded-md transition-colors"
          >
            <span className="flex items-center gap-2">
              {isDark ? <Sun className="w-4 h-4" /> : <Moon className="w-4 h-4" />}
              <span>{isDark ? 'Mode Terang' : 'Mode Gelap'}</span>
            </span>
          </button>

          <button
            onClick={handleSignOut}
            type="button"
            className="w-full flex items-center gap-3 px-3 py-2 text-sm text-expense hover:bg-expense/10 rounded-md transition-colors"
          >
            <LogOut className="w-4 h-4" />
            <span>Keluar</span>
          </button>
        </div>
      </aside>
    </>
  );
}
