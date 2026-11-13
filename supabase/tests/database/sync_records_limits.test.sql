-- pgTAP: record push/pull for two parents who both write, the one-call
-- sync_pull, base64 pulls, the kill switch and the limits of
-- docs/sync-design.md section 22 (migration 20261113000001).
-- Run with: supabase test db
begin;
select plan(44);

-- People: A owns family F, B is the second parent (guardian), D a viewer,
-- C an outsider with an approved phone. Sessions s?1 are bound to phones ?1;
-- sA2 has only signed in.
insert into auth.users (id, email) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'user31@example.com'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'user32@example.com'),
  ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'user33@example.com'),
  ('dddddddd-dddd-4ddd-8ddd-dddddddddddd', 'user34@example.com');

create function pg_temp.as_user(p_user uuid, p_session uuid) returns text language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated', 'session_id', p_session)::text, true);
$$;
create function pg_temp.as_a() returns text language sql as $$
  select pg_temp.as_user('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '5a000000-0000-4000-8000-0000000000a1'); $$;
create function pg_temp.as_b() returns text language sql as $$
  select pg_temp.as_user('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '5b000000-0000-4000-8000-0000000000b1'); $$;
create function pg_temp.key(p_byte int) returns bytea language sql as $$
  select decode(repeat(lpad(to_hex(p_byte), 2, '0'), 32), 'hex');
$$;
create function pg_temp.b64url(p bytea) returns text language sql as $$
  select rtrim(translate(encode(p, 'base64'), E'+/\n', '-_'), '=');
$$;
create function pg_temp.f() returns uuid language sql as $$ select 'f0000000-0000-4000-8000-00000000000f'::uuid; $$;
create function pg_temp.ct(p_byte text, p_len int default 296) returns bytea language sql as $$
  select decode(repeat(p_byte, p_len), 'hex');
$$;
create function pg_temp.rec(p_sync uuid, p_expected int, p_byte text default 'cd', p_deleted boolean default false)
returns jsonb language sql as $$
  select jsonb_build_object(
    'sync_id', p_sync, 'key_version', 1, 'expected_revision', p_expected, 'deleted', p_deleted,
    'ciphertext', replace(encode(pg_temp.ct(p_byte), 'base64'), E'\n', ''));
$$;
create function pg_temp.push(p_records jsonb, p_seq int default 1) returns jsonb language sql as $$
  select public.push_e2ee_records(pg_temp.f(), p_seq, p_records);
$$;
create function pg_temp.dev(p_device uuid) returns jsonb language sql as $$
  select jsonb_build_object('id', id, 'user', user_id, 'kind', kind,
    'kx', pg_temp.b64url(public_key), 'sig', pg_temp.b64url(signing_public_key))
  from public.devices where id = p_device;
$$;

-- Fixtures (as the Edge Functions would, after checking signatures) ----------
select set_config('request.jwt.claims', '{"role":"service_role"}', true);
insert into public.devices (id, user_id, platform, public_key, signing_public_key, created_session_id) values
  ('da000000-0000-4000-8000-0000000000a1', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'android',
   pg_temp.key(1), pg_temp.key(2), '5a000000-0000-4000-8000-0000000000a1'),
  ('db000000-0000-4000-8000-0000000000b1', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'ios',
   pg_temp.key(3), pg_temp.key(4), '5b000000-0000-4000-8000-0000000000b1'),
  ('dc000000-0000-4000-8000-0000000000c1', 'cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'ios',
   pg_temp.key(5), pg_temp.key(6), '5c000000-0000-4000-8000-0000000000c1'),
  ('dd000000-0000-4000-8000-0000000000d1', 'dddddddd-dddd-4ddd-8ddd-dddddddddddd', 'android',
   pg_temp.key(7), pg_temp.key(8), '5d000000-0000-4000-8000-0000000000d1');
select public.approve_device('da000000-0000-4000-8000-0000000000a1');
select public.approve_device('db000000-0000-4000-8000-0000000000b1');
select public.approve_device('dc000000-0000-4000-8000-0000000000c1');
select public.approve_device('dd000000-0000-4000-8000-0000000000d1');
select public.bind_device_session('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  '5a000000-0000-4000-8000-0000000000a1', 'da000000-0000-4000-8000-0000000000a1');
select public.bind_device_session('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  '5b000000-0000-4000-8000-0000000000b1', 'db000000-0000-4000-8000-0000000000b1');
select public.bind_device_session('cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  '5c000000-0000-4000-8000-0000000000c1', 'dc000000-0000-4000-8000-0000000000c1');
select public.bind_device_session('dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  '5d000000-0000-4000-8000-0000000000d1', 'dd000000-0000-4000-8000-0000000000d1');
insert into public.families (id, created_by) values (pg_temp.f(), 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
insert into public.family_members (family_id, user_id, role) values
  (pg_temp.f(), 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'guardian'),
  (pg_temp.f(), 'dddddddd-dddd-4ddd-8ddd-dddddddddddd', 'viewer');
select public.append_family_log(pg_temp.f(), 1, null,
  convert_to(jsonb_build_object(
    'v', 1, 'family', pg_temp.f(), 'seq', 1, 'prev', null, 'type', 'genesis',
    'by', 'da000000-0000-4000-8000-0000000000a1', 'at', '0000000000000000',
    'user', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'key_version', 1,
    'kc', pg_temp.b64url(decode(repeat('21', 32), 'hex')),
    'devices', jsonb_build_array(pg_temp.dev('da000000-0000-4000-8000-0000000000a1')))::text, 'UTF8'),
  decode(repeat('00', 64), 'hex'));
-- B and D were added directly above; their phones are current devices of F.
insert into public.family_devices (family_id, device_id, user_id, added_seq) values
  (pg_temp.f(), 'db000000-0000-4000-8000-0000000000b1', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 1),
  (pg_temp.f(), 'dd000000-0000-4000-8000-0000000000d1', 'dddddddd-dddd-4ddd-8ddd-dddddddddddd', 1);

-- Privileges ---------------------------------------------------------------
select ok(not has_table_privilege('authenticated', 'private.sync_switch', 'SELECT')
      and not has_table_privilege('authenticated', 'private.sync_switch', 'UPDATE'),
  'apps cannot read or flip the kill switch');
select ok(not has_table_privilege('authenticated', 'private.sync_call_counts', 'UPDATE')
      and not has_table_privilege('authenticated', 'private.family_write_counts', 'UPDATE'),
  'apps cannot reset their counters');
select ok(not has_function_privilege('anon', 'public.sync_pull(uuid, integer, xid8, uuid, integer)', 'execute')
      and not has_function_privilege('anon', 'public.pull_e2ee_changes(uuid, xid8, uuid, integer)', 'execute'),
  'anonymous callers cannot pull');
select ok(not has_function_privilege('authenticated', 'public.sync_housekeeping()', 'execute'),
  'apps cannot run housekeeping');
select is((select records_enabled from private.sync_switch), false, 'record sync is off by default');

-- Kill switch off ----------------------------------------------------------
set local role authenticated;
select pg_temp.as_b();
select is(pg_temp.push(jsonb_build_array(pg_temp.rec('e0000000-0000-4000-8000-000000000001', 0))) ->> 'error',
  'sync_disabled', 'switch off: push refused');
select is(public.sync_pull(pg_temp.f()) ->> 'error', 'sync_disabled', 'switch off: sync_pull refused');
select throws_ok($$ select * from public.pull_e2ee_changes(pg_temp.f()) $$,
  'PT503', 'sync_disabled', 'switch off: pull refused with 503');
select is((select count(*)::int from public.e2ee_records), 0, 'switch off: nothing written');
reset role;
update private.sync_switch set records_enabled = true;

-- Two parents write ------------------------------------------------------------
set local role authenticated;
select pg_temp.as_b();
select is(pg_temp.push(jsonb_build_array(
            pg_temp.rec('e0000000-0000-4000-8000-000000000001', 0, 'cd'),
            pg_temp.rec('e0000000-0000-4000-8000-000000000002', 0, 'ce'))) -> 'results',
  jsonb_build_array(
    jsonb_build_object('sync_id', 'e0000000-0000-4000-8000-000000000001', 'ok', true, 'revision', 1),
    jsonb_build_object('sync_id', 'e0000000-0000-4000-8000-000000000002', 'ok', true, 'revision', 1)),
  'the guardian pushes a batch of two new records in one call');
select pg_temp.as_a();
select is(pg_temp.push(jsonb_build_array(pg_temp.rec('e0000000-0000-4000-8000-000000000001', 1, 'cf'))) -> 'results' -> 0 ->> 'revision',
  '2', 'the owner edits the record the guardian wrote');
select pg_temp.as_b();
select is(pg_temp.push(jsonb_build_array(pg_temp.rec('e0000000-0000-4000-8000-000000000001', 1, 'd0'))) -> 'results' -> 0 ->> 'error',
  'revision_conflict', 'a write over an unmerged version is refused');
select is(pg_temp.push(jsonb_build_array(pg_temp.rec('e0000000-0000-4000-8000-000000000001', 1, 'd0'))) -> 'results' -> 0 -> 'current' ->> 'ciphertext',
  replace(encode(pg_temp.ct('cf'), 'base64'), E'\n', ''), 'the conflict answer carries the current version in base64');
select is(pg_temp.push(jsonb_build_array(pg_temp.rec('e0000000-0000-4000-8000-000000000001', 2, 'd0'))) -> 'results' -> 0 ->> 'revision',
  '3', 'after merging, the guardian writes on top');
select is(pg_temp.push(jsonb_build_array(pg_temp.rec('e0000000-0000-4000-8000-000000000003', 0)), 0) ->> 'error',
  'stale_log', 'a push from a phone behind the log head is refused');
select pg_temp.as_user('dddddddd-dddd-4ddd-8ddd-dddddddddddd', '5d000000-0000-4000-8000-0000000000d1');
select throws_ok($$ select pg_temp.push(jsonb_build_array(pg_temp.rec('e0000000-0000-4000-8000-000000000003', 0))) $$,
  '42501', 'forbidden', 'a viewer cannot write');

-- One-call pull ------------------------------------------------------------
-- Pulls only return rows of committed transactions older than every running
-- one, and this whole test is one transaction: give the rows older ids.
reset role;
alter table public.e2ee_records disable trigger e2ee_records_stamp;
update public.e2ee_records set change_txid = '10' where sync_id = 'e0000000-0000-4000-8000-000000000002';
update public.e2ee_records set change_txid = '11' where sync_id = 'e0000000-0000-4000-8000-000000000001';
alter table public.e2ee_records enable trigger e2ee_records_stamp;
set local role authenticated;
select pg_temp.as_a();
create temp table first_pull on commit drop as select public.sync_pull(pg_temp.f()) as r;
select is((select r ->> 'ok' from first_pull), 'true', 'sync_pull answers');
select is((select jsonb_array_length(r -> 'records') from first_pull), 2, 'it returns both records');
select is((select r -> 'records' -> 0 ->> 'ciphertext' from first_pull),
  replace(encode(pg_temp.ct('ce'), 'base64'), E'\n', ''), 'ciphertext comes as base64, not hex');
select is((select r -> 'records' -> 1 ->> 'revision' from first_pull), '3', 'with the current revision');
select is((select jsonb_array_length(r -> 'log') from first_pull), 1, 'the log from seq 1');
select is((select r -> 'log' -> 0 ->> 'seq' from first_pull), '1', 'starting at genesis');
select is((select r ->> 'head_seq' from first_pull), '1', 'and the head');
select is((select r ->> 'key_version' from first_pull), '1', 'the current key version');
select is((select jsonb_array_length(r -> 'epochs') from first_pull), 1, 'the epochs');
select is((select r ->> 'records_more' from first_pull), 'false', 'no more pages');
select is((select r ->> 'after_sync' from first_pull), 'e0000000-0000-4000-8000-000000000001',
  'the cursor names the last record');

select is(jsonb_array_length(public.sync_pull(pg_temp.f(), 1,
            (select (r ->> 'after_txid')::xid8 from first_pull),
            (select (r ->> 'after_sync')::uuid from first_pull)) -> 'records'),
  0, 'a pull from the cursor with nothing new returns no records');
select is(jsonb_array_length(public.sync_pull(pg_temp.f(), 1) -> 'log'), 0,
  'and no log entries the phone already has');
select is(jsonb_array_length(public.sync_pull(pg_temp.f(), 0, '0', null, 1) -> 'records'), 1,
  'pages respect the limit');
select is(public.sync_pull(pg_temp.f(), 0, '0', null, 1) ->> 'records_more', 'true',
  'and say another page waits');
select is((select ciphertext from public.pull_e2ee_changes(pg_temp.f()) limit 1),
  replace(encode(pg_temp.ct('ce'), 'base64'), E'\n', ''), 'pull_e2ee_changes returns base64 too');

select pg_temp.as_user('cccccccc-cccc-4ccc-8ccc-cccccccccccc', '5c000000-0000-4000-8000-0000000000c1');
select throws_ok($$ select public.sync_pull(pg_temp.f()) $$, '42501', 'forbidden',
  'an outsider''s approved phone cannot pull');
select pg_temp.as_user('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '5a000000-0000-4000-8000-0000000000a2');
select throws_ok($$ select public.sync_pull(pg_temp.f()) $$, '42501', 'forbidden',
  'a sign-in-only session cannot pull');
reset role;

-- Limits -------------------------------------------------------------------
-- 60 calls a minute per phone.
insert into private.sync_call_counts (device_id, minute, calls)
values ('db000000-0000-4000-8000-0000000000b1', date_trunc('minute', now()), 60)
on conflict (device_id, minute) do update set calls = 60;
set local role authenticated;
select pg_temp.as_b();
select throws_ok($$ select public.sync_pull(pg_temp.f()) $$, 'PT429', 'rate_limited',
  'the 61st call in a minute is refused with 429');
select throws_ok($$ select pg_temp.push(jsonb_build_array(pg_temp.rec('e0000000-0000-4000-8000-000000000004', 0))) $$,
  'PT429', 'rate_limited', 'pushes count too');
reset role;
select is((select calls from private.sync_call_counts
           where device_id = 'db000000-0000-4000-8000-0000000000b1' and minute = date_trunc('minute', now())),
  60, 'a refused call does not count');
delete from private.sync_call_counts;

-- 20,000 record writes a day per family.
insert into private.family_write_counts (family_id, day, writes)
values (pg_temp.f(), current_date, 19999)
on conflict (family_id, day) do update set writes = 19999;
set local role authenticated;
select pg_temp.as_b();
select is(pg_temp.push(jsonb_build_array(
            pg_temp.rec('e0000000-0000-4000-8000-000000000004', 0),
            pg_temp.rec('e0000000-0000-4000-8000-000000000005', 0))) ->> 'error',
  'daily_limit', 'a batch past 20,000 writes a day is refused');
select is(pg_temp.push(jsonb_build_array(pg_temp.rec('e0000000-0000-4000-8000-000000000004', 0))) ->> 'ok',
  'true', 'a batch up to the limit goes through');
reset role;
select is((select writes from private.family_write_counts where family_id = pg_temp.f() and day = current_date),
  20000, 'writes are counted');
delete from private.family_write_counts;

-- 20,000 live records per family (3 exist; add 19,997).
insert into public.e2ee_records (family_id, sync_id, key_version, ciphertext)
select pg_temp.f(), gen_random_uuid(), 1, pg_temp.ct('ab') from generate_series(1, 19997);
set local role authenticated;
select pg_temp.as_b();
select is(pg_temp.push(jsonb_build_array(pg_temp.rec('e0000000-0000-4000-8000-000000000006', 0))) ->> 'error',
  'family_full', 'a new record past 20,000 live records is refused');
select is(pg_temp.push(jsonb_build_array(pg_temp.rec('e0000000-0000-4000-8000-000000000001', 3))) -> 'results' -> 0 ->> 'ok',
  'true', 'edits to existing records still go through');
select is(pg_temp.push(jsonb_build_array(pg_temp.rec('e0000000-0000-4000-8000-000000000002', 1, 'cd', true))) -> 'results' -> 0 ->> 'ok',
  'true', 'and so do deletes');
reset role;

-- Housekeeping ---------------------------------------------------------------
insert into public.e2ee_records (family_id, sync_id, key_version, ciphertext, deleted_at) values
  (pg_temp.f(), 'e0000000-0000-4000-8000-0000000000aa', 1, pg_temp.ct('ab'), now() - interval '400 days'),
  (pg_temp.f(), 'e0000000-0000-4000-8000-0000000000ab', 1, pg_temp.ct('ab'), now() - interval '300 days');
insert into private.sync_call_counts values ('db000000-0000-4000-8000-0000000000b1', now() - interval '3 days', 5);
select public.sync_housekeeping();
select is((select array_agg(sync_id::text order by sync_id) from public.e2ee_records
           where sync_id in ('e0000000-0000-4000-8000-0000000000aa', 'e0000000-0000-4000-8000-0000000000ab')),
  array['e0000000-0000-4000-8000-0000000000ab'], 'tombstones older than a year are purged, younger ones kept');

select * from finish();
rollback;
