-- Triko queue engine core (M3).
-- Rules: docs/queue-rules.md. Ordering/positions come only from queue_effective_order;
-- every command funnels through private.finish_mutation (event, version, cache, notifications).
-- Error contract: raise exception '<ERROR_KEY>' using errcode = 'P0001'.

-- ---------------------------------------------------------------------------
-- queue_transfers: an undone transfer must not block the sender's real transfer later.
-- ---------------------------------------------------------------------------

alter table public.queue_transfers add column undone_at timestamptz;
alter table public.queue_transfers drop constraint queue_transfers_source_entry_id_key;

create unique index queue_transfers_source_entry_live_uq
  on public.queue_transfers (source_entry_id) where undone_at is null;

-- ---------------------------------------------------------------------------
-- queue_effective_order: the ONLY source of lanes and positions (queue-rules §2, §3).
--   ACTIVE    by activated_at
--   PRIORITY  by the active reservation's priority_sequence
--   WAITING   by join_sequence
--   reserved (away) / suspended: no position; reserved keeps reservation_priority.
-- ---------------------------------------------------------------------------

create function public.queue_effective_order(p_route_id uuid)
returns table (
  entry_id              uuid,
  driver_id             uuid,
  status                public.queue_entry_status,
  lane                  text,
  overall_position      integer,
  waiting_position      integer,
  waiting_ahead         integer,
  reservation_priority  integer,
  active_slot           integer,
  is_next_eligible      boolean
)
language sql
stable
set search_path = ''
as $$
  with live as (
    select qe.id, qe.driver_id, qe.status, qe.join_sequence, qe.activated_at,
           r.priority_sequence as res_seq
    from public.queue_entries qe
    left join public.queue_reservations r
      on r.queue_entry_id = qe.id and r.status = 'active'
    where qe.route_id = p_route_id
      and qe.status in ('waiting', 'active', 'reserved', 'priority', 'suspended')
  ),
  act as (
    select id, row_number() over (order by activated_at, id)::integer as slot
    from live where status = 'active'
  ),
  wait as (
    select id,
           row_number() over (
             order by (status = 'waiting'),                      -- PRIORITY lane first
                      case when status = 'priority' then res_seq else join_sequence end,
                      id
           )::integer as wpos
    from live where status in ('priority', 'waiting')
  ),
  resv as (
    select id, row_number() over (order by res_seq, id)::integer as rp
    from live where status in ('reserved', 'priority') and res_seq is not null
  ),
  total as (select count(*)::integer as active_count from act)
  select l.id,
         l.driver_id,
         l.status,
         l.status::text,
         coalesce(a.slot, t.active_count + w.wpos),
         w.wpos,
         w.wpos - 1,
         rv.rp,
         a.slot,
         coalesce(w.wpos = 1, false)
  from live l
  cross join total t
  left join act a  on a.id = l.id
  left join wait w on w.id = l.id
  left join resv rv on rv.id = l.id
  order by coalesce(a.slot, t.active_count + w.wpos) nulls last, rv.rp nulls last, l.join_sequence;
$$;

-- ---------------------------------------------------------------------------
-- Internal helpers (private schema: not exposed through the Data API)
-- ---------------------------------------------------------------------------

-- Operators of the route (or an admin) may run queue commands. Authorization
-- always comes from auth.uid(), never from a client-sent role.
create function private.assert_operator(p_route_id uuid)
returns void
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not (private.operator_has_route(p_route_id) or private.is_admin()) then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;
end;
$$;

-- Serializes every command on a route. Returns the route row read under the lock.
create function private.lock_queue(p_route_id uuid)
returns public.routes
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_route public.routes;
begin
  perform 1 from public.queue_state where route_id = p_route_id for update;
  if not found then
    raise exception 'NOT_FOUND' using errcode = 'P0001';
  end if;
  select * into v_route from public.routes where id = p_route_id;
  return v_route;
end;
$$;

-- Load -> authorize -> lock -> re-read the entry under the lock.
create function private.begin_entry_command(p_entry_id uuid)
returns public.queue_entries
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_route_id uuid;
  v_entry    public.queue_entries;
begin
  select route_id into v_route_id from public.queue_entries where id = p_entry_id;
  if not found then
    raise exception 'NOT_FOUND' using errcode = 'P0001';
  end if;

  perform private.assert_operator(v_route_id);
  perform private.lock_queue(v_route_id);

  select * into v_entry from public.queue_entries where id = p_entry_id for update;
  return v_entry;
end;
$$;

-- queue-rules §5.1 action matrix gate.
create function private.assert_status(
  p_status  public.queue_entry_status,
  p_allowed public.queue_entry_status[]
)
returns void
language plpgsql
immutable
set search_path = ''
as $$
begin
  if not (p_status = any (p_allowed)) then
    raise exception 'INVALID_TRANSITION' using errcode = 'P0001';
  end if;
end;
$$;

-- Next value of a queue_state counter; call only while holding lock_queue.
create function private.next_join_sequence(p_route_id uuid)
returns bigint
language sql
security definer
set search_path = ''
as $$
  update public.queue_state set queue_sequence = queue_sequence + 1
  where route_id = p_route_id
  returning queue_sequence;
$$;

create function private.next_priority_sequence(p_route_id uuid)
returns bigint
language sql
security definer
set search_path = ''
as $$
  update public.queue_state set priority_sequence = priority_sequence + 1
  where route_id = p_route_id
  returning priority_sequence;
$$;

-- entry_id -> waiting_position for everyone currently in a waiting lane.
create function private.snapshot_waiting_positions(p_route_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(jsonb_object_agg(o.entry_id::text, o.waiting_position), '{}'::jsonb)
  from public.queue_effective_order(p_route_id) o
  where o.waiting_position is not null;
$$;

-- Full rows the command touches; undo restores from this (queue-rules §6).
create function private.queue_snapshot(p_route_id uuid, p_entry_ids uuid[])
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'entries', coalesce((
      select jsonb_agg(to_jsonb(qe) order by qe.join_sequence)
      from public.queue_entries qe
      where qe.id = any (p_entry_ids)
    ), '[]'::jsonb),
    'reservations', coalesce((
      select jsonb_agg(to_jsonb(r) order by r.priority_sequence)
      from public.queue_reservations r
      where r.queue_entry_id = any (p_entry_ids) and r.status = 'active'
    ), '[]'::jsonb),
    'route', (
      select jsonb_build_object(
        'queue_capacity', rt.queue_capacity,
        'queue_status',   rt.queue_status,
        'qr_enabled',     rt.qr_enabled
      )
      from public.routes rt where rt.id = p_route_id
    )
  );
$$;

-- Rewrites the cached overall_position / waiting_position columns (cache, not truth).
create function private.refresh_position_cache(p_route_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.queue_entries qe
  set overall_position = o.overall_position,
      waiting_position = o.waiting_position
  from public.queue_effective_order(p_route_id) o
  where qe.id = o.entry_id
    and (qe.overall_position is distinct from o.overall_position
         or qe.waiting_position is distinct from o.waiting_position);

  update public.queue_entries qe
  set overall_position = null,
      waiting_position = null
  where qe.route_id = p_route_id
    and qe.status in ('completed', 'cancelled', 'removed')
    and (qe.overall_position is not null or qe.waiting_position is not null);
$$;

-- queue-rules §11: notify only on a forward move that crosses a threshold
-- (old > t >= new), sending only the lowest threshold crossed. Entries that were
-- not in a waiting lane before (join, return, resume, transfer receipt) never notify.
create function private.create_threshold_notifications(
  p_route_id uuid,
  p_before   jsonb,
  p_event_id uuid
)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.notification_events (
    driver_id, queue_entry_id, route_id, notification_cycle,
    notification_type, threshold, channel, source_event_id
  )
  select o.driver_id,
         o.entry_id,
         p_route_id,
         qe.notification_cycle,
         case when x.t = 1 then 'NEXT_IN_LINE' else 'QUEUE_THRESHOLD' end::public.notification_type,
         x.t,
         'push',
         p_event_id
  from public.queue_effective_order(p_route_id) o
  join public.queue_entries qe on qe.id = o.entry_id
  cross join lateral (
    select min(t) as t
    from unnest(array[10, 8, 6, 4, 2, 1]) as t
    where (p_before ->> o.entry_id::text)::integer > t
      and t >= o.waiting_position
  ) x
  where o.waiting_position is not null
    and p_before ? o.entry_id::text
    and x.t is not null
  on conflict do nothing;
$$;

-- Every command ends here, inside its transaction:
-- bump queue_version -> append queue_events -> set last_event_id -> refresh cache
-- -> threshold notifications (never for undo).
create function private.finish_mutation(
  p_route_id    uuid,
  p_entry_id    uuid,
  p_event_type  public.queue_event_type,
  p_old_state   jsonb,
  p_new_state   jsonb,
  p_before      jsonb,
  p_reason      text default null,
  p_undoes      uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_version  bigint;
  v_event_id uuid;
begin
  update public.queue_state
  set queue_version = queue_version + 1
  where route_id = p_route_id
  returning queue_version into v_version;

  insert into public.queue_events (
    route_id, queue_entry_id, event_type, performed_by,
    old_state, new_state, reason, queue_version_after, undoes_event_id
  )
  values (
    p_route_id, p_entry_id, p_event_type, auth.uid(),
    p_old_state, p_new_state, p_reason, v_version, p_undoes
  )
  returning id into v_event_id;

  update public.queue_state set last_event_id = v_event_id where route_id = p_route_id;

  perform private.refresh_position_cache(p_route_id);

  if p_undoes is null then
    perform private.create_threshold_notifications(p_route_id, p_before, v_event_id);
  end if;

  return jsonb_build_object('event_id', v_event_id, 'queue_version', v_version);
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants: internals are callable only by their owner (inside SECURITY DEFINER
-- commands). RLS helpers from 0002 keep their explicit grant to authenticated.
-- ---------------------------------------------------------------------------

revoke all on function public.queue_effective_order(uuid) from public, anon, authenticated;

revoke all on function private.assert_operator(uuid) from public;
revoke all on function private.lock_queue(uuid) from public;
revoke all on function private.begin_entry_command(uuid) from public;
revoke all on function private.assert_status(public.queue_entry_status, public.queue_entry_status[]) from public;
revoke all on function private.next_join_sequence(uuid) from public;
revoke all on function private.next_priority_sequence(uuid) from public;
revoke all on function private.snapshot_waiting_positions(uuid) from public;
revoke all on function private.queue_snapshot(uuid, uuid[]) from public;
revoke all on function private.refresh_position_cache(uuid) from public;
revoke all on function private.create_threshold_notifications(uuid, jsonb, uuid) from public;
revoke all on function private.finish_mutation(uuid, uuid, public.queue_event_type, jsonb, jsonb, jsonb, text, uuid) from public;
