import { test, expect, type Page } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';

const ARTIFACT_DIR =
  process.env.ORBIT_ARTIFACT_DIR ||
  path.resolve(__dirname, '../test-results/artifacts');
const WS_ID = 'ws-orbit-wave4';
const USER_ID = 'e2e-wave4-owner';

const DASHBOARD_ROUTES = [
  '/hari-ini',
  '/jadwal',
  '/tugas',
  '/transaksi',
  '/anggaran',
  '/tagihan',
  '/tabungan',
  '/akun',
  '/ringkasan',
  '/inbox',
  '/proyek',
  '/kategori',
  '/pengaturan',
] as const;

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

async function setupAuditMockApi(page: Page, theme: 'light' | 'dark') {
  const todayStr = toWibDateStr(0);

  await page.addInitScript((selectedTheme: 'light' | 'dark') => {
    window.localStorage.setItem('orbit_theme', selectedTheme);
    window.localStorage.setItem('orbit_active_workspace_id', 'ws-orbit-wave4');
  }, theme);

  const workspaces = [
    {
      id: WS_ID,
      name: 'Orbit Wave 4 Studio',
      type: 'shared',
      base_currency: 'IDR',
      owner_id: USER_ID,
      month_start_day: 1,
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
      opening_balance: 8500000,
      archived: false,
      visibility: 'shared',
      sort_order: 1,
      deleted_at: null,
    },
    {
      id: 'acc-gopay',
      workspace_id: WS_ID,
      name: 'GoPay Operasional',
      type: 'ewallet',
      currency: 'IDR',
      opening_balance: 1200000,
      archived: false,
      visibility: 'shared',
      sort_order: 2,
      deleted_at: null,
    },
  ];

  const categories = [
    {
      id: 'cat-inc-1',
      workspace_id: WS_ID,
      parent_id: null,
      name: 'Proyek Freelance',
      type: 'income',
      archived: false,
      sort_order: 1,
      deleted_at: null,
    },
    {
      id: 'cat-exp-1',
      workspace_id: WS_ID,
      parent_id: null,
      name: 'Konsumsi',
      type: 'expense',
      archived: false,
      sort_order: 2,
      deleted_at: null,
    },
  ];

  const projects = [
    {
      id: 'proj-1',
      workspace_id: WS_ID,
      kind: 'freelance',
      name: 'Portal Analitik Klien',
      description: 'Pengembangan modul keuangan dan tugas',
      status: 'berjalan',
      started_on: toWibDateStr(-14),
      deadline: toWibDateStr(14),
      color: '#0284C7',
      tags: ['web', 'nextjs'],
      client_name: 'PT Nusantara Digital',
      contract_value: 15000000,
      currency: 'IDR',
      platform_fee_percent: 5,
      fee_mode: 'expense_transaction',
      deleted_at: null,
      archived: false,
    },
  ];

  const projectPayments = [
    {
      id: 'pp-1',
      workspace_id: WS_ID,
      project_id: 'proj-1',
      label: 'Termin 1 (DP)',
      amount: 4500000,
      due_date: toWibDateStr(-2),
      status: 'paid',
      paid_at: isoAtWib(-1, 14),
      transaction_id: 'tx-1',
      deleted_at: null,
    },
    {
      id: 'pp-2',
      workspace_id: WS_ID,
      project_id: 'proj-1',
      label: 'Termin 2 (Final)',
      amount: 10500000,
      due_date: toWibDateStr(5),
      status: 'pending',
      paid_at: null,
      transaction_id: null,
      deleted_at: null,
    },
  ];

  const transactions = [
    {
      id: 'tx-1',
      workspace_id: WS_ID,
      account_id: 'acc-bca',
      category_id: 'cat-inc-1',
      project_id: 'proj-1',
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
      id: 'tx-2',
      workspace_id: WS_ID,
      account_id: 'acc-gopay',
      category_id: 'cat-exp-1',
      project_id: null,
      type: 'expense',
      amount: 185000,
      amount_base: 185000,
      currency: 'IDR',
      merchant: 'Alfamart Sudirman',
      note: 'Kebutuhan studio',
      occurred_at: isoAtWib(0, 10),
      source: 'personal',
      status: 'confirmed',
      origin: 'manual',
      draft_state: null,
      deleted_at: null,
    },
    {
      id: 'tx-draft-1',
      workspace_id: WS_ID,
      account_id: 'acc-bca',
      category_id: null,
      project_id: null,
      type: 'expense',
      amount: 65000,
      amount_base: 65000,
      currency: 'IDR',
      merchant: 'Indomaret Kemang',
      note: 'Draft struk belanja',
      occurred_at: isoAtWib(0, 9),
      source: 'personal',
      status: 'draft',
      origin: 'receipt_ocr',
      draft_state: 'perlu_dilengkapi',
      deleted_at: null,
    },
  ];

  const events = [
    {
      id: 'ev-1',
      workspace_id: WS_ID,
      title: 'Review Arsitektur Web',
      description: 'Validasi kesiapan rilis Gelombang 4',
      kind: 'freelance',
      starts_at: isoAtWib(0, 14, 0),
      ends_at: isoAtWib(0, 15, 0),
      all_day: false,
      location: 'Google Meet',
      deleted_at: null,
    },
  ];

  const tasks = [
    {
      id: 'task-1',
      workspace_id: WS_ID,
      project_id: 'proj-1',
      kind: 'freelance',
      title: 'Audit Aksesibilitas Responsive Mobile',
      description: 'Pastikan seluruh kontrol memenuhi 44x44 dan bebas overflow.',
      status: 'doing',
      priority: 'tinggi',
      due_at: isoAtWib(1, 17),
      due_is_date_only: false,
      progress_percent: 65,
      progress_mode: 'manual',
      revision_count: 0,
      updated_at: isoAtWib(0, 9),
      created_at: isoAtWib(-4, 9),
      sort_order: 1,
      deleted_at: null,
      projects: { name: 'Portal Analitik Klien' },
      task_checklist_items: [
        { id: 'chk-1', task_id: 'task-1', text: 'Cek mobile 390px', done: true, sort_order: 1 },
        { id: 'chk-2', task_id: 'task-1', text: 'Cek dark mode', done: false, sort_order: 2 },
      ],
    },
    {
      id: 'task-2',
      workspace_id: WS_ID,
      project_id: 'proj-1',
      kind: 'kuliah',
      title: 'Finalisasi Laporan Mingguan',
      description: null,
      status: 'todo',
      priority: 'sedang',
      due_at: isoAtWib(2, 18),
      due_is_date_only: false,
      progress_percent: 25,
      progress_mode: 'manual',
      revision_count: 0,
      updated_at: isoAtWib(-1, 10),
      created_at: isoAtWib(-3, 9),
      sort_order: 2,
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
      spent_amount: 640000,
      percentage_spent: 64,
      is_over_budget: false,
      is_warning: false,
      notify_at_percent: 80,
      remaining_amount: 360000,
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

  const savingsGoals = [
    {
      id: 'goal-1',
      workspace_id: WS_ID,
      name: 'Dana Darurat 6 Bulan',
      target_amount: 30000000,
      current_amount: 12500000,
      target_date: toWibDateStr(180),
      notes: 'Prioritas utama cadangan operasional',
      archived: false,
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
      push_subscription: null,
      last_seen_at: isoAtWib(0, 9),
      created_at: isoAtWib(-5, 9),
      updated_at: isoAtWib(0, 9),
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
        const count = Array.isArray(data) ? data.length : 1;
        return route.fulfill({
          status: 200,
          headers: {
            'content-range': count > 0 ? `0-${count - 1}/${count}` : '0-0/0',
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
      return respond(
        events.map((e) => ({
          id: e.id,
          item_type: 'event',
          title: e.title,
          kind: e.kind,
          starts_at: e.starts_at,
          ends_at: e.ends_at,
          all_day: e.all_day,
          location: e.location,
          status: null,
          priority: null,
          is_recurring: false,
          event_id: e.id,
        }))
      );
    }

    if (pathname.endsWith('/rpc/fn_detect_conflicts')) return respond([]);
    if (pathname.endsWith('/rpc/fn_global_search')) return respond([]);
    if (pathname.endsWith('/rpc/fn_my_sessions')) {
      return respond([
        {
          id: 'sess-wave4-1',
          created_at: isoAtWib(-1, 8),
          updated_at: isoAtWib(0, 8),
          user_agent: 'Chromium Playwright',
          aal: 'aal1',
          is_current: true,
        },
      ]);
    }

    if (pathname.endsWith('/workspaces')) return respond(wantsObject ? workspaces[0] : workspaces);
    if (pathname.endsWith('/workspace_members')) {
      return respond(wantsObject ? workspaceMembers[0] : workspaceMembers);
    }
    if (pathname.endsWith('/profiles')) return respond(wantsObject ? profiles[0] : profiles);
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
    if (pathname.endsWith('/accounts')) return respond(accounts);
    if (pathname.endsWith('/categories')) return respond(categories);
    if (pathname.endsWith('/projects')) return respond(projects);
    if (pathname.endsWith('/project_payments')) return respond(projectPayments);
    if (pathname.endsWith('/v_project_profit')) {
      return respond([
        {
          project_id: 'proj-1',
          workspace_id: WS_ID,
          name: 'Portal Analitik Klien',
          kind: 'freelance',
          status: 'berjalan',
          contract_value: 15000000,
          total_income: 4500000,
          total_expense: 185000,
          net_profit: 4315000,
        },
      ]);
    }
    if (pathname.endsWith('/v_receivables')) return respond([]);
    if (pathname.endsWith('/v_account_balances')) {
      return respond([
        {
          account_id: 'acc-bca',
          workspace_id: WS_ID,
          name: 'BCA Tabungan',
          type: 'bank',
          currency: 'IDR',
          balance: 8500000,
          is_liquid: true,
          archived: false,
          visibility: 'shared',
          last_txn_at: isoAtWib(-1, 14),
        },
        {
          account_id: 'acc-gopay',
          workspace_id: WS_ID,
          name: 'GoPay Operasional',
          type: 'ewallet',
          currency: 'IDR',
          balance: 1200000,
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
          expense: 185000,
          net: 4315000,
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
          total: 185000,
          txn_count: 1,
        },
      ]);
    }
    if (pathname.endsWith('/v_budget_progress')) return respond(budgets);
    if (pathname.endsWith('/recurring_bills')) return respond(bills);
    if (pathname.endsWith('/savings_goals')) return respond(savingsGoals);
    if (pathname.endsWith('/savings_rules')) return respond([]);
    if (pathname.endsWith('/expected_incomes')) return respond([]);
    if (pathname.endsWith('/events')) return respond(events);
    if (pathname.endsWith('/tasks')) return respond(tasks);
    if (pathname.endsWith('/user_devices')) return respond(userDevices);
    if (pathname.endsWith('/transactions')) {
      const statusEq = url.searchParams.get('status');
      if (statusEq === 'eq.draft') return respond(transactions.filter((t) => t.status === 'draft'));
      if (statusEq === 'eq.confirmed') {
        return respond(transactions.filter((t) => t.status === 'confirmed'));
      }
      return respond(transactions);
    }

    return respond([]);
  });

  const ssrSessionPayload = {
    access_token: 'e2e-wave4-access-token',
    refresh_token: 'e2e-wave4-refresh-token',
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

async function auditCurrentRoute(
  page: Page,
  route: string,
  options: {
    modeLabel: string;
    isMobile: boolean;
    expectedTheme?: 'light' | 'dark';
    consoleErrors: string[];
    pageErrors: string[];
  }
) {
  await page.goto(route, { waitUntil: 'load' });
  await expect(page.locator('main')).toBeVisible({ timeout: 25000 });
  // Pastikan shell & konten halaman selesai hydrate dan query tidak lagi loading
  await page.waitForFunction(
    () => {
      const headerText = (document.querySelector('header')?.innerText || '').trim();
      const mainText = (document.querySelector('main')?.innerText || '').trim();
      const busyCount = document.querySelectorAll(
        '[aria-busy="true"], main .animate-pulse'
      ).length;
      return headerText.length > 0 && mainText.length > 0 && busyCount === 0;
    },
    null,
    { timeout: 30000 }
  );
  if (options.expectedTheme === 'dark') {
    await expect(page.locator('html')).toHaveClass(/dark/, { timeout: 15000 });
  }

  expect(
    options.consoleErrors,
    `Console errors di ${route} (${options.modeLabel})`
  ).toEqual([]);
  expect(
    options.pageErrors,
    `Page errors di ${route} (${options.modeLabel})`
  ).toEqual([]);

  const result = await page.evaluate((isMobileViewport: boolean) => {
    const docEl = document.documentElement;
    const horizontalOverflow = docEl.scrollWidth > docEl.clientWidth + 2;
    const scrollWidth = docEl.scrollWidth;
    const clientWidth = docEl.clientWidth;

    const emojiRegex = /\p{Extended_Pictographic}/u;
    const bodyText = document.body.innerText || '';
    const emojiMatch = bodyText.match(emojiRegex);

    const htmlAndText = bodyText + '\n' + docEl.innerHTML;
    const leakedSecrets: string[] = [];
    const secretChecks: Array<{ label: string; pattern: RegExp }> = [
      {
        label: 'VAPID_PRIVATE_KEY value leak',
        pattern: /VAPID_PRIVATE_KEY\s*[:=]\s*["']?[A-Za-z0-9+/_-]{12,}/,
      },
      {
        label: 'SUPABASE_SERVICE_ROLE_KEY value leak',
        pattern: /SUPABASE_SERVICE_ROLE_KEY\s*[:=]\s*["']?[A-Za-z0-9._-]{12,}/,
      },
      {
        label: 'GOOGLE_CLIENT_SECRET value leak',
        pattern: /GOOGLE_CLIENT_SECRET\s*[:=]\s*["']?[A-Za-z0-9._-]{12,}/,
      },
      { label: 'GOOGLE_CLIENT_SECRET_TOKEN', pattern: /\bGOCSPX-[A-Za-z0-9_-]{10,}/ },
      { label: 'PEM_PRIVATE_KEY', pattern: /BEGIN (?:EC |RSA )?PRIVATE KEY/ },
      {
        label: 'SERVICE_ROLE_JWT',
        pattern: /eyJhbGciOi[^"'\s]{10,}\.[^"'\s]{10,}service_role/,
      },
    ];
    for (const check of secretChecks) {
      if (check.pattern.test(htmlAndText)) {
        leakedSecrets.push(check.label);
      }
    }

    const missingButtonLabels: string[] = [];
    const buttons = Array.from(document.querySelectorAll('button'));
    for (const btn of buttons) {
      const style = window.getComputedStyle(btn);
      const rect = btn.getBoundingClientRect();
      if (
        style.display === 'none' ||
        style.visibility === 'hidden' ||
        rect.width === 0 ||
        rect.height === 0
      ) {
        continue;
      }

      const visibleText = (btn.innerText || '').trim();
      if (visibleText.length > 0) continue;

      const ariaLabel = (btn.getAttribute('aria-label') || '').trim();
      const titleAttr = (btn.getAttribute('title') || '').trim();
      const labelledBy = (btn.getAttribute('aria-labelledby') || '').trim();
      const srOnlyText = Array.from(btn.querySelectorAll('.sr-only'))
        .map((n) => (n.textContent || '').trim())
        .join('')
        .trim();

      if (!ariaLabel && !titleAttr && !labelledBy && !srOnlyText) {
        missingButtonLabels.push(btn.outerHTML.slice(0, 140));
      }
    }

    const smallNavControls: string[] = [];
    if (isMobileViewport) {
      const navControls = Array.from(
        document.querySelectorAll(
          'header button, header a, nav button, nav a'
        )
      );
      for (const ctrl of navControls) {
        const style = window.getComputedStyle(ctrl);
        const rect = ctrl.getBoundingClientRect();
        if (
          style.display === 'none' ||
          style.visibility === 'hidden' ||
          rect.width === 0 ||
          rect.height === 0
        ) {
          continue;
        }
        // Pastikan kontrol tampak di dalam viewport (bukan di luar drawer tertutup)
        if (rect.right <= 0 || rect.left >= window.innerWidth) {
          continue;
        }
        if (rect.width < 43.5 || rect.height < 43.5) {
          const label =
            ctrl.getAttribute('aria-label') ||
            (ctrl.textContent || '').trim() ||
            ctrl.tagName;
          smallNavControls.push(
            `${label} (${Math.round(rect.width)}x${Math.round(rect.height)})`
          );
        }
      }
    }

    return {
      horizontalOverflow,
      scrollWidth,
      clientWidth,
      hasEmoji: Boolean(emojiMatch),
      emojiSample: emojiMatch ? emojiMatch[0] : null,
      leakedSecrets,
      missingButtonLabels,
      smallNavControls,
    };
  }, options.isMobile);

  expect(
    result.horizontalOverflow,
    `Horizontal overflow di ${route} (${options.modeLabel}): scrollWidth=${result.scrollWidth}, clientWidth=${result.clientWidth}`
  ).toBe(false);
  expect(
    result.hasEmoji,
    `Ditemukan emoji di ${route} (${options.modeLabel}): ${result.emojiSample}`
  ).toBe(false);
  expect(
    result.leakedSecrets,
    `Secret leak terdeteksi di ${route} (${options.modeLabel})`
  ).toEqual([]);
  expect(
    result.missingButtonLabels,
    `Icon-only button tanpa aria-label/teks terakses di ${route} (${options.modeLabel})`
  ).toEqual([]);
  expect(
    result.smallNavControls,
    `Kontrol navigasi/topbar mobile < 44x44 di ${route} (${options.modeLabel})`
  ).toEqual([]);
}

test.describe('Orbit Web v2 Gelombang 4: Audit A11y, Responsif, Tema Gelap, Nol Overflow & Nol Emoji', () => {
  test('1. Desktop 1280x800 (Light Mode) seluruh 13 rute bebas error, overflow, emoji, dan icon-only label hilang', async ({
    page,
  }) => {
    test.setTimeout(360000);
    await page.setViewportSize({ width: 1280, height: 800 });
    await setupAuditMockApi(page, 'light');

    const consoleErrors: string[] = [];
    const pageErrors: string[] = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') consoleErrors.push(msg.text());
    });
    page.on('pageerror', (err) => pageErrors.push(err.message));

    for (const route of DASHBOARD_ROUTES) {
      consoleErrors.length = 0;
      pageErrors.length = 0;
      await auditCurrentRoute(page, route, {
        modeLabel: 'Desktop Light 1280x800',
        isMobile: false,
        expectedTheme: 'light',
        consoleErrors,
        pageErrors,
      });
    }
  });

  test('2. Desktop 1280x800 (Dark Mode) seluruh 13 rute konsisten tanpa error/overflow + tangkap screenshot', async ({
    page,
  }) => {
    test.setTimeout(360000);
    await page.setViewportSize({ width: 1280, height: 800 });
    await setupAuditMockApi(page, 'dark');

    const consoleErrors: string[] = [];
    const pageErrors: string[] = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') consoleErrors.push(msg.text());
    });
    page.on('pageerror', (err) => pageErrors.push(err.message));

    for (const route of DASHBOARD_ROUTES) {
      consoleErrors.length = 0;
      pageErrors.length = 0;
      await auditCurrentRoute(page, route, {
        modeLabel: 'Desktop Dark 1280x800',
        isMobile: false,
        expectedTheme: 'dark',
        consoleErrors,
        pageErrors,
      });
      await expect(page.locator('html')).toHaveClass(/dark/);

      if (route === '/hari-ini') {
        fs.mkdirSync(ARTIFACT_DIR, { recursive: true });
        await page.evaluate(() => window.scrollTo(0, 0));
        await page.screenshot({
          path: path.join(ARTIFACT_DIR, 'wave4-web-audit-dark.png'),
          fullPage: true,
        });
      }
    }
  });

  test('3. Mobile 390x844 (Light Mode) seluruh 13 rute bebas overflow & kontrol navigasi/topbar >= 44x44 + tangkap screenshot', async ({
    page,
  }) => {
    test.setTimeout(360000);
    await page.setViewportSize({ width: 390, height: 844 });
    await setupAuditMockApi(page, 'light');

    const consoleErrors: string[] = [];
    const pageErrors: string[] = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') consoleErrors.push(msg.text());
    });
    page.on('pageerror', (err) => pageErrors.push(err.message));

    for (const route of DASHBOARD_ROUTES) {
      consoleErrors.length = 0;
      pageErrors.length = 0;
      await auditCurrentRoute(page, route, {
        modeLabel: 'Mobile Light 390x844',
        isMobile: true,
        expectedTheme: 'light',
        consoleErrors,
        pageErrors,
      });

      if (route === '/hari-ini') {
        fs.mkdirSync(ARTIFACT_DIR, { recursive: true });
        await page.evaluate(() => window.scrollTo(0, 0));
        await page.screenshot({
          path: path.join(ARTIFACT_DIR, 'wave4-web-audit-mobile.png'),
          fullPage: false,
        });
      }
    }
  });
});
