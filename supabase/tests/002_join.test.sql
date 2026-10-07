-- queue-rules §9: join checks, in order.
begin;
select plan(15);
select tests.as_operator();

select lives_ok($$ select tests.join('DRV-001') $$, 'operator adds an assigned driver');
select is(tests.status('DRV-001'), 'waiting', 'new entry is waiting');
select is((select join_method::text from public.queue_entries where id = tests.entry('DRV-001')),
          'operator', 'join method recorded');
select is((select join_sequence from public.queue_entries where id = tests.entry('DRV-001')),
          1::bigint, 'first join takes sequence 1');

select throws_ok($$ select tests.join('DRV-001') $$, 'P0001', 'ALREADY_IN_QUEUE', 'second join on the same route rejected');
select throws_ok($$ select tests.join('DRV-001', tests.route2()) $$, 'P0001', 'ALREADY_IN_OTHER_QUEUE',
                 'live entry anywhere blocks joining another route');
select throws_ok($$ select tests.join('DRV-011', tests.route2()) $$, 'P0001', 'QUEUE_CLOSED', 'CLOSED blocks joins');

select public.open_queue(tests.route2());
select throws_ok($$ select tests.join('DRV-002', tests.route2()) $$, 'P0001', 'DRIVER_NOT_ASSIGNED',
                 'driver must be assigned to the route');

update public.drivers set is_active = false where driver_code = 'DRV-003';
select throws_ok($$ select tests.join('DRV-003') $$, 'P0001', 'DRIVER_INACTIVE', 'inactive driver rejected');
update public.profiles set is_active = false where id = tests.profile('DRV-004');
select throws_ok($$ select tests.join('DRV-004') $$, 'P0001', 'DRIVER_INACTIVE', 'inactive profile rejected');
select throws_ok($$ select public.join_queue(tests.route(), gen_random_uuid()) $$, 'P0001', 'NOT_FOUND',
                 'unknown driver rejected');

select public.cancel_queue_entry(tests.entry('DRV-001'));
select lives_ok($$ select tests.join('DRV-001') $$, 'cancelled driver may rejoin');
select is((select join_sequence from public.queue_entries where id = tests.entry('DRV-001')),
          2::bigint, 'rejoin takes a new place at the end');

select tests.as_user(tests.profile('DRV-005'));
select throws_ok($$ select tests.join('DRV-005') $$, 'P0001', 'FORBIDDEN', 'a driver cannot add drivers');
select tests.as_user(null);
select throws_ok($$ select tests.join('DRV-005') $$, 'P0001', 'FORBIDDEN', 'unauthenticated caller rejected');

select * from finish();
rollback;
