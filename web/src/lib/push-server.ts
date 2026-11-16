import type { NextRequest } from 'next/server';
import * as webpush from 'web-push';

export interface PushConfigStatus {
  configured: boolean;
  status: 'ready' | 'needs_config';
  publicKey: string | null;
  missingVars: string[];
  instructions: string;
}

export function getPushConfigStatus(): PushConfigStatus {
  const publicKey = process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY?.trim() || '';
  const privateKey = process.env.VAPID_PRIVATE_KEY?.trim() || '';
  const missingVars: string[] = [];

  if (!publicKey) {
    missingVars.push('NEXT_PUBLIC_VAPID_PUBLIC_KEY');
  }
  if (!privateKey) {
    missingVars.push('VAPID_PRIVATE_KEY');
  }

  const configured = missingVars.length === 0;
  return {
    configured,
    status: configured ? 'ready' : 'needs_config',
    publicKey: publicKey || null,
    missingVars,
    instructions: configured
      ? 'Kunci VAPID Web Push aktif dan siap mengirim notifikasi terenkripsi.'
      : 'Tambahkan NEXT_PUBLIC_VAPID_PUBLIC_KEY dan VAPID_PRIVATE_KEY pada environment server (misalnya lewat npx web-push generate-vapid-keys) untuk mengaktifkan Web Push nyata.',
  };
}

export function isSameOriginRequest(request: NextRequest): boolean {
  const secFetchSite = request.headers.get('sec-fetch-site');
  if (secFetchSite === 'cross-site') {
    return false;
  }
  const origin = request.headers.get('origin');
  if (!origin) {
    return true;
  }
  try {
    const originUrl = new URL(origin);
    const expectedHost = request.headers.get('host') || request.nextUrl.host;
    return originUrl.host === expectedHost;
  } catch {
    return false;
  }
}

export interface StoredPushSubscription {
  endpoint: string;
  expirationTime?: number | null;
  keys: {
    p256dh: string;
    auth: string;
  };
}

export async function sendWebPushNotification(
  subscription: StoredPushSubscription,
  payload: Record<string, unknown>
): Promise<{ ok: boolean; statusCode?: number; error?: string }> {
  const config = getPushConfigStatus();
  const privateKey = process.env.VAPID_PRIVATE_KEY?.trim() || '';
  const subject = process.env.VAPID_SUBJECT?.trim() || 'mailto:admin@orbit.local';

  if (!config.configured || !config.publicKey || !privateKey) {
    return {
      ok: false,
      error: config.instructions,
    };
  }

  webpush.setVapidDetails(subject, config.publicKey, privateKey);

  try {
    const result = await webpush.sendNotification(
      subscription,
      JSON.stringify(payload),
      { TTL: 60 }
    );
    return {
      ok: true,
      statusCode: result.statusCode,
    };
  } catch (err: unknown) {
    const statusCode =
      typeof err === 'object' && err !== null && 'statusCode' in err
        ? Number((err as { statusCode?: number }).statusCode)
        : undefined;
    const message =
      err instanceof Error ? err.message : 'Gagal mengirim Web Push.';
    return {
      ok: false,
      statusCode,
      error: message,
    };
  }
}
