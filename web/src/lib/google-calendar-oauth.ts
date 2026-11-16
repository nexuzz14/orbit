import crypto from 'node:crypto';
import type { NextRequest, NextResponse } from 'next/server';

export const GOOGLE_TOKEN_COOKIE = 'orbit_google_calendar_token';
export const GOOGLE_STATE_COOKIE = 'orbit_google_oauth_state';
export const GOOGLE_CALENDAR_SCOPE = 'https://www.googleapis.com/auth/calendar.events';

export interface GoogleTokenPayload {
  access_token: string;
  refresh_token?: string;
  expires_at: number;
  workspace_id?: string;
}

export interface GoogleOAuthStatePayload {
  state: string;
  workspace_id: string;
}

export function isGoogleCalendarConfigured(): boolean {
  return Boolean(
    process.env.GOOGLE_CLIENT_ID?.trim() && process.env.GOOGLE_CLIENT_SECRET?.trim()
  );
}

export function getGoogleRedirectUri(request: NextRequest): string {
  const explicit = process.env.GOOGLE_CALENDAR_REDIRECT_URI?.trim();
  if (explicit) return explicit;
  const { origin } = new URL(request.url);
  const forwardedHost = request.headers.get('x-forwarded-host');
  const forwardedProto = request.headers.get('x-forwarded-proto') || 'https';
  const baseOrigin =
    process.env.NODE_ENV !== 'development' && forwardedHost
      ? `${forwardedProto}://${forwardedHost}`
      : origin;
  return `${baseOrigin}/api/calendar/google/callback`;
}

function getCookieSecret(): string {
  return (
    process.env.GOOGLE_CLIENT_SECRET?.trim() ||
    process.env.SUPABASE_SERVICE_ROLE_KEY?.trim() ||
    'orbit-local-fallback'
  );
}

export function signPayload(payload: object): string {
  const encoded = Buffer.from(JSON.stringify(payload), 'utf8').toString('base64url');
  const sig = crypto
    .createHmac('sha256', getCookieSecret())
    .update(encoded)
    .digest('base64url');
  return `${encoded}.${sig}`;
}

export function verifySignedPayload<T>(raw: string | undefined | null): T | null {
  if (!raw || !raw.includes('.')) return null;
  const [encoded, sig] = raw.split('.');
  if (!encoded || !sig) return null;
  const expected = crypto
    .createHmac('sha256', getCookieSecret())
    .update(encoded)
    .digest('base64url');
  try {
    const a = Buffer.from(sig);
    const b = Buffer.from(expected);
    if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) {
      return null;
    }
    return JSON.parse(Buffer.from(encoded, 'base64url').toString('utf8')) as T;
  } catch {
    return null;
  }
}

export function setSignedHttpOnlyCookie(
  response: NextResponse,
  name: string,
  payload: object,
  maxAgeSeconds: number
) {
  response.cookies.set(name, signPayload(payload), {
    httpOnly: true,
    sameSite: 'lax',
    secure: process.env.NODE_ENV === 'production',
    path: '/',
    maxAge: maxAgeSeconds,
  });
}

export async function refreshGoogleAccessToken(
  token: GoogleTokenPayload
): Promise<GoogleTokenPayload | null> {
  if (Date.now() < token.expires_at - 60_000) {
    return token;
  }
  if (!token.refresh_token || !isGoogleCalendarConfigured()) {
    return null;
  }

  const clientId = process.env.GOOGLE_CLIENT_ID!.trim();
  const clientSecret = process.env.GOOGLE_CLIENT_SECRET!.trim();

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      refresh_token: token.refresh_token,
      grant_type: 'refresh_token',
    }),
  });

  if (!res.ok) return null;
  const data = (await res.json()) as {
    access_token?: string;
    expires_in?: number;
  };
  if (!data.access_token) return null;

  return {
    ...token,
    access_token: data.access_token,
    expires_at: Date.now() + (data.expires_in ?? 3600) * 1000,
  };
}
