// Edge Function configuration. The secret key lives only in Edge Function secrets.
// Locally the runtime injects SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY;
// in production set TRIKO_SECRET_KEY (sb_secret_...) and AUTH_EMAIL_DOMAIN with `supabase secrets set`
// (names starting with SUPABASE_ are reserved by the CLI).

function required(name: string, value: string | undefined): string {
  if (!value) throw new Error(`Missing Edge Function env: ${name}`);
  return value;
}

export function supabaseUrl(): string {
  return required('SUPABASE_URL', Deno.env.get('SUPABASE_URL'));
}

export function secretKey(): string {
  return required(
    'TRIKO_SECRET_KEY',
    Deno.env.get('TRIKO_SECRET_KEY') ?? Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'),
  );
}

export function publishableKey(): string {
  return required(
    'SUPABASE_ANON_KEY',
    Deno.env.get('TRIKO_PUBLISHABLE_KEY') ?? Deno.env.get('SUPABASE_ANON_KEY'),
  );
}

export function authEmailDomain(): string {
  return required('AUTH_EMAIL_DOMAIN', Deno.env.get('AUTH_EMAIL_DOMAIN'));
}
