'use client';

import { useEffect } from 'react';

export function PwaRegistrar() {
  useEffect(() => {
    if (typeof window === 'undefined' || !('serviceWorker' in navigator)) {
      return;
    }

    const registerSw = async () => {
      try {
        await navigator.serviceWorker.register('/sw.js', { scope: '/' });
      } catch {
        // Biarkan aplikasi tetap berjalan normal apabila pendaftaran SW gagal
      }
    };

    void registerSw();
  }, []);

  return null;
}
