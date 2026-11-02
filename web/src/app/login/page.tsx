'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';
import { Lock, Mail, Key, ArrowLeft, CheckCircle2, AlertCircle } from 'lucide-react';
import {
  Card,
  CardContent,
  Button,
  Input,
  SegmentedControl,
} from '@/components/ui';

export default function LoginPage() {
  const router = useRouter();
  const supabase = createClient();

  const [mode, setMode] = useState<'login' | 'signup' | 'forgot'>('login');
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

    if (mode === 'forgot') {
      const { error } = await supabase.auth.resetPasswordForEmail(email, {
        redirectTo: `${window.location.origin}/auth/callback?next=/pengaturan`,
      });

      if (error) {
        setErrorMessage(`Gagal mengirim tautan pemulihan: ${error.message}`);
        setLoading(false);
        return;
      }

      setSuccessMessage(
        'Tautan pemulihan kata sandi telah dikirim ke email Anda. Silakan periksa kotak masuk atau folder spam.'
      );
      setLoading(false);
      return;
    }

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
          'Pendaftaran berhasil. Silakan periksa email untuk verifikasi atau masuk langsung.'
        );
        setMode('login');
        setLoading(false);
      }
      return;
    }

    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });

    if (error) {
      setErrorMessage('Kombinasi email atau kata sandi tidak valid.');
      setLoading(false);
      return;
    }

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
      <Card className="w-full max-w-md shadow-sm">
        <CardContent className="p-6 sm:p-8 space-y-6">
          <div className="text-center space-y-2">
            <div className="inline-flex items-center justify-center">
              <img
                src="/orbit-icon.png"
                alt="Orbit Logo"
                className="w-14 h-14 rounded-xl object-cover border border-border"
              />
            </div>
            <div>
              <h1 className="text-2xl font-bold tracking-tight text-foreground">ORBIT</h1>
              <p className="text-xs font-medium uppercase tracking-wider text-muted-foreground mt-0.5">
                Produktivitas &amp; Keuangan
              </p>
            </div>
            <p className="text-xs text-muted-foreground">
              {mode === 'login'
                ? 'Masuk ke pusat kendali agenda dan keuangan Anda'
                : mode === 'signup'
                ? 'Buat akun baru untuk mulai mencatat agenda dan keuangan'
                : 'Pulihkan akses kata sandi akun Orbit Anda'}
            </p>
          </div>

          {!factorId && mode !== 'forgot' && (
            <SegmentedControl
              fullWidth
              ariaLabel="Mode Autentikasi"
              value={mode}
              onChange={(val) => {
                setMode(val);
                setErrorMessage(null);
                setSuccessMessage(null);
              }}
              options={[
                { value: 'login', label: 'Masuk' },
                { value: 'signup', label: 'Daftar Akun Baru' },
              ]}
            />
          )}

          {errorMessage && (
            <div
              role="alert"
              className="p-3.5 text-xs rounded-lg bg-expense/10 text-expense border border-expense/25 flex items-start gap-2.5"
            >
              <AlertCircle className="w-4 h-4 shrink-0 mt-0.5" />
              <span>{errorMessage}</span>
            </div>
          )}

          {successMessage && (
            <div
              role="status"
              className="p-3.5 text-xs rounded-lg bg-income/10 text-income border border-income/25 flex items-start gap-2.5"
            >
              <CheckCircle2 className="w-4 h-4 shrink-0 mt-0.5" />
              <span>{successMessage}</span>
            </div>
          )}

          {factorId && mfaChallengeId ? (
            <form onSubmit={handleVerifyTotp} className="space-y-4">
              <div>
                <label htmlFor="totp" className="block text-xs font-medium text-foreground mb-1.5">
                  Kode Autentikator 2FA
                </label>
                <div className="relative">
                  <Input
                    id="totp"
                    type="text"
                    inputMode="numeric"
                    autoComplete="one-time-code"
                    required
                    maxLength={6}
                    value={totpCode}
                    onChange={(e) => setTotpCode(e.target.value.trim())}
                    placeholder="000000"
                    className="pl-10 tracking-widest text-center text-lg font-mono tabular-nums"
                  />
                  <Key className="w-4 h-4 text-muted-foreground absolute left-3.5 top-3.5" />
                </div>
                <p className="text-xs text-muted-foreground mt-1.5">
                  Masukkan 6 digit kode dari aplikasi autentikator Anda.
                </p>
              </div>

              <Button
                type="submit"
                disabled={loading || totpCode.length !== 6}
                className="w-full"
              >
                {loading ? 'Memverifikasi...' : 'Verifikasi & Masuk'}
              </Button>
            </form>
          ) : (
            <div className="space-y-4">
              <form onSubmit={handleSubmit} className="space-y-4">
                <div>
                  <label htmlFor="email" className="block text-xs font-medium text-foreground mb-1.5">
                    Alamat Email
                  </label>
                  <div className="relative">
                    <Input
                      id="email"
                      type="email"
                      required
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      placeholder="nama@domain.com"
                      className="pl-10"
                    />
                    <Mail className="w-4 h-4 text-muted-foreground absolute left-3.5 top-3.5" />
                  </div>
                </div>

                {mode !== 'forgot' && (
                  <div>
                    <div className="flex items-center justify-between mb-1.5">
                      <label htmlFor="password" className="block text-xs font-medium text-foreground">
                        Kata Sandi
                      </label>
                      {mode === 'login' && (
                        <button
                          type="button"
                          onClick={() => {
                            setMode('forgot');
                            setErrorMessage(null);
                            setSuccessMessage(null);
                          }}
                          className="text-xs font-medium text-primary hover:underline min-h-[28px] px-1"
                        >
                          Lupa kata sandi?
                        </button>
                      )}
                    </div>
                    <div className="relative">
                      <Input
                        id="password"
                        type="password"
                        required
                        minLength={6}
                        value={password}
                        onChange={(e) => setPassword(e.target.value)}
                        placeholder="Minimal 6 karakter"
                        className="pl-10"
                      />
                      <Lock className="w-4 h-4 text-muted-foreground absolute left-3.5 top-3.5" />
                    </div>
                  </div>
                )}

                <Button type="submit" disabled={loading} className="w-full">
                  {loading
                    ? 'Memproses...'
                    : mode === 'signup'
                    ? 'Buat Akun Orbit'
                    : mode === 'forgot'
                    ? 'Kirim Tautan Reset Sandi'
                    : 'Masuk ke Orbit'}
                </Button>

                {mode === 'forgot' && (
                  <Button
                    type="button"
                    variant="ghost"
                    className="w-full"
                    onClick={() => {
                      setMode('login');
                      setErrorMessage(null);
                      setSuccessMessage(null);
                    }}
                  >
                    <ArrowLeft className="w-4 h-4" />
                    <span>Kembali ke Halaman Masuk</span>
                  </Button>
                )}
              </form>

              {mode !== 'forgot' && (
                <>
                  <div className="relative my-4">
                    <div className="absolute inset-0 flex items-center">
                      <div className="w-full border-t border-border" />
                    </div>
                    <div className="relative flex justify-center text-xs uppercase tracking-wider">
                      <span className="bg-card px-3 text-muted-foreground">atau lanjutkan dengan</span>
                    </div>
                  </div>

                  <Button
                    onClick={handleGoogleLogin}
                    type="button"
                    variant="secondary"
                    disabled={loading}
                    className="w-full"
                  >
                    <svg className="w-4 h-4" viewBox="0 0 24 24" aria-hidden="true">
                      <path
                        fill="#4285F4"
                        d="M23.49 12.27c0-.79-.07-1.54-.19-2.27H12v4.51h6.47c-.29 1.48-1.14 2.73-2.4 3.58v3h3.86c2.26-2.09 3.56-5.17 3.56-8.82z"
                      />
                      <path
                        fill="#34A853"
                        d="M12 24c3.24 0 5.95-1.08 7.93-2.91l-3.86-3c-1.08.72-2.45 1.16-4.07 1.16-3.13 0-5.78-2.11-6.73-4.96H1.29v3.09C3.26 21.3 7.31 24 12 24z"
                      />
                      <path
                        fill="#FBBC05"
                        d="M5.27 14.29c-.25-.72-.38-1.49-.38-2.29s.14-1.57.38-2.29V6.62H1.29C.47 8.24 0 10.06 0 12s.47 3.76 1.29 5.38l3.98-3.09z"
                      />
                      <path
                        fill="#EA4335"
                        d="M12 4.75c1.77 0 3.35.61 4.6 1.8l3.42-3.42C17.95 1.19 15.24 0 12 0 7.31 0 3.26 2.7 1.29 6.62l3.98 3.09c.95-2.85 3.6-4.96 6.73-4.96z"
                      />
                    </svg>
                    <span>Masuk dengan Google</span>
                  </Button>
                </>
              )}
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
