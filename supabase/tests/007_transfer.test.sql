-- queue-rules §7: transfer once per entry, from waiting only, to an eligible driver.
begin;
select plan(21);
select tests.as_operator();
select tests.fill(6);
select public.activate_queue_entry(tests.entry('DRV-001'));

create temp table carlo as select tests.entry('DRV-003') as id;

select lives_ok($$ select public.transfer_queue_entry(tests.entry('DRV-003'), tests.driver('DRV-007')) $$,
                'Carlo transfers to Ben');
select is((select join_sequence from public.queue_entries where id = tests.entry('DRV-007')), 3::bigint,
          'Ben inherits Carlo''s join_sequence');
select is(tests.ord('DRV-007') ->> 'waiting_position', '2', 'Ben takes Carlo''s place');
select is((select join_method::text from public.queue_entries where id = tests.entry('DRV-007')), 'transfer',
          'recipient join method is transfer');
select is((select transfer_origin_entry_id from public.queue_entries where id = tests.entry('DRV-007')),
          (select id from carlo), 'recipient links the source entry');
select ok((select transfer_used from public.queue_entries where id = tests.entry('DRV-007')),
          'received entitlement can never transfer on');
select is(tests.entry('DRV-003'), (select id from carlo), 'Carlo keeps the same entry');
select is(tests.ord('DRV-003') ->> 'waiting_position', '6', 'Carlo goes to the end');
select is((select notification_cycle from public.queue_entries where id = tests.entry('DRV-003')), 2,
          'sender starts a new notification cycle');
select is((select original_waiting_position from public.queue_transfers where source_entry_id = (select id from carlo)),
          2, 'transfer records the original position');
select is((select count(*)::integer from public.queue_events where event_type = 'DRIVER_TRANSFERRED'), 1,
          'one DRIVER_TRANSFERRED event');

select throws_ok($$ select public.transfer_queue_entry(tests.entry('DRV-007'), tests.driver('DRV-008')) $$,
                 'P0001', 'TRANSFER_NOT_ALLOWED', 'Carlo -> Ben -> Rico rejected');
select throws_ok($$ select public.transfer_queue_entry(tests.entry('DRV-003'), tests.driver('DRV-008')) $$,
                 'P0001', 'TRANSFER_NOT_ALLOWED', 'sender cannot transfer twice in one participation');
select throws_ok($$ select public.transfer_queue_entry(tests.entry('DRV-004'), tests.driver('DRV-005')) $$,
                 'P0001', 'ALREADY_IN_QUEUE', 'target already in this queue');
select throws_ok($$ select public.transfer_queue_entry(tests.entry('DRV-004'), tests.driver('DRV-004')) $$,
                 'P0001', 'TRANSFER_NOT_ALLOWED', 'no transfer to oneself');

select public.open_queue(tests.route2());
select tests.join('DRV-011', tests.route2());
select throws_ok($$ select public.transfer_queue_entry(tests.entry('DRV-004'), tests.driver('DRV-011')) $$,
                 'P0001', 'ALREADY_IN_OTHER_QUEUE', 'target queued on another route');
select throws_ok($$ select public.transfer_queue_entry(tests.entry('DRV-004'), tests.driver('DRV-012')) $$,
                 'P0001', 'DRIVER_NOT_ASSIGNED', 'target must be assigned to the route');
update public.drivers set is_active = false where driver_code = 'DRV-009';
select throws_ok($$ select public.transfer_queue_entry(tests.entry('DRV-004'), tests.driver('DRV-009')) $$,
                 'P0001', 'DRIVER_INACTIVE', 'target must be an active driver');

select throws_ok($$ select public.transfer_queue_entry(tests.entry('DRV-001'), tests.driver('DRV-010')) $$,
                 'P0001', 'INVALID_TRANSITION', 'no transfer from active');
select public.reserve_queue_entry(tests.entry('DRV-005'));
select throws_ok($$ select public.transfer_queue_entry(tests.entry('DRV-005'), tests.driver('DRV-010')) $$,
                 'P0001', 'INVALID_TRANSITION', 'no transfer from reserved (protects priority)');

select public.close_queue(tests.route());
select lives_ok($$ select public.transfer_queue_entry(tests.entry('DRV-004'), tests.driver('DRV-010')) $$,
                'CLOSED does not block transfers');

select * from finish();
rollback;
