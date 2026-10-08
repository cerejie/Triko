-- Driver home header (M5): a driver reads their own tricycle number through RLS
-- (drivers_select_self + tricycles_select_driver), and nobody else's.
begin;
select plan(6);

set local role authenticated;
select tests.as_user(tests.profile('DRV-001'));

-- Same embed the app uses: drivers -> tricycles via current_tricycle_id.
select is(
  (select t.tricycle_number from public.drivers d join public.tricycles t on t.id = d.current_tricycle_id
   where d.profile_id = tests.profile('DRV-001')),
  'TRI-101', 'driver reads their own tricycle number');
select is((select count(*) from public.drivers)::int, 1, 'driver sees only their own driver row');
select is((select count(*) from public.tricycles)::int, 1, 'driver sees only their current tricycle');
select is((select count(*) from public.tricycles where tricycle_number = 'TRI-102')::int, 0,
          'driver cannot read another driver''s tricycle');

-- Anonymous: no table access at all.
reset role;
set local role anon;
select throws_ok($$ select tricycle_number from public.tricycles $$, '42501', null, 'anon cannot read tricycles');
select throws_ok($$ select driver_code from public.drivers $$, '42501', null, 'anon cannot read drivers');
reset role;

select * from finish();
rollback;
