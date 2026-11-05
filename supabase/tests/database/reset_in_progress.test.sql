-- pgTAP: an unenrolled account's open reset belongs to the phone that started
-- it (20261106000001_reset_in_progress.sql, docs/sync-design.md section 8).
-- Run with: supabase test db
begin;
select plan(6);

insert into auth.users (id, phone) values
  ('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', '201000000031'),
  ('ffffffff-ffff-4fff-8fff-ffffffffffff', '201000000032');

create function pg_temp.as_user(p_user uuid, p_session uuid) returns text language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated', 'session_id', p_session)::text, true);
$$;
create function pg_temp.key(p_byte int) returns bytea language sql immutable as $$
  select decode(repeat(lpad(to_hex(p_byte), 2, '0'), 32), 'hex');
$$;
-- Phone and Auth session by short name: 'e1' is E's first phone and its session.
create function pg_temp.d(p text) returns uuid language sql immutable as $$
  select ('d0000000-0000-4000-8000-0000000000' || p)::uuid;
$$;
create function pg_temp.s(p text) returns uuid language sql immutable as $$
  select ('50000000-0000-4000-8000-0000000000' || p)::uuid;
$$;
create function pg_temp.phone(p_user uuid, p text, p_key int) returns void language sql as $$
  insert into public.devices (id, user_id, platform, public_key, signing_public_key, created_session_id)
  values (pg_temp.d(p), p_user, 'ios', pg_temp.key(p_key), pg_temp.key(p_key + 1), pg_temp.s(p));
$$;
create temp table vals (k text primary key, id uuid);
grant all on vals to public;

-- E enrols with e1, then a reset started by e2 completes and e2 signs out
-- before enrolling: the reset can't be claimed, so the account isn't enrolled
-- and a new reset may start.
select pg_temp.phone('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'e1', 1);
select pg_temp.phone('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'e2', 3);
select public.bind_device_signed('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', pg_temp.s('e1'), pg_temp.d('e1'), true);
set local role authenticated;
select pg_temp.as_user('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', pg_temp.s('e2'));
select public.start_account_reset(pg_temp.d('e2'));
reset role;
update public.account_resets set completes_at = now() - interval '1 minute';
select public.complete_account_resets();
set local role authenticated;
select pg_temp.as_user('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', pg_temp.s('e2'));
select public.revoke_own_device(pg_temp.d('e2'));
reset role;
-- Two new phones race to start the next reset.
select pg_temp.phone('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'e3', 5);
select pg_temp.phone('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', 'e4', 7);

set local role authenticated;
select pg_temp.as_user('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', pg_temp.s('e3'));
insert into vals select 'reset', public.start_account_reset(pg_temp.d('e3'));
select ok((select id from vals where k = 'reset') is not null, 'the first phone starts the new reset');
select is(public.start_account_reset(pg_temp.d('e3')), (select id from vals where k = 'reset'),
  'and asking again returns its own reset');
select pg_temp.as_user('eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee', pg_temp.s('e4'));
select throws_ok($$ select public.start_account_reset(pg_temp.d('e4')) $$,
  '55000', 'reset_in_progress', 'another phone is told a reset is running, not joined into it');
reset role;
select is((select started_device from public.account_resets where id = (select id from vals where k = 'reset')),
  pg_temp.d('e3'), 'the open reset still belongs to the phone that started it');
select is((select count(*)::int from public.account_resets
           where user_id = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee' and completed_at is null and cancelled_at is null), 1,
  'and no second reset was opened');

-- An enrolled account keeps the earlier behaviour (another phone sees the
-- open reset; old approved phones cancel it).
select pg_temp.phone('ffffffff-ffff-4fff-8fff-ffffffffffff', 'f1', 11);
select pg_temp.phone('ffffffff-ffff-4fff-8fff-ffffffffffff', 'f2', 13);
select pg_temp.phone('ffffffff-ffff-4fff-8fff-ffffffffffff', 'f3', 15);
select public.bind_device_signed('ffffffff-ffff-4fff-8fff-ffffffffffff', pg_temp.s('f1'), pg_temp.d('f1'), true);
set local role authenticated;
select pg_temp.as_user('ffffffff-ffff-4fff-8fff-ffffffffffff', pg_temp.s('f2'));
insert into vals select 'reset-f', public.start_account_reset(pg_temp.d('f2'));
select pg_temp.as_user('ffffffff-ffff-4fff-8fff-ffffffffffff', pg_temp.s('f3'));
select is(public.start_account_reset(pg_temp.d('f3')), (select id from vals where k = 'reset-f'),
  'on an enrolled account another phone still sees the open reset');
reset role;

select * from finish();
rollback;
