import { createClient } from '@supabase/supabase-js';
import type { SupabaseClient } from '@supabase/supabase-js';
import { publishableKey, secretKey, supabaseUrl } from './env.ts';

const serverOptions = { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false } };

// Secret-key client: Auth Admin API and service_role-only RPCs.
export function adminClient(): SupabaseClient {
  return createClient(supabaseUrl(), secretKey(), serverOptions);
}

// Publishable-key client: password sign-in on behalf of the driver.
export function publicClient(): SupabaseClient {
  return createClient(supabaseUrl(), publishableKey(), serverOptions);
}
