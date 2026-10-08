import { isAuthRetryableFetchError } from '@supabase/supabase-js';
import type { Session } from '@supabase/supabase-js';
import { Storage } from 'expo-sqlite/kv-store';
import { create } from 'zustand';

import { clearQueueSnapshots } from '../../lib/sqlite';
import { AUTH_STORAGE_KEY, supabase } from '../../lib/supabase';
import { useDriverStatusStore } from '../driver/status.store';
import { clearTricycleNumber } from '../driver/tricycle';

const DRIVER_CODE_KEY = 'triko.driver_code';

type SessionState = {
  session: Session | null;
  // As typed at login, for the home header only (get_my_queue_status does not return it).
  driverCode: string | null;
  // True once the persisted session has been read; routing waits for it (no auth flicker).
  ready: boolean;
};

export const useSessionStore = create<SessionState>(() => ({ session: null, driverCode: null, ready: false }));

let started = false;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function isStoredSession(value: unknown): value is Session {
  return (
    isRecord(value) &&
    typeof value.access_token === 'string' &&
    typeof value.refresh_token === 'string' &&
    isRecord(value.user) &&
    typeof value.user.id === 'string'
  );
}

// Raw local read, no network. getSession() refreshes an expired token first, which offline
// retries for up to ~30 s and then reports no session at all.
async function readStoredSession(): Promise<Session | null> {
  try {
    const raw = await Storage.getItemAsync(AUTH_STORAGE_KEY);
    const value: unknown = raw ? JSON.parse(raw) : null;
    return isStoredSession(value) ? value : null;
  } catch {
    return null;
  }
}

// Route from the stored session immediately, then let supabase-js confirm it. A network failure
// keeps the stored session (offline is read-only, queue-rules §16); a rejected refresh signs out.
async function loadInitialSession(): Promise<void> {
  useSessionStore.setState({ session: await readStoredSession(), ready: true });
  try {
    const { data, error } = await supabase.auth.getSession();
    if (data.session || !isAuthRetryableFetchError(error)) useSessionStore.setState({ session: data.session });
  } catch {
    // Keep the stored session; the next foreground or reconnect retries.
  }
}

// Reads the stored session (works offline) and follows sign-in / refresh / sign-out.
export function startSessionSync(): void {
  if (started) return;
  started = true;
  Storage.getItemAsync(DRIVER_CODE_KEY)
    .then((driverCode) => useSessionStore.setState({ driverCode }))
    .catch(() => undefined);
  supabase.auth.onAuthStateChange((event, session) => {
    // The initial read is loadInitialSession's job: offline INITIAL_SESSION is null for an expired token.
    if (event === 'INITIAL_SESSION') return;
    useSessionStore.setState({ session, ready: true });
  });
  void loadInitialSession();
}

export async function rememberDriverCode(driverCode: string): Promise<void> {
  useSessionStore.setState({ driverCode });
  await Storage.setItemAsync(DRIVER_CODE_KEY, driverCode).catch(() => undefined);
}

const SIGN_OUT_WAIT_MS = 3000;

export async function logout(): Promise<void> {
  const userId = useSessionStore.getState().session?.user.id;
  // Offline with an expired token, signOut() retries the refresh for ~30 s and then keeps the
  // session. Wait briefly, then clear it locally: logout must always work offline (queue-rules §16).
  await Promise.race([
    supabase.auth.signOut({ scope: 'local' }).catch(() => undefined),
    new Promise((resolve) => setTimeout(resolve, SIGN_OUT_WAIT_MS)),
  ]);
  await Storage.removeItemAsync(AUTH_STORAGE_KEY).catch(() => undefined);
  useSessionStore.setState({ session: null });
  // The cached queue view must not outlive the session.
  useDriverStatusStore.getState().reset();
  useSessionStore.setState({ driverCode: null });
  await Storage.removeItemAsync(DRIVER_CODE_KEY).catch(() => undefined);
  await clearQueueSnapshots().catch(() => undefined);
  if (userId) await clearTricycleNumber(userId);
}
