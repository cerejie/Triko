-- Login throttling (queue-rules §12): per-account escalating lockout, per-device lockout,
-- unknown codes treated alike, service-role only.
begin;
select plan(18);

-- Insert n failures for a code (and optional device), all minutes_ago in the past.
create function pg_temp.fail(p_code text, n integer, p_minutes_ago numeric default 0, p_device text default null)
returns void language sql as $$
  insert into public.auth_login_attempts (driver_code, device_id, succeeded, attempted_at)
  select p_code, p_device, false, now() - make_interval(secs => p_minutes_ago * 60) from generate_series(1, n)
$$;

create function pg_temp.status(p_code text, p_device text default null) returns jsonb language sql as
$$ select public.login_throttle_status(p_code, p_device) $$;

-- ---------------- per account ----------------
select pg_temp.fail('DRV-001', 4);
select is(pg_temp.status('DRV-001') ->> 'locked', 'false', '4 failures do not lock');

select pg_temp.fail('DRV-001', 1);
select is(pg_temp.status('DRV-001') ->> 'locked', 'true', '5th consecutive failure locks the account');
select ok((pg_temp.status('DRV-001') ->> 'retry_after_seconds')::integer between 59 and 60, 'first lock is 1 minute');

delete from public.auth_login_attempts;
select pg_temp.fail('DRV-001', 5, 2);
select is(pg_temp.status('DRV-001') ->> 'locked', 'false', '1-minute lock expires');

select pg_temp.fail('DRV-001', 1);
select ok((pg_temp.status('DRV-001') ->> 'retry_after_seconds')::integer between 299 and 300, '6th failure locks for 5 minutes');

select pg_temp.fail('DRV-001', 1);
select ok((pg_temp.status('DRV-001') ->> 'retry_after_seconds')::integer between 899 and 900, '7th failure locks for 15 minutes');

select pg_temp.fail('DRV-001', 1);
select ok((pg_temp.status('DRV-001') ->> 'retry_after_seconds')::integer between 3599 and 3600, '8th failure locks for 60 minutes');

select pg_temp.fail('DRV-001', 5);
select ok((pg_temp.status('DRV-001') ->> 'retry_after_seconds')::integer between 3599 and 3600, 'lock is capped at 60 minutes');

select is(pg_temp.status('DRV-002') ->> 'locked', 'false', 'another account is unaffected');

delete from public.auth_login_attempts;
select pg_temp.fail('DRV-001', 4, 10);
insert into public.auth_login_attempts (driver_code, succeeded, attempted_at) values ('DRV-001', true, now() - interval '5 minutes');
select pg_temp.fail('DRV-001', 4);
select is(pg_temp.status('DRV-001') ->> 'locked', 'false', 'a success resets the consecutive-failure count');

select public.record_login_attempt(' drv-001 ', null, false);
select is(pg_temp.status('drv-001') ->> 'locked', 'true', 'codes are normalized (trim, upper case)');

-- ---------------- unknown codes ----------------
select pg_temp.fail('ZZZ-999', 5);
select is(pg_temp.status('ZZZ-999') ->> 'locked', 'true', 'unknown codes lock exactly like real ones');

-- ---------------- per device ----------------
delete from public.auth_login_attempts;
select pg_temp.fail(tests.code(i), 1, 0, 'device-A') from generate_series(1, 9) i;
select is(pg_temp.status('DRV-020', 'device-A') ->> 'locked', 'false', '9 device failures do not lock');

select pg_temp.fail('DRV-019', 1, 0, 'device-A');
select ok((pg_temp.status('DRV-020', 'device-A') ->> 'retry_after_seconds')::integer between 899 and 900,
          '10 failures across codes lock the device for 15 minutes');
select is(pg_temp.status('DRV-020', 'device-B') ->> 'locked', 'false', 'another device is unaffected');

delete from public.auth_login_attempts;
select pg_temp.fail(tests.code(i), 1, 16, 'device-A') from generate_series(1, 10) i;
select is(pg_temp.status('DRV-020', 'device-A') ->> 'locked', 'false', 'device failures older than 15 minutes do not count');

-- ---------------- account checks ----------------
update public.profiles set is_active = false where id = tests.profile('DRV-003');
select is(public.login_account_active('DRV-003'), false, 'inactive driver profile cannot log in');

-- ---------------- grants ----------------
set local role authenticated;
select throws_ok($$ select public.login_throttle_status('DRV-001', null) $$, '42501', null,
                 'clients cannot call login throttle functions');
reset role;

select * from finish();
rollback;
