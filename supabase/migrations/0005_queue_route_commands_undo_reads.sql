-- Triko route-level commands, undo, and read RPCs (M3).
-- QR join / QR sessions and Realtime broadcast are later milestones.

-- ---------------------------------------------------------------------------
-- Route-level commands share one shape: authorize -> lock -> validate -> update route.
-- ---------------------------------------------------------------------------

create function private.route_command(
  p_route_id   uuid,
  p_event_type public.queue_event_type,
  p_capacity   integer default null,
  p_status     public.route_queue_status default null,
  p_qr_enabled boolean default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_route  public.routes;
  v_before jsonb;
  v_old    jsonb;
begin
  perform private.assert_operator(p_route_id);
  v_route := private.lock_queue(p_route_id);

  if p_capacity is not null and (p_capacity < 1 or p_capacity > 50) then
    raise exception 'INVALID_CAPACITY' using errcode = 'P0001';
  end if;
  if (p_capacity is not null and p_capacity = v_route.queue_capacity)
     or (p_status is not null and p_status = v_route.queue_status)
     or (p_qr_enabled is not null and p_qr_enabled = v_route.qr_enabled) then
    raise exception 'INVALID_TRANSITION' using errcode = 'P0001';
  end if;

  v_before := private.snapshot_waiting_positions(p_route_id);
  v_old    := private.queue_snapshot(p_route_id, '{}');

  -- Capacity never ejects an active driver (§8); activation is never automatic.
  update public.routes
  set queue_capacity = coalesce(p_capacity, queue_capacity),
      queue_status   = coalesce(p_status, queue_status),
      qr_enabled     = coalesce(p_qr_enabled, qr_enabled)
  where id = p_route_id;

  return private.finish_mutation(
    p_route_id, null, p_event_type,
    v_old, private.queue_snapshot(p_route_id, '{}'), v_before
  );
end;
$$;

-- Returns over_capacity_count so the operator sees the §8 warning.
create function public.change_queue_capacity(p_route_id uuid, p_capacity integer)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  v_result := private.route_command(p_route_id, 'QUEUE_CAPACITY_CHANGED', p_capacity => p_capacity);
  return v_result || jsonb_build_object(
    'over_capacity_count',
    greatest((select count(*) from public.queue_entries
              where route_id = p_route_id and status = 'active') - p_capacity, 0)
  );
end;
$$;

create function public.open_queue(p_route_id uuid)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select private.route_command(p_route_id, 'QUEUE_OPENED', p_status => 'open');
$$;

-- CLOSED blocks new joins only; every other command keeps working (§5.2.4).
create function public.close_queue(p_route_id uuid)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select private.route_command(p_route_id, 'QUEUE_CLOSED', p_status => 'closed');
$$;

create function public.enable_qr(p_route_id uuid)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select private.route_command(p_route_id, 'QR_ENABLED', p_qr_enabled => true);
$$;

create function public.disable_qr(p_route_id uuid)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select private.route_command(p_route_id, 'QR_DISABLED', p_qr_enabled => false);
$$;

-- ---------------------------------------------------------------------------
-- undo_queue_event (queue-rules §6): latest route event only, 30 s, never an undo,
-- restores old_state, records UNDO_PERFORMED, sends no notifications.
-- ---------------------------------------------------------------------------

create function public.undo_queue_event(p_event_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_event    public.queue_events;
  v_old      jsonb;
  v_new      jsonb;
  v_touched  uuid[];
  v_inserted uuid[];
  v_before   jsonb;
begin
  select * into v_event from public.queue_events where id = p_event_id;
  if not found then
    raise exception 'NOT_FOUND' using errcode = 'P0001';
  end if;

  perform private.assert_operator(v_event.route_id);
  perform private.lock_queue(v_event.route_id);

  if v_event.event_type = 'UNDO_PERFORMED' then
    raise exception 'UNDO_NOT_ALLOWED' using errcode = 'P0001';
  end if;
  if (select last_event_id from public.queue_state where route_id = v_event.route_id)
     is distinct from p_event_id then
    raise exception 'UNDO_NOT_LATEST' using errcode = 'P0001';
  end if;
  if v_event.created_at < now() - interval '30 seconds' then
    raise exception 'UNDO_EXPIRED' using errcode = 'P0001';
  end if;

  v_old := v_event.old_state;
  v_new := v_event.new_state;

  select coalesce(array_agg(distinct (e ->> 'id')::uuid), '{}') into v_touched
  from (
    select jsonb_array_elements(v_old -> 'entries') as e
    union all
    select jsonb_array_elements(v_new -> 'entries')
  ) s;

  -- Entries the event created (join, transfer recipient): ended as a correction.
  select coalesce(array_agg((e ->> 'id')::uuid), '{}') into v_inserted
  from jsonb_array_elements(v_new -> 'entries') e
  where not exists (
    select 1 from jsonb_array_elements(v_old -> 'entries') o where o ->> 'id' = e ->> 'id'
  );

  v_before := private.queue_snapshot(v_event.route_id, v_touched);

  begin
    update public.queue_entries
    set status = 'removed', activated_at = null, ended_at = now()
    where id = any (v_inserted);

    -- Reservations the event created.
    update public.queue_reservations
    set status = 'cancelled', cancelled_at = now()
    where queue_entry_id = any (v_touched)
      and status = 'active'
      and id not in (
        select (r ->> 'id')::uuid from jsonb_array_elements(v_old -> 'reservations') r
      );

    update public.queue_entries qe
    set status             = o.status,
        join_sequence      = o.join_sequence,
        activated_at       = o.activated_at,
        transfer_used      = o.transfer_used,
        notification_cycle = o.notification_cycle,
        ended_at           = o.ended_at
    from jsonb_populate_recordset(null::public.queue_entries, v_old -> 'entries') o
    where qe.id = o.id;

    update public.queue_reservations qr
    set status            = o.status,
        priority_sequence = o.priority_sequence,
        returned_at       = o.returned_at,
        used_at           = o.used_at,
        cancelled_at      = o.cancelled_at
    from jsonb_populate_recordset(null::public.queue_reservations, v_old -> 'reservations') o
    where qr.id = o.id;

    update public.routes
    set queue_capacity = (v_old -> 'route' ->> 'queue_capacity')::integer,
        queue_status   = (v_old -> 'route' ->> 'queue_status')::public.route_queue_status,
        qr_enabled     = (v_old -> 'route' ->> 'qr_enabled')::boolean
    where id = v_event.route_id;

    if v_event.event_type = 'DRIVER_TRANSFERRED' then
      update public.queue_transfers
      set undone_at = now()
      where id = (v_new ->> 'transfer_id')::uuid;
    end if;
  exception when unique_violation then
    -- A restored driver has since joined another queue.
    raise exception 'UNDO_NOT_ALLOWED' using errcode = 'P0001';
  end;

  return private.finish_mutation(
    v_event.route_id, v_event.queue_entry_id, 'UNDO_PERFORMED',
    v_before, private.queue_snapshot(v_event.route_id, v_touched),
    null, null, p_event_id
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Read RPCs
-- ---------------------------------------------------------------------------

-- Operator view: full order with identities (route operators / admin only).
create function public.get_route_queue(p_route_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  perform private.assert_operator(p_route_id);

  select jsonb_build_object(
    'route', jsonb_build_object(
      'id', r.id, 'name', r.name, 'queue_capacity', r.queue_capacity,
      'queue_status', r.queue_status, 'qr_enabled', r.qr_enabled
    ),
    'queue_version', qs.queue_version,
    'active_count', (select count(*) from public.queue_entries
                     where route_id = r.id and status = 'active'),
    'last_event', (
      select jsonb_build_object(
        'id', e.id, 'event_type', e.event_type, 'created_at', e.created_at,
        'undoable_until', case when e.event_type <> 'UNDO_PERFORMED'
                               then e.created_at + interval '30 seconds' end
      )
      from public.queue_events e where e.id = qs.last_event_id
    ),
    'entries', coalesce((
      select jsonb_agg(jsonb_build_object(
        'entry_id', o.entry_id,
        'driver_id', o.driver_id,
        'driver_code', d.driver_code,
        'display_name', p.display_name,
        'tricycle_number', t.tricycle_number,
        'status', o.status,
        'lane', o.lane,
        'overall_position', o.overall_position,
        'waiting_position', o.waiting_position,
        'waiting_ahead', o.waiting_ahead,
        'reservation_priority', o.reservation_priority,
        'active_slot', o.active_slot,
        'is_next_eligible', o.is_next_eligible,
        'transfer_used', qe.transfer_used
      ) order by o.overall_position nulls last, o.reservation_priority nulls last, qe.join_sequence)
      from public.queue_effective_order(r.id) o
      join public.queue_entries qe on qe.id = o.entry_id
      join public.drivers d on d.id = o.driver_id
      join public.profiles p on p.id = d.profile_id
      left join public.tricycles t on t.id = qe.tricycle_id
    ), '[]'::jsonb)
  )
  into v_result
  from public.routes r
  join public.queue_state qs on qs.route_id = r.id
  where r.id = p_route_id;

  return v_result;
end;
$$;

-- Driver view: only the caller's own entry, never other drivers' identities.
create function public.get_my_queue_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_driver_id uuid := private.current_driver_id();
  v_entry     public.queue_entries;
  v_route_id  uuid;
begin
  if v_driver_id is null then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;

  select * into v_entry
  from public.queue_entries
  where driver_id = v_driver_id and status not in ('completed', 'cancelled', 'removed');

  v_route_id := coalesce(v_entry.route_id, private.current_driver_route_id());

  return jsonb_build_object(
    'route', (
      select jsonb_build_object('id', r.id, 'name', r.name, 'queue_status', r.queue_status)
      from public.routes r where r.id = v_route_id
    ),
    'queue_version', (select qs.queue_version from public.queue_state qs where qs.route_id = v_route_id),
    'entry', (
      select jsonb_build_object(
        'entry_id', o.entry_id,
        'status', o.status,
        'lane', o.lane,
        'overall_position', o.overall_position,
        'waiting_position', o.waiting_position,
        'waiting_ahead', o.waiting_ahead,
        'reservation_priority', o.reservation_priority,
        'active_slot', o.active_slot,
        'is_next_eligible', o.is_next_eligible
      )
      from public.queue_effective_order(v_entry.route_id) o
      where o.entry_id = v_entry.id
    )
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke all on function private.route_command(uuid, public.queue_event_type, integer, public.route_queue_status, boolean) from public;

revoke all on function public.change_queue_capacity(uuid, integer) from public, anon;
revoke all on function public.open_queue(uuid) from public, anon;
revoke all on function public.close_queue(uuid) from public, anon;
revoke all on function public.enable_qr(uuid) from public, anon;
revoke all on function public.disable_qr(uuid) from public, anon;
revoke all on function public.undo_queue_event(uuid) from public, anon;
revoke all on function public.get_route_queue(uuid) from public, anon;
revoke all on function public.get_my_queue_status() from public, anon;

grant execute on function public.change_queue_capacity(uuid, integer) to authenticated;
grant execute on function public.open_queue(uuid) to authenticated;
grant execute on function public.close_queue(uuid) to authenticated;
grant execute on function public.enable_qr(uuid) to authenticated;
grant execute on function public.disable_qr(uuid) to authenticated;
grant execute on function public.undo_queue_event(uuid) to authenticated;
grant execute on function public.get_route_queue(uuid) to authenticated;
grant execute on function public.get_my_queue_status() to authenticated;
