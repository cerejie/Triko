-- queue-rules §6: 30-second undo of the latest event, restores old_state, never recursive, never notifies.
begin;
select plan(27);
select tests.as_operator();
select tests.fill(6);
select public.activate_queue_entry(tests.entry('DRV-001'));

-- Every command followed by undo leaves the queue exactly as before.
create temp table fp (v jsonb);
create function pg_temp.undo_restores(p_sql text, p_label text) returns text language plpgsql as $$
begin
  delete from fp;
  insert into fp select tests.fingerprint();
  execute p_sql;
  perform tests.undo_last();
  return is(tests.fingerprint(), (select v from fp), 'undo restores: ' || p_label);
end $$;

select pg_temp.undo_restores($$ select tests.join('DRV-007') $$, 'join');
select is((select status::text from public.queue_entries where driver_id = tests.driver('DRV-007')), 'removed',
          'undone join is kept as removed, never deleted');
select pg_temp.undo_restores($$ select public.activate_queue_entry(tests.entry('DRV-002')) $$, 'activate');
select pg_temp.undo_restores($$ select public.complete_queue_entry(tests.entry('DRV-001')) $$, 'complete');
select pg_temp.undo_restores($$ select public.reserve_queue_entry(tests.entry('DRV-003')) $$, 'reserve');
select public.reserve_queue_entry(tests.entry('DRV-003'));
select pg_temp.undo_restores($$ select public.return_reserved_driver(tests.entry('DRV-003')) $$, 'return');
select public.return_reserved_driver(tests.entry('DRV-003'));
select pg_temp.undo_restores($$ select public.mark_priority_absent(tests.entry('DRV-003')) $$, 'absent again');
select pg_temp.undo_restores($$ select public.activate_queue_entry(tests.entry('DRV-003')) $$, 'activate from priority');
select pg_temp.undo_restores($$ select public.move_queue_entry_to_last(tests.entry('DRV-004')) $$, 'move to last');
select pg_temp.undo_restores($$ select public.cancel_queue_entry(tests.entry('DRV-003')) $$, 'cancel priority');
select pg_temp.undo_restores($$ select public.remove_queue_entry(tests.entry('DRV-004')) $$, 'remove');
select pg_temp.undo_restores($$ select public.suspend_queue_entry(tests.entry('DRV-001')) $$, 'suspend');
select public.suspend_queue_entry(tests.entry('DRV-001'));
select pg_temp.undo_restores($$ select public.resume_queue_entry(tests.entry('DRV-001')) $$, 'resume');
select pg_temp.undo_restores($$ select public.transfer_queue_entry(tests.entry('DRV-004'), tests.driver('DRV-008')) $$, 'transfer');
select ok((select undone_at is not null from public.queue_transfers where source_entry_id = tests.entry('DRV-004')),
          'undone transfer is marked, not deleted');
select lives_ok($$ select public.transfer_queue_entry(tests.entry('DRV-004'), tests.driver('DRV-008')) $$,
                'sender may transfer for real after an undone transfer');
select pg_temp.undo_restores($$ select public.change_queue_capacity(tests.route(), 5) $$, 'capacity');
select pg_temp.undo_restores($$ select public.close_queue(tests.route()) $$, 'close');
select pg_temp.undo_restores($$ select public.enable_qr(tests.route()) $$, 'enable QR');

-- Audit trail.
select is((select event_type::text from public.queue_events where id = tests.last_event()), 'UNDO_PERFORMED',
          'undo is recorded as a new event');
select isnt((select undoes_event_id from public.queue_events where id = tests.last_event()), null,
            'undo event points at the undone event');

-- Rules.
select throws_ok($$ select tests.undo_last() $$, 'P0001', 'UNDO_NOT_ALLOWED', 'an undo cannot be undone');

select public.move_queue_entry_to_last(tests.entry('DRV-005'));
create temp table first_event as select tests.last_event() as id;
select public.move_queue_entry_to_last(tests.entry('DRV-006'));
select throws_ok($$ select public.undo_queue_event((select id from first_event)) $$, 'P0001', 'UNDO_NOT_LATEST',
                 'a later mutation ends undo eligibility');

set local session_replication_role = replica;  -- bypass the append-only trigger to age the event
update public.queue_events set created_at = now() - interval '31 seconds' where id = tests.last_event();
set local session_replication_role = origin;
select throws_ok($$ select tests.undo_last() $$, 'P0001', 'UNDO_EXPIRED', 'undo window is 30 seconds');

-- Undo never notifies, even when it moves drivers forward.
select public.reserve_queue_entry(tests.entry('DRV-002'));
select public.return_reserved_driver(tests.entry('DRV-002'));
create temp table n_before as select tests.notif_count() as n;
select tests.undo_last();
select is(tests.notif_count(), (select n from n_before), 'undo creates no notifications');

-- A restored driver who joined another queue meanwhile blocks the undo.
select public.open_queue(tests.route2());
select public.cancel_queue_entry(tests.entry('DRV-006'));
create temp table cancel_event as select tests.last_event() as id;
update public.driver_route_assignments set route_id = tests.route2() where driver_id = tests.driver('DRV-006');
select tests.join('DRV-006', tests.route2());
select throws_ok($$ select public.undo_queue_event((select id from cancel_event)) $$, 'P0001', 'UNDO_NOT_ALLOWED',
                 'undo cannot create a second live entry');

select tests.as_user(tests.profile('DRV-002'));
select throws_ok($$ select tests.undo_last(tests.route2()) $$, 'P0001', 'FORBIDDEN', 'drivers cannot undo');

select * from finish();
rollback;
