-- Shared pgTAP helpers (local test database only; committed so later files can use them).
-- Seed fixtures: operator ...0001, route a1 Magpet (open, cap 3, DRV-001..010),
-- route a2 Matalam (closed, DRV-011..020).

begin;
create extension if not exists pgtap with schema extensions;
create schema if not exists tests;

create or replace function tests.route() returns uuid language sql immutable as
$$ select '00000000-0000-4000-8000-0000000000a1'::uuid $$;

create or replace function tests.route2() returns uuid language sql immutable as
$$ select '00000000-0000-4000-8000-0000000000a2'::uuid $$;

create or replace function tests.operator_id() returns uuid language sql immutable as
$$ select '00000000-0000-4000-8000-000000000001'::uuid $$;

create or replace function tests.code(i integer) returns text language sql immutable as
$$ select 'DRV-' || lpad(i::text, 3, '0') $$;

-- Act as a user for auth.uid() (role stays superuser; 011 switches roles explicitly).
create or replace function tests.as_user(p_uid uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    case when p_uid is null then '' else json_build_object('sub', p_uid, 'role', 'authenticated')::text end,
    true);
end $$;

create or replace function tests.as_operator() returns void language sql as
$$ select tests.as_user(tests.operator_id()) $$;

create or replace function tests.driver(p_code text) returns uuid language sql stable security definer as
$$ select id from public.drivers where driver_code = p_code $$;

create or replace function tests.profile(p_code text) returns uuid language sql stable security definer as
$$ select profile_id from public.drivers where driver_code = p_code $$;

-- The driver's live entry, else their latest one.
create or replace function tests.entry(p_code text) returns uuid language sql stable security definer as $$
  select qe.id from public.queue_entries qe
  where qe.driver_id = tests.driver(p_code)
  order by (qe.status in ('completed', 'cancelled', 'removed')), qe.join_sequence desc
  limit 1
$$;

create or replace function tests.join(p_code text, p_route uuid default null) returns uuid language sql as
$$ select (public.join_queue(coalesce(p_route, tests.route()), tests.driver(p_code)) ->> 'entry_id')::uuid $$;

-- Join DRV-001..DRV-<n> in order.
create or replace function tests.fill(n integer) returns void language plpgsql as $$
begin
  for i in 1..n loop
    perform tests.join(tests.code(i));
  end loop;
end $$;

-- The driver's row from queue_effective_order as jsonb (compare with ->>).
create or replace function tests.ord(p_code text) returns jsonb language sql stable as $$
  select to_jsonb(o) from public.queue_effective_order(
    (select route_id from public.queue_entries where id = tests.entry(p_code))
  ) o where o.entry_id = tests.entry(p_code)
$$;

create or replace function tests.status(p_code text) returns text language sql stable as
$$ select status::text from public.queue_entries where id = tests.entry(p_code) $$;

create or replace function tests.version(p_route uuid default null) returns bigint language sql stable as
$$ select queue_version from public.queue_state where route_id = coalesce(p_route, tests.route()) $$;

create or replace function tests.last_event(p_route uuid default null) returns uuid language sql stable as
$$ select last_event_id from public.queue_state where route_id = coalesce(p_route, tests.route()) $$;

create or replace function tests.undo_last(p_route uuid default null) returns jsonb language sql as
$$ select public.undo_queue_event(tests.last_event(p_route)) $$;

create or replace function tests.notif_count(p_code text default null, p_threshold integer default null)
returns integer language sql stable as $$
  select count(*)::integer from public.notification_events n
  where (p_code is null or n.driver_id = tests.driver(p_code))
    and (p_threshold is null or n.threshold = p_threshold)
$$;

-- Everything undo must restore: live entries, active reservations, route settings.
create or replace function tests.fingerprint(p_route uuid default null) returns jsonb language sql stable as $$
  select jsonb_build_object(
    'entries', (
      select coalesce(jsonb_agg(jsonb_build_array(qe.id, qe.status, qe.join_sequence, qe.notification_cycle,
                                                  qe.transfer_used, qe.activated_at is not null)
                                order by qe.join_sequence), '[]')
      from public.queue_entries qe
      where qe.route_id = coalesce(p_route, tests.route())
        and qe.status not in ('completed', 'cancelled', 'removed')
    ),
    'reservations', (
      select coalesce(jsonb_agg(jsonb_build_array(r.id, r.queue_entry_id, r.priority_sequence)
                                order by r.priority_sequence), '[]')
      from public.queue_reservations r
      where r.route_id = coalesce(p_route, tests.route()) and r.status = 'active'
    ),
    'route', (
      select jsonb_build_array(rt.queue_capacity, rt.queue_status, rt.qr_enabled)
      from public.routes rt where rt.id = coalesce(p_route, tests.route())
    )
  )
$$;

-- A bare auth user (what driver-admin's auth.admin.createUser leaves before the profile exists).
create or replace function tests.fake_auth_user(p_uid uuid, p_email text) returns uuid language sql as $$
  insert into auth.users (instance_id, id, aud, role, email, email_confirmed_at, created_at, updated_at)
  values ('00000000-0000-0000-0000-000000000000', p_uid, 'authenticated', 'authenticated', p_email, now(), now(), now())
  returning id
$$;

-- 011 runs some helpers as authenticated/anon.
grant usage on schema tests to authenticated, anon;
grant execute on all functions in schema tests to authenticated, anon;

select plan(1);
select has_schema('tests', 'test helpers installed');
select * from finish();
commit;
