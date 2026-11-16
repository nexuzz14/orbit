import { test, expect, type Page } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';

const ARTIFACT_DIR =
  process.env.ORBIT_ARTIFACT_DIR ||
  path.resolve(__dirname, '../test-results/artifacts');
const WS_ID = 'ws-orbit-wave3';
const USER_ID = 'e2e-wave3-owner';

function toWibDateStr(offsetDays = 0): string {
  const dt = new Date(Date.now() + 7 * 3600_000 + offsetDays * 86400_000);
  return dt.toISOString().slice(0, 10);
}

function isoAtWib(offsetDays: number, hour: number, minute = 0): string {
  const day = toWibDateStr(offsetDays);
  return new Date(
    `${day}T${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}:00+07:00`
  ).toISOString();
}

function getWibDayOfMonth(offsetDays = 0): number {
  const dt = new Date(Date.now() + 7 * 3600_000 + offsetDays * 86400_000);
  return dt.getUTCDate();
}

async function setupWave3MockApi(page: Page) {
  const todayStr = toWibDateStr(0);

  const workspaces = [
    {
      id: WS_ID,
      name: 'Orbit Wave 3 Studio',
      type: 'shared',
      base_currency: 'IDR',
      owner_id: USER_ID,
      created_at: isoAtWib(-30, 8),
      updated_at: isoAtWib(-1, 8),
    },
  ];

  const workspaceMembers = [
    {
      workspace_id: WS_ID,
      user_id: USER_ID,
      role: 'owner',
      created_at: isoAtWib(-30, 8),
      updated_at: isoAtWib(-30, 8),
      workspaces: workspaces[0],
    },
  ];

  const profiles = [
    {
      id: USER_ID,
      display_name: 'Nadia Pratama',
      base_currency: 'IDR',
      timezone: 'Asia/Jakarta',
      month_start_day: 1,
      created_at: isoAtWib(-30, 8),
      updated_at: isoAtWib(-1, 8),
    },
  ];

  const accounts = [
    {
      id: 'acc-bca',
      workspace_id: WS_ID,
      name: 'BCA Tabungan',
      type: 'bank',
      currency: 'IDR',
      opening_balance: 7500000,
      archived: false,
      visibility: 'shared',
      sort_order: 1,
      deleted_at: null,
    },
  ];

  const categories = [
    {
      id: 'cat-inc-1',
      workspace_id: WS_ID,
      name: 'Proyek Freelance',
      type: 'income',
      archived: false,
      deleted_at: null,
    },
    {
      id: 'cat-exp-1',
      workspace_id: WS_ID,
      name: 'Konsumsi',
      type: 'expense',
      archived: false,
      deleted_at: null,
    },
  ];

  const projects = [
    {
      id: 'proj-1',
      workspace_id: WS_ID,
      kind: 'freelance',
      name: 'Portal Analitik Klien',
      description: 'Proyek dashboard keuangan web',
      status: 'berjalan',
      started_on: toWibDateStr(-14),
      deadline: toWibDateStr(14),
      color: '#0284C7',
      tags: ['web'],
      client_name: 'PT Nusantara Digital',
      contract_value: 15000000,
      currency: 'IDR',
      platform_fee_percent: 5,
      fee_mode: 'expense_transaction',
      deleted_at: null,
      archived: false,
    },
  ];

  const transactions: Array<Record<string, unknown>> = [
    {
      id: 'tx-confirmed-1',
      workspace_id: WS_ID,
      account_id: 'acc-bca',
      category_id: 'cat-inc-1',
      type: 'income',
      amount: 4500000,
      amount_base: 4500000,
      currency: 'IDR',
      merchant: 'PT Nusantara Digital',
      note: 'Termin 1 Proyek Portal',
      occurred_at: isoAtWib(-1, 14),
      source: 'freelance',
      status: 'confirmed',
      origin: 'manual',
      draft_state: null,
      deleted_at: null,
    },
    {
      id: 'tx-confirmed-2',
      workspace_id: WS_ID,
      account_id: 'acc-bca',
      category_id: 'cat-exp-1',
      type: 'expense',
      amount: 325000,
      amount_base: 325000,
      currency: 'IDR',
      merchant: 'Kopi Kenangan Sudirman',
      note: 'Rapat Klien',
      occurred_at: isoAtWib(0, 10),
      source: 'personal',
      status: 'confirmed',
      origin: 'manual',
      draft_state: null,
      deleted_at: null,
    },
  ];

  const events: Array<Record<string, unknown>> = [
    {
      id: 'ev-conflict-1',
      workspace_id: WS_ID,
      title: 'Review Sprint Web',
      description: 'Tinjau capaian Gelombang 3',
      kind: 'freelance',
      starts_at: isoAtWib(1, 9, 0),
      ends_at: isoAtWib(1, 10, 30),
      all_day: false,
      location: 'Google Meet',
      deleted_at: null,
    },
    {
      id: 'ev-conflict-2',
      workspace_id: WS_ID,
      title: 'Sinkronisasi Desain',
      description: 'Bentrok jadwal dengan Review Sprint',
      kind: 'intern',
      starts_at: isoAtWib(1, 10, 0),
      ends_at: isoAtWib(1, 11, 30),
      all_day: false,
      location: 'Ruang Rapat B',
      deleted_at: null,
    },
  ];

  const tasks: Array<Record<string, unknown>> = [
    {
      id: 'task-done-1',
      workspace_id: WS_ID,
      project_id: 'proj-1',
      kind: 'freelance',
      title: 'Rilis Audit Keamanan CSP',
      description: null,
      status: 'done',
      priority: 'tinggi',
      due_at: isoAtWib(-2, 17),
      due_is_date_only: false,
      progress_percent: 100,
      progress_mode: 'manual',
      revision_count: 0,
      updated_at: isoAtWib(-2, 16),
      created_at: isoAtWib(-6, 9),
      sort_order: 1,
      deleted_at: null,
      projects: { name: 'Portal Analitik Klien' },
      task_checklist_items: [],
    },
    {
      id: 'task-overdue-1',
      workspace_id: WS_ID,
      project_id: 'proj-1',
      kind: 'freelance',
      title: 'Kirim Invoice Termin Kedua',
      description: null,
      status: 'doing',
      priority: 'tinggi',
      due_at: isoAtWib(-1, 17),
      due_is_date_only: false,
      progress_percent: 60,
      progress_mode: 'manual',
      revision_count: 0,
      updated_at: isoAtWib(-1, 12),
      created_at: isoAtWib(-5, 9),
      sort_order: 2,
      deleted_at: null,
      projects: { name: 'Portal Analitik Klien' },
      task_checklist_items: [],
    },
    {
      id: 'task-stagnant-1',
      workspace_id: WS_ID,
      project_id: 'proj-1',
      kind: 'kuliah',
      title: 'Revisi Bab 3 Metodologi',
      description: null,
      status: 'todo',
      priority: 'sedang',
      due_at: isoAtWib(3, 18),
      due_is_date_only: false,
      progress_percent: 20,
      progress_mode: 'manual',
      revision_count: 0,
      updated_at: isoAtWib(-7, 9),
      created_at: isoAtWib(-10, 9),
      sort_order: 3,
      deleted_at: null,
      projects: { name: 'Portal Analitik Klien' },
      task_checklist_items: [],
    },
  ];

  const budgets = [
    {
      budget_id: 'bud-1',
      workspace_id: WS_ID,
      category_id: 'cat-exp-1',
      category_name: 'Konsumsi',
      effective_budget_amount: 1000000,
      spent_amount: 860000,
      percentage_spent: 86,
      is_over_budget: false,
      is_warning: true,
      notify_at_percent: 80,
      remaining_amount: 140000,
    },
  ];

  const bills = [
    {
      id: 'bill-1',
      workspace_id: WS_ID,
      name: 'Internet Fiber Studio',
      amount: 385000,
      currency: 'IDR',
      active: true,
      schedule_type: 'monthly',
      schedule_value: getWibDayOfMonth(2),
      remind_days_before: [3],
      deleted_at: null,
    },
  ];

  const userDevices = [
    {
      id: 'dev-web-1',
      user_id: USER_ID,
      workspace_id: WS_ID,
      platform: 'web',
      device_name: 'Chromium Desktop Orbit',
      fcm_token: null,
      push_subscription: { endpoint: 'https://push.example.invalid/web-1' },
      last_seen_at: isoAtWib(0, 9),
      created_at: isoAtWib(-5, 9),
      updated_at: isoAtWib(0, 9),
    },
    {
      id: 'dev-android-1',
      user_id: USER_ID,
      workspace_id: WS_ID,
      platform: 'android',
      device_name: 'Android Orbit Companion',
      fcm_token: 'mock-fcm-token',
      push_subscription: null,
      last_seen_at: isoAtWib(-1, 18),
      created_at: isoAtWib(-10, 9),
      updated_at: isoAtWib(-1, 18),
    },
  ];

  await page.route('**/auth/v1/**', async (route) => {
    const pathname = new URL(route.request().url()).pathname;
    if (pathname.endsWith('/factors')) {
      return route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ all: [], totp: [] }),
      });
    }
    return route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        id: USER_ID,
        aud: 'authenticated',
        role: 'authenticated',
        email: 'nadia@orbit.local',
        app_metadata: { provider: 'email' },
        user_metadata: { display_name: 'Nadia Pratama' },
        created_at: isoAtWib(-30, 8),
      }),
    });
  });

  await page.route('**/rest/v1/**', async (route) => {
    const req = route.request();
    const method = req.method();
    const url = new URL(req.url());
    const pathname = url.pathname;
    const accept = req.headers()['accept'] ?? '';
    const wantsObject = accept.includes('vnd.pgrst.object');

    const respond = (data: unknown) => {
      if (method === 'HEAD') {
        return route.fulfill({
          status: 200,
          headers: {
            'content-range': Array.isArray(data)
              ? `0-${Math.max(0, data.length - 1)}/${data.length}`
              : '0-0/1',
          },
          body: '',
        });
      }
      if (wantsObject && Array.isArray(data)) {
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify(data[0] ?? null),
        });
      }
      return route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify(data),
      });
    };

    if (pathname.endsWith('/rpc/fn_agenda')) {
      return respond([
        ...events.map((e) => ({
          id: String(e.id),
          item_type: 'event',
          title: String(e.title),
          kind: String(e.kind),
          starts_at: String(e.starts_at),
          ends_at: String(e.ends_at),
          all_day: Boolean(e.all_day),
          location: e.location ? String(e.location) : null,
          status: null,
          priority: null,
          is_recurring: false,
          event_id: String(e.id),
        })),
      ]);
    }

    if (pathname.endsWith('/rpc/fn_detect_conflicts')) {
      return respond([]);
    }

    if (pathname.endsWith('/rpc/fn_my_sessions')) {
      return respond([
        {
          id: 'sess-wave3-1',
          created_at: isoAtWib(-1, 8),
          updated_at: isoAtWib(0, 8),
          user_agent: 'Chromium Playwright Desktop',
          aal: 'aal1',
          is_current: true,
        },
      ]);
    }

    if (pathname.endsWith('/rpc/fn_global_search')) {
      return respond([]);
    }

    if (pathname.endsWith('/workspaces')) {
      return respond(wantsObject ? workspaces[0] : workspaces);
    }

    if (pathname.endsWith('/workspace_members')) {
      return respond(wantsObject ? workspaceMembers[0] : workspaceMembers);
    }

    if (pathname.endsWith('/profiles')) {
      return respond(wantsObject ? profiles[0] : profiles);
    }

    if (pathname.endsWith('/notification_settings')) {
      return respond({
        workspace_id: WS_ID,
        budget_warning_enabled: true,
        budget_exceeded_enabled: true,
        bills_reminder_enabled: true,
        receivables_reminder_enabled: true,
        daily_summary_time: '08:00',
      });
    }

    if (pathname.endsWith('/accounts')) {
      return respond(accounts);
    }

    if (pathname.endsWith('/categories')) {
      return respond(categories);
    }

    if (pathname.endsWith('/projects')) {
      return respond(projects);
    }

    if (pathname.endsWith('/project_payments')) {
      return respond([]);
    }

    if (pathname.endsWith('/v_receivables')) {
      return respond([]);
    }

    if (pathname.endsWith('/v_account_balances')) {
      return respond([
        {
          account_id: 'acc-bca',
          workspace_id: WS_ID,
          name: 'BCA Tabungan',
          type: 'bank',
          currency: 'IDR',
          balance: 11675000,
          is_liquid: true,
          archived: false,
          visibility: 'shared',
          last_txn_at: isoAtWib(0, 10),
        },
      ]);
    }

    if (pathname.endsWith('/v_monthly_summary')) {
      return respond([
        {
          workspace_id: WS_ID,
          month_start: `${todayStr.slice(0, 7)}-01`,
          month_end: todayStr,
          currency: 'IDR',
          source: null,
          is_total: true,
          income: 4500000,
          expense: 325000,
          net: 4175000,
          txn_count: 2,
        },
      ]);
    }

    if (pathname.endsWith('/v_monthly_source_summary')) {
      return respond([
        {
          workspace_id: WS_ID,
          month_start: `${todayStr.slice(0, 7)}-01`,
          source: 'freelance',
          currency: 'IDR',
          income: 4500000,
          expense: 0,
          net: 4500000,
          txn_count: 1,
        },
        {
          workspace_id: WS_ID,
          month_start: `${todayStr.slice(0, 7)}-01`,
          source: 'personal',
          currency: 'IDR',
          income: 0,
          expense: 325000,
          net: -325000,
          txn_count: 1,
        },
      ]);
    }

    if (pathname.endsWith('/v_monthly_category_summary')) {
      return respond([
        {
          workspace_id: WS_ID,
          month_start: `${todayStr.slice(0, 7)}-01`,
          category_id: 'cat-exp-1',
          category_name: 'Konsumsi',
          type: 'expense',
          total: 325000,
          txn_count: 1,
        },
        {
          workspace_id: WS_ID,
          month_start: `${todayStr.slice(0, 7)}-01`,
          category_id: 'cat-inc-1',
          category_name: 'Proyek Freelance',
          type: 'income',
          total: 4500000,
          txn_count: 1,
        },
      ]);
    }

    if (pathname.endsWith('/v_budget_progress')) {
      return respond(budgets);
    }

    if (pathname.endsWith('/recurring_bills')) {
      return respond(bills);
    }

    if (pathname.endsWith('/events')) {
      return respond(events);
    }

    if (pathname.endsWith('/tasks')) {
      return respond(tasks);
    }

    if (pathname.endsWith('/user_devices')) {
      if (method === 'DELETE') {
        const idEq = url.searchParams.get('id')?.replace('eq.', '');
        const idx = userDevices.findIndex((d) => d.id === idEq);
        if (idx >= 0) userDevices.splice(idx, 1);
        return respond([]);
      }
      return respond(userDevices);
    }

    if (pathname.endsWith('/transactions')) {
      if (method === 'POST') {
        const raw = req.postDataJSON();
        const items = Array.isArray(raw) ? raw : [raw];
        const created = items.map((item, idx) => ({
          id: `tx-draft-${transactions.length + idx + 1}`,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
          deleted_at: null,
          ...item,
        }));
        transactions.unshift(...created);
        return respond(wantsObject ? created[0] : created);
      }
      const statusEq = url.searchParams.get('status');
      let list = [...transactions];
      if (statusEq === 'eq.draft') {
        list = list.filter((t) => t.status === 'draft');
      } else if (statusEq === 'eq.confirmed') {
        list = list.filter((t) => t.status === 'confirmed');
      }
      return respond(list);
    }

    return respond([]);
  });

  const ssrSessionPayload = {
    access_token: 'e2e-wave3-access-token',
    refresh_token: 'e2e-wave3-refresh-token',
    token_type: 'bearer',
    expires_in: 86400,
    expires_at: Math.floor(Date.now() / 1000) + 86400,
    user: {
      id: USER_ID,
      aud: 'authenticated',
      role: 'authenticated',
      email: 'nadia@orbit.local',
      app_metadata: { provider: 'email' },
      user_metadata: { display_name: 'Nadia Pratama' },
    },
  };
  const ssrCookieValue = `base64-${Buffer.from(JSON.stringify(ssrSessionPayload)).toString('base64url')}`;

  await page.context().addCookies([
    {
      name: 'orbit-e2e-user',
      value: 'true',
      domain: 'localhost',
      path: '/',
    },
    {
      name: 'sb-kpsfdqswoerzkicocvre-auth-token',
      value: ssrCookieValue,
      domain: 'localhost',
      path: '/',
    },
  ]);
}

async function captureScreen(page: Page, filename: string) {
  fs.mkdirSync(ARTIFACT_DIR, { recursive: true });
  await page.screenshot({
    path: path.join(ARTIFACT_DIR, filename),
    fullPage: true,
  });
}

test.describe('Orbit Web v2 Gelombang 3 Features', () => {
  test('1. Mode Privasi Nominal menyembunyikan Rp di /hari-ini, /transaksi, /ringkasan lalu mengembalikannya', async ({
    page,
  }) => {
    await setupWave3MockApi(page);

    await page.goto('/hari-ini', { waitUntil: 'networkidle' });
    await expect(page.getByText('Rp 11.675.000')).toBeVisible();

    const toggleBtn = page.getByTestId('privacy-mode-toggle');
    await expect(toggleBtn).toBeVisible();
    const btnBox = await toggleBtn.boundingBox();
    expect(btnBox).not.toBeNull();
    expect(btnBox!.width).toBeGreaterThanOrEqual(44);
    expect(btnBox!.height).toBeGreaterThanOrEqual(44);

    // Aktifkan Mode Privasi
    await toggleBtn.click();
    await expect(page.getByText('Rp 11.675.000')).toHaveCount(0);
    await expect(page.getByText('Rp ••••••').first()).toBeVisible();

    // Periksa sinkronisasi di /transaksi
    await page.goto('/transaksi', { waitUntil: 'networkidle' });
    await expect(page.getByText('Rp 4.500.000')).toHaveCount(0);
    await expect(page.getByText('Rp ••••••').first()).toBeVisible();

    // Periksa sinkronisasi di /ringkasan dan tangkap screenshot Mode Privasi aktif
    await page.goto('/ringkasan', { waitUntil: 'networkidle' });
    await expect(page.getByText('Rp 4.500.000')).toHaveCount(0);
    await expect(page.getByText('Rp ••••••').first()).toBeVisible();
    await captureScreen(page, 'wave3-web-privacy-mode.png');

    // Matikan Mode Privasi dan pastikan nominal kembali
    await page.getByTestId('privacy-mode-toggle').click();
    await expect(page.getByText('Rp 4.500.000').first()).toBeVisible();
  });

  test('2. /manifest.webmanifest, /sw.js, /offline, dan quick shortcuts merespons normal bebas CSP', async ({
    page,
    request,
  }) => {
    const manifestRes = await request.get('/manifest.webmanifest');
    expect(manifestRes.status()).toBe(200);
    const manifestCsp = manifestRes.headers()['content-security-policy'] || '';
    expect(manifestCsp).toContain("manifest-src 'self'");
    expect(manifestCsp).toContain("worker-src 'self'");
    const manifestJson = await manifestRes.json();
    expect(manifestJson.name).toBe('Orbit - Productivity & Finance');
    expect(manifestJson.short_name).toBe('Orbit');
    expect(manifestJson.start_url).toBe('/hari-ini');
    expect(manifestJson.theme_color).toBe('#0284C7');
    expect(Array.isArray(manifestJson.shortcuts)).toBe(true);
    expect(manifestJson.shortcuts.length).toBe(4);
    const shortcutUrls = manifestJson.shortcuts.map((s: { url: string }) => s.url);
    expect(shortcutUrls).toContain('/transaksi?quick=new');
    expect(shortcutUrls).toContain('/tugas?quick=new');
    expect(shortcutUrls).toContain('/inbox');

    for (const icon of manifestJson.icons) {
      const iconRes = await request.get(icon.src);
      expect(iconRes.status()).toBe(200);
    }

    const swRes = await request.get('/sw.js');
    expect(swRes.status()).toBe(200);
    const swText = await swRes.text();
    expect(swText).toContain('/offline');
    expect(swText).toContain('supabase.co');
    expect(swText).toContain("addEventListener('push'");
    expect(swText).toContain("addEventListener('notificationclick'");

    // Uji /offline pada mode gelap tanpa redirect login & bebas CSP error
    const cspErrors: string[] = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error' && msg.text().toLowerCase().includes('content security policy')) {
        cspErrors.push(msg.text());
      }
    });
    await page.addInitScript(() => {
      window.localStorage.setItem('orbit_theme', 'dark');
    });
    await page.goto('/offline', { waitUntil: 'networkidle' });
    await expect(page.getByRole('heading', { name: 'Anda sedang offline' })).toBeVisible();
    await expect(page.locator('html')).toHaveClass(/dark/);
    expect(cspErrors).toEqual([]);
    await captureScreen(page, 'wave3-web-offline-dark.png');

    // Uji quick shortcut ?quick=new membuka dialog cepat di /transaksi dan /tugas
    await setupWave3MockApi(page);
    await page.goto('/transaksi?quick=new', { waitUntil: 'networkidle' });
    await expect(page.getByRole('dialog')).toBeVisible({ timeout: 20000 });

    await page.goto('/tugas?quick=new', { waitUntil: 'networkidle' });
    await expect(page.getByRole('dialog')).toBeVisible({ timeout: 20000 });
  });

  test('3. /hari-ini menampilkan Pengingat Cerdas & Ringkasan Mingguan; /pengaturan menampilkan PWA/Push, user_devices & PIN', async ({
    page,
  }) => {
    await setupWave3MockApi(page);

    await page.goto('/hari-ini', { waitUntil: 'networkidle' });
    const digestSection = page.getByTestId('hari-ini-smart-digest');
    await expect(digestSection).toBeVisible();
    await expect(digestSection.getByText('Pengingat Cerdas')).toBeVisible();
    await expect(digestSection.getByText('Ringkasan Mingguan')).toBeVisible();
    await expect(digestSection.getByText(/Jadwal bentrok:/i)).toBeVisible();
    await expect(digestSection.getByText(/Tugas macet/i)).toBeVisible();
    await expect(digestSection.getByText(/Anggaran mendekati batas/i)).toBeVisible();
    await expect(digestSection.getByText(/Internet Fiber Studio/i)).toBeVisible();
    await expect(page.getByTestId('realtime-status-badge')).toBeVisible();

    await captureScreen(page, 'wave3-web-hari-ini-digest.png');

    // Periksa halaman /pengaturan
    await page.goto('/pengaturan', { waitUntil: 'networkidle' });
    const pwaCard = page.getByTestId('settings-pwa-card');
    await expect(pwaCard).toBeVisible({ timeout: 20000 });
    await expect(pwaCard.getByText('needs_config', { exact: true })).toBeVisible({ timeout: 20000 });
    await expect(pwaCard.getByText('Chromium Desktop Orbit')).toBeVisible();
    await expect(pwaCard.getByText('Android Orbit Companion')).toBeVisible();

    const privacyCard = page.getByTestId('settings-privacy-card');
    await expect(privacyCard).toBeVisible();
    await expect(privacyCard.getByText(/Hash SHA-256/i)).toBeVisible();

    await captureScreen(page, 'wave3-web-pengaturan-pwa.png');
  });

  test('4. /inbox mengekstrak teks notifikasi bank menjadi draft status:draft dan menolak nominal invalid', async ({
    page,
  }) => {
    await setupWave3MockApi(page);

    let postCount = 0;
    let lastPostedDraft: Record<string, unknown> | null = null;
    page.on('request', (req) => {
      if (req.method() === 'POST' && req.url().includes('/rest/v1/transactions')) {
        postCount += 1;
        lastPostedDraft = req.postDataJSON() as Record<string, unknown>;
      }
    });

    await page.goto('/inbox', { waitUntil: 'networkidle' });

    const extractTextarea = page.getByLabel('Teks struk atau notifikasi transaksi');
    const extractBtn = page.getByTestId('inbox-extract-btn');

    // Kasus invalid: nominal 0 / tidak ada nominal -> tidak boleh lolos menjadi draft
    await extractTextarea.fill('BCA: saldo rekening Rp 0 berhasil dicek tanpa transaksi');
    await extractBtn.click();
    await expect(page.getByRole('alert').filter({ hasText: 'Nominal' })).toBeVisible();
    await expect(page.getByTestId('inbox-extract-preview')).toHaveCount(0);
    expect(postCount).toBe(0);

    // Kasus valid: notifikasi bank BCA QRIS -> pratinjau lalu simpan sebagai draft Inbox
    await extractTextarea.fill(
      'BCA Mobile: Pembayaran QRIS di Kopi Kenangan sebesar Rp 45.000,00 pada 15/11/2026 09:30 WIB berhasil.'
    );
    await extractBtn.click();

    const preview = page.getByTestId('inbox-extract-preview');
    await expect(preview).toBeVisible();
    await expect(preview.getByText('Rp 45.000')).toBeVisible();

    await page.getByTestId('inbox-save-draft-btn').click();
    await expect(page.getByText(/Draft hasil ekstraksi tersimpan ke Inbox/i)).toBeVisible();
    expect(postCount).toBe(1);
    expect(lastPostedDraft).not.toBeNull();
    expect(lastPostedDraft!.status).toBe('draft');
    expect(lastPostedDraft!.amount).toBe(45000);

    // Pastikan draft baru tampil di daftar Inbox
    await expect(page.getByText('Kopi Kenangan').first()).toBeVisible();
    await captureScreen(page, 'wave3-web-inbox-ocr.png');
  });
});
