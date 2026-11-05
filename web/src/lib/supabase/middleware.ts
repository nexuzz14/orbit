import { createServerClient } from '@supabase/ssr';
import { NextResponse, type NextRequest } from 'next/server';

export async function updateSession(request: NextRequest) {
  let response = NextResponse.next({
    request: {
      headers: request.headers,
    },
  });

  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!supabaseUrl || !supabaseAnonKey) {
    return response;
  }

  const supabase = createServerClient(supabaseUrl, supabaseAnonKey, {
    cookies: {
      getAll() {
        return request.cookies.getAll();
      },
      setAll(cookiesToSet: Array<{ name: string; value: string; options?: any }>) {
        cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
        response = NextResponse.next({
          request,
        });
        cookiesToSet.forEach(({ name, value, options }) =>
          response.cookies.set(name, value, options)
        );
      },
    },
  });

  // Keamanan ketat: Bypass autentikasi E2E HANYA aktif bila:
  // 1. process.env.NODE_ENV !== 'production'
  // 2. process.env.E2E_AUTH_BYPASS === '1'
  // Di luar dua kondisi ini (termasuk build produksi di Vercel), bypass dinonaktifkan secara absolut.
  const isE2EBypassAllowed =
    process.env.NODE_ENV !== 'production' &&
    process.env.E2E_AUTH_BYPASS === '1';

  const e2eUserCookie = isE2EBypassAllowed
    ? request.cookies.get('orbit-e2e-user')?.value
    : null;

  let user: any = null;

  if (e2eUserCookie) {
    user = { id: 'e2e-test-user-id', email: 'e2e@test.local' };
  } else {
    const {
      data: { user: authUser },
    } = await supabase.auth.getUser();
    user = authUser;
  }

  const isAuthPage = request.nextUrl.pathname.startsWith('/login') ||
    request.nextUrl.pathname.startsWith('/auth');

  if (!user && !isAuthPage && request.nextUrl.pathname !== '/') {
    const url = request.nextUrl.clone();
    url.pathname = '/login';
    return NextResponse.redirect(url);
  }

  if (user && isAuthPage && !request.nextUrl.pathname.startsWith('/auth/callback')) {
    const url = request.nextUrl.clone();
    url.pathname = '/hari-ini';
    return NextResponse.redirect(url);
  }

  return response;
}
