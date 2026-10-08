import { getDeviceId } from '../../lib/device-id';
import { supabase } from '../../lib/supabase';
import { rememberDriverCode } from './session.store';

// Driver Code + PIN through the `login` Edge Function (queue-rules §12). Errors stay generic:
// the screen only ever sees these keys, never HTTP or Postgrest details.
export type LoginResult =
  | { ok: true }
  | { ok: false; error: 'LOGIN_FAILED' | 'INVALID_INPUT' | 'UNAVAILABLE' }
  | { ok: false; error: 'LOGIN_LOCKED'; retryAfterSeconds: number };

type SessionTokens = { access_token: string; refresh_token: string };

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function readSession(data: unknown): SessionTokens | null {
  if (!isRecord(data) || !isRecord(data.session)) return null;
  const { access_token, refresh_token } = data.session;
  return typeof access_token === 'string' && typeof refresh_token === 'string'
    ? { access_token, refresh_token }
    : null;
}

// supabase-js wraps non-2xx replies in FunctionsHttpError with the Response in `context`.
async function readErrorBody(error: unknown): Promise<Record<string, unknown> | null> {
  if (!isRecord(error) || !(error.context instanceof Response)) return null;
  try {
    const body: unknown = await error.context.json();
    return isRecord(body) ? body : null;
  } catch {
    return null;
  }
}

export async function loginDriver(driverCode: string, pin: string): Promise<LoginResult> {
  try {
    const { data, error } = await supabase.functions.invoke('login', {
      body: { driver_code: driverCode.trim(), pin, device_id: await getDeviceId() },
    });

    if (error) {
      const body = await readErrorBody(error);
      switch (body?.error) {
        case 'LOGIN_FAILED':
          return { ok: false, error: 'LOGIN_FAILED' };
        case 'INVALID_INPUT':
          return { ok: false, error: 'INVALID_INPUT' };
        case 'LOGIN_LOCKED': {
          const seconds = typeof body.retry_after_seconds === 'number' ? body.retry_after_seconds : 60;
          return { ok: false, error: 'LOGIN_LOCKED', retryAfterSeconds: seconds };
        }
        default:
          return { ok: false, error: 'UNAVAILABLE' };
      }
    }

    const tokens = readSession(data);
    if (!tokens) return { ok: false, error: 'UNAVAILABLE' };
    // Header label only; the server keeps the real identity in the session.
    await rememberDriverCode(driverCode.trim().toUpperCase());
    const { error: sessionError } = await supabase.auth.setSession(tokens);
    return sessionError ? { ok: false, error: 'UNAVAILABLE' } : { ok: true };
  } catch {
    return { ok: false, error: 'UNAVAILABLE' };
  }
}
