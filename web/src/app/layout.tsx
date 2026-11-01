import type { Metadata } from 'next';
import { headers } from 'next/headers';
import './globals.css';

export const dynamic = 'force-dynamic';

export const metadata: Metadata = {
  title: 'Orbit',
  description: 'Pusat kendali pribadi untuk uang, tugas, dan jadwal',
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
        {children}
      </body>
    </html>
  );
}
