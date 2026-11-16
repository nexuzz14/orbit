'use client';

import React from 'react';
import {
  AlertTriangle,
  CheckCircle2,
  CheckSquare,
  Circle,
  Clock,
  Folder,
  GitBranch,
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
} from '@/lib/task-v2';
import {
  cn,
  KindBadge,
  ProgressControl,
  StatusBadge,
  TaskStatusBadge,
} from '@/components/ui';
import type { TaskRecord } from './types';

interface TaskListViewProps {
  tasks: TaskRecord[];
  subtasksByParent: Map<string, TaskRecord[]>;
  onOpenTask: (task: TaskRecord) => void;
  onToggleDone: (task: TaskRecord) => void;
  onChangeStatus: (task: TaskRecord, toStatus: TaskStatus) => void;
}

const PRIORITY_BADGE: Record<
  TaskPriority,
  { label: string; variant: 'expense' | 'warning' | 'neutral' }
> = {
  tinggi: { label: 'Tinggi', variant: 'expense' },
  sedang: { label: 'Sedang', variant: 'warning' },
  rendah: { label: 'Rendah', variant: 'neutral' },
};

export function TaskListView({
  tasks,
  subtasksByParent,
  onOpenTask,
  onToggleDone,
  onChangeStatus,
}: TaskListViewProps) {
  return (
    <div className="rounded-lg border border-border bg-card divide-y divide-border overflow-hidden">
      {tasks.map((task) => {
        const isDone = task.status === 'done';
        const overdue = isTaskOverdue(task);
        const stagnant = isTaskStagnant(task);
        const stagnantDays = stagnant ? getStagnantDays(task) : 0;
        const subtasks = subtasksByParent.get(task.id) ?? [];
        const progress = computeTaskProgress({
          status: task.status,
          progressPercent: task.progress_percent,
          checklistItems: task.checklist_items,
          subtasks,
        });
        const priorityMeta = PRIORITY_BADGE[task.priority] || PRIORITY_BADGE.sedang;
        const checklistDone = task.checklist_items.filter((c) => c.done).length;
        const checklistTotal = task.checklist_items.length;
        const hasRecurrence = Boolean(parseRecurrenceRule(task.recurrence_rule));

        return (
          <div
            key={task.id}
            className={cn(
              'flex flex-col md:flex-row md:items-center justify-between gap-3 px-3.5 py-3 hover:bg-hover transition-colors duration-150',
              isDone && 'opacity-75'
            )}
          >
            <div className="flex items-start gap-2.5 min-w-0 flex-1">
              <button
                type="button"
                onClick={() => onToggleDone(task)}
                aria-label={isDone ? `Buka kembali ${task.title}` : `Selesaikan ${task.title}`}
                className={cn(
                  'h-11 w-11 -my-1.5 -ml-1.5 shrink-0 inline-flex items-center justify-center rounded-md transition-colors',
                  isDone ? 'text-income' : 'text-muted-foreground hover:text-primary'
                )}
              >
                {isDone ? (
                  <CheckCircle2 className="h-5 w-5" />
                ) : (
                  <Circle className="h-5 w-5" />
                )}
              </button>

              <div className="min-w-0 flex-1 space-y-1">
                <div className="flex flex-wrap items-center gap-2">
                  <button
                    type="button"
                    onClick={() => onOpenTask(task)}
                    className={cn(
                      'text-left text-sm font-semibold text-foreground hover:text-primary transition-colors',
                      isDone && 'line-through text-muted-foreground'
                    )}
                  >
                    {task.title}
                  </button>
                  <TaskStatusBadge status={task.status} compact />
                  <KindBadge kind={task.kind} />
                  <StatusBadge variant={priorityMeta.variant}>{priorityMeta.label}</StatusBadge>
                  {overdue && <StatusBadge variant="expense">Terlambat</StatusBadge>}
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

                <div className="flex flex-wrap items-center gap-3 text-xs text-muted-foreground tabular-nums">
                  {task.project_name && (
                    <span className="inline-flex items-center gap-1">
                      <Folder className="h-3.5 w-3.5" aria-hidden="true" />
                      <span>{task.project_name}</span>
                    </span>
                  )}
                  {task.due_at && (
                    <span
                      className={cn(
                        'inline-flex items-center gap-1',
                        overdue && 'text-expense font-semibold'
                      )}
                    >
                      <Clock className="h-3.5 w-3.5" aria-hidden="true" />
                      <span>{formatDateOnly(task.due_at)}</span>
                    </span>
                  )}
                  {checklistTotal > 0 && (
                    <span className="inline-flex items-center gap-1">
                      <CheckSquare className="h-3.5 w-3.5" aria-hidden="true" />
                      <span>
                        Checklist {checklistDone}/{checklistTotal}
                      </span>
                    </span>
                  )}
                  {subtasks.length > 0 && (
                    <span className="inline-flex items-center gap-1">
                      <GitBranch className="h-3.5 w-3.5" aria-hidden="true" />
                      <span>
                        Subtugas {subtasks.filter((s) => s.status === 'done').length}/{subtasks.length}
                      </span>
                    </span>
                  )}
                  {hasRecurrence && (
                    <span className="inline-flex items-center gap-1">
                      <Repeat className="h-3.5 w-3.5" aria-hidden="true" />
                      <span>Berulang</span>
                    </span>
                  )}
                </div>
              </div>
            </div>

            {/* Kanan: Progres + Status Select + Buka Detail */}
            <div className="flex items-center gap-3 pl-9 md:pl-0 shrink-0">
              <div className="w-24">
                <ProgressControl value={progress.percent} compact />
              </div>

              <select
                aria-label={`Ubah status ${task.title}`}
                value={task.status}
                onChange={(e) => onChangeStatus(task, e.target.value as TaskStatus)}
                className="min-h-11 rounded-md border border-border bg-background px-2.5 py-1.5 text-xs font-medium text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
              >
                <option value="todo">Belum dikerjakan</option>
                <option value="doing">Dikerjakan</option>
                <option value="revisi">Revisi</option>
                <option value="done">Selesai</option>
              </select>

              <button
                type="button"
                onClick={() => onOpenTask(task)}
                className="min-h-11 rounded-md border border-border bg-background px-3 py-2 text-xs font-medium text-foreground hover:bg-subtle transition-colors"
              >
                Detail
              </button>
            </div>
          </div>
        );
      })}
    </div>
  );
}
