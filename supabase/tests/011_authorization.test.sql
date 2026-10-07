-- Server authority: no direct writes, commands only for route operators, sanitized driver reads.
begin;
select plan(14);
select tests.as_operator();
select tests.fill(3);

-- A second operator who controls a different route.
insert into auth.users (instance_id, id, aud, role, email, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-8000-000000000002',
        'authenticated', 'authenticated', 'opr002@auth.triko.app', now(), now());
insert into public.profiles (id, role, display_name) values ('00000000-0000-4000-8000-000000000002', 'operator', 'Operator Two');
insert into public.routes (id, name, origin, destination) values ('00000000-0000-4000-8000-0000000000a3', 'Test Route', 'A', 'B');
insert into public.operator_route_assignments (operator_id, route_id)
values ('00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-0000000000a3');

-- Direct writes are denied for signed-in clients.
set local role authenticated;
select tests.as_operator();
select throws_ok($$ update public.queue_entries set status = 'active' $$, '42501', null, 'no direct UPDATE of queue_entries');
select throws_ok($$ insert into public.queue_events (route_id, event_type, queue_version_after)
                    values (tests.route(), 'QUEUE_OPENED', 1) $$, '42501', null, 'no direct INSERT into queue_events');
select throws_ok($$ update public.queue_state set queue_version = 0 $$, '42501', null, 'no direct UPDATE of queue_state');
select throws_ok($$ select * from public.queue_effective_order(tests.route()) $$, '42501', null,
                 'order function is internal');
select throws_ok($$ select private.finish_mutation(tests.route(), null, 'QUEUE_OPENED', null, null, '{}') $$, '42501', null,
                 'private helpers are internal');
select lives_ok($$ select public.get_route_queue(tests.route()) $$, 'route operator reads the full queue');

-- Operator of another route.
select tests.as_user('00000000-0000-4000-8000-000000000002');
select throws_ok($$ select public.reserve_queue_entry(tests.entry('DRV-002')) $$, 'P0001', 'FORBIDDEN',
                 'operator of another route cannot mutate');
select throws_ok($$ select public.get_route_queue(tests.route()) $$, 'P0001', 'FORBIDDEN',
                 'operator of another route cannot read the queue');

-- Driver.
select tests.as_user(tests.profile('DRV-002'));
select throws_ok($$ select public.activate_queue_entry(tests.entry('DRV-001')) $$, 'P0001', 'FORBIDDEN',
                 'drivers cannot run operator commands');
select is((select count(*)::integer from public.queue_entries), 1, 'RLS: a driver sees only their own entry');
select is((select array_agg(k order by k) from jsonb_object_keys(public.get_my_queue_status() -> 'entry') k),
          array['active_slot', 'entry_id', 'is_next_eligible', 'lane', 'overall_position', 'reservation_priority',
                'status', 'waiting_ahead', 'waiting_position'],
          'driver status exposes only their own position fields');
select is(public.get_my_queue_status() -> 'entry' ->> 'waiting_position', '2', 'driver sees their waiting position');

-- Anonymous.
reset role;
set local role anon;
select throws_ok($$ select public.join_queue('00000000-0000-4000-8000-0000000000a1', gen_random_uuid()) $$, '42501', null,
                 'anon cannot execute commands');
reset role;

-- Inactive operator.
update public.profiles set is_active = false where id = tests.operator_id();
select tests.as_operator();
select throws_ok($$ select public.reserve_queue_entry(tests.entry('DRV-002')) $$, 'P0001', 'FORBIDDEN',
                 'inactive operator loses access');

select * from finish();
rollback;
