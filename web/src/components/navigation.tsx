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
  Shield
} from 'lucide-react';
import { useEffect, useState } from 'react';
import { createClient } from '@/lib/supabase/client';

export function Navigation() {
  const pathname = usePathname();
  const router = useRouter();
  const [isDark, setIsDark] = useState(false);
  const supabase = createClient();

  useEffect(() => {
    const isDarkMode = localStorage.getItem('orbit_theme') === 'dark' ||
      (!localStorage.getItem('orbit_theme') && window.matchMedia('(prefers-color-scheme: dark)').matches);
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
    { href: '/akun', label: 'Akun', icon: Wallet },
    { href: '/kategori', label: 'Kategori', icon: Tags },
    { href: '/ringkasan', label: 'Ringkasan', icon: LayoutDashboard },
    { href: '/inbox', label: 'Inbox', icon: Inbox },
    { href: '/pengaturan', label: 'Keamanan & Sesi', icon: Shield },
  ];

  return (
    <aside className="w-64 border-r border-border bg-card flex flex-col justify-between min-h-screen">
      <div>
        <div className="p-6 border-b border-border">
          <Link href="/hari-ini" className="font-semibold text-lg tracking-tight">
            Orbit
          </Link>
          <div className="text-xs text-muted-foreground mt-1">Pusat Kendali Keuangan & Kerja</div>
        </div>

        <nav className="p-4 space-y-1">
          {navItems.map((item) => {
            const Icon = item.icon;
            const active = pathname.startsWith(item.href);
            return (
              <Link
                key={item.href}
                href={item.href}
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
  );
}
