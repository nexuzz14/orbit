import { NextResponse, type NextRequest } from 'next/server';
import {
  GOOGLE_TOKEN_COOKIE,
  isGoogleCalendarConfigured,
  verifySignedPayload,
  type GoogleTokenPayload,
} from '@/lib/google-calendar-oauth';

export async function GET(request: NextRequest) {
  const configured = isGoogleCalendarConfigured();
  const tokenCookie = request.cookies.get(GOOGLE_TOKEN_COOKIE)?.value;
  const tokenPayload = configured
    ? verifySignedPayload<GoogleTokenPayload>(tokenCookie)
    : null;
  const hasToken = Boolean(tokenPayload?.access_token);

  return NextResponse.json({
    configured,
    connected: configured && hasToken,
    message: configured
      ? hasToken
        ? 'OAuth Google Calendar siap dan sesi token browser aktif.'
        : 'Kredensial server Google Calendar tersedia. Hubungkan akun Google Anda untuk memulai sinkronisasi.'
      : 'GOOGLE_CLIENT_ID dan GOOGLE_CLIENT_SECRET belum dikonfigurasi pada environment server. Impor dan ekspor file .ics tetap aktif 100% secara lokal.',
  });
}
