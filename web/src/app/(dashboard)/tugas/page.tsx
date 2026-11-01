'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';
import { formatDateIndo } from '@/lib/format';
import type { ActivityKind, TaskPriority, TaskStatus } from '@/types/database';
import {
  CheckSquare,
  LayoutGrid,
  List as ListIcon,
  Plus,
  Trash2,
  Edit2,
  CheckCircle2,
  Circle,
  AlertTriangle,
  Clock,
  Briefcase,
  Laptop,
  GraduationCap,
  User,
  X,
  PlusCircle,
  Folder
} from 'lucide-react';

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

const KIND_CONFIG: Record<ActivityKind, { label: string; icon: typeof User; color: string }> = {
  intern: { label: 'Magang', icon: Briefcase, color: 'text-blue-500 bg-blue-500/10' },
  freelance: { label: 'Freelance', icon: Laptop, color: 'text-purple-500 bg-purple-500/10' },
  kuliah: { label: 'Kuliah', icon: GraduationCap, color: 'text-amber-500 bg-amber-500/10' },
  pribadi: { label: 'Pribadi', icon: User, color: 'text-emerald-500 bg-emerald-500/10' },
};

const PRIORITY_BADGE: Record<TaskPriority, { label: string; color: string }> = {
  tinggi: { label: 'Tinggi', color: 'bg-red-500/10 text-red-600 dark:text-red-400' },
  sedang: { label: 'Sedang', color: 'bg-amber-500/10 text-amber-600 dark:text-amber-400' },
  rendah: { label: 'Rendah', color: 'bg-muted text-muted-foreground' },
};

export default function TugasPage() {
  const supabase = createClient();
  const [workspaceId, setWorkspaceId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  // View mode: 'list' or 'kanban'
  const [viewMode, setViewMode] = useState<'list' | 'kanban'>('list');

  // Filters
  const [filterKind, setFilterKind] = useState<ActivityKind | 'all'>('all');
  const [filterProject, setFilterProject] = useState<string>('all');
  const [filterPriority, setFilterPriority] = useState<TaskPriority | 'all'>('all');
  const [searchQuery, setSearchQuery] = useState('');

  // Data
  const [tasks, setTasks] = useState<TaskItem[]>([]);
  const [projects, setProjects] = useState<ProjectOption[]>([]);
  const [milestones, setMilestones] = useState<PaymentOption[]>([]);
  const [accounts, setAccounts] = useState<AccountItem[]>([]);

  // Task Modal
  const [showTaskModal, setShowTaskModal] = useState(false);
  const [modalMode, setModalMode] = useState<'create' | 'edit'>('create');
  const [editingTaskId, setEditingTaskId] = useState<string | null>(null);

  // Form Fields
  const [formTitle, setFormTitle] = useState('');
  const [formDescription, setFormDescription] = useState('');
  const [formKind, setFormKind] = useState<ActivityKind>('pribadi');
  const [formProjectId, setFormProjectId] = useState<string>('');
  const [formPriority, setFormPriority] = useState<TaskPriority>('sedang');
  const [formDueAt, setFormDueAt] = useState('');
  const [formDueIsDateOnly, setFormDueIsDateOnly] = useState(true);
  const [formMilestoneId, setFormMilestoneId] = useState<string>('');

  // Checklist items inside modal
  const [formChecklist, setFormChecklist] = useState<{ id?: string; text: string; done: boolean }[]>([]);
  const [newChecklistText, setNewChecklistText] = useState('');

  const [savingTask, setSavingTask] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  // Dialog Milestone Confirmation
  const [showMilestoneConfirm, setShowMilestoneConfirm] = useState(false);
  const [confirmedMilestoneId, setConfirmedMilestoneId] = useState<string | null>(null);
  const [confirmedTaskTitle, setConfirmedTaskTitle] = useState('');
  const [payAccountId, setPayAccountId] = useState('');
  const [markingPaid, setMarkingPaid] = useState(false);

  const loadData = useCallback(async () => {
    setLoading(true);

    const { data: memberData } = await supabase
      .from('workspace_members')
      .select('workspace_id')
      .limit(1)
      .single();

    if (!memberData) {
      setLoading(false);
      return;
    }

    const wsId = memberData.workspace_id;
    setWorkspaceId(wsId);

    // Ambil akun untuk pelunasan
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

    // Ambil proyek
    const { data: projData } = await supabase
      .from('projects')
      .select('id, name, kind')
      .eq('workspace_id', wsId)
      .is('deleted_at', null)
      .order('name');

    if (projData) {
      setProjects(projData as unknown as ProjectOption[]);
    }

    // Ambil milestone payments
    const { data: payData } = await supabase
      .from('project_payments')
      .select('id, project_id, label, amount')
      .eq('workspace_id', wsId)
      .is('deleted_at', null);

    if (payData) {
      setMilestones(payData as unknown as PaymentOption[]);
    }

    // Ambil tasks beserta checklist items
    const { data: taskData } = await supabase
      .from('tasks')
      .select(`
        *,
        projects (name),
        task_checklist_items (*)
      `)
      .eq('workspace_id', wsId)
      .is('deleted_at', null)
      .order('created_at', { ascending: false });

    if (taskData) {
      const mapped = taskData.map((t: Record<string, unknown>) => ({
        ...(t as unknown as TaskItem),
        project_name: (t.projects as { name: string } | null)?.name || null,
        checklist_items: (t.task_checklist_items as ChecklistItem[]) || [],
      }));
      setTasks(mapped);
    }

    setLoading(false);
  }, [supabase, payAccountId]);

  useEffect(() => {
    loadData();
  }, [loadData]);

  // Toggle task complete / reopen via fn_complete_task
  const handleToggleTask = async (task: TaskItem) => {
    const wasDone = task.status === 'done';

    // Optimistic update
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

    // Jika baru selesai dan memiliki milestone, tawarkan pelunasan
    if (!wasDone && updatedTask && updatedTask.milestone_payment_id) {
      setConfirmedMilestoneId(updatedTask.milestone_payment_id);
      setConfirmedTaskTitle(task.title);
      setShowMilestoneConfirm(true);
    }
  };

  // Ubah status tugas di papan kanban
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

  // Toggle checklist item done
  const handleToggleChecklistItem = async (itemId: string, currentDone: boolean) => {
    await supabase.from('task_checklist_items').update({ done: !currentDone }).eq('id', itemId);
    loadData();
  };

  // Konfirmasi pelunasan milestone pembayaran
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

  // Reset form
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

  // Hapus tugas (soft delete)
  const handleDeleteTask = async (taskId: string) => {
    if (!confirm('Hapus tugas ini?')) return;
    await supabase.from('tasks').update({ deleted_at: new Date().toISOString() }).eq('id', taskId);
    loadData();
  };

  // Simpan tugas (Create / Edit)
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

      // Simpan checklist items
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

      // Sinkronkan checklist: hapus lama dan masukkan baru
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

  // Tambah item ke daftar checklist di form
  const handleAddChecklistDraft = () => {
    if (!newChecklistText.trim()) return;
    setFormChecklist([...formChecklist, { text: newChecklistText.trim(), done: false }]);
    setNewChecklistText('');
  };

  // Filter tasks
  const filteredTasks = tasks.filter((t) => {
    if (filterKind !== 'all' && t.kind !== filterKind) return false;
    if (filterProject !== 'all' && t.project_id !== filterProject) return false;
    if (filterPriority !== 'all' && t.priority !== filterPriority) return false;
    if (searchQuery.trim() && !t.title.toLowerCase().includes(searchQuery.toLowerCase())) return false;
    return true;
  });

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Tugas</h1>
          <p className="text-sm text-muted-foreground mt-0.5">
            Daftar tugas, papan alur kerja, checklist, dan milestone pembayaran.
          </p>
        </div>

        <div className="flex items-center gap-2">
          {/* View mode toggle */}
          <div className="flex items-center border border-border rounded-md p-0.5 bg-card">
            <button
              type="button"
              onClick={() => setViewMode('list')}
              className={`p-1.5 rounded text-xs font-medium transition-colors ${
                viewMode === 'list' ? 'bg-muted text-foreground' : 'text-muted-foreground hover:text-foreground'
              }`}
            >
              <ListIcon className="w-3.5 h-3.5" />
            </button>
            <button
              type="button"
              onClick={() => setViewMode('kanban')}
              className={`p-1.5 rounded text-xs font-medium transition-colors ${
                viewMode === 'kanban' ? 'bg-muted text-foreground' : 'text-muted-foreground hover:text-foreground'
              }`}
            >
              <LayoutGrid className="w-3.5 h-3.5" />
            </button>
          </div>

          <button
            type="button"
            onClick={openCreateModal}
            className="flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium bg-foreground text-background rounded-md hover:bg-foreground/90 transition-colors"
          >
            <Plus className="w-3.5 h-3.5" />
            <span>Tambah Tugas</span>
          </button>
        </div>
      </div>

      {/* Bar Filter */}
      <div className="flex flex-wrap items-center gap-2">
        <input
          type="text"
          placeholder="Cari tugas..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          className="text-xs rounded-md border border-border bg-card px-3 py-1.5 text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-1 focus:ring-foreground w-48"
        />

        <select
          value={filterKind}
          onChange={(e) => setFilterKind(e.target.value as ActivityKind | 'all')}
          className="text-xs rounded-md border border-border bg-card px-2.5 py-1.5 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
        >
          <option value="all">Semua Jenis</option>
          <option value="intern">Magang</option>
          <option value="freelance">Freelance</option>
          <option value="kuliah">Kuliah</option>
          <option value="pribadi">Pribadi</option>
        </select>

        <select
          value={filterProject}
          onChange={(e) => setFilterProject(e.target.value)}
          className="text-xs rounded-md border border-border bg-card px-2.5 py-1.5 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
        >
          <option value="all">Semua Proyek</option>
          {projects.map((p) => (
            <option key={p.id} value={p.id}>
              {p.name}
            </option>
          ))}
        </select>

        <select
          value={filterPriority}
          onChange={(e) => setFilterPriority(e.target.value as TaskPriority | 'all')}
          className="text-xs rounded-md border border-border bg-card px-2.5 py-1.5 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
        >
          <option value="all">Semua Prioritas</option>
          <option value="tinggi">Tinggi</option>
          <option value="sedang">Sedang</option>
          <option value="rendah">Rendah</option>
        </select>
      </div>

      {/* Konten Tugas: Tampilan Daftar (List View) */}
      {viewMode === 'list' && (
        <div className="space-y-2">
          {loading ? (
            <div className="p-8 text-center text-xs text-muted-foreground border border-border rounded-lg bg-card">
              Memuat tugas...
            </div>
          ) : filteredTasks.length === 0 ? (
            <div className="p-8 text-center text-xs text-muted-foreground border border-dashed border-border rounded-lg">
              Belum ada tugas yang cocok dengan filter.
            </div>
          ) : (
            filteredTasks.map((t) => {
              const isDone = t.status === 'done';
              const cfg = KIND_CONFIG[t.kind];
              const pBadge = PRIORITY_BADGE[t.priority];
              const isOverdue = t.due_at && new Date(t.due_at) < new Date() && !isDone;

              return (
                <div
                  key={t.id}
                  className={`p-3.5 rounded-lg border transition-colors flex items-start justify-between gap-3 ${
                    isDone ? 'border-border/60 bg-muted/20 opacity-70' : 'border-border bg-card'
                  }`}
                >
                  <div className="flex items-start gap-3 flex-1 min-w-0">
                    <button
                      type="button"
                      onClick={() => handleToggleTask(t)}
                      className={`mt-0.5 transition-colors ${
                        isDone ? 'text-emerald-500' : 'text-muted-foreground hover:text-foreground'
                      }`}
                    >
                      {isDone ? (
                        <CheckCircle2 className="w-4 h-4" />
                      ) : (
                        <Circle className="w-4 h-4" />
                      )}
                    </button>

                    <div className="space-y-1 flex-1 min-w-0">
                      <div className="flex items-center gap-2 flex-wrap">
                        <span
                          className={`font-medium text-sm text-foreground ${
                            isDone ? 'line-through text-muted-foreground' : ''
                          }`}
                        >
                          {t.title}
                        </span>
                        <span className={`text-[10px] px-1.5 py-0.5 rounded font-medium ${cfg.color}`}>
                          {cfg.label}
                        </span>
                        <span className={`text-[10px] px-1.5 py-0.5 rounded font-medium ${pBadge.color}`}>
                          {pBadge.label}
                        </span>
                        {isOverdue && (
                          <span className="text-[10px] px-1.5 py-0.5 rounded font-medium bg-red-500/10 text-red-600 dark:text-red-400">
                            Terlambat
                          </span>
                        )}
                        {t.milestone_payment_id && (
                          <span className="text-[10px] px-1.5 py-0.5 rounded font-medium bg-purple-500/10 text-purple-600 dark:text-purple-400">
                            Milestone
                          </span>
                        )}
                      </div>

                      {t.description && (
                        <p className="text-xs text-muted-foreground line-clamp-1">
                          {t.description}
                        </p>
                      )}

                      <div className="flex items-center gap-3 text-xs text-muted-foreground">
                        {t.project_name && (
                          <span className="flex items-center gap-1">
                            <Folder className="w-3 h-3" />
                            {t.project_name}
                          </span>
                        )}
                        {t.due_at && (
                          <span className="flex items-center gap-1">
                            <Clock className="w-3 h-3" />
                            Tenggat: {formatDateIndo(t.due_at)}
                          </span>
                        )}
                        {t.checklist_items && t.checklist_items.length > 0 && (
                          <span>
                            Checklist: {t.checklist_items.filter((c) => c.done).length}/{t.checklist_items.length}
                          </span>
                        )}
                      </div>

                      {/* Checklist Items Accordion */}
                      {t.checklist_items && t.checklist_items.length > 0 && (
                        <div className="pt-2 space-y-1">
                          {t.checklist_items.map((ci) => (
                            <div
                              key={ci.id}
                              onClick={() => handleToggleChecklistItem(ci.id, ci.done)}
                              className="flex items-center gap-2 text-xs text-muted-foreground hover:text-foreground cursor-pointer"
                            >
                              <div
                                className={`w-3 h-3 rounded border flex items-center justify-center ${
                                  ci.done ? 'bg-foreground border-foreground text-background' : 'border-border'
                                }`}
                              >
                                {ci.done && <CheckSquare className="w-2.5 h-2.5" />}
                              </div>
                              <span className={ci.done ? 'line-through text-muted-foreground/60' : ''}>
                                {ci.text}
                              </span>
                            </div>
                          ))}
                        </div>
                      )}
                    </div>
                  </div>

                  <div className="flex items-center gap-1 shrink-0">
                    <button
                      type="button"
                      onClick={() => openEditModal(t)}
                      className="p-1 text-muted-foreground hover:text-foreground transition-colors"
                    >
                      <Edit2 className="w-3.5 h-3.5" />
                    </button>
                    <button
                      type="button"
                      onClick={() => handleDeleteTask(t.id)}
                      className="p-1 text-muted-foreground hover:text-expense transition-colors"
                    >
                      <Trash2 className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </div>
              );
            })
          )}
        </div>
      )}

      {/* Konten Tugas: Tampilan Papan Kanban */}
      {viewMode === 'kanban' && (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {(['todo', 'doing', 'done'] as TaskStatus[]).map((colStatus) => {
            const colTitle = colStatus === 'todo' ? 'Akan Dikerjakan' : colStatus === 'doing' ? 'Sedang Dikerjakan' : 'Selesai';
            const colTasks = filteredTasks.filter((t) => t.status === colStatus);

            return (
              <div
                key={colStatus}
                className="p-3.5 rounded-lg border border-border bg-card flex flex-col space-y-3 min-h-[400px]"
              >
                <div className="flex items-center justify-between pb-2 border-b border-border">
                  <h3 className="font-semibold text-xs tracking-tight text-foreground uppercase">
                    {colTitle} ({colTasks.length})
                  </h3>
                </div>

                <div className="space-y-2 flex-1 overflow-y-auto">
                  {colTasks.length === 0 ? (
                    <div className="p-4 text-center text-xs text-muted-foreground border border-dashed border-border rounded-md">
                      Kosong
                    </div>
                  ) : (
                    colTasks.map((task) => {
                      const cfg = KIND_CONFIG[task.kind];
                      const pBadge = PRIORITY_BADGE[task.priority];

                      return (
                        <div
                          key={task.id}
                          className="p-3 rounded-lg border border-border bg-background shadow-xs space-y-2 text-xs"
                        >
                          <div className="flex items-center justify-between">
                            <span className={`text-[10px] px-1.5 py-0.5 rounded font-medium ${cfg.color}`}>
                              {cfg.label}
                            </span>
                            <span className={`text-[10px] px-1.5 py-0.5 rounded font-medium ${pBadge.color}`}>
                              {pBadge.label}
                            </span>
                          </div>

                          <div className="font-medium text-foreground">
                            {task.title}
                          </div>

                          {task.project_name && (
                            <div className="text-[11px] text-muted-foreground">
                              {task.project_name}
                            </div>
                          )}

                          {task.checklist_items && task.checklist_items.length > 0 && (
                            <div className="text-[11px] text-muted-foreground">
                              Checklist: {task.checklist_items.filter((c) => c.done).length}/{task.checklist_items.length}
                            </div>
                          )}

                          {/* Action pindah kolom kanban */}
                          <div className="pt-2 border-t border-border flex items-center justify-between">
                            <button
                              type="button"
                              onClick={() => openEditModal(task)}
                              className="text-[11px] text-muted-foreground hover:text-foreground"
                            >
                              Edit
                            </button>

                            <select
                              value={task.status}
                              onChange={(e) => handleChangeStatus(task.id, e.target.value as TaskStatus)}
                              className="text-[10px] rounded border border-border bg-muted/40 px-1.5 py-0.5 text-foreground"
                            >
                              <option value="todo">Todo</option>
                              <option value="doing">Doing</option>
                              <option value="done">Done</option>
                            </select>
                          </div>
                        </div>
                      );
                    })
                  )}
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Modal Tambah / Edit Tugas */}
      {showTaskModal && (
        <div className="fixed inset-0 z-50 bg-background/80 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
          <form
            onSubmit={handleSaveTask}
            className="bg-card border border-border rounded-lg shadow-lg max-w-lg w-full p-6 space-y-4 my-8"
          >
            <div className="flex items-center justify-between">
              <h3 className="font-semibold text-base text-foreground">
                {modalMode === 'create' ? 'Tambah Tugas Baru' : 'Edit Tugas'}
              </h3>
              <button
                type="button"
                onClick={() => setShowTaskModal(false)}
                className="text-muted-foreground hover:text-foreground"
              >
                <X className="w-4 h-4" />
              </button>
            </div>

            {formError && (
              <div className="p-3 rounded bg-red-500/10 border border-red-500/20 text-red-600 dark:text-red-400 text-xs">
                {formError}
              </div>
            )}

            <div className="space-y-3">
              <div>
                <label className="text-xs font-medium text-foreground block mb-1">
                  Judul Tugas
                </label>
                <input
                  type="text"
                  required
                  placeholder="Misal: Selesaikan Bab 3 Skripsi atau Implementasi UI"
                  value={formTitle}
                  onChange={(e) => setFormTitle(e.target.value)}
                  className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
                />
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">
                    Jenis Kegiatan
                  </label>
                  <select
                    value={formKind}
                    onChange={(e) => setFormKind(e.target.value as ActivityKind)}
                    className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
                  >
                    <option value="pribadi">Pribadi</option>
                    <option value="intern">Magang</option>
                    <option value="freelance">Freelance</option>
                    <option value="kuliah">Kuliah</option>
                  </select>
                </div>

                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">
                    Prioritas
                  </label>
                  <select
                    value={formPriority}
                    onChange={(e) => setFormPriority(e.target.value as TaskPriority)}
                    className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
                  >
                    <option value="tinggi">Tinggi</option>
                    <option value="sedang">Sedang</option>
                    <option value="rendah">Rendah</option>
                  </select>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">
                    Hubungkan ke Proyek (Opsional)
                  </label>
                  <select
                    value={formProjectId}
                    onChange={(e) => setFormProjectId(e.target.value)}
                    className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
                  >
                    <option value="">(Tugas Lepas / Tanpa Proyek)</option>
                    {projects.map((p) => (
                      <option key={p.id} value={p.id}>
                        {p.name} ({p.kind})
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">
                    Tenggat Waktu
                  </label>
                  <input
                    type="date"
                    value={formDueAt}
                    onChange={(e) => setFormDueAt(e.target.value)}
                    className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
                  />
                </div>
              </div>

              {/* Tautan Milestone Pembayaran (khusus proyek freelance) */}
              {formKind === 'freelance' && milestones.length > 0 && (
                <div>
                  <label className="text-xs font-medium text-foreground block mb-1">
                    Tautan Milestone Pembayaran (Opsional)
                  </label>
                  <select
                    value={formMilestoneId}
                    onChange={(e) => setFormMilestoneId(e.target.value)}
                    className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
                  >
                    <option value="">(Bukan Milestone Pembayaran)</option>
                    {milestones
                      .filter((m) => !formProjectId || m.project_id === formProjectId)
                      .map((m) => (
                        <option key={m.id} value={m.id}>
                          {m.label}
                        </option>
                      ))}
                  </select>
                </div>
              )}

              {/* Checklist Sub-items */}
              <div className="space-y-2 pt-2 border-t border-border">
                <label className="text-xs font-medium text-foreground block">
                  Checklist Pekerjaan
                </label>

                <div className="flex gap-2">
                  <input
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
                    className="flex-1 text-xs rounded-md border border-border bg-background px-3 py-1.5 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
                  />
                  <button
                    type="button"
                    onClick={handleAddChecklistDraft}
                    className="px-2.5 py-1.5 text-xs bg-muted text-foreground hover:bg-muted/80 rounded-md transition-colors"
                  >
                    Tambah
                  </button>
                </div>

                {formChecklist.length > 0 && (
                  <div className="space-y-1.5 max-h-36 overflow-y-auto">
                    {formChecklist.map((item, idx) => (
                      <div
                        key={idx}
                        className="flex items-center justify-between p-2 rounded bg-muted/30 border border-border/50 text-xs"
                      >
                        <span className={item.done ? 'line-through text-muted-foreground' : 'text-foreground'}>
                          {item.text}
                        </span>
                        <button
                          type="button"
                          onClick={() => setFormChecklist(formChecklist.filter((_, i) => i !== idx))}
                          className="text-muted-foreground hover:text-expense"
                        >
                          <X className="w-3.5 h-3.5" />
                        </button>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              <div>
                <label className="text-xs font-medium text-foreground block mb-1">
                  Catatan / Keterangan
                </label>
                <textarea
                  rows={2}
                  value={formDescription}
                  onChange={(e) => setFormDescription(e.target.value)}
                  className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
                />
              </div>
            </div>

            <div className="flex justify-end gap-2 pt-2 border-t border-border">
              <button
                type="button"
                onClick={() => setShowTaskModal(false)}
                className="px-3 py-1.5 text-xs font-medium border border-border rounded-md hover:bg-muted text-muted-foreground transition-colors"
              >
                Batal
              </button>
              <button
                type="submit"
                disabled={savingTask}
                className="px-3 py-1.5 text-xs font-medium bg-foreground text-background rounded-md hover:bg-foreground/90 transition-colors disabled:opacity-50"
              >
                {savingTask ? 'Menyimpan...' : 'Simpan Tugas'}
              </button>
            </div>
          </form>
        </div>
      )}

      {/* Modal Dialog Pelunasan Milestone saat Tugas Selesai */}
      {showMilestoneConfirm && (
        <div className="fixed inset-0 z-50 bg-background/80 backdrop-blur-sm flex items-center justify-center p-4">
          <div className="bg-card border border-border rounded-lg shadow-lg max-w-md w-full p-6 space-y-4">
            <h3 className="font-semibold text-base text-foreground">
              Konfirmasi Pelunasan Milestone
            </h3>
            <p className="text-xs text-muted-foreground">
              Tugas &ldquo;{confirmedTaskTitle}&rdquo; merupakan bagian dari milestone pembayaran.
              Apakah Anda ingin mencatat pembayaran ini sebagai pemasukan lunas sekarang?
            </p>

            <div className="space-y-2">
              <label className="text-xs font-medium text-foreground block">
                Pilih Akun Penerima
              </label>
              <select
                value={payAccountId}
                onChange={(e) => setPayAccountId(e.target.value)}
                className="w-full text-sm rounded-md border border-border bg-background px-3 py-2 text-foreground focus:outline-none focus:ring-1 focus:ring-foreground"
              >
                {accounts.map((acc) => (
                  <option key={acc.id} value={acc.id}>
                    {acc.name}
                  </option>
                ))}
              </select>
            </div>

            <div className="flex justify-end gap-2 pt-2">
              <button
                type="button"
                onClick={() => {
                  setShowMilestoneConfirm(false);
                  setConfirmedMilestoneId(null);
                }}
                className="px-3 py-1.5 text-xs font-medium border border-border rounded-md hover:bg-muted text-muted-foreground transition-colors"
              >
                Nanti Saja
              </button>
              <button
                type="button"
                disabled={markingPaid}
                onClick={handleConfirmMilestonePayment}
                className="px-3 py-1.5 text-xs font-medium bg-foreground text-background rounded-md hover:bg-foreground/90 transition-colors disabled:opacity-50"
              >
                {markingPaid ? 'Memproses...' : 'Tandai Lunas'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
