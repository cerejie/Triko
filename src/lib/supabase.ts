import { createClient } from '@supabase/supabase-js';
import { AppState } from 'react-native';
import { Storage } from 'expo-sqlite/kv-store';

import { env } from './env';

// The session (incl. refresh token) persists in expo-sqlite's key-value store (queue-rules §16).
export const supabase = createClient(env.supabaseUrl, env.supabasePublishableKey, {
  auth: {
    storage: Storage,
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: false,
  },
});

// Refresh tokens only while the app is in the foreground (supabase-js React Native guidance).
AppState.addEventListener('change', (state) => {
  if (state === 'active') supabase.auth.startAutoRefresh();
  else supabase.auth.stopAutoRefresh();
});
