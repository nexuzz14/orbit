'use client';

import React, { createContext, useCallback, useContext, useEffect, useState } from 'react';

export type OrbitAccentId = 'ocean' | 'emerald' | 'violet' | 'amber';

export interface OrbitAccentMeta {
  id: OrbitAccentId;
  label: string;
  swatchLight: string;
  swatchDark: string;
}

export const ORBIT_ACCENTS: OrbitAccentMeta[] = [
  { id: 'ocean', label: 'Biru Orbit', swatchLight: '#0284c7', swatchDark: '#38bdf8' },
  { id: 'emerald', label: 'Zamrud', swatchLight: '#059669', swatchDark: '#34d399' },
  { id: 'violet', label: 'Violet', swatchLight: '#7c3aed', swatchDark: '#a78bfa' },
  { id: 'amber', label: 'Amber', swatchLight: '#d97706', swatchDark: '#fbbf24' },
];

const ACCENT_STORAGE_KEY = 'orbit_accent';

interface ThemeAccentContextValue {
  accent: OrbitAccentId;
  setAccent: (next: OrbitAccentId) => void;
  cycleAccent: () => void;
}

const ThemeAccentContext = createContext<ThemeAccentContextValue>({
  accent: 'ocean',
  setAccent: () => {},
  cycleAccent: () => {},
});

function isValidAccent(value: string | null): value is OrbitAccentId {
  return value === 'ocean' || value === 'emerald' || value === 'violet' || value === 'amber';
}

export function ThemeAccentProvider({ children }: { children: React.ReactNode }) {
  const [accent, setAccentState] = useState<OrbitAccentId>('ocean');

  useEffect(() => {
    const saved = typeof window !== 'undefined' ? window.localStorage.getItem(ACCENT_STORAGE_KEY) : null;
    const initial: OrbitAccentId = isValidAccent(saved) ? saved : 'ocean';
    setAccentState(initial);
    document.documentElement.setAttribute('data-accent', initial);
  }, []);

  const setAccent = useCallback((next: OrbitAccentId) => {
    setAccentState(next);
    if (typeof window !== 'undefined') {
      window.localStorage.setItem(ACCENT_STORAGE_KEY, next);
    }
    document.documentElement.setAttribute('data-accent', next);
  }, []);

  const cycleAccent = useCallback(() => {
    const idx = ORBIT_ACCENTS.findIndex((a) => a.id === accent);
    const next = ORBIT_ACCENTS[(idx + 1) % ORBIT_ACCENTS.length].id;
    setAccent(next);
  }, [accent, setAccent]);

  return (
    <ThemeAccentContext.Provider value={{ accent, setAccent, cycleAccent }}>
      {children}
    </ThemeAccentContext.Provider>
  );
}

export function useThemeAccent() {
  return useContext(ThemeAccentContext);
}
