import type { Metadata, Viewport } from 'next';
import { headers } from 'next/headers';
import './globals.css';
import { PwaRegistrar } from '@/components/pwa-registrar';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  applicationName: 'Orbit',
  title: 'Orbit — Productivity & Finance',
  description: 'Pusat kendali pribadi untuk uang, tugas, dan jadwal terpadu',
  manifest: '/manifest.webmanifest',
  appleWebApp: {
    capable: true,
    statusBarStyle: 'default',
    title: 'Orbit',
  },
};

export const viewport: Viewport = {
  themeColor: [
    { media: '(prefers-color-scheme: light)', color: '#0284C7' },
    { media: '(prefers-color-scheme: dark)', color: '#38BDF8' },
  ],
};

export default async function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  const nonce = (await headers()).get('x-nonce') || undefined;

  return (
    <html lang="id" suppressHydrationWarning>
      <body className="antialiased min-h-screen" data-nonce={nonce ? 'active' : 'none'}>
        <PwaRegistrar />
        {children}
      </body>
    </html>
  );
}
