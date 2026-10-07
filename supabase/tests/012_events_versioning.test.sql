-- Every mutation: exactly one queue_events row and queue_version + 1; queue_events is append-only.
begin;
select plan(9);
select tests.as_operator();

create temp table mark (v bigint, n integer);
create function pg_temp.one_event(p_sql text, p_label text) returns text language plpgsql as $$
begin
  delete from mark;
  insert into mark select tests.version(), (select count(*)::integer from public.queue_events where route_id = tests.route());
  execute p_sql;
  return ok(
    tests.version() = (select v + 1 from mark)
    and (select count(*)::integer from public.queue_events where route_id = tests.route()) = (select n + 1 from mark),
    'one event, version +1: ' || p_label
  );
end $$;

select tests.fill(3);
select pg_temp.one_event($$ select tests.join('DRV-004') $$, 'join');
select pg_temp.one_event($$ select public.activate_queue_entry(tests.entry('DRV-001')) $$, 'activate');
select pg_temp.one_event($$ select public.transfer_queue_entry(tests.entry('DRV-002'), tests.driver('DRV-005')) $$, 'transfer');
select pg_temp.one_event($$ select tests.undo_last() $$, 'undo');

select is((select queue_version_after from public.queue_events where id = tests.last_event()), tests.version(),
          'event stores the version it produced');

create temp table v_before as select tests.version() as v;
select throws_ok($$ select public.activate_queue_entry(tests.entry('DRV-003')) $$, 'P0001', 'NOT_NEXT_ELIGIBLE',
                 'rejected command');
select is(tests.version(), (select v from v_before), 'a rejected command changes nothing');

select throws_ok($$ update public.queue_events set reason = 'x' $$, 'P0001', 'queue_events is append-only', 'no UPDATE');
select throws_ok($$ delete from public.queue_events $$, 'P0001', 'queue_events is append-only', 'no DELETE');

select * from finish();
rollback;
