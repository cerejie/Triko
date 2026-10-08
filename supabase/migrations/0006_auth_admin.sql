-- Triko auth support (M4): login throttling and driver-admin commands.
-- Every function here is called only by Edge Functions holding the secret key
-- (service_role). The service role has no auth.uid(), so admin commands take the
-- caller (p_actor) explicitly; the Edge Function derives it from a verified JWT.
-- queue-rules §12.

-- ---------------------------------------------------------------------------
-- Authorization helper
-- ---------------------------------------------------------------------------

-- True when p_actor is an active admin, or an active operator with an active
-- assignment to the route. Mirrors private.operator_has_route for an explicit actor.
create function private.can_manage_route(p_actor uuid, p_route uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = p_actor
      and p.is_active
      and (
        p.role = 'admin'
        or (p.role = 'operator' and exists (
          select 1 from public.operator_route_assignments ora
          where ora.operator_id = p_actor and ora.route_id = p_route and ora.is_active
        ))
      )
  );
$$;

-- ---------------------------------------------------------------------------
-- Login throttling (queue-rules §12)
-- Per account: 5 consecutive failures since the last success lock for 1 min;
-- each further failure escalates to 5, 15, then 60 min (cap), counted from the
-- latest failure. Per device: 10 failures within 15 min lock for 15 min.
-- Unknown codes are throttled the same way, so responses never reveal existence.
-- ---------------------------------------------------------------------------

create function public.login_throttle_status(p_driver_code text, p_device_id text default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_code          text := upper(trim(coalesce(p_driver_code, '')));
  v_last_success  timestamptz;
  v_fails         integer;
  v_last_fail     timestamptz;
  v_until         timestamptz := '-infinity';
  v_retry         integer;
begin
  select max(a.attempted_at) into v_last_success
  from public.auth_login_attempts a
  where a.driver_code = v_code and a.succeeded;

  select count(*)::integer, max(a.attempted_at) into v_fails, v_last_fail
  from public.auth_login_attempts a
  where a.driver_code = v_code
    and not a.succeeded
    and a.attempted_at > coalesce(v_last_success, '-infinity');

  if v_fails >= 5 then
    v_until := v_last_fail + case least(v_fails - 5, 3)
      when 0 then interval '1 minute'
      when 1 then interval '5 minutes'
      when 2 then interval '15 minutes'
      else interval '60 minutes'
    end;
  end if;

  if p_device_id is not null then
    select count(*)::integer, max(a.attempted_at) into v_fails, v_last_fail
    from public.auth_login_attempts a
    where a.device_id = p_device_id
      and not a.succeeded
      and a.attempted_at > now() - interval '15 minutes';

    if v_fails >= 10 then
      v_until := greatest(v_until, v_last_fail + interval '15 minutes');
    end if;
  end if;

  v_retry := greatest(ceil(extract(epoch from (v_until - now())))::integer, 0);

  return jsonb_build_object('locked', v_retry > 0, 'retry_after_seconds', v_retry);
end;
$$;

create function public.record_login_attempt(p_driver_code text, p_device_id text, p_succeeded boolean)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.auth_login_attempts (driver_code, device_id, succeeded)
  values (upper(trim(coalesce(p_driver_code, ''))), nullif(left(p_device_id, 200), ''), p_succeeded);
$$;

-- True when the code belongs to an active driver with an active driver profile.
create function public.login_account_active(p_driver_code text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.drivers d
    join public.profiles p on p.id = d.profile_id
    where d.driver_code = upper(trim(coalesce(p_driver_code, '')))
      and d.is_active and p.is_active and p.role = 'driver'
  );
$$;

-- ---------------------------------------------------------------------------
-- Driver admin (queue-rules §12). Driver Code and PIN are server-generated.
-- Flow in driver-admin: prepare_create -> auth.admin.createUser -> create_driver;
-- the Edge Function deletes the auth user if create_driver fails.
-- ---------------------------------------------------------------------------

-- Checks permission and returns the next free DRV-NNN code.
create function public.driver_admin_prepare_create(p_actor uuid, p_route_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_next integer;
begin
  if not exists (select 1 from public.routes r where r.id = p_route_id) then
    raise exception 'NOT_FOUND' using errcode = 'P0001';
  end if;
  if not private.can_manage_route(p_actor, p_route_id) then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;

  select coalesce(max(substring(d.driver_code from '^DRV-([0-9]+)$')::integer), 0) + 1 into v_next
  from public.drivers d
  where d.driver_code ~ '^DRV-[0-9]{1,6}$';

  return jsonb_build_object('driver_code', 'DRV-' || lpad(v_next::text, 3, '0'));
end;
$$;

-- Creates profile, tricycle (or reuses a free one), driver and both assignments
-- for an auth user just created by driver-admin. One transaction.
create function public.driver_admin_create_driver(
  p_actor            uuid,
  p_user_id          uuid,
  p_driver_code      text,
  p_display_name     text,
  p_phone_number     text,
  p_tricycle_number  text,
  p_route_id         uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name      text := trim(coalesce(p_display_name, ''));
  v_phone     text := nullif(trim(coalesce(p_phone_number, '')), '');
  v_tricycle  text := upper(trim(coalesce(p_tricycle_number, '')));
  v_tri_id    uuid;
  v_tri_live  boolean;
  v_driver_id uuid;
begin
  if not exists (select 1 from public.routes r where r.id = p_route_id) then
    raise exception 'NOT_FOUND' using errcode = 'P0001';
  end if;
  if not private.can_manage_route(p_actor, p_route_id) then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;

  if coalesce(p_driver_code, '') !~ '^[A-Z]{2,5}-[0-9]{1,6}$'
     or length(v_name) not between 1 and 80
     or (v_phone is not null and v_phone !~ '^[0-9+][0-9]{6,14}$')
     or v_tricycle !~ '^[A-Z0-9][A-Z0-9-]{1,19}$' then
    raise exception 'INVALID_INPUT' using errcode = 'P0001';
  end if;

  -- The auth user must exist and not already be linked to a profile.
  if not exists (select 1 from auth.users u where u.id = p_user_id)
     or exists (select 1 from public.profiles p where p.id = p_user_id) then
    raise exception 'INVALID_INPUT' using errcode = 'P0001';
  end if;

  -- [ASSUMPTION] queue-rules §15: a tricycle with an open assignment is not shared.
  select t.id, t.is_active into v_tri_id, v_tri_live
  from public.tricycles t
  where t.tricycle_number = v_tricycle
  for update;

  if v_tri_id is not null then
    if not v_tri_live then
      raise exception 'INVALID_INPUT' using errcode = 'P0001';
    end if;
    if exists (select 1 from public.driver_tricycle_assignments a
               where a.tricycle_id = v_tri_id and a.unassigned_at is null) then
      raise exception 'TRICYCLE_IN_USE' using errcode = 'P0001';
    end if;
  else
    insert into public.tricycles (tricycle_number) values (v_tricycle) returning id into v_tri_id;
  end if;

  insert into public.profiles (id, role, display_name, phone_number)
  values (p_user_id, 'driver', v_name, v_phone);

  begin
    insert into public.drivers (profile_id, driver_code, current_tricycle_id, current_route_id)
    values (p_user_id, p_driver_code, v_tri_id, p_route_id)
    returning id into v_driver_id;
  exception when unique_violation then
    -- A concurrent create took the code; driver-admin retries with a fresh one.
    raise exception 'DRIVER_CODE_TAKEN' using errcode = 'P0001';
  end;

  insert into public.driver_tricycle_assignments (driver_id, tricycle_id, assigned_by)
  values (v_driver_id, v_tri_id, p_actor);

  insert into public.driver_route_assignments (driver_id, route_id, assigned_by)
  values (v_driver_id, p_route_id, p_actor);

  return jsonb_build_object(
    'driver_id', v_driver_id,
    'profile_id', p_user_id,
    'tricycle_id', v_tri_id,
    'driver_code', p_driver_code
  );
end;
$$;

-- Checks that p_actor may reset this driver's PIN; returns the auth user id.
create function public.driver_admin_authorize_reset(p_actor uuid, p_driver_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_driver public.drivers;
begin
  select * into v_driver from public.drivers d where d.id = p_driver_id;
  if v_driver.id is null then
    raise exception 'NOT_FOUND' using errcode = 'P0001';
  end if;
  if not private.can_manage_route(p_actor, v_driver.current_route_id) then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;
  if not v_driver.is_active then
    raise exception 'DRIVER_INACTIVE' using errcode = 'P0001';
  end if;

  return jsonb_build_object('profile_id', v_driver.profile_id, 'driver_code', v_driver.driver_code);
end;
$$;

-- ---------------------------------------------------------------------------
-- Grants: service_role (Edge Functions) only. Supabase's default privileges
-- grant EXECUTE on new public functions to anon/authenticated, so revoke both.
-- ---------------------------------------------------------------------------

revoke all on function private.can_manage_route(uuid, uuid) from public, anon, authenticated;
revoke all on function public.login_throttle_status(text, text) from public, anon, authenticated;
revoke all on function public.record_login_attempt(text, text, boolean) from public, anon, authenticated;
revoke all on function public.login_account_active(text) from public, anon, authenticated;
revoke all on function public.driver_admin_prepare_create(uuid, uuid) from public, anon, authenticated;
revoke all on function public.driver_admin_create_driver(uuid, uuid, text, text, text, text, uuid) from public, anon, authenticated;
revoke all on function public.driver_admin_authorize_reset(uuid, uuid) from public, anon, authenticated;

grant usage on schema private to service_role;
grant execute on function private.can_manage_route(uuid, uuid) to service_role;
grant execute on function public.login_throttle_status(text, text) to service_role;
grant execute on function public.record_login_attempt(text, text, boolean) to service_role;
grant execute on function public.login_account_active(text) to service_role;
grant execute on function public.driver_admin_prepare_create(uuid, uuid) to service_role;
grant execute on function public.driver_admin_create_driver(uuid, uuid, text, text, text, text, uuid) to service_role;
grant execute on function public.driver_admin_authorize_reset(uuid, uuid) to service_role;
