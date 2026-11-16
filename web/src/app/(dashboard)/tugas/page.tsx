'use client';

import React, { Suspense, useCallback, useEffect, useMemo, useState } from 'react';
import { usePathname, useRouter, useSearchParams } from 'next/navigation';
import {
  Bookmark,
  FolderKanban,
  Kanban,
  List,
  Pin,
  PinOff,
  Plus,
  RotateCcw,
  Search,
  Sparkles,
  Trash2,
} from 'lucide-react';
import { createClient } from '@/lib/supabase/client';
import { useOrbitRealtime, RealtimeStatusBadge } from '@/lib/use-orbit-realtime';
import {
  applyTaskFilters,
  DEFAULT_TASK_FILTERS,
  DEFAULT_TASK_SORT,
  parseSavedViewFilter,
  parseSavedViewSort,
  serializeSavedViewFilter,
  sortTaskItems,
  type TaskAttentionFilter,
  type TaskFilterState,
  type TaskSortState,
} from '@/lib/task-v2';
import type { ActivityKind, Json, TaskPriority, TaskStatus } from '@/types/database';
import {
  Button,
  Dialog,
  EmptyState,
  ErrorState,
  Input,
  Select,
  Skeleton,
  cn,
} from '@/components/ui';
import {
  changeTaskStatusWithRpc,
  isSchemaFeatureUnavailable,
  mapRawTaskRow,
} from '@/components/tasks/task-actions';
import { KanbanBoard } from '@/components/tasks/kanban-board';
import { TaskListView } from '@/components/tasks/task-list-view';
import { TaskProjectView } from '@/components/tasks/task-project-view';
import { RevisionDialog } from '@/components/tasks/revision-dialog';
import { TaskCreateModal } from '@/components/tasks/task-create-modal';
import { DetailPeek } from '@/components/tasks/detail-peek';
import type {
  AccountOption,
  PaymentOption,
  ProjectOption,
  SavedViewItem,
  TaskRecord,
  TaskTemplateItem,
  TasksViewMode,
} from '@/components/tasks/types';

interface PendingTransition {
  task: TaskRecord;
  toStatus: TaskStatus;
  newSortOrder?: number;
  reorderedColumnUpdates?: Array<{ id: string; sort_order: number }>;
}

const ACTIVE_WORKSPACE_STORAGE_KEY = 'orbit_active_workspace_id';

function mapSavedViewModeToUi(mode: string | null | undefined): TasksViewMode {
  if (mode === 'list') return 'list';
  if (mode === 'projects') return 'projects';
  return 'board';
}

function TugasPageSkeleton() {
  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <Skeleton className="h-8 w-44" />
        <Skeleton className="h-11 w-36" />
      </div>
      <div className="grid grid-cols-1 gap-3 md:grid-cols-4">
        <Skeleton className="h-64 w-full" />
        <Skeleton className="h-64 w-full" />
        <Skeleton className="h-64 w-full" />
        <Skeleton className="h-64 w-full" />
      </div>
    </div>
  );
}

function TugasPageContent() {
  const supabase = useMemo(() => createClient(), []);
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();

  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [actionNotice, setActionNotice] = useState<{
    tone: 'error' | 'info';
    text: string;
  } | null>(null);

  const [workspaceId, setWorkspaceId] = useState<string | null>(null);
  const [tasks, setTasks] = useState<TaskRecord[]>([]);
  const [projects, setProjects] = useState<ProjectOption[]>([]);
  const [payments, setPayments] = useState<PaymentOption[]>([]);
  const [accounts, setAccounts] = useState<AccountOption[]>([]);
  const [savedViews, setSavedViews] = useState<SavedViewItem[]>([]);
  const [savedViewsSupported, setSavedViewsSupported] = useState(true);
  const [templates, setTemplates] = useState<TaskTemplateItem[]>([]);

  const [viewMode, setViewMode] = useState<TasksViewMode>('board');
  const [filters, setFilters] = useState<TaskFilterState>({ ...DEFAULT_TASK_FILTERS });
  const [sortState, setSortState] = useState<TaskSortState>({ ...DEFAULT_TASK_SORT });
  const [activeSavedViewId, setActiveSavedViewId] = useState<string | null>(null);

  const [createOpen, setCreateOpen] = useState(false);
  const [peekTaskId, setPeekTaskId] = useState<string | null>(null);

  const [pendingRevision, setPendingRevision] = useState<PendingTransition | null>(null);
  const [revisionSubmitting, setRevisionSubmitting] = useState(false);

  const [saveViewDialogOpen, setSaveViewDialogOpen] = useState(false);
  const [saveViewName, setSaveViewName] = useState('');
  const [saveViewPinned, setSaveViewPinned] = useState(true);
  const [savingView, setSavingView] = useState(false);

  const [milestonePrompt, setMilestonePrompt] = useState<{
    taskTitle: string;
    payment: PaymentOption;
  } | null>(null);
  const [milestoneAccountId, setMilestoneAccountId] = useState('');
  const [milestoneFee, setMilestoneFee] = useState('0');
  const [markingMilestone, setMarkingMilestone] = useState(false);

  const updateUrlQuery = useCallback(
    (patch: Record<string, string | null>) => {
      const params = new URLSearchParams(searchParams.toString());
      for (const [k, v] of Object.entries(patch)) {
        if (v === null || v === '') {
          params.delete(k);
        } else {
          params.set(k, v);
        }
      }
      const qs = params.toString();
      router.replace(qs ? `${pathname}?${qs}` : pathname, { scroll: false });
    },
    [pathname, router, searchParams]
  );

  const loadWorkspaceData = useCallback(async () => {
    setLoading(true);
    setLoadError(null);
    try {
      const { data: memberships, error: memberErr } = await supabase
        .from('workspace_members')
        .select('workspace_id');

      if (memberErr) throw memberErr;
      if (!memberships || memberships.length === 0) {
        setLoadError('Workspace tidak ditemukan untuk akun ini.');
        setLoading(false);
        return;
      }

      const preferred =
        typeof window !== 'undefined'
          ? window.localStorage.getItem(ACTIVE_WORKSPACE_STORAGE_KEY)
          : null;
      const resolvedWs =
        memberships.find((m) => m.workspace_id === preferred)?.workspace_id ??
        memberships[0].workspace_id;

      setWorkspaceId(resolvedWs);

      const [tasksRes, projectsRes, paymentsRes, accountsRes, viewsRes, templatesRes] =
        await Promise.all([
          supabase
            .from('tasks')
            .select(
              '*, projects(name), task_checklist_items(id, task_id, text, done, sort_order, created_at, updated_at)'
            )
            .eq('workspace_id', resolvedWs)
            .is('deleted_at', null)
            .order('sort_order', { ascending: true })
            .order('created_at', { ascending: false }),
          supabase
            .from('projects')
            .select('id, name, kind')
            .eq('workspace_id', resolvedWs)
            .is('deleted_at', null)
            .order('name', { ascending: true }),
          supabase
            .from('project_payments')
            .select('id, project_id, label, amount')
            .eq('workspace_id', resolvedWs)
            .eq('status', 'expected')
            .is('deleted_at', null),
          supabase
            .from('accounts')
            .select('id, name')
            .eq('workspace_id', resolvedWs)
            .is('deleted_at', null)
            .order('name', { ascending: true }),
          supabase
            .from('saved_views')
            .select('*')
            .eq('workspace_id', resolvedWs)
            .eq('scope', 'tasks')
            .is('deleted_at', null)
            .order('sort_order', { ascending: true })
            .order('created_at', { ascending: true }),
          supabase
            .from('task_templates')
            .select('*')
            .eq('workspace_id', resolvedWs)
            .is('deleted_at', null)
            .order('name', { ascending: true }),
        ]);

      if (tasksRes.error) throw tasksRes.error;
      if (projectsRes.error) throw projectsRes.error;

      const mappedTasks = ((tasksRes.data ?? []) as unknown as Record<string, unknown>[]).map(
        mapRawTaskRow
      );
      setTasks(mappedTasks);

      setProjects(
        (projectsRes.data ?? []).map((p) => ({
          id: p.id,
          name: p.name,
          kind: p.kind,
        }))
      );

      setPayments(
        (paymentsRes.data ?? []).map((pay) => ({
          id: pay.id,
          project_id: pay.project_id,
          label: pay.label,
          amount: Number(pay.amount),
        }))
      );

      const loadedAccounts = (accountsRes.data ?? []).map((acc) => ({
        id: acc.id,
        name: acc.name,
      }));
      setAccounts(loadedAccounts);
      if (loadedAccounts.length > 0) {
        setMilestoneAccountId((prev) => prev || loadedAccounts[0].id);
      }

      if (viewsRes.error) {
        if (isSchemaFeatureUnavailable(viewsRes.error)) {
          setSavedViewsSupported(false);
          setSavedViews([]);
        }
      } else {
        setSavedViewsSupported(true);
        setSavedViews((viewsRes.data ?? []) as SavedViewItem[]);
      }

      if (!templatesRes.error && templatesRes.data) {
        setTemplates(templatesRes.data as TaskTemplateItem[]);
      } else {
        setTemplates([]);
      }
    } catch (err) {
      setLoadError(
        err instanceof Error ? err.message : 'Gagal memuat daftar tugas dari server.'
      );
    } finally {
      setLoading(false);
    }
  }, [supabase]);

  useEffect(() => {
    void loadWorkspaceData();
  }, [loadWorkspaceData]);

  const { status: realtimeStatus } = useOrbitRealtime({
    workspaceId,
    tables: ['tasks', 'comments'],
    onChange: loadWorkspaceData,
  });

  // Sinkron query URL (?view=, ?task=, ?new=1, ?project=, ?attention=)
  useEffect(() => {
    const taskParam = searchParams.get('task');
    if (taskParam) {
      setPeekTaskId(taskParam);
    } else {
      setPeekTaskId(null);
    }

    if (searchParams.get('new') === '1' || searchParams.get('quick') === 'new') {
      setCreateOpen(true);
    }

    const projectParam = searchParams.get('project');
    if (projectParam) {
      setFilters((prev) => ({ ...prev, projectId: projectParam }));
    }

    const attentionParam = searchParams.get('attention');
    if (
      attentionParam === 'overdue' ||
      attentionParam === 'revisi' ||
      attentionParam === 'stagnant' ||
      attentionParam === 'attention'
    ) {
      setFilters((prev) => ({ ...prev, attention: attentionParam }));
    }

    const viewParam = searchParams.get('view');
    if (viewParam && savedViews.length > 0) {
      const matched = savedViews.find((v) => v.id === viewParam);
      if (matched) {
        setActiveSavedViewId(matched.id);
        setViewMode(mapSavedViewModeToUi(matched.view_mode));
        setFilters(parseSavedViewFilter(matched.filter_json));
        setSortState(parseSavedViewSort(matched.sort_json));
      }
    }
  }, [searchParams, savedViews, updateUrlQuery]);

  // Event global dari Command Palette & Sidebar
  useEffect(() => {
    const onOpenNew = () => setCreateOpen(true);
    const onOpenPeek = (e: Event) => {
      const detail = (e as CustomEvent<{ taskId?: string }>).detail;
      if (detail?.taskId) {
        setPeekTaskId(detail.taskId);
      }
    };
    const onViewMode = (e: Event) => {
      const detail = (e as CustomEvent<{ mode?: string }>).detail;
      if (detail?.mode) {
        setViewMode(mapSavedViewModeToUi(detail.mode));
      }
    };
    const onWorkspaceChanged = () => {
      setPeekTaskId(null);
      setActiveSavedViewId(null);
      void loadWorkspaceData();
    };

    window.addEventListener('orbit:open-new-task', onOpenNew);
    window.addEventListener('orbit:open-task-peek', onOpenPeek);
    window.addEventListener('orbit:tasks-view-mode', onViewMode);
    window.addEventListener('orbit:workspace-changed', onWorkspaceChanged);

    return () => {
      window.removeEventListener('orbit:open-new-task', onOpenNew);
      window.removeEventListener('orbit:open-task-peek', onOpenPeek);
      window.removeEventListener('orbit:tasks-view-mode', onViewMode);
      window.removeEventListener('orbit:workspace-changed', onWorkspaceChanged);
    };
  }, [loadWorkspaceData]);

  const subtasksByParent = useMemo(() => {
    const map = new Map<string, TaskRecord[]>();
    for (const item of tasks) {
      if (!item.parent_task_id) continue;
      const arr = map.get(item.parent_task_id) ?? [];
      arr.push(item);
      map.set(item.parent_task_id, arr);
    }
    return map;
  }, [tasks]);

  const filteredTasks = useMemo(() => {
    const matched = applyTaskFilters(tasks, filters);
    return sortTaskItems(matched, sortState);
  }, [tasks, filters, sortState]);

  const displayedTasks = useMemo(() => {
    if (filters.search.trim() || filters.attention !== 'all') {
      return filteredTasks;
    }
    return filteredTasks.filter((t) => !t.parent_task_id);
  }, [filteredTasks, filters.search, filters.attention]);

  const activePeekTask = useMemo(
    () => (peekTaskId ? tasks.find((t) => t.id === peekTaskId) ?? null : null),
    [tasks, peekTaskId]
  );

  const hasCustomFilters = useMemo(() => {
    return (
      filters.search !== '' ||
      filters.kind !== 'all' ||
      filters.priority !== 'all' ||
      filters.projectId !== 'all' ||
      filters.status !== 'all' ||
      filters.attention !== 'all' ||
      filters.tag !== ''
    );
  }, [filters]);

  const openTaskPeek = useCallback(
    (task: TaskRecord) => {
      setPeekTaskId(task.id);
      updateUrlQuery({ task: task.id });
    },
    [updateUrlQuery]
  );

  const closeTaskPeek = useCallback(() => {
    setPeekTaskId(null);
    updateUrlQuery({ task: null });
  }, [updateUrlQuery]);

  const executeStatusTransition = useCallback(
    async (transition: PendingTransition, note?: string | null) => {
      setActionNotice(null);
      const { task, toStatus, newSortOrder, reorderedColumnUpdates } = transition;
      const prevSnapshot = tasks;

      const optimisticDoneAt =
        toStatus === 'done' ? task.completed_at || new Date().toISOString() : null;
      const optimisticOrderMap = new Map(
        (reorderedColumnUpdates ?? []).map((u) => [u.id, u.sort_order])
      );

      setTasks((prev) =>
        prev.map((item) => {
          if (item.id === task.id) {
            return {
              ...item,
              status: toStatus,
              completed_at: optimisticDoneAt,
              sort_order: newSortOrder ?? optimisticOrderMap.get(item.id) ?? item.sort_order,
              progress_percent: toStatus === 'done' ? 100 : item.progress_percent,
              revision_count:
                toStatus === 'revisi' && task.status !== 'revisi'
                  ? item.revision_count + 1
                  : item.revision_count,
              latest_revision_note:
                toStatus === 'revisi' && note ? note : item.latest_revision_note,
              status_changed_at:
                task.status !== toStatus
                  ? new Date().toISOString()
                  : item.status_changed_at,
            };
          }
          const updatedOrder = optimisticOrderMap.get(item.id);
          return updatedOrder !== undefined ? { ...item, sort_order: updatedOrder } : item;
        })
      );

      const res = await changeTaskStatusWithRpc({
        supabase,
        task,
        toStatus,
        note: note ?? null,
        sortOrder: newSortOrder ?? null,
      });

      if (!res.ok) {
        setTasks(prevSnapshot);
        setActionNotice({
          tone: 'error',
          text: res.errorMessage ?? 'Gagal mengubah status tugas.',
        });
        return;
      }

      if (res.updatedRow) {
        setTasks((prev) =>
          prev.map((item) => (item.id === task.id ? res.updatedRow! : item))
        );
      }

      if (reorderedColumnUpdates && reorderedColumnUpdates.length > 0) {
        const otherUpdates = reorderedColumnUpdates.filter((u) => u.id !== task.id);
        await Promise.all(
          otherUpdates.map((upd) =>
            supabase
              .from('tasks')
              .update({ sort_order: upd.sort_order })
              .eq('id', upd.id)
          )
        );
      }

      if (toStatus === 'done' && task.milestone_payment_id) {
        const linkedPayment = payments.find((p) => p.id === task.milestone_payment_id);
        if (linkedPayment) {
          setMilestonePrompt({
            taskTitle: task.title,
            payment: linkedPayment,
          });
          setMilestoneFee('0');
        }
      }
    },
    [payments, supabase, tasks]
  );

  const handleRequestStatusChange = useCallback(
    async (
      task: TaskRecord,
      toStatus: TaskStatus,
      newSortOrder?: number,
      reorderedColumnUpdates?: Array<{ id: string; sort_order: number }>
    ) => {
      if (toStatus === 'revisi' && task.status !== 'revisi') {
        setPendingRevision({
          task,
          toStatus,
          newSortOrder,
          reorderedColumnUpdates,
        });
        return;
      }
      await executeStatusTransition({
        task,
        toStatus,
        newSortOrder,
        reorderedColumnUpdates,
      });
    },
    [executeStatusTransition]
  );

  const handleConfirmRevision = async (note: string) => {
    if (!pendingRevision) return;
    setRevisionSubmitting(true);
    try {
      await executeStatusTransition(pendingRevision, note);
      setPendingRevision(null);
    } finally {
      setRevisionSubmitting(false);
    }
  };

  const handleToggleDone = useCallback(
    (task: TaskRecord) => {
      const nextStatus: TaskStatus = task.status === 'done' ? 'todo' : 'done';
      void handleRequestStatusChange(task, nextStatus);
    },
    [handleRequestStatusChange]
  );

  const handleSelectSavedView = (view: SavedViewItem) => {
    setActiveSavedViewId(view.id);
    setViewMode(mapSavedViewModeToUi(view.view_mode));
    setFilters(parseSavedViewFilter(view.filter_json));
    setSortState(parseSavedViewSort(view.sort_json));
    updateUrlQuery({ view: view.id });
  };

  const handleSaveCurrentView = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!workspaceId) return;
    const cleanName = saveViewName.trim();
    if (!cleanName) return;

    setSavingView(true);
    setActionNotice(null);
    try {
      const { data, error } = await supabase
        .from('saved_views')
        .insert({
          workspace_id: workspaceId,
          name: cleanName,
          scope: 'tasks',
          view_mode: viewMode === 'projects' ? 'board' : viewMode,
          filter_json: serializeSavedViewFilter(filters),
          sort_json: sortState as unknown as Json,
          is_pinned: saveViewPinned,
          sort_order: savedViews.length,
        })
        .select('*')
        .single();

      if (error || !data) {
        if (isSchemaFeatureUnavailable(error)) {
          setSavedViewsSupported(false);
          setActionNotice({
            tone: 'info',
            text: 'Saved Views membutuhkan migrasi database v5.3 yang belum diterapkan di server.',
          });
        } else {
          setActionNotice({
            tone: 'error',
            text: error?.message ?? 'Gagal menyimpan tampilan.',
          });
        }
        return;
      }

      const created = data as SavedViewItem;
      setSavedViews((prev) => [...prev, created]);
      setActiveSavedViewId(created.id);
      setSaveViewDialogOpen(false);
      setSaveViewName('');
      updateUrlQuery({ view: created.id });
      window.dispatchEvent(new CustomEvent('orbit:saved-views-updated'));
    } finally {
      setSavingView(false);
    }
  };

  const handleTogglePinSavedView = async (view: SavedViewItem) => {
    const nextPinned = !view.is_pinned;
    setSavedViews((prev) =>
      prev.map((item) => (item.id === view.id ? { ...item, is_pinned: nextPinned } : item))
    );

    const { error } = await supabase
      .from('saved_views')
      .update({ is_pinned: nextPinned })
      .eq('id', view.id);

    if (error) {
      setSavedViews((prev) =>
        prev.map((item) =>
          item.id === view.id ? { ...item, is_pinned: view.is_pinned } : item
        )
      );
      setActionNotice({ tone: 'error', text: error.message });
      return;
    }

    window.dispatchEvent(new CustomEvent('orbit:saved-views-updated'));
  };

  const handleDeleteSavedView = async (viewId: string) => {
    setSavedViews((prev) => prev.filter((item) => item.id !== viewId));
    if (activeSavedViewId === viewId) {
      setActiveSavedViewId(null);
      updateUrlQuery({ view: null });
    }

    const softRes = await supabase
      .from('saved_views')
      .update({ deleted_at: new Date().toISOString() })
      .eq('id', viewId);

    if (softRes.error) {
      await supabase.from('saved_views').delete().eq('id', viewId);
    }

    window.dispatchEvent(new CustomEvent('orbit:saved-views-updated'));
  };

  const handleDeleteTemplate = async (templateId: string) => {
    setTemplates((prev) => prev.filter((item) => item.id !== templateId));
    const softRes = await supabase
      .from('task_templates')
      .update({ deleted_at: new Date().toISOString() })
      .eq('id', templateId);
    if (softRes.error) {
      await supabase.from('task_templates').delete().eq('id', templateId);
    }
  };

  const handleConfirmMilestonePaid = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!milestonePrompt) return;
    setMarkingMilestone(true);
    try {
      const feeNum = Math.max(0, Number(milestoneFee) || 0);
      const { error } = await supabase.rpc('fn_mark_payment_paid', {
        p_payment_id: milestonePrompt.payment.id,
        p_account_id: milestoneAccountId || undefined,
        p_fee: feeNum,
        p_paid_at: new Date().toISOString(),
      });

      if (error) {
        setActionNotice({ tone: 'error', text: error.message });
        return;
      }

      setPayments((prev) =>
        prev.filter((item) => item.id !== milestonePrompt.payment.id)
      );
      setMilestonePrompt(null);
      setActionNotice({
        tone: 'info',
        text: `Termin "${milestonePrompt.payment.label}" ditandai lunas dan dicatat ke transaksi.`,
      });
      window.dispatchEvent(new CustomEvent('orbit:transaction-created'));
    } finally {
      setMarkingMilestone(false);
    }
  };

  if (loading) {
    return <TugasPageSkeleton />;
  }

  if (loadError) {
    return (
      <ErrorState
        message={loadError}
        onRetry={() => void loadWorkspaceData()}
      />
    );
  }

  return (
    <div className="space-y-4">
      {/* Header Page + View Switcher + CTA */}
      <header className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
        <div>
          <div className="flex items-center gap-2.5 flex-wrap">
            <h1 className="text-xl font-semibold tracking-tight text-foreground sm:text-2xl">
              Tugas & Papan
            </h1>
            <RealtimeStatusBadge status={realtimeStatus} />
          </div>
          <p className="text-xs text-muted-foreground tabular-nums">
            {displayedTasks.length} tugas ditampilkan dari {tasks.length} total tugas aktif.
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          {/* ViewSwitcher */}
          <div
            role="tablist"
            aria-label="Pilih tampilan tugas"
            className="inline-flex rounded-lg border border-border bg-subtle p-1"
          >
            <button
              type="button"
              role="tab"
              aria-selected={viewMode === 'list'}
              onClick={() => setViewMode('list')}
              className={cn(
                'inline-flex min-h-[44px] items-center gap-1.5 rounded-md px-3 text-xs font-medium transition-colors',
                viewMode === 'list'
                  ? 'bg-card text-foreground border border-border'
                  : 'text-muted-foreground hover:text-foreground'
              )}
            >
              <List className="h-3.5 w-3.5" strokeWidth={1.75} />
              Daftar
            </button>
            <button
              type="button"
              role="tab"
              aria-selected={viewMode === 'board'}
              onClick={() => setViewMode('board')}
              className={cn(
                'inline-flex min-h-[44px] items-center gap-1.5 rounded-md px-3 text-xs font-medium transition-colors',
                viewMode === 'board'
                  ? 'bg-card text-foreground border border-border'
                  : 'text-muted-foreground hover:text-foreground'
              )}
            >
              <Kanban className="h-3.5 w-3.5" strokeWidth={1.75} />
              Papan Kanban
            </button>
            <button
              type="button"
              role="tab"
              aria-selected={viewMode === 'projects'}
              onClick={() => setViewMode('projects')}
              className={cn(
                'inline-flex min-h-[44px] items-center gap-1.5 rounded-md px-3 text-xs font-medium transition-colors',
                viewMode === 'projects'
                  ? 'bg-card text-foreground border border-border'
                  : 'text-muted-foreground hover:text-foreground'
              )}
            >
              <FolderKanban className="h-3.5 w-3.5" strokeWidth={1.75} />
              Proyek
            </button>
          </div>

          {savedViewsSupported && (
            <Button
              type="button"
              variant="outline"
              onClick={() => {
                setSaveViewName('');
                setSaveViewDialogOpen(true);
              }}
            >
              <Bookmark className="h-4 w-4" strokeWidth={1.75} />
              Simpan Tampilan
            </Button>
          )}

          <Button type="button" onClick={() => setCreateOpen(true)}>
            <Plus className="h-4 w-4" strokeWidth={1.75} />
            Tugas Baru
          </Button>
        </div>
      </header>

      {/* Saved Views Pills Bar */}
      {savedViews.length > 0 && (
        <div
          aria-label="Tampilan tersimpan"
          className="flex flex-wrap items-center gap-1.5 rounded-lg border border-border bg-card px-3 py-2"
        >
          <span className="inline-flex items-center gap-1 text-[11px] font-medium text-muted-foreground mr-1">
            <Sparkles className="h-3.5 w-3.5" strokeWidth={1.75} />
            Saved Views:
          </span>
          {savedViews.map((view) => {
            const active = activeSavedViewId === view.id;
            return (
              <div
                key={view.id}
                className={cn(
                  'inline-flex items-center rounded-md border text-xs transition-colors',
                  active
                    ? 'border-primary bg-primary-subtle text-primary'
                    : 'border-border bg-subtle text-foreground hover:bg-hover'
                )}
              >
                <button
                  type="button"
                  onClick={() => handleSelectSavedView(view)}
                  className="px-2.5 py-1.5 font-medium min-h-9"
                >
                  {view.name}
                </button>
                <button
                  type="button"
                  onClick={() => void handleTogglePinSavedView(view)}
                  className="px-1.5 py-1.5 text-muted-foreground hover:text-primary min-h-9"
                  aria-label={
                    view.is_pinned
                      ? `Lepas sematan ${view.name} dari sidebar`
                      : `Sematkan ${view.name} ke sidebar`
                  }
                  title={view.is_pinned ? 'Lepas dari sidebar' : 'Sematkan ke sidebar'}
                >
                  {view.is_pinned ? (
                    <Pin className="h-3 w-3 text-primary" strokeWidth={1.75} />
                  ) : (
                    <PinOff className="h-3 w-3" strokeWidth={1.75} />
                  )}
                </button>
                <button
                  type="button"
                  onClick={() => void handleDeleteSavedView(view.id)}
                  className="px-1.5 py-1.5 text-muted-foreground hover:text-danger min-h-9"
                  aria-label={`Hapus tampilan ${view.name}`}
                  title="Hapus tampilan"
                >
                  <Trash2 className="h-3 w-3" strokeWidth={1.75} />
                </button>
              </div>
            );
          })}
        </div>
      )}

      {/* Filter Bar */}
      <section
        aria-label="Filter dan pengurutan tugas"
        className="flex flex-wrap items-center gap-2 rounded-lg border border-border bg-card p-3"
      >
        <div className="relative w-full md:flex-1 md:min-w-[220px]">
          <Search
            className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground"
            strokeWidth={1.75}
            aria-hidden="true"
          />
          <Input
            value={filters.search}
            onChange={(e) =>
              setFilters((prev) => ({ ...prev, search: e.target.value }))
            }
            placeholder="Cari judul, catatan, atau alasan revisi..."
            className="pl-9"
            aria-label="Cari tugas"
          />
        </div>

        <Select
          aria-label="Filter kategori"
          className="w-full sm:w-auto sm:min-w-[145px]"
          value={filters.kind}
          onChange={(e) =>
            setFilters((prev) => ({
              ...prev,
              kind: e.target.value as ActivityKind | 'all',
            }))
          }
        >
          <option value="all">Semua Kategori</option>
          <option value="pribadi">Pribadi</option>
          <option value="kuliah">Kuliah</option>
          <option value="freelance">Freelance</option>
          <option value="intern">Intern</option>
        </Select>

        <Select
          aria-label="Filter prioritas"
          className="w-full sm:w-auto sm:min-w-[145px]"
          value={filters.priority}
          onChange={(e) =>
            setFilters((prev) => ({
              ...prev,
              priority: e.target.value as TaskPriority | 'all',
            }))
          }
        >
          <option value="all">Semua Prioritas</option>
          <option value="tinggi">Prioritas Tinggi</option>
          <option value="sedang">Prioritas Sedang</option>
          <option value="rendah">Prioritas Rendah</option>
        </Select>

        <Select
          aria-label="Filter proyek"
          className="w-full sm:w-auto sm:min-w-[155px]"
          value={filters.projectId}
          onChange={(e) =>
            setFilters((prev) => ({ ...prev, projectId: e.target.value }))
          }
        >
          <option value="all">Semua Proyek</option>
          <option value="none">Tanpa Proyek</option>
          {projects.map((p) => (
            <option key={p.id} value={p.id}>
              {p.name}
            </option>
          ))}
        </Select>

        <Select
          aria-label="Filter kondisi perhatian"
          className="w-full sm:w-auto sm:min-w-[150px]"
          value={filters.attention}
          onChange={(e) =>
            setFilters((prev) => ({
              ...prev,
              attention: e.target.value as TaskAttentionFilter,
            }))
          }
        >
          <option value="all">Semua Kondisi</option>
          <option value="attention">Perlu Perhatian</option>
          <option value="overdue">Terlambat</option>
          <option value="revisi">Status Revisi</option>
          <option value="stagnant">Macet &gt; 5 Hari</option>
        </Select>

        <Select
          aria-label="Urutkan tugas"
          className="w-full sm:w-auto sm:min-w-[155px]"
          value={sortState.by}
          onChange={(e) =>
            setSortState({ by: e.target.value as TaskSortState['by'] })
          }
        >
          <option value="board_default">Urut Papan</option>
          <option value="due_asc">Tenggat Terdekat</option>
          <option value="priority_desc">Prioritas Tertinggi</option>
          <option value="updated_desc">Terbaru Diubah</option>
        </Select>

        {hasCustomFilters && (
          <div className="w-full flex items-center justify-between pt-1 border-t border-border">
            <span className="text-xs text-muted-foreground">
              Filter aktif diterapkan ke tampilan saat ini.
            </span>
            <button
              type="button"
              onClick={() => {
                setFilters({ ...DEFAULT_TASK_FILTERS });
                setActiveSavedViewId(null);
                updateUrlQuery({ view: null, project: null, attention: null });
              }}
              className="inline-flex items-center gap-1 text-xs font-medium text-primary hover:underline"
            >
              <RotateCcw className="h-3.5 w-3.5" strokeWidth={1.75} />
              Reset Filter
            </button>
          </div>
        )}
      </section>

      {actionNotice && (
        <div
          role="status"
          className={cn(
            'flex items-center justify-between gap-2 rounded-lg border px-3.5 py-2.5 text-xs',
            actionNotice.tone === 'error'
              ? 'border-expense-border bg-expense-subtle text-expense'
              : 'border-primary bg-primary-subtle text-foreground'
          )}
        >
          <span>{actionNotice.text}</span>
          <button
            type="button"
            onClick={() => setActionNotice(null)}
            className="font-medium underline"
          >
            Tutup
          </button>
        </div>
      )}

      {/* Main Content by ViewSwitcher */}
      {tasks.length === 0 ? (
        <EmptyState
          title="Belum ada tugas di workspace ini"
          description="Mulai dengan membuat tugas pertama atau gunakan template tugas berulang."
          actionLabel="Buat Tugas Pertama"
          onAction={() => setCreateOpen(true)}
        />
      ) : displayedTasks.length === 0 && viewMode !== 'board' ? (
        <EmptyState
          title="Tidak ada tugas yang cocok"
          description="Coba ubah kata kunci pencarian atau reset filter aktif."
          actionLabel="Reset Filter"
          onAction={() => setFilters({ ...DEFAULT_TASK_FILTERS })}
        />
      ) : viewMode === 'board' ? (
        <KanbanBoard
          tasks={displayedTasks}
          subtasksByParent={subtasksByParent}
          onOpenTask={openTaskPeek}
          onMoveTask={handleRequestStatusChange}
        />
      ) : viewMode === 'projects' ? (
        <TaskProjectView
          tasks={displayedTasks}
          projects={projects}
          subtasksByParent={subtasksByParent}
          onOpenTask={openTaskPeek}
          onToggleDone={handleToggleDone}
          onChangeStatus={(task, toStatus) => void handleRequestStatusChange(task, toStatus)}
        />
      ) : (
        <TaskListView
          tasks={displayedTasks}
          subtasksByParent={subtasksByParent}
          onOpenTask={openTaskPeek}
          onToggleDone={handleToggleDone}
          onChangeStatus={(task, toStatus) => void handleRequestStatusChange(task, toStatus)}
        />
      )}

      {/* Create Task Modal */}
      {workspaceId && (
        <TaskCreateModal
          open={createOpen}
          onClose={() => {
            setCreateOpen(false);
            if (searchParams.get('new') === '1' || searchParams.get('quick') === 'new') {
              updateUrlQuery({ new: null, quick: null });
            }
          }}
          workspaceId={workspaceId}
          projects={projects}
          payments={payments}
          templates={templates}
          defaultProjectId={
            filters.projectId !== 'all' && filters.projectId !== 'none'
              ? filters.projectId
              : undefined
          }
          onCreated={(created) => {
            setTasks((prev) => [created, ...prev]);
            openTaskPeek(created);
          }}
          onDeleteTemplate={handleDeleteTemplate}
        />
      )}

      {/* Side Peek 480px Detail */}
      {workspaceId && (
        <DetailPeek
          open={Boolean(activePeekTask)}
          task={activePeekTask}
          allTasks={tasks}
          workspaceId={workspaceId}
          projects={projects}
          payments={payments}
          onClose={closeTaskPeek}
          onSelectTask={(nextId) => {
            setPeekTaskId(nextId);
            updateUrlQuery({ task: nextId });
          }}
          onTaskUpdated={(updated) => {
            setTasks((prev) =>
              prev.map((item) => (item.id === updated.id ? updated : item))
            );
          }}
          onTaskCreated={(created) => {
            setTasks((prev) => [...prev, created]);
          }}
          onTaskDeleted={(deletedId) => {
            setTasks((prev) => prev.filter((item) => item.id !== deletedId));
          }}
          onChangeStatus={(task, toStatus) => handleRequestStatusChange(task, toStatus)}
          onTemplateCreated={(tpl) => {
            setTemplates((prev) => [...prev, tpl]);
          }}
        />
      )}

      {/* Mandatory Revision Note Dialog */}
      <RevisionDialog
        open={Boolean(pendingRevision)}
        task={pendingRevision?.task ?? null}
        submitting={revisionSubmitting}
        onClose={() => {
          if (!revisionSubmitting) {
            setPendingRevision(null);
          }
        }}
        onConfirm={handleConfirmRevision}
      />

      {/* Save View Dialog */}
      <Dialog
        open={saveViewDialogOpen}
        onClose={() => setSaveViewDialogOpen(false)}
        title="Simpan Tampilan Saat Ini"
        description="Simpan kombinasi filter, pengurutan, dan mode tampilan untuk dibuka kembali dari bar atau sidebar."
      >
        <form onSubmit={handleSaveCurrentView} className="space-y-4">
          <div>
            <label className="mb-1.5 block text-xs font-medium text-foreground">
              Nama Tampilan *
            </label>
            <Input
              value={saveViewName}
              onChange={(e) => setSaveViewName(e.target.value)}
              placeholder="Misal: Tugas Freelance Prioritas Tinggi"
              autoFocus
              required
            />
          </div>

          <label className="flex items-center gap-2 text-sm text-foreground cursor-pointer min-h-10">
            <input
              type="checkbox"
              checked={saveViewPinned}
              onChange={(e) => setSaveViewPinned(e.target.checked)}
              className="h-4 w-4 rounded border-border accent-primary"
            />
            <span>Sematkan di sidebar bagian Saved Views</span>
          </label>

          <div className="flex justify-end gap-2 pt-2 border-t border-border">
            <Button
              type="button"
              variant="outline"
              onClick={() => setSaveViewDialogOpen(false)}
            >
              Batal
            </Button>
            <Button type="submit" disabled={savingView || !saveViewName.trim()}>
              {savingView ? 'Menyimpan...' : 'Simpan'}
            </Button>
          </div>
        </form>
      </Dialog>

      {/* Milestone Payment Linked Prompt */}
      <Dialog
        open={Boolean(milestonePrompt)}
        onClose={() => setMilestonePrompt(null)}
        title="Tugas Selesai dengan Termin Pembayaran"
        description={
          milestonePrompt
            ? `Tugas "${milestonePrompt.taskTitle}" terhubung ke termin "${milestonePrompt.payment.label}" sebesar Rp ${milestonePrompt.payment.amount.toLocaleString('id-ID')}. Catat pembayaran sebagai lunas sekarang?`
            : undefined
        }
      >
        {milestonePrompt && (
          <form onSubmit={handleConfirmMilestonePaid} className="space-y-4">
            <div>
              <label className="mb-1.5 block text-xs font-medium text-foreground">
                Akun / Rekening Penerima
              </label>
              <Select
                aria-label="Rekening penerima"
                value={milestoneAccountId}
                onChange={(e) => setMilestoneAccountId(e.target.value)}
              >
                {accounts.map((acc) => (
                  <option key={acc.id} value={acc.id}>
                    {acc.name}
                  </option>
                ))}
              </Select>
            </div>

            <div>
              <label className="mb-1.5 block text-xs font-medium text-foreground">
                Biaya Admin / Potongan (Rp)
              </label>
              <Input
                type="number"
                min={0}
                value={milestoneFee}
                onChange={(e) => setMilestoneFee(e.target.value)}
              />
            </div>

            <div className="flex justify-end gap-2 pt-2 border-t border-border">
              <Button
                type="button"
                variant="outline"
                onClick={() => setMilestonePrompt(null)}
              >
                Nanti Saja
              </Button>
              <Button type="submit" disabled={markingMilestone}>
                {markingMilestone ? 'Mencatat...' : 'Tandai Lunas'}
              </Button>
            </div>
          </form>
        )}
      </Dialog>
    </div>
  );
}

export default function TugasPage() {
  return (
    <Suspense fallback={<TugasPageSkeleton />}>
      <TugasPageContent />
    </Suspense>
  );
}
