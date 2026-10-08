import { Storage } from 'expo-sqlite/kv-store';
import { useEffect, useState } from 'react';

import { useIsOnline } from '../../lib/connectivity';
import { supabase } from '../../lib/supabase';

// The driver's current tricycle number for the home header (reference §4.3). Read through RLS
// (drivers_select_self + tricycles_select_driver); cached per user so it shows offline.
const keyFor = (userId: string) => `triko.tricycle_number:${userId}`;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

// string = assigned, null = no tricycle, undefined = could not read (keep the cache).
async function fetchTricycleNumber(userId: string): Promise<string | null | undefined> {
  const { data, error } = await supabase
    .from('drivers')
    .select('tricycles(tricycle_number)')
    .eq('profile_id', userId)
    .maybeSingle();
  if (error) return undefined;
  const row: unknown = data;
  if (!isRecord(row)) return null;
  const tricycle = row.tricycles;
  return isRecord(tricycle) && typeof tricycle.tricycle_number === 'string' ? tricycle.tricycle_number : null;
}

export async function clearTricycleNumber(userId: string): Promise<void> {
  await Storage.removeItemAsync(keyFor(userId)).catch(() => undefined);
}

// Cache first, then the server value whenever the app is online.
export function useTricycleNumber(userId: string): string | null {
  const isOnline = useIsOnline();
  const [value, setValue] = useState<string | null>(null);

  useEffect(() => {
    setValue(null);
    if (!userId) return;
    let live = true;
    Storage.getItemAsync(keyFor(userId))
      .then((cached) => {
        if (live && cached) setValue((current) => current ?? cached);
      })
      .catch(() => undefined);
    return () => {
      live = false;
    };
  }, [userId]);

  useEffect(() => {
    if (!userId || !isOnline) return;
    let live = true;
    fetchTricycleNumber(userId)
      .then(async (number) => {
        if (!live || number === undefined) return;
        setValue(number);
        if (number) await Storage.setItemAsync(keyFor(userId), number);
        else await clearTricycleNumber(userId);
      })
      .catch(() => undefined);
    return () => {
      live = false;
    };
  }, [userId, isOnline]);

  return value;
}
