import { Navigation } from '@/components/navigation';
import Link from 'next/link';
import { Plus, Receipt, CheckSquare, Inbox, Shield } from 'lucide-react';

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="min-h-screen bg-background">
      <Navigation />
      <div className="orbit-content-wrapper flex flex-col min-h-screen">
        {/* Modern Top Workspace Bar (Desktop) */}
        <div className="hidden md:flex items-center justify-between px-8 py-3 border-b border-border/70 bg-card/60 backdrop-blur-md sticky top-0 z-20">
          <div className="flex items-center gap-2.5">
            <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-semibold bg-emerald-500/10 text-emerald-500 border border-emerald-500/20">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
              Orbit Cloud Synced
            </span>
            <span className="text-xs text-muted-foreground">
              Productivity &amp; Finance Control Center
            </span>
          </div>

          <div className="flex items-center gap-2">
            <Link
              href="/transaksi"
              className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold border border-border bg-card hover:bg-muted transition-colors"
            >
              <Receipt className="w-3.5 h-3.5 text-sky-500" />
              <span>Transaksi</span>
            </Link>
            <Link
              href="/tugas"
              className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold border border-border bg-card hover:bg-muted transition-colors"
            >
              <CheckSquare className="w-3.5 h-3.5 text-indigo-500" />
              <span>Tugas</span>
            </Link>
            <Link
              href="/inbox"
              className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold border border-border bg-card hover:bg-muted transition-colors"
            >
              <Inbox className="w-3.5 h-3.5 text-purple-500" />
              <span>Inbox</span>
            </Link>
            <Link
              href="/pengaturan"
              className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold orbit-btn-primary"
            >
              <Shield className="w-3.5 h-3.5" />
              <span>Akun &amp; 2FA</span>
            </Link>
          </div>
        </div>

        <main className="flex-1 p-4 md:p-8 max-w-7xl w-full mx-auto">
          {children}
        </main>
      </div>
    </div>
  );
}
