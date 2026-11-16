'use client';

import React, { useMemo, useState } from 'react';
import {
  DndContext,
  DragOverlay,
  KeyboardSensor,
  PointerSensor,
  closestCorners,
  useDroppable,
  useSensor,
  useSensors,
  type DragEndEvent,
  type DragStartEvent,
} from '@dnd-kit/core';
import {
  SortableContext,
  arrayMove,
  sortableKeyboardCoordinates,
  useSortable,
  verticalListSortingStrategy,
} from '@dnd-kit/sortable';
import { CSS } from '@dnd-kit/utilities';
import {
  AlertTriangle,
  CheckSquare,
  Clock,
  Folder,
  GitBranch,
  GripVertical,
  Repeat,
  RotateCcw,
} from 'lucide-react';
import type { TaskPriority, TaskStatus } from '@/types/database';
import { formatDateOnly } from '@/lib/format';
import {
  computeTaskProgress,
  getStagnantDays,
  isTaskOverdue,
  isTaskStagnant,
  parseRecurrenceRule,
  partitionKanbanDoneTasks,
} from '@/lib/task-v2';
import {
  cn,
  KindBadge,
  ProgressControl,
  StatusBadge,
  TASK_STATUS_META,
} from '@/components/ui';
import type { TaskRecord } from './types';

interface KanbanBoardProps {
  tasks: TaskRecord[];
  subtasksByParent: Map<string, TaskRecord[]>;
  onOpenTask: (task: TaskRecord) => void;
  onMoveTask: (
    task: TaskRecord,
    toStatus: TaskStatus,
    newSortOrder?: number,
    reorderedColumnUpdates?: Array<{ id: string; sort_order: number }>
  ) => Promise<void> | void;
}

const KANBAN_COLUMNS: Array<{ status: TaskStatus; title: string }> = [
  { status: 'todo', title: TASK_STATUS_META.todo.label },
  { status: 'doing', title: TASK_STATUS_META.doing.label },
  { status: 'revisi', title: TASK_STATUS_META.revisi.label },
  { status: 'done', title: TASK_STATUS_META.done.label },
];

const PRIORITY_BADGE: Record<
  TaskPriority,
  { label: string; variant: 'expense' | 'warning' | 'neutral' }
> = {
  tinggi: { label: 'Tinggi', variant: 'expense' },
  sedang: { label: 'Sedang', variant: 'warning' },
  rendah: { label: 'Rendah', variant: 'neutral' },
};

function KanbanCardContent({
  task,
  subtasks,
  isDragging = false,
  onOpen,
  onQuickMove,
  dragHandleProps,
}: {
  task: TaskRecord;
  subtasks: TaskRecord[];
  isDragging?: boolean;
  onOpen?: () => void;
  onQuickMove?: (toStatus: TaskStatus) => void;
  dragHandleProps?: React.HTMLAttributes<HTMLButtonElement>;
}) {
  const overdue = isTaskOverdue(task);
  const stagnant = isTaskStagnant(task);
  const stagnantDays = stagnant ? getStagnantDays(task) : 0;
  const progress = computeTaskProgress({
    status: task.status,
    progressPercent: task.progress_percent,
    checklistItems: task.checklist_items,
    subtasks,
  });
  const priorityMeta = PRIORITY_BADGE[task.priority] || PRIORITY_BADGE.sedang;
  const checklistDone = task.checklist_items.filter((c) => c.done).length;
  const checklistTotal = task.checklist_items.length;
  const subtasksDone = subtasks.filter((s) => s.status === 'done').length;
  const hasRecurrence = Boolean(parseRecurrenceRule(task.recurrence_rule));

  return (
    <div
      className={cn(
        'rounded-md border border-border bg-card p-3 space-y-2.5 transition-colors duration-150',
        isDragging ? 'shadow-peek ring-2 ring-primary opacity-95' : 'hover:border-border-strong'
      )}
    >
      {/* Baris atas: Kind, Proyek, Prioritas & Handle */}
      <div className="flex items-start justify-between gap-2">
        <div className="flex flex-wrap items-center gap-1.5 min-w-0">
          <KindBadge kind={task.kind} />
          <StatusBadge variant={priorityMeta.variant}>{priorityMeta.label}</StatusBadge>
        </div>
        {dragHandleProps && (
          <button
            type="button"
            aria-label={`Seret kartu ${task.title}`}
            title="Seret untuk memindah atau mengurutkan"
            onClick={(e) => e.stopPropagation()}
            {...dragHandleProps}
            className="inline-flex h-8 w-8 shrink-0 cursor-grab items-center justify-center rounded-sm text-muted-foreground hover:bg-hover hover:text-foreground active:cursor-grabbing"
          >
            <GripVertical className="h-4 w-4" />
          </button>
        )}
      </div>

      {/* Judul Kartu (klik buka DetailPeek) */}
      <button
        type="button"
        onClick={onOpen}
        className="w-full text-left group focus-visible:outline-none"
      >
        <div
          className={cn(
            'text-sm font-semibold leading-snug text-foreground group-hover:text-primary transition-colors',
            task.status === 'done' && 'line-through text-muted-foreground'
          )}
        >
          {task.title}
        </div>
      </button>

      {/* Badge Proyek & Penanda Perhatian D.2 */}
      {(task.project_name || task.revision_count > 0 || stagnant) && (
        <div className="flex flex-wrap items-center gap-1.5">
          {task.project_name && (
            <span className="inline-flex items-center gap-1 rounded-xs border border-border bg-subtle/60 px-1.5 py-0.5 text-[11px] font-medium text-muted-foreground max-w-full">
              <Folder className="h-3 w-3 shrink-0" aria-hidden="true" />
              <span className="truncate">{task.project_name}</span>
            </span>
          )}
          {task.revision_count > 0 && (
            <StatusBadge variant="warning" className="gap-1">
              <RotateCcw className="h-3 w-3" aria-hidden="true" />
              <span>Revisi {task.revision_count} kali</span>
            </StatusBadge>
          )}
          {stagnant && (
            <StatusBadge variant="warning" className="gap-1">
              <AlertTriangle className="h-3 w-3" aria-hidden="true" />
              <span>Macet &gt;5 hari ({stagnantDays}h)</span>
            </StatusBadge>
          )}
        </div>
      )}

      {/* Progress Bar Mini */}
      <ProgressControl value={progress.percent} compact />

      {/* Footer Meta: Tenggat, Checklist, Subtugas */}
      <div className="flex flex-wrap items-center justify-between gap-2 text-[11px] text-muted-foreground tabular-nums">
        <div className="flex flex-wrap items-center gap-2.5">
          {task.due_at && (
            <span
              className={cn(
                'inline-flex items-center gap-1 font-medium',
                overdue ? 'text-expense font-semibold' : 'text-muted-foreground'
              )}
            >
              <Clock className="h-3 w-3 shrink-0" aria-hidden="true" />
              <span>{formatDateOnly(task.due_at)}</span>
            </span>
          )}
          {checklistTotal > 0 && (
            <span className="inline-flex items-center gap-1">
              <CheckSquare className="h-3 w-3 shrink-0" aria-hidden="true" />
              <span>
                {checklistDone}/{checklistTotal}
              </span>
            </span>
          )}
          {subtasks.length > 0 && (
            <span className="inline-flex items-center gap-1">
              <GitBranch className="h-3 w-3 shrink-0" aria-hidden="true" />
              <span>
                {subtasksDone}/{subtasks.length}
              </span>
            </span>
          )}
          {hasRecurrence && (
            <span title="Tugas berulang" className="inline-flex items-center">
              <Repeat className="h-3 w-3" aria-hidden="true" />
            </span>
          )}
        </div>
      </div>

      {/* Kontrol Aksesibel Pindah Status Tanpa Drag */}
      {onQuickMove && (
        <div
          className="pt-2 border-t border-border flex items-center justify-between gap-2"
          onPointerDown={(e) => e.stopPropagation()}
          onClick={(e) => e.stopPropagation()}
        >
          <button
            type="button"
            onClick={onOpen}
            className="min-h-11 px-2 rounded-sm text-xs font-medium text-primary hover:bg-primary-subtle transition-colors"
          >
            Detail
          </button>

          <select
            aria-label={`Ubah status ${task.title}`}
            value={task.status}
            onChange={(e) => onQuickMove(e.target.value as TaskStatus)}
            className="min-h-11 rounded-sm border border-border bg-background px-2 py-1 text-xs font-medium text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
          >
            <option value="todo">Belum dikerjakan</option>
            <option value="doing">Dikerjakan</option>
            <option value="revisi">Revisi</option>
            <option value="done">Selesai</option>
          </select>
        </div>
      )}
    </div>
  );
}

function SortableKanbanCard({
  task,
  subtasks,
  onOpen,
  onQuickMove,
}: {
  task: TaskRecord;
  subtasks: TaskRecord[];
  onOpen: () => void;
  onQuickMove: (toStatus: TaskStatus) => void;
}) {
  const {
    attributes,
    listeners,
    setNodeRef,
    transform,
    transition,
    isDragging,
  } = useSortable({
    id: task.id,
    data: { status: task.status },
  });

  const style: React.CSSProperties = {
    transform: CSS.Transform.toString(transform),
    transition,
    opacity: isDragging ? 0.35 : 1,
  };

  return (
    <div ref={setNodeRef} style={style}>
      <KanbanCardContent
        task={task}
        subtasks={subtasks}
        onOpen={onOpen}
        onQuickMove={onQuickMove}
        dragHandleProps={{ ...attributes, ...listeners }}
      />
    </div>
  );
}

function KanbanColumn({
  status,
  title,
  tasks,
  totalCount,
  subtasksByParent,
  footerSlot,
  onOpenTask,
  onQuickMove,
}: {
  status: TaskStatus;
  title: string;
  tasks: TaskRecord[];
  totalCount: number;
  subtasksByParent: Map<string, TaskRecord[]>;
  footerSlot?: React.ReactNode;
  onOpenTask: (task: TaskRecord) => void;
  onQuickMove: (task: TaskRecord, toStatus: TaskStatus) => void;
}) {
  const { setNodeRef, isOver } = useDroppable({
    id: `column-${status}`,
    data: { status },
  });

  const statusMeta = TASK_STATUS_META[status];

  return (
    <div
      ref={setNodeRef}
      data-column-status={status}
      className={cn(
        'flex flex-col rounded-lg border bg-sidebar p-3 min-h-[420px] transition-colors duration-150',
        isOver ? 'border-primary bg-primary-subtle' : 'border-border'
      )}
    >
      <div className="flex items-center justify-between gap-2 pb-2.5 mb-2.5 border-b border-border">
        <div className="flex items-center gap-2 min-w-0">
          <span
            aria-hidden="true"
            className="h-2 w-2 rounded-full shrink-0"
            style={{ backgroundColor: statusMeta.style.color }}
          />
          <h3 className="text-xs font-semibold uppercase tracking-wide text-foreground truncate">
            {title}
          </h3>
        </div>
        <span className="rounded-xs border border-border bg-card px-1.5 py-0.5 text-xs font-semibold text-muted-foreground tabular-nums">
          {totalCount}
        </span>
      </div>

      <SortableContext
        items={tasks.map((t) => t.id)}
        strategy={verticalListSortingStrategy}
      >
        <div className="flex-1 space-y-2.5">
          {tasks.length === 0 ? (
            <div className="rounded-md border border-dashed border-border bg-card/50 p-5 text-center text-xs text-muted-foreground">
              Seret tugas ke kolom ini
            </div>
          ) : (
            tasks.map((task) => (
              <SortableKanbanCard
                key={task.id}
                task={task}
                subtasks={subtasksByParent.get(task.id) ?? []}
                onOpen={() => onOpenTask(task)}
                onQuickMove={(toStatus) => onQuickMove(task, toStatus)}
              />
            ))
          )}
        </div>
      </SortableContext>

      {footerSlot}
    </div>
  );
}

export function KanbanBoard({
  tasks,
  subtasksByParent,
  onOpenTask,
  onMoveTask,
}: KanbanBoardProps) {
  const [showAllDone, setShowAllDone] = useState(false);
  const [activeTaskId, setActiveTaskId] = useState<string | null>(null);

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 6 } }),
    useSensor(KeyboardSensor, { coordinateGetter: sortableKeyboardCoordinates })
  );

  const tasksByStatus = useMemo(() => {
    const grouped: Record<TaskStatus, TaskRecord[]> = {
      todo: [],
      doing: [],
      revisi: [],
      done: [],
    };
    for (const t of tasks) {
      grouped[t.status].push(t);
    }
    return grouped;
  }, [tasks]);

  const donePartition = useMemo(
    () => partitionKanbanDoneTasks(tasksByStatus.done, showAllDone),
    [tasksByStatus.done, showAllDone]
  );

  const activeTask = useMemo(
    () => (activeTaskId ? tasks.find((t) => t.id === activeTaskId) || null : null),
    [activeTaskId, tasks]
  );

  const handleDragStart = (event: DragStartEvent) => {
    setActiveTaskId(String(event.active.id));
  };

  const handleDragEnd = async (event: DragEndEvent) => {
    setActiveTaskId(null);
    const { active, over } = event;
    if (!over) return;

    const draggedId = String(active.id);
    const overId = String(over.id);
    const draggedTask = tasks.find((t) => t.id === draggedId);
    if (!draggedTask) return;

    let targetStatus: TaskStatus = draggedTask.status;
    if (overId.startsWith('column-')) {
      targetStatus = overId.replace('column-', '') as TaskStatus;
    } else {
      const overTask = tasks.find((t) => t.id === overId);
      if (overTask) {
        targetStatus = overTask.status;
      }
    }

    const colTasks =
      targetStatus === 'done' ? donePartition.visible : tasksByStatus[targetStatus];

    if (draggedTask.status === targetStatus) {
      if (overId.startsWith('column-') || draggedId === overId) return;
      const oldIdx = colTasks.findIndex((t) => t.id === draggedId);
      const newIdx = colTasks.findIndex((t) => t.id === overId);
      if (oldIdx === -1 || newIdx === -1 || oldIdx === newIdx) return;

      const reordered = arrayMove(colTasks, oldIdx, newIdx);
      const updates = reordered.map((item, idx) => ({
        id: item.id,
        sort_order: (idx + 1) * 100,
      }));
      const targetOrder = updates.find((u) => u.id === draggedId)?.sort_order ?? (newIdx + 1) * 100;
      await onMoveTask(draggedTask, targetStatus, targetOrder, updates);
      return;
    }

    const overIdx = overId.startsWith('column-')
      ? colTasks.length
      : Math.max(0, colTasks.findIndex((t) => t.id === overId));
    const targetSortOrder = (overIdx + 1) * 100;

    await onMoveTask(draggedTask, targetStatus, targetSortOrder);
  };

  return (
    <DndContext
      sensors={sensors}
      collisionDetection={closestCorners}
      onDragStart={handleDragStart}
      onDragEnd={handleDragEnd}
    >
      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-3.5 items-start">
        {KANBAN_COLUMNS.map((col) => {
          const isDoneCol = col.status === 'done';
          const visibleTasks = isDoneCol ? donePartition.visible : tasksByStatus[col.status];
          const totalCount = isDoneCol
            ? visibleTasks.length
            : tasksByStatus[col.status].length;

          const doneFooter =
            isDoneCol && donePartition.hiddenCount > 0 ? (
              <div className="mt-3 pt-2.5 border-t border-border">
                <button
                  type="button"
                  onClick={() => setShowAllDone((prev) => !prev)}
                  className="min-h-11 w-full rounded-md border border-border bg-card px-3 py-2 text-xs font-medium text-foreground hover:bg-hover transition-colors tabular-nums"
                >
                  {showAllDone
                    ? `Tampilkan 14 hari terakhir (sembunyikan ${donePartition.hiddenCount})`
                    : `Lihat semua selesai (${donePartition.hiddenCount} tugas lama)`}
                </button>
              </div>
            ) : null;

          return (
            <KanbanColumn
              key={col.status}
              status={col.status}
              title={col.title}
              tasks={visibleTasks}
              totalCount={totalCount}
              subtasksByParent={subtasksByParent}
              footerSlot={doneFooter}
              onOpenTask={onOpenTask}
              onQuickMove={(task, toStatus) => onMoveTask(task, toStatus)}
            />
          );
        })}
      </div>

      <DragOverlay>
        {activeTask ? (
          <div className="w-[290px]">
            <KanbanCardContent
              task={activeTask}
              subtasks={subtasksByParent.get(activeTask.id) ?? []}
              isDragging
            />
          </div>
        ) : null}
      </DragOverlay>
    </DndContext>
  );
}
