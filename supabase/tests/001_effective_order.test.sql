-- queue-rules §2, §3: lanes and the position concepts (worked example).
begin;
select plan(20);
select tests.as_operator();

-- Juan, Pedro, Mark active; Carlo reserved; Ben returned; Rico, Jun, Leo waiting.
select tests.fill(8);
select public.activate_queue_entry(tests.entry('DRV-001'));
select public.activate_queue_entry(tests.entry('DRV-002'));
select public.activate_queue_entry(tests.entry('DRV-003'));
select public.reserve_queue_entry(tests.entry('DRV-004'));
select public.reserve_queue_entry(tests.entry('DRV-005'));
select public.return_reserved_driver(tests.entry('DRV-005'));

select is(tests.ord('DRV-001') ->> 'lane', 'active', 'active lane');
select is(tests.ord('DRV-001') ->> 'active_slot', '1', 'first activated holds slot 1');
select is(tests.ord('DRV-003') ->> 'overall_position', '3', 'active drivers take overall 1..A');
select is(tests.ord('DRV-004') ->> 'lane', 'reserved', 'away reserved driver is outside the lanes');
select is(tests.ord('DRV-004') ->> 'overall_position', null, 'away reserved driver has no position');
select is(tests.ord('DRV-004') ->> 'reservation_priority', '1', 'Carlo = RESERVED #1');
select is(tests.ord('DRV-005') ->> 'reservation_priority', '2', 'later reservation ranks after');
select is(tests.ord('DRV-005') ->> 'overall_position', '4', 'returned priority driver follows active');
select is(tests.ord('DRV-005') ->> 'waiting_position', '1', 'priority lane leads the waiting lanes');
select is(tests.ord('DRV-005') ->> 'is_next_eligible', 'true', 'waiting position 1 is next in line');
select is(tests.ord('DRV-006') ->> 'is_next_eligible', 'false', 'only one driver is next eligible');
select is(tests.ord('DRV-008') ->> 'overall_position', '7', 'Leo overall #7');
select is(tests.ord('DRV-008') ->> 'waiting_position', '4', 'Leo waiting position 4');
select is(tests.ord('DRV-008') ->> 'waiting_ahead', '3', 'Leo 3 AHEAD (active not counted)');
select is((select overall_position from public.queue_entries where id = tests.entry('DRV-008')), 7,
          'cached overall_position matches the order function');

-- Suspended drivers have no position; the remaining active drivers renumber.
select public.suspend_queue_entry(tests.entry('DRV-001'));
select is(tests.ord('DRV-001') ->> 'overall_position', null, 'suspended driver has no position');
select is(tests.ord('DRV-002') ->> 'active_slot', '1', 'active slots renumber by activation time');

-- PRIORITY lane is FIFO by priority_sequence: a resumed driver goes behind Ben.
select public.resume_queue_entry(tests.entry('DRV-001'));
select is(tests.ord('DRV-001') ->> 'waiting_position', '2', 'resumed driver joins the end of PRIORITY');
select is(tests.ord('DRV-006') ->> 'waiting_position', '3', 'NORMAL WAITING follows PRIORITY');
select is((select count(*)::integer from public.queue_effective_order(tests.route())), 8,
          'every live entry appears exactly once');

select * from finish();
rollback;
