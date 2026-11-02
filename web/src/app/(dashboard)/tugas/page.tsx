'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';
import { formatDateIndo } from '@/lib/format';
import type { ActivityKind, TaskPriority, TaskStatus } from '@/types/database';
import {
  CheckSquare,
  Plus,
  Trash2,
  Edit2,
  CheckCircle2,
  Circle,
  Clock,
  X,
  Folder,
} from 'lucide-react';
import {
  Card,
  CardContent,
  Button,
  Input,
  Select,
  Dialog,
  SegmentedControl,
  KindBadge,
  StatusBadge,
  Skeleton,
  EmptyState,
  ErrorState,
  AgendaSubNav,
  ACTIVITY_KIND_META,
} from '@/components/ui';

type TaskItem = {
  id: string;
  workspace_id: string;
  project_id: string | null;
  project_name?: string | null;
  kind: ActivityKind;
  title: string;
  description: string | null;
  status: TaskStatus;
  priority: TaskPriority;
  due_at: string | null;
  due_is_date_only: boolean;
  completed_at: string | null;
  milestone_payment_id: string | null;
  tags: string[];
  checklist_items?: ChecklistItem[];
};

type ChecklistItem = {
  id: string;
  task_id: string;
  text: string;
  done: boolean;
  sort_order: number;
};

type ProjectOption = {
  id: string;
  name: string;
  kind: ActivityKind;
};

type PaymentOption = {
  id: string;
  project_id: string;
  label: string;
  amount: number;
};

type AccountItem = {
  id: string;
  name: string;
};

const PRIORITY_VARIANT: Record<TaskPriority, { label: string; variant: 'expense' | 'warning' | 'neutral' }> = {
  tinggi: { label: 'Prioritas Tinggi', variant: 'expense' },
  sedang: { label: 'Prioritas Sedang', variant: 'warning' },
  rendah: { label: 'Prioritas Rendah', variant: 'neutral' },
};

export default function TugasPage() {
  const supabase = createClient();
  const [workspaceId, setWorkspaceId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState<string | null>(null);

  const [viewMode, setViewMode] = useState<'list' | 'kanban'>('list');

  const [filterKind, setFilterKind] = useState<ActivityKind | 'all'>('all');
  const [filterProject, setFilterProject] = useState<string>('all');
  const [filterPriority, setFilterPriority] = useState<TaskPriority | 'all'>('all');
  const [searchQuery, setSearchQuery] = useState('');

  const [tasks, setTasks] = useState<TaskItem[]>([]);
  const [projects, setProjects] = useState<ProjectOption[]>([]);
  const [milestones, setMilestones] = useState<PaymentOption[]>([]);
  const [accounts, setAccounts] = useState<AccountItem[]>([]);

  const [showTaskModal, setShowTaskModal] = useState(false);
  const [modalMode, setModalMode] = useState<'create' | 'edit'>('create');
  const [editingTaskId, setEditingTaskId] = useState<string | null>(null);

  const [formTitle, setFormTitle] = useState('');
  const [formDescription, setFormDescription] = useState('');
  const [formKind, setFormKind] = useState<ActivityKind>('pribadi');
  const [formProjectId, setFormProjectId] = useState<string>('');
  const [formPriority, setFormPriority] = useState<TaskPriority>('sedang');
  const [formDueAt, setFormDueAt] = useState('');
  const [formDueIsDateOnly, setFormDueIsDateOnly] = useState(true);
  const [formMilestoneId, setFormMilestoneId] = useState<string>('');

  const [formChecklist, setFormChecklist] = useState<{ id?: string; text: string; done: boolean }[]>([]);
  const [newChecklistText, setNewChecklistText] = useState('');

  const [savingTask, setSavingTask] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  const [showMilestoneConfirm, setShowMilestoneConfirm] = useState(false);
  const [confirmedMilestoneId, setConfirmedMilestoneId] = useState<string | null>(null);
  const [confirmedTaskTitle, setConfirmedTaskTitle] = useState('');
  const [payAccountId, setPayAccountId] = useState('');
  const [markingPaid, setMarkingPaid] = useState(false);

  const loadData = useCallback(async () => {
    setLoading(true);
    setLoadError(null);

    try {
      const { data: memberData, error: memberErr } = await supabase
        .from('workspace_members')
        .select('workspace_id')
        .limit(1)
        .single();

      if (memberErr) throw memberErr;
      if (!memberData) {
        setLoading(false);
        return;
      }

      const wsId = memberData.workspace_id;
      setWorkspaceId(wsId);

      const { data: accData } = await supabase
        .from('accounts')
        .select('id, name')
        .eq('workspace_id', wsId)
        .is('deleted_at', null)
        .order('sort_order');

      if (accData) {
        setAccounts(accData);
        if (accData.length > 0 && !payAccountId) {
          setPayAccountId(accData[0].id);
        }
      }

      const { data: projData } = await supabase
        .from('projects')
        .select('id, name, kind')
        .eq('workspace_id', wsId)
        .is('deleted_at', null)
        .order('name');

      if (projData) {
        setProjects(projData as unknown as ProjectOption[]);
      }

      const { data: payData } = await supabase
        .from('project_payments')
        .select('id, project_id, label, amount')
        .eq('workspace_id', wsId)
        .is('deleted_at', null);

      if (payData) {
        setMilestones(payData as unknown as PaymentOption[]);
      }

      const { data: taskData, error: taskErr } = await supabase
        .from('tasks')
        .select(`
          *,
          projects (name),
          task_checklist_items (*)
        `)
        .eq('workspace_id', wsId)
        .is('deleted_at', null)
        .order('created_at', { ascending: false });

      if (taskErr) throw taskErr;
      if (taskData) {
        const mapped = taskData.map((t: Record<string, unknown>) => ({
          ...(t as unknown as TaskItem),
          project_name: (t.projects as { name: string } | null)?.name || null,
          checklist_items: (t.task_checklist_items as ChecklistItem[]) || [],
        }));
        setTasks(mapped);
      }
    } catch (err: unknown) {
      setLoadError(err instanceof Error ? err.message : 'Gagal memuat daftar tugas.');
    } finally {
      setLoading(false);
    }
  }, [supabase, payAccountId]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  const handleToggleTask = async (task: TaskItem) => {
    const wasDone = task.status === 'done';

    setTasks((prev) =>
      prev.map((t) =>
        t.id === task.id
          ? {
              ...t,
              status: wasDone ? 'todo' : 'done',
              completed_at: wasDone ? null : new Date().toISOString(),
            }
          : t
      )
    );

    const { data: updatedTask, error } = await supabase.rpc('fn_complete_task', {
      p_task_id: task.id,
    });

    if (error) {
      loadData();
      return;
    }

    if (!wasDone && updatedTask && updatedTask.milestone_payment_id) {
      setConfirmedMilestoneId(updatedTask.milestone_payment_id);
      setConfirmedTaskTitle(task.title);
      setShowMilestoneConfirm(true);
    }
  };

  const handleChangeStatus = async (taskId: string, newStatus: TaskStatus) => {
    if (newStatus === 'done') {
      const task = tasks.find((t) => t.id === taskId);
      if (task) {
        handleToggleTask(task);
        return;
      }
    }

    setTasks((prev) =>
      prev.map((t) => (t.id === taskId ? { ...t, status: newStatus, completed_at: null } : t))
    );

    await supabase.from('tasks').update({ status: newStatus, completed_at: null }).eq('id', taskId);
  };

  const handleToggleChecklistItem = async (itemId: string, currentDone: boolean) => {
    await supabase.from('task_checklist_items').update({ done: !currentDone }).eq('id', itemId);
    loadData();
  };

  const handleConfirmMilestonePayment = async () => {
    if (!confirmedMilestoneId || !payAccountId) return;
    setMarkingPaid(true);

    await supabase.rpc('fn_mark_payment_paid', {
      p_payment_id: confirmedMilestoneId,
      p_account_id: payAccountId,
    });

    setMarkingPaid(false);
    setShowMilestoneConfirm(false);
    setConfirmedMilestoneId(null);
    loadData();
  };

  const resetForm = () => {
    setFormTitle('');
    setFormDescription('');
    setFormKind('pribadi');
    setFormProjectId('');
    setFormPriority('sedang');
    setFormDueAt('');
    setFormDueIsDateOnly(true);
    setFormMilestoneId('');
    setFormChecklist([]);
    setNewChecklistText('');
    setFormError(null);
  };

  const openCreateModal = () => {
    resetForm();
    setModalMode('create');
    setShowTaskModal(true);
  };

  const openEditModal = (task: TaskItem) => {
    setModalMode('edit');
    setEditingTaskId(task.id);
    setFormTitle(task.title);
    setFormDescription(task.description || '');
    setFormKind(task.kind);
    setFormProjectId(task.project_id || '');
    setFormPriority(task.priority);
    setFormDueAt(task.due_at ? task.due_at.split('T')[0] : '');
    setFormDueIsDateOnly(task.due_is_date_only);
    setFormMilestoneId(task.milestone_payment_id || '');
    setFormChecklist(task.checklist_items || []);
    setNewChecklistText('');
    setFormError(null);
    setShowTaskModal(true);
  };

  const handleDeleteTask = async (taskId: string) => {
    if (!confirm('Hapus tugas ini?')) return;
    await supabase.from('tasks').update({ deleted_at: new Date().toISOString() }).eq('id', taskId);
    loadData();
  };

  const handleSaveTask = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!workspaceId || !formTitle.trim()) return;

    setSavingTask(true);
    setFormError(null);

    const taskPayload = {
      workspace_id: workspaceId,
      title: formTitle.trim(),
      description: formDescription.trim() || null,
      kind: formKind,
      project_id: formProjectId || null,
      priority: formPriority,
      due_at: formDueAt ? new Date(formDueAt).toISOString() : null,
      due_is_date_only: formDueIsDateOnly,
      milestone_payment_id: formMilestoneId || null,
    };

    if (modalMode === 'create') {
      const { data: newTask, error } = await supabase
        .from('tasks')
        .insert(taskPayload)
        .select()
        .single();

      if (error) {
        setFormError(error.message);
        setSavingTask(false);
        return;
      }

      if (newTask && formChecklist.length > 0) {
        const checklistInserts = formChecklist.map((item, idx) => ({
          task_id: newTask.id,
          text: item.text,
          done: item.done,
          sort_order: idx + 1,
        }));
        await supabase.from('task_checklist_items').insert(checklistInserts);
      }
    } else if (modalMode === 'edit' && editingTaskId) {
      const { error } = await supabase
        .from('tasks')
        .update(taskPayload)
        .eq('id', editingTaskId);

      if (error) {
        setFormError(error.message);
        setSavingTask(false);
        return;
      }

      await supabase.from('task_checklist_items').delete().eq('task_id', editingTaskId);
      if (formChecklist.length > 0) {
        const checklistInserts = formChecklist.map((item, idx) => ({
          task_id: editingTaskId,
          text: item.text,
          done: item.done,
          sort_order: idx + 1,
        }));
        await supabase.from('task_checklist_items').insert(checklistInserts);
      }
    }

    setSavingTask(false);
    setShowTaskModal(false);
    loadData();
  };

  const handleAddChecklistDraft = () => {
    if (!newChecklistText.trim()) return;
    setFormChecklist([...formChecklist, { text: newChecklistText.trim(), done: false }]);
    setNewChecklistText('');
  };

  const filteredTasks = tasks.filter((t) => {
    if (filterKind !== 'all' && t.kind !== filterKind) return false;
    if (filterProject !== 'all' && t.project_id !== filterProject) return false;
    if (filterPriority !== 'all' && t.priority !== filterPriority) return false;
    if (searchQuery.trim() && !t.title.toLowerCase().includes(searchQuery.toLowerCase())) return false;
    return true;
  });

  return (
    <div className="space-y-6">
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-foreground">Agenda</h1>
          <p className="text-sm text-muted-foreground mt-0.5">
            Daftar tugas, papan alur kerja, checklist, dan milestone pembayaran
          </p>
        </div>

        <Button onClick={openCreateModal}>
          <Plus className="w-4 h-4" />
          <span>Tambah Tugas</span>
        </Button>
      </div>

      <AgendaSubNav />

      {/* Chip Filter Jenis Kegiatan & Segmented Tampilan */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-3">
        <div className="flex items-center gap-1.5 overflow-x-auto pb-1">
          <button
            type="button"
            onClick={() => setFilterKind('all')}
            className={`min-h-11 px-3.5 py-2 rounded-lg text-xs font-medium transition-colors border ${
              filterKind === 'all'
                ? 'bg-primary text-primary-foreground border-primary'
                : 'bg-card text-muted-foreground border-border hover:text-foreground'
            }`}
          >
            Semua Jenis
          </button>
          {(['intern', 'freelance', 'kuliah', 'pribadi'] as ActivityKind[]).map((k) => (
            <button
              key={k}
              type="button"
              onClick={() => setFilterKind(k)}
              className={`min-h-11 px-3.5 py-2 rounded-lg text-xs font-medium transition-colors border ${
                filterKind === k
                  ? 'bg-primary text-primary-foreground border-primary'
                  : 'bg-card text-muted-foreground border-border hover:text-foreground'
              }`}
            >
              {ACTIVITY_KIND_META[k].label}
            </button>
          ))}
        </div>

        <SegmentedControl
          ariaLabel="Mode Tampilan Tugas"
          value={viewMode}
          onChange={setViewMode}
          options={[
            { value: 'list', label: 'Daftar' },
            { value: 'kanban', label: 'Papan' },
          ]}
        />
      </div>

      {/* Filter Bar Tambahan */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
        <Input
          type="text"
          placeholder="Cari judul tugas..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
        />

        <Select
          value={filterProject}
          onChange={(e) => setFilterProject(e.target.value)}
        >
          <option value="all">Semua Kegiatan / Proyek</option>
          {projects.map((p) => (
            <option key={p.id} value={p.id}>
              {p.name}
            </option>
          ))}
        </Select>

        <Select
          value={filterPriority}
          onChange={(e) => setFilterPriority(e.target.value as TaskPriority | 'all')}
        >
          <option value="all">Semua Prioritas</option>
          <option value="tinggi">Prioritas Tinggi</option>
          <option value="sedang">Prioritas Sedang</option>
          <option value="rendah">Prioritas Rendah</option>
        </Select>
      </div>

      {loadError ? (
        <ErrorState message={loadError} onRetry={loadData} />
      ) : loading ? (
        <div className="space-y-3" aria-busy="true" aria-label="Memuat tugas">
          <Skeleton className="h-20 w-full" />
          <Skeleton className="h-20 w-full" />
          <Skeleton className="h-20 w-full" />
        </div>
      ) : viewMode === 'list' ? (
        filteredTasks.length === 0 ? (
          <EmptyState
            icon={<CheckSquare className="w-5 h-5" />}
            title="Belum ada tugas yang cocok"
            description="Buat tugas baru untuk mengatur prioritas pekerjaan dan tenggat waktu Anda."
            actionLabel="Tambah Tugas"
            onAction={openCreateModal}
          />
        ) : (
          <div className="space-y-2.5">
            {filteredTasks.map((t) => {
              const isDone = t.status === 'done';
              const pInfo = PRIORITY_VARIANT[t.priority];
              const isOverdue = t.due_at && new Date(t.due_at) < new Date() && !isDone;

              return (
                <Card
                  key={t.id}
                  className={isDone ? 'opacity-70 bg-muted/20' : ''}
                >
                  <CardContent className="p-4 flex items-start justify-between gap-3">
                    <div className="flex items-start gap-3 flex-1 min-w-0">
                      <button
                        type="button"
                        onClick={() => handleToggleTask(t)}
                        aria-label={isDone ? `Buka kembali ${t.title}` : `Selesaikan ${t.title}`}
                        className={`min-h-11 min-w-11 -m-2 inline-flex items-center justify-center rounded-lg transition-colors ${
                          isDone ? 'text-income' : 'text-muted-foreground hover:text-primary'
                        }`}
                      >
                        {isDone ? (
                          <CheckCircle2 className="w-5 h-5" />
                        ) : (
                          <Circle className="w-5 h-5" />
                        )}
                      </button>

                      <div className="space-y-1.5 flex-1 min-w-0">
                        <div className="flex items-center gap-2 flex-wrap">
                          <span
                            className={`font-semibold text-sm text-foreground ${
                              isDone ? 'line-through text-muted-foreground' : ''
                            }`}
                          >
                            {t.title}
                          </span>
                          <KindBadge kind={t.kind} />
                          <StatusBadge variant={pInfo.variant}>{pInfo.label}</StatusBadge>
                          {isOverdue && (
                            <StatusBadge variant="expense">Terlambat</StatusBadge>
                          )}
                          {t.milestone_payment_id && (
                            <StatusBadge variant="warning">Milestone</StatusBadge>
                          )}
                        </div>

                        {t.description && (
                          <p className="text-xs text-muted-foreground line-clamp-1">
                            {t.description}
                          </p>
                        )}

                        <div className="flex items-center gap-3 text-xs text-muted-foreground flex-wrap tabular-nums">
                          {t.project_name && (
                            <span className="flex items-center gap-1">
                              <Folder className="w-3.5 h-3.5" />
                              {t.project_name}
                            </span>
                          )}
                          {t.due_at && (
                            <span className="flex items-center gap-1">
                              <Clock className="w-3.5 h-3.5" />
                              Tenggat: {formatDateIndo(t.due_at)}
                            </span>
                          )}
                          {t.checklist_items && t.checklist_items.length > 0 && (
                            <span>
                              Checklist: {t.checklist_items.filter((c) => c.done).length}/{t.checklist_items.length}
                            </span>
                          )}
                        </div>

                        {t.checklist_items && t.checklist_items.length > 0 && (
                          <div className="pt-2 space-y-1">
                            {t.checklist_items.map((ci) => (
                              <button
                                key={ci.id}
                                type="button"
                                onClick={() => handleToggleChecklistItem(ci.id, ci.done)}
                                className="flex items-center gap-2 text-xs text-muted-foreground hover:text-foreground py-1"
                              >
                                <span
                                  className={`w-4 h-4 rounded border flex items-center justify-center ${
                                    ci.done ? 'bg-primary border-primary text-primary-foreground' : 'border-border'
                                  }`}
                                >
                                  {ci.done && <CheckSquare className="w-3 h-3" />}
                                </span>
                                <span className={ci.done ? 'line-through text-muted-foreground/60' : ''}>
                                  {ci.text}
                                </span>
                              </button>
                            ))}
                          </div>
                        )}
                      </div>
                    </div>

                    <div className="flex items-center gap-1 shrink-0">
                      <Button
                        type="button"
                        variant="ghost"
                        size="icon"
                        onClick={() => openEditModal(t)}
                        aria-label={`Ubah ${t.title}`}
                      >
                        <Edit2 className="w-4 h-4" />
                      </Button>
                      <Button
                        type="button"
                        variant="ghost"
                        size="icon"
                        onClick={() => handleDeleteTask(t.id)}
                        aria-label={`Hapus ${t.title}`}
                      >
                        <Trash2 className="w-4 h-4 text-muted-foreground hover:text-expense" />
                      </Button>
                    </div>
                  </CardContent>
                </Card>
              );
            })}
          </div>
        )
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {(['todo', 'doing', 'done'] as TaskStatus[]).map((colStatus) => {
            const colTitle =
              colStatus === 'todo'
                ? 'Akan Dikerjakan'
                : colStatus === 'doing'
                ? 'Sedang Dikerjakan'
                : 'Selesai';
            const colTasks = filteredTasks.filter((t) => t.status === colStatus);

            return (
              <Card
                key={colStatus}
                className="p-4 flex flex-col space-y-3 min-h-[400px]"
              >
                <div className="flex items-center justify-between pb-2 border-b border-border">
                  <h3 className="font-semibold text-xs tracking-wider text-foreground uppercase">
                    {colTitle} ({colTasks.length})
                  </h3>
                </div>

                <div className="space-y-2.5 flex-1 overflow-y-auto">
                  {colTasks.length === 0 ? (
                    <div className="p-6 text-center text-xs text-muted-foreground border border-dashed border-border rounded-lg">
                      Kosong
                    </div>
                  ) : (
                    colTasks.map((task) => {
                      const pInfo = PRIORITY_VARIANT[task.priority];

                      return (
                        <div
                          key={task.id}
                          className="p-3.5 rounded-lg border border-border bg-background space-y-2 text-xs"
                        >
                          <div className="flex items-center justify-between gap-2 flex-wrap">
                            <KindBadge kind={task.kind} />
                            <StatusBadge variant={pInfo.variant}>{pInfo.label}</StatusBadge>
                          </div>

                          <div className="font-semibold text-sm text-foreground">
                            {task.title}
                          </div>

                          {task.project_name && (
                            <div className="text-xs text-muted-foreground">
                              {task.project_name}
                            </div>
                          )}

                          {task.due_at && (
                            <div className="text-xs text-muted-foreground tabular-nums">
                              Tenggat: {formatDateIndo(task.due_at)}
                            </div>
                          )}

                          <div className="pt-2 border-t border-border flex items-center justify-between gap-2">
                            <Button
                              type="button"
                              variant="ghost"
                              size="sm"
                              onClick={() => openEditModal(task)}
                            >
                              Ubah
                            </Button>

                            <Select
                              value={task.status}
                              onChange={(e) => handleChangeStatus(task.id, e.target.value as TaskStatus)}
                              className="w-36 h-9 min-h-9 text-xs py-1"
                            >
                              <option value="todo">Akan Dikerjakan</option>
                              <option value="doing">Sedang Dikerjakan</option>
                              <option value="done">Selesai</option>
                            </Select>
                          </div>
                        </div>
                      );
                    })
                  )}
                </div>
              </Card>
            );
          })}
        </div>
      )}

      {/* Modal Tambah / Edit Tugas */}
      <Dialog
        open={showTaskModal}
        onClose={() => setShowTaskModal(false)}
        title={modalMode === 'create' ? 'Tambah Tugas Baru' : 'Ubah Tugas'}
      >
        <form onSubmit={handleSaveTask} className="space-y-4">
          {formError && (
            <div className="p-3 rounded-lg bg-expense/10 border border-expense/20 text-expense text-xs">
              {formError}
            </div>
          )}

          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">
              Judul Tugas
            </label>
            <Input
              type="text"
              required
              placeholder="Misal: Selesaikan Bab 3 Skripsi atau Implementasi UI"
              value={formTitle}
              onChange={(e) => setFormTitle(e.target.value)}
            />
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="text-xs font-medium text-foreground block mb-1.5">
                Jenis Kegiatan
              </label>
              <Select
                value={formKind}
                onChange={(e) => setFormKind(e.target.value as ActivityKind)}
              >
                <option value="pribadi">Pribadi</option>
                <option value="intern">Magang</option>
                <option value="freelance">Freelance</option>
                <option value="kuliah">Kuliah</option>
              </Select>
            </div>

            <div>
              <label className="text-xs font-medium text-foreground block mb-1.5">
                Prioritas
              </label>
              <Select
                value={formPriority}
                onChange={(e) => setFormPriority(e.target.value as TaskPriority)}
              >
                <option value="tinggi">Tinggi</option>
                <option value="sedang">Sedang</option>
                <option value="rendah">Rendah</option>
              </Select>
            </div>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div>
              <label className="text-xs font-medium text-foreground block mb-1.5">
                Hubungkan ke Kegiatan (Opsional)
              </label>
              <Select
                value={formProjectId}
                onChange={(e) => setFormProjectId(e.target.value)}
              >
                <option value="">(Tugas Lepas / Tanpa Kegiatan)</option>
                {projects.map((p) => (
                  <option key={p.id} value={p.id}>
                    {p.name} ({p.kind})
                  </option>
                ))}
              </Select>
            </div>

            <div>
              <label className="text-xs font-medium text-foreground block mb-1.5">
                Tenggat Waktu
              </label>
              <Input
                type="date"
                value={formDueAt}
                onChange={(e) => setFormDueAt(e.target.value)}
              />
            </div>
          </div>

          {formKind === 'freelance' && milestones.length > 0 && (
            <div>
              <label className="text-xs font-medium text-foreground block mb-1.5">
                Tautan Milestone Pembayaran (Opsional)
              </label>
              <Select
                value={formMilestoneId}
                onChange={(e) => setFormMilestoneId(e.target.value)}
              >
                <option value="">(Bukan Milestone Pembayaran)</option>
                {milestones
                  .filter((m) => !formProjectId || m.project_id === formProjectId)
                  .map((m) => (
                    <option key={m.id} value={m.id}>
                      {m.label}
                    </option>
                  ))}
              </Select>
            </div>
          )}

          <div className="space-y-2 pt-2 border-t border-border">
            <label className="text-xs font-medium text-foreground block">
              Checklist Pekerjaan
            </label>

            <div className="flex gap-2">
              <Input
                type="text"
                placeholder="Tambah butir checklist..."
                value={newChecklistText}
                onChange={(e) => setNewChecklistText(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter') {
                    e.preventDefault();
                    handleAddChecklistDraft();
                  }
                }}
              />
              <Button type="button" variant="secondary" onClick={handleAddChecklistDraft}>
                Tambah
              </Button>
            </div>

            {formChecklist.length > 0 && (
              <div className="space-y-1.5 max-h-36 overflow-y-auto">
                {formChecklist.map((item, idx) => (
                  <div
                    key={idx}
                    className="flex items-center justify-between p-2 rounded-lg bg-muted/40 border border-border text-xs"
                  >
                    <span className={item.done ? 'line-through text-muted-foreground' : 'text-foreground'}>
                      {item.text}
                    </span>
                    <button
                      type="button"
                      onClick={() => setFormChecklist(formChecklist.filter((_, i) => i !== idx))}
                      className="text-muted-foreground hover:text-expense p-1"
                    >
                      <X className="w-3.5 h-3.5" />
                    </button>
                  </div>
                ))}
              </div>
            )}
          </div>

          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">
              Catatan / Keterangan
            </label>
            <Input
              type="text"
              placeholder="Catatan tambahan..."
              value={formDescription}
              onChange={(e) => setFormDescription(e.target.value)}
            />
          </div>

          <div className="flex justify-end gap-2 pt-3 border-t border-border">
            <Button
              type="button"
              variant="secondary"
              onClick={() => setShowTaskModal(false)}
            >
              Batal
            </Button>
            <Button type="submit" disabled={savingTask}>
              {savingTask ? 'Menyimpan...' : 'Simpan Tugas'}
            </Button>
          </div>
        </form>
      </Dialog>

      {/* Modal Dialog Pelunasan Milestone */}
      <Dialog
        open={showMilestoneConfirm}
        onClose={() => {
          setShowMilestoneConfirm(false);
          setConfirmedMilestoneId(null);
        }}
        title="Konfirmasi Pelunasan Milestone"
        description={`Tugas "${confirmedTaskTitle}" terhubung ke milestone pembayaran. Catat sebagai pemasukan lunas sekarang?`}
      >
        <div className="space-y-4">
          <div>
            <label className="text-xs font-medium text-foreground block mb-1.5">
              Pilih Akun Penerima
            </label>
            <Select
              value={payAccountId}
              onChange={(e) => setPayAccountId(e.target.value)}
            >
              {accounts.map((acc) => (
                <option key={acc.id} value={acc.id}>
                  {acc.name}
                </option>
              ))}
            </Select>
          </div>

          <div className="flex justify-end gap-2 pt-3 border-t border-border">
            <Button
              type="button"
              variant="secondary"
              onClick={() => {
                setShowMilestoneConfirm(false);
                setConfirmedMilestoneId(null);
              }}
            >
              Nanti Saja
            </Button>
            <Button
              type="button"
              disabled={markingPaid}
              onClick={handleConfirmMilestonePayment}
            >
              {markingPaid ? 'Memproses...' : 'Tandai Lunas'}
            </Button>
          </div>
        </div>
      </Dialog>
    </div>
  );
}
