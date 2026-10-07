-- Triko core schema (M2).
-- Rules: docs/queue-rules.md. Queue tables are written only by the queue engine
-- (SECURITY DEFINER functions in M3) and Edge Functions; clients never update them directly.

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------

create type public.app_role as enum ('driver', 'operator', 'admin');

create type public.route_queue_status as enum ('open', 'closed');

-- Lanes (docs/queue-rules.md §2, §4):
--   active   -> ACTIVE lane
--   priority -> PRIORITY lane (returned reserved / resumed suspended)
--   waiting  -> NORMAL WAITING lane
--   reserved -> away, holds reservation, no position
--   suspended-> no position, resumable
--   completed / cancelled / removed -> terminal
create type public.queue_entry_status as enum (
  'waiting', 'active', 'reserved', 'priority', 'suspended',
  'completed', 'cancelled', 'removed'
);

create type public.queue_join_method as enum ('operator', 'qr', 'transfer');

create type public.reservation_status as enum ('active', 'used', 'cancelled');

-- Why a driver is in the priority lane.
create type public.reservation_source as enum ('absent', 'resumed');

create type public.queue_event_type as enum (
  'QUEUE_JOINED',
  'QUEUE_ACTIVATED',
  'DRIVER_LEFT',            -- completed / departure confirmed
  'DRIVER_RESERVED',
  'DRIVER_RETURNED',
  'DRIVER_ABSENT_AGAIN',
  'DRIVER_MOVED_TO_LAST',
  'DRIVER_CANCELLED',
  'DRIVER_SUSPENDED',
  'DRIVER_RESUMED',
  'DRIVER_TRANSFERRED',
  'DRIVER_REMOVED',
  'QUEUE_CAPACITY_CHANGED',
  'QUEUE_OPENED',
  'QUEUE_CLOSED',
  'QR_ENABLED',
  'QR_DISABLED',
  'UNDO_PERFORMED'
);

create type public.notification_type as enum ('QUEUE_THRESHOLD', 'NEXT_IN_LINE');

create type public.notification_channel as enum ('push', 'sms');

create type public.notification_status as enum ('pending', 'sent', 'failed', 'skipped');

-- ---------------------------------------------------------------------------
-- Shared trigger: updated_at
-- ---------------------------------------------------------------------------

create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- profiles: one per Supabase Auth user. Role is never trusted from the client.
-- ---------------------------------------------------------------------------

create table public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  role          public.app_role not null,
  display_name  text not null check (length(trim(display_name)) between 1 and 80),
  phone_number  text check (phone_number ~ '^[0-9+][0-9]{6,14}$'),
  is_active     boolean not null default true,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create trigger profiles_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- tricycles: an assignment target, never an identity.
-- ---------------------------------------------------------------------------

create table public.tricycles (
  id               uuid primary key default gen_random_uuid(),
  tricycle_number  text not null unique check (tricycle_number ~ '^[A-Z0-9][A-Z0-9-]{1,19}$'),
  is_active        boolean not null default true,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create trigger tricycles_updated_at before update on public.tricycles
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- routes: one queue per route.
-- ---------------------------------------------------------------------------

create table public.routes (
  id                uuid primary key default gen_random_uuid(),
  name              text not null unique check (length(trim(name)) between 1 and 80),
  origin            text not null,
  destination       text not null,
  queue_capacity    integer not null default 3 check (queue_capacity between 1 and 50),
  queue_status      public.route_queue_status not null default 'closed',
  queue_start_time  time not null default '04:00',
  qr_enabled        boolean not null default false,
  qr_start_time     time,
  timezone          text not null default 'Asia/Manila',
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create trigger routes_updated_at before update on public.routes
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- drivers: the persistent queue participant. Login is driver_code + PIN.
-- ---------------------------------------------------------------------------

create table public.drivers (
  id                   uuid primary key default gen_random_uuid(),
  profile_id           uuid not null unique references public.profiles (id) on delete restrict,
  driver_code          text not null unique check (driver_code ~ '^[A-Z]{2,5}-[0-9]{1,6}$'),
  current_tricycle_id  uuid references public.tricycles (id) on delete set null,
  current_route_id     uuid references public.routes (id) on delete set null,
  is_active            boolean not null default true,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

create index drivers_current_route_idx on public.drivers (current_route_id);

create trigger drivers_updated_at before update on public.drivers
  for each row execute function public.set_updated_at();

-- Assignment history (driver <-> tricycle, driver <-> route).
-- At most one open (unassigned_at is null) row per driver per table.

create table public.driver_tricycle_assignments (
  id             uuid primary key default gen_random_uuid(),
  driver_id      uuid not null references public.drivers (id) on delete restrict,
  tricycle_id    uuid not null references public.tricycles (id) on delete restrict,
  assigned_by    uuid references public.profiles (id),
  assigned_at    timestamptz not null default now(),
  unassigned_at  timestamptz,
  check (unassigned_at is null or unassigned_at >= assigned_at)
);

create unique index driver_tricycle_assignments_open_uq
  on public.driver_tricycle_assignments (driver_id) where unassigned_at is null;
create index driver_tricycle_assignments_tricycle_idx
  on public.driver_tricycle_assignments (tricycle_id);

create table public.driver_route_assignments (
  id             uuid primary key default gen_random_uuid(),
  driver_id      uuid not null references public.drivers (id) on delete restrict,
  route_id       uuid not null references public.routes (id) on delete restrict,
  assigned_by    uuid references public.profiles (id),
  assigned_at    timestamptz not null default now(),
  unassigned_at  timestamptz,
  check (unassigned_at is null or unassigned_at >= assigned_at)
);

create unique index driver_route_assignments_open_uq
  on public.driver_route_assignments (driver_id) where unassigned_at is null;
create index driver_route_assignments_route_idx
  on public.driver_route_assignments (route_id);

-- ---------------------------------------------------------------------------
-- operator_route_assignments: one operator -> many routes;
-- one active controlling operator per route (reference §3.16).
-- ---------------------------------------------------------------------------

create table public.operator_route_assignments (
  id           uuid primary key default gen_random_uuid(),
  operator_id  uuid not null references public.profiles (id) on delete restrict,
  route_id     uuid not null references public.routes (id) on delete restrict,
  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),
  unique (operator_id, route_id)
);

create unique index operator_route_assignments_one_controller_uq
  on public.operator_route_assignments (route_id) where is_active;

-- ---------------------------------------------------------------------------
-- queue_state: one authoritative row per route; locked by every command.
-- ---------------------------------------------------------------------------

create table public.queue_state (
  route_id           uuid primary key references public.routes (id) on delete cascade,
  queue_sequence     bigint not null default 0 check (queue_sequence >= 0),    -- last join_sequence issued
  priority_sequence  bigint not null default 0 check (priority_sequence >= 0), -- last reservation priority issued
  queue_version      bigint not null default 0 check (queue_version >= 0),     -- bumped by every mutation
  last_event_id      uuid,                                                     -- FK added after queue_events
  updated_at         timestamptz not null default now()
);

create trigger queue_state_updated_at before update on public.queue_state
  for each row execute function public.set_updated_at();

create function public.create_queue_state_for_route()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.queue_state (route_id) values (new.id);
  return new;
end;
$$;

create trigger routes_create_queue_state after insert on public.routes
  for each row execute function public.create_queue_state_for_route();

-- ---------------------------------------------------------------------------
-- queue_entries: one row per queue participation.
-- ---------------------------------------------------------------------------

create table public.queue_entries (
  id                        uuid primary key default gen_random_uuid(),
  route_id                  uuid not null references public.routes (id) on delete restrict,
  driver_id                 uuid not null references public.drivers (id) on delete restrict,
  tricycle_id               uuid references public.tricycles (id),       -- tricycle at join time (history)
  status                    public.queue_entry_status not null default 'waiting',
  join_method               public.queue_join_method not null,
  join_sequence             bigint not null check (join_sequence > 0),   -- normal-lane FIFO key
  activated_at              timestamptz,                                 -- ACTIVE lane order
  transfer_origin_entry_id  uuid references public.queue_entries (id),   -- set on a received transfer
  transfer_used             boolean not null default false,
  notification_cycle        integer not null default 1 check (notification_cycle >= 1),
  overall_position          integer check (overall_position >= 1),       -- cache from queue_effective_order
  waiting_position          integer check (waiting_position >= 1),       -- cache from queue_effective_order
  joined_at                 timestamptz not null default now(),
  ended_at                  timestamptz,
  updated_at                timestamptz not null default now(),
  -- A received entitlement can never be transferred onward.
  check (transfer_origin_entry_id is null or transfer_used),
  check ((status = 'active') = (activated_at is not null)),
  check ((status in ('completed', 'cancelled', 'removed')) = (ended_at is not null))
);

-- One live participation per driver across ALL routes (reference §3.13);
-- also blocks duplicates in the same queue.
create unique index queue_entries_one_live_per_driver_uq
  on public.queue_entries (driver_id)
  where status not in ('completed', 'cancelled', 'removed');

-- Live entries never share a FIFO place.
create unique index queue_entries_live_sequence_uq
  on public.queue_entries (route_id, join_sequence)
  where status not in ('completed', 'cancelled', 'removed');

create index queue_entries_route_status_idx on public.queue_entries (route_id, status);
create index queue_entries_driver_idx on public.queue_entries (driver_id);

create trigger queue_entries_updated_at before update on public.queue_entries
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- queue_reservations: PRIORITY lane entitlement, FIFO by priority_sequence.
-- ---------------------------------------------------------------------------

create table public.queue_reservations (
  id                 uuid primary key default gen_random_uuid(),
  route_id           uuid not null references public.routes (id) on delete restrict,
  queue_entry_id     uuid not null references public.queue_entries (id) on delete restrict,
  priority_sequence  bigint not null check (priority_sequence > 0),
  source             public.reservation_source not null,
  status             public.reservation_status not null default 'active',
  created_by         uuid references public.profiles (id),
  reserved_at        timestamptz not null default now(),
  returned_at        timestamptz,   -- latest physical return (priority lane)
  used_at            timestamptz,
  cancelled_at       timestamptz,
  check ((status = 'used') = (used_at is not null)),
  check ((status = 'cancelled') = (cancelled_at is not null))
);

-- One live reservation per entry; priority numbers unique per route.
create unique index queue_reservations_one_active_per_entry_uq
  on public.queue_reservations (queue_entry_id) where status = 'active';
create unique index queue_reservations_active_priority_uq
  on public.queue_reservations (route_id, priority_sequence) where status = 'active';

-- ---------------------------------------------------------------------------
-- queue_transfers: once per source entry (unique), recipient entry unique.
-- ---------------------------------------------------------------------------

create table public.queue_transfers (
  id                         uuid primary key default gen_random_uuid(),
  route_id                   uuid not null references public.routes (id) on delete restrict,
  source_entry_id            uuid not null unique references public.queue_entries (id),
  source_driver_id           uuid not null references public.drivers (id),
  target_entry_id            uuid not null unique references public.queue_entries (id),
  target_driver_id           uuid not null references public.drivers (id),
  original_join_sequence     bigint not null,
  original_overall_position  integer,
  original_waiting_position  integer,
  sender_new_join_sequence   bigint not null,
  created_by                 uuid not null references public.profiles (id),
  created_at                 timestamptz not null default now(),
  check (source_driver_id <> target_driver_id),
  check (source_entry_id <> target_entry_id)
);

-- ---------------------------------------------------------------------------
-- queue_events: append-only audit log, undo source, notification trigger source.
-- ---------------------------------------------------------------------------

create table public.queue_events (
  id                   uuid primary key default gen_random_uuid(),
  route_id             uuid not null references public.routes (id) on delete restrict,
  queue_entry_id       uuid references public.queue_entries (id),
  event_type           public.queue_event_type not null,
  performed_by         uuid references public.profiles (id),
  old_state            jsonb,
  new_state            jsonb,
  reason               text,
  queue_version_after  bigint not null,
  undoes_event_id      uuid unique references public.queue_events (id),
  created_at           timestamptz not null default now(),
  check ((event_type = 'UNDO_PERFORMED') = (undoes_event_id is not null))
);

create index queue_events_route_created_idx on public.queue_events (route_id, created_at desc);
create index queue_events_entry_idx on public.queue_events (queue_entry_id);

alter table public.queue_state
  add constraint queue_state_last_event_fk
  foreign key (last_event_id) references public.queue_events (id);

create function public.queue_events_append_only()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'queue_events is append-only' using errcode = 'P0001';
end;
$$;

create trigger queue_events_no_update before update or delete on public.queue_events
  for each row execute function public.queue_events_append_only();

-- ---------------------------------------------------------------------------
-- notification_events: dedup per (driver, entry, cycle, threshold, type, channel).
-- Never written to queue_events, so delivery never affects Undo.
-- ---------------------------------------------------------------------------

create table public.notification_events (
  id                   uuid primary key default gen_random_uuid(),
  driver_id            uuid not null references public.drivers (id) on delete restrict,
  queue_entry_id       uuid not null references public.queue_entries (id) on delete restrict,
  route_id             uuid not null references public.routes (id) on delete restrict,
  notification_cycle   integer not null check (notification_cycle >= 1),
  notification_type    public.notification_type not null,
  threshold            integer not null check (threshold in (10, 8, 6, 4, 2, 1)),
  channel              public.notification_channel not null default 'push',
  status               public.notification_status not null default 'pending',
  source_event_id      uuid references public.queue_events (id),
  created_at           timestamptz not null default now(),
  sent_at              timestamptz,
  failed_at            timestamptz,
  provider_message_id  text,
  error                text,
  check ((notification_type = 'NEXT_IN_LINE') = (threshold = 1)),
  unique (driver_id, queue_entry_id, notification_cycle, threshold, notification_type, channel)
);

create index notification_events_driver_created_idx on public.notification_events (driver_id, created_at desc);
create index notification_events_pending_idx on public.notification_events (created_at) where status = 'pending';

-- ---------------------------------------------------------------------------
-- device_tokens: a user may have several devices; a push token belongs to one row.
-- ---------------------------------------------------------------------------

create table public.device_tokens (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles (id) on delete cascade,
  device_id     text not null check (length(device_id) between 1 and 200),
  push_token    text not null unique check (length(push_token) between 1 and 500),
  platform      text not null default 'android' check (platform in ('android', 'ios')),
  is_active     boolean not null default true,
  last_seen_at  timestamptz not null default now(),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (user_id, device_id)
);

create trigger device_tokens_updated_at before update on public.device_tokens
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- queue_qr_sessions: random, route-scoped, time-boxed join tokens.
-- ---------------------------------------------------------------------------

create table public.queue_qr_sessions (
  id             uuid primary key default gen_random_uuid(),
  route_id       uuid not null references public.routes (id) on delete restrict,
  session_token  text not null unique default encode(extensions.gen_random_bytes(24), 'hex'),
  starts_at      timestamptz not null,
  expires_at     timestamptz not null,
  is_active      boolean not null default true,
  created_by     uuid not null references public.profiles (id),
  created_at     timestamptz not null default now(),
  check (expires_at > starts_at)
);

create unique index queue_qr_sessions_one_active_per_route_uq
  on public.queue_qr_sessions (route_id) where is_active;

-- ---------------------------------------------------------------------------
-- auth_login_attempts: throttling/lockout for the login Edge Function (M4).
-- Service-role only (RLS on, no policies).
-- ---------------------------------------------------------------------------

create table public.auth_login_attempts (
  id            bigint generated always as identity primary key,
  driver_code   text not null,
  device_id     text,
  succeeded     boolean not null,
  attempted_at  timestamptz not null default now()
);

create index auth_login_attempts_code_time_idx on public.auth_login_attempts (driver_code, attempted_at desc);
create index auth_login_attempts_device_time_idx on public.auth_login_attempts (device_id, attempted_at desc)
  where device_id is not null;
