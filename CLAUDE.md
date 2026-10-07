# CLAUDE.md

Guidance for Claude Code in this repository.

## Project

Triko — digital turno (queue) management for tricycle drivers and operators. Android-first, distributed as a direct APK, later Google Play.

- Mobile: React Native + Expo SDK 57 + TypeScript (strict) + Expo Router (`app/` at repo root) + Zustand + expo-sqlite.
- Backend: Supabase (PostgreSQL, Auth, Realtime Broadcast, Edge Functions). Local stack runs in Docker via the Supabase CLI.

Source documents (read before changing behavior):
- [TRIKO_BUILD_REFERENCE.md](TRIKO_BUILD_REFERENCE.md) — full product/engineering spec.
- [docs/queue-rules.md](docs/queue-rules.md) — **locked queue rules and decisions; overrides the reference where they differ.**

## The one rule

> **The mobile client is never the authority for queue state.**

The client may display, request, cache, subscribe and acknowledge. The server (PostgreSQL + queue engine functions) decides position, waiting position, priority, eligibility, reservation, transfer legality, activation, suspension, threshold crossings and notifications. Source of truth order: PostgreSQL → queue transactions → `queue_events` → Realtime → SQLite cache → push/SMS.

## Commands

```bash
npm start                 # Expo dev server
npm run typecheck         # tsc --noEmit
npm run lint              # expo lint
npm run doctor            # expo-doctor
npm run db:start          # local Supabase (needs Docker Desktop running)
npm run db:reset          # re-apply supabase/migrations + supabase/seed/*.sql
npm run db:test           # pgTAP tests in supabase/tests
npm run db:new -- <name>  # new migration file
```

The Supabase CLI is run through a pinned `npx supabase@2.120.0` (not a dev dependency — the Expo tree has an unrelated peer conflict).

Install mobile packages with `npx expo install <pkg>`, never plain `npm install`, so versions match the SDK. Expo APIs change every SDK: check `https://docs.expo.dev/versions/v57.0.0/` (or `https://docs.expo.dev/llms.txt`) instead of relying on memory. Push notifications need a development/EAS build, not Expo Go. Never hand-edit `android/`/`ios/` (generated).

## Layout

```
app/                 Expo Router routes only: (auth)/, (driver)/, (operator)/
src/design-system/   Triko* components (StyleSheet; no UI framework)
src/features/        auth, driver, operator, queue, notifications, qr
src/lib/             supabase, sqlite, notifications, connectivity clients
src/i18n/            Cebuano-first copy, English fallback
supabase/migrations/ schema, RLS, queue engine (SQL)
supabase/functions/  Edge Functions (driver-admin, login, notifications, qr, later sms)
supabase/tests/      pgTAP business-rule tests
supabase/seed/       local seed data
docs/                product decisions
```

## Backend rules

- Queue changes only through named command functions (`reserve_queue_entry(...)`), never client `UPDATE`s of status/rank. Clients have no direct write access to queue tables.
- Every command: lock the route's `queue_state` row → validate the transition → update entries → append `queue_events` (old/new state) → bump `queue_version` → compute old vs new waiting positions → create notification rows. One transaction.
- Ranks/positions are derived by a single function (`queue_effective_order`); `current_rank` is a cache, not truth.
- `queue_events` is append-only. Undo is a new event, never a delete.
- RLS on every table. Authorization comes from the authenticated user + database, never a client-sent role.
- Secrets (`sb_secret_...` key, SMS keys) live only in Edge Function secrets. The app ships only the publishable key. Auth users are created only by Edge Functions/admin scripts (public sign-up is disabled).
- Synthetic auth email domain comes from `AUTH_EMAIL_DOMAIN` / `EXPO_PUBLIC_AUTH_EMAIL_DOMAIN` — never hard-code it.
- Never invent a queue rule. If behavior is undefined, use the safest existing rule and flag it for product clarification in `docs/queue-rules.md`.

## Mobile rules

- Domain logic stays out of components; never duplicate queue rules across screens; never compute thresholds on the client.
- Startup: render cached SQLite state immediately, sync in the background. No blank network loading screens.
- Offline: read-only. Show `⚠ OFFLINE` + last updated time; operator mutations disabled. Server state always replaces local state.
- Low-end Android: `FlatList`, memoized rows, selective Zustand selectors, no polling, no heavy assets/animations, no large UI frameworks. Justify every new package.
- Driver UI: huge number, icon + text status (never color alone), very little text, almost no typing. Operator UI: queue first, large targets, confirm high-impact actions, 30-second Undo.
- Never show technical errors (Postgrest codes, "Network request failed") to users.

## Testing

Business rules are tested in pgTAP (`npm run db:test`) before any screen uses them. Always cover offline/reconnect states and destructive actions + undo.

## Commits

Title `Type: Short Title Case Summary` (Feature / Fix / BugFix / Migration / Update); body is one-line `-` bullets of important changes only.
