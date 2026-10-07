-- queue-rules §5: activate (next eligible, capacity) and complete.
begin;
select plan(13);
select tests.as_operator();
select tests.fill(6);

select throws_ok($$ select public.activate_queue_entry(tests.entry('DRV-002')) $$, 'P0001', 'NOT_NEXT_ELIGIBLE',
                 'only the next eligible driver can be activated');
select lives_ok($$ select public.activate_queue_entry(tests.entry('DRV-001')) $$, 'next eligible activated');
select public.activate_queue_entry(tests.entry('DRV-002'));
select public.activate_queue_entry(tests.entry('DRV-003'));
select throws_ok($$ select public.activate_queue_entry(tests.entry('DRV-004')) $$, 'P0001', 'CAPACITY_FULL',
                 'no activation at capacity');
select throws_ok($$ select public.activate_queue_entry(tests.entry('DRV-001')) $$, 'P0001', 'INVALID_TRANSITION',
                 'an active driver cannot be activated again');

select lives_ok($$ select public.complete_queue_entry(tests.entry('DRV-001')) $$, 'active driver completes');
select is(tests.status('DRV-001'), 'completed', 'completed is terminal');
select isnt((select ended_at from public.queue_entries where id = tests.entry('DRV-001')), null, 'ended_at set');
select throws_ok($$ select public.complete_queue_entry(tests.entry('DRV-004')) $$, 'P0001', 'INVALID_TRANSITION',
                 'a waiting driver cannot complete');
select is(tests.status('DRV-004'), 'waiting', 'activation is never automatic after a slot frees');

select public.activate_queue_entry(tests.entry('DRV-004'));
select is(tests.ord('DRV-004') ->> 'active_slot', '3', 'new active driver takes the last slot');

-- PRIORITY before NORMAL WAITING.
select public.reserve_queue_entry(tests.entry('DRV-006'));
select public.return_reserved_driver(tests.entry('DRV-006'));
select public.complete_queue_entry(tests.entry('DRV-002'));
select throws_ok($$ select public.activate_queue_entry(tests.entry('DRV-005')) $$, 'P0001', 'NOT_NEXT_ELIGIBLE',
                 'normal waiting cannot skip a returned priority driver');
select lives_ok($$ select public.activate_queue_entry(tests.entry('DRV-006')) $$, 'priority driver activated');
select is((select status::text from public.queue_reservations where queue_entry_id = tests.entry('DRV-006')),
          'used', 'activation consumes the reservation');

select * from finish();
rollback;
