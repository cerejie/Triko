# Architecture — who owns what

Source of truth order: PostgreSQL → queue transactions → `queue_events` → Realtime → SQLite cache → push/SMS.

| Concern | Owner | Never in |
|---|---|---|
| Queue state transitions, validation | SQL command function (`public.<verb>_queue_*`, `SECURITY DEFINER`) | client, Edge Function |
| Positions, lanes, next-eligible | `public.queue_effective_order(route_id)` only | anywhere else — callers read it |
| `overall_position` / `waiting_position` columns | cache refreshed by `private.refresh_position_cache` | treated as truth |
| Threshold notifications | `private.create_threshold_notifications`, inside the mutation tx | client, cron, trigger outside the tx |
| Audit | one `queue_events` row per mutation, append-only | UPDATE/DELETE, notification rows |
| Undo | `undo_queue_event` restores `old_state`, writes `UNDO_PERFORMED` | deletes, recursive undo |
| Authorization | `auth.uid()` + `private.operator_has_route` / `private.current_driver_id` | client-sent role or user id |
| Privileged admin (create auth users, PIN reset, login throttle) | Edge Function with `sb_secret_` key | app bundle |
| Push / SMS delivery | `notifications` Edge Function reading `notification_events` | queue transaction |
| Screen data | `src/features/<x>` hooks calling read RPCs → SQLite cache → Zustand | components computing rules |
| UI | `app/` routes composing `src/design-system` | business logic |

## SQL layout

- `public` — tables, command functions and read RPCs callable by `authenticated`.
- `private` — helpers not exposed through the Data API (`lock_queue`, `assert_operator`, `append_event`, …).
- Every function: `set search_path = ''`, schema-qualified names, `EXECUTE` revoked from `public`/`anon`.

## Migrations

Append-only numbered files. Never edit one that has been applied anywhere but the local stack; fix forward with a new migration.
