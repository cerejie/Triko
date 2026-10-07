# Conventions

## SQL

- Lowercase keywords, two-space indent, `snake_case` everywhere.
- Commands: `public.<verb>_queue_<object>` / `public.<verb>_<object>` matching `docs/queue-rules.md` §5 names exactly (`reserve_queue_entry`, `return_reserved_driver`, …).
- Parameters `p_<name>`, locals `v_<name>`.
- Every function: `language plpgsql` (or `sql`), `security definer` only when it must bypass RLS, `set search_path = ''`, fully qualified identifiers (`public.queue_entries`, `extensions.gen_random_bytes`).
- Commands return `jsonb` `{event_id, queue_version, entry_id, …}`.
- Errors: `raise exception '<ERROR_KEY>' using errcode = 'P0001'`. Keys are `UPPER_SNAKE` and stable — the app maps them to copy in `src/i18n/`. Current keys: `FORBIDDEN`, `NOT_FOUND`, `INVALID_TRANSITION`, `QUEUE_CLOSED`, `CAPACITY_FULL`, `NOT_NEXT_ELIGIBLE`, `ALREADY_IN_QUEUE`, `ALREADY_IN_OTHER_QUEUE`, `INVALID_CAPACITY`, `DRIVER_INACTIVE`, `DRIVER_NOT_ASSIGNED`, `TRANSFER_NOT_ALLOWED`, `UNDO_EXPIRED`, `UNDO_NOT_LATEST`, `UNDO_NOT_ALLOWED`. Add new keys here.
- Section banners as in `0001_core.sql` (`-- ----` lines). Comment the *why*, cite the rule (`-- queue-rules §7.4`).
- Grants at the end of each migration: `revoke execute … from public, anon; grant execute … to authenticated;`.

## pgTAP

- File `supabase/tests/NNN_<topic>.test.sql`; `begin; select plan(N); … select * from finish(); rollback;`.
- Use seed fixed UUIDs (operator `…0001`, routes `…00a1` Magpet open / `…00a2` Matalam closed, driver **profile** ids `…1001`–`…100a` on Magpet, `…100b`–`…1014` on Matalam). `drivers.id` is random — resolve it with `select id from public.drivers where driver_code = 'DRV-001'`.
- Reuse the `tests.*` helpers from `000_setup.test.sql` (`as_operator`, `as_user`, `fill`, `join`, `entry`, `ord`, `undo_last`, `fingerprint`, `notif_count`); add new ones there.
- `tests.as_user(uuid)` sets `auth.uid()` only. To test grants/RLS, also `set local role authenticated` (or `anon`) and `reset role` afterwards.
- Assert error keys with `throws_ok(sql, 'P0001', '<ERROR_KEY>')`.
- One rule per assertion, description reads as the rule: `'absent again keeps priority_sequence'`.

## TypeScript / Expo

- Strict TS; no `any`; `import type` for types.
- Components `PascalCase.tsx`; design-system components prefixed `Triko`; hooks `use<Thing>.ts`; stores `<feature>.store.ts`; one feature per `src/features/<feature>/`.
- `StyleSheet.create` only; no UI framework.
- All user-visible text from `src/i18n/` (Cebuano first). Never show technical errors — map RPC error keys to copy.
- Driver UI: huge number, icon + text status (never color alone). Operator: confirm high-impact actions, 30-second Undo.
