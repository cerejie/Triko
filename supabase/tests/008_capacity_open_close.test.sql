-- queue-rules §8, §10: capacity never ejects; CLOSED blocks joins only; no resets.
begin;
select plan(16);
select tests.as_operator();
select tests.fill(5);
select public.activate_queue_entry(tests.entry('DRV-001'));
select public.activate_queue_entry(tests.entry('DRV-002'));
select public.activate_queue_entry(tests.entry('DRV-003'));

select is((public.change_queue_capacity(tests.route(), 2) ->> 'over_capacity_count')::integer, 1,
          'capacity reduction reports the extra active driver');
select is((select count(*)::integer from public.queue_entries where route_id = tests.route() and status = 'active'),
          3, 'reducing capacity never ejects an active driver');
select throws_ok($$ select public.activate_queue_entry(tests.entry('DRV-004')) $$, 'P0001', 'CAPACITY_FULL',
                 'no activation while over capacity');
select public.complete_queue_entry(tests.entry('DRV-001'));
select throws_ok($$ select public.activate_queue_entry(tests.entry('DRV-004')) $$, 'P0001', 'CAPACITY_FULL',
                 'still full at the new capacity');
select public.complete_queue_entry(tests.entry('DRV-002'));
select lives_ok($$ select public.activate_queue_entry(tests.entry('DRV-004')) $$, 'activation resumes below capacity');

select throws_ok($$ select public.change_queue_capacity(tests.route(), 0) $$, 'P0001', 'INVALID_CAPACITY', 'capacity >= 1');
select throws_ok($$ select public.change_queue_capacity(tests.route(), 51) $$, 'P0001', 'INVALID_CAPACITY', 'capacity <= 50');
select throws_ok($$ select public.change_queue_capacity(tests.route(), 2) $$, 'P0001', 'INVALID_TRANSITION', 'no-op change rejected');

select lives_ok($$ select public.close_queue(tests.route()) $$, 'operator closes the queue');
select throws_ok($$ select tests.join('DRV-006') $$, 'P0001', 'QUEUE_CLOSED', 'CLOSED blocks new joins');
select throws_ok($$ select public.close_queue(tests.route()) $$, 'P0001', 'INVALID_TRANSITION', 'already closed');
select lives_ok($$ select public.reserve_queue_entry(tests.entry('DRV-005')) $$, 'other commands work while CLOSED');

select public.open_queue(tests.route());
select lives_ok($$ select tests.join('DRV-006') $$, 'reopened queue accepts joins');
select is((select join_sequence from public.queue_entries where id = tests.entry('DRV-006')), 6::bigint,
          'sequences continue across close/reopen (no reset)');

select public.enable_qr(tests.route());
select ok((select qr_enabled from public.routes where id = tests.route()), 'QR enabled');
select throws_ok($$ select public.enable_qr(tests.route()) $$, 'P0001', 'INVALID_TRANSITION', 'QR already enabled');

select * from finish();
rollback;
