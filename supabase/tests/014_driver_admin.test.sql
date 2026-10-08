-- Driver admin (queue-rules §12): route permission, server-generated codes, atomic creation,
-- tricycle reuse, PIN-reset authorization, service-role only.
begin;
select plan(25);

-- Operator Two controls route a3 only; an admin; three bare auth users for creates.
insert into auth.users (instance_id, id, aud, role, email, created_at, updated_at)
values ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-8000-000000000002',
        'authenticated', 'authenticated', 'opr002@auth.triko.app', now(), now()),
       ('00000000-0000-0000-0000-000000000000', '00000000-0000-4000-8000-000000000003',
        'authenticated', 'authenticated', 'adm001@auth.triko.app', now(), now());
insert into public.profiles (id, role, display_name) values
  ('00000000-0000-4000-8000-000000000002', 'operator', 'Operator Two'),
  ('00000000-0000-4000-8000-000000000003', 'admin', 'Admin One');
insert into public.routes (id, name, origin, destination) values ('00000000-0000-4000-8000-0000000000a3', 'Test Route', 'A', 'B');
insert into public.operator_route_assignments (operator_id, route_id)
values ('00000000-0000-4000-8000-000000000002', '00000000-0000-4000-8000-0000000000a3');

select tests.fake_auth_user('00000000-0000-4000-8000-00000000c001', 'drv021@auth.triko.app');
select tests.fake_auth_user('00000000-0000-4000-8000-00000000c002', 'drv022@auth.triko.app');
select tests.fake_auth_user('00000000-0000-4000-8000-00000000c003', 'drv023@auth.triko.app');

create function pg_temp.op2() returns uuid language sql as $$ select '00000000-0000-4000-8000-000000000002'::uuid $$;
create function pg_temp.admin() returns uuid language sql as $$ select '00000000-0000-4000-8000-000000000003'::uuid $$;
create function pg_temp.u(i integer) returns uuid language sql as
$$ select ('00000000-0000-4000-8000-00000000c00' || i)::uuid $$;
create function pg_temp.add_driver(p_actor uuid, p_user uuid, p_code text, p_tricycle text, p_phone text default null)
returns jsonb language sql as $$
  select public.driver_admin_create_driver(p_actor, p_user, p_code, 'New Driver', p_phone, p_tricycle, tests.route())
$$;

-- ---------------- prepare_create ----------------
select is(public.driver_admin_prepare_create(tests.operator_id(), tests.route()) ->> 'driver_code', 'DRV-021',
          'next driver code follows the highest DRV number');
select throws_ok($$ select public.driver_admin_prepare_create(pg_temp.op2(), tests.route()) $$, 'P0001', 'FORBIDDEN',
                 'operator of another route cannot add drivers here');
select throws_ok($$ select public.driver_admin_prepare_create(tests.operator_id(), gen_random_uuid()) $$, 'P0001', 'NOT_FOUND',
                 'unknown route is NOT_FOUND');
select throws_ok($$ select public.driver_admin_prepare_create(tests.profile('DRV-001'), tests.route()) $$, 'P0001', 'FORBIDDEN',
                 'drivers cannot add drivers');
select lives_ok($$ select public.driver_admin_prepare_create(pg_temp.admin(), tests.route()) $$, 'admin may add drivers on any route');

-- ---------------- create_driver ----------------
select lives_ok($$ select pg_temp.add_driver(tests.operator_id(), pg_temp.u(1), 'DRV-021', 'TRI-500') $$,
                'route operator creates a driver');
select is((select role::text from public.profiles where id = pg_temp.u(1)), 'driver', 'profile is created with role driver');
select is((select current_route_id from public.drivers where driver_code = 'DRV-021'), tests.route(),
          'driver current route is set');
select is((select t.tricycle_number from public.drivers d join public.tricycles t on t.id = d.current_tricycle_id
           where d.driver_code = 'DRV-021'), 'TRI-500', 'new tricycle is created and set as current');
select is((select assigned_by from public.driver_tricycle_assignments
           where driver_id = tests.driver('DRV-021') and unassigned_at is null), tests.operator_id(),
          'open tricycle assignment records the operator');
select is((select route_id from public.driver_route_assignments
           where driver_id = tests.driver('DRV-021') and unassigned_at is null), tests.route(),
          'open route assignment is created');
select is(public.driver_admin_prepare_create(tests.operator_id(), tests.route()) ->> 'driver_code', 'DRV-022',
          'next code advances after a create');

select throws_ok($$ select pg_temp.add_driver(tests.operator_id(), pg_temp.u(2), 'DRV-022', 'TRI-101') $$, 'P0001', 'TRICYCLE_IN_USE',
                 'a tricycle assigned to another driver is refused');

insert into public.tricycles (tricycle_number) values ('TRI-900');
select is((pg_temp.add_driver(tests.operator_id(), pg_temp.u(2), 'DRV-022', 'tri-900') ->> 'tricycle_id')::uuid,
          (select id from public.tricycles where tricycle_number = 'TRI-900'),
          'a free existing tricycle is reused (number normalized)');

select throws_ok($$ select pg_temp.add_driver(tests.operator_id(), pg_temp.u(3), 'DRV-001', 'TRI-777') $$, 'P0001', 'DRIVER_CODE_TAKEN',
                 'a taken driver code is DRIVER_CODE_TAKEN');
select ok(not exists (select 1 from public.profiles where id = pg_temp.u(3))
          and not exists (select 1 from public.tricycles where tricycle_number = 'TRI-777'),
          'a failed create leaves no profile or tricycle behind');
select throws_ok($$ select pg_temp.add_driver(tests.operator_id(), pg_temp.u(3), 'DRV-023', 'TRI-778', 'abc') $$, 'P0001', 'INVALID_INPUT',
                 'invalid phone number is INVALID_INPUT');
select throws_ok($$ select pg_temp.add_driver(tests.operator_id(), tests.profile('DRV-002'), 'DRV-023', 'TRI-778') $$, 'P0001', 'INVALID_INPUT',
                 'an auth user that already has a profile is refused');
select throws_ok($$ select pg_temp.add_driver(pg_temp.op2(), pg_temp.u(3), 'DRV-023', 'TRI-778') $$, 'P0001', 'FORBIDDEN',
                 'operator of another route cannot create here');

-- ---------------- authorize_reset ----------------
select is((public.driver_admin_authorize_reset(tests.operator_id(), tests.driver('DRV-005')) ->> 'profile_id')::uuid,
          tests.profile('DRV-005'), 'route operator may reset a driver PIN');
select throws_ok($$ select public.driver_admin_authorize_reset(pg_temp.op2(), tests.driver('DRV-005')) $$, 'P0001', 'FORBIDDEN',
                 'operator of another route cannot reset the PIN');
select throws_ok($$ select public.driver_admin_authorize_reset(tests.operator_id(), gen_random_uuid()) $$, 'P0001', 'NOT_FOUND',
                 'unknown driver is NOT_FOUND');
update public.drivers set is_active = false where driver_code = 'DRV-006';
select throws_ok($$ select public.driver_admin_authorize_reset(tests.operator_id(), tests.driver('DRV-006')) $$, 'P0001', 'DRIVER_INACTIVE',
                 'inactive driver PIN is not reset');

-- ---------------- grants ----------------
set local role authenticated;
select throws_ok($$ select public.driver_admin_authorize_reset(tests.operator_id(), tests.driver('DRV-005')) $$, '42501', null,
                 'signed-in clients cannot call driver-admin functions');
reset role;
set local role anon;
select throws_ok($$ select public.driver_admin_prepare_create(tests.operator_id(), tests.route()) $$, '42501', null,
                 'anon cannot call driver-admin functions');
reset role;

select * from finish();
rollback;
