import { useEffect } from 'react';
import { AppState } from 'react-native';
import { create } from 'zustand';

import { useIsOnline } from '../../lib/connectivity';
import { readQueueSnapshot, writeQueueSnapshot } from '../../lib/sqlite';
import { supabase } from '../../lib/supabase';
import { parseMyQueueStatus } from './status.types';
import type { MyQueueStatus } from './status.types';

// Driver home state: SQLite snapshot first, then get_my_queue_status() in the background.
// Server data always replaces the cache; nothing is computed here (CLAUDE.md "The one rule").
type DriverStatusState = {
  userId: string | null;
  status: MyQueueStatus | null;
  lastSyncedAt: string | null;
  syncFailed: boolean;
  reset: () => void;
};

const initial = { userId: null, status: null, lastSyncedAt: null, syncFailed: false };

export const useDriverStatusStore = create<DriverStatusState>((set) => ({
  ...initial,
  reset: () => set(initial),
}));

let inFlight: Promise<void> | null = null;

async function loadCache(userId: string): Promise<void> {
  const row = await readQueueSnapshot(userId).catch(() => null);
  if (!row || useDriverStatusStore.getState().userId !== userId) return;
  // Never let an older cache overwrite a server result that arrived first.
  if (useDriverStatusStore.getState().lastSyncedAt) return;
  let payload: unknown = null;
  try {
    payload = JSON.parse(row.payload);
  } catch {
    return;
  }
  const status = parseMyQueueStatus(payload);
  if (status) useDriverStatusStore.setState({ status, lastSyncedAt: row.lastSyncedAt });
}

function syncNow(userId: string): Promise<void> {
  inFlight ??= (async () => {
    try {
      const { data, error } = await supabase.rpc('get_my_queue_status');
      const status = error ? null : parseMyQueueStatus(data);
      // Ignore a reply that lands after logout or an account switch.
      if (useDriverStatusStore.getState().userId !== userId) return;
      if (!status) {
        useDriverStatusStore.setState({ syncFailed: true });
        return;
      }
      const lastSyncedAt = new Date().toISOString();
      useDriverStatusStore.setState({ status, lastSyncedAt, syncFailed: false });
      await writeQueueSnapshot(userId, {
        payload: JSON.stringify(data),
        queueVersion: status.queueVersion,
        lastSyncedAt,
      }).catch(() => undefined);
    } catch {
      if (useDriverStatusStore.getState().userId === userId) useDriverStatusStore.setState({ syncFailed: true });
    } finally {
      inFlight = null;
    }
  })();
  return inFlight;
}

// Mount: show cache, then sync. Re-sync on reconnect and when the app returns to the foreground.
// No polling; Realtime comes in a later milestone.
export function useDriverStatusSync(userId: string): void {
  const isOnline = useIsOnline();

  // userId is '' for the frame between sign-out and leaving the driver stack: do nothing then.
  useEffect(() => {
    if (!userId) return;
    if (useDriverStatusStore.getState().userId !== userId) {
      useDriverStatusStore.setState({ ...initial, userId });
    }
    void loadCache(userId);
  }, [userId]);

  useEffect(() => {
    if (userId && isOnline) void syncNow(userId);
  }, [isOnline, userId]);

  useEffect(() => {
    const subscription = AppState.addEventListener('change', (state) => {
      if (userId && state === 'active') void syncNow(userId);
    });
    return () => subscription.remove();
  }, [userId]);
}
