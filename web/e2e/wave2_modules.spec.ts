import { test, expect, type Page } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';

const ARTIFACT_DIR =
  process.env.ORBIT_ARTIFACT_DIR ||
  path.resolve(__dirname, '../test-results/artifacts');
const WS_ID = 'ws-orbit-wave2';
const USER_ID = 'e2e-wave2-owner';

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

async function setupWave2MockApi(page: Page) {
  const todayStr = toWibDateStr(0);

  const workspaces = [
    {
      id: WS_ID,
      name: 'Studio Orbit Kolaborasi',
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
    {
      workspace_id: WS_ID,
      user_id: 'member-editor-02',
      role: 'editor',
      created_at: isoAtWib(-20, 8),
      updated_at: isoAtWib(-20, 8),
      workspaces: workspaces[0],
    },
  ];

  const workspaceInvites: Array<Record<string, unknown>> = [];

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
      opening_balance: 5000000,
      archived: false,
      visibility: 'shared',
      sort_order: 1,
      deleted_at: null,
    },
  ];

  const categories = [
    { id: 'cat-inc-1', workspace_id: WS_ID, name: 'Proyek Freelance', type: 'income', archived: false, deleted_at: null },
    { id: 'cat-exp-1', workspace_id: WS_ID, name: 'Konsumsi', type: 'expense', archived: false, deleted_at: null },
    { id: 'cat-exp-2', workspace_id: WS_ID, name: 'Operasional Server', type: 'expense', archived: false, deleted_at: null },
  ];

  const projects = [
    {
      id: 'proj-1',
      workspace_id: WS_ID,
      kind: 'freelance',
      name: 'Platform Kasir UMKM',
      description: 'Pengembangan POS web dan sinkronisasi stok.',
      status: 'berjalan',
      started_on: toWibDateStr(-10),
      deadline: toWibDateStr(20),
      color: '#0284c7',
      tags: ['pos', 'web'],
      client_name: 'PT Niaga Maju',
      contract_value: 20000000,
      currency: 'IDR',
      platform_fee_percent: 0,
      fee_mode: 'expense_transaction',
      archived: false,
      deleted_at: null,
    },
    {
      id: 'proj-2',
      workspace_id: WS_ID,
      kind: 'kuliah',
      name: 'Tugas Akhir Sistem Terdistribusi',
      description: 'Implementasi replikasi konsensus dan benchmark.',
      status: 'berjalan',
      started_on: toWibDateStr(-5),
      deadline: toWibDateStr(35),
      color: '#16a34a',
      tags: ['skripsi'],
      client_name: null,
      contract_value: null,
      currency: 'IDR',
      semester: 7,
      course_code: 'IF4090',
      credits: 4,
      archived: false,
      deleted_at: null,
    },
  ];

  const projectPayments = [
    {
      id: 'pay-1',
      workspace_id: WS_ID,
      project_id: 'proj-1',
      label: 'Termin 1 (DP 50%)',
      amount: 10000000,
      paid_amount: 10000000,
      due_date: toWibDateStr(-7),
      status: 'paid',
      paid_at: isoAtWib(-7, 14),
      account_id: 'acc-bca',
      deleted_at: null,
    },
    {
      id: 'pay-2',
      workspace_id: WS_ID,
      project_id: 'proj-1',
      label: 'Termin 2 (Pelunasan)',
      amount: 10000000,
      paid_amount: 0,
      due_date: toWibDateStr(10),
      status: 'pending',
      paid_at: null,
      account_id: null,
      deleted_at: null,
    },
  ];

  const transactions: Array<Record<string, unknown>> = [
    {
      id: 'tx-1',
      workspace_id: WS_ID,
      account_id: 'acc-bca',
      category_id: 'cat-inc-1',
      project_id: 'proj-1',
      type: 'income',
      amount: 10000000,
      amount_base: 10000000,
      currency: 'IDR',
      fx_rate: 1,
      merchant: 'PT Niaga Maju',
      note: 'Pembayaran DP Termin 1',
      occurred_at: isoAtWib(-3, 11),
      origin: 'manual',
      source: 'freelance',
      status: 'confirmed',
      deleted_at: null,
      categories: { name: 'Proyek Freelance' },
      accounts: { name: 'BCA Tabungan' },
    },
    {
      id: 'tx-2',
      workspace_id: WS_ID,
      account_id: 'acc-bca',
      category_id: 'cat-exp-2',
      project_id: 'proj-1',
      type: 'expense',
      amount: 1500000,
      amount_base: 1500000,
      currency: 'IDR',
      fx_rate: 1,
      merchant: 'Cloud VPS',
      note: 'Server staging 3 bulan',
      occurred_at: isoAtWib(-1, 15),
      origin: 'manual',
      source: 'freelance',
      status: 'confirmed',
      deleted_at: null,
      categories: { name: 'Operasional Server' },
      accounts: { name: 'BCA Tabungan' },
    },
  ];

  const events: Array<Record<string, unknown>> = [
    {
      id: 'ev-1',
      workspace_id: WS_ID,
      title: 'Review Sprint POS UMKM',
      description: 'Demo modul kasir dengan klien',
      kind: 'freelance',
      project_id: 'proj-1',
      location: 'Google Meet',
      starts_at: isoAtWib(0, 9, 0),
      ends_at: isoAtWib(0, 11, 0),
      all_day: false,
      timezone: 'Asia/Jakarta',
      recurrence: null,
      deleted_at: null,
    },
    {
      id: 'ev-2',
      workspace_id: WS_ID,
      title: 'Bimbingan Skripsi',
      description: 'Cek bab metodologi',
      kind: 'kuliah',
      project_id: 'proj-2',
      location: 'Ruang Lab 302',
      starts_at: isoAtWib(0, 10, 0),
      ends_at: isoAtWib(0, 11, 30),
      all_day: false,
      timezone: 'Asia/Jakarta',
      recurrence: null,
      deleted_at: null,
    },
    {
      id: 'ev-3',
      workspace_id: WS_ID,
      title: 'Tenggat Dokumen Arsitektur',
      description: null,
      kind: 'freelance',
      project_id: 'proj-1',
      location: null,
      starts_at: isoAtWib(2, 0, 0),
      ends_at: isoAtWib(2, 23, 59),
      all_day: true,
      timezone: 'Asia/Jakarta',
      recurrence: null,
      deleted_at: null,
    },
  ];

  const tasks: Array<Record<string, unknown>> = [
    {
      id: 'task-w2-1',
      workspace_id: WS_ID,
      project_id: 'proj-1',
      kind: 'freelance',
      title: 'Implementasi modul cetak struk PDF & CSV',
      description: 'Pastikan format CSV aman dari formula injection.',
      description_blocks: null,
      status: 'doing',
      priority: 'tinggi',
      due_at: isoAtWib(1, 17, 0),
      due_is_date_only: false,
      completed_at: null,
      milestone_payment_id: null,
      sort_order: 1000,
      progress_percent: 60,
      revision_count: 0,
      latest_revision_note: null,
      status_changed_at: isoAtWib(-1, 9),
      parent_task_id: null,
      assignee_id: USER_ID,
      recurrence_rule: null,
      recurrence_parent_id: null,
      tags: ['keuangan', 'pdf'],
      estimate_minutes: 600,
      created_at: isoAtWib(-4, 9),
      updated_at: isoAtWib(-1, 9),
      deleted_at: null,
      projects: { name: 'Platform Kasir UMKM' },
      task_checklist_items: [],
    },
    {
      id: 'task-w2-2',
      workspace_id: WS_ID,
      project_id: 'proj-1',
      kind: 'freelance',
      title: 'Uji beban endpoint sinkronisasi stok',
      description: 'Simulasi 100 transaksi serentak.',
      description_blocks: null,
      status: 'todo',
      priority: 'sedang',
      due_at: isoAtWib(2, 16, 0),
      due_is_date_only: false,
      completed_at: null,
      milestone_payment_id: null,
      sort_order: 2000,
      progress_percent: 0,
      revision_count: 0,
      latest_revision_note: null,
      status_changed_at: isoAtWib(-2, 9),
      parent_task_id: null,
      assignee_id: USER_ID,
      recurrence_rule: null,
      recurrence_parent_id: null,
      tags: ['qa'],
      estimate_minutes: 2100,
      created_at: isoAtWib(-3, 9),
      updated_at: isoAtWib(-2, 9),
      deleted_at: null,
      projects: { name: 'Platform Kasir UMKM' },
      task_checklist_items: [],
    },
    {
      id: 'task-w2-done',
      workspace_id: WS_ID,
      project_id: 'proj-2',
      kind: 'kuliah',
      title: 'Desain skema database v5.3',
      description: null,
      description_blocks: null,
      status: 'done',
      priority: 'rendah',
      due_at: isoAtWib(-2, 12, 0),
      due_is_date_only: false,
      completed_at: isoAtWib(-2, 10, 0),
      milestone_payment_id: null,
      sort_order: 3000,
      progress_percent: 100,
      revision_count: 0,
      latest_revision_note: null,
      status_changed_at: isoAtWib(-2, 10),
      parent_task_id: null,
      assignee_id: 'member-editor-02',
      recurrence_rule: null,
      recurrence_parent_id: null,
      tags: [],
      estimate_minutes: 120,
      created_at: isoAtWib(-7, 9),
      updated_at: isoAtWib(-2, 10),
      deleted_at: null,
      projects: { name: 'Tugas Akhir Sistem Terdistribusi' },
      task_checklist_items: [],
    },
  ];

  const taskTimeLogs: Array<Record<string, unknown>> = [
    {
      id: 'tl-1',
      workspace_id: WS_ID,
      task_id: 'task-w2-1',
      user_id: USER_ID,
      started_at: isoAtWib(-1, 10, 0),
      ended_at: isoAtWib(-1, 10, 45),
      duration_seconds: 2700,
      mode: 'pomodoro',
      note: 'Setup parser CSV awal',
      created_at: isoAtWib(-1, 10, 45),
      deleted_at: null,
    },
  ];

  const monthlySummaryRows = [
    {
      workspace_id: WS_ID,
      month_start: '2026-09-01',
      month_end: '2026-09-30',
      currency: 'IDR',
      source: 'total',
      is_total: true,
      income: 7500000,
      expense: 3100000,
      net: 4400000,
      txn_count: 14,
    },
    {
      workspace_id: WS_ID,
      month_start: '2026-10-01',
      month_end: '2026-10-31',
      currency: 'IDR',
      source: 'total',
      is_total: true,
      income: 9200000,
      expense: 4200000,
      net: 5000000,
      txn_count: 19,
    },
    {
      workspace_id: WS_ID,
      month_start: '2026-11-01',
      month_end: '2026-11-30',
      currency: 'IDR',
      source: 'total',
      is_total: true,
      income: 12500000,
      expense: 3850000,
      net: 8650000,
      txn_count: 12,
    },
    {
      workspace_id: WS_ID,
      month_start: '2026-11-01',
      month_end: '2026-11-30',
      currency: 'IDR',
      source: 'freelance',
      is_total: false,
      income: 10000000,
      expense: 1500000,
      net: 8500000,
      txn_count: 4,
    },
    {
      workspace_id: WS_ID,
      month_start: '2026-11-01',
      month_end: '2026-11-30',
      currency: 'IDR',
      source: 'personal',
      is_total: false,
      income: 2500000,
      expense: 2350000,
      net: 150000,
      txn_count: 8,
    },
  ];

  const monthlyCategoryRows = [
    { workspace_id: WS_ID, month_start: '2026-11-01', category_id: 'cat-exp-2', category_name: 'Operasional Server', type: 'expense', total: 2100000, txn_count: 3 },
    { workspace_id: WS_ID, month_start: '2026-11-01', category_id: 'cat-exp-1', category_name: 'Konsumsi', type: 'expense', total: 1750000, txn_count: 5 },
    { workspace_id: WS_ID, month_start: '2026-11-01', category_id: 'cat-inc-1', category_name: 'Proyek Freelance', type: 'income', total: 12500000, txn_count: 4 },
  ];

  const vProjectProfit = [
    {
      workspace_id: WS_ID,
      project_id: 'proj-1',
      project_name: 'Platform Kasir UMKM',
      kind: 'freelance',
      client_name: 'PT Niaga Maju',
      status: 'berjalan',
      contract_value: 20000000,
      currency: 'IDR',
      total_invoiced: 20000000,
      total_paid: 10000000,
      total_expense: 1500000,
      platform_fee_deducted: 0,
      net_profit: 8500000,
      margin_percent: 85,
      remaining_invoiced: 10000000,
    },
  ];

  const vReceivables = [
    {
      workspace_id: WS_ID,
      payment_id: 'pay-2',
      project_id: 'proj-1',
      project_name: 'Platform Kasir UMKM',
      client_name: 'PT Niaga Maju',
      label: 'Termin 2 (Pelunasan)',
      amount: 10000000,
      paid_amount: 0,
      remaining_amount: 10000000,
      due_date: toWibDateStr(10),
      status: 'pending',
      is_overdue: false,
      days_overdue: 0,
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
            'content-range': Array.isArray(data) ? `0-${Math.max(0, data.length - 1)}/${data.length}` : '0-0/1',
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
      const agendaList = [
        ...events
          .filter((e) => !e.deleted_at)
          .map((e) => ({
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
        ...tasks
          .filter((t) => !t.deleted_at && t.due_at)
          .map((t) => ({
            id: `task-${t.id}`,
            item_type: 'task',
            title: String(t.title),
            kind: String(t.kind),
            starts_at: String(t.due_at),
            ends_at: String(t.due_at),
            all_day: false,
            location: null,
            status: String(t.status),
            priority: String(t.priority),
            is_recurring: false,
            event_id: null,
          })),
      ];
      return respond(agendaList);
    }

    if (pathname.endsWith('/rpc/fn_detect_conflicts')) {
      return respond([
        {
          conflict_date: todayStr,
          event1_id: 'ev-1',
          event1_title: 'Review Sprint POS UMKM',
          event1_starts_at: isoAtWib(0, 9, 0),
          event1_ends_at: isoAtWib(0, 11, 0),
          event2_id: 'ev-2',
          event2_title: 'Bimbingan Skripsi',
          event2_starts_at: isoAtWib(0, 10, 0),
          event2_ends_at: isoAtWib(0, 11, 30),
          is_heavy_day: false,
        },
      ]);
    }

    if (pathname.endsWith('/rpc/fn_my_sessions')) {
      return respond([
        {
          id: 'sess-1',
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
      let rows = [...workspaceMembers];
      const userIdEq = url.searchParams.get('user_id');
      if (userIdEq?.startsWith('eq.')) {
        const uid = userIdEq.slice(3);
        rows = rows.filter((m) => m.user_id === uid);
      }
      const wsIdEq = url.searchParams.get('workspace_id');
      if (wsIdEq?.startsWith('eq.')) {
        const wid = wsIdEq.slice(3);
        rows = rows.filter((m) => m.workspace_id === wid);
      }
      const limitParam = url.searchParams.get('limit');
      if (limitParam) {
        const lim = Number(limitParam);
        if (Number.isFinite(lim) && lim > 0) {
          rows = rows.slice(0, lim);
        }
      }
      return respond(wantsObject ? rows[0] ?? null : rows);
    }

    if (pathname.endsWith('/workspace_invites')) {
      if (method === 'POST') {
        const body = req.postDataJSON() as Record<string, unknown>;
        const row = {
          id: `inv-${workspaceInvites.length + 1}`,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
          accepted_at: null,
          revoked_at: null,
          created_by: USER_ID,
          ...body,
        };
        workspaceInvites.unshift(row);
        return respond(wantsObject ? row : [row]);
      }
      if (method === 'DELETE') {
        const idEq = url.searchParams.get('id')?.replace('eq.', '');
        const idx = workspaceInvites.findIndex((x) => x.id === idEq);
        if (idx >= 0) workspaceInvites.splice(idx, 1);
        return respond([]);
      }
      return respond(workspaceInvites);
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

    if (pathname.endsWith('/calendar_connections')) {
      return respond(wantsObject ? null : []);
    }

    if (pathname.endsWith('/events')) {
      if (method === 'POST') {
        const raw = req.postDataJSON();
        const items = Array.isArray(raw) ? raw : [raw];
        const created = items.map((item, idx) => ({
          id: `ev-new-${events.length + idx + 1}`,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
          deleted_at: null,
          ...item,
        }));
        events.push(...created);
        return respond(wantsObject ? created[0] : created);
      }
      return respond(events.filter((e) => !e.deleted_at));
    }

    if (pathname.endsWith('/accounts')) {
      return respond(accounts);
    }

    if (pathname.endsWith('/categories')) {
      return respond(categories);
    }

    if (pathname.endsWith('/transactions')) {
      if (method === 'POST') {
        const raw = req.postDataJSON();
        const items = Array.isArray(raw) ? raw : [raw];
        const created = items.map((item, idx) => ({
          id: `tx-new-${transactions.length + idx + 1}`,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
          deleted_at: null,
          categories: { name: 'Konsumsi' },
          accounts: { name: 'BCA Tabungan' },
          ...item,
        }));
        transactions.unshift(...created);
        return respond(wantsObject ? created[0] : created);
      }
      return respond(transactions.filter((t) => !t.deleted_at));
    }

    if (pathname.endsWith('/v_monthly_summary')) {
      return respond(monthlySummaryRows);
    }

    if (pathname.endsWith('/v_monthly_category_summary')) {
      return respond(monthlyCategoryRows);
    }

    if (pathname.endsWith('/projects')) {
      return respond(projects);
    }

    if (pathname.endsWith('/project_payments')) {
      return respond(projectPayments);
    }

    if (pathname.endsWith('/v_project_profit')) {
      return respond(vProjectProfit);
    }

    if (pathname.endsWith('/v_receivables')) {
      return respond(vReceivables);
    }

    if (pathname.endsWith('/tasks')) {
      if (method === 'PATCH') {
        const body = req.postDataJSON() as Record<string, unknown>;
        const idEq = url.searchParams.get('id')?.replace('eq.', '');
        const idx = tasks.findIndex((t) => t.id === idEq);
        if (idx >= 0) {
          tasks[idx] = { ...tasks[idx], ...body, updated_at: new Date().toISOString() };
          return respond(wantsObject ? tasks[idx] : [tasks[idx]]);
        }
      }
      return respond(tasks.filter((t) => !t.deleted_at));
    }

    if (pathname.endsWith('/task_time_logs')) {
      if (method === 'POST') {
        const body = req.postDataJSON() as Record<string, unknown>;
        const created = {
          id: `tl-${taskTimeLogs.length + 1}`,
          user_id: USER_ID,
          created_at: new Date().toISOString(),
          deleted_at: null,
          ...body,
        };
        taskTimeLogs.unshift(created);
        return respond(wantsObject ? created : [created]);
      }
      return respond(taskTimeLogs.filter((l) => !l.deleted_at));
    }

    return respond([]);
  });

  const ssrSessionPayload = {
    access_token: 'e2e-wave2-access-token',
    refresh_token: 'e2e-wave2-refresh-token',
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

test.describe('Orbit Web v2 Gelombang 2 Modules', () => {
  test('1. /jadwal mendukung Daftar, Kalender, Linimasa, dan Impor/Ekspor .ics + status jujur Google', async ({
    page,
  }) => {
    await setupWave2MockApi(page);
    await page.goto('/jadwal');

    await expect(page.getByRole('heading', { name: 'Agenda' })).toBeVisible();
    await expect(page.getByText('Review Sprint POS UMKM').first()).toBeVisible();
    await expect(page.getByText(/OAuth Belum Terkonfigurasi|Google/i).first()).toBeVisible();

    // Pindah ke tab Kalender bulanan
    await page.getByRole('tab', { name: 'Kalender' }).click();
    await expect(page.getByText('Sen', { exact: true }).first()).toBeVisible();
    await expect(page.getByText('Min', { exact: true }).first()).toBeVisible();
    await captureScreen(page, 'wave2-web-jadwal-kalender.png');

    // Pindah ke tab Linimasa jam (06:00-23:00)
    await page.getByRole('tab', { name: 'Linimasa' }).click();
    await expect(page.getByText('08:00').first()).toBeVisible();
    await expect(page.getByText('Bentrok').first()).toBeVisible();
    await captureScreen(page, 'wave2-web-jadwal-linimasa.png');

    // Uji modal Impor .ics
    await page.getByRole('button', { name: 'Impor .ics' }).click();
    const textarea = page.locator('textarea');
    await textarea.fill(
      [
        'BEGIN:VCALENDAR',
        'VERSION:2.0',
        'BEGIN:VEVENT',
        'SUMMARY:Workshop Keamanan API',
        `DTSTART:${toWibDateStr(1).replace(/-/g, '')}T090000`,
        `DTEND:${toWibDateStr(1).replace(/-/g, '')}T110000`,
        'LOCATION:Auditorium',
        'END:VEVENT',
        'END:VCALENDAR',
      ].join('\n')
    );
    await expect(page.getByText('Pratinjau: 1 acara siap diimpor')).toBeVisible();
    await page.getByRole('button', { name: 'Impor 1 Acara' }).click();
    await expect(page.getByText('Berhasil mengimpor 1 acara dari file .ics ke Orbit.')).toBeVisible();
  });

  test('2. /ringkasan menampilkan grafik SVG CSP-safe dan /transaksi mendukung Impor CSV & Ekspor CSV', async ({
    page,
  }) => {
    await setupWave2MockApi(page);

    // Cek Ringkasan & Grafik SVG
    await page.goto('/ringkasan');
    await expect(
      page.getByRole('img', { name: /Grafik batang arus kas bulanan/i })
    ).toBeVisible();
    await expect(page.getByRole('heading', { name: 'Komposisi Kategori' })).toBeVisible();
    await page.getByRole('button', { name: 'Pemasukan' }).click();
    await expect(page.getByText('Proyek Freelance').first()).toBeVisible();
    await captureScreen(page, 'wave2-web-ringkasan.png');

    // Cek Transaksi + Modal Impor CSV
    await page.goto('/transaksi');
    await expect(page.getByText('PT Niaga Maju').first()).toBeVisible();
    await page.getByRole('button', { name: 'Impor CSV' }).click();
    await expect(page.getByText('Impor Mutasi Rekening (CSV)')).toBeVisible();

    const csvTextarea = page.locator('textarea');
    await csvTextarea.fill(
      [
        'Tanggal;Keterangan;Debit;Kredit;Saldo',
        '15/11/2026;Warung Makan Sederhana;45.000;0;4.955.000',
        '16/11/2026;Refund Biaya Admin;0;15.000;4.970.000',
      ].join('\n')
    );
    await expect(page.getByText(/2 baris siap diimpor/i)).toBeVisible();
    await captureScreen(page, 'wave2-web-transaksi-csv.png');

    await page.getByRole('button', { name: 'Impor 2 Transaksi' }).click();
    await expect(page.getByText('Berhasil mengimpor 2 baris mutasi CSV ke Orbit.')).toBeVisible();
  });

  test('3. /proyek menampilkan Daftar, Linimasa Gantt, Beban Kerja, dan Laporan Margin', async ({
    page,
  }) => {
    await setupWave2MockApi(page);
    await page.goto('/proyek');

    await expect(page.getByText('Platform Kasir UMKM').first()).toBeVisible();
    await expect(page.getByText('Progres Tugas').first()).toBeVisible();

    // Tab Linimasa Gantt
    await page.getByRole('tab', { name: 'Linimasa Gantt' }).click();
    await expect(page.getByText('Linimasa Gantt Proyek & Tenggat Tugas')).toBeVisible();
    await page.getByRole('button', { name: 'Mingguan (30H)' }).click();
    await captureScreen(page, 'wave2-web-proyek-gantt.png');

    // Tab Beban Kerja
    await page.getByRole('tab', { name: 'Beban Kerja' }).click();
    await expect(page.getByText('Matriks Beban Kerja per Penanggung Jawab')).toBeVisible();
    await expect(page.getByText('Beban Tinggi').first()).toBeVisible();
    await captureScreen(page, 'wave2-web-proyek-workload.png');

    // Tab Laporan & Piutang
    await page.getByRole('tab', { name: /Laporan & Piutang/i }).click();
    await expect(
      page.getByText(/Laporan Keuangan Proyek, Sisa Tagihan & Margin Bersih/i)
    ).toBeVisible();
    await expect(page.getByRole('button', { name: 'Ekspor CSV' })).toBeVisible();
  });

  test('4. /pengaturan menampilkan Kolaborasi & status jujur, dan /tugas Side Peek memiliki TimeTrackerBlock + Penanggung Jawab (Dark Mode)', async ({
    page,
  }) => {
    await setupWave2MockApi(page);

    await page.goto('/pengaturan');
    await expect(page.getByText('Kolaborasi & Anggota Ruang Kerja')).toBeVisible();
    await expect(page.getByText('Nadia Pratama (nadia@orbit.local)')).toBeVisible();
    await expect(page.getByText('Gelombang 3 (Android)')).toBeVisible();

    await page.getByPlaceholder('rekan@contoh.com').fill('rekan@orbit.local');
    await page.getByRole('button', { name: 'Undang' }).click();
    await expect(page.getByText('rekan@orbit.local').first()).toBeVisible();
    await expect(page.getByRole('button', { name: 'Salin Tautan' })).toBeVisible();
    await captureScreen(page, 'wave2-web-pengaturan.png');

    // Buka /tugas Side Peek + uji TimeTrackerBlock & mode gelap
    await page.goto('/tugas');
    await page.getByText('Implementasi modul cetak struk PDF & CSV').first().click();

    await expect(page.getByLabel('Pilih penanggung jawab tugas')).toBeVisible();
    await expect(page.getByText('Pelacak Waktu & Mode Fokus')).toBeVisible();

    await page.getByPlaceholder('Misal: Riset referensi antarmuka').fill('Verifikasi BOM Excel');
    await page.getByRole('button', { name: 'Catat', exact: true }).click();
    await expect(page.getByText('Verifikasi BOM Excel')).toBeVisible();
    await captureScreen(page, 'wave2-web-tugas-timetracker.png');

    // Uji mode gelap tetap rapi
    await page.evaluate(() => {
      document.documentElement.classList.add('dark');
    });
    await page.waitForTimeout(150);
    await captureScreen(page, 'wave2-web-dark.png');
  });
});
