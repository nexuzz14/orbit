import { test, expect, type Page } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';

const ARTIFACT_DIR =
  process.env.ORBIT_ARTIFACT_DIR ||
  path.resolve(__dirname, '../test-results/artifacts');
const WS_ID = 'ws-orbit-wave1';
const NOW = Date.now();
const isoDaysAgo = (days: number) => new Date(NOW - days * 86400000).toISOString();
const TODAY_KEY = new Date(NOW).toISOString().slice(0, 10);

interface MockTask {
  id: string;
  workspace_id: string;
  project_id: string | null;
  kind: 'kuliah' | 'freelance' | 'intern' | 'pribadi';
  title: string;
  description: string | null;
  description_blocks: Record<string, unknown> | null;
  status: 'todo' | 'doing' | 'revisi' | 'done';
  priority: 'rendah' | 'sedang' | 'tinggi';
  due_at: string | null;
  due_is_date_only: boolean;
  completed_at: string | null;
  milestone_payment_id: string | null;
  sort_order: number;
  progress_percent: number;
  revision_count: number;
  latest_revision_note: string | null;
  status_changed_at: string;
  parent_task_id: string | null;
  assignee_id: string | null;
  recurrence_rule: Record<string, unknown> | null;
  recurrence_parent_id: string | null;
  tags: string[];
  estimate_minutes: number | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
  projects: { name: string } | null;
  task_checklist_items: Array<{
    id: string;
    task_id: string;
    text: string;
    done: boolean;
    sort_order: number;
    created_at: string;
    updated_at: string;
  }>;
}

async function setupMockOrbitApi(page: Page) {
  const projects = [
    { id: 'proj-1', workspace_id: WS_ID, name: 'Portal Klien Q4', kind: 'freelance', status: 'berjalan' },
    { id: 'proj-2', workspace_id: WS_ID, name: 'Magang Backend', kind: 'intern', status: 'berjalan' },
    { id: 'proj-3', workspace_id: WS_ID, name: 'Skripsi Sistem', kind: 'kuliah', status: 'berjalan' },
  ];

  const tasks: MockTask[] = [
    {
      id: 'task-todo-1',
      workspace_id: WS_ID,
      project_id: 'proj-1',
      kind: 'freelance',
      title: 'Susun spesifikasi API webhook pembayaran',
      description: 'Dokumentasi endpoint callback, signature HMAC, dan retry policy.',
      description_blocks: {
        type: 'doc',
        content: [
          {
            type: 'paragraph',
            content: [{ type: 'text', text: 'Dokumentasi endpoint callback, signature HMAC, dan retry policy.' }],
          },
        ],
      },
      status: 'todo',
      priority: 'tinggi',
      due_at: isoDaysAgo(-2),
      due_is_date_only: false,
      completed_at: null,
      milestone_payment_id: null,
      sort_order: 1000,
      progress_percent: 50,
      revision_count: 0,
      latest_revision_note: null,
      status_changed_at: isoDaysAgo(1),
      parent_task_id: null,
      assignee_id: null,
      recurrence_rule: null,
      recurrence_parent_id: null,
      tags: ['api', 'webhook'],
      estimate_minutes: 90,
      created_at: isoDaysAgo(2),
      updated_at: isoDaysAgo(1),
      deleted_at: null,
      projects: { name: 'Portal Klien Q4' },
      task_checklist_items: [
        {
          id: 'chk-1',
          task_id: 'task-todo-1',
          text: 'Verifikasi header X-Orbit-Signature',
          done: true,
          sort_order: 1,
          created_at: isoDaysAgo(2),
          updated_at: isoDaysAgo(1),
        },
        {
          id: 'chk-2',
          task_id: 'task-todo-1',
          text: 'Tulis kontrak JSON error timeout',
          done: false,
          sort_order: 2,
          created_at: isoDaysAgo(2),
          updated_at: isoDaysAgo(1),
        },
      ],
    },
    {
      id: 'task-doing-1',
      workspace_id: WS_ID,
      project_id: 'proj-2',
      kind: 'intern',
      title: 'Optimasi query index tabel transaksi',
      description: 'Menurunkan waktu p95 endpoint riwayat dari 420ms menjadi <80ms.',
      description_blocks: null,
      status: 'doing',
      priority: 'tinggi',
      due_at: isoDaysAgo(1),
      due_is_date_only: false,
      completed_at: null,
      milestone_payment_id: null,
      sort_order: 1000,
      progress_percent: 65,
      revision_count: 0,
      latest_revision_note: null,
      status_changed_at: isoDaysAgo(7),
      parent_task_id: null,
      assignee_id: null,
      recurrence_rule: { freq: 'weekly', interval: 1 },
      recurrence_parent_id: null,
      tags: ['postgres', 'perf'],
      estimate_minutes: 120,
      created_at: isoDaysAgo(9),
      updated_at: isoDaysAgo(7),
      deleted_at: null,
      projects: { name: 'Magang Backend' },
      task_checklist_items: [],
    },
    {
      id: 'task-revisi-1',
      workspace_id: WS_ID,
      project_id: 'proj-1',
      kind: 'freelance',
      title: 'Perbaiki validasi form checkout termin klien',
      description: 'Validasi nominal termin wajib lebih besar dari biaya admin.',
      description_blocks: null,
      status: 'revisi',
      priority: 'sedang',
      due_at: isoDaysAgo(-1),
      due_is_date_only: false,
      completed_at: null,
      milestone_payment_id: null,
      sort_order: 1000,
      progress_percent: 45,
      revision_count: 2,
      latest_revision_note: 'Tombol submit masih aktif saat nominal termin nol.',
      status_changed_at: isoDaysAgo(2),
      parent_task_id: null,
      assignee_id: null,
      recurrence_rule: null,
      recurrence_parent_id: null,
      tags: ['ui', 'revisi'],
      estimate_minutes: 45,
      created_at: isoDaysAgo(5),
      updated_at: isoDaysAgo(2),
      deleted_at: null,
      projects: { name: 'Portal Klien Q4' },
      task_checklist_items: [],
    },
    {
      id: 'task-sub-1',
      workspace_id: WS_ID,
      project_id: 'proj-1',
      kind: 'freelance',
      title: 'Tambah unit test payload kosong HMAC',
      description: null,
      description_blocks: null,
      status: 'done',
      priority: 'rendah',
      due_at: null,
      due_is_date_only: false,
      completed_at: isoDaysAgo(1),
      milestone_payment_id: null,
      sort_order: 1000,
      progress_percent: 100,
      revision_count: 0,
      latest_revision_note: null,
      status_changed_at: isoDaysAgo(1),
      parent_task_id: 'task-todo-1',
      assignee_id: null,
      recurrence_rule: null,
      recurrence_parent_id: null,
      tags: ['test'],
      estimate_minutes: 20,
      created_at: isoDaysAgo(2),
      updated_at: isoDaysAgo(1),
      deleted_at: null,
      projects: { name: 'Portal Klien Q4' },
      task_checklist_items: [],
    },
    {
      id: 'task-done-recent',
      workspace_id: WS_ID,
      project_id: 'proj-3',
      kind: 'kuliah',
      title: 'Kumpulkan draft bab 2 tinjauan pustaka',
      description: null,
      description_blocks: null,
      status: 'done',
      priority: 'sedang',
      due_at: null,
      due_is_date_only: false,
      completed_at: isoDaysAgo(3),
      milestone_payment_id: null,
      sort_order: 2000,
      progress_percent: 100,
      revision_count: 0,
      latest_revision_note: null,
      status_changed_at: isoDaysAgo(3),
      parent_task_id: null,
      assignee_id: null,
      recurrence_rule: null,
      recurrence_parent_id: null,
      tags: ['skripsi'],
      estimate_minutes: 60,
      created_at: isoDaysAgo(6),
      updated_at: isoDaysAgo(3),
      deleted_at: null,
      projects: { name: 'Skripsi Sistem' },
      task_checklist_items: [],
    },
    {
      id: 'task-done-old',
      workspace_id: WS_ID,
      project_id: 'proj-3',
      kind: 'kuliah',
      title: 'Arsip proposal awal semester (25 hari lalu)',
      description: null,
      description_blocks: null,
      status: 'done',
      priority: 'rendah',
      due_at: null,
      due_is_date_only: false,
      completed_at: isoDaysAgo(25),
      milestone_payment_id: null,
      sort_order: 3000,
      progress_percent: 100,
      revision_count: 0,
      latest_revision_note: null,
      status_changed_at: isoDaysAgo(25),
      parent_task_id: null,
      assignee_id: null,
      recurrence_rule: null,
      recurrence_parent_id: null,
      tags: ['arsip'],
      estimate_minutes: 30,
      created_at: isoDaysAgo(30),
      updated_at: isoDaysAgo(25),
      deleted_at: null,
      projects: { name: 'Skripsi Sistem' },
      task_checklist_items: [],
    },
  ];

  const savedViews = [
    {
      id: 'sv-revisi',
      workspace_id: WS_ID,
      name: 'Fokus Revisi Klien',
      scope: 'tasks',
      view_mode: 'board',
      filter_json: { attention: 'revisi' },
      sort_json: { field: 'priority', direction: 'desc' },
      is_pinned: true,
      sort_order: 1,
      created_at: isoDaysAgo(4),
      updated_at: isoDaysAgo(4),
      deleted_at: null,
    },
  ];

  const templates = [
    {
      id: 'tpl-1',
      workspace_id: WS_ID,
      name: 'Review PR Backend',
      kind: 'intern',
      title_template: 'Review PR layanan pembayaran',
      description: 'Periksa skema validasi, migrasi aman, dan coverage unit test.',
      priority: 'tinggi',
      estimate_minutes: 45,
      default_checklists: ['Cek migrasi database', 'Verifikasi unit test', 'Uji kasus edge timeout'],
      recurrence_rule: null,
      tags: ['review', 'backend'],
      created_at: isoDaysAgo(5),
      updated_at: isoDaysAgo(5),
      deleted_at: null,
    },
  ];

  const statusHistory = [
    {
      id: 'hist-1',
      task_id: 'task-todo-1',
      workspace_id: WS_ID,
      from_status: 'todo',
      to_status: 'doing',
      note: 'Mulai penyusunan dokumen OpenAPI.',
      changed_at: isoDaysAgo(2),
    },
    {
      id: 'hist-2',
      task_id: 'task-todo-1',
      workspace_id: WS_ID,
      from_status: 'doing',
      to_status: 'todo',
      note: 'Menunggu konfirmasi secret header dari vendor.',
      changed_at: isoDaysAgo(1),
    },
  ];

  const comments = [
    {
      id: 'cmt-1',
      workspace_id: WS_ID,
      entity_type: 'task',
      entity_id: 'task-todo-1',
      author_id: 'e2e-wave1-user',
      body: 'Pastikan timestamp tolerance 300 detik terdokumentasi di README.',
      created_at: isoDaysAgo(1),
      updated_at: isoDaysAgo(1),
      deleted_at: null,
    },
  ];

  const rpcCalls: Array<{ fn: string; body: Record<string, unknown> }> = [];

  await page.route('**/auth/v1/**', async (route) => {
    return route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({
        id: 'e2e-wave1-user',
        aud: 'authenticated',
        role: 'authenticated',
        email: 'wave1@orbit.local',
      }),
    });
  });

  await page.route('**/rest/v1/**', async (route) => {
    const req = route.request();
    const url = req.url();
    const method = req.method();
    const accept = req.headers()['accept'] ?? '';
    const wantsObject = accept.includes('vnd.pgrst.object');

    const respond = (data: unknown) => {
      if (method === 'HEAD') {
        return route.fulfill({
          status: 200,
          headers: { 'content-range': Array.isArray(data) ? `0-0/${data.length}` : '0-0/1' },
          body: '',
        });
      }
      return route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify(data),
      });
    };

    const pathname = new URL(url).pathname;

    if (pathname.endsWith('/rpc/fn_global_search')) {
      const payload = (req.postDataJSON() ?? {}) as Record<string, unknown>;
      const q = String(payload.p_query ?? '').toLowerCase();
      rpcCalls.push({ fn: 'fn_global_search', body: payload });
      const hits = tasks
        .filter((t) => t.title.toLowerCase().includes(q) || !q)
        .map((t) => ({
          entity_type: 'task',
          entity_id: t.id,
          title: t.title,
          subtitle: t.projects?.name ?? 'Tugas',
          status_label: t.status,
          kind: t.kind,
        }));
      return respond(hits);
    }

    if (pathname.endsWith('/rpc/fn_change_task_status')) {
      const payload = (req.postDataJSON() ?? {}) as Record<string, unknown>;
      rpcCalls.push({ fn: 'fn_change_task_status', body: payload });
      const taskId = String(payload.p_task_id);
      const toStatus = payload.p_to_status as MockTask['status'];
      const note = typeof payload.p_note === 'string' ? payload.p_note : null;
      const sortOrder = typeof payload.p_sort_order === 'number' ? payload.p_sort_order : undefined;

      const idx = tasks.findIndex((t) => t.id === taskId);
      if (idx >= 0) {
        const cur = tasks[idx];
        tasks[idx] = {
          ...cur,
          status: toStatus,
          sort_order: sortOrder ?? cur.sort_order,
          revision_count: toStatus === 'revisi' ? cur.revision_count + 1 : cur.revision_count,
          latest_revision_note: toStatus === 'revisi' ? note : cur.latest_revision_note,
          status_changed_at: new Date().toISOString(),
          completed_at: toStatus === 'done' ? new Date().toISOString() : null,
          progress_percent: toStatus === 'done' ? 100 : cur.progress_percent,
          updated_at: new Date().toISOString(),
        };
        return respond(tasks[idx]);
      }
      return respond(null);
    }

    if (pathname.endsWith('/rpc/fn_agenda')) {
      return respond([
        {
          id: 'ev-1',
          item_type: 'event',
          kind: 'intern',
          title: 'Standup Tim Engineering',
          description: null,
          project_id: 'proj-2',
          project_name: 'Magang Backend',
          project_color: null,
          starts_at: `${TODAY_KEY}T02:00:00.000Z`,
          ends_at: `${TODAY_KEY}T02:45:00.000Z`,
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
          is_recurring: false,
          milestone_payment_id: null,
        },
      ]);
    }

    if (pathname.endsWith('/rpc/fn_detect_conflicts')) {
      return respond([
        {
          conflict_date: TODAY_KEY,
          event1_id: 'ev-1',
          event1_title: 'Standup Tim Engineering',
          event1_starts_at: `${TODAY_KEY}T02:00:00.000Z`,
          event1_ends_at: `${TODAY_KEY}T02:45:00.000Z`,
          event2_id: 'ev-2',
          event2_title: 'Sinkronisasi Desain',
          event2_starts_at: `${TODAY_KEY}T02:30:00.000Z`,
          event2_ends_at: `${TODAY_KEY}T03:15:00.000Z`,
        },
      ]);
    }

    if (pathname.endsWith('/workspace_members')) {
      const list = [{ workspace_id: WS_ID, workspaces: { id: WS_ID, name: 'Orbit / Pribadi', type: 'personal' } }];
      return respond(wantsObject ? list[0] : list);
    }
    if (pathname.endsWith('/workspaces')) {
      const list = [{ id: WS_ID, name: 'Orbit / Pribadi', type: 'personal', month_start_day: 1 }];
      return respond(wantsObject ? list[0] : list);
    }
    if (pathname.endsWith('/projects')) {
      return respond(wantsObject ? projects[0] : projects);
    }
    if (pathname.endsWith('/saved_views')) {
      return respond(wantsObject ? savedViews[0] : savedViews);
    }
    if (pathname.endsWith('/task_templates')) {
      return respond(wantsObject ? templates[0] : templates);
    }
    if (pathname.endsWith('/task_status_history')) {
      return respond(statusHistory);
    }
    if (pathname.endsWith('/comments')) {
      return respond(comments);
    }
    if (pathname.endsWith('/tasks')) {
      if (method === 'PATCH') {
        const body = (req.postDataJSON() ?? {}) as Partial<MockTask>;
        return respond(wantsObject ? { ...tasks[0], ...body } : [{ ...tasks[0], ...body }]);
      }
      return respond(wantsObject ? tasks[0] : tasks);
    }
    if (pathname.endsWith('/accounts')) {
      return respond([{ id: 'acc-1', name: 'BCA Utama', currency: 'IDR', type: 'bank' }]);
    }
    if (pathname.endsWith('/v_account_balances')) {
      return respond([{ balance: 12450000, is_liquid: true }]);
    }

    return respond(wantsObject ? null : []);
  });

  return { rpcCalls };
}

test.describe('Gelombang 1 Web UI & Workflows Verification', () => {
  test.beforeEach(async ({ context, page }) => {
    await context.addCookies([
      {
        name: 'orbit-e2e-user',
        value: 'true',
        domain: 'localhost',
        path: '/',
      },
    ]);
    await page.addInitScript(() => {
      window.localStorage.setItem('orbit_sidebar_collapsed', 'false');
    });
  });

  test('Hari Ini Attention Banner, Sidebar Collapse, Ctrl+K Global Search, Kanban D.2, Revisi Note & Side Peek', async ({
    page,
  }) => {
    const { rpcCalls } = await setupMockOrbitApi(page);

    await page.setViewportSize({ width: 1280, height: 800 });
    await page.goto('/hari-ini', { waitUntil: 'networkidle' });

    await expect(page.getByText('Perlu Perhatian')).toBeVisible();
    await expect(page.getByText('Terlambat', { exact: true }).first()).toBeVisible();
    await expect(page.getByText('Perlu Revisi', { exact: true }).first()).toBeVisible();
    await expect(page.getByText('Macet > 5 hari', { exact: true }).first()).toBeVisible();
    await expect(page.getByText('Jadwal Bentrok', { exact: true }).first()).toBeVisible();

    fs.mkdirSync(ARTIFACT_DIR, { recursive: true });
    await page.screenshot({
      path: path.join(ARTIFACT_DIR, 'wave1-web-hari-ini-light.png'),
      fullPage: false,
    });

    // Uji Sidebar Collapsible (240px -> 56px -> 240px)
    const collapseBtn = page.getByRole('button', { name: 'Lipat sidebar' });
    await collapseBtn.click();
    await expect(page.getByRole('button', { name: 'Bentangkan sidebar' })).toBeVisible();
    await page.getByRole('button', { name: 'Bentangkan sidebar' }).click();

    // Uji Command Palette Ctrl+K + fn_global_search
    await page.keyboard.press('Control+k');
    const searchInput = page.getByPlaceholder('Cari tugas, proyek, jadwal, transaksi, atau perintah...');
    await expect(searchInput).toBeVisible();
    await searchInput.fill('webhook');
    await expect(page.getByText('Susun spesifikasi API webhook pembayaran')).toBeVisible();
    expect(rpcCalls.some((c) => c.fn === 'fn_global_search')).toBe(true);
    await page.keyboard.press('Escape');

    // Navigasi ke /tugas dan uji Kanban D.2
    await page.goto('/tugas', { waitUntil: 'networkidle' });
    await expect(page.getByRole('heading', { name: 'Tugas & Papan' })).toBeVisible();

    // Pindah ke tab Papan Kanban jika belum aktif
    const boardTab = page.getByRole('tab', { name: 'Papan Kanban' });
    await boardTab.click();

    const todoCol = page.locator('[data-column-status="todo"]');
    const doingCol = page.locator('[data-column-status="doing"]');
    const revisiCol = page.locator('[data-column-status="revisi"]');
    const doneCol = page.locator('[data-column-status="done"]');
    await expect(todoCol).toBeVisible();
    await expect(doingCol).toBeVisible();
    await expect(revisiCol).toBeVisible();
    await expect(doneCol).toBeVisible();

    // Kolom Selesai 14 hari sembunyikan arsip 25 hari lalu hingga toggle diklik
    await expect(doneCol.getByText('Kumpulkan draft bab 2 tinjauan pustaka')).toBeVisible();
    await expect(doneCol.getByText('Arsip proposal awal semester (25 hari lalu)')).toBeHidden();

    // Penanda stagnant >5 hari pada task doing
    await expect(doingCol.getByText(/Macet >5 hari/)).toBeVisible();

    await page.screenshot({
      path: path.join(ARTIFACT_DIR, 'wave1-web-tugas-kanban-light.png'),
      fullPage: false,
    });

    await doneCol.getByRole('button', { name: /Lihat semua selesai/i }).click();
    await expect(doneCol.getByText('Arsip proposal awal semester (25 hari lalu)')).toBeVisible();

    // Uji Dialog Wajib Catatan Revisi saat pindah status ke revisi
    const statusSelect = page.getByLabel('Ubah status Optimasi query index tabel transaksi');
    await statusSelect.selectOption('revisi');
    await expect(page.getByText('Pindahkan ke Status Revisi')).toBeVisible();
    const noteInput = page.locator('#revision-note-input');
    await noteInput.fill('Perlu tambah partial index deleted_at is null.');
    await page.getByRole('button', { name: /Pindahkan ke Revisi/i }).click();
    await expect(
      rpcCalls.some(
        (c) =>
          c.fn === 'fn_change_task_status' &&
          c.body.p_to_status === 'revisi' &&
          String(c.body.p_note).includes('partial index')
      )
    ).toBe(true);

    // Uji Side Peek 480px pada task dengan checklist + subtasks + comments + history
    await todoCol.getByText('Susun spesifikasi API webhook pembayaran').click();
    const peekProps = page.locator('section[aria-label="Properti tugas"]');
    await expect(peekProps).toBeVisible();
    await expect(peekProps.getByText('Otomatis', { exact: true })).toBeVisible();
    await expect(page.getByText(/Subtugas \(/)).toBeVisible();
    await expect(page.getByText(/Komentar \(/)).toBeVisible();
    await expect(page.getByText(/Riwayat Status \(/)).toBeVisible();

    await page.screenshot({
      path: path.join(ARTIFACT_DIR, 'wave1-web-tugas-peek-light.png'),
      fullPage: false,
    });

    // Screenshot Dark Mode
    await page.evaluate(() => {
      document.documentElement.classList.add('dark');
      window.localStorage.setItem('orbit_theme', 'dark');
    });
    await page.waitForTimeout(250);
    await page.screenshot({
      path: path.join(ARTIFACT_DIR, 'wave1-web-tugas-peek-dark.png'),
      fullPage: false,
    });

    // Screenshot Mobile Viewport 390x844
    await page.setViewportSize({ width: 390, height: 844 });
    await page.waitForTimeout(150);
    await page.screenshot({
      path: path.join(ARTIFACT_DIR, 'wave1-web-mobile-peek-dark.png'),
      fullPage: false,
    });
  });
});
