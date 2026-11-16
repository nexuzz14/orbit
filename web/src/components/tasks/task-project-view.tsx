'use client';

import React, { useMemo } from 'react';
import { Folder, Inbox } from 'lucide-react';
import type { TaskStatus } from '@/types/database';
import { KindBadge, ProgressControl, StatusBadge } from '@/components/ui';
import type { ProjectOption, TaskRecord } from './types';
import { TaskListView } from './task-list-view';

interface TaskProjectViewProps {
  tasks: TaskRecord[];
  projects: ProjectOption[];
  subtasksByParent: Map<string, TaskRecord[]>;
  onOpenTask: (task: TaskRecord) => void;
  onToggleDone: (task: TaskRecord) => void;
  onChangeStatus: (task: TaskRecord, toStatus: TaskStatus) => void;
}

export function TaskProjectView({
  tasks,
  projects,
  subtasksByParent,
  onOpenTask,
  onToggleDone,
  onChangeStatus,
}: TaskProjectViewProps) {
  const groups = useMemo(() => {
    const projectMap = new Map(projects.map((p) => [p.id, p]));
    const bucket = new Map<string, TaskRecord[]>();

    for (const task of tasks) {
      const key = task.project_id || '__unassigned__';
      const arr = bucket.get(key) || [];
      arr.push(task);
      bucket.set(key, arr);
    }

    const result: Array<{
      key: string;
      name: string;
      kind: string | null;
      items: TaskRecord[];
    }> = [];

    for (const [key, items] of bucket.entries()) {
      if (key === '__unassigned__') continue;
      const proj = projectMap.get(key);
      result.push({
        key,
        name: proj?.name || items[0]?.project_name || 'Proyek',
        kind: proj?.kind || items[0]?.kind || null,
        items,
      });
    }

    result.sort((a, b) => a.name.localeCompare(b.name, 'id'));

    const unassigned = bucket.get('__unassigned__');
    if (unassigned && unassigned.length > 0) {
      result.push({
        key: '__unassigned__',
        name: 'Tugas Lepas (Tanpa Kegiatan)',
        kind: null,
        items: unassigned,
      });
    }

    return result;
  }, [tasks, projects]);

  return (
    <div className="space-y-5">
      {groups.map((group) => {
        const doneCount = group.items.filter((t) => t.status === 'done').length;
        const pct = group.items.length > 0 ? Math.round((doneCount / group.items.length) * 100) : 0;

        return (
          <section key={group.key} className="space-y-2.5">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 rounded-lg border border-border bg-sidebar px-4 py-3">
              <div className="flex items-center gap-2.5 min-w-0">
                {group.key === '__unassigned__' ? (
                  <Inbox className="h-4 w-4 shrink-0 text-muted-foreground" aria-hidden="true" />
                ) : (
                  <Folder className="h-4 w-4 shrink-0 text-primary" aria-hidden="true" />
                )}
                <h2 className="text-sm font-semibold text-foreground truncate">{group.name}</h2>
                {group.kind && <KindBadge kind={group.kind} />}
                <StatusBadge variant="neutral">
                  {doneCount}/{group.items.length} selesai
                </StatusBadge>
              </div>
              <div className="w-full sm:w-40">
                <ProgressControl value={pct} compact />
              </div>
            </div>

            <TaskListView
              tasks={group.items}
              subtasksByParent={subtasksByParent}
              onOpenTask={onOpenTask}
              onToggleDone={onToggleDone}
              onChangeStatus={onChangeStatus}
            />
          </section>
        );
      })}
    </div>
  );
}
