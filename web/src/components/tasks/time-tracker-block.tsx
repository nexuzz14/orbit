'use client';

import React, { useEffect, useMemo, useRef, useState } from 'react';
import {
  CheckSquare,
  Clock,
  Pause,
  Play,
  Plus,
  RotateCcw,
  Trash2,
} from 'lucide-react';
import { createClient } from '@/lib/supabase/client';
import { formatDateIndo } from '@/lib/format';
import { isSchemaFeatureUnavailable } from './task-actions';
import type { TaskTimeLogItem } from './types';
import { Button, Input, StatusBadge, cn } from '@/components/ui';

type TrackerMode = 'pomodoro' | 'stopwatch';
const POMODORO_SECONDS = 25 * 60;

function formatDurationClock(totalSeconds: number): string {
  const safe = Math.max(0, Math.floor(totalSeconds));
  const hrs = Math.floor(safe / 3600);
  const mins = Math.floor((safe % 3600) / 60);
  const secs = safe % 60;
  if (hrs > 0) {
    return `${String(hrs).padStart(2, '0')}:${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
  }
  return `${String(mins).padStart(2, '0')}:${String(secs).padStart(2, '0')}`;
}

function formatTotalMinutesSummary(totalSeconds: number): string {
  const totalMins = Math.round(totalSeconds / 60);
  const hrs = Math.floor(totalMins / 60);
  const rem = totalMins % 60;
  if (hrs === 0) return `${totalMins} mnt`;
  if (rem === 0) return `${hrs} jam`;
  return `${hrs}j ${rem}m`;
}

export function TimeTrackerBlock({
  taskId,
  workspaceId,
  estimateMinutes,
  logs,
  schemaAvailable,
  onReload,
}: {
  taskId: string;
  workspaceId: string;
  estimateMinutes: number | null;
  logs: TaskTimeLogItem[];
  schemaAvailable: boolean;
  onReload: () => Promise<void> | void;
}) {
  const supabase = useMemo(() => createClient(), []);

  const [trackerMode, setTrackerMode] = useState<TrackerMode>('pomodoro');
  const [running, setRunning] = useState(false);
  const [elapsedSeconds, setElapsedSeconds] = useState(0);
  const [startedAtIso, setStartedAtIso] = useState<string | null>(null);
  const [timerNote, setTimerNote] = useState('');

  const [manualMinutes, setManualMinutes] = useState('25');
  const [manualNote, setManualNote] = useState('');
  const [saving, setSaving] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [schemaBlocked, setSchemaBlocked] = useState(!schemaAvailable);

  const lastTickRef = useRef<number | null>(null);

  useEffect(() => {
    setSchemaBlocked(!schemaAvailable);
  }, [schemaAvailable]);

  useEffect(() => {
    setRunning(false);
    setElapsedSeconds(0);
    setStartedAtIso(null);
    lastTickRef.current = null;
  }, [taskId]);

  useEffect(() => {
    if (!running) {
      lastTickRef.current = null;
      return;
    }

    lastTickRef.current = Date.now();
    const interval = window.setInterval(() => {
      const now = Date.now();
      const prev = lastTickRef.current ?? now;
      const delta = Math.max(1, Math.round((now - prev) / 1000));
      lastTickRef.current = now;
      setElapsedSeconds((curr) => curr + delta);
    }, 1000);

    return () => window.clearInterval(interval);
  }, [running]);

  const totalLoggedSeconds = useMemo(
    () => logs.reduce((acc, item) => acc + Math.max(0, Number(item.duration_seconds || 0)), 0),
    [logs]
  );

  const estimateSeconds = (estimateMinutes ?? 0) * 60;
  const estimatePct =
    estimateSeconds > 0 ? Math.min(100, Math.round((totalLoggedSeconds / estimateSeconds) * 100)) : null;

  const displaySeconds =
    trackerMode === 'pomodoro'
      ? Math.max(0, POMODORO_SECONDS - elapsedSeconds)
      : elapsedSeconds;

  const handleToggleStartPause = () => {
    setErrorMsg(null);
    if (!running) {
      if (!startedAtIso) {
        setStartedAtIso(new Date().toISOString());
      }
      setRunning(true);
    } else {
      setRunning(false);
    }
  };

  const handleReset = () => {
    setRunning(false);
    setElapsedSeconds(0);
    setStartedAtIso(null);
  };

  const handleSaveActiveTimer = async () => {
    if (elapsedSeconds <= 0) {
      setErrorMsg('Jalankan timer minimal 1 detik sebelum menyimpan sesi.');
      return;
    }

    setRunning(false);
    setSaving(true);
    setErrorMsg(null);

    const endMs = Date.now();
    const endedAt = new Date(endMs).toISOString();
    const startedAt =
      startedAtIso || new Date(endMs - elapsedSeconds * 1000).toISOString();

    const { error } = await supabase.from('task_time_logs').insert({
      workspace_id: workspaceId,
      task_id: taskId,
      started_at: startedAt,
      ended_at: endedAt,
      duration_seconds: elapsedSeconds,
      mode: trackerMode,
      note: timerNote.trim() || null,
    });

    setSaving(false);

    if (error) {
      if (isSchemaFeatureUnavailable(error)) {
        setSchemaBlocked(true);
      } else {
        setErrorMsg(error.message);
      }
      return;
    }

    setElapsedSeconds(0);
    setStartedAtIso(null);
    setTimerNote('');
    await onReload();
  };

  const handleSaveManualLog = async (e: React.FormEvent) => {
    e.preventDefault();
    const mins = Number(manualMinutes);
    if (!Number.isFinite(mins) || mins <= 0) {
      setErrorMsg('Masukkan durasi menit yang valid (> 0).');
      return;
    }

    setSaving(true);
    setErrorMsg(null);

    const durationSec = Math.round(mins * 60);
    const endedAt = new Date();
    const startedAt = new Date(endedAt.getTime() - durationSec * 1000);

    const { error } = await supabase.from('task_time_logs').insert({
      workspace_id: workspaceId,
      task_id: taskId,
      started_at: startedAt.toISOString(),
      ended_at: endedAt.toISOString(),
      duration_seconds: durationSec,
      mode: 'manual',
      note: manualNote.trim() || null,
    });

    setSaving(false);

    if (error) {
      if (isSchemaFeatureUnavailable(error)) {
        setSchemaBlocked(true);
      } else {
        setErrorMsg(error.message);
      }
      return;
    }

    setManualMinutes('25');
    setManualNote('');
    await onReload();
  };

  const handleDeleteLog = async (logId: string) => {
    const { error } = await supabase
      .from('task_time_logs')
      .update({ deleted_at: new Date().toISOString() })
      .eq('id', logId);
    if (!error) {
      await onReload();
    }
  };

  return (
    <section className="rounded-lg border border-border bg-card p-4 space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <div className="flex items-center gap-2">
          <Clock className="w-4 h-4 text-primary" />
          <h3 className="text-sm font-semibold text-foreground">Pelacak Waktu &amp; Mode Fokus</h3>
        </div>
        <div className="text-xs text-muted-foreground tabular-nums">
          Total tercatat:{' '}
          <strong className="text-foreground">{formatTotalMinutesSummary(totalLoggedSeconds)}</strong>
          {estimateMinutes ? ` / Estimasi ${estimateMinutes} mnt` : ''}
        </div>
      </div>

      {estimatePct !== null && (
        <div className="space-y-1">
          <div className="h-2 w-full rounded-full bg-subtle border border-border overflow-hidden">
            <div
              className={cn(
                'h-full transition-all duration-150',
                totalLoggedSeconds > estimateSeconds ? 'bg-warning' : 'bg-primary'
              )}
              style={{ width: `${estimatePct}%` }}
            />
          </div>
        </div>
      )}

      {schemaBlocked ? (
        <div className="rounded-md border border-warning-border bg-warning-subtle px-3 py-2.5 text-xs text-warning">
          Tabel pelacak waktu (task_time_logs) belum tersedia pada basis data ini. Terapkan migrasi v5.3 untuk menyimpan log fokus.
        </div>
      ) : (
        <>
          {errorMsg && (
            <div className="rounded-md border border-expense-border bg-expense-subtle px-3 py-2 text-xs text-expense">
              {errorMsg}
            </div>
          )}

          {/* Switch Mode Pomodoro / Stopwatch */}
          <div className="rounded-md border border-border bg-subtle p-3 space-y-3">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <div className="inline-flex rounded-md border border-border bg-card p-0.5">
                <button
                  type="button"
                  onClick={() => {
                    if (!running) {
                      setTrackerMode('pomodoro');
                      setElapsedSeconds(0);
                    }
                  }}
                  className={cn(
                    'min-h-11 px-3 rounded-sm text-xs font-medium transition-colors',
                    trackerMode === 'pomodoro'
                      ? 'bg-primary text-primary-foreground font-semibold'
                      : 'text-muted-foreground hover:text-foreground'
                  )}
                >
                  Pomodoro (25m)
                </button>
                <button
                  type="button"
                  onClick={() => {
                    if (!running) {
                      setTrackerMode('stopwatch');
                      setElapsedSeconds(0);
                    }
                  }}
                  className={cn(
                    'min-h-11 px-3 rounded-sm text-xs font-medium transition-colors',
                    trackerMode === 'stopwatch'
                      ? 'bg-primary text-primary-foreground font-semibold'
                      : 'text-muted-foreground hover:text-foreground'
                  )}
                >
                  Stopwatch
                </button>
              </div>

              <div
                aria-live="polite"
                className="text-2xl font-bold tracking-tight text-foreground tabular-nums"
              >
                {formatDurationClock(displaySeconds)}
              </div>
            </div>

            <div className="flex flex-wrap items-center gap-2">
              <Button
                type="button"
                variant={running ? 'secondary' : 'primary'}
                onClick={handleToggleStartPause}
              >
                {running ? <Pause className="w-4 h-4" /> : <Play className="w-4 h-4" />}
                <span>{running ? 'Jeda' : elapsedSeconds > 0 ? 'Lanjutkan' : 'Mulai Fokus'}</span>
              </Button>
              <Button
                type="button"
                variant="secondary"
                onClick={handleSaveActiveTimer}
                disabled={saving || elapsedSeconds <= 0}
              >
                <CheckSquare className="w-4 h-4" />
                <span>{saving ? 'Menyimpan...' : 'Selesai & Simpan'}</span>
              </Button>
              <Button
                type="button"
                variant="ghost"
                size="icon"
                onClick={handleReset}
                disabled={elapsedSeconds === 0 && !running}
                aria-label="Reset timer"
                title="Reset timer"
              >
                <RotateCcw className="w-4 h-4" />
              </Button>
            </div>

            <Input
              value={timerNote}
              onChange={(e) => setTimerNote(e.target.value)}
              placeholder="Catatan sesi fokus (opsional)..."
            />
          </div>

          {/* Form Catat Manual Cepat */}
          <form onSubmit={handleSaveManualLog} className="grid grid-cols-1 sm:grid-cols-12 gap-2 items-end">
            <div className="sm:col-span-3">
              <label className="text-[11px] font-medium text-muted-foreground block mb-1">
                Catat Manual (mnt)
              </label>
              <Input
                type="number"
                min={1}
                max={1440}
                value={manualMinutes}
                onChange={(e) => setManualMinutes(e.target.value)}
                className="tabular-nums"
              />
            </div>
            <div className="sm:col-span-6">
              <label className="text-[11px] font-medium text-muted-foreground block mb-1">
                Catatan Singkat
              </label>
              <Input
                value={manualNote}
                onChange={(e) => setManualNote(e.target.value)}
                placeholder="Misal: Riset referensi antarmuka"
              />
            </div>
            <div className="sm:col-span-3">
              <Button type="submit" variant="secondary" className="w-full" disabled={saving}>
                <Plus className="w-4 h-4" />
                <span>Catat</span>
              </Button>
            </div>
          </form>

          {/* Riwayat Log Waktu */}
          {logs.length > 0 && (
            <div className="divide-y divide-border rounded-md border border-border">
              {logs.map((log) => (
                <div
                  key={log.id}
                  className="px-3 py-2 flex items-center justify-between gap-2 text-xs hover:bg-hover"
                >
                  <div className="min-w-0 space-y-0.5">
                    <div className="flex items-center gap-2">
                      <StatusBadge variant="neutral">
                        {log.mode === 'pomodoro'
                          ? 'Pomodoro'
                          : log.mode === 'manual'
                          ? 'Manual'
                          : 'Stopwatch'}
                      </StatusBadge>
                      <span className="font-semibold text-foreground tabular-nums">
                        {formatTotalMinutesSummary(log.duration_seconds)}
                      </span>
                      <span className="text-muted-foreground tabular-nums">
                        {formatDateIndo(log.started_at)}
                      </span>
                    </div>
                    {log.note && (
                      <div className="text-muted-foreground truncate">{log.note}</div>
                    )}
                  </div>
                  <Button
                    type="button"
                    variant="ghost"
                    size="icon"
                    onClick={() => handleDeleteLog(log.id)}
                    aria-label="Hapus catatan waktu"
                  >
                    <Trash2 className="w-3.5 h-3.5 text-muted-foreground hover:text-expense" />
                  </Button>
                </div>
              ))}
            </div>
          )}
        </>
      )}
    </section>
  );
}
