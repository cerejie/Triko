-- queue-rules §4, §5: move to last, cancel from every non-terminal state, remove, terminal states.
begin;
select plan(20);
select tests.as_operator();
select tests.fill(6);

select public.move_queue_entry_to_last(tests.entry('DRV-001'));
select is(tests.ord('DRV-001') ->> 'waiting_position', '6', 'moved to the end');
select is((select join_sequence from public.queue_entries where id = tests.entry('DRV-001')),
          7::bigint, 'new join_sequence from the counter');
select is((select notification_cycle from public.queue_entries where id = tests.entry('DRV-001')),
          2, 'move to last starts a new notification cycle');
select is(tests.ord('DRV-002') ->> 'waiting_position', '1', 'everyone behind moves up');

select public.activate_queue_entry(tests.entry('DRV-002'));
select throws_ok($$ select public.move_queue_entry_to_last(tests.entry('DRV-002')) $$, 'P0001', 'INVALID_TRANSITION',
                 'active driver cannot be moved to last');

-- Cancel from each non-terminal state.
select public.suspend_queue_entry(tests.entry('DRV-002'));
select lives_ok($$ select public.cancel_queue_entry(tests.entry('DRV-002')) $$, 'cancel from suspended');
select public.reserve_queue_entry(tests.entry('DRV-003'));
select lives_ok($$ select public.cancel_queue_entry(tests.entry('DRV-003')) $$, 'cancel from reserved');
select is((select status::text from public.queue_reservations where queue_entry_id = tests.entry('DRV-003')),
          'cancelled', 'cancel cancels the reservation');
select public.reserve_queue_entry(tests.entry('DRV-004'));
select public.return_reserved_driver(tests.entry('DRV-004'));
select lives_ok($$ select public.cancel_queue_entry(tests.entry('DRV-004')) $$, 'cancel from priority');
select lives_ok($$ select public.cancel_queue_entry(tests.entry('DRV-005')) $$, 'cancel from waiting');
select public.activate_queue_entry(tests.entry('DRV-006'));
select lives_ok($$ select public.cancel_queue_entry(tests.entry('DRV-006')) $$, 'cancel from active');
select is((select activated_at from public.queue_entries where id = tests.entry('DRV-006')), null,
          'cancelled active driver frees the slot');

-- Terminal states accept nothing.
select throws_ok($$ select public.cancel_queue_entry(tests.entry('DRV-005')) $$, 'P0001', 'INVALID_TRANSITION', 'cancelled: no cancel');
select throws_ok($$ select public.activate_queue_entry(tests.entry('DRV-005')) $$, 'P0001', 'INVALID_TRANSITION', 'cancelled: no activate');
select throws_ok($$ select public.reserve_queue_entry(tests.entry('DRV-005')) $$, 'P0001', 'INVALID_TRANSITION', 'cancelled: no reserve');
select throws_ok($$ select public.remove_queue_entry(tests.entry('DRV-005')) $$, 'P0001', 'INVALID_TRANSITION', 'cancelled: no remove');

select lives_ok($$ select public.remove_queue_entry(tests.entry('DRV-001'), 'duplicate entry') $$, 'correction remove');
select is(tests.status('DRV-001'), 'removed', 'status removed');
select is((select reason from public.queue_events where id = tests.last_event()), 'duplicate entry', 'reason recorded');
select is((select count(*)::integer from public.queue_entries where route_id = tests.route()), 6,
          'terminal entries are never deleted');

select * from finish();
rollback;
