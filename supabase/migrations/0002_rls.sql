-- Triko Row Level Security (M2).
-- Clients get READ access scoped to their role. Queue mutations go only through
-- SECURITY DEFINER command functions (M3) and Edge Functions (service role),
-- so no INSERT/UPDATE/DELETE policies exist on queue tables.
-- Drivers read the shared route queue via a sanitized RPC (M3), not raw rows.

-- ---------------------------------------------------------------------------
-- Helper functions (private schema: not exposed through the Data API)
-- ---------------------------------------------------------------------------

create schema if not exists private;
grant usage on schema private to authenticated;

create function private.current_app_role()
returns public.app_role
language sql
stable
security definer
set search_path = ''
as $$
  select p.role
  from public.profiles p
  where p.id = auth.uid() and p.is_active;
$$;

create function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(private.current_app_role() = 'admin', false);
$$;

create function private.current_driver_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select d.id
  from public.drivers d
  join public.profiles p on p.id = d.profile_id
  where d.profile_id = auth.uid() and d.is_active and p.is_active;
$$;

create function private.current_driver_route_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select d.current_route_id
  from public.drivers d
  join public.profiles p on p.id = d.profile_id
  where d.profile_id = auth.uid() and d.is_active and p.is_active;
$$;

-- True when the caller is an active operator with an active assignment to the route.
create function private.operator_has_route(p_route_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.operator_route_assignments ora
    join public.profiles p on p.id = ora.operator_id
    where ora.operator_id = auth.uid()
      and ora.route_id = p_route_id
      and ora.is_active
      and p.is_active
      and p.role = 'operator'
  );
$$;

-- True when the caller operates a route this driver is assigned to or queued on.
create function private.operator_manages_driver(p_driver_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.drivers d
    where d.id = p_driver_id and private.operator_has_route(d.current_route_id)
  ) or exists (
    select 1 from public.queue_entries qe
    where qe.driver_id = p_driver_id
      and qe.status not in ('completed', 'cancelled', 'removed')
      and private.operator_has_route(qe.route_id)
  );
$$;

revoke all on all functions in schema private from public;
grant execute on all functions in schema private to authenticated;

-- ---------------------------------------------------------------------------
-- Default privileges: anon gets nothing; authenticated may only SELECT
-- (plus device_tokens self-management). RLS narrows the rows further.
-- ---------------------------------------------------------------------------

revoke all on all tables in schema public from anon;
revoke insert, update, delete, truncate on all tables in schema public from authenticated;
grant select on all tables in schema public to authenticated;
grant insert, update, delete on public.device_tokens to authenticated;

revoke all on public.auth_login_attempts from authenticated;

alter default privileges in schema public revoke all on tables from anon;
alter default privileges in schema public revoke insert, update, delete, truncate on tables from authenticated;

-- ---------------------------------------------------------------------------
-- Enable RLS everywhere
-- ---------------------------------------------------------------------------

alter table public.profiles                    enable row level security;
alter table public.tricycles                   enable row level security;
alter table public.routes                      enable row level security;
alter table public.drivers                     enable row level security;
alter table public.driver_tricycle_assignments enable row level security;
alter table public.driver_route_assignments    enable row level security;
alter table public.operator_route_assignments  enable row level security;
alter table public.queue_state                 enable row level security;
alter table public.queue_entries               enable row level security;
alter table public.queue_reservations          enable row level security;
alter table public.queue_transfers             enable row level security;
alter table public.queue_events                enable row level security;
alter table public.notification_events         enable row level security;
alter table public.device_tokens               enable row level security;
alter table public.queue_qr_sessions           enable row level security;
alter table public.auth_login_attempts         enable row level security;  -- no policies: service role only

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------

create policy profiles_select_self on public.profiles
  for select to authenticated
  using (id = (select auth.uid()));

create policy profiles_select_operator on public.profiles
  for select to authenticated
  using (exists (
    select 1 from public.drivers d
    where d.profile_id = profiles.id and private.operator_manages_driver(d.id)
  ));

create policy profiles_select_admin on public.profiles
  for select to authenticated
  using (private.is_admin());

-- ---------------------------------------------------------------------------
-- drivers
-- ---------------------------------------------------------------------------

create policy drivers_select_self on public.drivers
  for select to authenticated
  using (profile_id = (select auth.uid()));

create policy drivers_select_operator on public.drivers
  for select to authenticated
  using (private.operator_manages_driver(id));

create policy drivers_select_admin on public.drivers
  for select to authenticated
  using (private.is_admin());

-- ---------------------------------------------------------------------------
-- tricycles: operators see all (to assign); drivers see their current one.
-- ---------------------------------------------------------------------------

create policy tricycles_select_operator on public.tricycles
  for select to authenticated
  using (private.current_app_role() in ('operator', 'admin'));

create policy tricycles_select_driver on public.tricycles
  for select to authenticated
  using (exists (
    select 1 from public.drivers d
    where d.profile_id = (select auth.uid()) and d.current_tricycle_id = tricycles.id
  ));

-- ---------------------------------------------------------------------------
-- routes
-- ---------------------------------------------------------------------------

create policy routes_select_driver on public.routes
  for select to authenticated
  using (id = private.current_driver_route_id());

create policy routes_select_operator on public.routes
  for select to authenticated
  using (private.operator_has_route(id));

create policy routes_select_admin on public.routes
  for select to authenticated
  using (private.is_admin());

-- ---------------------------------------------------------------------------
-- assignment history
-- ---------------------------------------------------------------------------

create policy driver_tricycle_assignments_select on public.driver_tricycle_assignments
  for select to authenticated
  using (
    driver_id = private.current_driver_id()
    or private.operator_manages_driver(driver_id)
    or private.is_admin()
  );

create policy driver_route_assignments_select on public.driver_route_assignments
  for select to authenticated
  using (
    driver_id = private.current_driver_id()
    or private.operator_has_route(route_id)
    or private.is_admin()
  );

create policy operator_route_assignments_select on public.operator_route_assignments
  for select to authenticated
  using (operator_id = (select auth.uid()) or private.is_admin());

-- ---------------------------------------------------------------------------
-- queue_state
-- ---------------------------------------------------------------------------

create policy queue_state_select on public.queue_state
  for select to authenticated
  using (
    route_id = private.current_driver_route_id()
    or private.operator_has_route(route_id)
    or private.is_admin()
  );

-- ---------------------------------------------------------------------------
-- queue_entries: drivers see only their own rows; operators their routes.
-- ---------------------------------------------------------------------------

create policy queue_entries_select_driver on public.queue_entries
  for select to authenticated
  using (driver_id = private.current_driver_id());

create policy queue_entries_select_operator on public.queue_entries
  for select to authenticated
  using (private.operator_has_route(route_id) or private.is_admin());

-- ---------------------------------------------------------------------------
-- queue_reservations
-- ---------------------------------------------------------------------------

create policy queue_reservations_select on public.queue_reservations
  for select to authenticated
  using (
    private.operator_has_route(route_id)
    or private.is_admin()
    or exists (
      select 1 from public.queue_entries qe
      where qe.id = queue_reservations.queue_entry_id
        and qe.driver_id = private.current_driver_id()
    )
  );

-- ---------------------------------------------------------------------------
-- queue_transfers
-- ---------------------------------------------------------------------------

create policy queue_transfers_select on public.queue_transfers
  for select to authenticated
  using (
    private.operator_has_route(route_id)
    or private.is_admin()
    or private.current_driver_id() in (source_driver_id, target_driver_id)
  );

-- ---------------------------------------------------------------------------
-- queue_events: operator history only.
-- ---------------------------------------------------------------------------

create policy queue_events_select on public.queue_events
  for select to authenticated
  using (private.operator_has_route(route_id) or private.is_admin());

-- ---------------------------------------------------------------------------
-- notification_events
-- ---------------------------------------------------------------------------

create policy notification_events_select on public.notification_events
  for select to authenticated
  using (
    driver_id = private.current_driver_id()
    or private.operator_has_route(route_id)
    or private.is_admin()
  );

-- ---------------------------------------------------------------------------
-- device_tokens: each user manages only their own devices.
-- ---------------------------------------------------------------------------

create policy device_tokens_select_own on public.device_tokens
  for select to authenticated
  using (user_id = (select auth.uid()));

create policy device_tokens_insert_own on public.device_tokens
  for insert to authenticated
  with check (user_id = (select auth.uid()));

create policy device_tokens_update_own on public.device_tokens
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy device_tokens_delete_own on public.device_tokens
  for delete to authenticated
  using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------------
-- queue_qr_sessions: operators of the route only (drivers never read tokens).
-- ---------------------------------------------------------------------------

create policy queue_qr_sessions_select on public.queue_qr_sessions
  for select to authenticated
  using (private.operator_has_route(route_id) or private.is_admin());
