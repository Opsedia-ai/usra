-- pgTAP: the sync backend blockers (B0.1–B0.7 in docs/sync-design.md).
-- Each rule is checked for the allowed caller, another user, and an
-- "SMS-only" session: signed in, but not bound to an approved device.
-- Run with: supabase test db
begin;
select plan(91);

-- People: A owns family F, B is a guardian, C is invited later.
-- Sessions: sA1 / sB1 / sC1 are bound to approved devices A1 / B1 / C1.
-- sA2 and sC2 only proved an SMS code (not bound). sA2 registers device A2.
insert into auth.users (id, phone) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '201000000011'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '201000000012'),
  ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', '201000000013');

create function pg_temp.as_user(p_user uuid, p_session uuid) returns text language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated', 'session_id', p_session)::text, true);
$$;
create function pg_temp.as_service() returns text language sql as $$
  select set_config('request.jwt.claims', '{"role":"service_role"}', true);
$$;
create function pg_temp.key(p_byte int) returns bytea language sql as $$
  select decode(repeat(lpad(to_hex(p_byte), 2, '0'), 32), 'hex');
$$;
create function pg_temp.head() returns bytea language sql as $$
  select hash from public.family_log
  where family_id = 'f0000000-0000-4000-8000-00000000000f' order by seq desc limit 1;
$$;
-- A log entry for family F (the signature is checked by the Edge Function, not here).
create function pg_temp.entry(p_seq int, p_prev bytea, p_type text, p_by uuid, p_extra jsonb default '{}')
returns bytea language sql as $$
  select convert_to((jsonb_build_object(
    'v', 1, 'family', 'f0000000-0000-4000-8000-00000000000f', 'seq', p_seq,
    'prev', private.b64url(p_prev), 'type', p_type, 'by', p_by, 'at', '0000000000000000')
    || p_extra)::text, 'UTF8');
$$;
create function pg_temp.append(p_seq int, p_type text, p_by uuid, p_extra jsonb default '{}')
returns jsonb language sql as $$
  select public.append_family_log('f0000000-0000-4000-8000-00000000000f', p_seq, pg_temp.head(),
    pg_temp.entry(p_seq, pg_temp.head(), p_type, p_by, p_extra), decode(repeat('00', 64), 'hex'));
$$;
create function pg_temp.rec(p_sync uuid, p_kv int, p_expected int, p_len int default 296)
returns jsonb language sql as $$
  select jsonb_build_array(jsonb_build_object(
    'sync_id', p_sync, 'key_version', p_kv, 'expected_revision', p_expected, 'deleted', false,
    'ciphertext', replace(encode(decode(repeat('cd', p_len), 'hex'), 'base64'), E'\n', '')));
$$;
create function pg_temp.push(p_seq int, p_records jsonb) returns jsonb language sql as $$
  select public.push_e2ee_records('f0000000-0000-4000-8000-00000000000f', p_seq, p_records);
$$;

-- Fixtures (service role, as the Edge Functions would after checking signatures)
select pg_temp.as_service();
insert into public.devices (id, user_id, platform, public_key, signing_public_key, created_session_id) values
  ('da000000-0000-4000-8000-0000000000a1', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'android',
   pg_temp.key(1), pg_temp.key(2), '5a000000-0000-4000-8000-0000000000a1'),
  ('db000000-0000-4000-8000-0000000000b1', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'ios',
   pg_temp.key(3), pg_temp.key(4), '5b000000-0000-4000-8000-0000000000b1'),
  ('dc000000-0000-4000-8000-0000000000c1', 'cccccccc-cccc-4ccc-8ccc-cccccccccccc', 'ios',
   pg_temp.key(5), pg_temp.key(6), '5c000000-0000-4000-8000-0000000000c1');
select public.approve_device('da000000-0000-4000-8000-0000000000a1');  -- each account's first device
select public.approve_device('db000000-0000-4000-8000-0000000000b1');
select public.approve_device('dc000000-0000-4000-8000-0000000000c1');
select public.bind_device_session('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  '5a000000-0000-4000-8000-0000000000a1', 'da000000-0000-4000-8000-0000000000a1');
select public.bind_device_session('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  '5b000000-0000-4000-8000-0000000000b1', 'db000000-0000-4000-8000-0000000000b1');
select public.bind_device_session('cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  '5c000000-0000-4000-8000-0000000000c1', 'dc000000-0000-4000-8000-0000000000c1');
insert into public.push_tokens (user_id, device_id, token) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'da000000-0000-4000-8000-0000000000a1', 'fcm-a1');
insert into public.families (id, created_by) values
  ('f0000000-0000-4000-8000-00000000000f', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
insert into public.family_members (family_id, user_id, role) values
  ('f0000000-0000-4000-8000-00000000000f', 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', 'guardian');
select pg_temp.append(1, 'genesis', 'da000000-0000-4000-8000-0000000000a1');

-- Privileges the apps never get -----------------------------------------------------
select ok(not has_column_privilege('authenticated', 'public.devices', 'status', 'INSERT')
      and not has_column_privilege('authenticated', 'public.devices', 'approved_at', 'INSERT')
      and not has_column_privilege('authenticated', 'public.devices', 'approved_by_device', 'INSERT')
      and not has_column_privilege('authenticated', 'public.devices', 'revoked_at', 'INSERT'),
  'B0.2: apps cannot insert device trust fields');
select ok(not has_column_privilege('authenticated', 'public.devices', 'id', 'INSERT')
      and not has_column_privilege('authenticated', 'public.devices', 'created_session_id', 'INSERT'),
  'B0.2: device ids and the registering session are server-set');
select ok(not has_column_privilege('authenticated', 'public.devices', 'public_key', 'UPDATE')
      and not has_column_privilege('authenticated', 'public.devices', 'signing_public_key', 'UPDATE'),
  'B0.1: apps cannot update device keys');
select ok(not has_column_privilege('authenticated', 'public.devices', 'status', 'UPDATE')
      and not has_column_privilege('authenticated', 'public.devices', 'approved_at', 'UPDATE'),
  'B0.2: apps cannot update trust fields');
select ok(not has_table_privilege('authenticated', 'public.families', 'DELETE'),
  'B0.4: no direct family delete');
select ok(not has_table_privilege('authenticated', 'public.family_members', 'INSERT')
      and not has_table_privilege('authenticated', 'public.family_members', 'UPDATE')
      and not has_column_privilege('authenticated', 'public.family_members', 'role', 'UPDATE')
      and not has_table_privilege('authenticated', 'public.family_members', 'DELETE'),
  'B0.5: no direct membership writes');
select ok(not has_table_privilege('authenticated', 'public.family_invites', 'INSERT')
      and not has_table_privilege('authenticated', 'public.family_invites', 'DELETE'),
  'B0.5: no direct invite writes');
select ok(not has_table_privilege('authenticated', 'public.e2ee_records', 'INSERT')
      and not has_table_privilege('authenticated', 'public.e2ee_records', 'UPDATE')
      and not has_column_privilege('authenticated', 'public.e2ee_records', 'ciphertext', 'UPDATE'),
  'B0.6: no direct record writes');
select ok(not has_table_privilege('authenticated', 'public.device_sessions', 'SELECT')
      and not has_table_privilege('authenticated', 'public.device_sessions', 'INSERT'),
  'apps cannot read or write session bindings');
select ok(not has_function_privilege('authenticated', 'public.approve_device(uuid, uuid)', 'execute')
      and not has_function_privilege('authenticated', 'public.revoke_device(uuid)', 'execute')
      and not has_function_privilege('authenticated', 'public.bind_device_session(uuid, uuid, uuid)', 'execute')
      and not has_function_privilege('authenticated', 'public.append_family_log(uuid, integer, bytea, bytea, bytea)', 'execute'),
  'signature-trusting functions are service-role only');
select ok(not has_function_privilege('anon', 'public.push_e2ee_records(uuid, integer, jsonb)', 'execute')
      and not has_function_privilege('anon', 'public.delete_family(uuid)', 'execute')
      and not has_function_privilege('anon', 'public.create_family_invite(uuid, text, text, timestamptz)', 'execute'),
  'anonymous callers cannot call the family functions');

-- The owner's SMS-only session (sA2) ------------------------------------------------
set local role authenticated;
select pg_temp.as_user('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '5a000000-0000-4000-8000-0000000000a2');

select throws_ok($$ insert into public.devices (platform, status) values ('ios', 'approved') $$,
  '42501', null, 'B0.2: an SMS-only session cannot insert an approved device');
select lives_ok($$ insert into public.devices (platform, app_version, public_key, signing_public_key)
  values ('ios', '1.0.0', pg_temp.key(7), pg_temp.key(8)) $$,
  'an SMS-only session registers a device');
select is((select status from public.devices
           where created_session_id = '5a000000-0000-4000-8000-0000000000a2'), 'pending',
  'the new device is pending and remembers the session that registered it');
select throws_ok($$ update public.devices set public_key = pg_temp.key(9)
  where id = 'da000000-0000-4000-8000-0000000000a1' $$,
  '42501', null, 'B0.1: an SMS-only session cannot overwrite the approved device''s key');
select throws_ok($$ update public.devices set signing_public_key = pg_temp.key(9)
  where created_session_id = '5a000000-0000-4000-8000-0000000000a2' $$,
  '42501', null, 'B0.1: nor the key of the device it registered');
insert into public.devices (platform, public_key, signing_public_key) values ('ios', pg_temp.key(10), pg_temp.key(11));
delete from public.devices where public_key = pg_temp.key(10);
select is((select count(*)::int from public.devices where public_key = pg_temp.key(10)), 0,
  'an SMS-only session deletes a device it registered (sign-out)');
update public.devices set last_seen_at = now() - interval '1 year'
  where id = 'da000000-0000-4000-8000-0000000000a1';
select ok((select last_seen_at > now() - interval '1 day' from public.devices
           where id = 'da000000-0000-4000-8000-0000000000a1'),
  'an SMS-only session cannot update another device row');
delete from public.devices where id = 'da000000-0000-4000-8000-0000000000a1';
select is((select count(*)::int from public.devices where id = 'da000000-0000-4000-8000-0000000000a1'), 1,
  'an SMS-only session cannot delete the approved device');
select throws_ok($$ select public.approve_device(
    (select id from public.devices where created_session_id = '5a000000-0000-4000-8000-0000000000a2'),
    'da000000-0000-4000-8000-0000000000a1') $$,
  '42501', null, 'an SMS-only session cannot approve its own device');

-- B0.3 push tokens
select is((select count(*)::int from public.push_tokens), 0,
  'B0.3: an SMS-only session cannot see the approved device''s push token');
select throws_ok($$ insert into public.push_tokens (device_id, token)
  values ('da000000-0000-4000-8000-0000000000a1', 'fcm-attacker') $$,
  '42501', null, 'B0.3: cannot add a token to another device of the account');
update public.push_tokens set token = 'fcm-attacker' where device_id = 'da000000-0000-4000-8000-0000000000a1';
delete from public.push_tokens where device_id = 'da000000-0000-4000-8000-0000000000a1';
select lives_ok($$ insert into public.push_tokens (device_id, token)
  select id, 'fcm-a2' from public.devices where created_session_id = '5a000000-0000-4000-8000-0000000000a2' $$,
  'B0.3: an unbound session adds a token for the device it registered');
reset role;
select is((select token from public.push_tokens where device_id = 'da000000-0000-4000-8000-0000000000a1'), 'fcm-a1',
  'B0.3: an SMS-only session cannot redirect or delete another device''s token');
set local role authenticated;

-- B0.4–B0.6 as the owner without an approved device
select throws_ok($$ select public.delete_family('f0000000-0000-4000-8000-00000000000f') $$,
  '42501', 'approved_device_required', 'B0.4: the owner''s SMS-only session cannot delete the family');
select throws_ok($$ insert into public.families (created_by) values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa') $$,
  '42501', null, 'an SMS-only session cannot create a family');
select throws_ok($$ select public.create_family_invite('f0000000-0000-4000-8000-00000000000f', 'viewer',
    encode(sha256('code-sms'::bytea), 'hex')) $$,
  '42501', 'approved_device_required', 'B0.5: the owner''s SMS-only session cannot create invites');
select throws_ok($$ select pg_temp.push(1, pg_temp.rec('e0000000-0000-4000-8000-000000000001', 1, 0)) $$,
  '42501', 'approved_device_required', 'B0.6: the owner''s SMS-only session cannot push records');
select is((select count(*)::int from public.family_log), 0, 'an SMS-only session reads no family log');
select is((select count(*)::int from public.family_invites), 0, 'an SMS-only owner session reads no invites');

-- The owner on an approved device (sA1) ----------------------------------------------
select pg_temp.as_user('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '5a000000-0000-4000-8000-0000000000a1');

select is((select count(*)::int from public.family_log), 1, 'an approved device reads the family log');
update public.push_tokens set token = 'fcm-a1-new' where device_id = 'da000000-0000-4000-8000-0000000000a1';
select is((select token from public.push_tokens), 'fcm-a1-new',
  'B0.3: a bound session updates its own device''s token and sees only that one');
delete from public.push_tokens where token = 'fcm-a2';
select throws_ok($$ insert into public.push_tokens (device_id, token)
  select id, 'fcm-a2-b' from public.devices where created_session_id = '5a000000-0000-4000-8000-0000000000a2' $$,
  '42501', null, 'B0.3: a bound session cannot add tokens for other devices, even its own account''s');
select ok(public.create_family_invite('f0000000-0000-4000-8000-00000000000f', 'viewer',
    encode(sha256('code-c'::bytea), 'hex')) is not null,
  'B0.5: the owner on an approved device creates an invite');
select lives_ok($$ select public.revoke_family_invite(public.create_family_invite(
    'f0000000-0000-4000-8000-00000000000f', 'viewer', encode(sha256('code-x'::bytea), 'hex'))) $$,
  'B0.5: and revokes one');
select throws_ok($$ select public.create_family_invite('f0000000-0000-4000-8000-00000000000f', 'owner',
    encode(sha256('code-y'::bytea), 'hex')) $$,
  '23514', null, 'an invite cannot make someone owner');
select throws_ok($$ select public.create_family_invite('f0000000-0000-4000-8000-00000000000f', 'viewer',
    encode(sha256('code-z'::bytea), 'hex'), now() + interval '30 days') $$,
  '22023', 'bad_expiry', 'an invite lasts at most 7 days');

-- The guardian on an approved device (sB1)
select pg_temp.as_user('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '5b000000-0000-4000-8000-0000000000b1');
select throws_ok($$ select public.delete_family('f0000000-0000-4000-8000-00000000000f') $$,
  '42501', 'forbidden', 'B0.4: a guardian cannot delete the family');
select throws_ok($$ select public.create_family_invite('f0000000-0000-4000-8000-00000000000f', 'viewer',
    encode(sha256('code-b'::bytea), 'hex')) $$,
  '42501', 'forbidden', 'B0.5: a guardian cannot create invites');
select is((select count(*)::int from public.family_invites), 0, 'a guardian cannot read invites');

-- C: first only SMS (sC2), then on an approved device (sC1)
select pg_temp.as_user('cccccccc-cccc-4ccc-8ccc-cccccccccccc', '5c000000-0000-4000-8000-0000000000c2');
select throws_ok($$ select public.accept_family_invite('code-c') $$,
  '42501', 'approved_device_required', 'accepting an invite needs an approved device');
select pg_temp.as_user('cccccccc-cccc-4ccc-8ccc-cccccccccccc', '5c000000-0000-4000-8000-0000000000c1');
select throws_ok($$ select public.delete_family('f0000000-0000-4000-8000-00000000000f') $$,
  '42501', 'forbidden', 'B0.4: another user cannot delete the family');
select throws_ok($$ select pg_temp.push(1, pg_temp.rec('e0000000-0000-4000-8000-000000000001', 1, 0)) $$,
  '42501', 'forbidden', 'B0.6: another user cannot push records');
select throws_ok($$ select public.revoke_family_invite((select id from public.family_invites limit 1)) $$,
  '42501', 'forbidden', 'B0.5: another user cannot revoke invites');
select is(public.accept_family_invite('code-c'), 'f0000000-0000-4000-8000-00000000000f'::uuid,
  'accepting on an approved device joins the family');
select throws_ok($$ select pg_temp.push(1, pg_temp.rec('e0000000-0000-4000-8000-000000000001', 1, 0)) $$,
  '42501', 'forbidden', 'a viewer cannot write records');

-- The family log: compare-and-set on the head (service role) -----------------------
reset role;
select pg_temp.as_service();

select is(public.append_family_log('f0000000-0000-4000-8000-00000000000f', 1, null,
    pg_temp.entry(1, null, 'genesis', 'da000000-0000-4000-8000-0000000000a1'),
    decode(repeat('00', 64), 'hex')) ->> 'error', 'head_mismatch',
  'an append at a seq the log already has is refused');
select is(public.append_family_log('f0000000-0000-4000-8000-00000000000f', 2, decode(repeat('00', 32), 'hex'),
    pg_temp.entry(2, decode(repeat('00', 32), 'hex'), 'change_role', 'da000000-0000-4000-8000-0000000000a1',
                  '{"user":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","role":"guardian"}'),
    decode(repeat('00', 64), 'hex')) ->> 'error', 'head_mismatch',
  'an append on a different prev hash is refused');
select is(public.append_family_log('f0000000-0000-4000-8000-00000000000f', 3, pg_temp.head(),
    pg_temp.entry(3, pg_temp.head(), 'change_role', 'da000000-0000-4000-8000-0000000000a1',
                  '{"user":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","role":"guardian"}'),
    decode(repeat('00', 64), 'hex')) ->> 'error', 'head_mismatch',
  'an append that skips a seq is refused');
select throws_ok($$ select public.append_family_log('f0000000-0000-4000-8000-00000000000f', 2, pg_temp.head(),
    pg_temp.entry(3, pg_temp.head(), 'rotate_key', 'da000000-0000-4000-8000-0000000000a1', '{"key_version":2}'),
    decode(repeat('00', 64), 'hex')) $$,
  '22023', 'entry_mismatch', 'the entry''s own seq must match');
select throws_ok($$ select pg_temp.append(2, 'change_role', 'db000000-0000-4000-8000-0000000000b1',
    '{"user":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","role":"guardian"}') $$,
  '42501', 'forbidden', 'a guardian''s device cannot change roles');
select throws_ok($$ select pg_temp.append(2, 'change_role',
    (select id from public.devices where created_session_id = '5a000000-0000-4000-8000-0000000000a2'),
    '{"user":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","role":"guardian"}') $$,
  '42501', 'signer_not_approved', 'a pending device cannot sign log entries, even the owner''s');
select throws_ok($$ select pg_temp.append(2, 'change_role', 'da000000-0000-4000-8000-0000000000a1',
    '{"user":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","role":"owner"}') $$,
  '22023', 'bad_role', 'nobody becomes owner by a role change');
select is(pg_temp.append(2, 'change_role', 'da000000-0000-4000-8000-0000000000a1',
    '{"user":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","role":"guardian"}') ->> 'ok', 'true',
  'B0.5: the owner''s device changes a role through the log');
select is((select role from public.family_members
           where family_id = 'f0000000-0000-4000-8000-00000000000f'
             and user_id = 'cccccccc-cccc-4ccc-8ccc-cccccccccccc'), 'guardian',
  'the change is mirrored into family_members');
select throws_ok($$ select pg_temp.append(3, 'add_member', 'da000000-0000-4000-8000-0000000000a1',
    '{"user":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","role":"viewer"}') $$,
  '42501', 'no_accepted_invite', 'add_member needs that person''s accepted invite');
select ok((select hash = sha256(entry) from public.family_log
           where family_id = 'f0000000-0000-4000-8000-00000000000f' and seq = 2),
  'the chain hash is sha256 of the entry bytes');

-- Records: compare-and-set on the log head and the revision --------------------------
set local role authenticated;
select pg_temp.as_user('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '5a000000-0000-4000-8000-0000000000a1');

select is(pg_temp.push(2, pg_temp.rec('e0000000-0000-4000-8000-000000000001', 1, 0)) -> 'results' -> 0 ->> 'revision',
  '1', 'B0.6: the owner pushes a new record');
select is(pg_temp.push(2, pg_temp.rec('e0000000-0000-4000-8000-000000000001', 1, 0)) -> 'results' -> 0 ->> 'error',
  'revision_conflict', 'creating the same sync id again conflicts');
select is(pg_temp.push(2, pg_temp.rec('e0000000-0000-4000-8000-000000000001', 1, 1)) -> 'results' -> 0 ->> 'revision',
  '2', 'a write on top of the stored revision succeeds');
select is(pg_temp.push(2, pg_temp.rec('e0000000-0000-4000-8000-000000000001', 1, 1)) -> 'results' -> 0 -> 'current' ->> 'revision',
  '2', 'a write on an old revision conflicts and returns the current row');
select is(pg_temp.push(1, pg_temp.rec('e0000000-0000-4000-8000-000000000002', 1, 0)) ->> 'error',
  'stale_log', 'a writer behind the log head is refused');
select is(pg_temp.push(2, pg_temp.rec('e0000000-0000-4000-8000-000000000002', 2, 0)) -> 'results' -> 0 ->> 'error',
  'stale_key', 'a record under a key version that is not current is refused');
select throws_ok($$ select pg_temp.push(2, pg_temp.rec('e0000000-0000-4000-8000-000000000002', 1, 0, 300)) $$,
  '23514', null, 'ciphertext that is not padded to a size bucket is refused');
select throws_ok($$ select pg_temp.push(2, pg_temp.rec('01890000-0000-7000-8000-000000000002', 1, 0)) $$,
  '23514', null, 'a UUID v7 (time-ordered) sync id is refused');
select is((select count(*)::int from public.e2ee_records), 1, 'an approved device reads the family''s records');

select pg_temp.as_user('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '5a000000-0000-4000-8000-0000000000a2');
select is((select count(*)::int from public.e2ee_records), 0, 'an SMS-only session reads no ciphertext');

select pg_temp.as_user('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '5b000000-0000-4000-8000-0000000000b1');
select is(pg_temp.push(2, pg_temp.rec('e0000000-0000-4000-8000-000000000003', 1, 0)) -> 'results' -> 0 ->> 'ok',
  'true', 'a guardian on an approved device pushes records');

reset role;
select throws_ok($$ insert into public.e2ee_records (family_id, sync_id, ciphertext)
  values ('f0000000-0000-4000-8000-00000000000f', 'e0000000-0000-4000-8000-000000000004', null) $$,
  '23502', null, 'ciphertext is required, tombstones included');

-- Removal, rotation and the key epoch
select is(pg_temp.append(3, 'remove_member', 'da000000-0000-4000-8000-0000000000a1',
    '{"user":"cccccccc-cccc-4ccc-8ccc-cccccccccccc","reason":"removed"}') ->> 'ok', 'true',
  'the owner removes a member through the log');
select ok((select rotation_pending from public.families where id = 'f0000000-0000-4000-8000-00000000000f'),
  'a removal makes a key rotation pending');
set local role authenticated;
select pg_temp.as_user('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '5a000000-0000-4000-8000-0000000000a1');
select is(pg_temp.push(3, pg_temp.rec('e0000000-0000-4000-8000-000000000001', 1, 2)) ->> 'error',
  'rotation_pending', 'no record is written until the key rotates');
reset role;
select throws_ok($$ select pg_temp.append(4, 'rotate_key', 'da000000-0000-4000-8000-0000000000a1',
    '{"key_version":3}') $$,
  '22023', 'bad_key_version', 'a rotation must go to the next key version');
select is(pg_temp.append(4, 'rotate_key', 'db000000-0000-4000-8000-0000000000b1', '{"key_version":2}') ->> 'ok',
  'true', 'any member''s device rotates the key');
select is((select current_key_version from public.families where id = 'f0000000-0000-4000-8000-00000000000f'), 2,
  'the new key version is mirrored');
set local role authenticated;
select pg_temp.as_user('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '5a000000-0000-4000-8000-0000000000a1');
select is(pg_temp.push(4, pg_temp.rec('e0000000-0000-4000-8000-000000000001', 1, 2)) -> 'results' -> 0 ->> 'error',
  'stale_key', 'after a rotation the old key version is refused');
select is(pg_temp.push(4, pg_temp.rec('e0000000-0000-4000-8000-000000000001', 2, 2)) -> 'results' -> 0 ->> 'revision',
  '3', 'and the new one accepted');
reset role;

-- Ownership
select throws_ok($$ select pg_temp.append(5, 'remove_member', 'da000000-0000-4000-8000-0000000000a1',
    '{"user":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","reason":"left"}') $$,
  '42501', 'owner_cannot_be_removed', 'the owner cannot leave without handing over');
select is(pg_temp.append(5, 'transfer_owner', 'da000000-0000-4000-8000-0000000000a1',
    '{"user":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb"}') ->> 'ok', 'true',
  'the owner hands the family over through the log');
select is((select string_agg(role, ',' order by role) from public.family_members
           where family_id = 'f0000000-0000-4000-8000-00000000000f'), 'guardian,owner',
  'the old owner becomes guardian, the new one owner');

-- Device keys and trust (even the service role goes through the functions) ----------
select throws_ok($$ update public.devices set public_key = pg_temp.key(9)
  where id = 'da000000-0000-4000-8000-0000000000a1' $$,
  '42501', 'device_keys_immutable', 'B0.1: keys are immutable for every role');
select throws_ok($$ update public.devices set status = 'approved', approved_at = now()
  where created_session_id = '5a000000-0000-4000-8000-0000000000a2' $$,
  '42501', 'device_trust_only_through_functions', 'B0.2: approval only through approve_device');
select throws_ok($$ select public.approve_device(
    (select id from public.devices where created_session_id = '5a000000-0000-4000-8000-0000000000a2')) $$,
  '42501', 'account_already_enrolled', 'a new device never self-approves once the account is enrolled');
select throws_ok($$ select public.approve_device(
    (select id from public.devices where created_session_id = '5a000000-0000-4000-8000-0000000000a2'),
    'dc000000-0000-4000-8000-0000000000c1') $$,
  '42501', 'approver_not_approved', 'another user''s device cannot approve it');
select lives_ok($$ select public.approve_device(
    (select id from public.devices where created_session_id = '5a000000-0000-4000-8000-0000000000a2'),
    'da000000-0000-4000-8000-0000000000a1') $$,
  'an approved device of the same account approves it');
select public.revoke_device((select id from public.devices
                             where created_session_id = '5a000000-0000-4000-8000-0000000000a2'));
select throws_ok($$ select public.approve_device(
    (select id from public.devices where created_session_id = '5a000000-0000-4000-8000-0000000000a2'),
    'da000000-0000-4000-8000-0000000000a1') $$,
  '42501', 'device_not_pending', 'revoked is final');
select throws_ok($$ select public.bind_device_session('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    '5a000000-0000-4000-8000-0000000000a2',
    (select id from public.devices where created_session_id = '5a000000-0000-4000-8000-0000000000a2')) $$,
  'P0002', 'unknown_device', 'a revoked device cannot be bound');
select throws_ok($$ select public.bind_device_session('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    '5a000000-0000-4000-8000-0000000000a1', 'db000000-0000-4000-8000-0000000000b1') $$,
  'P0002', 'unknown_device', 'a session cannot be bound to another user''s device');

-- Deleting the family
set local role authenticated;
select pg_temp.as_user('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '5a000000-0000-4000-8000-0000000000a1');
select throws_ok($$ select public.delete_family('f0000000-0000-4000-8000-00000000000f') $$,
  '42501', 'forbidden', 'B0.4/B0.7: after the hand-over the creator cannot delete the family');
select pg_temp.as_user('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '5b000000-0000-4000-8000-0000000000b1');
select lives_ok($$ select public.delete_family('f0000000-0000-4000-8000-00000000000f') $$,
  'B0.4: the owner on an approved device deletes the family');
reset role;
select is((select count(*)::int from public.e2ee_records
           where family_id = 'f0000000-0000-4000-8000-00000000000f'), 0,
  'with its records');

select * from finish();
rollback;
