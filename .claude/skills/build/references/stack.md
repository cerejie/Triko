# Stack rules

Apply only the sections whose tool the change touches.

## Expo SDK 57 / React Native

- `npx expo install <pkg>` only. Check APIs at `https://docs.expo.dev/versions/v57.0.0/` — they change every SDK.
- Expo Router: routes in `app/` only, grouped `(auth)`, `(driver)`, `(operator)`.
- Push notifications need a development/EAS build, not Expo Go.
- `FlatList` + memoized rows; no heavy assets or animations; no polling.

## expo-sqlite

- Local cache only: render cached state immediately, sync in background, server state replaces local state.
- Store `queue_version` + `last_synced_at`; offline is read-only with `⚠ OFFLINE` + last updated time.

## Zustand

- Selective selectors (`useStore(s => s.x)`), never the whole store in a component.

## supabase-js

- App ships only the publishable key. Call commands with `supabase.rpc('<command>', { p_… })`; map `error.message` (an error key) to i18n copy.
- Never `.from('queue_*').update/insert` — RLS denies it and it violates the server-authority rule.

## Supabase CLI (local)

- Always `npx supabase@2.120.0 …` via the npm scripts (`db:start`, `db:reset`, `db:test`, `db:new`). Needs Docker Desktop running.
- `db:reset` re-applies all migrations + `supabase/seed/*.sql`; `db:test` runs `supabase/tests/`.
- Synthetic auth email domain from `AUTH_EMAIL_DOMAIN` / `EXPO_PUBLIC_AUTH_EMAIL_DOMAIN`; never hard-code it outside the seed.
