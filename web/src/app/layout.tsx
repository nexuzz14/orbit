import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'Orbit',
  description: 'Pusat kendali pribadi untuk uang, tugas, dan jadwal',
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="id" suppressHydrationWarning>
      <body className="antialiased min-h-screen">{children}</body>
    </html>
  );
}
