import crypto from 'node:crypto';
import { NextResponse, type NextRequest } from 'next/server';
import {
  GOOGLE_CALENDAR_SCOPE,
  GOOGLE_STATE_COOKIE,
  getGoogleRedirectUri,
  isGoogleCalendarConfigured,
  setSignedHttpOnlyCookie,
} from '@/lib/google-calendar-oauth';

export async function GET(request: NextRequest) {
  if (!isGoogleCalendarConfigured()) {
    return NextResponse.json(
      {
        error: 'google_oauth_unconfigured',
        message:
          'Sinkronisasi OAuth Google Calendar belum aktif karena GOOGLE_CLIENT_ID dan GOOGLE_CLIENT_SECRET belum diatur pada environment server.',
      },
      { status: 503 }
    );
  }

  const { searchParams } = new URL(request.url);
  const workspaceId = searchParams.get('workspace_id')?.trim() || '';
  const state = crypto.randomBytes(24).toString('hex');
  const redirectUri = getGoogleRedirectUri(request);

  const authUrl = new URL('https://accounts.google.com/o/oauth2/v2/auth');
  authUrl.searchParams.set('client_id', process.env.GOOGLE_CLIENT_ID!.trim());
  authUrl.searchParams.set('redirect_uri', redirectUri);
  authUrl.searchParams.set('response_type', 'code');
  authUrl.searchParams.set('scope', GOOGLE_CALENDAR_SCOPE);
  authUrl.searchParams.set('access_type', 'offline');
  authUrl.searchParams.set('prompt', 'consent');
  authUrl.searchParams.set('state', state);

  const response = NextResponse.redirect(authUrl.toString());
  setSignedHttpOnlyCookie(
    response,
    GOOGLE_STATE_COOKIE,
    { state, workspace_id: workspaceId },
    600
  );
  return response;
}
