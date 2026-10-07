-- LOCAL DEVELOPMENT SEED ONLY. Never run against production.
-- Creates 1 operator, 2 routes, 20 drivers (10 per route) with tricycles.
-- Everyone's PIN is 123456. Production accounts are created by the
-- driver-admin Edge Function / admin script, never by this file.
--
-- Synthetic auth emails use the local default AUTH_EMAIL_DOMAIN (auth.triko.app);
-- a seed file cannot read env vars, so change it here too if the domain changes.
-- Queue entries are NOT seeded: they are created only by the queue engine (M3).

do $$
declare
  v_domain     constant text := 'auth.triko.app';
  v_pin        constant text := '123456';
  v_operator   uuid := '00000000-0000-4000-8000-000000000001';
  v_route_ids  uuid[] := array[
    '00000000-0000-4000-8000-0000000000a1'::uuid,  -- Magpet
    '00000000-0000-4000-8000-0000000000a2'::uuid   -- Matalam
  ];
  v_user       uuid;
  v_driver     uuid;
  v_tricycle   uuid;
  v_code       text;
  v_route      uuid;
  i            int;

begin
  -- ---------------- auth users (stored the way GoTrue stores email/password users) ----------------
  create temporary table seed_users (id uuid, email text, display_name text, role public.app_role, code text)
    on commit drop;

  insert into seed_users values (v_operator, 'opr001@' || v_domain, 'Operator Benjie', 'operator', 'OPR-001');

  for i in 1..20 loop
    v_code := 'DRV-' || lpad(i::text, 3, '0');
    insert into seed_users values (
      ('00000000-0000-4000-8000-' || lpad(to_hex(4096 + i), 12, '0'))::uuid,
      lower(replace(v_code, '-', '')) || '@' || v_domain,
      (array['Juan','Pedro','Mark','Carlo','Ben','Rico','Jun','Leo','Ramon','Nestor',
             'Arnel','Boyet','Dodong','Eddie','Fidel','Gerry','Hector','Isko','Jojo','Kiko'])[i],
      'driver',
      v_code
    );
  end loop;

  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, email_change, email_change_token_new, recovery_token
  )
  select
    '00000000-0000-0000-0000-000000000000', su.id, 'authenticated', 'authenticated', su.email,
    extensions.crypt(v_pin, extensions.gen_salt('bf')), now(),
    '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, now(), now(),
    '', '', '', ''
  from seed_users su;

  insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  select gen_random_uuid(), su.id, su.id::text,
         jsonb_build_object('sub', su.id::text, 'email', su.email, 'email_verified', true),
         'email', now(), now(), now()
  from seed_users su;

  insert into public.profiles (id, role, display_name)
  select su.id, su.role, su.display_name from seed_users su;

  -- ---------------- routes (queue_state rows created by trigger) ----------------
  insert into public.routes (id, name, origin, destination, queue_capacity, queue_status, qr_start_time)
  values
    (v_route_ids[1], 'Kidapawan → Magpet',  'Kidapawan', 'Magpet',  3, 'open',   '05:30'),
    (v_route_ids[2], 'Kidapawan → Matalam', 'Kidapawan', 'Matalam', 3, 'closed', '05:30');

  insert into public.operator_route_assignments (operator_id, route_id)
  select v_operator, unnest(v_route_ids);

  -- ---------------- drivers + tricycles + assignment history ----------------
  for i in 1..20 loop
    select su.id, su.code into v_user, v_code
    from seed_users su where su.role = 'driver' order by su.code offset i - 1 limit 1;

    v_route := v_route_ids[case when i <= 10 then 1 else 2 end];

    insert into public.tricycles (tricycle_number)
    values ('TRI-' || (100 + i)::text)
    returning id into v_tricycle;

    insert into public.drivers (profile_id, driver_code, current_tricycle_id, current_route_id)
    values (v_user, v_code, v_tricycle, v_route)
    returning id into v_driver;

    insert into public.driver_tricycle_assignments (driver_id, tricycle_id, assigned_by)
    values (v_driver, v_tricycle, v_operator);

    insert into public.driver_route_assignments (driver_id, route_id, assigned_by)
    values (v_driver, v_route, v_operator);
  end loop;
end;
$$;
