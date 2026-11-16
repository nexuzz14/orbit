'use client';

import React, { useMemo, useRef, useState } from 'react';
import {
  ArrowRight,
  CheckCircle2,
  Circle,
  Download,
  File as FileIcon,
  GitBranch,
  History,
  Link2,
  ListChecks,
  MessageSquare,
  Paperclip,
  Pencil,
  Plus,
  Trash2,
  Upload,
} from 'lucide-react';
import { formatDateIndo } from '@/lib/format';
import {
  ALLOWED_ATTACHMENT_MIMES,
  computeTaskProgress,
  formatFileSize,
  MAX_ATTACHMENT_BYTES,
} from '@/lib/task-v2';
import type { TaskStatus } from '@/types/database';
import {
  BlockContainer,
  Button,
  Input,
  Select,
  TaskStatusBadge,
  cn,
} from '@/components/ui';
import type {
  AttachmentItem,
  ChecklistItemRecord,
  EntityLinkItem,
  TaskCommentItem,
  TaskRecord,
  TaskStatusHistoryItem,
} from './types';

export interface LinkTargetOption {
  id: string;
  label: string;
  subtitle?: string;
}

export type EntityTargetType = 'project' | 'event' | 'transaction' | 'bill' | 'task';
export type EntityRelationType =
  | 'related'
  | 'blocks'
  | 'blocked_by'
  | 'funded_by'
  | 'derived_from';

const TARGET_TYPE_LABELS: Record<EntityTargetType, string> = {
  project: 'Proyek',
  event: 'Jadwal',
  transaction: 'Transaksi',
  bill: 'Tagihan',
  task: 'Tugas',
};

const RELATION_LABELS: Record<EntityRelationType, string> = {
  related: 'Terkait',
  blocks: 'Memblokir',
  blocked_by: 'Diblokir oleh',
  funded_by: 'Didanai oleh',
  derived_from: 'Turunan dari',
};

/* -------------------------------------------------------------------------- */
/* Checklist Block                                                             */
/* -------------------------------------------------------------------------- */

export function TaskChecklistSection({
  items,
  onAddItem,
  onToggleItem,
  onDeleteItem,
}: {
  items: ChecklistItemRecord[];
  onAddItem: (text: string) => Promise<void>;
  onToggleItem: (item: ChecklistItemRecord) => Promise<void>;
  onDeleteItem: (itemId: string) => Promise<void>;
}) {
  const [draftText, setDraftText] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const doneCount = items.filter((item) => item.done).length;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const clean = draftText.trim();
    if (!clean || submitting) return;
    setSubmitting(true);
    try {
      await onAddItem(clean);
      setDraftText('');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <BlockContainer
      title={`Checklist (${doneCount}/${items.length})`}
      action={
        <ListChecks className="h-4 w-4 text-muted-foreground" strokeWidth={1.75} aria-hidden="true" />
      }
    >
      {items.length > 0 ? (
        <ul className="space-y-1.5 mb-3">
          {items.map((item) => (
            <li
              key={item.id}
              className="group flex items-center justify-between gap-2 rounded-md border border-transparent px-1.5 py-1 hover:border-border hover:bg-subtle/60"
            >
              <button
                type="button"
                onClick={() => void onToggleItem(item)}
                className="flex flex-1 min-w-0 items-center gap-2 text-left text-sm min-h-9"
              >
                {item.done ? (
                  <CheckCircle2
                    className="h-4 w-4 shrink-0 text-income"
                    strokeWidth={1.75}
                    aria-hidden="true"
                  />
                ) : (
                  <Circle
                    className="h-4 w-4 shrink-0 text-muted-foreground"
                    strokeWidth={1.75}
                    aria-hidden="true"
                  />
                )}
                <span
                  className={cn(
                    'truncate',
                    item.done && 'line-through text-muted-foreground'
                  )}
                >
                  {item.text}
                </span>
              </button>
              <button
                type="button"
                onClick={() => void onDeleteItem(item.id)}
                className="inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-md text-muted-foreground opacity-75 hover:bg-expense-subtle hover:text-expense hover:opacity-100"
                aria-label={`Hapus item ${item.text}`}
              >
                <Trash2 className="h-3.5 w-3.5" strokeWidth={1.75} />
              </button>
            </li>
          ))}
        </ul>
      ) : (
        <p className="mb-3 text-xs text-muted-foreground">
          Belum ada item checklist. Tambah langkah agar progres dihitung otomatis.
        </p>
      )}

      <form onSubmit={handleSubmit} className="flex gap-2">
        <Input
          value={draftText}
          onChange={(e) => setDraftText(e.target.value)}
          placeholder="Tambah item checklist..."
          aria-label="Item checklist baru"
        />
        <Button type="submit" size="sm" variant="outline" disabled={submitting || !draftText.trim()}>
          <Plus className="h-4 w-4" strokeWidth={1.75} />
          Tambah
        </Button>
      </form>
    </BlockContainer>
  );
}

/* -------------------------------------------------------------------------- */
/* Nested Subtasks Block                                                       */
/* -------------------------------------------------------------------------- */

export function TaskSubtasksSection({
  subtasks,
  schemaSupported,
  onAddSubtask,
  onToggleSubtaskDone,
  onOpenSubtask,
}: {
  subtasks: TaskRecord[];
  schemaSupported: boolean;
  onAddSubtask: (title: string) => Promise<void>;
  onToggleSubtaskDone: (subtask: TaskRecord) => Promise<void>;
  onOpenSubtask: (subtaskId: string) => void;
}) {
  const [title, setTitle] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const doneCount = subtasks.filter((st) => st.status === 'done').length;

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const clean = title.trim();
    if (!clean || submitting) return;
    setSubmitting(true);
    try {
      await onAddSubtask(clean);
      setTitle('');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <BlockContainer
      title={`Subtugas (${doneCount}/${subtasks.length})`}
      action={
        <GitBranch className="h-4 w-4 text-muted-foreground" strokeWidth={1.75} aria-hidden="true" />
      }
    >
      {!schemaSupported ? (
        <p className="text-xs text-muted-foreground">
          Subtugas bertingkat menunggu migrasi v5.2 aktif di basis data.
        </p>
      ) : (
        <>
          {subtasks.length > 0 ? (
            <ul className="space-y-1.5 mb-3">
              {subtasks.map((st) => {
                const pct = computeTaskProgress({
                  status: st.status,
                  progressPercent: st.progress_percent,
                  checklistItems: st.checklist_items,
                }).percent;

                return (
                  <li
                    key={st.id}
                    className="flex items-center justify-between gap-2 rounded-md border border-border bg-subtle/40 px-2.5 py-1.5"
                  >
                    <button
                      type="button"
                      onClick={() => void onToggleSubtaskDone(st)}
                      className="inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-md hover:bg-hover"
                      aria-label={
                        st.status === 'done'
                          ? `Buka kembali subtugas ${st.title}`
                          : `Selesaikan subtugas ${st.title}`
                      }
                    >
                      {st.status === 'done' ? (
                        <CheckCircle2 className="h-4 w-4 text-income" strokeWidth={1.75} />
                      ) : (
                        <Circle className="h-4 w-4 text-muted-foreground" strokeWidth={1.75} />
                      )}
                    </button>

                    <button
                      type="button"
                      onClick={() => onOpenSubtask(st.id)}
                      className="flex flex-1 min-w-0 items-center justify-between gap-2 text-left min-h-9"
                    >
                      <span
                        className={cn(
                          'truncate text-sm font-medium text-foreground hover:text-primary',
                          st.status === 'done' && 'line-through text-muted-foreground'
                        )}
                      >
                        {st.title}
                      </span>
                      <span className="flex items-center gap-1.5 shrink-0">
                        <span className="text-[11px] text-muted-foreground tabular-nums">
                          {pct}%
                        </span>
                        <TaskStatusBadge status={st.status} compact />
                      </span>
                    </button>
                  </li>
                );
              })}
            </ul>
          ) : (
            <p className="mb-3 text-xs text-muted-foreground">
              Pecah pekerjaan besar menjadi subtugas terpisah dengan status masing-masing.
            </p>
          )}

          <form onSubmit={handleSubmit} className="flex gap-2">
            <Input
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="Tambah subtugas cepat..."
              aria-label="Judul subtugas baru"
            />
            <Button type="submit" size="sm" variant="outline" disabled={submitting || !title.trim()}>
              <Plus className="h-4 w-4" strokeWidth={1.75} />
              Tambah
            </Button>
          </form>
        </>
      )}
    </BlockContainer>
  );
}

/* -------------------------------------------------------------------------- */
/* Entity Links Block                                                          */
/* -------------------------------------------------------------------------- */

export function TaskEntityLinksSection({
  taskId,
  links,
  schemaSupported,
  targetsByType,
  onAddLink,
  onDeleteLink,
  onNavigateTarget,
}: {
  taskId: string;
  links: EntityLinkItem[];
  schemaSupported: boolean;
  targetsByType: Record<EntityTargetType, LinkTargetOption[]>;
  onAddLink: (params: {
    targetType: EntityTargetType;
    targetId: string;
    relationType: EntityRelationType;
  }) => Promise<void>;
  onDeleteLink: (linkId: string) => Promise<void>;
  onNavigateTarget: (targetType: string, targetId: string) => void;
}) {
  const [targetType, setTargetType] = useState<EntityTargetType>('project');
  const [relationType, setRelationType] = useState<EntityRelationType>('related');
  const [targetId, setTargetId] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const availableTargets = useMemo(() => {
    const raw = targetsByType[targetType] ?? [];
    if (targetType === 'task') {
      return raw.filter((opt) => opt.id !== taskId);
    }
    return raw;
  }, [targetsByType, targetType, taskId]);

  const resolveLabel = (type: string, id: string): string => {
    const list = targetsByType[type as EntityTargetType] ?? [];
    return list.find((item) => item.id === id)?.label ?? `${type} (${id.slice(0, 6)})`;
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!targetId || submitting) return;
    setSubmitting(true);
    try {
      await onAddLink({ targetType, targetId, relationType });
      setTargetId('');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <BlockContainer
      title={`Tautan Lintas Entitas (${links.length})`}
      action={<Link2 className="h-4 w-4 text-muted-foreground" strokeWidth={1.75} aria-hidden="true" />}
    >
      {!schemaSupported ? (
        <p className="text-xs text-muted-foreground">
          Tautan entitas akan aktif setelah migrasi v5.3 diterapkan pada basis data.
        </p>
      ) : (
        <>
          {links.length > 0 ? (
            <ul className="space-y-1.5 mb-3">
              {links.map((link) => {
                const isOutbound = link.source_type === 'task' && link.source_id === taskId;
                const peerType = isOutbound ? link.target_type : link.source_type;
                const peerId = isOutbound ? link.target_id : link.source_id;
                const typeLabel =
                  TARGET_TYPE_LABELS[peerType as EntityTargetType] ?? peerType;
                const relLabel =
                  RELATION_LABELS[link.relation_type as EntityRelationType] ??
                  link.relation_type;

                return (
                  <li
                    key={link.id}
                    className="flex items-center justify-between gap-2 rounded-md border border-border bg-subtle/40 px-2.5 py-1.5 text-xs"
                  >
                    <button
                      type="button"
                      onClick={() => onNavigateTarget(peerType, peerId)}
                      className="flex flex-1 min-w-0 items-center gap-2 text-left min-h-8"
                    >
                      <span className="rounded bg-surface px-1.5 py-0.5 text-[10px] font-medium text-muted-foreground border border-border shrink-0">
                        {relLabel} / {typeLabel}
                      </span>
                      <span className="truncate font-medium text-foreground hover:text-primary">
                        {resolveLabel(peerType, peerId)}
                      </span>
                    </button>
                    <button
                      type="button"
                      onClick={() => void onDeleteLink(link.id)}
                      className="inline-flex h-8 w-8 shrink-0 items-center justify-center rounded-md text-muted-foreground hover:bg-expense-subtle hover:text-expense"
                      aria-label="Lepas tautan entitas"
                    >
                      <Trash2 className="h-3.5 w-3.5" strokeWidth={1.75} />
                    </button>
                  </li>
                );
              })}
            </ul>
          ) : (
            <p className="mb-3 text-xs text-muted-foreground">
              Tautkan tugas ini dengan jadwal, transaksi, tagihan, proyek, atau tugas lain.
            </p>
          )}

          <form onSubmit={handleSubmit} className="space-y-2">
            <div className="grid grid-cols-2 gap-2">
              <Select
                aria-label="Jenis entitas tujuan"
                value={targetType}
                onChange={(e) => {
                  setTargetType(e.target.value as EntityTargetType);
                  setTargetId('');
                }}
              >
                <option value="project">Proyek</option>
                <option value="event">Jadwal</option>
                <option value="transaction">Transaksi</option>
                <option value="bill">Tagihan</option>
                <option value="task">Tugas Lain</option>
              </Select>

              <Select
                aria-label="Jenis relasi"
                value={relationType}
                onChange={(e) => setRelationType(e.target.value as EntityRelationType)}
              >
                <option value="related">Terkait</option>
                <option value="blocks">Memblokir</option>
                <option value="blocked_by">Diblokir oleh</option>
                <option value="funded_by">Didanai oleh</option>
                <option value="derived_from">Turunan dari</option>
              </Select>
            </div>

            <div className="flex gap-2">
              <Select
                aria-label="Pilih item tujuan"
                value={targetId}
                onChange={(e) => setTargetId(e.target.value)}
              >
                <option value="">
                  {availableTargets.length > 0
                    ? `Pilih ${TARGET_TYPE_LABELS[targetType]}...`
                    : `Belum ada data ${TARGET_TYPE_LABELS[targetType]}`}
                </option>
                {availableTargets.map((opt) => (
                  <option key={opt.id} value={opt.id}>
                    {opt.subtitle ? `${opt.label} (${opt.subtitle})` : opt.label}
                  </option>
                ))}
              </Select>
              <Button
                type="submit"
                size="sm"
                variant="outline"
                disabled={submitting || !targetId}
              >
                Tautkan
              </Button>
            </div>
          </form>
        </>
      )}
    </BlockContainer>
  );
}

/* -------------------------------------------------------------------------- */
/* Comments Thread Block                                                       */
/* -------------------------------------------------------------------------- */

export function TaskCommentsSection({
  comments,
  currentUserId,
  schemaSupported,
  onAddComment,
  onEditComment,
  onDeleteComment,
}: {
  comments: TaskCommentItem[];
  currentUserId: string | null;
  schemaSupported: boolean;
  onAddComment: (body: string) => Promise<void>;
  onEditComment: (commentId: string, body: string) => Promise<void>;
  onDeleteComment: (commentId: string) => Promise<void>;
}) {
  const [body, setBody] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editingBody, setEditingBody] = useState('');

  const handleAdd = async (e: React.FormEvent) => {
    e.preventDefault();
    const clean = body.trim();
    if (!clean || submitting) return;
    setSubmitting(true);
    try {
      await onAddComment(clean);
      setBody('');
    } finally {
      setSubmitting(false);
    }
  };

  const handleSaveEdit = async (commentId: string) => {
    const clean = editingBody.trim();
    if (!clean) return;
    await onEditComment(commentId, clean);
    setEditingId(null);
    setEditingBody('');
  };

  return (
    <BlockContainer
      title={`Komentar (${comments.length})`}
      action={
        <MessageSquare className="h-4 w-4 text-muted-foreground" strokeWidth={1.75} aria-hidden="true" />
      }
    >
      {!schemaSupported ? (
        <p className="text-xs text-muted-foreground">
          Thread komentar akan aktif setelah migrasi v5.3 diterapkan pada basis data.
        </p>
      ) : (
        <>
          {comments.length > 0 ? (
            <ul className="space-y-2.5 mb-3">
              {comments.map((comment) => {
                const isOwn = Boolean(currentUserId && comment.author_id === currentUserId);
                const isEditing = editingId === comment.id;

                return (
                  <li
                    key={comment.id}
                    className="rounded-md border border-border bg-subtle/40 px-3 py-2 text-xs"
                  >
                    <div className="flex items-center justify-between gap-2 mb-1">
                      <span className="font-medium text-muted-foreground tabular-nums">
                        {formatDateIndo(comment.created_at, 'Asia/Jakarta')}
                        {comment.updated_at !== comment.created_at && ' (diedit)'}
                      </span>
                      {isOwn && !isEditing && (
                        <div className="flex items-center gap-1">
                          <button
                            type="button"
                            onClick={() => {
                              setEditingId(comment.id);
                              setEditingBody(comment.body);
                            }}
                            className="inline-flex h-7 w-7 items-center justify-center rounded text-muted-foreground hover:bg-hover hover:text-foreground"
                            aria-label="Edit komentar"
                          >
                            <Pencil className="h-3 w-3" strokeWidth={1.75} />
                          </button>
                          <button
                            type="button"
                            onClick={() => void onDeleteComment(comment.id)}
                            className="inline-flex h-7 w-7 items-center justify-center rounded text-muted-foreground hover:bg-expense-subtle hover:text-expense"
                            aria-label="Hapus komentar"
                          >
                            <Trash2 className="h-3 w-3" strokeWidth={1.75} />
                          </button>
                        </div>
                      )}
                    </div>

                    {isEditing ? (
                      <div className="space-y-2">
                        <textarea
                          rows={2}
                          value={editingBody}
                          onChange={(e) => setEditingBody(e.target.value)}
                          className="w-full rounded-md border border-border bg-surface px-2.5 py-1.5 text-sm text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
                        />
                        <div className="flex justify-end gap-1.5">
                          <Button
                            type="button"
                            size="sm"
                            variant="ghost"
                            onClick={() => {
                              setEditingId(null);
                              setEditingBody('');
                            }}
                          >
                            Batal
                          </Button>
                          <Button
                            type="button"
                            size="sm"
                            onClick={() => void handleSaveEdit(comment.id)}
                          >
                            Simpan
                          </Button>
                        </div>
                      </div>
                    ) : (
                      <p className="whitespace-pre-wrap text-sm text-foreground leading-relaxed">
                        {comment.body}
                      </p>
                    )}
                  </li>
                );
              })}
            </ul>
          ) : (
            <p className="mb-3 text-xs text-muted-foreground">
              Belum ada komentar. Catat progres, kendala, atau keputusan di sini.
            </p>
          )}

          <form onSubmit={handleAdd} className="space-y-2">
            <textarea
              rows={2}
              value={body}
              onChange={(e) => setBody(e.target.value)}
              placeholder="Tulis komentar atau catatan progres..."
              aria-label="Tulis komentar"
              className="w-full rounded-md border border-border bg-surface px-3 py-2 text-sm text-foreground placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary focus-visible:border-primary resize-none"
            />
            <div className="flex justify-end">
              <Button type="submit" size="sm" disabled={submitting || !body.trim()}>
                {submitting ? 'Mengirim...' : 'Kirim Komentar'}
              </Button>
            </div>
          </form>
        </>
      )}
    </BlockContainer>
  );
}

/* -------------------------------------------------------------------------- */
/* Attachments Block                                                           */
/* -------------------------------------------------------------------------- */

export function TaskAttachmentsSection({
  attachments,
  uploading,
  errorMessage,
  onUploadFile,
  onDownloadAttachment,
  onDeleteAttachment,
}: {
  attachments: AttachmentItem[];
  uploading: boolean;
  errorMessage: string | null;
  onUploadFile: (file: File) => Promise<void>;
  onDownloadAttachment: (item: AttachmentItem) => Promise<void>;
  onDeleteAttachment: (item: AttachmentItem) => Promise<void>;
}) {
  const inputRef = useRef<HTMLInputElement | null>(null);
  const [validationError, setValidationError] = useState<string | null>(null);

  const handleFileChange = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file) return;

    if (!ALLOWED_ATTACHMENT_MIMES.has(file.type)) {
      setValidationError(
        'Format berkas tidak didukung. Gunakan PNG, JPG, WEBP, atau PDF.'
      );
      return;
    }
    if (file.size > MAX_ATTACHMENT_BYTES) {
      setValidationError('Ukuran berkas melebihi batas maksimal 10 MB.');
      return;
    }

    setValidationError(null);
    await onUploadFile(file);
  };

  const displayName = (item: AttachmentItem): string => {
    if (item.file_name) return item.file_name;
    const parts = item.storage_path.split('/');
    return parts[parts.length - 1] || 'Lampiran';
  };

  return (
    <BlockContainer
      title={`Lampiran (${attachments.length})`}
      action={
        <div className="flex items-center gap-2">
          <input
            ref={inputRef}
            type="file"
            accept="image/png,image/jpeg,image/webp,application/pdf"
            onChange={(e) => void handleFileChange(e)}
            className="hidden"
          />
          <Button
            type="button"
            size="sm"
            variant="outline"
            disabled={uploading}
            onClick={() => inputRef.current?.click()}
          >
            <Upload className="h-3.5 w-3.5" strokeWidth={1.75} />
            {uploading ? 'Mengunggah...' : 'Unggah'}
          </Button>
        </div>
      }
    >
      {(validationError || errorMessage) && (
        <div className="mb-3 rounded-md border border-warning-border bg-warning-subtle px-3 py-2 text-xs text-warning">
          {validationError || errorMessage}
        </div>
      )}

      {attachments.length > 0 ? (
        <ul className="space-y-1.5">
          {attachments.map((att) => (
            <li
              key={att.id}
              className="flex items-center justify-between gap-2 rounded-md border border-border bg-subtle/40 px-2.5 py-2 text-xs"
            >
              <div className="flex items-center gap-2 min-w-0">
                <Paperclip
                  className="h-3.5 w-3.5 shrink-0 text-muted-foreground"
                  strokeWidth={1.75}
                  aria-hidden="true"
                />
                <div className="min-w-0">
                  <p className="truncate font-medium text-foreground">{displayName(att)}</p>
                  <p className="text-[11px] text-muted-foreground tabular-nums">
                    {formatFileSize(att.size)} · {att.mime}
                  </p>
                </div>
              </div>
              <div className="flex items-center gap-1 shrink-0">
                <button
                  type="button"
                  onClick={() => void onDownloadAttachment(att)}
                  className="inline-flex h-8 w-8 items-center justify-center rounded-md text-muted-foreground hover:bg-hover hover:text-primary"
                  aria-label={`Unduh ${displayName(att)}`}
                >
                  <Download className="h-3.5 w-3.5" strokeWidth={1.75} />
                </button>
                <button
                  type="button"
                  onClick={() => void onDeleteAttachment(att)}
                  className="inline-flex h-8 w-8 items-center justify-center rounded-md text-muted-foreground hover:bg-expense-subtle hover:text-expense"
                  aria-label={`Hapus ${displayName(att)}`}
                >
                  <Trash2 className="h-3.5 w-3.5" strokeWidth={1.75} />
                </button>
              </div>
            </li>
          ))}
        </ul>
      ) : (
        <div className="flex items-center gap-2 text-xs text-muted-foreground">
          <FileIcon className="h-3.5 w-3.5 shrink-0" strokeWidth={1.75} aria-hidden="true" />
          <span>Belum ada berkas terlampir. Maksimal 10 MB (PNG, JPG, WEBP, PDF).</span>
        </div>
      )}
    </BlockContainer>
  );
}

/* -------------------------------------------------------------------------- */
/* Status History Block                                                        */
/* -------------------------------------------------------------------------- */

export function TaskHistorySection({
  history,
  schemaSupported,
}: {
  history: TaskStatusHistoryItem[];
  schemaSupported: boolean;
}) {
  return (
    <BlockContainer
      title={`Riwayat Status (${history.length})`}
      action={
        <History className="h-4 w-4 text-muted-foreground" strokeWidth={1.75} aria-hidden="true" />
      }
    >
      {!schemaSupported ? (
        <p className="text-xs text-muted-foreground">
          Linimasa perubahan status akan aktif setelah migrasi v5.2 diterapkan.
        </p>
      ) : history.length > 0 ? (
        <ol className="space-y-2.5">
          {history.map((entry) => (
            <li
              key={entry.id}
              className="rounded-md border border-border bg-subtle/40 px-3 py-2 text-xs"
            >
              <div className="flex flex-wrap items-center justify-between gap-2">
                <div className="flex items-center gap-1.5">
                  {entry.from_status ? (
                    <>
                      <TaskStatusBadge status={entry.from_status as TaskStatus} compact />
                      <ArrowRight className="h-3 w-3 text-muted-foreground" strokeWidth={1.75} />
                    </>
                  ) : (
                    <span className="text-[11px] font-medium text-muted-foreground">Dibuat:</span>
                  )}
                  <TaskStatusBadge status={entry.to_status as TaskStatus} compact />
                </div>
                <span className="text-[11px] text-muted-foreground tabular-nums">
                  {formatDateIndo(entry.created_at, 'Asia/Jakarta')}
                </span>
              </div>
              {entry.note && (
                <p className="mt-1.5 rounded bg-surface px-2 py-1 text-xs text-foreground border border-border">
                  {entry.note}
                </p>
              )}
            </li>
          ))}
        </ol>
      ) : (
        <p className="text-xs text-muted-foreground">
          Belum ada catatan perpindahan status pada tugas ini.
        </p>
      )}
    </BlockContainer>
  );
}
