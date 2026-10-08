// Driver login: Driver Code + 6-digit PIN -> Supabase session (queue-rules §12).
// POST { driver_code, pin, device_id? } -> 200 { session } | 400 INVALID_INPUT | 401 LOGIN_FAILED | 429 LOGIN_LOCKED.
// Throttling lives in SQL (login_throttle_status / record_login_attempt, 0006_auth_admin.sql).
// Errors are generic: a wrong code and a wrong PIN look the same.
import { authEmailFor, normalizeDriverCode } from '../_shared/auth-email.ts';
import { adminClient, publicClient } from '../_shared/clients.ts';
import { corsHeaders, errorResponse, json, readJsonObject, stringField } from '../_shared/http.ts';
import { isPin } from '../_shared/pin.ts';

type ThrottleStatus = { locked: boolean; retry_after_seconds: number };

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return errorResponse('METHOD_NOT_ALLOWED');

  try {
    const body = await readJsonObject(request);
    const rawCode = body ? stringField(body, 'driver_code') : null;
    const pin = body ? stringField(body, 'pin') : null;
    const deviceId = body ? stringField(body, 'device_id') : null;
    const driverCode = rawCode ? normalizeDriverCode(rawCode) : null;
    if (!driverCode || !pin || !isPin(pin)) return errorResponse('INVALID_INPUT');

    const admin = adminClient();

    const throttle = await admin.rpc('login_throttle_status', { p_driver_code: driverCode, p_device_id: deviceId });
    if (throttle.error) return errorResponse('INTERNAL');
    const status = throttle.data as ThrottleStatus;
    if (status.locked) return errorResponse('LOGIN_LOCKED', { retry_after_seconds: status.retry_after_seconds });

    const record = (succeeded: boolean) =>
      admin.rpc('record_login_attempt', { p_driver_code: driverCode, p_device_id: deviceId, p_succeeded: succeeded });

    const active = await admin.rpc('login_account_active', { p_driver_code: driverCode });
    if (active.error) return errorResponse('INTERNAL');
    if (active.data !== true) {
      await record(false);
      return errorResponse('LOGIN_FAILED');
    }

    const signIn = await publicClient().auth.signInWithPassword({ email: authEmailFor(driverCode), password: pin });
    // Auth rate limits / outages are not the driver's fault: do not count them as failures.
    if (signIn.error && (signIn.error.status === 429 || (signIn.error.status ?? 500) >= 500)) {
      return errorResponse('INTERNAL');
    }
    if (signIn.error || !signIn.data.session) {
      await record(false);
      return errorResponse('LOGIN_FAILED');
    }

    await record(true);
    const { access_token, refresh_token, expires_at, expires_in } = signIn.data.session;
    return json({ session: { access_token, refresh_token, expires_at, expires_in } });
  } catch (error) {
    console.error('login failed unexpectedly', error);
    return errorResponse('INTERNAL');
  }
});
