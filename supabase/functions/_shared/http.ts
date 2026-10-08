// JSON responses with stable error keys only — never technical details (CLAUDE.md mobile rules).

export const corsHeaders: Record<string, string> = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

export type ErrorKey =
  | 'INVALID_INPUT'
  | 'LOGIN_FAILED'
  | 'LOGIN_LOCKED'
  | 'UNAUTHORIZED'
  | 'FORBIDDEN'
  | 'NOT_FOUND'
  | 'DRIVER_INACTIVE'
  | 'TRICYCLE_IN_USE'
  | 'METHOD_NOT_ALLOWED'
  | 'INTERNAL';

const statusFor: Record<ErrorKey, number> = {
  INVALID_INPUT: 400,
  LOGIN_FAILED: 401,
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  METHOD_NOT_ALLOWED: 405,
  DRIVER_INACTIVE: 409,
  TRICYCLE_IN_USE: 409,
  LOGIN_LOCKED: 429,
  INTERNAL: 500,
};

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

export function errorResponse(key: ErrorKey, extra: Record<string, unknown> = {}): Response {
  return json({ error: key, ...extra }, statusFor[key]);
}

// Maps a database error message (our P0001 keys) to a response; anything else is INTERNAL.
export function dbErrorResponse(message: string | undefined): Response {
  const known: ErrorKey[] = ['INVALID_INPUT', 'FORBIDDEN', 'NOT_FOUND', 'DRIVER_INACTIVE', 'TRICYCLE_IN_USE'];
  const key = known.find((k) => k === message);
  return errorResponse(key ?? 'INTERNAL');
}

export async function readJsonObject(request: Request): Promise<Record<string, unknown> | null> {
  try {
    const body: unknown = await request.json();
    return typeof body === 'object' && body !== null && !Array.isArray(body)
      ? (body as Record<string, unknown>)
      : null;
  } catch {
    return null;
  }
}

export function stringField(body: Record<string, unknown>, key: string): string | null {
  const value = body[key];
  return typeof value === 'string' ? value : null;
}
