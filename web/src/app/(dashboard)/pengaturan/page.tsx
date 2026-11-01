'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';
import { formatDateIndo } from '@/lib/format';
import type { Database, NotificationSettings } from '@/types/database';
import {
  ShieldCheck,
  Smartphone,
  Key,
  LogOut,
  User,
  Check,
  AlertCircle,
  Bell
} from 'lucide-react';

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

  // Profile Form state
  const [displayName, setDisplayName] = useState('');
  const [monthStartDay, setMonthStartDay] = useState(1);
  const [profileMsg, setProfileMsg] = useState<string | null>(null);

  // Notification Settings state
  const [workspaceId, setWorkspaceId] = useState<string | null>(null);
  const [notifSettings, setNotifSettings] = useState<NotificationSettings | null>(null);
  const [budgetWarning, setBudgetWarning] = useState(true);
  const [budgetExceeded, setBudgetExceeded] = useState(true);
  const [billsReminder, setBillsReminder] = useState(true);
  const [receivablesReminder, setReceivablesReminder] = useState(true);
  const [dailySummaryTime, setDailySummaryTime] = useState('08:00');
  const [notifMsg, setNotifMsg] = useState<string | null>(null);
  const [savingNotif, setSavingNotif] = useState(false);

  // 2FA state
  const [hasMfa, setHasMfa] = useState(false);
  const [enrolling, setEnrolling] = useState(false);
  const [qrCodeSvg, setQrCodeSvg] = useState<string | null>(null);
  const [totpSecret, setTotpSecret] = useState<string | null>(null);
  const [verifyCode, setVerifyCode] = useState('');
  const [pendingFactorId, setPendingFactorId] = useState<string | null>(null);
  const [mfaError, setMfaError] = useState<string | null>(null);

  const loadData = useCallback(async () => {
    setLoading(true);

    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) {
      setLoading(false);
      return;
    }

    // Ambil profil
    const { data: profData } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', user.id)
      .single();

    if (profData) {
      setProfile(profData);
      setDisplayName(profData.display_name || '');
      setMonthStartDay(profData.month_start_day || 1);
    }

    // Ambil workspace_id
    const { data: memberData } = await supabase
      .from('workspace_members')
      .select('workspace_id')
      .limit(1)
      .single();

    if (memberData?.workspace_id) {
      setWorkspaceId(memberData.workspace_id);
      // Ambil preferensi notifikasi
      const { data: notifData } = await supabase
        .from('notification_settings')
        .select('*')
        .eq('workspace_id', memberData.workspace_id)
        .maybeSingle();

      if (notifData) {
        setNotifSettings(notifData);
        setBudgetWarning(notifData.budget_warning_enabled);
        setBudgetExceeded(notifData.budget_exceeded_enabled);
        setBillsReminder(notifData.bills_reminder_enabled);
        setReceivablesReminder(notifData.receivables_reminder_enabled);
        setDailySummaryTime(notifData.daily_summary_time || '08:00');
      }
    }

    // Ambil daftar sesi
    const { data: sessionData } = await supabase.rpc('fn_my_sessions');
    if (sessionData) {
      setSessions(sessionData);
    }

    // Ambil faktor MFA
    const { data: factors } = await supabase.auth.mfa.listFactors();
    const verifiedTotp = factors?.totp?.find((f) => f.status === 'verified');
    setHasMfa(!!verifiedTotp);

    setLoading(false);
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
    if (!confirm('Keluar dari semua perangkat? Anda akan dialihkan ke halaman login.')) return;

    await supabase.auth.signOut({ scope: 'global' });
    window.location.href = '/login';
  };

  return (
    <div className="space-y-8 max-w-4xl">
      <div>
        <h1 className="text-2xl font-semibold tracking-tight">Keamanan & Pengaturan</h1>
        <p className="text-sm text-muted-foreground">
          Kelola profil, preferensi notifikasi finansial, TOTP 2FA, dan sesi aktif
        </p>
      </div>

      {loading ? (
        <div className="p-8 text-center text-sm text-muted-foreground">Memuat data pengaturan...</div>
      ) : (
        <>
          {/* Bagian Profil */}
          <div className="p-6 border border-border bg-card rounded-lg space-y-4">
            <div className="flex items-center gap-3 border-b border-border pb-3">
              <User className="w-5 h-5 text-muted-foreground" />
              <h2 className="text-base font-semibold">Pengaturan Profil</h2>
            </div>

            {profileMsg && (
              <div className="p-3 text-xs rounded bg-muted text-foreground flex items-center gap-2">
                <Check className="w-4 h-4 text-income" />
                <span>{profileMsg}</span>
              </div>
            )}

            <form onSubmit={handleUpdateProfile} className="space-y-4 max-w-md">
              <div>
                <label className="block text-xs font-medium mb-1">Nama Tampilan</label>
                <input
                  type="text"
                  value={displayName}
                  onChange={(e) => setDisplayName(e.target.value)}
                  placeholder="Nama Anda"
                  className="w-full px-3 py-2 text-sm border border-border rounded bg-background focus:outline-none focus:ring-1 focus:ring-foreground"
                />
              </div>

              <div>
                <label className="block text-xs font-medium mb-1">
                  Tanggal Mulai Siklus Bulanan (1-28)
                </label>
                <input
                  type="number"
                  min={1}
                  max={28}
                  value={monthStartDay}
                  onChange={(e) => setMonthStartDay(Number(e.target.value))}
                  className="w-full px-3 py-2 text-sm border border-border rounded bg-background focus:outline-none"
                />
                <p className="text-[11px] text-muted-foreground mt-1">
                  Digunakan untuk menghitung laporan bulanan dan anggaran sesuai tanggal gajian.
                </p>
              </div>

              <button
                type="submit"
                className="px-4 py-2 text-sm font-medium bg-foreground text-background rounded hover:opacity-90 transition-opacity"
              >
                Simpan Profil
              </button>
            </form>
          </div>

          {/* Bagian Preferensi Notifikasi Finansial */}
          <div className="p-6 border border-border bg-card rounded-lg space-y-4">
            <div className="flex items-center gap-3 border-b border-border pb-3">
              <Bell className="w-5 h-5 text-muted-foreground" />
              <div>
                <h2 className="text-base font-semibold">Preferensi Notifikasi & Peringatan</h2>
                <p className="text-xs text-muted-foreground">
                  Atur ambang batas peringatan anggaran, jadwal tagihan, dan ringkasan harian
                </p>
              </div>
            </div>

            {notifMsg && (
              <div className="p-3 text-xs rounded bg-muted text-foreground flex items-center gap-2">
                <Check className="w-4 h-4 text-income" />
                <span>{notifMsg}</span>
              </div>
            )}

            <form onSubmit={handleSaveNotifications} className="space-y-3 max-w-md">
              <label className="flex items-center gap-2.5 cursor-pointer">
                <input
                  type="checkbox"
                  checked={budgetWarning}
                  onChange={(e) => setBudgetWarning(e.target.checked)}
                  className="rounded border-input text-primary focus:ring-ring"
                />
                <span className="text-xs font-medium">Peringatan Anggaran 80% (Waspada)</span>
              </label>

              <label className="flex items-center gap-2.5 cursor-pointer">
                <input
                  type="checkbox"
                  checked={budgetExceeded}
                  onChange={(e) => setBudgetExceeded(e.target.checked)}
                  className="rounded border-input text-primary focus:ring-ring"
                />
                <span className="text-xs font-medium">Peringatan Anggaran 100% (Over Budget)</span>
              </label>

              <label className="flex items-center gap-2.5 cursor-pointer">
                <input
                  type="checkbox"
                  checked={billsReminder}
                  onChange={(e) => setBillsReminder(e.target.checked)}
                  className="rounded border-input text-primary focus:ring-ring"
                />
                <span className="text-xs font-medium">Pengingat Tagihan Jatuh Tempo (H-3 & Hari-H)</span>
              </label>

              <label className="flex items-center gap-2.5 cursor-pointer">
                <input
                  type="checkbox"
                  checked={receivablesReminder}
                  onChange={(e) => setReceivablesReminder(e.target.checked)}
                  className="rounded border-input text-primary focus:ring-ring"
                />
                <span className="text-xs font-medium">Pengingat Piutang & Komitmen Pembayaran</span>
              </label>

              <div className="pt-2">
                <label className="block text-xs font-medium mb-1">Waktu Ringkasan Pagi</label>
                <input
                  type="time"
                  value={dailySummaryTime}
                  onChange={(e) => setDailySummaryTime(e.target.value)}
                  className="px-3 py-1.5 text-sm border border-border rounded bg-background focus:outline-none"
                />
              </div>

              <div className="pt-3">
                <button
                  type="submit"
                  disabled={savingNotif}
                  className="px-4 py-2 text-sm font-medium bg-foreground text-background rounded hover:opacity-90 transition-opacity disabled:opacity-50"
                >
                  {savingNotif ? 'Menyimpan...' : 'Simpan Preferensi Notifikasi'}
                </button>
              </div>
            </form>
          </div>

          {/* Bagian 2FA / TOTP */}
          <div className="p-6 border border-border bg-card rounded-lg space-y-4">
            <div className="flex items-center gap-3 border-b border-border pb-3">
              <Key className="w-5 h-5 text-muted-foreground" />
              <div>
                <h2 className="text-base font-semibold">Autentikasi Dua Faktor (TOTP 2FA)</h2>
                <p className="text-xs text-muted-foreground">
                  Lapisan keamanan tambahan menggunakan aplikasi autentikator (Google Authenticator, Aegis, 1Password)
                </p>
              </div>
            </div>

            {mfaError && (
              <div className="p-3 text-xs rounded bg-expense/10 text-expense border border-expense/20 flex items-center gap-2">
                <AlertCircle className="w-4 h-4" />
                <span>{mfaError}</span>
              </div>
            )}

            {hasMfa ? (
              <div className="flex items-center justify-between p-4 border border-income/30 bg-income/5 rounded-md">
                <div className="flex items-center gap-3">
                  <ShieldCheck className="w-5 h-5 text-income" />
                  <div>
                    <div className="text-sm font-medium text-foreground">2FA Aktif</div>
                    <div className="text-xs text-muted-foreground">
                      Akun Anda terlindungi dengan kode autentikator saat login
                    </div>
                  </div>
                </div>
              </div>
            ) : enrolling ? (
              <div className="p-4 border border-border bg-muted/20 rounded-md space-y-4 max-w-md">
                <div className="text-sm font-medium">Scan QR Code Berikut:</div>
                {qrCodeSvg && (
                  <div
                    className="p-3 bg-white w-fit rounded border border-border"
                    dangerouslySetInnerHTML={{ __html: qrCodeSvg }}
                  />
                )}
                <div className="text-xs text-muted-foreground">
                  Atau masukkan kunci rahasia ini secara manual:{' '}
                  <code className="font-mono bg-muted px-1.5 py-0.5 rounded select-all font-semibold">
                    {totpSecret}
                  </code>
                </div>

                <form onSubmit={verifyAndActivateTotp} className="space-y-3 pt-2">
                  <div>
                    <label className="block text-xs font-medium mb-1">
                      Masukkan 6 Digit Kode Konfirmasi
                    </label>
                    <input
                      type="text"
                      maxLength={6}
                      required
                      value={verifyCode}
                      onChange={(e) => setVerifyCode(e.target.value)}
                      placeholder="000000"
                      className="w-full px-3 py-2 text-center text-lg font-mono tracking-widest border border-border rounded bg-background focus:outline-none"
                    />
                  </div>
                  <div className="flex items-center gap-2">
                    <button
                      type="submit"
                      className="px-4 py-2 text-xs font-medium bg-foreground text-background rounded hover:opacity-90"
                    >
                      Aktifkan 2FA
                    </button>
                    <button
                      type="button"
                      onClick={() => setEnrolling(false)}
                      className="px-4 py-2 text-xs font-medium border border-border rounded hover:bg-muted"
                    >
                      Batal
                    </button>
                  </div>
                </form>
              </div>
            ) : (
              <div className="flex items-center justify-between">
                <div className="text-xs text-muted-foreground">
                  2FA belum diaktifkan pada akun ini. Sangat disarankan untuk mengaktifkannya.
                </div>
                <button
                  onClick={startTotpEnrollment}
                  type="button"
                  className="px-4 py-2 text-xs font-medium bg-foreground text-background rounded hover:opacity-90 transition-opacity"
                >
                  Aktifkan 2FA Sekarang
                </button>
              </div>
            )}
          </div>

          {/* Bagian Sesi Aktif */}
          <div className="p-6 border border-border bg-card rounded-lg space-y-4">
            <div className="flex items-center justify-between border-b border-border pb-3">
              <div className="flex items-center gap-3">
                <Smartphone className="w-5 h-5 text-muted-foreground" />
                <div>
                  <h2 className="text-base font-semibold">Daftar Sesi Aktif</h2>
                  <p className="text-xs text-muted-foreground">
                    Perangkat yang saat ini memiliki akses ke akun Orbit Anda
                  </p>
                </div>
              </div>

              <button
                onClick={handleLogoutAll}
                type="button"
                className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-expense hover:bg-expense/10 rounded transition-colors"
              >
                <LogOut className="w-3.5 h-3.5" />
                <span>Keluar dari Semua Perangkat</span>
              </button>
            </div>

            <div className="divide-y divide-border">
              {sessions.length === 0 ? (
                <div className="p-4 text-center text-xs text-muted-foreground">
                  Tidak ada sesi aktif terdeteksi
                </div>
              ) : (
                sessions.map((s) => (
                  <div
                    key={s.id}
                    className="py-3 flex items-center justify-between gap-4 text-sm"
                  >
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="font-medium text-xs">
                          {s.user_agent ? s.user_agent.slice(0, 70) : 'Perangkat Tidak Dikenal'}
                        </span>
                        {s.is_current && (
                          <span className="text-[10px] uppercase font-semibold tracking-wider px-1.5 py-0.5 rounded bg-income/10 text-income">
                            Sesi Ini
                          </span>
                        )}
                        <span className="text-[10px] font-mono px-1 py-0.5 rounded bg-muted text-muted-foreground">
                          {s.aal}
                        </span>
                      </div>
                      <div className="text-[11px] text-muted-foreground mt-0.5">
                        Terakhir aktif: {formatDateIndo(s.updated_at || s.created_at)}
                      </div>
                    </div>

                    {!s.is_current && (
                      <button
                        onClick={() => handleRevokeSession(s.id)}
                        type="button"
                        className="text-xs text-muted-foreground hover:text-expense px-2 py-1 rounded transition-colors"
                      >
                        Cabut Akses
                      </button>
                    )}
                  </div>
                ))
              )}
            </div>
          </div>
        </>
      )}
    </div>
  );
}
