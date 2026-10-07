-- Triko queue entry commands (M3).
-- One command = one transaction: authorize -> lock route -> validate (queue-rules §5.1)
-- -> mutate -> private.finish_mutation. Each returns jsonb {event_id, queue_version, entry_id}.

-- ---------------------------------------------------------------------------
-- Shared driver eligibility (queue-rules §9 checks 2, 3, 6, 7; §7 rule 2)
-- ---------------------------------------------------------------------------

create function private.assert_driver_can_enter(
  p_driver_id    uuid,
  p_route_id     uuid,
  p_require_open boolean
)
returns public.drivers
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_driver     public.drivers;
  v_live_route uuid;
begin
  select d.* into v_driver
  from public.drivers d
  where d.id = p_driver_id;
  if not found then
    raise exception 'NOT_FOUND' using errcode = 'P0001';
  end if;

  if not v_driver.is_active or not exists (
    select 1 from public.profiles p where p.id = v_driver.profile_id and p.is_active
  ) then
    raise exception 'DRIVER_INACTIVE' using errcode = 'P0001';
  end if;

  select qe.route_id into v_live_route
  from public.queue_entries qe
  where qe.driver_id = p_driver_id
    and qe.status not in ('completed', 'cancelled', 'removed');
  if found then
    if v_live_route = p_route_id then
      raise exception 'ALREADY_IN_QUEUE' using errcode = 'P0001';
    end if;
    raise exception 'ALREADY_IN_OTHER_QUEUE' using errcode = 'P0001';
  end if;

  if p_require_open and exists (
    select 1 from public.routes r where r.id = p_route_id and r.queue_status <> 'open'
  ) then
    raise exception 'QUEUE_CLOSED' using errcode = 'P0001';
  end if;

  if not exists (
    select 1 from public.driver_route_assignments dra
    where dra.driver_id = p_driver_id
      and dra.route_id = p_route_id
      and dra.unassigned_at is null
  ) then
    raise exception 'DRIVER_NOT_ASSIGNED' using errcode = 'P0001';
  end if;

  return v_driver;
end;
$$;

-- ---------------------------------------------------------------------------
-- join_queue: operator ADD (QR join is a later milestone). — -> waiting
-- ---------------------------------------------------------------------------

create function public.join_queue(p_route_id uuid, p_driver_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_driver   public.drivers;
  v_before   jsonb;
  v_entry_id uuid;
begin
  perform private.assert_operator(p_route_id);
  perform private.lock_queue(p_route_id);

  -- §9 order: driver active -> no live entry anywhere -> queue open -> assigned.
  v_driver := private.assert_driver_can_enter(p_driver_id, p_route_id, true);

  v_before := private.snapshot_waiting_positions(p_route_id);

  begin
    insert into public.queue_entries (route_id, driver_id, tricycle_id, join_method, join_sequence)
    values (p_route_id, p_driver_id, v_driver.current_tricycle_id, 'operator',
            private.next_join_sequence(p_route_id))
    returning id into v_entry_id;
  exception when unique_violation then
    -- Concurrent join on another route won the one-live-entry index.
    raise exception 'ALREADY_IN_OTHER_QUEUE' using errcode = 'P0001';
  end;

  return private.finish_mutation(
    p_route_id, v_entry_id, 'QUEUE_JOINED',
    private.queue_snapshot(p_route_id, '{}'),
    private.queue_snapshot(p_route_id, array[v_entry_id]),
    v_before
  ) || jsonb_build_object('entry_id', v_entry_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- activate_queue_entry: waiting/priority -> active (next eligible, capacity free)
-- ---------------------------------------------------------------------------

create function public.activate_queue_entry(p_entry_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entry  public.queue_entries;
  v_route  public.routes;
  v_before jsonb;
  v_old    jsonb;
begin
  v_entry := private.begin_entry_command(p_entry_id);
  perform private.assert_status(v_entry.status, array['waiting', 'priority']::public.queue_entry_status[]);

  select * into v_route from public.routes where id = v_entry.route_id;
  if (select count(*) from public.queue_entries
      where route_id = v_entry.route_id and status = 'active') >= v_route.queue_capacity then
    raise exception 'CAPACITY_FULL' using errcode = 'P0001';
  end if;

  if not exists (
    select 1 from public.queue_effective_order(v_entry.route_id) o
    where o.entry_id = p_entry_id and o.is_next_eligible
  ) then
    raise exception 'NOT_NEXT_ELIGIBLE' using errcode = 'P0001';
  end if;

  v_before := private.snapshot_waiting_positions(v_entry.route_id);
  v_old    := private.queue_snapshot(v_entry.route_id, array[p_entry_id]);

  update public.queue_entries
  set status = 'active', activated_at = clock_timestamp()
  where id = p_entry_id;

  -- A returned/resumed driver's priority entitlement is consumed.
  update public.queue_reservations
  set status = 'used', used_at = now()
  where queue_entry_id = p_entry_id and status = 'active';

  return private.finish_mutation(
    v_entry.route_id, p_entry_id, 'QUEUE_ACTIVATED',
    v_old, private.queue_snapshot(v_entry.route_id, array[p_entry_id]), v_before
  ) || jsonb_build_object('entry_id', p_entry_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- complete_queue_entry: active -> completed (operator confirms departure)
-- ---------------------------------------------------------------------------

create function public.complete_queue_entry(p_entry_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entry  public.queue_entries;
  v_before jsonb;
  v_old    jsonb;
begin
  v_entry := private.begin_entry_command(p_entry_id);
  perform private.assert_status(v_entry.status, array['active']::public.queue_entry_status[]);

  v_before := private.snapshot_waiting_positions(v_entry.route_id);
  v_old    := private.queue_snapshot(v_entry.route_id, array[p_entry_id]);

  update public.queue_entries
  set status = 'completed', activated_at = null, ended_at = now()
  where id = p_entry_id;

  return private.finish_mutation(
    v_entry.route_id, p_entry_id, 'DRIVER_LEFT',
    v_old, private.queue_snapshot(v_entry.route_id, array[p_entry_id]), v_before
  ) || jsonb_build_object('entry_id', p_entry_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- reserve_queue_entry: waiting -> reserved (absent decision, new priority number)
-- ---------------------------------------------------------------------------

create function public.reserve_queue_entry(p_entry_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entry  public.queue_entries;
  v_before jsonb;
  v_old    jsonb;
begin
  v_entry := private.begin_entry_command(p_entry_id);
  perform private.assert_status(v_entry.status, array['waiting']::public.queue_entry_status[]);

  v_before := private.snapshot_waiting_positions(v_entry.route_id);
  v_old    := private.queue_snapshot(v_entry.route_id, array[p_entry_id]);

  update public.queue_entries set status = 'reserved' where id = p_entry_id;

  insert into public.queue_reservations (route_id, queue_entry_id, priority_sequence, source, created_by)
  values (v_entry.route_id, p_entry_id, private.next_priority_sequence(v_entry.route_id), 'absent', auth.uid());

  return private.finish_mutation(
    v_entry.route_id, p_entry_id, 'DRIVER_RESERVED',
    v_old, private.queue_snapshot(v_entry.route_id, array[p_entry_id]), v_before
  ) || jsonb_build_object('entry_id', p_entry_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- return_reserved_driver: reserved -> priority (keeps priority_sequence)
-- ---------------------------------------------------------------------------

create function public.return_reserved_driver(p_entry_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entry  public.queue_entries;
  v_before jsonb;
  v_old    jsonb;
begin
  v_entry := private.begin_entry_command(p_entry_id);
  perform private.assert_status(v_entry.status, array['reserved']::public.queue_entry_status[]);

  v_before := private.snapshot_waiting_positions(v_entry.route_id);
  v_old    := private.queue_snapshot(v_entry.route_id, array[p_entry_id]);

  update public.queue_entries set status = 'priority' where id = p_entry_id;
  update public.queue_reservations
  set returned_at = now()
  where queue_entry_id = p_entry_id and status = 'active';

  return private.finish_mutation(
    v_entry.route_id, p_entry_id, 'DRIVER_RETURNED',
    v_old, private.queue_snapshot(v_entry.route_id, array[p_entry_id]), v_before
  ) || jsonb_build_object('entry_id', p_entry_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- mark_priority_absent: priority -> reserved (keeps ORIGINAL priority_sequence, §5.2.1)
-- ---------------------------------------------------------------------------

create function public.mark_priority_absent(p_entry_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entry  public.queue_entries;
  v_before jsonb;
  v_old    jsonb;
begin
  v_entry := private.begin_entry_command(p_entry_id);
  perform private.assert_status(v_entry.status, array['priority']::public.queue_entry_status[]);

  v_before := private.snapshot_waiting_positions(v_entry.route_id);
  v_old    := private.queue_snapshot(v_entry.route_id, array[p_entry_id]);

  update public.queue_entries set status = 'reserved' where id = p_entry_id;

  return private.finish_mutation(
    v_entry.route_id, p_entry_id, 'DRIVER_ABSENT_AGAIN',
    v_old, private.queue_snapshot(v_entry.route_id, array[p_entry_id]), v_before
  ) || jsonb_build_object('entry_id', p_entry_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- move_queue_entry_to_last: waiting -> waiting (new join_sequence, new notification cycle)
-- ---------------------------------------------------------------------------

create function public.move_queue_entry_to_last(p_entry_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entry  public.queue_entries;
  v_before jsonb;
  v_old    jsonb;
begin
  v_entry := private.begin_entry_command(p_entry_id);
  perform private.assert_status(v_entry.status, array['waiting']::public.queue_entry_status[]);

  v_before := private.snapshot_waiting_positions(v_entry.route_id);
  v_old    := private.queue_snapshot(v_entry.route_id, array[p_entry_id]);

  update public.queue_entries
  set join_sequence      = private.next_join_sequence(v_entry.route_id),
      notification_cycle = notification_cycle + 1
  where id = p_entry_id;

  return private.finish_mutation(
    v_entry.route_id, p_entry_id, 'DRIVER_MOVED_TO_LAST',
    v_old, private.queue_snapshot(v_entry.route_id, array[p_entry_id]), v_before
  ) || jsonb_build_object('entry_id', p_entry_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- cancel / remove: any non-terminal -> cancelled / removed (cancels the reservation)
-- ---------------------------------------------------------------------------

create function private.end_queue_entry(
  p_entry_id   uuid,
  p_status     public.queue_entry_status,
  p_event_type public.queue_event_type,
  p_reason     text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entry  public.queue_entries;
  v_before jsonb;
  v_old    jsonb;
begin
  v_entry := private.begin_entry_command(p_entry_id);
  perform private.assert_status(
    v_entry.status,
    array['waiting', 'active', 'reserved', 'priority', 'suspended']::public.queue_entry_status[]
  );

  v_before := private.snapshot_waiting_positions(v_entry.route_id);
  v_old    := private.queue_snapshot(v_entry.route_id, array[p_entry_id]);

  update public.queue_entries
  set status = p_status, activated_at = null, ended_at = now()
  where id = p_entry_id;

  update public.queue_reservations
  set status = 'cancelled', cancelled_at = now()
  where queue_entry_id = p_entry_id and status = 'active';

  return private.finish_mutation(
    v_entry.route_id, p_entry_id, p_event_type,
    v_old, private.queue_snapshot(v_entry.route_id, array[p_entry_id]), v_before, p_reason
  ) || jsonb_build_object('entry_id', p_entry_id);
end;
$$;

create function public.cancel_queue_entry(p_entry_id uuid, p_reason text default null)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select private.end_queue_entry(p_entry_id, 'cancelled', 'DRIVER_CANCELLED', p_reason);
$$;

-- Correction only (duplicate, wrong driver, test) — not in the normal operator menu.
create function public.remove_queue_entry(p_entry_id uuid, p_reason text default null)
returns jsonb
language sql
security definer
set search_path = ''
as $$
  select private.end_queue_entry(p_entry_id, 'removed', 'DRIVER_REMOVED', p_reason);
$$;

-- ---------------------------------------------------------------------------
-- suspend_queue_entry: active -> suspended (slot freed immediately)
-- ---------------------------------------------------------------------------

create function public.suspend_queue_entry(p_entry_id uuid, p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entry  public.queue_entries;
  v_before jsonb;
  v_old    jsonb;
begin
  v_entry := private.begin_entry_command(p_entry_id);
  perform private.assert_status(v_entry.status, array['active']::public.queue_entry_status[]);

  v_before := private.snapshot_waiting_positions(v_entry.route_id);
  v_old    := private.queue_snapshot(v_entry.route_id, array[p_entry_id]);

  update public.queue_entries set status = 'suspended', activated_at = null where id = p_entry_id;

  return private.finish_mutation(
    v_entry.route_id, p_entry_id, 'DRIVER_SUSPENDED',
    v_old, private.queue_snapshot(v_entry.route_id, array[p_entry_id]), v_before, p_reason
  ) || jsonb_build_object('entry_id', p_entry_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- resume_queue_entry: suspended -> priority (new priority number at the end of PRIORITY)
-- ---------------------------------------------------------------------------

create function public.resume_queue_entry(p_entry_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entry  public.queue_entries;
  v_before jsonb;
  v_old    jsonb;
begin
  v_entry := private.begin_entry_command(p_entry_id);
  perform private.assert_status(v_entry.status, array['suspended']::public.queue_entry_status[]);

  v_before := private.snapshot_waiting_positions(v_entry.route_id);
  v_old    := private.queue_snapshot(v_entry.route_id, array[p_entry_id]);

  update public.queue_entries set status = 'priority' where id = p_entry_id;

  insert into public.queue_reservations (
    route_id, queue_entry_id, priority_sequence, source, created_by, returned_at
  )
  values (
    v_entry.route_id, p_entry_id, private.next_priority_sequence(v_entry.route_id),
    'resumed', auth.uid(), now()
  );

  return private.finish_mutation(
    v_entry.route_id, p_entry_id, 'DRIVER_RESUMED',
    v_old, private.queue_snapshot(v_entry.route_id, array[p_entry_id]), v_before
  ) || jsonb_build_object('entry_id', p_entry_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- transfer_queue_entry (queue-rules §7): waiting sender keeps his entry and goes
-- last; target gets a NEW entry at the sender's place that can never transfer on.
-- ---------------------------------------------------------------------------

create function public.transfer_queue_entry(p_entry_id uuid, p_target_driver_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entry       public.queue_entries;
  v_target      public.drivers;
  v_order       record;
  v_before      jsonb;
  v_old         jsonb;
  v_new_seq     bigint;
  v_target_id   uuid;
  v_transfer_id uuid;
begin
  v_entry := private.begin_entry_command(p_entry_id);
  perform private.assert_status(v_entry.status, array['waiting']::public.queue_entry_status[]);

  if v_entry.transfer_used then
    raise exception 'TRANSFER_NOT_ALLOWED' using errcode = 'P0001';
  end if;

  select d.* into v_target from public.drivers d where d.id = p_target_driver_id;
  if found and v_target.id = v_entry.driver_id then
    raise exception 'TRANSFER_NOT_ALLOWED' using errcode = 'P0001';
  end if;
  -- CLOSED blocks new joins only (§5.2.4), not transfers.
  v_target := private.assert_driver_can_enter(p_target_driver_id, v_entry.route_id, false);

  select o.overall_position, o.waiting_position into v_order
  from public.queue_effective_order(v_entry.route_id) o
  where o.entry_id = p_entry_id;

  v_before := private.snapshot_waiting_positions(v_entry.route_id);
  v_old    := private.queue_snapshot(v_entry.route_id, array[p_entry_id]);

  -- Sender first, so the inherited join_sequence is free for the target.
  v_new_seq := private.next_join_sequence(v_entry.route_id);
  update public.queue_entries
  set join_sequence      = v_new_seq,
      transfer_used      = true,
      notification_cycle = notification_cycle + 1
  where id = p_entry_id;

  begin
    insert into public.queue_entries (
      route_id, driver_id, tricycle_id, join_method, join_sequence,
      transfer_origin_entry_id, transfer_used
    )
    values (
      v_entry.route_id, p_target_driver_id, v_target.current_tricycle_id, 'transfer',
      v_entry.join_sequence, p_entry_id, true
    )
    returning id into v_target_id;
  exception when unique_violation then
    raise exception 'ALREADY_IN_OTHER_QUEUE' using errcode = 'P0001';
  end;

  insert into public.queue_transfers (
    route_id, source_entry_id, source_driver_id, target_entry_id, target_driver_id,
    original_join_sequence, original_overall_position, original_waiting_position,
    sender_new_join_sequence, created_by
  )
  values (
    v_entry.route_id, p_entry_id, v_entry.driver_id, v_target_id, p_target_driver_id,
    v_entry.join_sequence, v_order.overall_position, v_order.waiting_position,
    v_new_seq, auth.uid()
  )
  returning id into v_transfer_id;

  return private.finish_mutation(
    v_entry.route_id, p_entry_id, 'DRIVER_TRANSFERRED',
    v_old,
    private.queue_snapshot(v_entry.route_id, array[p_entry_id, v_target_id])
      || jsonb_build_object('transfer_id', v_transfer_id),
    v_before
  ) || jsonb_build_object('entry_id', p_entry_id, 'target_entry_id', v_target_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke all on function private.assert_driver_can_enter(uuid, uuid, boolean) from public;
revoke all on function private.end_queue_entry(uuid, public.queue_entry_status, public.queue_event_type, text) from public;

revoke all on function public.join_queue(uuid, uuid) from public, anon;
revoke all on function public.activate_queue_entry(uuid) from public, anon;
revoke all on function public.complete_queue_entry(uuid) from public, anon;
revoke all on function public.reserve_queue_entry(uuid) from public, anon;
revoke all on function public.return_reserved_driver(uuid) from public, anon;
revoke all on function public.mark_priority_absent(uuid) from public, anon;
revoke all on function public.move_queue_entry_to_last(uuid) from public, anon;
revoke all on function public.cancel_queue_entry(uuid, text) from public, anon;
revoke all on function public.remove_queue_entry(uuid, text) from public, anon;
revoke all on function public.suspend_queue_entry(uuid, text) from public, anon;
revoke all on function public.resume_queue_entry(uuid) from public, anon;
revoke all on function public.transfer_queue_entry(uuid, uuid) from public, anon;

grant execute on function public.join_queue(uuid, uuid) to authenticated;
grant execute on function public.activate_queue_entry(uuid) to authenticated;
grant execute on function public.complete_queue_entry(uuid) to authenticated;
grant execute on function public.reserve_queue_entry(uuid) to authenticated;
grant execute on function public.return_reserved_driver(uuid) to authenticated;
grant execute on function public.mark_priority_absent(uuid) to authenticated;
grant execute on function public.move_queue_entry_to_last(uuid) to authenticated;
grant execute on function public.cancel_queue_entry(uuid, text) to authenticated;
grant execute on function public.remove_queue_entry(uuid, text) to authenticated;
grant execute on function public.suspend_queue_entry(uuid, text) to authenticated;
grant execute on function public.resume_queue_entry(uuid) to authenticated;
grant execute on function public.transfer_queue_entry(uuid, uuid) to authenticated;
