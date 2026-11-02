'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';
import { formatDateIndo } from '@/lib/format';
import type { Database } from '@/types/database';
import {
  ShieldCheck,
  Smartphone,
  Key,
  LogOut,
  User,
  Check,
  AlertCircle,
  Bell,
} from 'lucide-react';
import {
  Card,
  CardHeader,
  CardTitle,
  CardContent,
  Button,
  Input,
  StatusBadge,
  Skeleton,
  ErrorState,
  LainnyaSubNav,
} from '@/components/ui';

type SessionItem = {
  id: string;
  created_at: string;
  updated_at: string;
  user_agent: string | null;
  aal: string;
  is_current: boolean;
};

type ProfileRow = Database['public']['Tables']['profiles']['Row'];

export default function PengaturanPage() {
  const supabase = createClient();

  const [profile, setProfile] = useState<ProfileRow | null>(null);
  const [sessions, setSessions] = useState<SessionItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);

  const [displayName, setDisplayName] = useState('');
  const [monthStartDay, setMonthStartDay] = useState(1);
  const [profileMsg, setProfileMsg] = useState<string | null>(null);

  const [workspaceId, setWorkspaceId] = useState<string | null>(null);
  const [budgetWarning, setBudgetWarning] = useState(true);
  const [budgetExceeded, setBudgetExceeded] = useState(true);
  const [billsReminder, setBillsReminder] = useState(true);
  const [receivablesReminder, setReceivablesReminder] = useState(true);
  const [dailySummaryTime, setDailySummaryTime] = useState('08:00');
  const [notifMsg, setNotifMsg] = useState<string | null>(null);
  const [savingNotif, setSavingNotif] = useState(false);

  const [hasMfa, setHasMfa] = useState(false);
  const [enrolling, setEnrolling] = useState(false);
  const [qrCodeSvg, setQrCodeSvg] = useState<string | null>(null);
  const [totpSecret, setTotpSecret] = useState<string | null>(null);
  const [verifyCode, setVerifyCode] = useState('');
  const [pendingFactorId, setPendingFactorId] = useState<string | null>(null);
  const [mfaError, setMfaError] = useState<string | null>(null);

  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [passwordMsg, setPasswordMsg] = useState<string | null>(null);
  const [passwordErr, setPasswordErr] = useState<string | null>(null);
  const [savingPassword, setSavingPassword] = useState(false);

  const loadData = useCallback(async () => {
    setLoading(true);
    setLoadError(null);

    try {
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) {
        setLoading(false);
        return;
      }

      const { data: profData, error: profErr } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', user.id)
        .single();

      if (profErr) throw profErr;
      if (profData) {
        setProfile(profData);
        setDisplayName(profData.display_name || '');
        setMonthStartDay(profData.month_start_day || 1);
      }

      const { data: memberData } = await supabase
        .from('workspace_members')
        .select('workspace_id')
        .limit(1)
        .single();

      if (memberData?.workspace_id) {
        setWorkspaceId(memberData.workspace_id);
        const { data: notifData } = await supabase
          .from('notification_settings')
          .select('*')
          .eq('workspace_id', memberData.workspace_id)
          .maybeSingle();

        if (notifData) {
          setBudgetWarning(notifData.budget_warning_enabled);
          setBudgetExceeded(notifData.budget_exceeded_enabled);
          setBillsReminder(notifData.bills_reminder_enabled);
          setReceivablesReminder(notifData.receivables_reminder_enabled);
          setDailySummaryTime(notifData.daily_summary_time || '08:00');
        }
      }

      const { data: sessionData } = await supabase.rpc('fn_my_sessions');
      if (sessionData) {
        setSessions(sessionData);
      }

      const { data: factors } = await supabase.auth.mfa.listFactors();
      const verifiedTotp = factors?.totp?.find((f) => f.status === 'verified');
      setHasMfa(!!verifiedTotp);
    } catch (err: unknown) {
      setLoadError(err instanceof Error ? err.message : 'Gagal memuat pengaturan akun.');
    } finally {
      setLoading(false);
    }
  }, [supabase]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  const handleUpdateProfile = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!profile) return;

    setProfileMsg(null);
    const { error } = await supabase
      .from('profiles')
      .update({
        display_name: displayName.trim(),
        month_start_day: Number(monthStartDay),
      })
      .eq('id', profile.id);

    if (error) {
      setProfileMsg(`Gagal menyimpan profil: ${error.message}`);
    } else {
      setProfileMsg('Profil berhasil diperbarui.');
      loadData();
    }
  };

  const handleSaveNotifications = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!workspaceId) return;

    setSavingNotif(true);
    setNotifMsg(null);

    const payload = {
      workspace_id: workspaceId,
      budget_warning_enabled: budgetWarning,
      budget_exceeded_enabled: budgetExceeded,
      bills_reminder_enabled: billsReminder,
      receivables_reminder_enabled: receivablesReminder,
      daily_summary_time: dailySummaryTime,
      updated_at: new Date().toISOString(),
    };

    const { error } = await supabase
      .from('notification_settings')
      .upsert(payload, { onConflict: 'workspace_id' });

    if (error) {
      setNotifMsg(`Gagal menyimpan preferensi: ${error.message}`);
    } else {
      setNotifMsg('Preferensi notifikasi berhasil disimpan.');
      await loadData();
    }
    setSavingNotif(false);
  };

  const startTotpEnrollment = async () => {
    setMfaError(null);
    const { data, error } = await supabase.auth.mfa.enroll({
      factorType: 'totp',
      issuer: 'Orbit',
      friendlyName: 'Orbit Mobile/Web Authenticator',
    });

    if (error) {
      setMfaError(error.message);
      return;
    }

    setPendingFactorId(data.id);
    setQrCodeSvg(data.totp.qr_code);
    setTotpSecret(data.totp.secret);
    setEnrolling(true);
  };

  const verifyAndActivateTotp = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!pendingFactorId) return;

    setMfaError(null);
    const challenge = await supabase.auth.mfa.challenge({ factorId: pendingFactorId });
    if (challenge.error) {
      setMfaError(challenge.error.message);
      return;
    }

    const verify = await supabase.auth.mfa.verify({
      factorId: pendingFactorId,
      challengeId: challenge.data.id,
      code: verifyCode.trim(),
    });

    if (verify.error) {
      setMfaError('Kode verifikasi salah.');
      return;
    }

    setEnrolling(false);
    setPendingFactorId(null);
    setQrCodeSvg(null);
    setVerifyCode('');
    loadData();
  };

  const handleRevokeSession = async (sessionId: string) => {
    if (!confirm('Cabut sesi ini? Perangkat tersebut akan diminta masuk kembali.')) return;

    const { error } = await supabase.rpc('fn_revoke_session', {
      p_session_id: sessionId,
    });

    if (error) {
      alert(`Gagal mencabut sesi: ${error.message}`);
    } else {
      loadData();
    }
  };

  const handleLogoutAll = async () => {
    if (!confirm('Keluar dari semua perangkat? Anda akan dialihkan ke halaman masuk.')) return;

    await supabase.auth.signOut({ scope: 'global' });
    window.location.href = '/login';
  };

  const handleUpdatePassword = async (e: React.FormEvent) => {
    e.preventDefault();
    setPasswordMsg(null);
    setPasswordErr(null);

    if (newPassword.length < 6) {
      setPasswordErr('Kata sandi baru minimal harus 6 karakter.');
      return;
    }
    if (newPassword !== confirmPassword) {
      setPasswordErr('Konfirmasi kata sandi tidak cocok.');
      return;
    }

    setSavingPassword(true);
    const { error } = await supabase.auth.updateUser({
      password: newPassword,
    });
    setSavingPassword(false);

    if (error) {
      setPasswordErr(`Gagal memperbarui kata sandi: ${error.message}`);
    } else {
      setPasswordMsg('Kata sandi akun berhasil diperbarui.');
      setNewPassword('');
      setConfirmPassword('');
    }
  };

  return (
    <div className="space-y-6 max-w-4xl">
      <div>
        <h1 className="text-2xl font-bold tracking-tight text-foreground">Lainnya</h1>
        <p className="text-sm text-muted-foreground mt-0.5">
          Kelola profil, preferensi notifikasi finansial, autentikasi 2FA, dan sesi perangkat
        </p>
      </div>

      <LainnyaSubNav />

      {loadError ? (
        <ErrorState message={loadError} onRetry={loadData} />
      ) : loading ? (
        <div className="space-y-4" aria-busy="true">
          <Skeleton className="h-48 w-full" />
          <Skeleton className="h-48 w-full" />
          <Skeleton className="h-48 w-full" />
        </div>
      ) : (
        <div className="space-y-6">
          {/* Bagian Profil */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2.5">
                <User className="w-4 h-4 text-primary" />
                <span>Pengaturan Profil</span>
              </CardTitle>
            </CardHeader>

            <CardContent className="space-y-4">
              {profileMsg && (
                <div className="p-3 text-xs rounded-lg bg-income/10 text-income border border-income/20 flex items-center gap-2">
                  <Check className="w-4 h-4" />
                  <span>{profileMsg}</span>
                </div>
              )}

              <form onSubmit={handleUpdateProfile} className="space-y-4 max-w-md">
                <div>
                  <label className="block text-xs font-medium text-foreground mb-1.5">
                    Nama Tampilan
                  </label>
                  <Input
                    type="text"
                    value={displayName}
                    onChange={(e) => setDisplayName(e.target.value)}
                    placeholder="Nama Anda"
                  />
                </div>

                <div>
                  <label className="block text-xs font-medium text-foreground mb-1.5">
                    Tanggal Mulai Siklus Bulanan (1-28)
                  </label>
                  <Input
                    type="number"
                    min={1}
                    max={28}
                    value={monthStartDay}
                    onChange={(e) => setMonthStartDay(Number(e.target.value))}
                    className="tabular-nums"
                  />
                  <p className="text-xs text-muted-foreground mt-1">
                    Digunakan untuk menghitung laporan bulanan dan anggaran sesuai tanggal gajian.
                  </p>
                </div>

                <Button type="submit">Simpan Profil</Button>
              </form>
            </CardContent>
          </Card>

          {/* Bagian Ubah Kata Sandi */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2.5">
                <Key className="w-4 h-4 text-primary" />
                <span>Kata Sandi Akun</span>
              </CardTitle>
            </CardHeader>

            <CardContent className="space-y-4">
              {passwordMsg && (
                <div className="p-3 text-xs rounded-lg bg-income/10 text-income border border-income/20 flex items-center gap-2">
                  <Check className="w-4 h-4" />
                  <span>{passwordMsg}</span>
                </div>
              )}

              {passwordErr && (
                <div className="p-3 text-xs rounded-lg bg-expense/10 text-expense border border-expense/20 flex items-center gap-2">
                  <AlertCircle className="w-4 h-4" />
                  <span>{passwordErr}</span>
                </div>
              )}

              <form onSubmit={handleUpdatePassword} className="space-y-4 max-w-md">
                <div>
                  <label className="block text-xs font-medium text-foreground mb-1.5">
                    Kata Sandi Baru
                  </label>
                  <Input
                    type="password"
                    required
                    minLength={6}
                    value={newPassword}
                    onChange={(e) => setNewPassword(e.target.value)}
                    placeholder="Minimal 6 karakter"
                  />
                </div>

                <div>
                  <label className="block text-xs font-medium text-foreground mb-1.5">
                    Konfirmasi Kata Sandi Baru
                  </label>
                  <Input
                    type="password"
                    required
                    minLength={6}
                    value={confirmPassword}
                    onChange={(e) => setConfirmPassword(e.target.value)}
                    placeholder="Ulangi kata sandi baru"
                  />
                </div>

                <Button type="submit" disabled={savingPassword}>
                  {savingPassword ? 'Menyimpan...' : 'Perbarui Kata Sandi'}
                </Button>
              </form>
            </CardContent>
          </Card>

          {/* Bagian Preferensi Notifikasi Finansial */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2.5">
                <Bell className="w-4 h-4 text-primary" />
                <span>Preferensi Notifikasi & Peringatan</span>
              </CardTitle>
            </CardHeader>

            <CardContent className="space-y-4">
              {notifMsg && (
                <div className="p-3 text-xs rounded-lg bg-income/10 text-income border border-income/20 flex items-center gap-2">
                  <Check className="w-4 h-4" />
                  <span>{notifMsg}</span>
                </div>
              )}

              <form onSubmit={handleSaveNotifications} className="space-y-3 max-w-md">
                <label className="flex items-center gap-2.5 cursor-pointer min-h-11">
                  <input
                    type="checkbox"
                    checked={budgetWarning}
                    onChange={(e) => setBudgetWarning(e.target.checked)}
                    className="w-4 h-4 rounded border-border text-primary"
                  />
                  <span className="text-xs font-medium text-foreground">
                    Peringatan Anggaran 80% (Waspada)
                  </span>
                </label>

                <label className="flex items-center gap-2.5 cursor-pointer min-h-11">
                  <input
                    type="checkbox"
                    checked={budgetExceeded}
                    onChange={(e) => setBudgetExceeded(e.target.checked)}
                    className="w-4 h-4 rounded border-border text-primary"
                  />
                  <span className="text-xs font-medium text-foreground">
                    Peringatan Anggaran 100% (Over Budget)
                  </span>
                </label>

                <label className="flex items-center gap-2.5 cursor-pointer min-h-11">
                  <input
                    type="checkbox"
                    checked={billsReminder}
                    onChange={(e) => setBillsReminder(e.target.checked)}
                    className="w-4 h-4 rounded border-border text-primary"
                  />
                  <span className="text-xs font-medium text-foreground">
                    Pengingat Tagihan Jatuh Tempo (H-3 & Hari-H)
                  </span>
                </label>

                <label className="flex items-center gap-2.5 cursor-pointer min-h-11">
                  <input
                    type="checkbox"
                    checked={receivablesReminder}
                    onChange={(e) => setReceivablesReminder(e.target.checked)}
                    className="w-4 h-4 rounded border-border text-primary"
                  />
                  <span className="text-xs font-medium text-foreground">
                    Pengingat Piutang & Komitmen Pembayaran
                  </span>
                </label>

                <div className="pt-2">
                  <label className="block text-xs font-medium text-foreground mb-1.5">
                    Waktu Ringkasan Pagi
                  </label>
                  <Input
                    type="time"
                    value={dailySummaryTime}
                    onChange={(e) => setDailySummaryTime(e.target.value)}
                    className="w-40 tabular-nums"
                  />
                </div>

                <div className="pt-2">
                  <Button type="submit" disabled={savingNotif}>
                    {savingNotif ? 'Menyimpan...' : 'Simpan Preferensi Notifikasi'}
                  </Button>
                </div>
              </form>
            </CardContent>
          </Card>

          {/* Bagian 2FA / TOTP */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2.5">
                <ShieldCheck className="w-4 h-4 text-primary" />
                <span>Autentikasi Dua Faktor (TOTP 2FA)</span>
              </CardTitle>
            </CardHeader>

            <CardContent className="space-y-4">
              {mfaError && (
                <div className="p-3 text-xs rounded-lg bg-expense/10 text-expense border border-expense/20 flex items-center gap-2">
                  <AlertCircle className="w-4 h-4" />
                  <span>{mfaError}</span>
                </div>
              )}

              {hasMfa ? (
                <div className="flex items-center justify-between p-4 border border-income/30 bg-income/5 rounded-lg">
                  <div className="flex items-center gap-3">
                    <ShieldCheck className="w-5 h-5 text-income" />
                    <div>
                      <div className="text-sm font-semibold text-foreground">2FA Aktif</div>
                      <div className="text-xs text-muted-foreground">
                        Akun Anda terlindungi dengan kode autentikator saat masuk
                      </div>
                    </div>
                  </div>
                </div>
              ) : enrolling ? (
                <div className="p-4 border border-border bg-muted/20 rounded-lg space-y-4 max-w-md">
                  <div className="text-sm font-semibold text-foreground">Scan QR Code Berikut:</div>
                  {qrCodeSvg && (
                    <div
                      className="p-3 bg-white w-fit rounded-lg border border-border"
                      dangerouslySetInnerHTML={{ __html: qrCodeSvg }}
                    />
                  )}
                  <div className="text-xs text-muted-foreground">
                    Atau masukkan kunci rahasia ini secara manual:{' '}
                    <code className="font-mono bg-muted px-1.5 py-0.5 rounded select-all font-semibold text-foreground">
                      {totpSecret}
                    </code>
                  </div>

                  <form onSubmit={verifyAndActivateTotp} className="space-y-3 pt-2">
                    <div>
                      <label className="block text-xs font-medium text-foreground mb-1.5">
                        Masukkan 6 Digit Kode Konfirmasi
                      </label>
                      <Input
                        type="text"
                        maxLength={6}
                        required
                        value={verifyCode}
                        onChange={(e) => setVerifyCode(e.target.value)}
                        placeholder="000000"
                        className="text-center text-lg font-mono tracking-widest tabular-nums"
                      />
                    </div>
                    <div className="flex items-center gap-2">
                      <Button type="submit">Aktifkan 2FA</Button>
                      <Button
                        type="button"
                        variant="secondary"
                        onClick={() => setEnrolling(false)}
                      >
                        Batal
                      </Button>
                    </div>
                  </form>
                </div>
              ) : (
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                  <div className="text-xs text-muted-foreground">
                    2FA belum diaktifkan pada akun ini. Sangat disarankan untuk mengaktifkannya.
                  </div>
                  <Button onClick={startTotpEnrollment} type="button">
                    Aktifkan 2FA Sekarang
                  </Button>
                </div>
              )}
            </CardContent>
          </Card>

          {/* Bagian Sesi Aktif */}
          <Card className="overflow-hidden">
            <CardHeader>
              <CardTitle className="flex items-center gap-2.5">
                <Smartphone className="w-4 h-4 text-primary" />
                <span>Daftar Sesi Aktif</span>
              </CardTitle>
              <Button
                onClick={handleLogoutAll}
                type="button"
                variant="destructive"
                size="sm"
              >
                <LogOut className="w-3.5 h-3.5" />
                <span>Keluar dari Semua Perangkat</span>
              </Button>
            </CardHeader>

            <div className="divide-y divide-border">
              {sessions.length === 0 ? (
                <div className="p-6 text-center text-xs text-muted-foreground">
                  Tidak ada sesi aktif terdeteksi
                </div>
              ) : (
                sessions.map((s) => (
                  <div
                    key={s.id}
                    className="p-4 flex items-center justify-between gap-4 text-sm"
                  >
                    <div>
                      <div className="flex items-center gap-2 flex-wrap">
                        <span className="font-semibold text-xs text-foreground">
                          {s.user_agent ? s.user_agent.slice(0, 70) : 'Perangkat Tidak Dikenal'}
                        </span>
                        {s.is_current && (
                          <StatusBadge variant="income">Sesi Ini</StatusBadge>
                        )}
                        <StatusBadge variant="neutral">{s.aal}</StatusBadge>
                      </div>
                      <div className="text-xs text-muted-foreground mt-1 tabular-nums">
                        Terakhir aktif: {formatDateIndo(s.updated_at || s.created_at)}
                      </div>
                    </div>

                    {!s.is_current && (
                      <Button
                        onClick={() => handleRevokeSession(s.id)}
                        type="button"
                        variant="ghost"
                        size="sm"
                      >
                        Cabut Akses
                      </Button>
                    )}
                  </div>
                ))
              )}
            </div>
          </Card>
        </div>
      )}
    </div>
  );
}
