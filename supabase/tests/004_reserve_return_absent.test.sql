-- queue-rules §5, §5.2.1: reserve, return, absent again keeps priority.
begin;
select plan(14);
select tests.as_operator();
select tests.fill(6);
select public.activate_queue_entry(tests.entry('DRV-001'));
select public.activate_queue_entry(tests.entry('DRV-002'));
select public.activate_queue_entry(tests.entry('DRV-003'));

select lives_ok($$ select public.reserve_queue_entry(tests.entry('DRV-004')) $$, 'waiting driver reserved');
select is(tests.status('DRV-004'), 'reserved', 'status reserved');
select is(tests.ord('DRV-004') ->> 'reservation_priority', '1', 'first reservation is #1');
select public.reserve_queue_entry(tests.entry('DRV-006'));
select is(tests.ord('DRV-006') ->> 'reservation_priority', '2', 'reservations are FIFO');
select throws_ok($$ select public.reserve_queue_entry(tests.entry('DRV-004')) $$, 'P0001', 'INVALID_TRANSITION',
                 'reserved driver cannot be reserved again');
select throws_ok($$ select public.reserve_queue_entry(tests.entry('DRV-001')) $$, 'P0001', 'INVALID_TRANSITION',
                 'active driver cannot be reserved');

-- Returning order does not matter: priority is by reservation time.
select public.return_reserved_driver(tests.entry('DRV-006'));
select public.return_reserved_driver(tests.entry('DRV-004'));
select is(tests.ord('DRV-004') ->> 'waiting_position', '1', 'earlier reservation leads PRIORITY');
select is(tests.ord('DRV-006') ->> 'waiting_position', '2', 'later reservation follows');

create temp table seq_before as
  select priority_sequence from public.queue_reservations
  where queue_entry_id = tests.entry('DRV-004') and status = 'active';
select lives_ok($$ select public.mark_priority_absent(tests.entry('DRV-004')) $$, 'due but absent again');
select is(tests.status('DRV-004'), 'reserved', 'back to reserved');
select is((select priority_sequence from public.queue_reservations
           where queue_entry_id = tests.entry('DRV-004') and status = 'active'),
          (select priority_sequence from seq_before), 'absent again keeps the original priority_sequence');
select public.return_reserved_driver(tests.entry('DRV-004'));
select is(tests.ord('DRV-004') ->> 'waiting_position', '1', 'returns to the front of PRIORITY');

select throws_ok($$ select public.return_reserved_driver(tests.entry('DRV-005')) $$, 'P0001', 'INVALID_TRANSITION',
                 'a waiting driver cannot be returned');
select throws_ok($$ select public.mark_priority_absent(tests.entry('DRV-005')) $$, 'P0001', 'INVALID_TRANSITION',
                 'a waiting driver cannot be marked absent again');

select * from finish();
rollback;
