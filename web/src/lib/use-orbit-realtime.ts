'use client';

import React, { useEffect, useMemo, useRef, useState } from 'react';
import { Radio, WifiOff } from 'lucide-react';
import { createClient } from '@/lib/supabase/client';
import { cn } from '@/components/ui';

export type OrbitRealtimeTable =
  | 'tasks'
  | 'transactions'
  | 'events'
  | 'comments'
  | 'project_payments'
  | 'budgets';

export type RealtimeConnectionStatus = 'local' | 'connecting' | 'connected';

export const DEFAULT_REALTIME_TABLES: OrbitRealtimeTable[] = [
  'tasks',
  'transactions',
  'events',
  'comments',
  'project_payments',
  'budgets',
];

export interface UseOrbitRealtimeOptions {
  workspaceId: string | null | undefined;
  tables?: OrbitRealtimeTable[];
  onChange: () => void;
  enabled?: boolean;
  debounceMs?: number;
}

export function useOrbitRealtime({
  workspaceId,
  tables = DEFAULT_REALTIME_TABLES,
  onChange,
  enabled = true,
  debounceMs = 300,
}: UseOrbitRealtimeOptions): { status: RealtimeConnectionStatus } {
  const supabase = useMemo(() => createClient(), []);
  const [status, setStatus] = useState<RealtimeConnectionStatus>('local');
  const onChangeRef = useRef(onChange);
  const debounceTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    onChangeRef.current = onChange;
  }, [onChange]);

  const tablesKey = tables.join(',');

  useEffect(() => {
    if (!enabled || !workspaceId) {
      setStatus('local');
      return;
    }

    if (typeof navigator !== 'undefined' && !navigator.onLine) {
      setStatus('local');
      return;
    }

    const parsedTables = tablesKey
      .split(',')
      .map((t) => t.trim())
      .filter(Boolean) as OrbitRealtimeTable[];

    if (parsedTables.length === 0) {
      setStatus('local');
      return;
    }

    let isDisposed = false;
    setStatus('connecting');

    const scheduleRefresh = () => {
      if (isDisposed) return;
      if (debounceTimerRef.current) {
        clearTimeout(debounceTimerRef.current);
      }
      debounceTimerRef.current = setTimeout(() => {
        if (!isDisposed) {
          onChangeRef.current();
        }
      }, debounceMs);
    };

    const channelName = `orbit-rt-${workspaceId}-${parsedTables.join('-')}`;
    let channel: ReturnType<typeof supabase.channel> | null = null;

    try {
      let builder = supabase.channel(channelName);
      for (const table of parsedTables) {
        builder = builder.on(
          'postgres_changes',
          {
            event: '*',
            schema: 'public',
            table,
            filter: `workspace_id=eq.${workspaceId}`,
          },
          scheduleRefresh
        );
      }

      channel = builder.subscribe((subscriptionStatus) => {
        if (isDisposed) return;
        if (subscriptionStatus === 'SUBSCRIBED') {
          setStatus('connected');
        } else if (
          subscriptionStatus === 'CHANNEL_ERROR' ||
          subscriptionStatus === 'TIMED_OUT' ||
          subscriptionStatus === 'CLOSED'
        ) {
          setStatus('local');
        }
      });
    } catch {
      setStatus('local');
    }

    const handleOffline = () => setStatus('local');
    window.addEventListener('offline', handleOffline);

    return () => {
      isDisposed = true;
      window.removeEventListener('offline', handleOffline);
      if (debounceTimerRef.current) {
        clearTimeout(debounceTimerRef.current);
        debounceTimerRef.current = null;
      }
      if (channel) {
        void supabase.removeChannel(channel);
      }
    };
  }, [supabase, workspaceId, tablesKey, enabled, debounceMs]);

  return { status };
}

export function RealtimeStatusBadge({
  status,
  className,
}: {
  status: RealtimeConnectionStatus;
  className?: string;
}) {
  const isConnected = status === 'connected';
  const isConnecting = status === 'connecting';

  const label = isConnected
    ? 'Realtime aktif'
    : isConnecting
      ? 'Menghubungkan'
      : 'Mode lokal';

  const badgeIcon =
    isConnected || isConnecting
      ? React.createElement(Radio, {
          className: 'h-3 w-3 shrink-0',
          'aria-hidden': 'true',
        })
      : React.createElement(WifiOff, {
          className: 'h-3 w-3 shrink-0',
          'aria-hidden': 'true',
        });

  return React.createElement(
    'span',
    {
      'data-testid': 'realtime-status-badge',
      'data-realtime-status': status,
      className: cn(
        'inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-[11px] font-medium whitespace-nowrap',
        isConnected
          ? 'border-income-border bg-income-subtle text-income'
          : isConnecting
            ? 'border-border bg-primary-subtle text-primary'
            : 'border-border bg-subtle text-muted-foreground',
        className
      ),
    },
    badgeIcon,
    React.createElement('span', null, label)
  );
}
