# Queue command recipe

Every queue mutation is one SQL function, one transaction, in this order (queue-rules §5, CLAUDE.md backend rules):

1. **Load + authorize** — find the entry/route; `private.assert_operator(route_id)` (or driver self-check). Unknown id → `NOT_FOUND`.
2. **Lock** — `private.lock_queue(route_id)` (`select … from public.queue_state … for update`). Lock *before* validating so two operators serialize.
3. **Snapshot** — `v_before := private.snapshot_waiting_positions(route_id)`, and capture full `old_state` rows (entries, reservations, route fields) the command will touch — undo restores from it.
4. **Validate** — the §5.1 action matrix for the entry's current status (`INVALID_TRANSITION`), then command-specific rules (capacity, next eligible, transfer limits…).
5. **Mutate** — update/insert entries, reservations, transfers. Sequences come from `queue_state` counters (`queue_sequence`, `priority_sequence`), incremented under the lock; they never go backwards.
6. **Finish** — `private.finish_mutation(route_id, entry_id, event_type, old_state, new_state, v_before, reason)`: appends one `queue_events` row, bumps `queue_version`, sets `last_event_id`, refreshes position caches, creates threshold notifications (skipped for undo).
7. **Return** `jsonb` `{event_id, queue_version, entry_id}`.

## Checklist before calling it done

- [ ] `set search_path = ''`, qualified names, `security definer`.
- [ ] `revoke execute … from public, anon; grant execute … to authenticated`.
- [ ] Every rejection uses a stable error key from `conventions.md`.
- [ ] pgTAP: happy path, each rejection, event + version bump, notification effect, undo restores.
- [ ] Any behavior not in `docs/queue-rules.md` is recorded there as **[ASSUMPTION]**.

## pgTAP skeleton

```sql
begin;
select plan(3);

-- act as operator
set local role authenticated;
set local request.jwt.claims = '{"sub":"00000000-0000-4000-8000-000000000001","role":"authenticated"}';

select lives_ok($$ select public.join_queue('00000000-0000-4000-8000-0000000000a1', <driver_id>) $$, 'operator can add driver');
select throws_ok($$ select public.join_queue('00000000-0000-4000-8000-0000000000a1', <driver_id>) $$, 'P0001', 'ALREADY_IN_QUEUE', 'second join rejected');

reset role;
select is((select queue_version from public.queue_state where route_id = '00000000-0000-4000-8000-0000000000a1'), 1::bigint, 'one mutation bumps version once');

select * from finish();
rollback;
```
