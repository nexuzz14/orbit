'use client';

import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';
import {
  AlertTriangle,
  ArrowLeft,
  BookmarkPlus,
  CalendarPlus,
  Check,
  Maximize2,
  Minimize2,
  Plus,
  Receipt,
  Repeat,
  RotateCcw,
  Trash2,
  X,
} from 'lucide-react';
import { createClient } from '@/lib/supabase/client';
import { getDateKeyInTimezone } from '@/lib/format';
import {
  buildTemplateBlocks,
  computeTaskProgress,
  getStagnantDays,
  isTaskOverdue,
  isTaskStagnant,
  parseRecurrenceRule,
  serializeRecurrenceRule,
  snapProgressStep5,
  type RecurrenceFreq,
} from '@/lib/task-v2';
import type {
  ActivityKind,
  Database,
  Json,
  TaskPriority,
  TaskStatus,
} from '@/types/database';
import {
  Button,
  Input,
  KindBadge,
  ProgressControl,
  PropertyRow,
  Select,
  StatusBadge,
  TaskStatusBadge,
  cn,
} from '@/components/ui';
import { isSchemaFeatureUnavailable, mapRawTaskRow } from './task-actions';
import { TaskRichEditor } from './task-rich-editor';
import { TimeTrackerBlock } from './time-tracker-block';
import {
  TaskAttachmentsSection,
  TaskChecklistSection,
  TaskCommentsSection,
  TaskEntityLinksSection,
  TaskHistorySection,
  TaskSubtasksSection,
  type EntityRelationType,
  type EntityTargetType,
  type LinkTargetOption,
} from './detail-peek-sections';
import type {
  AttachmentItem,
  ChecklistItemRecord,
  EntityLinkItem,
  PaymentOption,
  ProjectOption,
  TaskCommentItem,
  TaskRecord,
  TaskStatusHistoryItem,
  TaskTemplateItem,
  TaskTimeLogItem,
  WorkspaceMemberOption,
} from './types';

interface DetailPeekProps {
  open: boolean;
  task: TaskRecord | null;
  allTasks: TaskRecord[];
  workspaceId: string;
  projects: ProjectOption[];
  payments: PaymentOption[];
  onClose: () => void;
  onSelectTask: (taskId: string) => void;
  onTaskUpdated: (updated: TaskRecord) => void;
  onTaskCreated: (created: TaskRecord) => void;
  onTaskDeleted: (taskId: string) => void;
  onChangeStatus: (task: TaskRecord, toStatus: TaskStatus) => Promise<void> | void;
  onTemplateCreated?: (template: TaskTemplateItem) => void;
}

function getWibTimeHHMM(isoString: string | null): string {
  if (!isoString) return '';
  const d = new Date(isoString);
  if (Number.isNaN(d.getTime())) return '';
  try {
    return new Intl.DateTimeFormat('en-GB', {
      timeZone: 'Asia/Jakarta',
      hour: '2-digit',
      minute: '2-digit',
      hour12: false,
    }).format(d);
  } catch {
    return '';
  }
}

export function DetailPeek({
  open,
  task,
  allTasks,
  workspaceId,
  projects,
  payments,
  onClose,
  onSelectTask,
  onTaskUpdated,
  onTaskCreated,
  onTaskDeleted,
  onChangeStatus,
  onTemplateCreated,
}: DetailPeekProps) {
  const supabase = useMemo(() => createClient(), []);
  const router = useRouter();

  const [expanded, setExpanded] = useState(false);
  const [titleDraft, setTitleDraft] = useState('');
  const [tagDraft, setTagDraft] = useState('');
  const [dueDateDraft, setDueDateDraft] = useState('');
  const [dueTimeDraft, setDueTimeDraft] = useState('');
  const [estimateDraft, setEstimateDraft] = useState('');
  const [progressDraft, setProgressDraft] = useState(0);

  const [showTemplatePrompt, setShowTemplatePrompt] = useState(false);
  const [templateName, setTemplateName] = useState('');
  const [savingTemplate, setSavingTemplate] = useState(false);
  const [templateFeedback, setTemplateFeedback] = useState<string | null>(null);

  const [confirmDelete, setConfirmDelete] = useState(false);
  const [deletingTask, setDeletingTask] = useState(false);
  const [savingMessage, setSavingMessage] = useState<string | null>(null);
  const [errorBanner, setErrorBanner] = useState<string | null>(null);
  const [schedulingBlock, setSchedulingBlock] = useState(false);

  const [currentUserId, setCurrentUserId] = useState<string | null>(null);
  const [subtasksSupported, setSubtasksSupported] = useState(true);
  const [fetchedSubtasks, setFetchedSubtasks] = useState<TaskRecord[]>([]);

  const [historySupported, setHistorySupported] = useState(true);
  const [history, setHistory] = useState<TaskStatusHistoryItem[]>([]);

  const [commentsSupported, setCommentsSupported] = useState(true);
  const [comments, setComments] = useState<TaskCommentItem[]>([]);

  const [linksSupported, setLinksSupported] = useState(true);
  const [links, setLinks] = useState<EntityLinkItem[]>([]);
  const [targetsByType, setTargetsByType] = useState<
    Record<EntityTargetType, LinkTargetOption[]>
  >({
    project: [],
    event: [],
    transaction: [],
    bill: [],
    task: [],
  });

  const [attachments, setAttachments] = useState<AttachmentItem[]>([]);
  const [uploadingAttachment, setUploadingAttachment] = useState(false);
  const [attachmentError, setAttachmentError] = useState<string | null>(null);

  const [timeLogsSupported, setTimeLogsSupported] = useState(true);
  const [timeLogs, setTimeLogs] = useState<TaskTimeLogItem[]>([]);
  const [members, setMembers] = useState<WorkspaceMemberOption[]>([]);

  const taskId = task?.id ?? null;

  useEffect(() => {
    if (!task) return;
    setTitleDraft(task.title);
    setDueDateDraft(task.due_at ? getDateKeyInTimezone(task.due_at, 'Asia/Jakarta') : '');
    setDueTimeDraft(
      task.due_at && !task.due_is_date_only ? getWibTimeHHMM(task.due_at) : ''
    );
    setEstimateDraft(
      task.estimate_minutes != null ? String(task.estimate_minutes) : ''
    );
    setProgressDraft(task.progress_percent);
    setShowTemplatePrompt(false);
    setTemplateName(task.title);
    setTemplateFeedback(null);
    setConfirmDelete(false);
    setErrorBanner(null);
    setAttachmentError(null);
  }, [task]);

  useEffect(() => {
    if (!open) return;
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        onClose();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [open, onClose]);

  const reloadTimeLogs = useCallback(async () => {
    if (!taskId || !workspaceId) return;
    const res = await supabase
      .from('task_time_logs')
      .select('id, workspace_id, task_id, user_id, started_at, ended_at, duration_seconds, mode, note, created_at')
      .eq('workspace_id', workspaceId)
      .eq('task_id', taskId)
      .is('deleted_at', null)
      .order('started_at', { ascending: false })
      .limit(30);

    if (res.error) {
      if (isSchemaFeatureUnavailable(res.error)) {
        setTimeLogsSupported(false);
      }
      return;
    }

    setTimeLogsSupported(true);
    setTimeLogs(((res.data ?? []) as unknown as TaskTimeLogItem[]));
  }, [supabase, taskId, workspaceId]);

  useEffect(() => {
    if (!open || !taskId || !workspaceId) return;
    let cancelled = false;

    const loadDetailRelations = async () => {
      const { data: userData } = await supabase.auth.getUser();
      const activeUid = userData.user?.id ?? null;
      if (!cancelled) {
        setCurrentUserId(activeUid);
      }

      const [
        subtasksRes,
        historyRes,
        commentsRes,
        linksRes,
        attachmentsRes,
        eventsRes,
        txRes,
        billsRes,
        membersRes,
        timeLogsRes,
      ] = await Promise.all([
        supabase
          .from('tasks')
          .select(
            '*, projects(name), task_checklist_items(id, task_id, text, done, sort_order, created_at, updated_at)'
          )
          .eq('workspace_id', workspaceId)
          .eq('parent_task_id', taskId)
          .is('deleted_at', null)
          .order('sort_order', { ascending: true }),
        supabase
          .from('task_status_history')
          .select('*')
          .eq('task_id', taskId)
          .order('created_at', { ascending: false })
          .limit(30),
        supabase
          .from('comments')
          .select('*')
          .eq('workspace_id', workspaceId)
          .eq('entity_type', 'task')
          .eq('entity_id', taskId)
          .is('deleted_at', null)
          .order('created_at', { ascending: true }),
        supabase
          .from('entity_links')
          .select('*')
          .eq('workspace_id', workspaceId)
          .or(
            `and(source_type.eq.task,source_id.eq.${taskId}),and(target_type.eq.task,target_id.eq.${taskId})`
          )
          .order('created_at', { ascending: false }),
        supabase
          .from('attachments')
          .select('*')
          .eq('owner_table', 'tasks')
          .eq('owner_id', taskId)
          .is('deleted_at', null)
          .order('created_at', { ascending: false }),
        supabase
          .from('events')
          .select('id, title, starts_at')
          .eq('workspace_id', workspaceId)
          .is('deleted_at', null)
          .order('starts_at', { ascending: false })
          .limit(40),
        supabase
          .from('transactions')
          .select('id, merchant, note, amount, occurred_at')
          .eq('workspace_id', workspaceId)
          .is('deleted_at', null)
          .order('occurred_at', { ascending: false })
          .limit(40),
        supabase
          .from('recurring_bills')
          .select('id, name, amount')
          .eq('workspace_id', workspaceId)
          .is('deleted_at', null)
          .order('name', { ascending: true })
          .limit(40),
        supabase
          .from('workspace_members')
          .select('user_id, role')
          .eq('workspace_id', workspaceId),
        supabase
          .from('task_time_logs')
          .select('id, workspace_id, task_id, user_id, started_at, ended_at, duration_seconds, mode, note, created_at')
          .eq('workspace_id', workspaceId)
          .eq('task_id', taskId)
          .is('deleted_at', null)
          .order('started_at', { ascending: false })
          .limit(30),
      ]);

      if (cancelled) return;

      if (timeLogsRes.error) {
        if (isSchemaFeatureUnavailable(timeLogsRes.error)) {
          setTimeLogsSupported(false);
        }
      } else {
        setTimeLogsSupported(true);
        setTimeLogs((timeLogsRes.data ?? []) as unknown as TaskTimeLogItem[]);
      }

      const memberRows = (membersRes.data as Array<{ user_id: string; role: string }>) ?? [];
      if (memberRows.length > 0) {
        const { data: profRows } = await supabase
          .from('profiles')
          .select('id, display_name')
          .in(
            'id',
            memberRows.map((m) => m.user_id)
          );
        const nameMap = new Map<string, string>();
        for (const prof of profRows ?? []) {
          if (prof.display_name) nameMap.set(prof.id, prof.display_name);
        }
        setMembers(
          memberRows.map((m) => ({
            user_id: m.user_id,
            role: m.role,
            display_name:
              nameMap.get(m.user_id) ||
              (activeUid && m.user_id === activeUid
                ? 'Saya'
                : `Anggota ${m.user_id.slice(0, 6)}`),
          }))
        );
      } else {
        setMembers([]);
      }

      if (subtasksRes.error) {
        if (isSchemaFeatureUnavailable(subtasksRes.error)) {
          setSubtasksSupported(false);
        }
      } else {
        setSubtasksSupported(true);
        const mapped = ((subtasksRes.data ?? []) as unknown as Record<string, unknown>[]).map(
          mapRawTaskRow
        );
        setFetchedSubtasks(mapped);
      }

      if (historyRes.error) {
        if (isSchemaFeatureUnavailable(historyRes.error)) {
          setHistorySupported(false);
        }
      } else {
        setHistorySupported(true);
        setHistory((historyRes.data ?? []) as TaskStatusHistoryItem[]);
      }

      if (commentsRes.error) {
        if (isSchemaFeatureUnavailable(commentsRes.error)) {
          setCommentsSupported(false);
        }
      } else {
        setCommentsSupported(true);
        setComments((commentsRes.data ?? []) as TaskCommentItem[]);
      }

      if (linksRes.error) {
        if (isSchemaFeatureUnavailable(linksRes.error)) {
          setLinksSupported(false);
        }
      } else {
        setLinksSupported(true);
        setLinks((linksRes.data ?? []) as EntityLinkItem[]);
      }

      if (attachmentsRes.error) {
        if (isSchemaFeatureUnavailable(attachmentsRes.error)) {
          const fallbackAtt = await supabase
            .from('attachments')
            .select('*')
            .eq('owner_table', 'tasks')
            .eq('owner_id', taskId)
            .order('created_at', { ascending: false });
          if (!cancelled && !fallbackAtt.error) {
            setAttachments(
              ((fallbackAtt.data ?? []) as unknown as Array<Record<string, unknown>>).map(
                (row) => ({
                  id: String(row.id),
                  workspace_id: String(row.workspace_id),
                  owner_table: String(row.owner_table),
                  owner_id: String(row.owner_id),
                  storage_path: String(row.storage_path),
                  file_name:
                    typeof row.file_name === 'string' ? row.file_name : null,
                  mime: String(row.mime),
                  size: Number(row.size ?? 0),
                  created_at: String(row.created_at),
                  deleted_at:
                    typeof row.deleted_at === 'string' ? row.deleted_at : null,
                })
              )
            );
          }
        }
      } else {
        setAttachments((attachmentsRes.data ?? []) as AttachmentItem[]);
      }

      setTargetsByType({
        project: projects.map((p) => ({ id: p.id, label: p.name, subtitle: p.kind })),
        event: (eventsRes.data ?? []).map((ev) => ({
          id: ev.id,
          label: ev.title,
          subtitle: getDateKeyInTimezone(ev.starts_at, 'Asia/Jakarta'),
        })),
        transaction: (txRes.data ?? []).map((tx) => ({
          id: tx.id,
          label: tx.merchant || tx.note || 'Transaksi',
          subtitle: `Rp ${Number(tx.amount).toLocaleString('id-ID')}`,
        })),
        bill: (billsRes.data ?? []).map((b) => ({
          id: b.id,
          label: b.name,
          subtitle: `Rp ${Number(b.amount).toLocaleString('id-ID')}`,
        })),
        task: allTasks.map((t) => ({
          id: t.id,
          label: t.title,
          subtitle: t.status,
        })),
      });
    };

    void loadDetailRelations();

    return () => {
      cancelled = true;
    };
  }, [open, taskId, workspaceId, supabase, projects, allTasks, task?.status, task?.revision_count]);

  const subtasks = useMemo(() => {
    if (!task) return [];
    const fromAll = allTasks.filter((t) => t.parent_task_id === task.id);
    return fromAll.length > 0 ? fromAll : fetchedSubtasks;
  }, [allTasks, fetchedSubtasks, task]);

  const parentTask = useMemo(() => {
    if (!task?.parent_task_id) return null;
    return allTasks.find((t) => t.id === task.parent_task_id) ?? null;
  }, [allTasks, task]);

  const patchTaskFields = useCallback(
    async (
      targetTask: TaskRecord,
      patch: Partial<TaskRecord>,
      dbPatch: Database['public']['Tables']['tasks']['Update'],
      coreFallbackPatch?: Database['public']['Tables']['tasks']['Update']
    ) => {
      setSavingMessage('Menyimpan...');
      setErrorBanner(null);

      const optimistic: TaskRecord = {
        ...targetTask,
        ...patch,
        updated_at: new Date().toISOString(),
      };
      onTaskUpdated(optimistic);

      const { error } = await supabase
        .from('tasks')
        .update(dbPatch)
        .eq('id', targetTask.id);

      if (error) {
        if (coreFallbackPatch && isSchemaFeatureUnavailable(error)) {
          const fallbackRes = await supabase
            .from('tasks')
            .update(coreFallbackPatch)
            .eq('id', targetTask.id);
          if (fallbackRes.error) {
            setErrorBanner(fallbackRes.error.message);
            setSavingMessage(null);
            return;
          }
        } else {
          setErrorBanner(error.message);
          setSavingMessage(null);
          return;
        }
      }

      setSavingMessage('Tersimpan');
      window.setTimeout(() => {
        setSavingMessage((prev) => (prev === 'Tersimpan' ? null : prev));
      }, 1500);
    },
    [onTaskUpdated, supabase]
  );

  const syncAutoProgress = useCallback(
    async (
      targetTask: TaskRecord,
      nextChecklist: ChecklistItemRecord[],
      nextSubtasks: TaskRecord[]
    ) => {
      const computed = computeTaskProgress({
        status: targetTask.status,
        progressPercent: targetTask.progress_percent,
        checklistItems: nextChecklist,
        subtasks: nextSubtasks,
      });

      const updated: TaskRecord = {
        ...targetTask,
        checklist_items: nextChecklist,
        progress_percent: computed.percent,
        updated_at: new Date().toISOString(),
      };
      setProgressDraft(computed.percent);
      onTaskUpdated(updated);

      const { error } = await supabase
        .from('tasks')
        .update({ progress_percent: computed.percent })
        .eq('id', targetTask.id);

      if (error && !isSchemaFeatureUnavailable(error)) {
        setErrorBanner(error.message);
      }
    },
    [onTaskUpdated, supabase]
  );

  if (!open || !task) return null;

  const computedProgress = computeTaskProgress({
    status: task.status,
    progressPercent: progressDraft,
    checklistItems: task.checklist_items,
    subtasks,
  });

  const overdue = isTaskOverdue(task);
  const stagnant = isTaskStagnant(task);
  const stagnantDays = stagnant ? getStagnantDays(task) : 0;
  const parsedRecurrence = parseRecurrenceRule(task.recurrence_rule);
  const recurrenceFreq: RecurrenceFreq = parsedRecurrence?.freq ?? 'none';
  const recurrenceInterval = parsedRecurrence?.interval ?? 1;
  const projectPayments = task.project_id
    ? payments.filter((p) => p.project_id === task.project_id)
    : [];

  const handleTitleCommit = async () => {
    const clean = titleDraft.trim();
    if (!clean) {
      setTitleDraft(task.title);
      return;
    }
    if (clean === task.title) return;
    await patchTaskFields(task, { title: clean }, { title: clean }, { title: clean });
  };

  const handleDueChange = async (nextDate: string, nextTime: string) => {
    setDueDateDraft(nextDate);
    setDueTimeDraft(nextTime);

    let dueAt: string | null = null;
    let dueIsDateOnly = false;
    if (nextDate) {
      if (nextTime) {
        dueAt = new Date(`${nextDate}T${nextTime}:00+07:00`).toISOString();
        dueIsDateOnly = false;
      } else {
        dueAt = new Date(`${nextDate}T23:59:59+07:00`).toISOString();
        dueIsDateOnly = true;
      }
    }

    await patchTaskFields(
      task,
      { due_at: dueAt, due_is_date_only: dueIsDateOnly },
      { due_at: dueAt, due_is_date_only: dueIsDateOnly },
      { due_at: dueAt, due_is_date_only: dueIsDateOnly }
    );
  };

  const handleProgressCommit = async (nextValue: number) => {
    const snapped = snapProgressStep5(nextValue);
    setProgressDraft(snapped);
    await patchTaskFields(
      task,
      { progress_percent: snapped },
      { progress_percent: snapped }
    );
  };

  const handleAddTag = async () => {
    const clean = tagDraft.trim().replace(/^#/, '');
    if (!clean) return;
    if (task.tags.some((t) => t.toLowerCase() === clean.toLowerCase())) {
      setTagDraft('');
      return;
    }
    const nextTags = [...task.tags, clean];
    setTagDraft('');
    await patchTaskFields(task, { tags: nextTags }, { tags: nextTags }, { tags: nextTags });
  };

  const handleRemoveTag = async (tagToRemove: string) => {
    const nextTags = task.tags.filter((t) => t !== tagToRemove);
    await patchTaskFields(task, { tags: nextTags }, { tags: nextTags }, { tags: nextTags });
  };

  const handleRichSave = async (blocks: Json, plainText: string | null) => {
    await patchTaskFields(
      task,
      { description_blocks: blocks, description: plainText },
      { description_blocks: blocks, description: plainText },
      { description: plainText }
    );
  };

  const handleAddChecklist = async (text: string) => {
    const nextOrder = task.checklist_items.length;
    const { data, error } = await supabase
      .from('task_checklist_items')
      .insert({
        task_id: task.id,
        text,
        done: false,
        sort_order: nextOrder,
      })
      .select('id, task_id, text, done, sort_order, created_at, updated_at')
      .single();

    if (error || !data) {
      setErrorBanner(error?.message ?? 'Gagal menambah item checklist.');
      return;
    }

    const nextItems = [...task.checklist_items, data as ChecklistItemRecord];
    await syncAutoProgress(task, nextItems, subtasks);
  };

  const handleToggleChecklist = async (item: ChecklistItemRecord) => {
    const nextDone = !item.done;
    const nextItems = task.checklist_items.map((c) =>
      c.id === item.id ? { ...c, done: nextDone } : c
    );
    await syncAutoProgress(task, nextItems, subtasks);

    const { error } = await supabase
      .from('task_checklist_items')
      .update({ done: nextDone })
      .eq('id', item.id);

    if (error) {
      setErrorBanner(error.message);
    }
  };

  const handleDeleteChecklist = async (itemId: string) => {
    const nextItems = task.checklist_items.filter((c) => c.id !== itemId);
    await syncAutoProgress(task, nextItems, subtasks);

    const { error } = await supabase
      .from('task_checklist_items')
      .delete()
      .eq('id', itemId);

    if (error) {
      setErrorBanner(error.message);
    }
  };

  const handleAddSubtask = async (title: string) => {
    const { data, error } = await supabase
      .from('tasks')
      .insert({
        workspace_id: workspaceId,
        parent_task_id: task.id,
        project_id: task.project_id,
        kind: task.kind,
        title,
        priority: 'sedang',
        status: 'todo',
        progress_percent: 0,
      })
      .select(
        '*, projects(name), task_checklist_items(id, task_id, text, done, sort_order, created_at, updated_at)'
      )
      .single();

    if (error || !data) {
      if (isSchemaFeatureUnavailable(error)) {
        setSubtasksSupported(false);
      } else {
        setErrorBanner(error?.message ?? 'Gagal menambah subtugas.');
      }
      return;
    }

    const createdSubtask = mapRawTaskRow(data as unknown as Record<string, unknown>);
    const nextSubtasks = [...subtasks, createdSubtask];
    setFetchedSubtasks(nextSubtasks);
    onTaskCreated(createdSubtask);
    await syncAutoProgress(task, task.checklist_items, nextSubtasks);
  };

  const handleToggleSubtaskDone = async (subtask: TaskRecord) => {
    const toStatus: TaskStatus = subtask.status === 'done' ? 'todo' : 'done';
    await onChangeStatus(subtask, toStatus);
    const nextSubtasks = subtasks.map((st) =>
      st.id === subtask.id
        ? {
            ...st,
            status: toStatus,
            progress_percent: toStatus === 'done' ? 100 : 0,
          }
        : st
    );
    setFetchedSubtasks(nextSubtasks);
    await syncAutoProgress(task, task.checklist_items, nextSubtasks);
  };

  const handleAddEntityLink = async (params: {
    targetType: EntityTargetType;
    targetId: string;
    relationType: EntityRelationType;
  }) => {
    const { data, error } = await supabase
      .from('entity_links')
      .insert({
        workspace_id: workspaceId,
        source_type: 'task',
        source_id: task.id,
        target_type: params.targetType,
        target_id: params.targetId,
        relation_type: params.relationType,
      })
      .select('*')
      .single();

    if (error || !data) {
      if (isSchemaFeatureUnavailable(error)) {
        setLinksSupported(false);
      } else {
        setErrorBanner(error?.message ?? 'Gagal menautkan entitas.');
      }
      return;
    }

    setLinks((prev) => [data as EntityLinkItem, ...prev]);
  };

  const handleDeleteEntityLink = async (linkId: string) => {
    setLinks((prev) => prev.filter((item) => item.id !== linkId));
    const { error } = await supabase.from('entity_links').delete().eq('id', linkId);
    if (error) {
      setErrorBanner(error.message);
    }
  };

  const handleNavigateEntity = (targetType: string, targetId: string) => {
    if (targetType === 'task') {
      onSelectTask(targetId);
      return;
    }
    if (targetType === 'project') {
      router.push(`/proyek?id=${targetId}`);
      return;
    }
    if (targetType === 'event') {
      router.push('/jadwal');
      return;
    }
    if (targetType === 'transaction') {
      router.push('/transaksi');
      return;
    }
    if (targetType === 'bill') {
      router.push('/tagihan');
    }
  };

  const handleAddComment = async (body: string) => {
    const { data, error } = await supabase
      .from('comments')
      .insert({
        workspace_id: workspaceId,
        entity_type: 'task',
        entity_id: task.id,
        body,
        author_id: currentUserId,
      })
      .select('*')
      .single();

    if (error || !data) {
      if (isSchemaFeatureUnavailable(error)) {
        setCommentsSupported(false);
      } else {
        setErrorBanner(error?.message ?? 'Gagal mengirim komentar.');
      }
      return;
    }

    setComments((prev) => [...prev, data as TaskCommentItem]);
  };

  const handleEditComment = async (commentId: string, body: string) => {
    const { data, error } = await supabase
      .from('comments')
      .update({ body })
      .eq('id', commentId)
      .select('*')
      .single();

    if (error || !data) {
      setErrorBanner(error?.message ?? 'Gagal mengubah komentar.');
      return;
    }

    setComments((prev) =>
      prev.map((item) => (item.id === commentId ? (data as TaskCommentItem) : item))
    );
  };

  const handleDeleteComment = async (commentId: string) => {
    const deletedAt = new Date().toISOString();
    setComments((prev) => prev.filter((item) => item.id !== commentId));

    const { error } = await supabase
      .from('comments')
      .update({ deleted_at: deletedAt })
      .eq('id', commentId);

    if (error) {
      const hardDel = await supabase.from('comments').delete().eq('id', commentId);
      if (hardDel.error) {
        setErrorBanner(hardDel.error.message);
      }
    }
  };

  const handleUploadAttachment = async (file: File) => {
    setUploadingAttachment(true);
    setAttachmentError(null);
    try {
      const safeName = file.name.replace(/[^a-zA-Z0-9._-]/g, '_');
      const storagePath = `${workspaceId}/tasks/${task.id}/${Date.now()}-${safeName}`;

      const uploadRes = await supabase.storage
        .from('attachments')
        .upload(storagePath, file, {
          contentType: file.type,
          upsert: false,
        });

      if (uploadRes.error) {
        setAttachmentError(
          `Unggah storage gagal (${uploadRes.error.message}). Pastikan bucket "attachments" dan policy akses sudah siap.`
        );
        return;
      }

      const firstInsert = await supabase
        .from('attachments')
        .insert({
          workspace_id: workspaceId,
          owner_table: 'tasks',
          owner_id: task.id,
          storage_path: storagePath,
          file_name: file.name,
          mime: file.type,
          size: file.size,
        })
        .select('*')
        .single();

      if (firstInsert.error) {
        if (isSchemaFeatureUnavailable(firstInsert.error)) {
          const fallbackInsert = await supabase
            .from('attachments')
            .insert({
              workspace_id: workspaceId,
              owner_table: 'tasks',
              owner_id: task.id,
              storage_path: storagePath,
              mime: file.type,
              size: file.size,
            })
            .select('*')
            .single();

          if (fallbackInsert.error || !fallbackInsert.data) {
            setAttachmentError(
              `Berkas terunggah ke storage, tetapi metadata DB gagal disimpan: ${fallbackInsert.error?.message ?? 'Error'}`
            );
            return;
          }
          setAttachments((prev) => [
            {
              ...(fallbackInsert.data as AttachmentItem),
              file_name: file.name,
              deleted_at: null,
            },
            ...prev,
          ]);
          return;
        }

        setAttachmentError(
          `Gagal mencatat lampiran ke basis data: ${firstInsert.error.message}`
        );
        return;
      }

      if (firstInsert.data) {
        setAttachments((prev) => [firstInsert.data as AttachmentItem, ...prev]);
      }
    } finally {
      setUploadingAttachment(false);
    }
  };

  const handleDownloadAttachment = async (item: AttachmentItem) => {
    setAttachmentError(null);
    const { data, error } = await supabase.storage
      .from('attachments')
      .createSignedUrl(item.storage_path, 3600);

    if (error || !data?.signedUrl) {
      setAttachmentError(
        error?.message ?? 'Gagal membuat tautan unduh untuk lampiran ini.'
      );
      return;
    }

    window.open(data.signedUrl, '_blank', 'noopener,noreferrer');
  };

  const handleDeleteAttachment = async (item: AttachmentItem) => {
    setAttachmentError(null);
    setAttachments((prev) => prev.filter((att) => att.id !== item.id));

    const softRes = await supabase
      .from('attachments')
      .update({ deleted_at: new Date().toISOString() })
      .eq('id', item.id);

    if (softRes.error) {
      const hardRes = await supabase.from('attachments').delete().eq('id', item.id);
      if (hardRes.error) {
        setAttachmentError(hardRes.error.message);
      }
    }

    await supabase.storage.from('attachments').remove([item.storage_path]);
  };

  const handleSaveAsTemplate = async (e: React.FormEvent) => {
    e.preventDefault();
    const cleanName = templateName.trim() || task.title;
    setSavingTemplate(true);
    setTemplateFeedback(null);
    try {
      const blocksJson = buildTemplateBlocks({
        doc: task.description_blocks,
        tags: task.tags,
        recurrenceRule: task.recurrence_rule,
        description: task.description,
      });

      const checklistJson = task.checklist_items.map((item) => item.text);

      const { data, error } = await supabase
        .from('task_templates')
        .insert({
          workspace_id: workspaceId,
          name: cleanName,
          kind: task.kind,
          default_priority: task.priority,
          default_estimate_minutes: task.estimate_minutes,
          checklist_json: checklistJson as Json,
          blocks_json: blocksJson,
          created_by: currentUserId,
        })
        .select('*')
        .single();

      if (error || !data) {
        if (isSchemaFeatureUnavailable(error)) {
          setTemplateFeedback(
            'Tabel template tugas belum tersedia di basis data (menunggu migrasi v5.3).'
          );
        } else {
          setTemplateFeedback(error?.message ?? 'Gagal menyimpan template.');
        }
        return;
      }

      onTemplateCreated?.(data as TaskTemplateItem);
      setTemplateFeedback('Tersimpan sebagai template tugas.');
      setShowTemplatePrompt(false);
    } finally {
      setSavingTemplate(false);
    }
  };

  const handleDeleteTask = async () => {
    setDeletingTask(true);
    try {
      const deletedAt = new Date().toISOString();
      const softRes = await supabase
        .from('tasks')
        .update({ deleted_at: deletedAt })
        .eq('id', task.id);

      if (softRes.error) {
        const hardRes = await supabase.from('tasks').delete().eq('id', task.id);
        if (hardRes.error) {
          setErrorBanner(hardRes.error.message);
          return;
        }
      }

      onTaskDeleted(task.id);
      onClose();
    } finally {
      setDeletingTask(false);
    }
  };

  return (
    <div
      className="fixed inset-0 z-50 flex justify-end bg-black/35 backdrop-blur-[1px]"
      role="dialog"
      aria-modal="true"
      aria-label={`Detail tugas ${task.title}`}
      onClick={(e) => {
        if (e.target === e.currentTarget) {
          onClose();
        }
      }}
    >
      <aside
        className={cn(
          'relative flex h-full w-full max-w-full min-w-0 overflow-x-hidden flex-col border-l border-border bg-card shadow-peek transition-all duration-200',
          expanded ? 'md:w-[760px]' : 'md:w-[480px]'
        )}
      >
        {/* Top bar header */}
        <header className="sticky top-0 z-10 border-b border-border bg-card px-4 py-3 sm:px-5">
          <div className="flex items-center justify-between gap-2">
            <div className="flex items-center gap-1.5 min-w-0">
              {task.parent_task_id && (
                <button
                  type="button"
                  onClick={() => onSelectTask(task.parent_task_id as string)}
                  className="inline-flex min-h-9 items-center gap-1 rounded-md border border-border bg-subtle px-2 py-1 text-xs font-medium text-foreground hover:bg-hover"
                >
                  <ArrowLeft className="h-3.5 w-3.5" strokeWidth={1.75} />
                  <span className="truncate max-w-[120px]">
                    {parentTask ? parentTask.title : 'Tugas Induk'}
                  </span>
                </button>
              )}
              <KindBadge kind={task.kind} />
              <TaskStatusBadge status={task.status} compact />
              {savingMessage && (
                <span className="text-[11px] font-medium text-muted-foreground">
                  {savingMessage}
                </span>
              )}
            </div>

            <div className="flex items-center gap-1 shrink-0">
              <button
                type="button"
                onClick={() => setExpanded((prev) => !prev)}
                className="hidden md:inline-flex h-10 w-10 items-center justify-center rounded-md text-muted-foreground hover:bg-hover hover:text-foreground"
                aria-label={expanded ? 'Perkecil panel detail' : 'Perlebar panel detail'}
                title={expanded ? 'Perkecil panel' : 'Perlebar panel'}
              >
                {expanded ? (
                  <Minimize2 className="h-4 w-4" strokeWidth={1.75} />
                ) : (
                  <Maximize2 className="h-4 w-4" strokeWidth={1.75} />
                )}
              </button>
              <button
                type="button"
                onClick={() => {
                  setShowTemplatePrompt((prev) => !prev);
                  setConfirmDelete(false);
                }}
                className="inline-flex h-10 w-10 items-center justify-center rounded-md text-muted-foreground hover:bg-hover hover:text-foreground"
                aria-label="Simpan jadi template"
                title="Simpan jadi Template"
              >
                <BookmarkPlus className="h-4 w-4" strokeWidth={1.75} />
              </button>
              <button
                type="button"
                onClick={() => {
                  setConfirmDelete((prev) => !prev);
                  setShowTemplatePrompt(false);
                }}
                className="inline-flex h-10 w-10 items-center justify-center rounded-md text-muted-foreground hover:bg-expense-subtle hover:text-expense"
                aria-label="Hapus tugas"
                title="Hapus tugas"
              >
                <Trash2 className="h-4 w-4" strokeWidth={1.75} />
              </button>
              <button
                type="button"
                onClick={onClose}
                className="inline-flex h-10 w-10 items-center justify-center rounded-md text-muted-foreground hover:bg-hover hover:text-foreground"
                aria-label="Tutup panel detail"
                title="Tutup (Esc)"
              >
                <X className="h-4 w-4" strokeWidth={1.75} />
              </button>
            </div>
          </div>

          {/* Inline title editor */}
          <div className="mt-2">
            <input
              type="text"
              value={titleDraft}
              onChange={(e) => setTitleDraft(e.target.value)}
              onBlur={() => void handleTitleCommit()}
              onKeyDown={(e) => {
                if (e.key === 'Enter') {
                  e.currentTarget.blur();
                }
              }}
              aria-label="Judul tugas"
              className="w-full min-w-0 rounded-md border border-transparent bg-transparent px-1.5 py-1 text-lg font-semibold text-foreground hover:border-border focus:border-primary focus:bg-card focus:outline-none"
            />
          </div>

          <div className="mt-2 flex flex-wrap items-center gap-1.5">
            <button
              type="button"
              disabled={schedulingBlock}
              onClick={async () => {
                setSchedulingBlock(true);
                setErrorBanner(null);
                const todayKey = getDateKeyInTimezone(new Date(), 'Asia/Jakarta');
                const targetDay = task.due_at
                  ? getDateKeyInTimezone(task.due_at, 'Asia/Jakarta')
                  : todayKey;
                const nowHr = new Date().getHours();
                const startHr = Math.min(22, Math.max(8, nowHr + 1));
                const mins = Math.max(30, Math.min(180, task.estimate_minutes || 60));
                const startDt = new Date(`${targetDay}T${String(startHr).padStart(2, '0')}:00:00+07:00`);
                const endDt = new Date(startDt.getTime() + mins * 60 * 1000);
                const { data: ev, error } = await supabase
                  .from('events')
                  .insert({
                    workspace_id: workspaceId,
                    project_id: task.project_id,
                    kind: task.kind,
                    title: `Fokus: ${task.title}`,
                    starts_at: startDt.toISOString(),
                    ends_at: endDt.toISOString(),
                    all_day: false,
                    timezone: 'Asia/Jakarta',
                  })
                  .select('id')
                  .single();
                if (!error && ev?.id) {
                  try {
                    await supabase.from('entity_links').insert({
                      workspace_id: workspaceId,
                      source_type: 'event',
                      source_id: ev.id,
                      target_type: 'task',
                      target_id: task.id,
                      relation_type: 'related',
                    });
                  } catch {}
                  setSavingMessage(`Masuk jadwal (${mins} mnt)`);
                } else if (error) {
                  setErrorBanner(error.message);
                }
                setSchedulingBlock(false);
              }}
              className="inline-flex min-h-8 items-center gap-1.5 rounded-md border border-border bg-subtle/70 px-2.5 py-1 text-xs font-medium text-foreground hover:border-primary/40 hover:text-primary transition-colors"
            >
              <CalendarPlus className="h-3.5 w-3.5 text-primary" />
              <span>{schedulingBlock ? 'Menjadwalkan...' : 'Jadwalkan Blok Fokus'}</span>
            </button>
            <button
              type="button"
              onClick={() => {
                const sourceVal =
                  task.kind === 'intern' || task.kind === 'freelance' || task.kind === 'kuliah'
                    ? task.kind
                    : 'personal';
                window.dispatchEvent(
                  new CustomEvent('orbit:open-new-transaction', {
                    detail: {
                      prefill: {
                        type: 'expense',
                        note: `Biaya tugas: ${task.title}`,
                        source: sourceVal,
                        projectId: task.project_id,
                        linkTarget: { type: 'task', id: task.id },
                      },
                    },
                  })
                );
              }}
              className="inline-flex min-h-8 items-center gap-1.5 rounded-md border border-border bg-subtle/70 px-2.5 py-1 text-xs font-medium text-foreground hover:border-primary/40 hover:text-primary transition-colors"
            >
              <Receipt className="h-3.5 w-3.5 text-primary" />
              <span>Catat Biaya Tugas</span>
            </button>
          </div>

          {showTemplatePrompt && (
            <form
              onSubmit={handleSaveAsTemplate}
              className="mt-2.5 flex flex-col gap-2 rounded-md border border-border bg-subtle p-2.5 sm:flex-row sm:items-center"
            >
              <Input
                value={templateName}
                onChange={(e) => setTemplateName(e.target.value)}
                placeholder="Nama template..."
                aria-label="Nama template tugas"
              />
              <div className="flex items-center gap-1.5 shrink-0">
                <Button
                  type="button"
                  size="sm"
                  variant="ghost"
                  onClick={() => setShowTemplatePrompt(false)}
                >
                  Batal
                </Button>
                <Button type="submit" size="sm" disabled={savingTemplate}>
                  {savingTemplate ? 'Menyimpan...' : 'Simpan Template'}
                </Button>
              </div>
            </form>
          )}

          {templateFeedback && (
            <div className="mt-2 flex items-center gap-1.5 rounded-md border border-border bg-subtle px-2.5 py-1.5 text-xs text-foreground">
              <Check className="h-3.5 w-3.5 text-income shrink-0" strokeWidth={1.75} />
              <span>{templateFeedback}</span>
            </div>
          )}

          {confirmDelete && (
            <div className="mt-2.5 flex items-center justify-between gap-2 rounded-md border border-expense-border bg-expense-subtle px-3 py-2 text-xs">
              <span className="font-medium text-expense">
                Hapus tugas ini secara permanen dari papan?
              </span>
              <div className="flex items-center gap-1.5 shrink-0">
                <Button
                  type="button"
                  size="sm"
                  variant="ghost"
                  onClick={() => setConfirmDelete(false)}
                >
                  Batal
                </Button>
                <Button
                  type="button"
                  size="sm"
                  variant="destructive"
                  disabled={deletingTask}
                  onClick={() => void handleDeleteTask()}
                >
                  {deletingTask ? 'Menghapus...' : 'Ya, Hapus'}
                </Button>
              </div>
            </div>
          )}
        </header>

        {/* Scrollable body */}
        <div className="flex-1 overflow-y-auto px-4 py-4 space-y-5 sm:px-5">
          {errorBanner && (
            <div className="rounded-md border border-expense-border bg-expense-subtle px-3 py-2 text-xs text-expense">
              {errorBanner}
            </div>
          )}

          {(overdue || stagnant || task.status === 'revisi') && (
            <div className="rounded-lg border border-warning-border bg-warning-subtle px-3 py-2.5 space-y-1.5">
              <div className="flex flex-wrap items-center gap-1.5">
                {task.status === 'revisi' && (
                  <StatusBadge variant="warning">
                    <RotateCcw className="h-3 w-3" strokeWidth={1.75} />
                    Perlu Revisi ({task.revision_count}x)
                  </StatusBadge>
                )}
                {overdue && (
                  <StatusBadge variant="expense">
                    <AlertTriangle className="h-3 w-3" strokeWidth={1.75} />
                    Melewati Tenggat
                  </StatusBadge>
                )}
                {stagnant && (
                  <StatusBadge variant="warning">
                    Macet {stagnantDays} hari
                  </StatusBadge>
                )}
              </div>
              {task.latest_revision_note && (
                <p className="text-xs text-foreground">
                  <span className="font-semibold">Catatan Revisi Terakhir:</span>{' '}
                  {task.latest_revision_note}
                </p>
              )}
            </div>
          )}

          {/* Inline Property Rows */}
          <section
            aria-label="Properti tugas"
            className="rounded-lg border border-border bg-card px-3.5 py-2 divide-y divide-border/70"
          >
            <PropertyRow label="Status">
              <Select
                aria-label="Ubah status tugas"
                value={task.status}
                onChange={(e) => void onChangeStatus(task, e.target.value as TaskStatus)}
              >
                <option value="todo">Belum dikerjakan</option>
                <option value="doing">Dikerjakan</option>
                <option value="revisi">Revisi</option>
                <option value="done">Selesai</option>
              </Select>
            </PropertyRow>

            <PropertyRow label="Prioritas">
              <Select
                aria-label="Ubah prioritas"
                value={task.priority}
                onChange={(e) => {
                  const next = e.target.value as TaskPriority;
                  void patchTaskFields(
                    task,
                    { priority: next },
                    { priority: next },
                    { priority: next }
                  );
                }}
              >
                <option value="rendah">Rendah</option>
                <option value="sedang">Sedang</option>
                <option value="tinggi">Tinggi</option>
              </Select>
            </PropertyRow>

            <PropertyRow label="Kategori">
              <Select
                aria-label="Ubah kategori aktivitas"
                value={task.kind}
                onChange={(e) => {
                  const next = e.target.value as ActivityKind;
                  void patchTaskFields(task, { kind: next }, { kind: next }, { kind: next });
                }}
              >
                <option value="pribadi">Pribadi</option>
                <option value="kuliah">Kuliah</option>
                <option value="freelance">Freelance</option>
                <option value="intern">Intern</option>
              </Select>
            </PropertyRow>

            <PropertyRow label="Tenggat">
              <div className="flex flex-wrap items-center gap-2 w-full min-w-0">
                <Input
                  type="date"
                  value={dueDateDraft}
                  onChange={(e) => void handleDueChange(e.target.value, dueTimeDraft)}
                  aria-label="Tanggal tenggat"
                  className="w-full sm:w-auto sm:flex-1 sm:min-w-[130px]"
                />
                <Input
                  type="time"
                  value={dueTimeDraft}
                  disabled={!dueDateDraft}
                  onChange={(e) => void handleDueChange(dueDateDraft, e.target.value)}
                  aria-label="Jam tenggat"
                  className="w-full sm:w-[110px]"
                />
                {dueDateDraft && (
                  <Button
                    type="button"
                    size="sm"
                    variant="ghost"
                    onClick={() => void handleDueChange('', '')}
                  >
                    Hapus
                  </Button>
                )}
              </div>
            </PropertyRow>

            <PropertyRow label="Progres">
              <div className="w-full space-y-2">
                <ProgressControl
                  value={computedProgress.percent}
                  lockedByChecklist={computedProgress.lockedByChecklist || task.status === 'done'}
                  onChange={
                    !computedProgress.lockedByChecklist && task.status !== 'done'
                      ? (nextVal) => void handleProgressCommit(nextVal)
                      : undefined
                  }
                />
                {!computedProgress.lockedByChecklist && task.status !== 'done' && (
                  <div className="flex flex-wrap gap-1.5">
                    {[0, 25, 50, 75].map((preset) => (
                      <button
                        key={preset}
                        type="button"
                        onClick={() => void handleProgressCommit(preset)}
                        className={cn(
                          'rounded border px-2 py-0.5 text-[11px] font-medium tabular-nums transition-colors',
                          computedProgress.percent === preset
                            ? 'border-primary bg-primary-subtle text-primary'
                            : 'border-border bg-subtle text-muted-foreground hover:text-foreground'
                        )}
                      >
                        {preset}%
                      </button>
                    ))}
                  </div>
                )}
              </div>
            </PropertyRow>

            <PropertyRow label="Revisi">
              <div className="space-y-1 text-xs">
                <span className="font-semibold text-foreground tabular-nums">
                  {task.revision_count} kali
                </span>
                {task.latest_revision_note && (
                  <p className="text-muted-foreground">{task.latest_revision_note}</p>
                )}
              </div>
            </PropertyRow>

            <PropertyRow label="Proyek">
              <Select
                aria-label="Pilih proyek"
                value={task.project_id ?? ''}
                onChange={(e) => {
                  const nextProjectId = e.target.value || null;
                  const nextProjName =
                    projects.find((p) => p.id === nextProjectId)?.name ?? null;
                  void patchTaskFields(
                    task,
                    {
                      project_id: nextProjectId,
                      project_name: nextProjName,
                      milestone_payment_id: null,
                    },
                    {
                      project_id: nextProjectId,
                      milestone_payment_id: null,
                    },
                    {
                      project_id: nextProjectId,
                      milestone_payment_id: null,
                    }
                  );
                }}
              >
                <option value="">Tanpa Proyek</option>
                {projects.map((proj) => (
                  <option key={proj.id} value={proj.id}>
                    {proj.name}
                  </option>
                ))}
              </Select>
            </PropertyRow>

            <PropertyRow label="Penanggung Jawab">
              <Select
                aria-label="Pilih penanggung jawab tugas"
                value={task.assignee_id ?? ''}
                onChange={(e) => {
                  const nextAssigneeId = e.target.value || null;
                  void patchTaskFields(
                    task,
                    { assignee_id: nextAssigneeId },
                    { assignee_id: nextAssigneeId },
                    { assignee_id: nextAssigneeId }
                  );
                }}
              >
                <option value="">Belum Ditugaskan</option>
                {members.map((m) => (
                  <option key={m.user_id} value={m.user_id}>
                    {m.display_name} ({m.role})
                  </option>
                ))}
              </Select>
            </PropertyRow>

            {projectPayments.length > 0 && (
              <PropertyRow label="Termin">
                <Select
                  aria-label="Pilih termin pembayaran"
                  value={task.milestone_payment_id ?? ''}
                  onChange={(e) => {
                    const nextPayId = e.target.value || null;
                    void patchTaskFields(
                      task,
                      { milestone_payment_id: nextPayId },
                      { milestone_payment_id: nextPayId },
                      { milestone_payment_id: nextPayId }
                    );
                  }}
                >
                  <option value="">Tidak ditautkan</option>
                  {projectPayments.map((pay) => (
                    <option key={pay.id} value={pay.id}>
                      {pay.label}
                    </option>
                  ))}
                </Select>
              </PropertyRow>
            )}

            <PropertyRow label="Pengulangan">
              <div className="flex flex-wrap items-center gap-2 w-full">
                <Select
                  aria-label="Aturan pengulangan"
                  value={recurrenceFreq}
                  onChange={(e) => {
                    const nextFreq = e.target.value as RecurrenceFreq;
                    const serialized = serializeRecurrenceRule(
                      nextFreq,
                      recurrenceInterval
                    );
                    void patchTaskFields(
                      task,
                      { recurrence_rule: serialized },
                      { recurrence_rule: serialized }
                    );
                  }}
                  className="flex-1 min-w-[130px]"
                >
                  <option value="none">Tidak berulang</option>
                  <option value="daily">Harian</option>
                  <option value="weekly">Mingguan</option>
                  <option value="monthly">Bulanan</option>
                </Select>

                {recurrenceFreq !== 'none' && (
                  <div className="flex items-center gap-1.5">
                    <Repeat className="h-3.5 w-3.5 text-muted-foreground" strokeWidth={1.75} />
                    <Input
                      type="number"
                      min={1}
                      max={90}
                      value={recurrenceInterval}
                      onChange={(e) => {
                        const nextInt = Math.max(1, Number(e.target.value) || 1);
                        const serialized = serializeRecurrenceRule(recurrenceFreq, nextInt);
                        void patchTaskFields(
                          task,
                          { recurrence_rule: serialized },
                          { recurrence_rule: serialized }
                        );
                      }}
                      aria-label="Interval pengulangan"
                      className="w-[72px]"
                    />
                  </div>
                )}
              </div>
            </PropertyRow>

            <PropertyRow label="Estimasi">
              <div className="flex items-center gap-2 w-full">
                <Input
                  type="number"
                  min={0}
                  step={5}
                  value={estimateDraft}
                  onChange={(e) => setEstimateDraft(e.target.value)}
                  onBlur={() => {
                    const num = estimateDraft.trim() ? Number(estimateDraft) : null;
                    const safeNum =
                      num != null && Number.isFinite(num) && num > 0
                        ? Math.round(num)
                        : null;
                    if (safeNum === task.estimate_minutes) return;
                    void patchTaskFields(
                      task,
                      { estimate_minutes: safeNum },
                      { estimate_minutes: safeNum },
                      { estimate_minutes: safeNum }
                    );
                  }}
                  placeholder="0"
                  aria-label="Estimasi menit"
                  className="w-[100px]"
                />
                <span className="text-xs text-muted-foreground">menit</span>
              </div>
            </PropertyRow>

            <PropertyRow label="Tag">
              <div className="w-full space-y-2">
                {task.tags.length > 0 && (
                  <div className="flex flex-wrap gap-1.5">
                    {task.tags.map((tag) => (
                      <span
                        key={tag}
                        className="inline-flex items-center gap-1 rounded border border-border bg-subtle px-2 py-0.5 text-xs text-foreground"
                      >
                        #{tag}
                        <button
                          type="button"
                          onClick={() => void handleRemoveTag(tag)}
                          className="text-muted-foreground hover:text-expense"
                          aria-label={`Hapus tag ${tag}`}
                        >
                          <X className="h-3 w-3" />
                        </button>
                      </span>
                    ))}
                  </div>
                )}
                <div className="flex gap-1.5">
                  <Input
                    value={tagDraft}
                    onChange={(e) => setTagDraft(e.target.value)}
                    onKeyDown={(e) => {
                      if (e.key === 'Enter') {
                        e.preventDefault();
                        void handleAddTag();
                      }
                    }}
                    placeholder="Tambah tag..."
                    aria-label="Tag baru"
                  />
                  <Button
                    type="button"
                    size="sm"
                    variant="outline"
                    onClick={() => void handleAddTag()}
                    disabled={!tagDraft.trim()}
                  >
                    <Plus className="h-4 w-4" strokeWidth={1.75} />
                  </Button>
                </div>
              </div>
            </PropertyRow>
          </section>

          {/* Pelacak Waktu & Mode Fokus (Pomodoro / Stopwatch / Catat Manual) */}
          <TimeTrackerBlock
            taskId={task.id}
            workspaceId={workspaceId}
            estimateMinutes={task.estimate_minutes}
            logs={timeLogs}
            schemaAvailable={timeLogsSupported}
            onReload={reloadTimeLogs}
          />

          {/* Rich Text Blocks */}
          <TaskRichEditor
            taskId={task.id}
            initialBlocks={task.description_blocks}
            initialDescription={task.description}
            onSave={handleRichSave}
          />

          {/* Checklist */}
          <TaskChecklistSection
            items={task.checklist_items}
            onAddItem={handleAddChecklist}
            onToggleItem={handleToggleChecklist}
            onDeleteItem={handleDeleteChecklist}
          />

          {/* Nested Subtasks */}
          <TaskSubtasksSection
            subtasks={subtasks}
            schemaSupported={subtasksSupported}
            onAddSubtask={handleAddSubtask}
            onToggleSubtaskDone={handleToggleSubtaskDone}
            onOpenSubtask={onSelectTask}
          />

          {/* Cross-Entity Links */}
          <TaskEntityLinksSection
            taskId={task.id}
            links={links}
            schemaSupported={linksSupported}
            targetsByType={targetsByType}
            onAddLink={handleAddEntityLink}
            onDeleteLink={handleDeleteEntityLink}
            onNavigateTarget={handleNavigateEntity}
          />

          {/* Attachments */}
          <TaskAttachmentsSection
            attachments={attachments}
            uploading={uploadingAttachment}
            errorMessage={attachmentError}
            onUploadFile={handleUploadAttachment}
            onDownloadAttachment={handleDownloadAttachment}
            onDeleteAttachment={handleDeleteAttachment}
          />

          {/* Comments */}
          <TaskCommentsSection
            comments={comments}
            currentUserId={currentUserId}
            schemaSupported={commentsSupported}
            onAddComment={handleAddComment}
            onEditComment={handleEditComment}
            onDeleteComment={handleDeleteComment}
          />

          {/* Status History */}
          <TaskHistorySection history={history} schemaSupported={historySupported} />
        </div>
      </aside>
    </div>
  );
}
