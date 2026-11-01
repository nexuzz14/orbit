'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';
import { ShieldCheck, Lock, Mail, Key, UserPlus } from 'lucide-react';

export default function LoginPage() {
  const router = useRouter();
  const supabase = createClient();

  const [mode, setMode] = useState<'login' | 'signup'>('login');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [totpCode, setTotpCode] = useState('');
  const [factorId, setFactorId] = useState<string | null>(null);
  const [mfaChallengeId, setMfaChallengeId] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  useEffect(() => {
    if (typeof window !== 'undefined') {
      const params = new URLSearchParams(window.location.search);
      if (params.get('error') === 'auth_failed') {
        setErrorMessage('Autentikasi gagal atau sesi kedaluwarsa. Silakan coba masuk kembali.');
      }
    }
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setErrorMessage(null);
    setSuccessMessage(null);

    if (mode === 'signup') {
      const { data, error } = await supabase.auth.signUp({
        email,
        password,
        options: {
          emailRedirectTo: `${window.location.origin}/auth/callback`,
        },
      });

      if (error) {
        setErrorMessage(error.message);
        setLoading(false);
        return;
      }

      if (data.session) {
        router.push('/hari-ini');
        router.refresh();
      } else {
        setSuccessMessage(
          'Pendaftaran berhasil! Silakan periksa email untuk verifikasi atau masuk langsung jika auto-confirm aktif.'
        );
        setMode('login');
        setLoading(false);
      }
      return;
    }

    // Mode: login
    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (error) {
      setErrorMessage('Kombinasi email atau kata sandi tidak valid.');
      setLoading(false);
      return;
    }

    // Periksa apakah akun memerlukan verifikasi MFA / TOTP
    const { data: mfaData, error: mfaError } =
      await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
    if (!mfaError && mfaData.nextLevel === 'aal2' && mfaData.currentLevel === 'aal1') {
      const factors = await supabase.auth.mfa.listFactors();
      const totpFactor = factors.data?.totp?.[0];
      if (totpFactor) {
        const challenge = await supabase.auth.mfa.challenge({ factorId: totpFactor.id });
        if (challenge.data) {
          setFactorId(totpFactor.id);
          setMfaChallengeId(challenge.data.id);
          setLoading(false);
          return;
        }
      }
    }

    router.push('/hari-ini');
    router.refresh();
  };

  const handleVerifyTotp = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!factorId || !mfaChallengeId) return;

    setLoading(true);
    setErrorMessage(null);

    const { error } = await supabase.auth.mfa.verify({
      factorId,
      challengeId: mfaChallengeId,
      code: totpCode,
    });

    if (error) {
      setErrorMessage('Kode verifikasi 2FA tidak valid atau sudah kedaluwarsa.');
      setLoading(false);
      return;
    }

    router.push('/hari-ini');
    router.refresh();
  };

  const handleGoogleLogin = async () => {
    setLoading(true);
    setErrorMessage(null);

    const { error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: `${window.location.origin}/auth/callback`,
      },
    });

    if (error) {
      setErrorMessage('Gagal menghubungkan ke layanan Google OAuth.');
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center p-4 bg-background">
      <div className="w-full max-w-md p-8 border border-border bg-card rounded-lg shadow-sm">
        <div className="mb-6 text-center">
          <div className="inline-flex items-center justify-center w-12 h-12 rounded-full bg-muted mb-3 text-foreground">
            {mode === 'login' ? <Lock className="w-6 h-6" /> : <UserPlus className="w-6 h-6" />}
          </div>
          <h1 className="text-xl font-semibold tracking-tight">
            {mode === 'login' ? 'Masuk ke Orbit' : 'Daftar Akun Orbit'}
          </h1>
          <p className="text-sm text-muted-foreground mt-1">
            Pusat kendali keuangan & kerja terpadu
          </p>
        </div>

        {/* Tab Toggle Mode */}
        {!factorId && (
          <div className="flex border border-border rounded-md p-1 mb-6 bg-muted/30">
            <button
              type="button"
              onClick={() => {
                setMode('login');
                setErrorMessage(null);
                setSuccessMessage(null);
              }}
              className={`flex-1 py-1.5 text-xs font-medium rounded transition-colors ${
                mode === 'login'
                  ? 'bg-background text-foreground shadow-sm'
                  : 'text-muted-foreground hover:text-foreground'
              }`}
            >
              Masuk
            </button>
            <button
              type="button"
              onClick={() => {
                setMode('signup');
                setErrorMessage(null);
                setSuccessMessage(null);
              }}
              className={`flex-1 py-1.5 text-xs font-medium rounded transition-colors ${
                mode === 'signup'
                  ? 'bg-background text-foreground shadow-sm'
                  : 'text-muted-foreground hover:text-foreground'
              }`}
            >
              Daftar Akun Baru
            </button>
          </div>
        )}

        {errorMessage && (
          <div className="mb-4 p-3 text-xs rounded bg-expense/10 text-expense border border-expense/20">
            {errorMessage}
          </div>
        )}

        {successMessage && (
          <div className="mb-4 p-3 text-xs rounded bg-income/10 text-income border border-income/20">
            {successMessage}
          </div>
        )}

        {factorId && mfaChallengeId ? (
          <form onSubmit={handleVerifyTotp} className="space-y-4">
            <div>
              <label htmlFor="totp" className="block text-xs font-medium mb-1">
                Kode Autentikator 2FA
              </label>
              <div className="relative">
                <input
                  id="totp"
                  type="text"
                  inputMode="numeric"
                  autoComplete="one-time-code"
                  required
                  maxLength={6}
                  value={totpCode}
                  onChange={(e) => setTotpCode(e.target.value.trim())}
                  placeholder="000000"
                  className="w-full px-3 py-2 pl-9 border border-border rounded bg-background tracking-widest text-center text-lg font-mono focus:outline-none focus:ring-1 focus:ring-foreground"
                />
                <Key className="w-4 h-4 text-muted-foreground absolute left-3 top-3" />
              </div>
              <p className="text-[11px] text-muted-foreground mt-1">
                Masukkan 6 digit kode dari aplikasi autentikator Anda.
              </p>
            </div>

            <button
              type="submit"
              disabled={loading || totpCode.length !== 6}
              className="w-full py-2 px-4 rounded bg-foreground text-background font-medium hover:opacity-90 transition-opacity disabled:opacity-50 text-sm"
            >
              {loading ? 'Memverifikasi...' : 'Verifikasi & Masuk'}
            </button>
          </form>
        ) : (
          <div className="space-y-4">
            <form onSubmit={handleSubmit} className="space-y-4">
              <div>
                <label htmlFor="email" className="block text-xs font-medium mb-1">
                  Email
                </label>
                <div className="relative">
                  <input
                    id="email"
                    type="email"
                    required
                    value={email}
                    onChange={(e) => setEmail(e.target.value)}
                    placeholder="nama@domain.com"
                    className="w-full px-3 py-2 pl-9 border border-border rounded bg-background focus:outline-none focus:ring-1 focus:ring-foreground text-sm"
                  />
                  <Mail className="w-4 h-4 text-muted-foreground absolute left-3 top-3" />
                </div>
              </div>

              <div>
                <label htmlFor="password" className="block text-xs font-medium mb-1">
                  Kata Sandi
                </label>
                <div className="relative">
                  <input
                    id="password"
                    type="password"
                    required
                    minLength={6}
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder="Minimal 6 karakter"
                    className="w-full px-3 py-2 pl-9 border border-border rounded bg-background focus:outline-none focus:ring-1 focus:ring-foreground text-sm"
                  />
                  <Lock className="w-4 h-4 text-muted-foreground absolute left-3 top-3" />
                </div>
              </div>

              <button
                type="submit"
                disabled={loading}
                className="w-full py-2 px-4 rounded bg-foreground text-background font-medium hover:opacity-90 transition-opacity disabled:opacity-50 text-sm"
              >
                {loading
                  ? 'Memproses...'
                  : mode === 'signup'
                  ? 'Buat Akun'
                  : 'Masuk'}
              </button>
            </form>

            <div className="relative my-4">
              <div className="absolute inset-0 flex items-center">
                <div className="w-full border-t border-border" />
              </div>
              <div className="relative flex justify-center text-xs uppercase">
                <span className="bg-card px-2 text-muted-foreground">atau</span>
              </div>
            </div>

            <button
              onClick={handleGoogleLogin}
              type="button"
              disabled={loading}
              className="w-full py-2 px-4 border border-border rounded font-medium hover:bg-muted/50 transition-colors flex items-center justify-center gap-2 text-sm"
            >
              <ShieldCheck className="w-4 h-4" />
              <span>Masuk dengan Google</span>
            </button>
          </div>
        )}
      </div>
    </div>
  );
}
