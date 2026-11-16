import { getDateKeyInTimezone } from './format';
import type { ActivityKind, Json, TaskPriority, TaskStatus } from '@/types/database';

export type RecurrenceFreq = 'none' | 'daily' | 'weekly' | 'monthly';

export interface RecurrenceRule {
  freq: Exclude<RecurrenceFreq, 'none'>;
  interval: number;
}

export interface TaskChecklistLite {
  id?: string;
  done: boolean;
  text?: string;
}

export interface TaskSubtaskLite {
  id: string;
  status: string;
}

export interface TaskV2Like {
  id: string;
  title: string;
  description?: string | null;
  description_blocks?: Json | null;
  status: TaskStatus | string;
  priority: TaskPriority | string;
  kind: ActivityKind | string;
  project_id?: string | null;
  due_at?: string | null;
  due_is_date_only?: boolean;
  completed_at?: string | null;
  status_changed_at?: string | null;
  updated_at?: string | null;
  created_at?: string | null;
  progress_percent?: number | null;
  revision_count?: number | null;
  latest_revision_note?: string | null;
  sort_order?: number | null;
  tags?: string[] | null;
  parent_task_id?: string | null;
  recurrence_rule?: Json | null;
  estimate_minutes?: number | null;
}

export type TaskAttentionFilter = 'all' | 'overdue' | 'revisi' | 'stagnant' | 'attention';

export interface TaskFilterState {
  search: string;
  kind: ActivityKind | 'all';
  priority: TaskPriority | 'all';
  projectId: string;
  status: TaskStatus | 'all';
  attention: TaskAttentionFilter;
  tag: string;
}

export interface TaskSortState {
  by: 'board_default' | 'due_asc' | 'priority_desc' | 'updated_desc';
}

export type SavedViewScope = 'tasks' | 'agenda' | 'transactions' | 'projects';
export type SavedViewMode = 'list' | 'board' | 'calendar' | 'timeline';

export const DEFAULT_TASK_FILTERS: TaskFilterState = {
  search: '',
  kind: 'all',
  priority: 'all',
  projectId: 'all',
  status: 'all',
  attention: 'all',
  tag: '',
};

export const DEFAULT_TASK_SORT: TaskSortState = {
  by: 'board_default',
};

const VALID_STATUSES: ReadonlySet<string> = new Set(['todo', 'doing', 'revisi', 'done']);
const VALID_PRIORITIES: ReadonlySet<string> = new Set(['rendah', 'sedang', 'tinggi']);
const VALID_KINDS: ReadonlySet<string> = new Set(['intern', 'freelance', 'kuliah', 'pribadi']);

export const DONE_WINDOW_DAYS = 14;
export const STAGNANT_DAYS_THRESHOLD = 5;
const MS_PER_DAY = 86_400_000;

export function normalizeTaskStatus(status: string | null | undefined): TaskStatus {
  if (status && VALID_STATUSES.has(status)) {
    return status as TaskStatus;
  }
  return 'todo';
}

export function normalizeTaskPriority(priority: string | null | undefined): TaskPriority {
  if (priority && VALID_PRIORITIES.has(priority)) {
    return priority as TaskPriority;
  }
  return 'sedang';
}

export function normalizeActivityKind(kind: string | null | undefined): ActivityKind {
  if (kind && VALID_KINDS.has(kind)) {
    return kind as ActivityKind;
  }
  return 'pribadi';
}

export function snapProgressStep5(value: number): number {
  if (!Number.isFinite(value)) return 0;
  const clamped = Math.max(0, Math.min(100, value));
  return Math.round(clamped / 5) * 5;
}

export function computeTaskProgress(params: {
  status: string;
  progressPercent?: number | null;
  checklistItems?: TaskChecklistLite[];
  subtasks?: TaskSubtaskLite[];
}): {
  percent: number;
  lockedByChecklist: boolean;
  source: 'done' | 'checklist' | 'subtasks' | 'manual';
} {
  const status = normalizeTaskStatus(params.status);
  const checklist = params.checklistItems ?? [];
  const subtasks = params.subtasks ?? [];
  const hasAutoSource = checklist.length > 0 || subtasks.length > 0;

  if (status === 'done') {
    return {
      percent: 100,
      lockedByChecklist: hasAutoSource,
      source: 'done',
    };
  }

  if (checklist.length > 0) {
    const doneCount = checklist.filter((item) => item.done).length;
    return {
      percent: Math.round((doneCount / checklist.length) * 100),
      lockedByChecklist: true,
      source: 'checklist',
    };
  }

  if (subtasks.length > 0) {
    const doneCount = subtasks.filter((st) => normalizeTaskStatus(st.status) === 'done').length;
    return {
      percent: Math.round((doneCount / subtasks.length) * 100),
      lockedByChecklist: true,
      source: 'subtasks',
    };
  }

  const raw = typeof params.progressPercent === 'number' && Number.isFinite(params.progressPercent)
    ? Math.max(0, Math.min(100, Math.round(params.progressPercent)))
    : 0;

  return {
    percent: raw,
    lockedByChecklist: false,
    source: 'manual',
  };
}

export function isTaskOverdue(
  task: Pick<TaskV2Like, 'status' | 'due_at' | 'due_is_date_only'>,
  now: Date = new Date(),
  timeZone = 'Asia/Jakarta'
): boolean {
  if (normalizeTaskStatus(task.status) === 'done') return false;
  if (!task.due_at) return false;

  if (task.due_is_date_only) {
    const dueKey = getDateKeyInTimezone(task.due_at, timeZone);
    const todayKey = getDateKeyInTimezone(now, timeZone);
    if (!dueKey || !todayKey) return false;
    return dueKey < todayKey;
  }

  const dueTs = new Date(task.due_at).getTime();
  if (Number.isNaN(dueTs)) return false;
  return dueTs < now.getTime();
}

export function getStagnantDays(
  task: Pick<TaskV2Like, 'status' | 'status_changed_at' | 'updated_at' | 'created_at'>,
  now: Date = new Date()
): number {
  const status = normalizeTaskStatus(task.status);
  if (status === 'done') return 0;

  const refIso = task.status_changed_at || task.updated_at || task.created_at;
  if (!refIso) return 0;
  const refMs = new Date(refIso).getTime();
  if (Number.isNaN(refMs)) return 0;

  const diffMs = now.getTime() - refMs;
  if (diffMs <= 0) return 0;
  return Math.floor(diffMs / MS_PER_DAY);
}

export function isTaskStagnant(
  task: Pick<TaskV2Like, 'status' | 'status_changed_at' | 'updated_at' | 'created_at'>,
  now: Date = new Date(),
  thresholdDays: number = STAGNANT_DAYS_THRESHOLD
): boolean {
  const status = normalizeTaskStatus(task.status);
  if (status === 'done') return false;

  const refIso = task.status_changed_at || task.updated_at || task.created_at;
  if (!refIso) return false;
  const refMs = new Date(refIso).getTime();
  if (Number.isNaN(refMs)) return false;

  return now.getTime() - refMs > thresholdDays * MS_PER_DAY;
}

export function isWithinDoneWindow(
  task: Pick<TaskV2Like, 'status' | 'completed_at' | 'status_changed_at' | 'updated_at'>,
  now: Date = new Date(),
  windowDays: number = DONE_WINDOW_DAYS
): boolean {
  if (normalizeTaskStatus(task.status) !== 'done') return false;
  const refIso = task.completed_at || task.status_changed_at || task.updated_at;
  if (!refIso) return true;
  const refMs = new Date(refIso).getTime();
  if (Number.isNaN(refMs)) return true;
  return now.getTime() - refMs <= windowDays * MS_PER_DAY;
}

export function partitionKanbanDoneTasks<
  T extends Pick<TaskV2Like, 'status' | 'completed_at' | 'status_changed_at' | 'updated_at'>
>(
  doneTasks: T[],
  showAllDone: boolean,
  now: Date = new Date(),
  windowDays: number = DONE_WINDOW_DAYS
): { visible: T[]; hiddenCount: number } {
  const recentCount = doneTasks.filter((t) => isWithinDoneWindow(t, now, windowDays)).length;
  const hiddenCount = Math.max(0, doneTasks.length - recentCount);

  if (showAllDone) {
    return { visible: doneTasks, hiddenCount };
  }

  return {
    visible: doneTasks.filter((t) => isWithinDoneWindow(t, now, windowDays)),
    hiddenCount,
  };
}

export function validateRevisionTransition(params: {
  fromStatus: string;
  toStatus: string;
  note?: string | null;
}): { valid: boolean; cleanNote: string | null; error?: string } {
  const from = normalizeTaskStatus(params.fromStatus);
  const to = normalizeTaskStatus(params.toStatus);
  const trimmed = params.note?.trim() ?? '';
  const cleanNote = trimmed.length > 0 ? trimmed.slice(0, 1000) : null;

  if (to === 'revisi' && from !== 'revisi' && !cleanNote) {
    return {
      valid: false,
      cleanNote: null,
      error: 'Catatan alasan wajib diisi saat memindahkan tugas ke Revisi.',
    };
  }

  return { valid: true, cleanNote };
}

export function parseRecurrenceRule(raw: Json | null | undefined): RecurrenceRule | null {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null;
  const obj = raw as Record<string, unknown>;
  const freq = obj.freq;
  if (freq !== 'daily' && freq !== 'weekly' && freq !== 'monthly') {
    return null;
  }
  const intervalRaw = typeof obj.interval === 'number' ? obj.interval : Number(obj.interval);
  const interval = Number.isFinite(intervalRaw) && intervalRaw >= 1 ? Math.floor(intervalRaw) : 1;
  return { freq, interval };
}

export function serializeRecurrenceRule(
  freq: RecurrenceFreq,
  interval: number = 1
): Json | null {
  if (freq === 'none') return null;
  const safeInterval = Number.isFinite(interval) && interval >= 1 ? Math.floor(interval) : 1;
  return { freq, interval: safeInterval };
}

export function formatRecurrenceLabel(raw: Json | null | undefined): string {
  const parsed = parseRecurrenceRule(raw);
  if (!parsed) return 'Tidak berulang';

  const unitMap: Record<RecurrenceRule['freq'], string> = {
    daily: 'hari',
    weekly: 'minggu',
    monthly: 'bulan',
  };

  if (parsed.interval === 1) {
    return `Setiap ${unitMap[parsed.freq]}`;
  }
  return `Setiap ${parsed.interval} ${unitMap[parsed.freq]}`;
}

export function parseSavedViewFilter(raw: Json | null | undefined): TaskFilterState {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    return { ...DEFAULT_TASK_FILTERS };
  }
  const obj = raw as Record<string, unknown>;
  const kindVal = typeof obj.kind === 'string' && (obj.kind === 'all' || VALID_KINDS.has(obj.kind))
    ? (obj.kind as ActivityKind | 'all')
    : 'all';
  const priorityVal =
    typeof obj.priority === 'string' && (obj.priority === 'all' || VALID_PRIORITIES.has(obj.priority))
      ? (obj.priority as TaskPriority | 'all')
      : 'all';
  const statusVal =
    typeof obj.status === 'string' && (obj.status === 'all' || VALID_STATUSES.has(obj.status))
      ? (obj.status as TaskStatus | 'all')
      : 'all';
  const attentionVal =
    obj.attention === 'overdue' ||
    obj.attention === 'revisi' ||
    obj.attention === 'stagnant' ||
    obj.attention === 'attention'
      ? obj.attention
      : 'all';

  return {
    search: typeof obj.search === 'string' ? obj.search : '',
    kind: kindVal,
    priority: priorityVal,
    projectId: typeof obj.projectId === 'string' && obj.projectId ? obj.projectId : 'all',
    status: statusVal,
    attention: attentionVal,
    tag: typeof obj.tag === 'string' ? obj.tag : '',
  };
}

export function serializeSavedViewFilter(filter: TaskFilterState): Json {
  return {
    search: filter.search,
    kind: filter.kind,
    priority: filter.priority,
    projectId: filter.projectId,
    status: filter.status,
    attention: filter.attention,
    tag: filter.tag,
  };
}

export function parseSavedViewSort(raw: Json | null | undefined): TaskSortState {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    return { ...DEFAULT_TASK_SORT };
  }
  const by = (raw as Record<string, unknown>).by;
  if (
    by === 'board_default' ||
    by === 'due_asc' ||
    by === 'priority_desc' ||
    by === 'updated_desc'
  ) {
    return { by };
  }
  return { ...DEFAULT_TASK_SORT };
}

export function applyTaskFilters<T extends TaskV2Like>(
  tasks: T[],
  filter: TaskFilterState,
  now: Date = new Date()
): T[] {
  const q = filter.search.trim().toLowerCase();
  const tagFilter = filter.tag.trim().toLowerCase();

  return tasks.filter((t) => {
    if (filter.kind !== 'all' && normalizeActivityKind(t.kind) !== filter.kind) return false;
    if (filter.priority !== 'all' && normalizeTaskPriority(t.priority) !== filter.priority) return false;
    if (filter.projectId !== 'all') {
      if (filter.projectId === 'none') {
        if (t.project_id) return false;
      } else if (t.project_id !== filter.projectId) {
        return false;
      }
    }
    if (filter.status !== 'all' && normalizeTaskStatus(t.status) !== filter.status) return false;

    if (filter.attention === 'overdue' && !isTaskOverdue(t, now)) return false;
    if (filter.attention === 'revisi' && normalizeTaskStatus(t.status) !== 'revisi') return false;
    if (filter.attention === 'stagnant' && !isTaskStagnant(t, now)) return false;
    if (filter.attention === 'attention') {
      const hasAttention =
        isTaskOverdue(t, now) ||
        normalizeTaskStatus(t.status) === 'revisi' ||
        isTaskStagnant(t, now);
      if (!hasAttention) return false;
    }

    if (tagFilter) {
      const tags = (t.tags ?? []).map((item) => item.toLowerCase());
      if (!tags.some((tag) => tag.includes(tagFilter))) return false;
    }

    if (q) {
      const haystacks = [t.title, t.description ?? '', t.latest_revision_note ?? '']
        .join(' ')
        .toLowerCase();
      if (!haystacks.includes(q)) return false;
    }

    return true;
  });
}

const PRIORITY_WEIGHT: Record<TaskPriority, number> = {
  tinggi: 3,
  sedang: 2,
  rendah: 1,
};

export function sortTaskItems<T extends TaskV2Like>(
  tasks: T[],
  sort: TaskSortState = DEFAULT_TASK_SORT
): T[] {
  const copy = [...tasks];
  copy.sort((a, b) => {
    if (sort.by === 'due_asc') {
      const aDue = a.due_at ? new Date(a.due_at).getTime() : Number.MAX_SAFE_INTEGER;
      const bDue = b.due_at ? new Date(b.due_at).getTime() : Number.MAX_SAFE_INTEGER;
      if (aDue !== bDue) return aDue - bDue;
    } else if (sort.by === 'priority_desc') {
      const diff =
        PRIORITY_WEIGHT[normalizeTaskPriority(b.priority)] -
        PRIORITY_WEIGHT[normalizeTaskPriority(a.priority)];
      if (diff !== 0) return diff;
    } else if (sort.by === 'updated_desc') {
      const aUpd = a.updated_at ? new Date(a.updated_at).getTime() : 0;
      const bUpd = b.updated_at ? new Date(b.updated_at).getTime() : 0;
      if (aUpd !== bUpd) return bUpd - aUpd;
    } else {
      // board_default: sort_order asc (if explicit), then priority desc, then due_at asc
      const aOrd = a.sort_order ?? 0;
      const bOrd = b.sort_order ?? 0;
      if (aOrd !== bOrd) return aOrd - bOrd;

      const pDiff =
        PRIORITY_WEIGHT[normalizeTaskPriority(b.priority)] -
        PRIORITY_WEIGHT[normalizeTaskPriority(a.priority)];
      if (pDiff !== 0) return pDiff;

      const aDue = a.due_at ? new Date(a.due_at).getTime() : Number.MAX_SAFE_INTEGER;
      const bDue = b.due_at ? new Date(b.due_at).getTime() : Number.MAX_SAFE_INTEGER;
      if (aDue !== bDue) return aDue - bDue;
    }

    const aCreated = a.created_at ? new Date(a.created_at).getTime() : 0;
    const bCreated = b.created_at ? new Date(b.created_at).getTime() : 0;
    return bCreated - aCreated;
  });
  return copy;
}

export function getSavedViewHref(view: { id: string; scope?: string | null }): string {
  switch (view.scope) {
    case 'agenda':
      return `/jadwal?view=${view.id}`;
    case 'transactions':
      return `/transaksi?view=${view.id}`;
    case 'projects':
      return `/proyek?view=${view.id}`;
    case 'tasks':
    default:
      return `/tugas?view=${view.id}`;
  }
}

export function tiptapDocToPlainText(doc: Json | null | undefined): string {
  if (!doc || typeof doc !== 'object' || Array.isArray(doc)) return '';
  const chunks: string[] = [];

  const visit = (node: Record<string, unknown>) => {
    if (typeof node.text === 'string') {
      chunks.push(node.text);
    }
    if (Array.isArray(node.content)) {
      for (const child of node.content) {
        if (child && typeof child === 'object' && !Array.isArray(child)) {
          visit(child as Record<string, unknown>);
        }
      }
      if (
        node.type === 'paragraph' ||
        node.type === 'heading' ||
        node.type === 'listItem' ||
        node.type === 'blockquote' ||
        node.type === 'codeBlock'
      ) {
        chunks.push('\n');
      }
    }
  };

  visit(doc as Record<string, unknown>);
  return chunks.join('').replace(/\n{3,}/g, '\n\n').trim();
}

export function plainTextToTiptapDoc(text: string | null | undefined): Json {
  const clean = (text ?? '').trim();
  if (!clean) {
    return {
      type: 'doc',
      content: [{ type: 'paragraph' }],
    };
  }
  const paragraphs = clean.split(/\r?\n+/).map((line) => ({
    type: 'paragraph',
    content: line ? [{ type: 'text', text: line }] : [],
  }));
  return {
    type: 'doc',
    content: paragraphs,
  };
}

export interface ParsedTemplateBlocks {
  doc: Json | null;
  tags: string[];
  recurrenceRule: Json | null;
  description: string | null;
}

export function parseTemplateBlocks(blocksJson: Json | null | undefined): ParsedTemplateBlocks {
  if (!blocksJson || typeof blocksJson !== 'object' || Array.isArray(blocksJson)) {
    return { doc: null, tags: [], recurrenceRule: null, description: null };
  }

  const obj = blocksJson as Record<string, unknown>;
  if (obj.type === 'doc') {
    const plain = tiptapDocToPlainText(blocksJson);
    return {
      doc: blocksJson,
      tags: [],
      recurrenceRule: null,
      description: plain || null,
    };
  }

  const doc = obj.doc && typeof obj.doc === 'object' ? (obj.doc as Json) : null;
  const tags = Array.isArray(obj.tags)
    ? obj.tags.filter((t): t is string => typeof t === 'string' && t.trim().length > 0)
    : [];
  const recurrenceRule = parseRecurrenceRule(obj.recurrence_rule as Json | undefined)
    ? (obj.recurrence_rule as Json)
    : null;
  const description =
    typeof obj.description === 'string' && obj.description.trim()
      ? obj.description.trim()
      : doc
      ? tiptapDocToPlainText(doc) || null
      : null;

  return { doc, tags, recurrenceRule, description };
}

export function buildTemplateBlocks(params: {
  doc?: Json | null;
  tags?: string[];
  recurrenceRule?: Json | null;
  description?: string | null;
}): Json {
  return {
    doc: params.doc ?? (params.description ? plainTextToTiptapDoc(params.description) : null),
    tags: params.tags ?? [],
    recurrence_rule: params.recurrenceRule ?? null,
    description: params.description ?? null,
  };
}

export function parseTemplateChecklist(checklistJson: Json | null | undefined): string[] {
  if (!Array.isArray(checklistJson)) return [];
  const out: string[] = [];
  for (const entry of checklistJson) {
    if (typeof entry === 'string' && entry.trim()) {
      out.push(entry.trim());
    } else if (entry && typeof entry === 'object' && !Array.isArray(entry)) {
      const text = (entry as Record<string, unknown>).text;
      if (typeof text === 'string' && text.trim()) {
        out.push(text.trim());
      }
    }
  }
  return out;
}

export function computeAttentionSummary(params: {
  tasks: TaskV2Like[];
  conflictCount: number;
  now?: Date;
}): {
  overdueCount: number;
  revisiCount: number;
  stagnantCount: number;
  conflictCount: number;
  totalAttention: number;
} {
  const now = params.now ?? new Date();
  let overdueCount = 0;
  let revisiCount = 0;
  let stagnantCount = 0;

  for (const task of params.tasks) {
    if (normalizeTaskStatus(task.status) === 'done') continue;
    if (isTaskOverdue(task, now)) overdueCount += 1;
    if (normalizeTaskStatus(task.status) === 'revisi') revisiCount += 1;
    if (isTaskStagnant(task, now)) stagnantCount += 1;
  }

  return {
    overdueCount,
    revisiCount,
    stagnantCount,
    conflictCount: Math.max(0, params.conflictCount),
    totalAttention: overdueCount + revisiCount + stagnantCount + Math.max(0, params.conflictCount),
  };
}

export function formatFileSize(bytes: number): string {
  if (!Number.isFinite(bytes) || bytes < 0) return '0 B';
  if (bytes < 1024) return `${Math.round(bytes)} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

export const ALLOWED_ATTACHMENT_MIMES = new Set([
  'image/png',
  'image/jpeg',
  'image/webp',
  'application/pdf',
]);

export const MAX_ATTACHMENT_BYTES = 10 * 1024 * 1024;
