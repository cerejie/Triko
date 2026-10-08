-- Driver home read (M5): get_my_queue_status shapes per queue-rules §3 / §13.
-- The home screen shows waiting_position (NEXT IN LINE at 1), active_slot, or reservation_priority.
begin;
select plan(15);
select tests.as_operator();
select tests.fill(5);
select public.activate_queue_entry(tests.entry('DRV-001'));
select public.reserve_queue_entry(tests.entry('DRV-003'));

set local role authenticated;

-- Active driver: a slot, no waiting position.
select tests.as_user(tests.profile('DRV-001'));
select is(public.get_my_queue_status() -> 'entry' ->> 'status', 'active', 'active driver reads status active');
select is(public.get_my_queue_status() -> 'entry' ->> 'active_slot', '1', 'active driver reads their slot');
select is(public.get_my_queue_status() -> 'entry' -> 'waiting_position', 'null'::jsonb,
          'active driver has no waiting position');

-- First waiting driver: NEXT IN LINE.
select tests.as_user(tests.profile('DRV-002'));
select is(public.get_my_queue_status() -> 'entry' ->> 'waiting_position', '1', 'first waiting driver is waiting 1');
select is(public.get_my_queue_status() -> 'entry' ->> 'waiting_ahead', '0', 'nobody waits ahead of waiting 1');

-- Reserved driver: reservation rank, no position.
select tests.as_user(tests.profile('DRV-003'));
select is(public.get_my_queue_status() -> 'entry' ->> 'status', 'reserved', 'reserved driver reads status reserved');
select is(public.get_my_queue_status() -> 'entry' ->> 'reservation_priority', '1', 'reserved driver reads RESERVED #1');
select is(public.get_my_queue_status() -> 'entry' -> 'waiting_position', 'null'::jsonb,
          'reserved driver has no waiting position');

-- Waiting behind a reserved driver: reserved drivers are not counted.
select tests.as_user(tests.profile('DRV-004'));
select is(public.get_my_queue_status() -> 'entry' ->> 'waiting_position', '2', 'reserved driver is not counted ahead');
select is(public.get_my_queue_status() -> 'entry' ->> 'waiting_ahead', '1', 'waiting_ahead is waiting_position - 1');

-- Driver not in the queue: entry null, assigned route still returned.
select tests.as_user(tests.profile('DRV-006'));
select is(public.get_my_queue_status() -> 'entry', 'null'::jsonb, 'driver not in queue reads entry null');
select is(public.get_my_queue_status() -> 'route' ->> 'id', tests.route()::text, 'driver not in queue still reads their route');
select isnt(public.get_my_queue_status() -> 'queue_version', 'null'::jsonb, 'queue_version is returned for the cache');

-- Closed route.
select tests.as_user(tests.profile('DRV-011'));
select is(public.get_my_queue_status() -> 'route' ->> 'queue_status', 'closed', 'driver reads a closed queue');

-- Anonymous.
reset role;
set local role anon;
select throws_ok($$ select public.get_my_queue_status() $$, '42501', null, 'anon cannot read driver status');
reset role;

select * from finish();
rollback;
