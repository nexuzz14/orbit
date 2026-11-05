import { test, expect } from '@playwright/test';
import * as path from 'path';

const outPath = path.resolve(__dirname, '../../docs/design/web-sidebar-1280x700.png');

test.describe('Fase D.1b Authenticated CSP, Hydration, and Sidebar 1280x700 Verification', () => {
  test.beforeEach(async ({ context, page }) => {
    // 1. Set cookie sesi uji lokal agar middleware Next.js mengizinkan akses ke rute terproteksi
    await context.addCookies([
      {
        name: 'orbit-e2e-user',
        value: 'true',
        domain: 'localhost',
        path: '/',
      },
    ]);

    // 2. Intersep semua panggilan API Supabase Auth & REST agar tidak memanggil Supabase Cloud
    await page.route('**/auth/v1/**', async (route) => {
      return route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({
          id: 'e2e-test-user-id',
          aud: 'authenticated',
          role: 'authenticated',
          email: 'e2e@test.local',
          app_metadata: { provider: 'email' },
          user_metadata: {},
          created_at: new Date().toISOString(),
        }),
      });
    });

    await page.route('**/rest/v1/**', async (route) => {
      const url = route.request().url();
      if (url.includes('workspace_members')) {
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ workspace_id: 'ws-e2e-test' }),
        });
      }
      if (url.includes('fn_agenda')) {
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify([]),
        });
      }
      if (url.includes('fn_detect_conflicts')) {
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify([]),
        });
      }
      if (url.includes('v_account_balances')) {
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify([]),
        });
      }
      if (url.includes('accounts')) {
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify([]),
        });
      }
      if (url.includes('categories')) {
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify([]),
        });
      }
      if (url.includes('projects')) {
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify([]),
        });
      }
      if (url.includes('tasks')) {
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify([]),
        });
      }
      if (url.includes('workspaces')) {
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ id: 'ws-e2e-test', month_start_day: 1, name: 'Workspace Uji' }),
        });
      }
      if (url.includes('v_budget_progress') || url.includes('budgets')) {
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify([]),
        });
      }
      if (url.includes('recurring_bills')) {
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify([]),
        });
      }
      if (url.includes('savings_goals')) {
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify([]),
        });
      }
      if (url.includes('expected_incomes')) {
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify([]),
        });
      }
      if (url.includes('transactions')) {
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify([]),
        });
      }
      if (route.request().method() === 'HEAD') {
        return route.fulfill({
          status: 200,
          headers: { 'content-range': '0-0/0' },
          body: '',
        });
      }
      return route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify([]),
      });
    });
  });

  const protectedRoutes = [
    '/hari-ini',
    '/transaksi',
    '/tugas',
    '/jadwal',
    '/anggaran',
    '/tagihan',
    '/tabungan',
    '/inbox',
    '/proyek',
    '/kategori',
    '/ringkasan',
    '/pengaturan',
    '/akun',
  ];

  for (const route of protectedRoutes) {
    test(`CSP and Hydration check on authenticated route: ${route}`, async ({ page }) => {
      const cspViolations: string[] = [];
      const pageErrors: Error[] = [];

      page.on('console', (msg) => {
        const text = msg.text();
        if (
          msg.type() === 'error' &&
          (text.toLowerCase().includes('content security policy') ||
            text.toLowerCase().includes('violates') ||
            text.toLowerCase().includes('refused to'))
        ) {
          cspViolations.push(text);
        }
      });

      page.on('pageerror', (err) => {
        pageErrors.push(err);
      });

      const response = await page.goto(route, { waitUntil: 'networkidle' });
      expect(response).not.toBeNull();

      // Pastikan tidak dialihkan kembali ke /login
      expect(page.url()).not.toContain('/login');
      expect(page.url()).toContain(route);

      // Pastikan CSP header terpasang
      const headers = response!.headers();
      expect(headers['content-security-policy']).toBeDefined();

      // Pastikan tidak ada pelanggaran CSP dan tidak ada runtime hydration error
      expect(cspViolations).toEqual([]);
      expect(pageErrors).toEqual([]);
    });
  }

  test('Sidebar viewport 1280x700 proves 5 Lainnya items and menu scrollability', async ({ page }) => {
    await page.setViewportSize({ width: 1280, height: 700 });
    await page.goto('/hari-ini', { waitUntil: 'networkidle' });

    // Pastikan sidebar terlihat
    const sidebar = page.locator('aside[aria-label="Navigasi utama desktop"]');
    await expect(sidebar).toBeVisible();

    const expectedItems = [
      'Kegiatan & Piutang',
      'Kategori & Aturan',
      'Sumber Otomatis',
      'Keamanan',
      'Pengaturan',
    ];

    for (const label of expectedItems) {
      const link = sidebar.getByRole('link', { name: label });
      await expect(link).toBeAttached();
      await link.scrollIntoViewIfNeeded();
      await expect(link).toBeVisible();
    }

    // Ambil screenshot sidebar dan dashboard pada viewport 1280x700
    await page.screenshot({ path: outPath });
    expect(page.url()).toContain('/hari-ini');
  });
});
