'use client';

import { useEffect, useState, useCallback, useMemo } from 'react';
import Link from 'next/link';
import { createClient } from '@/lib/supabase/client';
import { formatDateIndo } from '@/lib/format';
import { usePrivacyMode } from '@/lib/privacy-mode';
import { buildWeeklyDigestSummary } from '@/lib/smart-alerts';
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
  Copy,
  Radio,
  Trash2,
  UserPlus,
  Users,
  Eye,
  EyeOff,
  Lock,
  Mail,
  Sparkles,
  Wifi,
} from 'lucide-react';
import {
  Card,
  CardHeader,
  CardTitle,
  CardContent,
  Button,
  Input,
  Select,
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
type WorkspaceMemberRow = Database['public']['Tables']['workspace_members']['Row'];
type WorkspaceInviteRow = Database['public']['Tables']['workspace_invites']['Row'];
type UserDeviceRow = Database['public']['Tables']['user_devices']['Row'];

interface PushStatusPayload {
  configured: boolean;
  status: 'ready' | 'needs_config';
  publicKey: string | null;
  missingVars: string[];
  instructions: string;
  deviceCount?: number | null;
}

function urlBase64ToUint8Array(base64String: string): ArrayBuffer {
  const padding = '='.repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
  const rawData = window.atob(base64);
  const bytes = new Uint8Array(rawData.length);
  for (let i = 0; i < rawData.length; i += 1) {
    bytes[i] = rawData.charCodeAt(i);
  }
  return bytes.buffer;
}

async function sha256Hex(raw: string): Promise<string> {
  const bytes = new TextEncoder().encode(raw);
  const digest = await window.crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

export default function PengaturanPage() {
  const supabase = useMemo(() => createClient(), []);
  const {
    privacyMode,
    setPrivacyMode,
    hasPin,
    idleLockMinutes,
    setIdleLockMinutes,
    setLockPin,
    clearLockPin,
    lockSessionNow,
  } = usePrivacyMode();

  const [profile, setProfile] = useState<ProfileRow | null>(null);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);
  const [currentUserEmail, setCurrentUserEmail] = useState<string | null>(null);
  const [sessions, setSessions] = useState<SessionItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);

  const [displayName, setDisplayName] = useState('');
  const [monthStartDay, setMonthStartDay] = useState(1);
  const [profileMsg, setProfileMsg] = useState<string | null>(null);

  const [workspaceId, setWorkspaceId] = useState<string | null>(null);
  const [workspaceName, setWorkspaceName] = useState<string>('Ruang Kerja');
  const [workspaceType, setWorkspaceType] = useState<'personal' | 'shared'>('personal');
  const [myWorkspaceRole, setMyWorkspaceRole] = useState<'owner' | 'editor' | 'viewer'>('owner');
  const [members, setMembers] = useState<Array<WorkspaceMemberRow & { display_name: string }>>([]);
  const [invites, setInvites] = useState<WorkspaceInviteRow[]>([]);
  const [inviteEmail, setInviteEmail] = useState('');
  const [inviteRole, setInviteRole] = useState<'editor' | 'viewer'>('editor');
  const [creatingInvite, setCreatingInvite] = useState(false);
  const [inviteMsg, setInviteMsg] = useState<string | null>(null);
  const [inviteErr, setInviteErr] = useState<string | null>(null);
  const [generatedLinks, setGeneratedLinks] = useState<Record<string, string>>({});
  const [copiedInviteId, setCopiedInviteId] = useState<string | null>(null);
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

  const [devices, setDevices] = useState<UserDeviceRow[]>([]);
  const [pushStatus, setPushStatus] = useState<PushStatusPayload | null>(null);
  const [swActive, setSwActive] = useState(false);
  const [browserNotifPerm, setBrowserNotifPerm] = useState<string>('default');
  const [pushFeedback, setPushFeedback] = useState<string | null>(null);
  const [subscribingPush, setSubscribingPush] = useState(false);
  const [testingPush, setTestingPush] = useState(false);

  const [pinInput, setPinInput] = useState('');
  const [pinConfirm, setPinConfirm] = useState('');
  const [pinMsg, setPinMsg] = useState<string | null>(null);
  const [pinErr, setPinErr] = useState<string | null>(null);

  const [digestStats, setDigestStats] = useState<{
    tasks: Array<{ id: string; title: string; status: string; due_at?: string | null; updated_at?: string | null }>;
    transactions: Array<{ id: string; type: 'income' | 'expense' | 'transfer'; amount: number; occurred_at: string; status?: string; deleted_at?: string | null }>;
  }>({ tasks: [], transactions: [] });
  const [copiedDigest, setCopiedDigest] = useState(false);

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
      setCurrentUserId(user.id);
      setCurrentUserEmail(user.email ?? null);

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

      const storedWsId =
        typeof window !== 'undefined'
          ? window.localStorage.getItem('orbit_active_workspace_id')
          : null;

      let memberData: { workspace_id: string; role: string } | null = null;
      if (storedWsId) {
        const res = await supabase
          .from('workspace_members')
          .select('workspace_id, role')
          .eq('workspace_id', storedWsId)
          .eq('user_id', user.id)
          .limit(1);
        memberData = res.data?.[0] ?? null;
      }

      if (!memberData?.workspace_id) {
        const fallback = await supabase
          .from('workspace_members')
          .select('workspace_id, role')
          .eq('user_id', user.id)
          .limit(1);
        memberData = fallback.data?.[0] ?? null;
      }

      const resolvedWsId = memberData?.workspace_id ?? null;
      if (resolvedWsId) {
        setWorkspaceId(resolvedWsId);
        if (memberData?.role) {
          setMyWorkspaceRole(memberData.role as 'owner' | 'editor' | 'viewer');
        }

        const [wsRes, allMembersRes, notifRes] = await Promise.all([
          supabase
            .from('workspaces')
            .select('id, name, type')
            .eq('id', resolvedWsId)
            .maybeSingle(),
          supabase
            .from('workspace_members')
            .select('*')
            .eq('workspace_id', resolvedWsId)
            .order('created_at', { ascending: true }),
          supabase
            .from('notification_settings')
            .select('*')
            .eq('workspace_id', resolvedWsId)
            .maybeSingle(),
        ]);

        if (wsRes.data) {
          setWorkspaceName(wsRes.data.name);
          setWorkspaceType(wsRes.data.type as 'personal' | 'shared');
        }

        const rawMembers = (allMembersRes.data ?? []) as WorkspaceMemberRow[];
        if (rawMembers.length > 0) {
          const { data: memberProfiles } = await supabase
            .from('profiles')
            .select('id, display_name')
            .in(
              'id',
              rawMembers.map((m) => m.user_id)
            );
          const profileMap = new Map<string, string>();
          for (const mp of memberProfiles ?? []) {
            if (mp.display_name) profileMap.set(mp.id, mp.display_name);
          }
          setMembers(
            rawMembers.map((m) => ({
              ...m,
              display_name:
                m.user_id === user.id
                  ? profData?.display_name || user.email || 'Anda'
                  : profileMap.get(m.user_id) || `Anggota ${m.user_id.slice(0, 6)}`,
            }))
          );
        } else {
          setMembers([]);
        }

        const effectiveRole = (memberData?.role || 'owner') as 'owner' | 'editor' | 'viewer';
        if (effectiveRole === 'owner') {
          const { data: invData, error: invErr } = await supabase
            .from('workspace_invites')
            .select('*')
            .eq('workspace_id', resolvedWsId)
            .is('revoked_at', null)
            .order('created_at', { ascending: false });
          if (!invErr && invData) {
            setInvites(invData as WorkspaceInviteRow[]);
          } else {
            setInvites([]);
          }
        } else {
          setInvites([]);
        }

        const notifData = notifRes.data;
        if (notifData) {
          setBudgetWarning(notifData.budget_warning_enabled);
          setBudgetExceeded(notifData.budget_exceeded_enabled);
          setBillsReminder(notifData.bills_reminder_enabled);
          setReceivablesReminder(notifData.receivables_reminder_enabled);
          setDailySummaryTime(notifData.daily_summary_time || '08:00');
        }

        const past7Iso = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
        const [devRes, digestTasksRes, digestTxRes] = await Promise.all([
          supabase
            .from('user_devices')
            .select('*')
            .eq('workspace_id', resolvedWsId)
            .order('last_seen_at', { ascending: false }),
          supabase
            .from('tasks')
            .select('id, title, status, due_at, updated_at')
            .eq('workspace_id', resolvedWsId)
            .is('deleted_at', null),
          supabase
            .from('transactions')
            .select('id, type, amount, occurred_at, status, deleted_at')
            .eq('workspace_id', resolvedWsId)
            .eq('status', 'confirmed')
            .is('deleted_at', null)
            .gte('occurred_at', past7Iso),
        ]);

        if (!devRes.error && Array.isArray(devRes.data)) {
          setDevices(devRes.data as UserDeviceRow[]);
        } else {
          setDevices([]);
        }
        setDigestStats({
          tasks: (!digestTasksRes.error && Array.isArray(digestTasksRes.data) ? digestTasksRes.data : []) as Array<{ id: string; title: string; status: string; due_at?: string | null; updated_at?: string | null }>,
          transactions: (!digestTxRes.error && Array.isArray(digestTxRes.data) ? digestTxRes.data : []) as Array<{ id: string; type: 'income' | 'expense' | 'transfer'; amount: number; occurred_at: string; status?: string; deleted_at?: string | null }>,
        });
      }

      void Promise.allSettled([
        fetch('/api/push/status').then(async (res) =>
          res.ok ? ((await res.json()) as PushStatusPayload) : null
        ),
        typeof window !== 'undefined' && 'serviceWorker' in navigator
          ? navigator.serviceWorker.getRegistration('/')
          : Promise.resolve(undefined),
        supabase.rpc('fn_my_sessions'),
        supabase.auth.mfa.listFactors(),
      ]).then(([pushResult, swResult, sessionResult, factorsResult]) => {
        setPushStatus(pushResult.status === 'fulfilled' ? pushResult.value : null);

        if (typeof window !== 'undefined' && 'Notification' in window) {
          setBrowserNotifPerm(Notification.permission);
        }
        if (swResult.status === 'fulfilled') {
          setSwActive(Boolean(swResult.value));
        }

        if (sessionResult.status === 'fulfilled' && sessionResult.value.data) {
          setSessions(sessionResult.value.data);
        }

        if (factorsResult.status === 'fulfilled') {
          const verifiedTotp = factorsResult.value.data?.totp?.find(
            (f) => f.status === 'verified'
          );
          setHasMfa(!!verifiedTotp);
        }
      });
    } catch (err: unknown) {
      setLoadError(err instanceof Error ? err.message : 'Gagal memuat pengaturan akun.');
    } finally {
      setLoading(false);
    }
  }, [supabase]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  const weeklyDigestPreview = useMemo(
    () =>
      buildWeeklyDigestSummary({
        tasks: digestStats.tasks,
        transactions: digestStats.transactions,
        maskAmounts: privacyMode,
        workspaceName,
      }),
    [digestStats, privacyMode, workspaceName]
  );

  const handleSubscribeWebPush = async () => {
    setPushFeedback(null);
    if (!pushStatus?.configured || !pushStatus.publicKey) {
      setPushFeedback(
        pushStatus?.instructions ||
          'VAPID key belum dikonfigurasi pada server (status: needs_config).'
      );
      return;
    }
    if (
      typeof window === 'undefined' ||
      !('serviceWorker' in navigator) ||
      !('PushManager' in window)
    ) {
      setPushFeedback('Browser ini belum mendukung Web Push Manager.');
      return;
    }

    setSubscribingPush(true);
    try {
      let perm = Notification.permission;
      if (perm === 'default') {
        perm = await Notification.requestPermission();
        setBrowserNotifPerm(perm);
      }
      if (perm !== 'granted') {
        setPushFeedback('Izin notifikasi ditolak oleh browser.');
        return;
      }

      const reg = await navigator.serviceWorker.ready;
      const existingSub = await reg.pushManager.getSubscription();
      const sub =
        existingSub ||
        (await reg.pushManager.subscribe({
          userVisibleOnly: true,
          applicationServerKey: urlBase64ToUint8Array(pushStatus.publicKey),
        }));

      const res = await fetch('/api/push/subscribe', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          subscription: sub.toJSON(),
          deviceName: navigator.userAgent.slice(0, 80),
          workspaceId,
        }),
      });
      const json = (await res.json()) as { ok?: boolean; error?: string };
      if (!res.ok || !json.ok) {
        setPushFeedback(json.error || 'Gagal menyimpan langganan Web Push.');
        return;
      }
      setPushFeedback('Browser ini berhasil didaftarkan untuk menerima Web Push.');
      await loadData();
    } catch (err: unknown) {
      setPushFeedback(
        err instanceof Error ? err.message : 'Gagal berlangganan Web Push.'
      );
    } finally {
      setSubscribingPush(false);
    }
  };

  const handleTestWebPush = async () => {
    setPushFeedback(null);
    setTestingPush(true);
    try {
      const res = await fetch('/api/push/test', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ privacyMasked: privacyMode }),
      });
      const json = (await res.json()) as { message?: string; status?: string };
      setPushFeedback(
        json.message || 'Status pengujian Web Push diterima dari server.'
      );
    } catch {
      setPushFeedback('Gagal menghubungi endpoint uji Web Push.');
    } finally {
      setTestingPush(false);
    }
  };

  const handleDeleteDevice = async (deviceId: string) => {
    await supabase.from('user_devices').delete().eq('id', deviceId);
    await loadData();
  };

  const handleSavePin = async (e: React.FormEvent) => {
    e.preventDefault();
    setPinMsg(null);
    setPinErr(null);
    if (pinInput.trim() !== pinConfirm.trim()) {
      setPinErr('Konfirmasi PIN tidak cocok.');
      return;
    }
    const res = await setLockPin(pinInput);
    if (!res.ok) {
      setPinErr(res.error || 'Gagal menyimpan PIN lokal.');
      return;
    }
    setPinInput('');
    setPinConfirm('');
    setPinMsg('PIN kunci sesi berhasil disimpan dalam bentuk hash SHA-256 lokal.');
  };

  useEffect(() => {
    if (!loading && typeof window !== 'undefined') {
      const tab = new URLSearchParams(window.location.search).get('tab');
      if (tab === 'sumber' || tab === 'keamanan') {
        const target = document.getElementById(tab);
        if (target) {
          setTimeout(() => {
            target.scrollIntoView({ behavior: 'smooth', block: 'start' });
          }, 100);
        }
      }
    }
  }, [loading]);

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

  const handleCreateInvite = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!workspaceId) return;
    const normalizedEmail = inviteEmail.trim().toLowerCase();
    if (!normalizedEmail || !normalizedEmail.includes('@')) {
      setInviteErr('Masukkan alamat email yang valid.');
      return;
    }

    if (myWorkspaceRole !== 'owner') {
      setInviteErr('Hanya pemilik (owner) ruang kerja yang dapat membuat undangan.');
      return;
    }

    if (workspaceType !== 'shared') {
      setInviteErr(
        'Undangan anggota hanya didukung pada ruang kerja bertipe Berbagi (shared) sesuai aturan basis data.'
      );
      return;
    }

    setCreatingInvite(true);
    setInviteErr(null);
    setInviteMsg(null);

    try {
      const rawToken = window.crypto.randomUUID();
      const tokenHash = await sha256Hex(rawToken);
      const expiresAt = new Date(Date.now() + 7 * 86400_000).toISOString();

      const { data: inserted, error } = await supabase
        .from('workspace_invites')
        .insert({
          workspace_id: workspaceId,
          email: normalizedEmail,
          role: inviteRole,
          token_hash: tokenHash,
          expires_at: expiresAt,
        })
        .select('*')
        .single();

      if (error) {
        setInviteErr(error.message);
        return;
      }

      if (inserted) {
        const origin = typeof window !== 'undefined' ? window.location.origin : '';
        const inviteUrl = `${origin}/login?invite=${encodeURIComponent(rawToken)}`;
        setGeneratedLinks((prev) => ({ ...prev, [inserted.id]: inviteUrl }));
        setInvites((prev) => [inserted as WorkspaceInviteRow, ...prev]);
        setInviteMsg(`Undangan dibuat untuk ${normalizedEmail}. Salin tautan sebelum menutup halaman.`);
        setInviteEmail('');
      }
    } catch (err) {
      setInviteErr(err instanceof Error ? err.message : 'Gagal membuat undangan ruang kerja.');
    } finally {
      setCreatingInvite(false);
    }
  };

  const handleDeleteInvite = async (inviteId: string) => {
    if (myWorkspaceRole !== 'owner') return;
    const { error } = await supabase.from('workspace_invites').delete().eq('id', inviteId);
    if (error) {
      setInviteErr(error.message);
      return;
    }
    setInvites((prev) => prev.filter((item) => item.id !== inviteId));
  };

  const handleCopyInviteLink = async (inviteId: string, url: string) => {
    try {
      await navigator.clipboard.writeText(url);
      setCopiedInviteId(inviteId);
      setTimeout(() => setCopiedInviteId(null), 2000);
    } catch {
      setInviteErr('Tidak dapat mengakses clipboard browser. Salin tautan secara manual.');
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
          <Card id="profil">
            <CardHeader>
              <CardTitle className="flex items-center gap-2.5">
                <User className="w-4 h-4 text-primary" />
                <span>Pengaturan Profil</span>
              </CardTitle>
            </CardHeader>

            <CardContent className="space-y-4">
              {profileMsg && (
                <div className="p-3 text-xs rounded-lg bg-income-subtle text-income border border-income-border flex items-center gap-2">
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

          {/* Bagian Kolaborasi & Anggota Ruang Kerja */}
          <Card id="kolaborasi">
            <CardHeader className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
              <CardTitle className="flex items-center gap-2.5">
                <Users className="w-4 h-4 text-primary" />
                <span>Kolaborasi &amp; Anggota Ruang Kerja</span>
              </CardTitle>
              <div className="flex items-center gap-2">
                <StatusBadge variant={workspaceType === 'shared' ? 'income' : 'neutral'}>
                  {workspaceName} ({workspaceType === 'shared' ? 'Berbagi' : 'Pribadi'})
                </StatusBadge>
                <StatusBadge variant="neutral">Peran: {myWorkspaceRole}</StatusBadge>
              </div>
            </CardHeader>

            <CardContent className="space-y-5">
              {/* Daftar Anggota Aktif */}
              <div className="space-y-2">
                <h3 className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                  Anggota Ruang Kerja ({members.length})
                </h3>
                <div className="divide-y divide-border rounded-md border border-border">
                  {members.length === 0 ? (
                    <div className="p-4 text-xs text-muted-foreground">
                      Belum ada daftar anggota ruang kerja.
                    </div>
                  ) : (
                    members.map((m) => (
                      <div
                        key={`${m.workspace_id}-${m.user_id}`}
                        className="px-4 py-3 flex items-center justify-between gap-3 text-xs"
                      >
                        <div className="min-w-0 space-y-0.5">
                          <div className="font-semibold text-foreground truncate">
                            {m.display_name}
                            {currentUserId === m.user_id && currentUserEmail
                              ? ` (${currentUserEmail})`
                              : ''}
                          </div>
                          <div className="text-[11px] text-muted-foreground tabular-nums">
                            ID: {m.user_id.slice(0, 8)}... · Bergabung{' '}
                            {formatDateIndo(m.created_at)}
                          </div>
                        </div>
                        <StatusBadge variant={m.role === 'owner' ? 'income' : 'neutral'}>
                          {m.role}
                        </StatusBadge>
                      </div>
                    ))
                  )}
                </div>
              </div>

              {/* Form Undang Anggota */}
              <div className="pt-4 border-t border-border space-y-3">
                <div className="flex items-center gap-2">
                  <UserPlus className="w-4 h-4 text-primary" />
                  <h3 className="text-sm font-semibold text-foreground">Undang Anggota Baru</h3>
                </div>

                {inviteMsg && (
                  <div className="p-3 text-xs rounded-md bg-income-subtle text-income border border-income-border flex items-center gap-2">
                    <Check className="w-4 h-4 shrink-0" />
                    <span>{inviteMsg}</span>
                  </div>
                )}

                {inviteErr && (
                  <div className="p-3 text-xs rounded-md bg-expense-subtle text-expense border border-expense-border flex items-center gap-2">
                    <AlertCircle className="w-4 h-4 shrink-0" />
                    <span>{inviteErr}</span>
                  </div>
                )}

                {myWorkspaceRole !== 'owner' ? (
                  <div className="rounded-md border border-warning-border bg-warning-subtle p-3 text-xs text-warning">
                    Hanya pemilik (owner) ruang kerja yang memiliki izin membuat atau mengelola undangan anggota.
                  </div>
                ) : workspaceType !== 'shared' ? (
                  <div className="rounded-md border border-border bg-subtle p-3 text-xs text-muted-foreground">
                    Ruang kerja aktif bertipe <strong>Pribadi (personal)</strong>. Fitur undangan kolaborasi hanya aktif pada ruang kerja bertipe <strong>Berbagi (shared)</strong> sesuai kebijakan RLS basis data.
                  </div>
                ) : (
                  <form
                    onSubmit={handleCreateInvite}
                    className="grid grid-cols-1 sm:grid-cols-12 gap-3 items-end"
                  >
                    <div className="sm:col-span-6">
                      <label className="block text-xs font-medium text-foreground mb-1.5">
                        Email Anggota
                      </label>
                      <Input
                        type="email"
                        required
                        value={inviteEmail}
                        onChange={(e) => setInviteEmail(e.target.value)}
                        placeholder="rekan@contoh.com"
                      />
                    </div>
                    <div className="sm:col-span-3">
                      <label className="block text-xs font-medium text-foreground mb-1.5">
                        Peran
                      </label>
                      <Select
                        value={inviteRole}
                        onChange={(e) => setInviteRole(e.target.value as 'editor' | 'viewer')}
                      >
                        <option value="editor">Editor (Ubah data)</option>
                        <option value="viewer">Viewer (Baca saja)</option>
                      </Select>
                    </div>
                    <div className="sm:col-span-3">
                      <Button type="submit" className="w-full" disabled={creatingInvite}>
                        <UserPlus className="w-4 h-4" />
                        <span>{creatingInvite ? 'Membuat...' : 'Undang'}</span>
                      </Button>
                    </div>
                  </form>
                )}

                {/* Daftar Undangan Aktif */}
                {myWorkspaceRole === 'owner' && invites.length > 0 && (
                  <div className="space-y-2 pt-2">
                    <h4 className="text-xs font-semibold uppercase tracking-wider text-muted-foreground">
                      Undangan Aktif ({invites.length})
                    </h4>
                    <div className="divide-y divide-border rounded-md border border-border">
                      {invites.map((inv) => {
                        const readyLink = generatedLinks[inv.id];
                        return (
                          <div
                            key={inv.id}
                            className="px-4 py-3 flex flex-col sm:flex-row sm:items-center justify-between gap-2 text-xs"
                          >
                            <div className="space-y-0.5 min-w-0">
                              <div className="flex items-center gap-2 flex-wrap">
                                <span className="font-semibold text-foreground">{inv.email}</span>
                                <StatusBadge variant="neutral">{inv.role}</StatusBadge>
                                {inv.accepted_at ? (
                                  <StatusBadge variant="income">Diterima</StatusBadge>
                                ) : (
                                  <StatusBadge variant="warning">Menunggu</StatusBadge>
                                )}
                              </div>
                              <div className="text-[11px] text-muted-foreground tabular-nums">
                                Kedaluwarsa: {formatDateIndo(inv.expires_at)}
                              </div>
                            </div>

                            <div className="flex items-center gap-1.5 shrink-0">
                              {readyLink && (
                                <Button
                                  type="button"
                                  variant="secondary"
                                  size="sm"
                                  onClick={() => handleCopyInviteLink(inv.id, readyLink)}
                                >
                                  <Copy className="w-3.5 h-3.5" />
                                  <span>
                                    {copiedInviteId === inv.id ? 'Tersalin' : 'Salin Tautan'}
                                  </span>
                                </Button>
                              )}
                              <Button
                                type="button"
                                variant="ghost"
                                size="icon"
                                onClick={() => handleDeleteInvite(inv.id)}
                                aria-label={`Hapus undangan ${inv.email}`}
                              >
                                <Trash2 className="w-4 h-4 text-muted-foreground hover:text-expense" />
                              </Button>
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  </div>
                )}
              </div>
            </CardContent>
          </Card>

          {/* Bagian PWA & Web Push (#15) */}
          <Card id="pwa-push" data-testid="settings-pwa-card">
            <CardHeader>
              <CardTitle className="flex items-center gap-2.5">
                <Wifi className="w-4 h-4 text-primary" />
                <span>PWA &amp; Web Push Notification</span>
              </CardTitle>
              <StatusBadge
                variant={pushStatus?.status === 'ready' ? 'income' : 'warning'}
              >
                {pushStatus?.status === 'ready' ? 'VAPID Siap' : 'Perlu Konfigurasi VAPID'}
              </StatusBadge>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 text-xs">
                <div className="rounded-lg border border-border bg-subtle p-3">
                  <div className="text-muted-foreground">Service Worker</div>
                  <div className="font-semibold text-foreground mt-0.5">
                    {swActive ? 'Aktif (/sw.js)' : 'Menunggu Registrasi'}
                  </div>
                </div>
                <div className="rounded-lg border border-border bg-subtle p-3">
                  <div className="text-muted-foreground">Izin Notifikasi Browser</div>
                  <div className="font-semibold text-foreground mt-0.5 capitalize">
                    {browserNotifPerm === 'granted'
                      ? 'Diizinkan'
                      : browserNotifPerm === 'denied'
                        ? 'Ditolak'
                        : 'Belum Diminta'}
                  </div>
                </div>
                <div className="rounded-lg border border-border bg-subtle p-3">
                  <div className="text-muted-foreground">Status Server VAPID</div>
                  <div className="font-semibold text-foreground mt-0.5">
                    {pushStatus?.status === 'ready' ? 'Terkonfigurasi' : 'needs_config'}
                  </div>
                </div>
              </div>

              {pushStatus && !pushStatus.configured && (
                <div className="rounded-lg border border-warning-border bg-warning-subtle p-3.5 text-xs text-warning space-y-1">
                  <div className="font-semibold">
                    Konfigurasi VAPID Belum Aktif (needs_config)
                  </div>
                  <p>{pushStatus.instructions}</p>
                  {pushStatus.missingVars.length > 0 && (
                    <div className="font-mono text-[11px] text-foreground pt-1">
                      Variabel kosong: {pushStatus.missingVars.join(', ')}
                    </div>
                  )}
                </div>
              )}

              {pushFeedback && (
                <div className="rounded-md border border-border bg-subtle p-3 text-xs text-foreground">
                  {pushFeedback}
                </div>
              )}

              <div className="flex flex-wrap items-center gap-2.5">
                <Button
                  type="button"
                  onClick={handleSubscribeWebPush}
                  disabled={subscribingPush}
                >
                  <Bell className="w-4 h-4" />
                  <span>
                    {subscribingPush
                      ? 'Mendaftarkan...'
                      : 'Aktifkan Langganan Web Push'}
                  </span>
                </Button>
                <Button
                  type="button"
                  variant="secondary"
                  onClick={handleTestWebPush}
                  disabled={testingPush}
                >
                  <span>{testingPush ? 'Menguji...' : 'Uji Web Push'}</span>
                </Button>
                <Link
                  href="/offline"
                  className="min-h-11 inline-flex items-center rounded-md border border-border bg-card px-3.5 text-xs font-medium text-foreground hover:bg-hover transition-colors"
                >
                  Pratinjau Halaman Offline
                </Link>
              </div>

              {/* Daftar Perangkat Terdaftar (user_devices) */}
              <div className="pt-3 border-t border-border space-y-2.5">
                <div className="text-xs font-semibold text-foreground">
                  Perangkat Terdaftar (user_devices: {devices.length})
                </div>
                {devices.length === 0 ? (
                  <div className="rounded-md border border-dashed border-border p-4 text-xs text-muted-foreground">
                    Belum ada perangkat Web atau Android yang terdaftar pada workspace ini.
                  </div>
                ) : (
                  <div className="divide-y divide-border rounded-lg border border-border overflow-hidden">
                    {devices.map((d) => (
                      <div
                        key={d.id}
                        className="p-3 flex items-center justify-between gap-3 bg-card text-xs"
                      >
                        <div className="min-w-0 space-y-0.5">
                          <div className="flex items-center gap-2 flex-wrap">
                            <span className="font-semibold text-foreground truncate">
                              {d.device_name || `Perangkat ${d.platform}`}
                            </span>
                            <StatusBadge variant="neutral">{d.platform}</StatusBadge>
                          </div>
                          <div className="text-muted-foreground tabular-nums">
                            Terakhir aktif: {formatDateIndo(d.last_seen_at)}
                          </div>
                        </div>
                        <Button
                          type="button"
                          variant="ghost"
                          size="icon"
                          onClick={() => handleDeleteDevice(d.id)}
                          aria-label={`Hapus perangkat ${d.device_name || d.platform}`}
                        >
                          <Trash2 className="w-4 h-4 text-muted-foreground hover:text-expense" />
                        </Button>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </CardContent>
          </Card>

          {/* Bagian Mode Privasi & Kunci Sesi Web (#14) */}
          <Card id="privasi" data-testid="settings-privacy-card">
            <CardHeader>
              <CardTitle className="flex items-center gap-2.5">
                {privacyMode ? (
                  <EyeOff className="w-4 h-4 text-primary" />
                ) : (
                  <Eye className="w-4 h-4 text-primary" />
                )}
                <span>Mode Privasi Nominal &amp; Kunci Sesi Web</span>
              </CardTitle>
              <StatusBadge variant={privacyMode ? 'warning' : 'neutral'}>
                {privacyMode ? 'Nominal Disembunyikan' : 'Nominal Terlihat'}
              </StatusBadge>
            </CardHeader>
            <CardContent className="space-y-5">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 rounded-lg border border-border bg-subtle p-3.5">
                <div className="space-y-0.5">
                  <div className="text-xs font-semibold text-foreground">
                    Mode Privasi Nominal (Rp)
                  </div>
                  <div className="text-xs text-muted-foreground">
                    Menyembunyikan seluruh angka saldo, pemasukan, pengeluaran, dan anggaran menjadi <code className="font-mono text-foreground">Rp ••••••</code>.
                  </div>
                </div>
                <Button
                  type="button"
                  variant={privacyMode ? 'primary' : 'outline'}
                  onClick={() => setPrivacyMode(!privacyMode)}
                >
                  {privacyMode ? 'Matikan Mode Privasi' : 'Aktifkan Mode Privasi'}
                </Button>
              </div>

              <div className="border-t border-border pt-4 space-y-4">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div>
                    <div className="text-xs font-semibold text-foreground flex items-center gap-1.5">
                      <Lock className="w-3.5 h-3.5 text-primary" />
                      <span>Kunci Sesi Lokal dengan PIN (Hash SHA-256)</span>
                    </div>
                    <p className="text-xs text-muted-foreground mt-0.5">
                      PIN tidak pernah disimpan sebagai teks polos dan hanya diverifikasi secara lokal melalui Web Crypto SHA-256.
                    </p>
                  </div>
                  {hasPin && <StatusBadge variant="income">PIN Aktif</StatusBadge>}
                </div>

                {pinMsg && (
                  <div className="rounded-md border border-income-border bg-income-subtle p-3 text-xs text-income">
                    {pinMsg}
                  </div>
                )}
                {pinErr && (
                  <div className="rounded-md border border-expense-border bg-expense-subtle p-3 text-xs text-expense">
                    {pinErr}
                  </div>
                )}

                <form onSubmit={handleSavePin} className="grid grid-cols-1 sm:grid-cols-3 gap-3 max-w-2xl">
                  <div>
                    <label className="block text-xs font-medium text-foreground mb-1">
                      PIN Baru (4-8 digit)
                    </label>
                    <Input
                      type="password"
                      inputMode="numeric"
                      autoComplete="off"
                      placeholder="1234"
                      value={pinInput}
                      onChange={(e) => setPinInput(e.target.value)}
                    />
                  </div>
                  <div>
                    <label className="block text-xs font-medium text-foreground mb-1">
                      Ulangi PIN
                    </label>
                    <Input
                      type="password"
                      inputMode="numeric"
                      autoComplete="off"
                      placeholder="1234"
                      value={pinConfirm}
                      onChange={(e) => setPinConfirm(e.target.value)}
                    />
                  </div>
                  <div className="flex items-end">
                    <Button type="submit" className="w-full">
                      {hasPin ? 'Perbarui PIN' : 'Pasang PIN Lokal'}
                    </Button>
                  </div>
                </form>

                <div className="flex flex-wrap items-center gap-3">
                  <div className="w-56">
                    <label className="block text-xs font-medium text-foreground mb-1">
                      Kunci Otomatis Saat Idle
                    </label>
                    <Select
                      value={String(idleLockMinutes)}
                      onChange={(e) => setIdleLockMinutes(Number(e.target.value))}
                      aria-label="Durasi idle kunci sesi otomatis"
                    >
                      <option value="0">Manual saja (Nonaktif)</option>
                      <option value="5">5 menit tanpa aktivitas</option>
                      <option value="15">15 menit tanpa aktivitas</option>
                      <option value="30">30 menit tanpa aktivitas</option>
                    </Select>
                  </div>

                  {hasPin && (
                    <div className="flex flex-wrap items-end gap-2 pt-4">
                      <Button
                        type="button"
                        variant="secondary"
                        onClick={lockSessionNow}
                      >
                        <Lock className="w-3.5 h-3.5" />
                        <span>Kunci Sesi Sekarang</span>
                      </Button>
                      <Button
                        type="button"
                        variant="outline"
                        onClick={clearLockPin}
                      >
                        <span>Hapus PIN Lokal</span>
                      </Button>
                    </div>
                  )}
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Bagian Ringkasan Mingguan Email (#12) */}
          <Card id="ringkasan-mingguan">
            <CardHeader>
              <CardTitle className="flex items-center gap-2.5">
                <Sparkles className="w-4 h-4 text-primary" />
                <span>Ringkasan Mingguan (Siap Kirim Email)</span>
              </CardTitle>
              <span className="text-xs text-muted-foreground tabular-nums">
                {weeklyDigestPreview.periodLabel}
              </span>
            </CardHeader>
            <CardContent className="space-y-3">
              <ul className="space-y-1.5 text-xs text-muted-foreground list-disc pl-4">
                {weeklyDigestPreview.highlights.map((line, idx) => (
                  <li key={idx}>{line}</li>
                ))}
              </ul>
              <div className="flex flex-wrap items-center gap-2 pt-1">
                <Button
                  type="button"
                  variant="outline"
                  size="sm"
                  onClick={async () => {
                    await navigator.clipboard.writeText(weeklyDigestPreview.plainText);
                    setCopiedDigest(true);
                    setTimeout(() => setCopiedDigest(false), 2000);
                  }}
                >
                  <Copy className="w-3.5 h-3.5" />
                  <span>{copiedDigest ? 'Teks Disalin' : 'Salin Ringkasan'}</span>
                </Button>
                <a
                  href={weeklyDigestPreview.mailtoHref}
                  className="min-h-[36px] inline-flex items-center gap-1.5 rounded-md border border-border bg-card px-3 py-1.5 text-xs font-medium text-foreground hover:bg-hover transition-colors"
                >
                  <Mail className="w-3.5 h-3.5 text-primary" />
                  <span>Buka Draft Email</span>
                </a>
              </div>
            </CardContent>
          </Card>

          {/* Bagian Sumber Otomatis */}
          <Card id="sumber">
            <CardHeader>
              <CardTitle className="flex items-center gap-2.5">
                <Radio className="w-4 h-4 text-primary" />
                <span>Sumber Otomatis &amp; Impor Transaksi</span>
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <p className="text-xs text-muted-foreground">
                Status jujur sumber pencatatan otomatis: aplikasi web mendukung impor file mutasi CSV secara langsung, sedangkan penangkap notifikasi Android berjalan melalui aplikasi pendamping Android (Gelombang 3).
              </p>
              <div className="space-y-3 max-w-2xl">
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 p-3 rounded-md border border-border bg-subtle/50">
                  <div>
                    <div className="text-xs font-semibold text-foreground">
                      Impor Mutasi Rekening CSV (Web)
                    </div>
                    <div className="text-xs text-muted-foreground mt-0.5">
                      Unggah atau tempel mutasi bank (.csv pemisah koma/titik koma) dari halaman{' '}
                      <Link href="/transaksi" className="text-primary underline">
                        Transaksi
                      </Link>
                      .
                    </div>
                  </div>
                  <StatusBadge variant="income">Aktif di Web</StatusBadge>
                </div>

                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 p-3 rounded-md border border-border bg-subtle/50">
                  <div>
                    <div className="text-xs font-semibold text-foreground">
                      Listener Notifikasi SMS &amp; Aplikasi Bank Android
                    </div>
                    <div className="text-xs text-muted-foreground mt-0.5">
                      Parsing notifikasi lokal di perangkat Android untuk membuat draft Inbox (membutuhkan modul Android Gelombang 3).
                    </div>
                  </div>
                  <StatusBadge variant="warning">Gelombang 3 (Android)</StatusBadge>
                </div>

                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 p-3 rounded-md border border-border bg-subtle/50">
                  <div>
                    <div className="text-xs font-semibold text-foreground">
                      Penerusan Email Struk Pembayaran
                    </div>
                    <div className="text-xs text-muted-foreground mt-0.5">
                      Belum tersedia pada deployment web saat ini. Gunakan impor CSV atau catat manual di Transaksi.
                    </div>
                  </div>
                  <StatusBadge variant="neutral">Belum Tersedia</StatusBadge>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Bagian Ubah Kata Sandi */}
          <Card id="keamanan">
            <CardHeader>
              <CardTitle className="flex items-center gap-2.5">
                <Key className="w-4 h-4 text-primary" />
                <span>Kata Sandi Akun</span>
              </CardTitle>
            </CardHeader>

            <CardContent className="space-y-4">
              {passwordMsg && (
                <div className="p-3 text-xs rounded-lg bg-income-subtle text-income border border-income-border flex items-center gap-2">
                  <Check className="w-4 h-4" />
                  <span>{passwordMsg}</span>
                </div>
              )}

              {passwordErr && (
                <div className="p-3 text-xs rounded-lg bg-expense-subtle text-expense border border-expense-border flex items-center gap-2">
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
                <div className="p-3 text-xs rounded-lg bg-income-subtle text-income border border-income-border flex items-center gap-2">
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
                <div className="p-3 text-xs rounded-lg bg-expense-subtle text-expense border border-expense-border flex items-center gap-2">
                  <AlertCircle className="w-4 h-4" />
                  <span>{mfaError}</span>
                </div>
              )}

              {hasMfa ? (
                <div className="flex items-center justify-between p-4 border border-income-border bg-income-subtle rounded-lg">
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
                <div className="p-4 border border-border bg-subtle rounded-lg space-y-4 max-w-md">
                  <div className="text-sm font-semibold text-foreground">Scan QR Code Berikut:</div>
                  {qrCodeSvg && (
                    <div
                      className="p-3 bg-white w-fit rounded-lg border border-border"
                      dangerouslySetInnerHTML={{ __html: qrCodeSvg }}
                    />
                  )}
                  <div className="text-xs text-muted-foreground">
                    Atau masukkan kunci rahasia ini secara manual:{' '}
                    <code className="font-mono bg-card border border-border px-1.5 py-0.5 rounded select-all font-semibold text-foreground">
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
