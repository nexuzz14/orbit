import type { SupabaseClient } from '@supabase/supabase-js';
import type { Database, Json, TaskStatus } from '@/types/database';
import {
  normalizeActivityKind,
  normalizeTaskPriority,
  normalizeTaskStatus,
  validateRevisionTransition,
} from '@/lib/task-v2';
import type { ChecklistItemRecord, TaskRecord } from './types';

export function mapRawTaskRow(raw: Record<string, unknown>): TaskRecord {
  const projectsObj = raw.projects as { name?: string } | null | undefined;
  const rawChecklist = Array.isArray(raw.task_checklist_items)
    ? (raw.task_checklist_items as ChecklistItemRecord[])
    : [];
  const sortedChecklist = [...rawChecklist].sort(
    (a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0)
  );

  const createdAt =
    typeof raw.created_at === 'string' ? raw.created_at : new Date().toISOString();
  const updatedAt = typeof raw.updated_at === 'string' ? raw.updated_at : createdAt;

  return {
    id: String(raw.id ?? ''),
    workspace_id: String(raw.workspace_id ?? ''),
    project_id: typeof raw.project_id === 'string' ? raw.project_id : null,
    project_name: projectsObj?.name ?? (typeof raw.project_name === 'string' ? raw.project_name : null),
    kind: normalizeActivityKind(typeof raw.kind === 'string' ? raw.kind : null),
    title: typeof raw.title === 'string' ? raw.title : '',
    description: typeof raw.description === 'string' ? raw.description : null,
    description_blocks: (raw.description_blocks as Json | null | undefined) ?? null,
    status: normalizeTaskStatus(typeof raw.status === 'string' ? raw.status : null),
    priority: normalizeTaskPriority(typeof raw.priority === 'string' ? raw.priority : null),
    due_at: typeof raw.due_at === 'string' ? raw.due_at : null,
    due_is_date_only: Boolean(raw.due_is_date_only),
    estimate_minutes: typeof raw.estimate_minutes === 'number' ? raw.estimate_minutes : null,
    completed_at: typeof raw.completed_at === 'string' ? raw.completed_at : null,
    milestone_payment_id:
      typeof raw.milestone_payment_id === 'string' ? raw.milestone_payment_id : null,
    tags: Array.isArray(raw.tags)
      ? raw.tags.filter((item): item is string => typeof item === 'string')
      : [],
    sort_order: typeof raw.sort_order === 'number' ? raw.sort_order : 0,
    progress_percent: typeof raw.progress_percent === 'number' ? raw.progress_percent : 0,
    revision_count: typeof raw.revision_count === 'number' ? raw.revision_count : 0,
    latest_revision_note:
      typeof raw.latest_revision_note === 'string' ? raw.latest_revision_note : null,
    status_changed_at:
      typeof raw.status_changed_at === 'string' ? raw.status_changed_at : updatedAt,
    parent_task_id: typeof raw.parent_task_id === 'string' ? raw.parent_task_id : null,
    assignee_id: typeof raw.assignee_id === 'string' ? raw.assignee_id : null,
    recurrence_rule: (raw.recurrence_rule as Json | null | undefined) ?? null,
    recurrence_parent_id:
      typeof raw.recurrence_parent_id === 'string' ? raw.recurrence_parent_id : null,
    created_at: createdAt,
    updated_at: updatedAt,
    checklist_items: sortedChecklist,
  };
}

export function isSchemaFeatureUnavailable(error: { code?: string; message?: string } | null | undefined): boolean {
  if (!error) return false;
  const code = error.code || '';
  const msg = (error.message || '').toLowerCase();
  return (
    code === '42P01' ||
    code === '42703' ||
    code === 'PGRST202' ||
    code === 'PGRST204' ||
    code === 'PGRST205' ||
    msg.includes('could not find the function') ||
    msg.includes('does not exist') ||
    msg.includes('schema cache')
  );
}

export async function changeTaskStatusWithRpc(params: {
  supabase: SupabaseClient<Database>;
  task: TaskRecord;
  toStatus: TaskStatus;
  note?: string | null;
  sortOrder?: number | null;
}): Promise<{
  ok: boolean;
  updatedRow?: TaskRecord;
  errorMessage?: string;
}> {
  const validation = validateRevisionTransition({
    fromStatus: params.task.status,
    toStatus: params.toStatus,
    note: params.note,
  });
  if (!validation.valid) {
    return { ok: false, errorMessage: validation.error };
  }

  const { data, error } = await params.supabase.rpc('fn_change_task_status', {
    p_task_id: params.task.id,
    p_to_status: params.toStatus,
    p_note: validation.cleanNote,
    p_sort_order: params.sortOrder ?? null,
  });

  if (!error && data) {
    const mapped = mapRawTaskRow({
      ...(data as unknown as Record<string, unknown>),
      projects: params.task.project_name ? { name: params.task.project_name } : null,
      task_checklist_items: params.task.checklist_items,
    });
    return { ok: true, updatedRow: mapped };
  }

  // Fallback jika migrasi v5.2 belum di-push ke cloud database
  if (isSchemaFeatureUnavailable(error)) {
    if (params.toStatus === 'revisi') {
      return {
        ok: false,
        errorMessage:
          'Status Revisi memerlukan migrasi database v5.2 (fn_change_task_status) yang belum diterapkan di server.',
      };
    }

    const fallbackCompletedAt =
      params.toStatus === 'done'
        ? params.task.completed_at || new Date().toISOString()
        : null;

    const { data: updData, error: updErr } = await params.supabase
      .from('tasks')
      .update({
        status: params.toStatus,
        completed_at: fallbackCompletedAt,
        sort_order: params.sortOrder ?? params.task.sort_order,
      })
      .eq('id', params.task.id)
      .select('*')
      .single();

    if (updErr) {
      return { ok: false, errorMessage: updErr.message };
    }
    if (updData) {
      return {
        ok: true,
        updatedRow: mapRawTaskRow({
          ...(updData as unknown as Record<string, unknown>),
          projects: params.task.project_name ? { name: params.task.project_name } : null,
          task_checklist_items: params.task.checklist_items,
        }),
      };
    }
  }

  return {
    ok: false,
    errorMessage: error?.message || 'Gagal memperbarui status tugas.',
  };
}
