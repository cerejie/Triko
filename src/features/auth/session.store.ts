import type { Session } from '@supabase/supabase-js';
import { Storage } from 'expo-sqlite/kv-store';
import { create } from 'zustand';

import { clearQueueSnapshots } from '../../lib/sqlite';
import { supabase } from '../../lib/supabase';
import { useDriverStatusStore } from '../driver/status.store';

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

// Reads the stored session (works offline) and follows sign-in / refresh / sign-out.
export function startSessionSync(): void {
  if (started) return;
  started = true;
  Storage.getItemAsync(DRIVER_CODE_KEY)
    .then((driverCode) => useSessionStore.setState({ driverCode }))
    .catch(() => undefined);
  supabase.auth.onAuthStateChange((_event, session) => {
    useSessionStore.setState({ session, ready: true });
  });
  supabase.auth
    .getSession()
    .then(({ data }) => useSessionStore.setState({ session: data.session, ready: true }))
    .catch(() => useSessionStore.setState({ ready: true }));
}

export async function rememberDriverCode(driverCode: string): Promise<void> {
  useSessionStore.setState({ driverCode });
  await Storage.setItemAsync(DRIVER_CODE_KEY, driverCode).catch(() => undefined);
}

export async function logout(): Promise<void> {
  // Local sign-out works offline; the cached queue view must not outlive the session.
  await supabase.auth.signOut({ scope: 'local' }).catch(() => undefined);
  useDriverStatusStore.getState().reset();
  useSessionStore.setState({ driverCode: null });
  await Storage.removeItemAsync(DRIVER_CODE_KEY).catch(() => undefined);
  await clearQueueSnapshots().catch(() => undefined);
}
