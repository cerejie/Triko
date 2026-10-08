// Public config bundled into the APK. Only the publishable key ever goes here (CLAUDE.md backend rules).
// EXPO_PUBLIC_* must be read with static property access so Metro inlines them.

function required(name: string, value: string | undefined): string {
  if (!value) throw new Error(`Missing ${name} (see .env.example)`);
  return value;
}

export const env = {
  supabaseUrl: required('EXPO_PUBLIC_SUPABASE_URL', process.env.EXPO_PUBLIC_SUPABASE_URL),
  supabasePublishableKey: required(
    'EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY',
    process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
  ),
};
