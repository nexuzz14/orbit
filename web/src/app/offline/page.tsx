'use client';

import React, { useEffect, useState } from 'react';
import Link from 'next/link';
import { Moon, RefreshCw, ShieldCheck, Sun, WifiOff } from 'lucide-react';
import { Button, Card, CardContent } from '@/components/ui';

export default function OfflinePage() {
  const [isDark, setIsDark] = useState(false);

  useEffect(() => {
    try {
      const saved = window.localStorage.getItem('orbit_theme');
      const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
      const shouldDark = saved ? saved === 'dark' : prefersDark;
      setIsDark(shouldDark);
      document.documentElement.classList.toggle('dark', shouldDark);
    } catch {
      // Abaikan jika penyimpanan lokal tidak tersedia
    }
  }, []);

  const toggleTheme = () => {
    const next = !isDark;
    setIsDark(next);
    document.documentElement.classList.toggle('dark', next);
    try {
      window.localStorage.setItem('orbit_theme', next ? 'dark' : 'light');
    } catch {
      // Abaikan jika localStorage tidak tersedia
    }
  };

  return (
    <div className="min-h-screen bg-background text-foreground flex flex-col items-center justify-center p-4 sm:p-6">
      <div className="w-full max-w-lg space-y-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2.5">
            <img
              src="/orbit-icon-192.png"
              alt="Ikon Orbit"
              width={28}
              height={28}
              className="rounded-md border border-border bg-card"
            />
            <span className="text-sm font-semibold tracking-tight text-foreground">
              Orbit
            </span>
          </div>
          <Button
            type="button"
            variant="outline"
            size="sm"
            onClick={toggleTheme}
            aria-label={isDark ? 'Aktifkan Mode Terang' : 'Aktifkan Mode Gelap'}
          >
            {isDark ? (
              <>
                <Sun className="h-4 w-4" />
                <span>Mode Terang</span>
              </>
            ) : (
              <>
                <Moon className="h-4 w-4" />
                <span>Mode Gelap</span>
              </>
            )}
          </Button>
        </div>

        <Card>
          <CardContent className="p-6 sm:p-8 space-y-5">
            <div className="flex items-start gap-4">
              <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-lg bg-primary-subtle text-primary border border-border">
                <WifiOff className="h-5 w-5" />
              </div>
              <div className="space-y-1.5">
                <h1 className="text-xl font-semibold tracking-tight text-foreground">
                  Anda sedang offline
                </h1>
                <p className="text-sm leading-relaxed text-muted-foreground">
                  Koneksi internet ke server Orbit belum tersambung. Halaman ini tetap tersedia dari cache shell PWA agar Anda dapat mencoba memuat ulang dengan cepat.
                </p>
              </div>
            </div>

            <div className="rounded-lg border border-border bg-subtle p-3.5 text-xs text-muted-foreground flex items-start gap-2.5">
              <ShieldCheck className="h-4 w-4 shrink-0 text-primary mt-0.5" />
              <span>
                Demi keamanan privasi, respons sensitif autentikasi dan saldo tidak disimpan di cache publik Service Worker.
              </span>
            </div>

            <div className="flex flex-wrap items-center gap-2.5 pt-1">
              <Button
                type="button"
                onClick={() => {
                  window.location.reload();
                }}
              >
                <RefreshCw className="h-4 w-4" />
                <span>Coba Muat Ulang</span>
              </Button>
              <Link
                href="/hari-ini"
                className="inline-flex h-10 items-center justify-center rounded-md border border-border bg-card px-4 text-sm font-medium text-foreground hover:bg-hover transition-colors"
              >
                Kembali ke Hari Ini
              </Link>
              <Link
                href="/login"
                className="inline-flex h-10 items-center justify-center rounded-md px-3 text-sm font-medium text-muted-foreground hover:bg-hover hover:text-foreground transition-colors"
              >
                Halaman Masuk
              </Link>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
