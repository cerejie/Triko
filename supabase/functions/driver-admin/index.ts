// Operator driver administration (queue-rules §12). Requires the caller's JWT.
// POST { action: 'create', route_id, display_name, tricycle_number, phone_number? }
//   -> 201 { driver_id, driver_code, pin }   (PIN shown once to the operator)
// POST { action: 'reset_pin', driver_id }
//   -> 200 { driver_code, pin }
// Permission checks and all row writes are in SQL (0006_auth_admin.sql); this function
// only holds the secret key for the Auth Admin API. If anything fails after the auth
// user is created, that auth user is deleted.
import type { SupabaseClient } from '@supabase/supabase-js';
import { authEmailFor } from '../_shared/auth-email.ts';
import { adminClient } from '../_shared/clients.ts';
import { corsHeaders, dbErrorResponse, errorResponse, json, readJsonObject, stringField } from '../_shared/http.ts';
import { generatePin } from '../_shared/pin.ts';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

async function callerId(admin: SupabaseClient, request: Request): Promise<string | null> {
  const token = request.headers.get('Authorization')?.replace(/^Bearer\s+/i, '');
  if (!token) return null;
  const { data, error } = await admin.auth.getUser(token);
  return error || !data.user ? null : data.user.id;
}

async function deleteAuthUser(admin: SupabaseClient, userId: string): Promise<void> {
  const { error } = await admin.auth.admin.deleteUser(userId);
  // An orphan auth user has no profile, so it cannot use the app; log it for cleanup.
  if (error) console.error('driver-admin: failed to delete orphan auth user', userId, error.message);
}

async function createDriver(admin: SupabaseClient, actor: string, body: Record<string, unknown>): Promise<Response> {
  const routeId = stringField(body, 'route_id');
  const displayName = stringField(body, 'display_name');
  const tricycleNumber = stringField(body, 'tricycle_number');
  const phoneNumber = stringField(body, 'phone_number');
  if (!routeId || !UUID.test(routeId) || !displayName || !tricycleNumber) return errorResponse('INVALID_INPUT');

  // One retry when a concurrent create takes the same server-generated code.
  for (let attempt = 0; attempt < 2; attempt++) {
    const prepared = await admin.rpc('driver_admin_prepare_create', { p_actor: actor, p_route_id: routeId });
    if (prepared.error) return dbErrorResponse(prepared.error.message);
    const driverCode = (prepared.data as { driver_code: string }).driver_code;
    const pin = generatePin();

    const created = await admin.auth.admin.createUser({
      email: authEmailFor(driverCode),
      password: pin,
      email_confirm: true,
    });
    if (created.error || !created.data.user) {
      console.error('driver-admin: createUser failed', created.error?.message);
      return errorResponse('INTERNAL');
    }
    const userId = created.data.user.id;

    try {
      const result = await admin.rpc('driver_admin_create_driver', {
        p_actor: actor,
        p_user_id: userId,
        p_driver_code: driverCode,
        p_display_name: displayName,
        p_phone_number: phoneNumber,
        p_tricycle_number: tricycleNumber,
        p_route_id: routeId,
      });
      if (result.error) {
        await deleteAuthUser(admin, userId);
        if (result.error.message === 'DRIVER_CODE_TAKEN') continue;
        return dbErrorResponse(result.error.message);
      }
      const row = result.data as { driver_id: string };
      return json({ driver_id: row.driver_id, driver_code: driverCode, pin }, 201);
    } catch (error) {
      await deleteAuthUser(admin, userId);
      throw error;
    }
  }
  return errorResponse('INTERNAL');
}

async function resetPin(admin: SupabaseClient, actor: string, body: Record<string, unknown>): Promise<Response> {
  const driverId = stringField(body, 'driver_id');
  if (!driverId || !UUID.test(driverId)) return errorResponse('INVALID_INPUT');

  const authorized = await admin.rpc('driver_admin_authorize_reset', { p_actor: actor, p_driver_id: driverId });
  if (authorized.error) return dbErrorResponse(authorized.error.message);
  const { profile_id, driver_code } = authorized.data as { profile_id: string; driver_code: string };

  const pin = generatePin();
  const updated = await admin.auth.admin.updateUserById(profile_id, { password: pin });
  if (updated.error) {
    console.error('driver-admin: updateUserById failed', updated.error.message);
    return errorResponse('INTERNAL');
  }
  return json({ driver_code, pin });
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return errorResponse('METHOD_NOT_ALLOWED');

  try {
    const admin = adminClient();
    const actor = await callerId(admin, request);
    if (!actor) return errorResponse('UNAUTHORIZED');

    const body = await readJsonObject(request);
    if (!body) return errorResponse('INVALID_INPUT');

    switch (stringField(body, 'action')) {
      case 'create':
        return await createDriver(admin, actor, body);
      case 'reset_pin':
        return await resetPin(admin, actor, body);
      default:
        return errorResponse('INVALID_INPUT');
    }
  } catch (error) {
    console.error('driver-admin failed unexpectedly', error);
    return errorResponse('INTERNAL');
  }
});
