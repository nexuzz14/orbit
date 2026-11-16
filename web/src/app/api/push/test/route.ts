import { NextResponse, type NextRequest } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import {
  getPushConfigStatus,
  isSameOriginRequest,
  sendWebPushNotification,
  type StoredPushSubscription,
} from '@/lib/push-server';

export async function POST(request: NextRequest) {
  if (!isSameOriginRequest(request)) {
    return NextResponse.json(
      { ok: false, sent: false, error: 'Permintaan lintas origin ditolak.' },
      { status: 403 }
    );
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return NextResponse.json(
      { ok: false, sent: false, error: 'Autentikasi diperlukan.' },
      { status: 401 }
    );
  }

  const config = getPushConfigStatus();
  if (!config.configured) {
    return NextResponse.json({
      ok: false,
      sent: false,
      status: 'needs_config',
      missingVars: config.missingVars,
      message: config.instructions,
    });
  }

  let privacyMasked = true;
  try {
    const body = (await request.json()) as { privacyMasked?: boolean };
    if (typeof body?.privacyMasked === 'boolean') {
      privacyMasked = body.privacyMasked;
    }
  } catch {
    privacyMasked = true;
  }

  const { data: devices, error: devErr } = await supabase
    .from('user_devices')
    .select('id, push_subscription')
    .eq('user_id', user.id)
    .eq('platform', 'web')
    .not('push_subscription', 'is', null);

  if (devErr) {
    return NextResponse.json(
      { ok: false, sent: false, status: 'error', message: devErr.message },
      { status: 500 }
    );
  }

  const validDevices = (devices ?? []).filter((d) => {
    const sub = d.push_subscription as Partial<StoredPushSubscription> | null;
    return Boolean(sub?.endpoint && sub?.keys?.p256dh && sub?.keys?.auth);
  });

  if (validDevices.length === 0) {
    return NextResponse.json({
      ok: false,
      sent: false,
      status: 'no_subscription',
      message: 'Belum ada browser terdaftar untuk Web Push di akun Anda.',
    });
  }

  let sentCount = 0;
  let failedCount = 0;
  const expiredIds: string[] = [];

  for (const device of validDevices) {
    const sub = device.push_subscription as unknown as StoredPushSubscription;
    const res = await sendWebPushNotification(sub, {
      title: privacyMasked
        ? 'Notifikasi Orbit'
        : 'Uji Web Push Orbit Berhasil',
      body: privacyMasked
        ? 'Ada pembaruan penting di ruang kerja Anda. Buka Orbit untuk melihat detail.'
        : 'Saluran Web Push terenkripsi VAPID aktif dan terhubung ke browser Anda.',
      privacyMasked,
      url: '/hari-ini',
      tag: 'orbit-test-push',
    });

    if (res.ok) {
      sentCount += 1;
    } else {
      failedCount += 1;
      if (res.statusCode === 404 || res.statusCode === 410) {
        expiredIds.push(device.id);
      }
    }
  }

  if (expiredIds.length > 0) {
    await supabase.from('user_devices').delete().in('id', expiredIds);
  }

  return NextResponse.json({
    ok: sentCount > 0,
    sent: sentCount > 0,
    status: sentCount > 0 ? 'sent' : 'failed',
    sentCount,
    failedCount,
    expiredCleaned: expiredIds.length,
    message:
      sentCount > 0
        ? `Uji Web Push terkirim ke ${sentCount} perangkat browser.`
        : 'Pengiriman Web Push gagal pada semua langganan terdaftar.',
  });
}
