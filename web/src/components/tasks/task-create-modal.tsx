'use client';

import { useEffect, useMemo, useState } from 'react';
import {
  FileText,
  Layers,
  ListChecks,
  Plus,
  Repeat,
  Tag,
  Trash2,
  X,
} from 'lucide-react';
import { createClient } from '@/lib/supabase/client';
import {
  parseRecurrenceRule,
  parseTemplateBlocks,
  parseTemplateChecklist,
  plainTextToTiptapDoc,
  serializeRecurrenceRule,
  type RecurrenceFreq,
} from '@/lib/task-v2';
import type { ActivityKind, TaskPriority } from '@/types/database';
import { Button, Dialog, Input, Select } from '@/components/ui/primitives';
import { isSchemaFeatureUnavailable, mapRawTaskRow } from './task-actions';
import type { PaymentOption, ProjectOption, TaskRecord, TaskTemplateItem } from './types';

interface TaskCreateModalProps {
  open: boolean;
  onClose: () => void;
  workspaceId: string;
  projects: ProjectOption[];
  payments: PaymentOption[];
  templates: TaskTemplateItem[];
  onCreated: (task: TaskRecord) => void;
  onDeleteTemplate?: (templateId: string) => Promise<void> | void;
  defaultProjectId?: string;
}

export function TaskCreateModal({
  open,
  onClose,
  workspaceId,
  projects,
  payments,
  templates,
  onCreated,
  onDeleteTemplate,
  defaultProjectId,
}: TaskCreateModalProps) {
  const supabase = useMemo(() => createClient(), []);

  const [selectedTemplateId, setSelectedTemplateId] = useState<string>('');
  const [title, setTitle] = useState('');
  const [kind, setKind] = useState<ActivityKind>('pribadi');
  const [priority, setPriority] = useState<TaskPriority>('sedang');
  const [projectId, setProjectId] = useState<string>('');
  const [milestonePaymentId, setMilestonePaymentId] = useState<string>('');
  const [dueDate, setDueDate] = useState<string>('');
  const [dueTime, setDueTime] = useState<string>('');
  const [estimateMinutes, setEstimateMinutes] = useState<string>('');
  const [recurrenceFreq, setRecurrenceFreq] = useState<RecurrenceFreq>('none');
  const [recurrenceInterval, setRecurrenceInterval] = useState<number>(1);
  const [description, setDescription] = useState<string>('');
  const [tagInput, setTagInput] = useState<string>('');
  const [tags, setTags] = useState<string[]>([]);
  const [checklistInput, setChecklistInput] = useState<string>('');
  const [checklists, setChecklists] = useState<string[]>([]);
  const [submitting, setSubmitting] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  useEffect(() => {
    if (!open) return;
    setSelectedTemplateId('');
    setTitle('');
    setKind('pribadi');
    setPriority('sedang');
    setProjectId(defaultProjectId ?? '');
    setMilestonePaymentId('');
    setDueDate('');
    setDueTime('');
    setEstimateMinutes('');
    setRecurrenceFreq('none');
    setRecurrenceInterval(1);
    setDescription('');
    setTagInput('');
    setTags([]);
    setChecklistInput('');
    setChecklists([]);
    setErrorMessage(null);
  }, [open, defaultProjectId]);

  const filteredPayments = useMemo(
    () => (projectId ? payments.filter((p) => p.project_id === projectId) : []),
    [payments, projectId]
  );

  const selectedTemplate = useMemo(
    () => templates.find((tpl) => tpl.id === selectedTemplateId) ?? null,
    [templates, selectedTemplateId]
  );

  const applyTemplate = (templateId: string) => {
    setSelectedTemplateId(templateId);
    const tpl = templates.find((item) => item.id === templateId);
    if (!tpl) return;

    const parsedBlocks = parseTemplateBlocks(tpl.blocks_json);
    const parsedChecklists = parseTemplateChecklist(tpl.checklist_json);
    const parsedRecurrence = parseRecurrenceRule(parsedBlocks.recurrenceRule);

    if (!title.trim()) {
      setTitle(tpl.name);
    }
    setKind(tpl.kind);
    setPriority(tpl.default_priority);
    setEstimateMinutes(
      tpl.default_estimate_minutes != null ? String(tpl.default_estimate_minutes) : ''
    );
    setTags(parsedBlocks.tags);
    setChecklists(parsedChecklists);
    setDescription(parsedBlocks.description ?? '');
    if (parsedRecurrence) {
      setRecurrenceFreq(parsedRecurrence.freq);
      setRecurrenceInterval(parsedRecurrence.interval);
    } else {
      setRecurrenceFreq('none');
      setRecurrenceInterval(1);
    }
  };

  const handleAddTag = () => {
    const clean = tagInput.trim().replace(/^#/, '');
    if (!clean) return;
    if (!tags.some((item) => item.toLowerCase() === clean.toLowerCase())) {
      setTags((prev) => [...prev, clean]);
    }
    setTagInput('');
  };

  const handleAddChecklist = () => {
    const clean = checklistInput.trim();
    if (!clean) return;
    setChecklists((prev) => [...prev, clean]);
    setChecklistInput('');
  };

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault();
    const cleanTitle = title.trim();
    if (!cleanTitle) {
      setErrorMessage('Judul tugas wajib diisi.');
      return;
    }

    setSubmitting(true);
    setErrorMessage(null);

    try {
      let dueAt: string | null = null;
      let dueIsDateOnly = false;
      if (dueDate) {
        if (dueTime) {
          dueAt = new Date(`${dueDate}T${dueTime}:00+07:00`).toISOString();
          dueIsDateOnly = false;
        } else {
          dueAt = new Date(`${dueDate}T23:59:59+07:00`).toISOString();
          dueIsDateOnly = true;
        }
      }

      const parsedEstimate = estimateMinutes.trim() ? Number(estimateMinutes) : null;
      const safeEstimate =
        parsedEstimate != null && Number.isFinite(parsedEstimate) && parsedEstimate > 0
          ? Math.round(parsedEstimate)
          : null;

      const recurrenceRule = serializeRecurrenceRule(recurrenceFreq, recurrenceInterval);
      const cleanDescription = description.trim() || null;

      const selectedTplBlocks = selectedTemplate
        ? parseTemplateBlocks(selectedTemplate.blocks_json)
        : null;
      const descriptionBlocks =
        cleanDescription && selectedTplBlocks?.description === cleanDescription && selectedTplBlocks.doc
          ? selectedTplBlocks.doc
          : cleanDescription
          ? plainTextToTiptapDoc(cleanDescription)
          : null;

      const v2Payload = {
        workspace_id: workspaceId,
        project_id: projectId || null,
        milestone_payment_id: milestonePaymentId || null,
        kind,
        title: cleanTitle,
        description: cleanDescription,
        description_blocks: descriptionBlocks,
        priority,
        status: 'todo' as const,
        due_at: dueAt,
        due_is_date_only: dueIsDateOnly,
        estimate_minutes: safeEstimate,
        tags,
        recurrence_rule: recurrenceRule,
        progress_percent: 0,
      };

      const fullSelect =
        '*, projects(name), task_checklist_items(id, task_id, text, done, sort_order, created_at, updated_at)';

      let insertedRaw: Record<string, unknown> | null = null;
      const firstAttempt = await supabase
        .from('tasks')
        .insert(v2Payload)
        .select(fullSelect)
        .single();

      if (firstAttempt.error) {
        if (isSchemaFeatureUnavailable(firstAttempt.error)) {
          const corePayload = {
            workspace_id: workspaceId,
            project_id: projectId || null,
            milestone_payment_id: milestonePaymentId || null,
            kind,
            title: cleanTitle,
            description: cleanDescription,
            priority,
            status: 'todo' as const,
            due_at: dueAt,
            due_is_date_only: dueIsDateOnly,
            estimate_minutes: safeEstimate,
            tags,
          };
          const fallbackAttempt = await supabase
            .from('tasks')
            .insert(corePayload)
            .select(fullSelect)
            .single();
          if (fallbackAttempt.error) {
            throw fallbackAttempt.error;
          }
          insertedRaw = fallbackAttempt.data as unknown as Record<string, unknown>;
        } else {
          throw firstAttempt.error;
        }
      } else {
        insertedRaw = firstAttempt.data as unknown as Record<string, unknown>;
      }

      if (!insertedRaw) {
        throw new Error('Gagal membuat tugas baru.');
      }

      const taskRecord = mapRawTaskRow(insertedRaw);

      if (checklists.length > 0) {
        const checklistRows = checklists.map((text, idx) => ({
          task_id: taskRecord.id,
          text,
          done: false,
          sort_order: idx,
        }));
        const { data: insertedChecklist, error: checklistError } = await supabase
          .from('task_checklist_items')
          .insert(checklistRows)
          .select('id, task_id, text, done, sort_order, created_at, updated_at');

        if (!checklistError && insertedChecklist) {
          taskRecord.checklist_items = insertedChecklist.map((row) => ({
            id: row.id,
            task_id: row.task_id,
            text: row.text,
            done: row.done,
            sort_order: row.sort_order,
            created_at: row.created_at,
            updated_at: row.updated_at,
          }));
        }
      }

      onCreated(taskRecord);
      onClose();
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Gagal menyimpan tugas baru.';
      setErrorMessage(msg);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <Dialog
      open={open}
      onClose={onClose}
      title="Buat Tugas Baru"
      description="Mulai dari kosong atau gunakan template tersimpan lengkap dengan checklist dan pengulangan."
    >
      <form onSubmit={handleSubmit} className="space-y-4">
        {templates.length > 0 && (
          <div className="rounded-lg border border-border bg-subtle/60 p-3">
            <div className="flex items-center justify-between gap-2 mb-2">
              <span className="inline-flex items-center gap-1.5 text-xs font-medium text-muted-foreground">
                <FileText className="h-3.5 w-3.5" strokeWidth={1.75} />
                Gunakan Template ({templates.length})
              </span>
              {selectedTemplate && onDeleteTemplate && (
                <button
                  type="button"
                  onClick={() => void onDeleteTemplate(selectedTemplate.id)}
                  className="inline-flex items-center gap-1 text-[11px] font-medium text-danger hover:underline"
                >
                  <Trash2 className="h-3 w-3" strokeWidth={1.75} />
                  Hapus Template Ini
                </button>
              )}
            </div>
            <Select
              aria-label="Pilih template tugas"
              value={selectedTemplateId}
              onChange={(e) => applyTemplate(e.target.value)}
            >
              <option value="">Kosong (tanpa template)</option>
              {templates.map((tpl) => (
                <option key={tpl.id} value={tpl.id}>
                  {tpl.name} ({tpl.kind})
                </option>
              ))}
            </Select>
          </div>
        )}

        {errorMessage && (
          <div className="rounded-lg border border-expense-border bg-expense-subtle px-3 py-2 text-xs text-expense">
            {errorMessage}
          </div>
        )}

        <div>
          <label className="mb-1.5 block text-xs font-medium text-foreground">
            Judul Tugas *
          </label>
          <Input
            placeholder="Misal: Finalisasi API invoice klien A"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            autoFocus
            required
          />
        </div>

        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <div>
            <label className="mb-1.5 block text-xs font-medium text-foreground">
              Kategori Aktivitas
            </label>
            <Select
              aria-label="Kategori aktivitas"
              value={kind}
              onChange={(e) => setKind(e.target.value as ActivityKind)}
            >
              <option value="pribadi">Pribadi</option>
              <option value="kuliah">Kuliah</option>
              <option value="freelance">Freelance</option>
              <option value="intern">Intern</option>
            </Select>
          </div>

          <div>
            <label className="mb-1.5 block text-xs font-medium text-foreground">
              Prioritas
            </label>
            <Select
              aria-label="Prioritas tugas"
              value={priority}
              onChange={(e) => setPriority(e.target.value as TaskPriority)}
            >
              <option value="rendah">Rendah</option>
              <option value="sedang">Sedang</option>
              <option value="tinggi">Tinggi</option>
            </Select>
          </div>
        </div>

        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <div>
            <label className="mb-1.5 inline-flex items-center gap-1 text-xs font-medium text-foreground">
              <Layers className="h-3.5 w-3.5 text-muted-foreground" strokeWidth={1.75} />
              Proyek (Opsional)
            </label>
            <Select
              aria-label="Proyek tugas"
              value={projectId}
              onChange={(e) => {
                setProjectId(e.target.value);
                setMilestonePaymentId('');
              }}
            >
              <option value="">Tanpa Proyek</option>
              {projects.map((project) => (
                <option key={project.id} value={project.id}>
                  {project.name}
                </option>
              ))}
            </Select>
          </div>

          <div>
            <label className="mb-1.5 block text-xs font-medium text-foreground">
              Estimasi Durasi (Menit)
            </label>
            <Input
              type="number"
              min={5}
              step={5}
              placeholder="Contoh: 60"
              value={estimateMinutes}
              onChange={(e) => setEstimateMinutes(e.target.value)}
            />
          </div>
        </div>

        {projectId && filteredPayments.length > 0 && (
          <div>
            <label className="mb-1.5 block text-xs font-medium text-foreground">
              Tautkan Termin Pembayaran (Opsional)
            </label>
            <Select
              aria-label="Termin pembayaran"
              value={milestonePaymentId}
              onChange={(e) => setMilestonePaymentId(e.target.value)}
            >
              <option value="">Tidak ditautkan ke termin</option>
              {filteredPayments.map((payment) => (
                <option key={payment.id} value={payment.id}>
                  {payment.label}
                </option>
              ))}
            </Select>
          </div>
        )}

        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
          <div>
            <label className="mb-1.5 block text-xs font-medium text-foreground">
              Tenggat Tanggal
            </label>
            <Input
              type="date"
              value={dueDate}
              onChange={(e) => setDueDate(e.target.value)}
            />
          </div>

          <div>
            <label className="mb-1.5 block text-xs font-medium text-foreground">
              Jam Tenggat (Opsional)
            </label>
            <Input
              type="time"
              value={dueTime}
              onChange={(e) => setDueTime(e.target.value)}
              disabled={!dueDate}
            />
          </div>
        </div>

        <div className="rounded-lg border border-border bg-subtle/40 p-3 space-y-2">
          <label className="inline-flex items-center gap-1.5 text-xs font-medium text-foreground">
            <Repeat className="h-3.5 w-3.5 text-muted-foreground" strokeWidth={1.75} />
            Aturan Tugas Berulang
          </label>
          <div className="grid grid-cols-1 gap-2 sm:grid-cols-2">
            <Select
              aria-label="Frekuensi pengulangan"
              value={recurrenceFreq}
              onChange={(e) => setRecurrenceFreq(e.target.value as RecurrenceFreq)}
            >
              <option value="none">Tidak berulang</option>
              <option value="daily">Harian</option>
              <option value="weekly">Mingguan</option>
              <option value="monthly">Bulanan</option>
            </Select>

            {recurrenceFreq !== 'none' && (
              <div className="flex items-center gap-2">
                <span className="text-xs text-muted-foreground shrink-0">Setiap</span>
                <Input
                  type="number"
                  min={1}
                  max={90}
                  value={recurrenceInterval}
                  onChange={(e) =>
                    setRecurrenceInterval(Math.max(1, Number(e.target.value) || 1))
                  }
                  aria-label="Interval pengulangan"
                />
                <span className="text-xs text-muted-foreground shrink-0">
                  {recurrenceFreq === 'daily'
                    ? 'hari'
                    : recurrenceFreq === 'weekly'
                    ? 'minggu'
                    : 'bulan'}
                </span>
              </div>
            )}
          </div>
        </div>

        <div>
          <label className="mb-1.5 block text-xs font-medium text-foreground">
            Catatan Ringkas / Deskripsi
          </label>
          <textarea
            rows={3}
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="Tambahkan konteks singkat, link, atau kriteria selesai..."
            className="w-full rounded-md border border-border bg-surface px-3 py-2 text-sm text-foreground placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:border-primary resize-none"
          />
        </div>

        <div>
          <label className="mb-1.5 inline-flex items-center gap-1.5 text-xs font-medium text-foreground">
            <Tag className="h-3.5 w-3.5 text-muted-foreground" strokeWidth={1.75} />
            Tag
          </label>
          <div className="flex gap-2">
            <Input
              value={tagInput}
              onChange={(e) => setTagInput(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') {
                  e.preventDefault();
                  handleAddTag();
                }
              }}
              placeholder="Ketik tag lalu tekan Enter..."
            />
            <Button type="button" variant="outline" onClick={handleAddTag}>
              Tambah
            </Button>
          </div>
          {tags.length > 0 && (
            <div className="mt-2 flex flex-wrap gap-1.5">
              {tags.map((tag) => (
                <span
                  key={tag}
                  className="inline-flex items-center gap-1 rounded-md border border-border bg-subtle px-2 py-0.5 text-xs text-foreground"
                >
                  #{tag}
                  <button
                    type="button"
                    onClick={() => setTags((prev) => prev.filter((item) => item !== tag))}
                    className="text-muted-foreground hover:text-danger"
                    aria-label={`Hapus tag ${tag}`}
                  >
                    <X className="h-3 w-3" />
                  </button>
                </span>
              ))}
            </div>
          )}
        </div>

        <div>
          <label className="mb-1.5 inline-flex items-center gap-1.5 text-xs font-medium text-foreground">
            <ListChecks className="h-3.5 w-3.5 text-muted-foreground" strokeWidth={1.75} />
            Checklist Awal ({checklists.length})
          </label>
          <div className="flex gap-2">
            <Input
              value={checklistInput}
              onChange={(e) => setChecklistInput(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') {
                  e.preventDefault();
                  handleAddChecklist();
                }
              }}
              placeholder="Tambah langkah kerja..."
            />
            <Button type="button" variant="outline" onClick={handleAddChecklist}>
              <Plus className="h-4 w-4" strokeWidth={1.75} />
            </Button>
          </div>
          {checklists.length > 0 && (
            <ul className="mt-2 space-y-1">
              {checklists.map((item, idx) => (
                <li
                  key={`${item}-${idx}`}
                  className="flex items-center justify-between rounded-md border border-border bg-subtle/40 px-2.5 py-1.5 text-xs text-foreground"
                >
                  <span className="truncate">{item}</span>
                  <button
                    type="button"
                    onClick={() =>
                      setChecklists((prev) => prev.filter((_, i) => i !== idx))
                    }
                    className="ml-2 text-muted-foreground hover:text-danger"
                    aria-label={`Hapus item checklist ${item}`}
                  >
                    <X className="h-3.5 w-3.5" />
                  </button>
                </li>
              ))}
            </ul>
          )}
        </div>

        <div className="flex items-center justify-end gap-2 pt-2 border-t border-border">
          <Button type="button" variant="outline" onClick={onClose}>
            Batal
          </Button>
          <Button type="submit" disabled={submitting}>
            {submitting ? 'Menyimpan...' : 'Simpan Tugas'}
          </Button>
        </div>
      </form>
    </Dialog>
  );
}
