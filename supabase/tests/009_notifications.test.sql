-- queue-rules §11: thresholds 10, 8, 6, 4, 2, 1 on forward crossings only, deduplicated per cycle.
begin;
select plan(13);
select tests.as_operator();

-- 20 drivers on one route so positions start above 10.
update public.driver_route_assignments set route_id = tests.route() where route_id = tests.route2();
update public.drivers set current_route_id = tests.route() where current_route_id = tests.route2();
select tests.fill(20);

select is(tests.notif_count(), 0, 'joining never notifies by itself');

select public.activate_queue_entry(tests.entry('DRV-001'));
select is(tests.notif_count(), 6, 'one forward step crosses each threshold once');
select is(tests.notif_count('DRV-011', 10), 1, '11 -> 10 sends #10');
select is(tests.notif_count('DRV-010'), 0, '10 -> 9 crosses nothing');
select is((select notification_type::text from public.notification_events where driver_id = tests.driver('DRV-002')),
          'NEXT_IN_LINE', '2 -> 1 sends NEXT IN LINE');

-- Moving backward never notifies; moving forward again in the same cycle never duplicates.
select public.reserve_queue_entry(tests.entry('DRV-020'));
select public.return_reserved_driver(tests.entry('DRV-020'));
select is(tests.notif_count(), 6, 'a returning reserved driver pushes others back without notifying');
select public.activate_queue_entry(tests.entry('DRV-020'));
select is(tests.notif_count('DRV-011', 10), 1, 'same threshold in the same cycle is not sent twice');
select is(tests.notif_count(), 6, 'no duplicates anywhere');

-- Jump: only the lowest threshold crossed is sent (12 -> 8 sends 8 only).
select private.create_threshold_notifications(
  tests.route(),
  jsonb_build_object(tests.entry('DRV-008')::text, 12),
  tests.last_event()
);
select is((select array_agg(threshold) from public.notification_events where driver_id = tests.driver('DRV-008')),
          array[8], 'a jump sends only the most urgent threshold');

-- Transfer recipient is not alerted at its starting place.
select public.cancel_queue_entry(tests.entry('DRV-019'));
select public.transfer_queue_entry(tests.entry('DRV-005'), tests.driver('DRV-019'));
select is(tests.notif_count('DRV-019'), 0, 'transfer receipt does not notify');

-- Move to last opens a new cycle: thresholds can alert again.
select public.move_queue_entry_to_last(tests.entry('DRV-003'));
select is(tests.notif_count('DRV-003', 2), 1, 'cycle 1 threshold #2 already sent');
do $$
declare v_id uuid;
begin
  for v_id in
    select o.entry_id from public.queue_effective_order(tests.route()) o
    where o.waiting_position is not null and o.entry_id <> tests.entry('DRV-003')
    order by o.waiting_position
  loop
    perform public.cancel_queue_entry(v_id);
  end loop;
end $$;
select is((select count(*)::integer from public.notification_events
           where driver_id = tests.driver('DRV-003') and threshold = 2 and notification_cycle = 2), 1,
          'threshold #2 alerts again in the new cycle');
select is(tests.notif_count('DRV-003', 1), 1, 'and NEXT IN LINE once');

select * from finish();
rollback;
