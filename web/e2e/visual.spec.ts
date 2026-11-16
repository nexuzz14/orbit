import { test, expect, Page } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';

const outDir = path.resolve(__dirname, '../../docs/design/sesudah');
const wsId = 'ws-orbit-sesudah';
const todayIso = new Date().toISOString().slice(0, 10);
const yesterdayDate = new Date(Date.now() - 86400000).toISOString().slice(0, 10);

const mockAccounts = [
  { id: 'acc-1', workspace_id: wsId, name: 'BCA Utama', type: 'bank', currency: 'IDR', initial_balance: 10000000, current_balance: 12450000, is_liquid: true, archived: false, sort_order: 1, deleted_at: null },
  { id: 'acc-2', workspace_id: wsId, name: 'GoPay', type: 'ewallet', currency: 'IDR', initial_balance: 500000, current_balance: 485000, is_liquid: true, archived: false, sort_order: 2, deleted_at: null },
  { id: 'acc-3', workspace_id: wsId, name: 'Mandiri Bisnis', type: 'bank', currency: 'IDR', initial_balance: 5000000, current_balance: 5000000, is_liquid: true, archived: false, sort_order: 3, deleted_at: null },
];

const mockCategories = [
  { id: 'cat-1', workspace_id: wsId, name: 'Makan & Minum', type: 'expense', sort_order: 1, deleted_at: null },
  { id: 'cat-2', workspace_id: wsId, name: 'Transportasi', type: 'expense', sort_order: 2, deleted_at: null },
  { id: 'cat-3', workspace_id: wsId, name: 'Langganan & Cloud', type: 'expense', sort_order: 3, deleted_at: null },
  { id: 'cat-4', workspace_id: wsId, name: 'Freelance & Proyek', type: 'income', sort_order: 1, deleted_at: null },
];

const mockProjects = [
  { id: 'proj-1', workspace_id: wsId, kind: 'intern', name: 'Magang Backend Engineer', status: 'berjalan', client_name: 'PT Teknologi Nusantara', contract_value: 4500000, currency: 'IDR', deleted_at: null },
  { id: 'proj-2', workspace_id: wsId, kind: 'freelance', name: 'Redesign Portal Klien', status: 'berjalan', client_name: 'Studio Kreatif Nusantara', contract_value: 8500000, currency: 'IDR', deleted_at: null },
  { id: 'proj-3', workspace_id: wsId, kind: 'kuliah', name: 'Rekayasa Perangkat Lunak', status: 'berjalan', semester: 5, course_code: 'IF3102', credits: 3, deleted_at: null },
];

const mockAgenda = [
  {
    id: 'ev-1',
    item_type: 'event',
    kind: 'intern',
    title: 'Sinkronisasi Sprint Engineering',
    description: null,
    project_id: 'proj-1',
    project_name: 'Magang Backend Engineer',
    project_color: null,
    starts_at: `${todayIso}T02:00:00.000Z`,
    ends_at: `${todayIso}T03:00:00.000Z`,
    all_day: false,
    location: 'Google Meet',
    status: 'scheduled',
    priority: null,
    due_at: null,
    due_is_date_only: false,
    is_overdue: false,
    checklist_total: 0,
    checklist_done: 0,
    event_id: 'ev-1',
    is_recurring: true,
    milestone_payment_id: null,
  },
  {
    id: 'ev-2',
    item_type: 'event',
    kind: 'freelance',
    title: 'Presentasi Prototipe ke Klien',
    description: null,
    project_id: 'proj-2',
    project_name: 'Redesign Portal Klien',
    project_color: null,
    starts_at: `${todayIso}T02:30:00.000Z`,
    ends_at: `${todayIso}T04:00:00.000Z`,
    all_day: false,
    location: 'Zoom',
    status: 'scheduled',
    priority: null,
    due_at: null,
    due_is_date_only: false,
    is_overdue: false,
    checklist_total: 0,
    checklist_done: 0,
    event_id: 'ev-2',
    is_recurring: false,
    milestone_payment_id: null,
  },
  {
    id: 'task-1',
    item_type: 'task',
    kind: 'freelance',
    title: 'Finalisasi sistem desain dan komponen UI',
    description: null,
    project_id: 'proj-2',
    project_name: 'Redesign Portal Klien',
    project_color: null,
    starts_at: null,
    ends_at: null,
    all_day: false,
    location: null,
    status: 'todo',
    priority: 'tinggi',
    due_at: `${todayIso}T10:00:00.000Z`,
    due_is_date_only: false,
    is_overdue: false,
    checklist_total: 4,
    checklist_done: 3,
    event_id: null,
    is_recurring: false,
    milestone_payment_id: null,
  },
  {
    id: 'task-2',
    item_type: 'task',
    kind: 'kuliah',
    title: 'Kumpulkan laporan praktikum arsitektur perangkat lunak',
    description: null,
    project_id: 'proj-3',
    project_name: 'Rekayasa Perangkat Lunak',
    project_color: null,
    starts_at: null,
    ends_at: null,
    all_day: false,
    location: null,
    status: 'todo',
    priority: 'tinggi',
    due_at: `${yesterdayDate}T10:00:00.000Z`,
    due_is_date_only: false,
    is_overdue: true,
    checklist_total: 2,
    checklist_done: 1,
    event_id: null,
    is_recurring: false,
    milestone_payment_id: null,
  },
];

const mockConflicts = [
  {
    conflict_date: todayIso,
    event1_id: 'ev-1',
    event1_title: 'Sinkronisasi Sprint Engineering',
    event1_starts_at: `${todayIso}T02:00:00.000Z`,
    event1_ends_at: `${todayIso}T03:00:00.000Z`,
    event2_id: 'ev-2',
    event2_title: 'Presentasi Prototipe ke Klien',
    event2_starts_at: `${todayIso}T02:30:00.000Z`,
    event2_ends_at: `${todayIso}T04:00:00.000Z`,
    is_heavy_day: false,
  },
];

const mockTransactions = [
  {
    id: 'tx-1',
    workspace_id: wsId,
    account_id: 'acc-1',
    category_id: 'cat-4',
    type: 'income',
    status: 'confirmed',
    amount: 2500000,
    currency: 'IDR',
    source: 'freelance',
    merchant: 'Studio Kreatif Nusantara',
    note: 'Termin 1 Redesign Portal',
    occurred_at: `${todayIso}T09:15:00.000Z`,
    deleted_at: null,
  },
  {
    id: 'tx-2',
    workspace_id: wsId,
    account_id: 'acc-2',
    category_id: 'cat-1',
    type: 'expense',
    status: 'confirmed',
    amount: 48000,
    currency: 'IDR',
    source: 'intern',
    merchant: 'Kopi Kenangan',
    note: 'Kopi & sarapan pagi',
    occurred_at: `${todayIso}T07:45:00.000Z`,
    deleted_at: null,
  },
  {
    id: 'tx-3',
    workspace_id: wsId,
    account_id: 'acc-2',
    category_id: 'cat-2',
    type: 'expense',
    status: 'draft',
    amount: 32000,
    currency: 'IDR',
    source: 'kuliah',
    merchant: 'Gojek Indonesia',
    note: 'Otomatis dari notifikasi',
    occurred_at: `${yesterdayDate}T17:20:00.000Z`,
    deleted_at: null,
  },
];

async function setTheme(page: Page, mode: 'light' | 'dark') {
  await page.evaluate((m) => {
    localStorage.setItem('orbit_theme', m);
    document.documentElement.classList.toggle('dark', m === 'dark');
  }, mode);
  await page.waitForTimeout(150);
}

test.describe('Fase D Visual Regression & Sesudah Screenshots', () => {
  test.setTimeout(360000);

  test('Capture and verify main Web routes in Desktop & Mobile viewports', async ({ page }) => {
    fs.mkdirSync(outDir, { recursive: true });

    // 1. Login Route (Unauthenticated)
    await page.setViewportSize({ width: 1280, height: 800 });
    await page.goto('/login', { waitUntil: 'load' });
    await setTheme(page, 'light');
    await expect(page.getByRole('heading', { name: 'ORBIT' })).toBeVisible();
    await page.screenshot({ path: path.join(outDir, 'web-desktop-login-data.png'), animations: 'disabled' });

    await page.setViewportSize({ width: 390, height: 844 });
    await page.screenshot({ path: path.join(outDir, 'web-mobile-login-data.png'), animations: 'disabled' });

    // 2. Simulasi sesi terautentikasi E2E & mock API Supabase
    const mockUserId = 'e2e-visual-user';
    const mockSession = {
      access_token: 'e2e-visual-access-token',
      refresh_token: 'e2e-visual-refresh-token',
      token_type: 'bearer',
      expires_in: 86400,
      expires_at: Math.floor(Date.now() / 1000) + 86400,
      user: {
        id: mockUserId,
        aud: 'authenticated',
        role: 'authenticated',
        email: 'orbit.visual.e2e@gmail.com',
        app_metadata: { provider: 'email' },
        user_metadata: { display_name: 'Orbit Visual E2E' },
        created_at: `${yesterdayDate}T08:00:00.000Z`,
      },
    };
    const ssrCookieValue = `base64-${Buffer.from(JSON.stringify(mockSession)).toString('base64url')}`;

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
      {
        name: 'sb-dummy-auth-token',
        value: ssrCookieValue,
        domain: 'localhost',
        path: '/',
      },
    ]);

    await page.evaluate((id) => {
      window.localStorage.setItem('orbit_active_workspace_id', id);
    }, wsId);

    await page.route('**/auth/v1/**', async (route) => {
      const pathname = new URL(route.request().url()).pathname;
      if (pathname.endsWith('/factors')) {
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ all: [], totp: [] }),
        });
      }
      if (pathname.endsWith('/token')) {
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify(mockSession),
        });
      }
      return route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify(mockSession.user),
      });
    });

    let mockMode: 'data' | 'empty' | 'error' = 'data';
    const mockWorkspace = {
      id: wsId,
      name: 'Orbit Workspace Sesudah',
      type: 'shared',
      base_currency: 'IDR',
      owner_id: mockUserId,
      month_start_day: 1,
      created_at: `${yesterdayDate}T08:00:00.000Z`,
      updated_at: `${todayIso}T08:00:00.000Z`,
    };
    const mockMemberships = [
      {
        workspace_id: wsId,
        user_id: mockUserId,
        role: 'owner',
        workspaces: mockWorkspace,
      },
    ];

    await page.route('**/rest/v1/**', async (route) => {
      const req = route.request();
      const method = req.method();
      const parsedUrl = new URL(req.url());
      const pathname = parsedUrl.pathname;
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

      if (pathname.endsWith('/workspaces')) {
        return respond(wantsObject ? mockWorkspace : [mockWorkspace]);
      }
      if (pathname.endsWith('/workspace_members')) {
        return respond(wantsObject ? mockMemberships[0] : mockMemberships);
      }
      if (pathname.endsWith('/profiles')) {
        return respond({
          id: mockUserId,
          display_name: 'Orbit Visual E2E',
          base_currency: 'IDR',
          timezone: 'Asia/Jakarta',
          month_start_day: 1,
        });
      }
      if (pathname.endsWith('/notification_settings')) {
        return respond({
          workspace_id: wsId,
          budget_warning_enabled: true,
          budget_exceeded_enabled: true,
          bills_reminder_enabled: true,
          receivables_reminder_enabled: true,
          daily_summary_time: '08:00',
        });
      }
      if (mockMode === 'error') {
        return route.fulfill({
          status: 500,
          contentType: 'application/json',
          body: JSON.stringify({ message: 'Simulasi gangguan jaringan server.' }),
        });
      }
      if (mockMode === 'empty') {
        return respond([]);
      }

      if (pathname.endsWith('/rpc/fn_agenda')) {
        return respond(mockAgenda);
      }
      if (pathname.endsWith('/rpc/fn_detect_conflicts')) {
        return respond(mockConflicts);
      }
      if (pathname.endsWith('/rpc/fn_global_search')) {
        return respond([]);
      }
      if (pathname.endsWith('/rpc/fn_my_sessions')) {
        return respond([]);
      }
      if (pathname.endsWith('/v_account_balances')) {
        return respond([
          { account_id: 'acc-1', workspace_id: wsId, name: 'BCA Utama', type: 'bank', currency: 'IDR', balance: 12450000, is_liquid: true, archived: false },
          { account_id: 'acc-2', workspace_id: wsId, name: 'GoPay', type: 'ewallet', currency: 'IDR', balance: 485000, is_liquid: true, archived: false },
        ]);
      }
      if (pathname.endsWith('/v_monthly_summary')) {
        return respond([
          {
            workspace_id: wsId,
            month_start: `${todayIso.slice(0, 7)}-01`,
            month_end: todayIso,
            currency: 'IDR',
            source: null,
            is_total: true,
            income: 2500000,
            expense: 80000,
            net: 2420000,
            txn_count: 3,
          },
        ]);
      }
      if (pathname.endsWith('/v_monthly_source_summary')) {
        return respond([
          {
            workspace_id: wsId,
            month_start: `${todayIso.slice(0, 7)}-01`,
            source: 'freelance',
            currency: 'IDR',
            income: 2500000,
            expense: 0,
            net: 2500000,
            txn_count: 1,
          },
        ]);
      }
      if (pathname.endsWith('/v_monthly_category_summary')) {
        return respond([
          {
            workspace_id: wsId,
            month_start: `${todayIso.slice(0, 7)}-01`,
            category_id: 'cat-1',
            category_name: 'Makan & Minum',
            type: 'expense',
            total: 48000,
            txn_count: 1,
          },
        ]);
      }
      if (pathname.endsWith('/v_receivables')) {
        return respond([
          {
            payment_id: 'rec-1',
            project_id: 'proj-2',
            project_name: 'Redesign Portal Klien',
            client_name: 'Studio Kreatif',
            label: 'Termin 2 Desain UI',
            amount: 3500000,
            remaining_amount: 3500000,
            due_date: todayIso,
            status: 'menunggu',
            is_overdue: false,
            days_overdue: 0,
          },
        ]);
      }
      if (pathname.endsWith('/v_project_profit')) {
        return respond([
          {
            project_id: 'proj-2',
            workspace_id: wsId,
            name: 'Redesign Portal Klien',
            kind: 'freelance',
            status: 'berjalan',
            contract_value: 8500000,
            total_income: 2500000,
            total_expense: 0,
            net_profit: 2500000,
          },
        ]);
      }
      if (pathname.endsWith('/v_budget_progress')) {
        return respond([
          {
            budget_id: 'b-1',
            category_id: 'cat-1',
            category_name: 'Makan & Minum',
            period: 'monthly',
            budget_amount: 1500000,
            spent_amount: 1220000,
            remaining_amount: 280000,
            usage_percent: 81.3,
            notify_at_percent: 80,
            is_warning: true,
            is_over_budget: false,
          },
        ]);
      }
      if (pathname.endsWith('/accounts')) return respond(mockAccounts);
      if (pathname.endsWith('/categories')) return respond(mockCategories);
      if (pathname.endsWith('/projects')) return respond(mockProjects);
      if (pathname.endsWith('/events')) {
        return respond(
          mockAgenda
            .filter((a) => a.item_type === 'event')
            .map((e) => ({
              id: e.id,
              workspace_id: wsId,
              project_id: e.project_id,
              kind: e.kind,
              title: e.title,
              starts_at: e.starts_at,
              ends_at: e.ends_at,
              location: e.location,
              all_day: false,
            }))
        );
      }
      if (pathname.endsWith('/tasks')) {
        return respond(
          mockAgenda
            .filter((a) => a.item_type === 'task')
            .map((t, index) => ({
              id: t.id,
              workspace_id: wsId,
              project_id: t.project_id,
              kind: t.kind,
              title: t.title,
              description: null,
              status: index === 0 ? 'doing' : 'todo',
              priority: t.priority,
              due_at: t.due_at,
              due_is_date_only: false,
              sort_order: index + 1,
              progress_percent: index === 0 ? 50 : 25,
              revision_count: 0,
              latest_revision_note: null,
              tags: [],
              projects: { name: t.project_name },
              task_checklist_items: [],
            }))
        );
      }
      if (pathname.endsWith('/recurring_bills')) {
        return respond([
          {
            id: 'bill-1',
            workspace_id: wsId,
            name: 'Cloud Server & Domain',
            amount: 185000,
            category_id: 'cat-3',
            account_id: 'acc-1',
            schedule_type: 'monthly',
            schedule_value: 15,
            active: true,
            auto_create_draft: true,
            categories: { name: 'Langganan & Cloud' },
            accounts: { name: 'BCA Utama' },
          },
        ]);
      }
      if (pathname.endsWith('/savings_goals')) {
        return respond([
          {
            id: 'goal-1',
            workspace_id: wsId,
            name: 'Dana Darurat 6 Bulan',
            target_amount: 15000000,
            current_amount: 9500000,
            target_date: '2026-12-31',
            is_completed: false,
          },
        ]);
      }
      if (pathname.endsWith('/transactions')) {
        return respond(mockTransactions);
      }
      return respond([]);
    });

    await page.setViewportSize({ width: 1280, height: 800 });
    await page.goto('/hari-ini', { waitUntil: 'load' });
    await expect(page).toHaveURL(/\/hari-ini/, { timeout: 20000 });
    await expect(page.locator('main')).toBeVisible();

    const dashboardRoutes = [
      { slug: 'hari-ini', path: '/hari-ini' },
      { slug: 'jadwal', path: '/jadwal' },
      { slug: 'tugas', path: '/tugas' },
      { slug: 'transaksi', path: '/transaksi' },
      { slug: 'akun', path: '/akun' },
      { slug: 'ringkasan', path: '/ringkasan' },
      { slug: 'inbox', path: '/inbox' },
      { slug: 'anggaran', path: '/anggaran' },
      { slug: 'tagihan', path: '/tagihan' },
      { slug: 'tabungan', path: '/tabungan' },
      { slug: 'proyek', path: '/proyek' },
      { slug: 'kategori', path: '/kategori' },
      { slug: 'pengaturan', path: '/pengaturan' },
    ];

    for (const r of dashboardRoutes) {
      mockMode = 'data';
      await page.setViewportSize({ width: 1280, height: 800 });
      await page.goto(r.path, { waitUntil: 'load' });
      await expect(page).not.toHaveURL(/\/login/, { timeout: 15000 });
      await expect(page.locator('main')).toBeVisible({ timeout: 20000 });
      await page.waitForFunction(
        () => {
          const mainText = (document.querySelector('main')?.innerText || '').trim();
          const busyCount = document.querySelectorAll('[aria-busy="true"], main .animate-pulse').length;
          return mainText.length > 0 && busyCount === 0;
        },
        null,
        { timeout: 25000 }
      );
      await setTheme(page, 'light');
      await page.screenshot({ path: path.join(outDir, `web-desktop-${r.slug}-data.png`), animations: 'disabled' });

      await setTheme(page, 'dark');
      await page.screenshot({ path: path.join(outDir, `web-desktop-${r.slug}-gelap.png`), animations: 'disabled' });

      await page.setViewportSize({ width: 390, height: 844 });
      await setTheme(page, 'light');
      await page.screenshot({ path: path.join(outDir, `web-mobile-${r.slug}-data.png`), animations: 'disabled' });
    }

    // Empty & Error states on main routes
    for (const r of [
      { slug: 'hari-ini', path: '/hari-ini' },
      { slug: 'transaksi', path: '/transaksi' },
      { slug: 'jadwal', path: '/jadwal' },
      { slug: 'tugas', path: '/tugas' },
    ]) {
      mockMode = 'empty';
      await page.setViewportSize({ width: 1280, height: 800 });
      await page.goto(r.path, { waitUntil: 'load' });
      await expect(page).not.toHaveURL(/\/login/, { timeout: 15000 });
      await expect(page.locator('main')).toBeVisible({ timeout: 20000 });
      await page.waitForTimeout(200);
      await setTheme(page, 'light');
      await page.screenshot({ path: path.join(outDir, `web-desktop-${r.slug}-empty.png`), animations: 'disabled' });

      mockMode = 'error';
      await page.goto(r.path, { waitUntil: 'load' });
      await expect(page).not.toHaveURL(/\/login/, { timeout: 15000 });
      await expect(page.locator('main')).toBeVisible({ timeout: 20000 });
      await page.waitForTimeout(200);
      await setTheme(page, 'light');
      await page.screenshot({ path: path.join(outDir, `web-desktop-${r.slug}-error.png`), animations: 'disabled' });
    }
  });
});
