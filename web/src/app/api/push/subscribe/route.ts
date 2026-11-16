import { NextResponse, type NextRequest } from 'next/server';
import { z } from 'zod';
import { createClient } from '@/lib/supabase/server';
import { isSameOriginRequest } from '@/lib/push-server';
import type { Json } from '@/types/database';

const SubscribeSchema = z.object({
  subscription: z.object({
    endpoint: z
      .string()
      .url()
      .refine((url) => url.startsWith('https://'), {
        message: 'Endpoint push wajib menggunakan HTTPS.',
      }),
    expirationTime: z.number().nullable().optional(),
    keys: z.object({
      p256dh: z.string().min(8),
      auth: z.string().min(8),
    }),
  }),
  deviceName: z.string().trim().min(1).max(120).optional(),
  workspaceId: z.string().uuid().optional(),
});

export async function POST(request: NextRequest) {
  if (!isSameOriginRequest(request)) {
    return NextResponse.json(
      { ok: false, error: 'Permintaan lintas origin ditolak.' },
      { status: 403 }
    );
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return NextResponse.json(
      { ok: false, error: 'Autentikasi diperlukan untuk mendaftarkan perangkat Web Push.' },
      { status: 401 }
    );
  }

  let bodyRaw: unknown;
  try {
    bodyRaw = await request.json();
  } catch {
    return NextResponse.json(
      { ok: false, error: 'Payload JSON tidak valid.' },
      { status: 400 }
    );
  }

  const parsed = SubscribeSchema.safeParse(bodyRaw);
  if (!parsed.success) {
    return NextResponse.json(
      { ok: false, error: 'Format langganan Web Push tidak valid.' },
      { status: 400 }
    );
  }

  const { subscription, deviceName, workspaceId } = parsed.data;

  const { data: memberships, error: memErr } = await supabase
    .from('workspace_members')
    .select('workspace_id')
    .eq('user_id', user.id);

  if (memErr || !memberships || memberships.length === 0) {
    return NextResponse.json(
      { ok: false, error: 'Workspace pengguna tidak ditemukan.' },
      { status: 404 }
    );
  }

  const allowedIds = memberships.map((m) => m.workspace_id);
  const targetWorkspaceId =
    workspaceId && allowedIds.includes(workspaceId)
      ? workspaceId
      : allowedIds[0];

  const nowIso = new Date().toISOString();
  const subscriptionJson = subscription as unknown as Json;
  const resolvedName = deviceName || 'Browser Web Orbit';

  const { data: existingRows } = await supabase
    .from('user_devices')
    .select('id, push_subscription')
    .eq('user_id', user.id)
    .eq('workspace_id', targetWorkspaceId)
    .eq('platform', 'web');

  const matchingRow = (existingRows ?? []).find((row) => {
    const sub = row.push_subscription as { endpoint?: string } | null;
    return sub?.endpoint === subscription.endpoint;
  });

  if (matchingRow) {
    const { error: updateErr } = await supabase
      .from('user_devices')
      .update({
        device_name: resolvedName,
        push_subscription: subscriptionJson,
        last_seen_at: nowIso,
        updated_at: nowIso,
      })
      .eq('id', matchingRow.id);

    if (updateErr) {
      return NextResponse.json(
        { ok: false, error: `Gagal memperbarui perangkat: ${updateErr.message}` },
        { status: 500 }
      );
    }

    return NextResponse.json({
      ok: true,
      updated: true,
      deviceId: matchingRow.id,
      workspaceId: targetWorkspaceId,
    });
  }

  const { data: inserted, error: insertErr } = await supabase
    .from('user_devices')
    .insert({
      user_id: user.id,
      workspace_id: targetWorkspaceId,
      platform: 'web',
      device_name: resolvedName,
      push_subscription: subscriptionJson,
      last_seen_at: nowIso,
    })
    .select('id')
    .single();

  if (insertErr) {
    return NextResponse.json(
      { ok: false, error: `Gagal menyimpan perangkat: ${insertErr.message}` },
      { status: 500 }
    );
  }

  return NextResponse.json({
    ok: true,
    updated: false,
    deviceId: inserted?.id ?? null,
    workspaceId: targetWorkspaceId,
  });
}

export async function DELETE(request: NextRequest) {
  if (!isSameOriginRequest(request)) {
    return NextResponse.json(
      { ok: false, error: 'Permintaan lintas origin ditolak.' },
      { status: 403 }
    );
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return NextResponse.json(
      { ok: false, error: 'Autentikasi diperlukan.' },
      { status: 401 }
    );
  }

  let endpoint: string | null = null;
  try {
    const body = (await request.json()) as { endpoint?: string };
    endpoint = typeof body?.endpoint === 'string' ? body.endpoint : null;
  } catch {
    endpoint = null;
  }

  const { data: rows } = await supabase
    .from('user_devices')
    .select('id, push_subscription')
    .eq('user_id', user.id)
    .eq('platform', 'web');

  const idsToDelete = (rows ?? [])
    .filter((row) => {
      if (!endpoint) return true;
      const sub = row.push_subscription as { endpoint?: string } | null;
      return sub?.endpoint === endpoint;
    })
    .map((r) => r.id);

  if (idsToDelete.length > 0) {
    await supabase.from('user_devices').delete().in('id', idsToDelete);
  }

  return NextResponse.json({ ok: true, removedCount: idsToDelete.length });
}
