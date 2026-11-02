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
  test.setTimeout(120000);

  test('Capture and verify main Web routes in Desktop & Mobile viewports', async ({ page }) => {
    fs.mkdirSync(outDir, { recursive: true });

    // 1. Login Route (Unauthenticated)
    await page.setViewportSize({ width: 1280, height: 800 });
    await page.goto('/login', { waitUntil: 'networkidle' });
    await setTheme(page, 'light');
    await expect(page.getByRole('heading', { name: 'ORBIT' })).toBeVisible();
    await page.screenshot({ path: path.join(outDir, 'web-desktop-login-data.png') });

    await page.setViewportSize({ width: 390, height: 844 });
    await page.screenshot({ path: path.join(outDir, 'web-mobile-login-data.png') });

    // 2. Authenticate via test user
    await page.setViewportSize({ width: 1280, height: 800 });
    await page.fill('input[type="email"]', 'orbit.visual.e2e@gmail.com');
    await page.fill('input[type="password"]', 'OrbitTestPassword123!');
    await page.click('button[type="submit"]');
    await page.waitForURL('**/hari-ini', { timeout: 20000 });

    let mockMode: 'data' | 'empty' | 'error' = 'data';

    await page.route('**/rest/v1/**', async (route) => {
      const url = route.request().url();
      if (url.includes('workspace_members')) {
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify({ workspace_id: wsId }),
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
        if (route.request().method() === 'HEAD') {
          return route.fulfill({ status: 200, headers: { 'content-range': '0-0/0' }, body: '' });
        }
        return route.fulfill({ status: 200, contentType: 'application/json', body: '[]' });
      }

      if (url.includes('fn_agenda')) {
        return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(mockAgenda) });
      }
      if (url.includes('fn_detect_conflicts')) {
        return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(mockConflicts) });
      }
      if (url.includes('v_account_balances')) {
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify([
            { account_id: 'acc-1', name: 'BCA Utama', type: 'bank', currency: 'IDR', balance: 12450000, is_liquid: true, archived: false },
            { account_id: 'acc-2', name: 'GoPay', type: 'ewallet', currency: 'IDR', balance: 485000, is_liquid: true, archived: false },
          ]),
        });
      }
      if (url.includes('v_receivables')) {
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify([
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
          ]),
        });
      }
      if (url.includes('v_budget_progress')) {
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify([
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
          ]),
        });
      }
      if (url.includes('/accounts')) {
        return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(mockAccounts) });
      }
      if (url.includes('/categories')) {
        return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(mockCategories) });
      }
      if (url.includes('/projects')) {
        return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(mockProjects) });
      }
      if (url.includes('/events')) {
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify(
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
          ),
        });
      }
      if (url.includes('/tasks')) {
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify(
            mockAgenda
              .filter((a) => a.item_type === 'task')
              .map((t) => ({
                id: t.id,
                workspace_id: wsId,
                project_id: t.project_id,
                kind: t.kind,
                title: t.title,
                status: 'hari_ini',
                priority: t.priority,
                due_at: t.due_at,
                projects: { name: t.project_name },
              }))
          ),
        });
      }
      if (url.includes('/recurring_bills')) {
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify([
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
          ]),
        });
      }
      if (url.includes('/savings_goals')) {
        return route.fulfill({
          status: 200,
          contentType: 'application/json',
          body: JSON.stringify([
            {
              id: 'goal-1',
              workspace_id: wsId,
              name: 'Dana Darurat 6 Bulan',
              target_amount: 15000000,
              current_amount: 9500000,
              target_date: '2026-12-31',
              is_completed: false,
            },
          ]),
        });
      }
      if (url.includes('/transactions')) {
        if (route.request().method() === 'HEAD') {
          return route.fulfill({ status: 200, headers: { 'content-range': '0-0/1' }, body: '' });
        }
        return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(mockTransactions) });
      }
      return route.fulfill({ status: 200, contentType: 'application/json', body: '[]' });
    });

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
      await page.goto(r.path, { waitUntil: 'domcontentloaded' });
      await expect(page.locator('main')).toBeVisible();
      await page.waitForTimeout(250);
      await setTheme(page, 'light');
      await page.screenshot({ path: path.join(outDir, `web-desktop-${r.slug}-data.png`) });

      await setTheme(page, 'dark');
      await page.screenshot({ path: path.join(outDir, `web-desktop-${r.slug}-gelap.png`) });

      await page.setViewportSize({ width: 390, height: 844 });
      await setTheme(page, 'light');
      await page.screenshot({ path: path.join(outDir, `web-mobile-${r.slug}-data.png`) });
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
      await page.goto(r.path, { waitUntil: 'domcontentloaded' });
      await expect(page.locator('main')).toBeVisible();
      await page.waitForTimeout(250);
      await setTheme(page, 'light');
      await page.screenshot({ path: path.join(outDir, `web-desktop-${r.slug}-empty.png`) });

      mockMode = 'error';
      await page.goto(r.path, { waitUntil: 'domcontentloaded' });
      await expect(page.locator('main')).toBeVisible();
      await page.waitForTimeout(250);
      await setTheme(page, 'light');
      await page.screenshot({ path: path.join(outDir, `web-desktop-${r.slug}-error.png`) });
    }
  });
});
