import { NextResponse, type NextRequest } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import {
  GOOGLE_TOKEN_COOKIE,
  isGoogleCalendarConfigured,
  refreshGoogleAccessToken,
  setSignedHttpOnlyCookie,
  verifySignedPayload,
  type GoogleTokenPayload,
} from '@/lib/google-calendar-oauth';

interface GoogleEventItem {
  id: string;
  etag?: string;
  status?: string;
  summary?: string;
  description?: string;
  location?: string;
  start?: { date?: string; dateTime?: string };
  end?: { date?: string; dateTime?: string };
}

function toGoogleEventPayload(ev: {
  title: string;
  description: string | null;
  location: string | null;
  starts_at: string;
  ends_at: string;
  all_day: boolean;
}) {
  if (ev.all_day) {
    const startDate = ev.starts_at.slice(0, 10);
    const endDt = new Date(ev.ends_at);
    endDt.setUTCDate(endDt.getUTCDate() + 1);
    return {
      summary: ev.title,
      description: ev.description ?? undefined,
      location: ev.location ?? undefined,
      start: { date: startDate },
      end: { date: endDt.toISOString().slice(0, 10) },
    };
  }
  return {
    summary: ev.title,
    description: ev.description ?? undefined,
    location: ev.location ?? undefined,
    start: { dateTime: ev.starts_at, timeZone: 'Asia/Jakarta' },
    end: { dateTime: ev.ends_at, timeZone: 'Asia/Jakarta' },
  };
}

export async function POST(request: NextRequest) {
  if (!isGoogleCalendarConfigured()) {
    return NextResponse.json(
      {
        error: 'google_oauth_unconfigured',
        message:
          'Sinkronisasi Google Calendar membutuhkan GOOGLE_CLIENT_ID dan GOOGLE_CLIENT_SECRET pada environment server. Gunakan Ekspor / Impor .ics untuk sinkronisasi manual.',
      },
      { status: 503 }
    );
  }

  const rawCookie = request.cookies.get(GOOGLE_TOKEN_COOKIE)?.value;
  const parsedToken = verifySignedPayload<GoogleTokenPayload>(rawCookie);
  if (!parsedToken) {
    return NextResponse.json(
      {
        error: 'google_not_connected',
        message: 'Akun Google Calendar belum terhubung di sesi ini. Klik Hubungkan Google terlebih dahulu.',
      },
      { status: 401 }
    );
  }

  const activeToken = await refreshGoogleAccessToken(parsedToken);
  if (!activeToken) {
    return NextResponse.json(
      {
        error: 'google_token_expired',
        message: 'Sesi otorisasi Google Calendar telah kedaluwarsa. Hubungkan ulang akun Google Anda.',
      },
      { status: 401 }
    );
  }

  const body = (await request.json().catch(() => ({}))) as { workspace_id?: string };
  const workspaceId = body.workspace_id?.trim() || activeToken.workspace_id;
  if (!workspaceId) {
    return NextResponse.json(
      { error: 'missing_workspace', message: 'ID ruang kerja tidak ditemukan.' },
      { status: 400 }
    );
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) {
    return NextResponse.json({ error: 'unauthorized', message: 'Sesi pengguna tidak valid.' }, { status: 401 });
  }

  const headers = {
    Authorization: `Bearer ${activeToken.access_token}`,
    'Content-Type': 'application/json',
  };

  let pushed = 0;
  let pulled = 0;
  const nowIso = new Date().toISOString();

  // 1. Pull acara dari Google Calendar primary (30 hari lalu s.d. 90 hari ke depan)
  const timeMin = new Date(Date.now() - 30 * 86400_000).toISOString();
  const timeMax = new Date(Date.now() + 90 * 86400_000).toISOString();
  const listUrl = new URL('https://www.googleapis.com/calendar/v3/calendars/primary/events');
  listUrl.searchParams.set('singleEvents', 'true');
  listUrl.searchParams.set('maxResults', '100');
  listUrl.searchParams.set('timeMin', timeMin);
  listUrl.searchParams.set('timeMax', timeMax);

  const gRes = await fetch(listUrl.toString(), { headers });
  if (!gRes.ok) {
    return NextResponse.json(
      {
        error: 'google_api_error',
        message: `Gagal membaca Google Calendar (HTTP ${gRes.status}).`,
      },
      { status: 502 }
    );
  }

  const gJson = (await gRes.json()) as { items?: GoogleEventItem[]; nextSyncToken?: string };
  const gItems = gJson.items ?? [];

  for (const gItem of gItems) {
    if (!gItem.id || gItem.status === 'cancelled') continue;
    const isAllDay = Boolean(gItem.start?.date && !gItem.start?.dateTime);
    const startsAt = isAllDay
      ? new Date(`${gItem.start!.date}T00:00:00+07:00`).toISOString()
      : gItem.start?.dateTime;
    const endsAt = isAllDay
      ? new Date(`${gItem.end?.date ?? gItem.start!.date}T23:59:59+07:00`).toISOString()
      : gItem.end?.dateTime ?? startsAt;

    if (!startsAt || !endsAt) continue;

    const { data: existing } = await supabase
      .from('events')
      .select('id, external_etag')
      .eq('workspace_id', workspaceId)
      .eq('external_provider', 'google')
      .eq('external_event_id', gItem.id)
      .is('deleted_at', null)
      .maybeSingle();

    if (existing) {
      if (existing.external_etag !== gItem.etag) {
        await supabase
          .from('events')
          .update({
            title: gItem.summary?.trim() || 'Jadwal Google',
            description: gItem.description?.trim() || null,
            location: gItem.location?.trim() || null,
            starts_at: startsAt,
            ends_at: endsAt,
            all_day: isAllDay,
            external_etag: gItem.etag ?? null,
            last_synced_at: nowIso,
          })
          .eq('id', existing.id);
        pulled += 1;
      }
    } else {
      await supabase.from('events').insert({
        workspace_id: workspaceId,
        title: gItem.summary?.trim() || 'Jadwal Google',
        description: gItem.description?.trim() || null,
        location: gItem.location?.trim() || null,
        kind: 'pribadi',
        starts_at: startsAt,
        ends_at: endsAt,
        all_day: isAllDay,
        timezone: 'Asia/Jakarta',
        external_provider: 'google',
        external_event_id: gItem.id,
        external_etag: gItem.etag ?? null,
        last_synced_at: nowIso,
      });
      pulled += 1;
    }
  }

  // 2. Push event lokal yang belum pernah dikirim ke Google Calendar
  const { data: localUnsynced } = await supabase
    .from('events')
    .select('id, title, description, location, starts_at, ends_at, all_day')
    .eq('workspace_id', workspaceId)
    .is('external_event_id', null)
    .is('deleted_at', null)
    .gte('ends_at', timeMin)
    .limit(50);

  for (const ev of localUnsynced ?? []) {
    const pushRes = await fetch(
      'https://www.googleapis.com/calendar/v3/calendars/primary/events',
      {
        method: 'POST',
        headers,
        body: JSON.stringify(toGoogleEventPayload(ev)),
      }
    );
    if (pushRes.ok) {
      const created = (await pushRes.json()) as { id?: string; etag?: string };
      if (created.id) {
        await supabase
          .from('events')
          .update({
            external_provider: 'google',
            external_event_id: created.id,
            external_etag: created.etag ?? null,
            last_synced_at: nowIso,
          })
          .eq('id', ev.id);
        pushed += 1;
      }
    }
  }

  // 3. Perbarui metadata calendar_connections
  await supabase.from('calendar_connections').upsert(
    {
      user_id: user.id,
      workspace_id: workspaceId,
      provider: 'google',
      external_calendar_id: 'primary',
      sync_direction: 'two_way',
      sync_token: gJson.nextSyncToken?.slice(0, 500) ?? null,
      enabled: true,
      last_synced_at: nowIso,
    },
    { onConflict: 'user_id,workspace_id,provider,external_calendar_id' }
  );

  const response = NextResponse.json({
    ok: true,
    pulled,
    pushed,
    last_synced_at: nowIso,
    message: `Sinkronisasi selesai: ${pulled} masuk dari Google, ${pushed} dikirim ke Google.`,
  });

  if (activeToken.access_token !== parsedToken.access_token) {
    setSignedHttpOnlyCookie(response, GOOGLE_TOKEN_COOKIE, activeToken, 60 * 60 * 24 * 30);
  }

  return response;
}
