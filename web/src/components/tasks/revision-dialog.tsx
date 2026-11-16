'use client';

import React, { useEffect, useState } from 'react';
import { RotateCcw } from 'lucide-react';
import { Button, Dialog } from '@/components/ui';
import type { TaskRecord } from './types';

interface RevisionDialogProps {
  open: boolean;
  task: TaskRecord | null;
  submitting?: boolean;
  onClose: () => void;
  onConfirm: (note: string) => Promise<void> | void;
}

export function RevisionDialog({
  open,
  task,
  submitting = false,
  onClose,
  onConfirm,
}: RevisionDialogProps) {
  const [note, setNote] = useState('');
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (open) {
      setNote('');
      setError(null);
    }
  }, [open, task?.id]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const trimmed = note.trim();
    if (!trimmed) {
      setError('Catatan alasan revisi wajib diisi sebelum memindahkan tugas.');
      return;
    }
    setError(null);
    await onConfirm(trimmed);
  };

  return (
    <Dialog
      open={open}
      onClose={onClose}
      title="Pindahkan ke Status Revisi"
      description={
        task
          ? `Jelaskan bagian yang perlu diperbaiki untuk "${task.title}".`
          : 'Masukkan alasan perubahan status ke Revisi.'
      }
    >
      <form onSubmit={handleSubmit} className="space-y-4">
        {task && task.revision_count > 0 && (
          <div className="rounded-md border border-warning-border bg-warning-subtle px-3 py-2 text-xs text-warning">
            <span className="font-semibold tabular-nums">
              Revisi ke-{task.revision_count + 1}
            </span>
            {task.latest_revision_note && (
              <span className="block mt-0.5 text-foreground/80">
                Catatan sebelumnya: {task.latest_revision_note}
              </span>
            )}
          </div>
        )}

        <div>
          <label
            htmlFor="revision-note-input"
            className="mb-1.5 flex items-center gap-1.5 text-xs font-semibold text-foreground"
          >
            <RotateCcw className="h-3.5 w-3.5 text-warning" aria-hidden="true" />
            <span>Catatan Alasan Revisi (Wajib)</span>
          </label>
          <textarea
            id="revision-note-input"
            rows={4}
            required
            autoFocus
            maxLength={1000}
            value={note}
            onChange={(e) => {
              setNote(e.target.value);
              if (error) setError(null);
            }}
            placeholder="Contoh: Tambahkan penanganan retry webhook saat timeout dan perbarui unit test."
            className="w-full rounded-md border border-border bg-card px-3 py-2 text-sm text-foreground placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary"
          />
          <div className="mt-1 flex items-center justify-between text-[11px] text-muted-foreground tabular-nums">
            <span>Akan dicatat ke riwayat status dan penghitung revisi.</span>
            <span>{note.trim().length}/1000</span>
          </div>
          {error && (
            <p role="alert" className="mt-1.5 text-xs font-medium text-expense">
              {error}
            </p>
          )}
        </div>

        <div className="flex items-center justify-end gap-2 border-t border-border pt-3">
          <Button type="button" variant="outline" onClick={onClose} disabled={submitting}>
            Batal
          </Button>
          <Button type="submit" variant="primary" disabled={submitting}>
            {submitting ? 'Memindahkan...' : 'Pindahkan ke Revisi'}
          </Button>
        </div>
      </form>
    </Dialog>
  );
}
