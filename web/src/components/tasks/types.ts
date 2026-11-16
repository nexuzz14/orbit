import type { ActivityKind, Json, TaskPriority, TaskStatus } from '@/types/database';

export type TasksViewMode = 'list' | 'board' | 'projects';

export interface ChecklistItemRecord {
  id: string;
  task_id: string;
  text: string;
  done: boolean;
  sort_order: number;
  created_at?: string;
  updated_at?: string;
}

export interface TaskRecord {
  id: string;
  workspace_id: string;
  project_id: string | null;
  project_name: string | null;
  kind: ActivityKind;
  title: string;
  description: string | null;
  description_blocks: Json | null;
  status: TaskStatus;
  priority: TaskPriority;
  due_at: string | null;
  due_is_date_only: boolean;
  estimate_minutes: number | null;
  completed_at: string | null;
  milestone_payment_id: string | null;
  tags: string[];
  sort_order: number;
  progress_percent: number;
  revision_count: number;
  latest_revision_note: string | null;
  status_changed_at: string;
  parent_task_id: string | null;
  assignee_id: string | null;
  recurrence_rule: Json | null;
  recurrence_parent_id: string | null;
  created_at: string;
  updated_at: string;
  checklist_items: ChecklistItemRecord[];
}

export interface ProjectOption {
  id: string;
  name: string;
  kind: ActivityKind;
}

export interface PaymentOption {
  id: string;
  project_id: string;
  label: string;
  amount: number;
}

export interface AccountOption {
  id: string;
  name: string;
}

export interface TaskStatusHistoryItem {
  id: string;
  workspace_id: string;
  task_id: string;
  from_status: TaskStatus | null;
  to_status: TaskStatus;
  note: string | null;
  changed_by: string | null;
  created_at: string;
}

export interface TaskCommentItem {
  id: string;
  workspace_id: string;
  entity_type: string;
  entity_id: string;
  parent_comment_id: string | null;
  body: string;
  author_id: string | null;
  created_at: string;
  updated_at: string;
  deleted_at: string | null;
}

export interface EntityLinkItem {
  id: string;
  workspace_id: string;
  source_type: string;
  source_id: string;
  target_type: string;
  target_id: string;
  relation_type: string;
  created_at: string;
}

export interface AttachmentItem {
  id: string;
  workspace_id: string;
  owner_table: string;
  owner_id: string;
  storage_path: string;
  file_name: string | null;
  mime: string;
  size: number;
  created_at: string;
  deleted_at: string | null;
}

export interface SavedViewItem {
  id: string;
  workspace_id: string;
  name: string;
  scope: string;
  view_mode: string;
  filter_json: Json;
  sort_json: Json;
  is_pinned: boolean;
  sort_order: number;
}

export interface TaskTemplateItem {
  id: string;
  workspace_id: string;
  name: string;
  kind: ActivityKind;
  default_priority: TaskPriority;
  default_estimate_minutes: number | null;
  checklist_json: Json;
  blocks_json: Json | null;
}

export interface TaskTimeLogItem {
  id: string;
  workspace_id: string;
  task_id: string;
  user_id: string | null;
  started_at: string;
  ended_at: string | null;
  duration_seconds: number;
  mode: 'stopwatch' | 'pomodoro' | 'manual';
  note: string | null;
  created_at: string;
}

export interface WorkspaceMemberOption {
  user_id: string;
  role: string;
  display_name: string;
}
