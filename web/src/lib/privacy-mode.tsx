'use client';

import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';
import { Eye, EyeOff, KeyRound, Lock, LogOut, ShieldAlert } from 'lucide-react';
import { createClient } from '@/lib/supabase/client';
import { formatCurrency } from '@/lib/format';
import { Button, Input } from '@/components/ui';

export const PRIVACY_STORAGE_KEYS = {
  mode: 'orbit_privacy_mode',
  pinHash: 'orbit_lock_pin_hash',
  idleMinutes: 'orbit_idle_lock_minutes',
  locked: 'orbit_session_locked',
} as const;

const PRIVACY_SYNC_EVENT = 'orbit:privacy-changed';

export function formatMaskedCurrency(
  amount: number | string,
  currency: string | null = 'IDR',
  privacyMode = false
): string {
  const safeCurrency = currency || 'IDR';
  if (privacyMode) {
    return safeCurrency === 'IDR' ? 'Rp ••••••' : `${safeCurrency} ••••••`;
  }
  const numericAmount = typeof amount === 'number' ? amount : Number(amount);
  const safeAmount = Number.isFinite(numericAmount) ? numericAmount : 0;
  return formatCurrency(safeAmount, safeCurrency);
}

export async function hashPinSha256(pin: string): Promise<string> {
  const normalized = pin.trim();
  if (typeof window === 'undefined' || !window.crypto?.subtle) {
    throw new Error('Web Crypto API tidak tersedia di browser ini.');
  }
  const encoded = new TextEncoder().encode(`orbit-pin-v1:${normalized}`);
  const digest = await window.crypto.subtle.digest('SHA-256', encoded);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

interface PrivacyContextValue {
  privacyMode: boolean;
  setPrivacyMode: (enabled: boolean) => void;
  togglePrivacyMode: () => void;
  formatAmount: (amount: number | string, currency?: string | null) => string;
  hasPin: boolean;
  idleLockMinutes: number;
  setIdleLockMinutes: (minutes: number) => void;
  setLockPin: (newPin: string) => Promise<{ ok: boolean; error?: string }>;
  verifyLockPin: (candidatePin: string) => Promise<boolean>;
  clearLockPin: () => void;
  isLocked: boolean;
  lockSessionNow: () => void;
  unlockWithPin: (candidatePin: string) => Promise<boolean>;
  resetSessionLogin: () => Promise<void>;
}

const DEFAULT_CONTEXT: PrivacyContextValue = {
  privacyMode: false,
  setPrivacyMode: () => {},
  togglePrivacyMode: () => {},
  formatAmount: (amount, currency = 'IDR') =>
    formatMaskedCurrency(amount, currency, false),
  hasPin: false,
  idleLockMinutes: 0,
  setIdleLockMinutes: () => {},
  setLockPin: async () => ({ ok: false, error: 'Provider belum aktif' }),
  verifyLockPin: async () => false,
  clearLockPin: () => {},
  isLocked: false,
  lockSessionNow: () => {},
  unlockWithPin: async () => false,
  resetSessionLogin: async () => {},
};

const PrivacyContext = createContext<PrivacyContextValue>(DEFAULT_CONTEXT);

export function usePrivacyMode(): PrivacyContextValue {
  return useContext(PrivacyContext);
}

export function MaskedCurrency({
  amount,
  currency = 'IDR',
  prefix = '',
  suffix = '',
  className,
}: {
  amount: number | string;
  currency?: string;
  prefix?: string;
  suffix?: string;
  className?: string;
}) {
  const { privacyMode } = usePrivacyMode();
  const display = formatMaskedCurrency(amount, currency, privacyMode);
  return (
    <span className={className} data-privacy-masked={privacyMode ? 'true' : 'false'}>
      {prefix}
      {display}
      {suffix}
    </span>
  );
}

function readLocalStorageItem(key: string): string | null {
  try {
    return window.localStorage.getItem(key);
  } catch {
    return null;
  }
}

function writeLocalStorageItem(key: string, value: string | null) {
  try {
    if (value === null) {
      window.localStorage.removeItem(key);
    } else {
      window.localStorage.setItem(key, value);
    }
    window.dispatchEvent(new CustomEvent(PRIVACY_SYNC_EVENT));
  } catch {
    // Abaikan apabila penyimpanan lokal dibatasi browser
  }
}

export function PrivacyProvider({ children }: { children: React.ReactNode }) {
  const [privacyMode, setPrivacyModeState] = useState(false);
  const [pinHash, setPinHash] = useState<string | null>(null);
  const [idleLockMinutes, setIdleLockMinutesState] = useState(0);
  const [isLocked, setIsLocked] = useState(false);

  const [unlockInput, setUnlockInput] = useState('');
  const [unlockError, setUnlockError] = useState<string | null>(null);
  const [verifyingUnlock, setVerifyingUnlock] = useState(false);

  const lastActivityRef = useRef<number>(Date.now());

  const syncFromStorage = useCallback(() => {
    if (typeof window === 'undefined') return;
    const storedMode = readLocalStorageItem(PRIVACY_STORAGE_KEYS.mode) === 'true';
    const storedHash = readLocalStorageItem(PRIVACY_STORAGE_KEYS.pinHash);
    const storedIdleRaw = readLocalStorageItem(PRIVACY_STORAGE_KEYS.idleMinutes);
    const parsedIdle = storedIdleRaw ? Number.parseInt(storedIdleRaw, 10) : 0;
    const storedLocked =
      Boolean(storedHash) && readLocalStorageItem(PRIVACY_STORAGE_KEYS.locked) === 'true';

    setPrivacyModeState(storedMode);
    setPinHash(storedHash && storedHash.length === 64 ? storedHash : null);
    setIdleLockMinutesState(Number.isFinite(parsedIdle) && parsedIdle > 0 ? parsedIdle : 0);
    setIsLocked(storedLocked);
  }, []);

  useEffect(() => {
    syncFromStorage();
    const handleStorage = (event: StorageEvent) => {
      if (
        !event.key ||
        Object.values(PRIVACY_STORAGE_KEYS).includes(
          event.key as (typeof PRIVACY_STORAGE_KEYS)[keyof typeof PRIVACY_STORAGE_KEYS]
        )
      ) {
        syncFromStorage();
      }
    };
    const handleLocalSync = () => syncFromStorage();

    window.addEventListener('storage', handleStorage);
    window.addEventListener(PRIVACY_SYNC_EVENT, handleLocalSync);
    return () => {
      window.removeEventListener('storage', handleStorage);
      window.removeEventListener(PRIVACY_SYNC_EVENT, handleLocalSync);
    };
  }, [syncFromStorage]);

  const setPrivacyMode = useCallback((enabled: boolean) => {
    setPrivacyModeState(enabled);
    writeLocalStorageItem(PRIVACY_STORAGE_KEYS.mode, enabled ? 'true' : 'false');
  }, []);

  const togglePrivacyMode = useCallback(() => {
    setPrivacyMode(!privacyMode);
  }, [privacyMode, setPrivacyMode]);

  const setIdleLockMinutes = useCallback((minutes: number) => {
    const safeMinutes = Number.isFinite(minutes) && minutes > 0 ? Math.min(240, Math.round(minutes)) : 0;
    setIdleLockMinutesState(safeMinutes);
    writeLocalStorageItem(PRIVACY_STORAGE_KEYS.idleMinutes, String(safeMinutes));
  }, []);

  const setLockPin = useCallback(async (newPin: string) => {
    const cleaned = newPin.trim();
    if (!/^\d{4,8}$/.test(cleaned)) {
      return {
        ok: false,
        error: 'PIN kunci sesi harus berupa 4 sampai 8 digit angka.',
      };
    }
    try {
      const hashed = await hashPinSha256(cleaned);
      setPinHash(hashed);
      writeLocalStorageItem(PRIVACY_STORAGE_KEYS.pinHash, hashed);
      writeLocalStorageItem(PRIVACY_STORAGE_KEYS.locked, 'false');
      setIsLocked(false);
      return { ok: true };
    } catch (err: unknown) {
      return {
        ok: false,
        error: err instanceof Error ? err.message : 'Gagal membuat hash PIN.',
      };
    }
  }, []);

  const verifyLockPin = useCallback(
    async (candidatePin: string): Promise<boolean> => {
      if (!pinHash) return false;
      try {
        const candidateHash = await hashPinSha256(candidatePin);
        return candidateHash === pinHash;
      } catch {
        return false;
      }
    },
    [pinHash]
  );

  const clearLockPin = useCallback(() => {
    setPinHash(null);
    setIsLocked(false);
    writeLocalStorageItem(PRIVACY_STORAGE_KEYS.pinHash, null);
    writeLocalStorageItem(PRIVACY_STORAGE_KEYS.locked, null);
  }, []);

  const lockSessionNow = useCallback(() => {
    if (!pinHash) return;
    setIsLocked(true);
    setUnlockInput('');
    setUnlockError(null);
    writeLocalStorageItem(PRIVACY_STORAGE_KEYS.locked, 'true');
  }, [pinHash]);

  const unlockWithPin = useCallback(
    async (candidatePin: string): Promise<boolean> => {
      const valid = await verifyLockPin(candidatePin);
      if (valid) {
        lastActivityRef.current = Date.now();
        setIsLocked(false);
        setUnlockInput('');
        setUnlockError(null);
        writeLocalStorageItem(PRIVACY_STORAGE_KEYS.locked, 'false');
      }
      return valid;
    },
    [verifyLockPin]
  );

  const resetSessionLogin = useCallback(async () => {
    try {
      const supabase = createClient();
      await supabase.auth.signOut();
    } catch {
      // Lanjutkan pembersihan kunci lokal dan arahkan ulang ke /login
    }
    clearLockPin();
    window.location.href = '/login';
  }, [clearLockPin]);

  // Monitor aktivitas idle untuk mengunci sesi otomatis bila idleLockMinutes > 0
  useEffect(() => {
    if (!pinHash || idleLockMinutes <= 0 || isLocked) {
      return;
    }

    const markActive = () => {
      lastActivityRef.current = Date.now();
    };

    const events: Array<keyof WindowEventMap> = [
      'pointerdown',
      'keydown',
      'mousemove',
      'scroll',
    ];
    for (const ev of events) {
      window.addEventListener(ev, markActive, { passive: true });
    }

    const interval = window.setInterval(() => {
      const idleMs = Date.now() - lastActivityRef.current;
      if (idleMs >= idleLockMinutes * 60 * 1000) {
        lockSessionNow();
      }
    }, 10000);

    return () => {
      for (const ev of events) {
        window.removeEventListener(ev, markActive);
      }
      window.clearInterval(interval);
    };
  }, [pinHash, idleLockMinutes, isLocked, lockSessionNow]);

  const formatAmount = useCallback(
    (amount: number | string, currency: string | null = 'IDR') =>
      formatMaskedCurrency(amount, currency, privacyMode),
    [privacyMode]
  );

  const value = useMemo<PrivacyContextValue>(
    () => ({
      privacyMode,
      setPrivacyMode,
      togglePrivacyMode,
      formatAmount,
      hasPin: Boolean(pinHash),
      idleLockMinutes,
      setIdleLockMinutes,
      setLockPin,
      verifyLockPin,
      clearLockPin,
      isLocked,
      lockSessionNow,
      unlockWithPin,
      resetSessionLogin,
    }),
    [
      privacyMode,
      setPrivacyMode,
      togglePrivacyMode,
      formatAmount,
      pinHash,
      idleLockMinutes,
      setIdleLockMinutes,
      setLockPin,
      verifyLockPin,
      clearLockPin,
      isLocked,
      lockSessionNow,
      unlockWithPin,
      resetSessionLogin,
    ]
  );

  const handleUnlockSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setUnlockError(null);
    setVerifyingUnlock(true);
    try {
      const ok = await unlockWithPin(unlockInput);
      if (!ok) {
        setUnlockError('PIN salah. Periksa kembali PIN kunci sesi lokal Anda.');
      }
    } finally {
      setVerifyingUnlock(false);
    }
  };

  return (
    <PrivacyContext.Provider value={value}>
      {children}

      {isLocked && Boolean(pinHash) && (
        <div
          role="dialog"
          aria-modal="true"
          aria-label="Sesi Orbit Terkunci"
          data-testid="session-lock-overlay"
          className="fixed inset-0 z-50 flex items-center justify-center bg-background p-4"
        >
          <div className="w-full max-w-sm rounded-xl border border-border bg-card p-6 shadow-peek space-y-5">
            <div className="flex items-start gap-3.5">
              <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-lg border border-border bg-primary-subtle text-primary">
                <Lock className="h-5 w-5" />
              </div>
              <div className="space-y-1">
                <h2 className="text-lg font-semibold text-foreground">
                  Sesi Web Terkunci
                </h2>
                <p className="text-xs leading-relaxed text-muted-foreground">
                  Masukkan PIN lokal Anda untuk melanjutkan. Nominal dan data ruang kerja disembunyikan selama layar terkunci.
                </p>
              </div>
            </div>

            <form onSubmit={handleUnlockSubmit} className="space-y-4">
              <div className="space-y-1.5">
                <label
                  htmlFor="orbit-session-unlock-pin"
                  className="text-xs font-medium text-foreground flex items-center gap-1.5"
                >
                  <KeyRound className="h-3.5 w-3.5 text-muted-foreground" />
                  <span>PIN Kunci Sesi</span>
                </label>
                <Input
                  id="orbit-session-unlock-pin"
                  type="password"
                  inputMode="numeric"
                  autoComplete="off"
                  placeholder="4-8 digit PIN"
                  value={unlockInput}
                  onChange={(e) => setUnlockInput(e.target.value)}
                  autoFocus
                  required
                />
              </div>

              {unlockError && (
                <div className="rounded-md border border-expense-border bg-expense-subtle px-3 py-2 text-xs text-expense flex items-center gap-2">
                  <ShieldAlert className="h-4 w-4 shrink-0" />
                  <span>{unlockError}</span>
                </div>
              )}

              <Button
                type="submit"
                className="w-full"
                disabled={verifyingUnlock || unlockInput.trim().length < 4}
              >
                {verifyingUnlock ? 'Memeriksa PIN...' : 'Buka Kunci Sesi'}
              </Button>
            </form>

            <div className="border-t border-border pt-4 flex items-center justify-between gap-2">
              <span className="text-xs text-muted-foreground flex items-center gap-1">
                {privacyMode ? <EyeOff className="h-3.5 w-3.5" /> : <Eye className="h-3.5 w-3.5" />}
                <span>Lupa PIN lokal?</span>
              </span>
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => void resetSessionLogin()}
              >
                <LogOut className="h-3.5 w-3.5" />
                <span>Reset Sesi Login</span>
              </Button>
            </div>
          </div>
        </div>
      )}
    </PrivacyContext.Provider>
  );
}
