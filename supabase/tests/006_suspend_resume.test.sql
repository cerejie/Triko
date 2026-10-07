-- queue-rules §5, §5.2.2: suspend only from active; resume into the end of PRIORITY.
begin;
select plan(11);
select tests.as_operator();
select tests.fill(6);
select public.activate_queue_entry(tests.entry('DRV-001'));
select public.activate_queue_entry(tests.entry('DRV-002'));
select public.activate_queue_entry(tests.entry('DRV-003'));
select public.reserve_queue_entry(tests.entry('DRV-005'));
select public.return_reserved_driver(tests.entry('DRV-005'));

select throws_ok($$ select public.suspend_queue_entry(tests.entry('DRV-004')) $$, 'P0001', 'INVALID_TRANSITION',
                 'waiting driver cannot be suspended');
select lives_ok($$ select public.suspend_queue_entry(tests.entry('DRV-002')) $$, 'active driver suspended');
select is(tests.ord('DRV-002') ->> 'overall_position', null, 'suspended has no position');
select is((select count(*)::integer from public.queue_entries where route_id = tests.route() and status = 'active'),
          2, 'the slot is freed immediately');
select throws_ok($$ select public.activate_queue_entry(tests.entry('DRV-002')) $$, 'P0001', 'INVALID_TRANSITION',
                 'suspended driver cannot be activated directly');

select lives_ok($$ select public.resume_queue_entry(tests.entry('DRV-002')) $$, 'suspended driver resumed');
select is(tests.status('DRV-002'), 'priority', 'resume enters PRIORITY');
select is((select source::text from public.queue_reservations
           where queue_entry_id = tests.entry('DRV-002') and status = 'active'), 'resumed', 'reservation source resumed');
select is(tests.ord('DRV-002') ->> 'waiting_position', '2', 'resumed goes behind the earlier priority driver');
select is((select count(*)::integer from public.queue_entries where route_id = tests.route() and status = 'active'),
          2, 'resume never takes an active slot');
select throws_ok($$ select public.resume_queue_entry(tests.entry('DRV-004')) $$, 'P0001', 'INVALID_TRANSITION',
                 'only suspended drivers resume');

select * from finish();
rollback;
