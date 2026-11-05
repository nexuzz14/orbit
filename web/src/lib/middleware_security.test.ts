import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import { NextRequest } from 'next/server';
import { updateSession } from './supabase/middleware';

describe('Security: Authentication Bypass Guard in Middleware', () => {
  const originalNodeEnv = process.env.NODE_ENV;
  const originalBypass = process.env.E2E_AUTH_BYPASS;
  const originalUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const originalAnon = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  process.env.NEXT_PUBLIC_SUPABASE_URL = 'https://kpsfdqswoerzkicocvre.supabase.co';
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.dummy';

  test('In production (NODE_ENV=production), cookie orbit-e2e-user is ignored and redirects to /login', async () => {
    (process.env as any).NODE_ENV = 'production';
    process.env.E2E_AUTH_BYPASS = '1'; // Even if bypass is set, production must override

    const req = new NextRequest(new Request('http://localhost:3000/hari-ini', {
      headers: {
        cookie: 'orbit-e2e-user=true',
      },
    }));

    const res = await updateSession(req);
    // In production without genuine Supabase session, it must redirect to /login
    assert.equal(res.status, 307);
    assert.ok(res.headers.get('location')?.includes('/login'), 'Must redirect to /login');
  });

  test('When E2E_AUTH_BYPASS is not set or not "1", cookie orbit-e2e-user is ignored and redirects to /login', async () => {
    (process.env as any).NODE_ENV = 'development';
    delete process.env.E2E_AUTH_BYPASS;

    const req = new NextRequest(new Request('http://localhost:3000/hari-ini', {
      headers: {
        cookie: 'orbit-e2e-user=true',
      },
    }));

    const res = await updateSession(req);
    assert.equal(res.status, 307);
    assert.ok(res.headers.get('location')?.includes('/login'), 'Must redirect to /login');
  });

  test('When E2E_AUTH_BYPASS="0", cookie orbit-e2e-user is ignored and redirects to /login', async () => {
    (process.env as any).NODE_ENV = 'development';
    process.env.E2E_AUTH_BYPASS = '0';

    const req = new NextRequest(new Request('http://localhost:3000/hari-ini', {
      headers: {
        cookie: 'orbit-e2e-user=true',
      },
    }));

    const res = await updateSession(req);
    assert.equal(res.status, 307);
    assert.ok(res.headers.get('location')?.includes('/login'), 'Must redirect to /login');
  });

  test('Only when NODE_ENV !== "production" AND E2E_AUTH_BYPASS="1", cookie orbit-e2e-user grants bypass', async () => {
    (process.env as any).NODE_ENV = 'development';
    process.env.E2E_AUTH_BYPASS = '1';

    const req = new NextRequest(new Request('http://localhost:3000/hari-ini', {
      headers: {
        cookie: 'orbit-e2e-user=true',
      },
    }));

    const res = await updateSession(req);
    // When allowed, status is 200 (not redirected to /login)
    assert.equal(res.status, 200);
    assert.equal(res.headers.get('location'), null);
  });

  // Cleanup
  test('Restore environment variables', () => {
    (process.env as any).NODE_ENV = originalNodeEnv;
    if (originalBypass !== undefined) {
      process.env.E2E_AUTH_BYPASS = originalBypass;
    } else {
      delete process.env.E2E_AUTH_BYPASS;
    }
    process.env.NEXT_PUBLIC_SUPABASE_URL = originalUrl;
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY = originalAnon;
  });
});
