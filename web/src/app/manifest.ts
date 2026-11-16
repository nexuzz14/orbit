import type { MetadataRoute } from 'next';

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: 'Orbit - Productivity & Finance',
    short_name: 'Orbit',
    description: 'Pusat kendali pribadi untuk keuangan, tugas, dan jadwal terpadu.',
    start_url: '/hari-ini',
    scope: '/',
    display: 'standalone',
    orientation: 'portrait-primary',
    background_color: '#FFFFFF',
    theme_color: '#0284C7',
    lang: 'id',
    icons: [
      {
        src: '/orbit-icon-192.png',
        sizes: '192x192',
        type: 'image/png',
        purpose: 'any',
      },
      {
        src: '/orbit-icon.png',
        sizes: '2000x2000',
        type: 'image/png',
        purpose: 'any',
      },
    ],
    shortcuts: [
      {
        name: 'Hari Ini',
        short_name: 'Hari Ini',
        description: 'Ringkasan jadwal, tugas, dan keuangan hari ini',
        url: '/hari-ini',
        icons: [
          {
            src: '/orbit-icon-192.png',
            sizes: '192x192',
            type: 'image/png',
          },
        ],
      },
      {
        name: 'Tambah Transaksi',
        short_name: 'Transaksi',
        description: 'Catat pemasukan atau pengeluaran baru',
        url: '/transaksi?quick=new',
        icons: [
          {
            src: '/orbit-icon-192.png',
            sizes: '192x192',
            type: 'image/png',
          },
        ],
      },
      {
        name: 'Tambah Tugas',
        short_name: 'Tugas',
        description: 'Buat tugas atau tenggat baru',
        url: '/tugas?quick=new',
        icons: [
          {
            src: '/orbit-icon-192.png',
            sizes: '192x192',
            type: 'image/png',
          },
        ],
      },
      {
        name: 'Inbox Draft',
        short_name: 'Inbox',
        description: 'Tinjau draf transaksi dan ekstrak teks struk',
        url: '/inbox',
        icons: [
          {
            src: '/orbit-icon-192.png',
            sizes: '192x192',
            type: 'image/png',
          },
        ],
      },
    ],
  };
}
