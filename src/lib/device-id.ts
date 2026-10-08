import { Storage } from 'expo-sqlite/kv-store';

// Stable per-install id for the login function's per-device throttle (queue-rules §12).
// Not a secret and not used for authorization.
const KEY = 'triko.device_id';

function randomId(): string {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = Math.floor(Math.random() * 16);
    return (c === 'x' ? r : (r & 0x3) | 0x8).toString(16);
  });
}

export async function getDeviceId(): Promise<string> {
  const existing = await Storage.getItemAsync(KEY);
  if (existing) return existing;
  const id = randomId();
  await Storage.setItemAsync(KEY, id);
  return id;
}
