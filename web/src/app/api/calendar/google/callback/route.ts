import { NextResponse, type NextRequest } from 'next/server';
import { createClient } from '@/lib/supabase/server';
import {
  GOOGLE_STATE_COOKIE,
  GOOGLE_TOKEN_COOKIE,
  getGoogleRedirectUri,
  isGoogleCalendarConfigured,
  setSignedHttpOnlyCookie,
  verifySignedPayload,
  type GoogleOAuthStatePayload,
} from '@/lib/google-calendar-oauth';

export async function GET(request: NextRequest) {
  const { searchParams, origin } = new URL(request.url);
  const jadwalUrl = new URL('/jadwal', origin);

  if (!isGoogleCalendarConfigured()) {
    return NextResponse.json(
      {
        error: 'google_oauth_unconfigured',
        message:
          'GOOGLE_CLIENT_ID dan GOOGLE_CLIENT_SECRET belum diatur pada environment server.',
      },
      { status: 503 }
    );
  }

  const oauthError = searchParams.get('error');
  if (oauthError) {
    jadwalUrl.searchParams.set('google_sync', 'cancelled');
    return NextResponse.redirect(jadwalUrl.toString());
  }

  const code = searchParams.get('code');
  const returnedState = searchParams.get('state');
  const stateCookie = verifySignedPayload<GoogleOAuthStatePayload>(
    request.cookies.get(GOOGLE_STATE_COOKIE)?.value
  );

  if (!code || !returnedState || !stateCookie || stateCookie.state !== returnedState) {
    jadwalUrl.searchParams.set('google_sync', 'invalid_state');
    return NextResponse.redirect(jadwalUrl.toString());
  }

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      code,
      client_id: process.env.GOOGLE_CLIENT_ID!.trim(),
      client_secret: process.env.GOOGLE_CLIENT_SECRET!.trim(),
      redirect_uri: getGoogleRedirectUri(request),
      grant_type: 'authorization_code',
    }),
  });

  if (!tokenRes.ok) {
    jadwalUrl.searchParams.set('google_sync', 'token_exchange_failed');
    return NextResponse.redirect(jadwalUrl.toString());
  }

  const tokenData = (await tokenRes.json()) as {
    access_token?: string;
    refresh_token?: string;
    expires_in?: number;
  };

  if (!tokenData.access_token) {
    jadwalUrl.searchParams.set('google_sync', 'missing_token');
    return NextResponse.redirect(jadwalUrl.toString());
  }

  if (stateCookie.workspace_id) {
    try {
      const supabase = await createClient();
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (user) {
        await supabase.from('calendar_connections').upsert(
          {
            user_id: user.id,
            workspace_id: stateCookie.workspace_id,
            provider: 'google',
            external_calendar_id: 'primary',
            sync_direction: 'two_way',
            enabled: true,
          },
          { onConflict: 'user_id,workspace_id,provider,external_calendar_id' }
        );
      }
    } catch {
      // Tetap lanjut menyimpan token cookie; status koneksi DB akan diselaraskan saat sync
    }
  }

  jadwalUrl.searchParams.set('google_sync', 'connected');
  const response = NextResponse.redirect(jadwalUrl.toString());
  response.cookies.delete(GOOGLE_STATE_COOKIE);
  setSignedHttpOnlyCookie(
    response,
    GOOGLE_TOKEN_COOKIE,
    {
      access_token: tokenData.access_token,
      refresh_token: tokenData.refresh_token,
      expires_at: Date.now() + (tokenData.expires_in ?? 3600) * 1000,
      workspace_id: stateCookie.workspace_id || undefined,
    },
    60 * 60 * 24 * 30
  );

  return response;
}
