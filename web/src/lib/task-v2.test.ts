import test from 'node:test';
import assert from 'node:assert/strict';
import {
  applyTaskFilters,
  buildTemplateBlocks,
  computeAttentionSummary,
  computeTaskProgress,
  DEFAULT_TASK_FILTERS,
  formatRecurrenceLabel,
  getSavedViewHref,
  isTaskOverdue,
  isTaskStagnant,
  isWithinDoneWindow,
  partitionKanbanDoneTasks,
  parseRecurrenceRule,
  parseSavedViewFilter,
  parseTemplateBlocks,
  parseTemplateChecklist,
  plainTextToTiptapDoc,
  serializeRecurrenceRule,
  snapProgressStep5,
  sortTaskItems,
  tiptapDocToPlainText,
  validateRevisionTransition,
} from './task-v2';

test('Filter Done 14 hari pada kolom Selesai Kanban', () => {
  const now = new Date('2026-11-15T12:00:00Z');
  const recentDone = {
    id: 't1',
    status: 'done',
    completed_at: '2026-11-05T10:00:00Z',
    status_changed_at: '2026-11-05T10:00:00Z',
  };
  const exact14dDone = {
    id: 't2',
    status: 'done',
    completed_at: '2026-11-01T12:00:00Z',
    status_changed_at: '2026-11-01T12:00:00Z',
  };
  const oldDone = {
    id: 't3',
    status: 'done',
    completed_at: '2026-10-25T10:00:00Z',
    status_changed_at: '2026-10-25T10:00:00Z',
  };

  assert.equal(isWithinDoneWindow(recentDone, now), true);
  assert.equal(isWithinDoneWindow(exact14dDone, now), true);
  assert.equal(isWithinDoneWindow(oldDone, now), false);

  const defaultView = partitionKanbanDoneTasks([recentDone, exact14dDone, oldDone], false, now);
  assert.equal(defaultView.visible.length, 2);
  assert.equal(defaultView.hiddenCount, 1);

  const expandedView = partitionKanbanDoneTasks([recentDone, exact14dDone, oldDone], true, now);
  assert.equal(expandedView.visible.length, 3);
  assert.equal(expandedView.hiddenCount, 1);
});

test('Deteksi tugas macet > 5 hari', () => {
  const now = new Date('2026-11-15T12:00:00Z');

  assert.equal(
    isTaskStagnant({ status: 'doing', status_changed_at: '2026-11-09T11:59:00Z' }, now),
    true
  );
  assert.equal(
    isTaskStagnant({ status: 'todo', status_changed_at: '2026-11-10T12:00:00Z' }, now),
    false
  );
  assert.equal(
    isTaskStagnant({ status: 'revisi', status_changed_at: '2026-11-01T00:00:00Z' }, now),
    true
  );
  assert.equal(
    isTaskStagnant({ status: 'done', status_changed_at: '2026-10-01T00:00:00Z' }, now),
    false
  );
});

test('Deteksi keterlambatan tugas menghormati mode date-only WIB dan timestamp', () => {
  const nowWib10am = new Date('2026-11-15T03:00:00Z'); // 10:00 WIB 15 Nov 2026
  const dueTodayDateOnly = {
    status: 'todo',
    due_at: '2026-11-15T00:00:00Z', // 07:00 WIB 15 Nov
    due_is_date_only: true,
  };
  assert.equal(isTaskOverdue(dueTodayDateOnly, nowWib10am), false);

  const dueYesterdayDateOnly = {
    status: 'doing',
    due_at: '2026-11-14T12:00:00Z',
    due_is_date_only: true,
  };
  assert.equal(isTaskOverdue(dueYesterdayDateOnly, nowWib10am), true);

  const dueTimestampPast = {
    status: 'todo',
    due_at: '2026-11-15T02:30:00Z', // 09:30 WIB < 10:00 WIB
    due_is_date_only: false,
  };
  assert.equal(isTaskOverdue(dueTimestampPast, nowWib10am), true);

  assert.equal(
    isTaskOverdue({ status: 'done', due_at: '2026-11-10T00:00:00Z', due_is_date_only: false }, nowWib10am),
    false
  );
});

test('Kalkulasi progres otomatis vs manual step-5', () => {
  assert.equal(snapProgressStep5(62), 60);
  assert.equal(snapProgressStep5(63), 65);
  assert.equal(snapProgressStep5(120), 100);
  assert.equal(snapProgressStep5(-5), 0);

  const fromChecklist = computeTaskProgress({
    status: 'doing',
    progressPercent: 10,
    checklistItems: [{ done: true }, { done: true }, { done: false }],
  });
  assert.deepEqual(fromChecklist, {
    percent: 67,
    lockedByChecklist: true,
    source: 'checklist',
  });

  const fromSubtasks = computeTaskProgress({
    status: 'todo',
    progressPercent: 0,
    subtasks: [
      { id: 's1', status: 'done' },
      { id: 's2', status: 'doing' },
      { id: 's3', status: 'done' },
      { id: 's4', status: 'todo' },
    ],
  });
  assert.deepEqual(fromSubtasks, {
    percent: 50,
    lockedByChecklist: true,
    source: 'subtasks',
  });

  const manual = computeTaskProgress({
    status: 'doing',
    progressPercent: 45,
    checklistItems: [],
    subtasks: [],
  });
  assert.deepEqual(manual, {
    percent: 45,
    lockedByChecklist: false,
    source: 'manual',
  });

  const doneTask = computeTaskProgress({
    status: 'done',
    progressPercent: 40,
    checklistItems: [{ done: false }],
  });
  assert.equal(doneTask.percent, 100);
  assert.equal(doneTask.lockedByChecklist, true);
});

test('Validasi catatan wajib saat pindah ke status Revisi', () => {
  const emptyRes = validateRevisionTransition({ fromStatus: 'doing', toStatus: 'revisi', note: '   ' });
  assert.equal(emptyRes.valid, false);
  assert.ok(emptyRes.error);

  const okRes = validateRevisionTransition({
    fromStatus: 'doing',
    toStatus: 'revisi',
    note: '  Perbaiki validasi webhook  ',
  });
  assert.equal(okRes.valid, true);
  assert.equal(okRes.cleanNote, 'Perbaiki validasi webhook');

  const alreadyRevisi = validateRevisionTransition({
    fromStatus: 'revisi',
    toStatus: 'revisi',
    note: '',
  });
  assert.equal(alreadyRevisi.valid, true);
});

test('Parsing, serialisasi, dan format recurrence_rule', () => {
  assert.equal(serializeRecurrenceRule('none', 2), null);
  assert.deepEqual(serializeRecurrenceRule('weekly', 2), { freq: 'weekly', interval: 2 });
  assert.deepEqual(parseRecurrenceRule({ freq: 'monthly', interval: 3 }), {
    freq: 'monthly',
    interval: 3,
  });
  assert.equal(parseRecurrenceRule({ freq: 'yearly' }), null);
  assert.equal(formatRecurrenceLabel(null), 'Tidak berulang');
  assert.equal(formatRecurrenceLabel({ freq: 'daily', interval: 1 }), 'Setiap hari');
  assert.equal(formatRecurrenceLabel({ freq: 'weekly', interval: 2 }), 'Setiap 2 minggu');
});

test('Saved views filter parsing, aplikasi filter, sorting, dan routing', () => {
  const parsed = parseSavedViewFilter({
    kind: 'freelance',
    priority: 'tinggi',
    attention: 'revisi',
    search: 'webhook',
  });
  assert.equal(parsed.kind, 'freelance');
  assert.equal(parsed.priority, 'tinggi');
  assert.equal(parsed.attention, 'revisi');
  assert.equal(parsed.search, 'webhook');

  assert.equal(getSavedViewHref({ id: 'v1', scope: 'tasks' }), '/tugas?view=v1');
  assert.equal(getSavedViewHref({ id: 'v2', scope: 'agenda' }), '/jadwal?view=v2');
  assert.equal(getSavedViewHref({ id: 'v3', scope: 'transactions' }), '/transaksi?view=v3');
  assert.equal(getSavedViewHref({ id: 'v4', scope: 'projects' }), '/proyek?view=v4');

  const sampleTasks = [
    {
      id: 'a',
      title: 'Fix webhook Midtrans',
      kind: 'freelance',
      priority: 'tinggi',
      status: 'revisi',
      project_id: 'p1',
      sort_order: 2,
      tags: ['api', 'payment'],
    },
    {
      id: 'b',
      title: 'Baca modul kuliah',
      kind: 'kuliah',
      priority: 'rendah',
      status: 'todo',
      project_id: 'p2',
      sort_order: 1,
      tags: ['kuliah'],
    },
  ];

  const filtered = applyTaskFilters(sampleTasks, parsed);
  assert.equal(filtered.length, 1);
  assert.equal(filtered[0].id, 'a');

  const sorted = sortTaskItems(sampleTasks, { by: 'priority_desc' });
  assert.equal(sorted[0].id, 'a');

  const sortedDefault = sortTaskItems(sampleTasks, { by: 'board_default' });
  assert.equal(sortedDefault[0].id, 'b');

  const tagFiltered = applyTaskFilters(sampleTasks, {
    ...DEFAULT_TASK_FILTERS,
    tag: 'pay',
  });
  assert.equal(tagFiltered.length, 1);
  assert.equal(tagFiltered[0].id, 'a');
});

test('Sinkronisasi Tiptap doc, Template blocks, dan Attention summary', () => {
  const doc = plainTextToTiptapDoc('Baris pertama\nBaris kedua');
  assert.equal(tiptapDocToPlainText(doc), 'Baris pertama\nBaris kedua');

  const built = buildTemplateBlocks({
    doc,
    tags: ['urgent', 'sprint'],
    recurrenceRule: { freq: 'weekly', interval: 1 },
    description: 'Baris pertama\nBaris kedua',
  });
  const parsedTpl = parseTemplateBlocks(built);
  assert.deepEqual(parsedTpl.tags, ['urgent', 'sprint']);
  assert.deepEqual(parsedTpl.recurrenceRule, { freq: 'weekly', interval: 1 });
  assert.equal(parsedTpl.description, 'Baris pertama\nBaris kedua');

  const checklist = parseTemplateChecklist(['Siapkan repo', { text: 'Tulis test' }]);
  assert.deepEqual(checklist, ['Siapkan repo', 'Tulis test']);

  const now = new Date('2026-11-15T12:00:00Z');
  const summary = computeAttentionSummary({
    tasks: [
      {
        id: '1',
        title: 'Telat & Macet',
        status: 'doing',
        priority: 'tinggi',
        kind: 'intern',
        due_at: '2026-11-10T10:00:00Z',
        status_changed_at: '2026-11-05T10:00:00Z',
      },
      {
        id: '2',
        title: 'Revisi',
        status: 'revisi',
        priority: 'sedang',
        kind: 'freelance',
        status_changed_at: '2026-11-14T10:00:00Z',
      },
      {
        id: '3',
        title: 'Selesai',
        status: 'done',
        priority: 'rendah',
        kind: 'pribadi',
        due_at: '2026-11-01T10:00:00Z',
        status_changed_at: '2026-10-01T10:00:00Z',
      },
    ],
    conflictCount: 2,
    now,
  });

  assert.equal(summary.overdueCount, 1);
  assert.equal(summary.revisiCount, 1);
  assert.equal(summary.stagnantCount, 1);
  assert.equal(summary.conflictCount, 2);
  assert.equal(summary.totalAttention, 5);
});
