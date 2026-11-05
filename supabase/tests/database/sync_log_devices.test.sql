-- pgTAP: device binding, approval, pairing, recovery and reset (B1–B4), and the
-- signed family log, invites, key wraps, rotation and head beacons (B5, B6, B9)
-- from docs/sync-design.md. Signatures are checked by the Edge Functions
-- (tests/functions); here every rule the database enforces is checked for the
-- allowed caller and for another user, an SMS-only session (signed in, not bound
-- to an approved device), a revoked or removed device, and replays.
-- Run with: supabase test db
begin;
select plan(174);

-- People: A owns family F; B joins as guardian and later resets their account;
-- C is an outsider; D never enrolled.
insert into auth.users (id, phone) values
  ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', '201000000021'),
  ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb', '201000000022'),
  ('cccccccc-cccc-4ccc-8ccc-cccccccccccc', '201000000023'),
  ('dddddddd-dddd-4ddd-8ddd-dddddddddddd', '201000000024');

create function pg_temp.u(p text) returns uuid language sql immutable as $$
  select (repeat(lower(p), 8) || '-' || repeat(lower(p), 4) || '-4' || repeat(lower(p), 3) || '-8'
          || repeat(lower(p), 3) || '-' || repeat(lower(p), 12))::uuid;
$$;
-- Devices and Auth sessions by short name ('a1' = A's first phone / session).
create function pg_temp.d(p text) returns uuid language sql immutable as $$
  select ('d0000000-0000-4000-8000-0000000000' || lower(p))::uuid;
$$;
create function pg_temp.s(p text) returns uuid language sql immutable as $$
  select ('50000000-0000-4000-8000-0000000000' || lower(p))::uuid;
$$;
create function pg_temp.f() returns uuid language sql immutable as $$
  select 'f0000000-0000-4000-8000-00000000000f'::uuid;
$$;
create function pg_temp.key(p_byte int) returns bytea language sql immutable as $$
  select decode(repeat(lpad(to_hex(p_byte), 2, '0'), 32), 'hex');
$$;
create function pg_temp.bytes(p_hex text, p_n int) returns bytea language sql immutable as $$
  select decode(repeat(p_hex, p_n), 'hex');
$$;
create function pg_temp.b64(p bytea) returns text language sql immutable as $$
  select replace(encode(p, 'base64'), E'\n', '');
$$;
create function pg_temp.b64url(p bytea) returns text language sql immutable as $$
  select rtrim(translate(encode(p, 'base64'), E'+/\n', '-_'), '=');
$$;
create function pg_temp.as_user(p_user uuid, p_session uuid) returns text language sql as $$
  select set_config('request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated', 'session_id', p_session)::text, true);
$$;

-- Values the steps hand to each other (nonces, generated ids).
create temp table vals (k text primary key, b bytea, id uuid);
grant all on vals to public;
create function pg_temp.v(p text) returns bytea language sql as $$ select b from vals where k = p; $$;
create function pg_temp.id(p text) returns uuid language sql as $$ select id from vals where k = p; $$;

create function pg_temp.dev(p_device uuid) returns jsonb language sql as $$
  select jsonb_build_object('id', id, 'user', user_id, 'kind', kind,
    'kx', pg_temp.b64url(public_key), 'sig', pg_temp.b64url(signing_public_key))
  from public.devices where id = p_device;
$$;
create function pg_temp.head() returns bytea language sql as $$
  select hash from public.family_log where family_id = pg_temp.f() order by seq desc limit 1;
$$;
create function pg_temp.head_seq() returns int language sql as $$
  select coalesce(max(seq), 0) from public.family_log where family_id = pg_temp.f();
$$;
create function pg_temp.entry(p_seq int, p_prev bytea, p_type text, p_by uuid, p_extra jsonb) returns bytea
language sql as $$
  select convert_to((jsonb_build_object(
    'v', 1, 'family', pg_temp.f(), 'seq', p_seq, 'prev', pg_temp.b64url(p_prev), 'type', p_type,
    'by', p_by, 'at', '019300f8a1b20003') || p_extra)::text, 'UTF8');
$$;
-- The next entry on top of the current head, appended through the caller checks.
create function pg_temp.next(p_user uuid, p_session uuid, p_type text, p_by uuid, p_extra jsonb) returns jsonb
language sql as $$
  select public.append_family_log_as(p_user, p_session, pg_temp.f(), pg_temp.head_seq() + 1, pg_temp.head(),
    pg_temp.entry(pg_temp.head_seq() + 1, pg_temp.head(), p_type, p_by, p_extra), pg_temp.bytes('00', 64));
$$;
create function pg_temp.raw(p_user uuid, p_session uuid, p_entry bytea) returns jsonb language sql as $$
  select public.append_family_log_as(p_user, p_session, pg_temp.f(), pg_temp.head_seq() + 1, pg_temp.head(),
    p_entry, pg_temp.bytes('00', 64));
$$;
create function pg_temp.genesis(p_devices jsonb) returns jsonb language sql as $$
  select jsonb_build_object('user', pg_temp.u('a'), 'key_version', 1,
    'kc', pg_temp.b64url(pg_temp.bytes('21', 32)), 'devices', p_devices);
$$;
create function pg_temp.wraps(p_devices uuid[]) returns jsonb language sql as $$
  select jsonb_agg(jsonb_build_object('recipient', x, 'enc', pg_temp.b64(pg_temp.bytes('01', 32)),
    'ct', pg_temp.b64(pg_temp.bytes('02', 48)), 'sig', pg_temp.b64(pg_temp.bytes('03', 64))))
  from unnest(p_devices) x;
$$;
create function pg_temp.current_devices() returns uuid[] language sql as $$
  select array_agg(fd.device_id order by fd.device_id) from public.family_devices fd
  join public.family_members m using (family_id, user_id)
  where fd.family_id = pg_temp.f() and m.status = 'active';
$$;
create function pg_temp.recipients(p_devices uuid[]) returns bytea language sql as $$
  select sha256(string_agg(decode(replace(x::text, '-', ''), 'hex'), ''::bytea order by x)) from unnest(p_devices) x;
$$;
-- rotate_key; by default valid for the current devices.
create function pg_temp.rotate(p_user uuid, p_session uuid, p_by uuid, p_kv int,
                               p_devices uuid[] default null, p_recipients bytea default null,
                               p_history_hash bytea default null) returns jsonb language sql as $$
  select public.append_family_log_as(p_user, p_session, pg_temp.f(), pg_temp.head_seq() + 1, pg_temp.head(),
    pg_temp.entry(pg_temp.head_seq() + 1, pg_temp.head(), 'rotate_key', p_by, jsonb_build_object(
      'key_version', p_kv, 'kc', pg_temp.b64url(pg_temp.bytes('22', 32)),
      'history', pg_temp.b64url(coalesce(p_history_hash, sha256(pg_temp.bytes('11', 72)))),
      'recipients', pg_temp.b64url(coalesce(p_recipients, pg_temp.recipients(pg_temp.current_devices()))))),
    pg_temp.bytes('00', 64), pg_temp.bytes('11', 72),
    pg_temp.wraps(coalesce(p_devices, pg_temp.current_devices())));
$$;
create function pg_temp.lookup(p_secret bytea) returns text language sql immutable as $$
  select encode(sha256(convert_to('usra/v1/invite-lookup', 'UTF8') || '\x00'::bytea || p_secret), 'hex');
$$;
create function pg_temp.rec(p_sync uuid, p_kv int, p_expected int) returns jsonb language sql as $$
  select jsonb_build_array(jsonb_build_object(
    'sync_id', p_sync, 'key_version', p_kv, 'expected_revision', p_expected, 'deleted', false,
    'ciphertext', pg_temp.b64(pg_temp.bytes('cd', 296))));
$$;
create function pg_temp.beacon(p_device uuid, p_seq int, p_hash bytea) returns bytea language sql as $$
  select convert_to(jsonb_build_object('v', 1, 'family', pg_temp.f(), 'device', p_device, 'seq', p_seq,
    'h', pg_temp.b64url(p_hash), 'at', '019300f8a1b20003')::text, 'UTF8');
$$;

-- Phones registered by their own SMS sessions, as the app does after sign-in.
insert into public.devices (id, user_id, platform, public_key, signing_public_key, created_session_id) values
  (pg_temp.d('a1'), pg_temp.u('a'), 'android', pg_temp.key(1), pg_temp.key(2), pg_temp.s('a1')),
  (pg_temp.d('a2'), pg_temp.u('a'), 'ios', pg_temp.key(3), pg_temp.key(4), pg_temp.s('a2')),
  (pg_temp.d('a3'), pg_temp.u('a'), 'ios', pg_temp.key(5), pg_temp.key(6), pg_temp.s('a3')),
  (pg_temp.d('a4'), pg_temp.u('a'), 'ios', pg_temp.key(7), pg_temp.key(8), pg_temp.s('a4')),
  (pg_temp.d('a5'), pg_temp.u('a'), 'ios', pg_temp.key(19), pg_temp.key(20), pg_temp.s('a5')),
  (pg_temp.d('b1'), pg_temp.u('b'), 'android', pg_temp.key(11), pg_temp.key(12), pg_temp.s('b1')),
  (pg_temp.d('b2'), pg_temp.u('b'), 'android', pg_temp.key(15), pg_temp.key(16), pg_temp.s('b2')),
  (pg_temp.d('b9'), pg_temp.u('b'), 'android', pg_temp.key(21), pg_temp.key(22), pg_temp.s('b9')),
  (pg_temp.d('c1'), pg_temp.u('c'), 'ios', pg_temp.key(13), pg_temp.key(14), pg_temp.s('c1')),
  (pg_temp.d('d1'), pg_temp.u('d'), 'ios', pg_temp.key(23), pg_temp.key(24), pg_temp.s('d1'));

-- =====================================================================================
-- Privileges
-- =====================================================================================
select ok(not has_function_privilege('authenticated', 'public.take_device_challenge(uuid, uuid, text, uuid, bytea)', 'execute')
      and not has_function_privilege('authenticated', 'public.bind_device_signed(uuid, uuid, uuid, boolean)', 'execute')
      and not has_function_privilege('authenticated', 'public.approve_device_signed(uuid, uuid, uuid, uuid, bytea)', 'execute')
      and not has_function_privilege('authenticated', 'public.recover_device_signed(uuid, uuid, uuid)', 'execute')
      and not has_function_privilege('authenticated', 'public.append_family_log_as(uuid, uuid, uuid, integer, bytea, bytea, bytea, bytea, jsonb)', 'execute')
      and not has_function_privilege('authenticated', 'public.publish_family_head(uuid, uuid, uuid, bytea, bytea)', 'execute')
      and not has_function_privilege('authenticated', 'public.device_signing_key(uuid)', 'execute')
      and not has_function_privilege('authenticated', 'public.session_device_key(uuid, uuid)', 'execute')
      and not has_function_privilege('authenticated', 'public.complete_account_resets()', 'execute')
      and not has_function_privilege('authenticated', 'public.sync_housekeeping()', 'execute'),
  'functions that trust a checked signature, or run from cron, are service-role only');
select ok(not has_function_privilege('anon', 'public.issue_device_challenge(text, uuid)', 'execute')
      and not has_function_privilege('anon', 'public.pairing_start(uuid, bytea)', 'execute')
      and not has_function_privilege('anon', 'public.start_account_reset(uuid)', 'execute')
      and not has_function_privilege('anon', 'public.accept_family_invite(text, jsonb, bytea)', 'execute')
      and not has_function_privilege('anon', 'public.put_family_key_wraps(uuid, integer, jsonb)', 'execute')
      and not has_function_privilege('anon', 'public.set_account_recovery(bytea, jsonb, bytea, bytea)', 'execute'),
  'anonymous callers cannot call any device or family function');
select ok(not has_table_privilege('authenticated', 'public.device_challenges', 'SELECT')
      and not has_table_privilege('authenticated', 'public.device_challenges', 'INSERT')
      and not has_table_privilege('authenticated', 'public.invite_accept_attempts', 'INSERT'),
  'apps cannot read nonces or touch the attempt counters');
select ok(not has_table_privilege('authenticated', 'public.family_devices', 'INSERT')
      and not has_table_privilege('authenticated', 'public.family_devices', 'DELETE')
      and not has_table_privilege('authenticated', 'public.family_epochs', 'INSERT')
      and not has_table_privilege('authenticated', 'public.family_key_wraps', 'INSERT')
      and not has_table_privilege('authenticated', 'public.family_key_wraps', 'UPDATE')
      and not has_table_privilege('authenticated', 'public.family_heads', 'INSERT')
      and not has_table_privilege('authenticated', 'public.families', 'INSERT'),
  'no direct writes to family devices, epochs, wraps, beacons or families');
select ok(not has_table_privilege('authenticated', 'public.account_recovery', 'INSERT')
      and not has_table_privilege('authenticated', 'public.account_recovery', 'UPDATE')
      and not has_table_privilege('authenticated', 'public.pairing_sessions', 'INSERT')
      and not has_table_privilege('authenticated', 'public.pairing_sessions', 'UPDATE')
      and not has_table_privilege('authenticated', 'public.pairing_bundles', 'INSERT')
      and not has_table_privilege('authenticated', 'public.account_resets', 'INSERT')
      and not has_table_privilege('authenticated', 'public.account_resets', 'UPDATE'),
  'no direct writes to recovery, pairing or reset state');
select ok(not has_column_privilege('authenticated', 'public.devices', 'kind', 'INSERT'),
  'apps cannot register a recovery device directly');

-- =====================================================================================
-- Binding a session by proving the device key (B2), and re-registering
-- =====================================================================================
set local role authenticated;
select pg_temp.as_user(pg_temp.u('a'), pg_temp.s('a1'));
insert into vals (k, b) select 'n-bind', decode(public.issue_device_challenge('bind', pg_temp.d('a1')), 'base64');
insert into vals (k, b) select 'n-old', decode(public.issue_device_challenge('bind', pg_temp.d('a1')), 'base64');
select is(octet_length(pg_temp.v('n-bind')), 32, 'an SMS-only session gets a 32-byte nonce to bind its phone');
select throws_ok($$ select public.issue_device_challenge('bind', pg_temp.d('c1')) $$,
  'P0002', 'unknown_device', 'no nonce for another user''s phone');
select throws_ok($$ select public.issue_device_challenge('approve', pg_temp.d('a2')) $$,
  '42501', 'approved_device_required', 'an SMS-only session cannot ask to approve a phone');
select throws_ok($$ select public.issue_device_challenge('sign-anything', pg_temp.d('a1')) $$,
  '22023', 'bad_purpose', 'nonces only for known purposes');
reset role;

select throws_ok($$ select public.take_device_challenge(pg_temp.u('a'), pg_temp.s('a7'), 'bind', pg_temp.d('a1'),
    pg_temp.v('n-bind')) $$,
  '42501', 'bad_challenge', 'a nonce only works for the session it was issued to');
select throws_ok($$ select public.take_device_challenge(pg_temp.u('a'), pg_temp.s('a1'), 'recover', pg_temp.d('a1'),
    pg_temp.v('n-bind')) $$,
  '42501', 'bad_challenge', 'and only for its purpose');
select is(public.take_device_challenge(pg_temp.u('a'), pg_temp.s('a1'), 'bind', pg_temp.d('a1'),
    pg_temp.v('n-bind')) -> 'signer' ->> 'sig', pg_temp.b64(pg_temp.key(2)),
  'binding is checked against the phone''s own registered signing key');
select throws_ok($$ select public.take_device_challenge(pg_temp.u('a'), pg_temp.s('a1'), 'bind', pg_temp.d('a1'),
    pg_temp.v('n-bind')) $$,
  '42501', 'bad_challenge', 'a nonce is used once (replay)');
update public.device_challenges set expires_at = now() - interval '1 second' where nonce = pg_temp.v('n-old');
select throws_ok($$ select public.take_device_challenge(pg_temp.u('a'), pg_temp.s('a1'), 'bind', pg_temp.d('a1'),
    pg_temp.v('n-old')) $$,
  '42501', 'bad_challenge', 'an expired nonce is refused');

select is(public.bind_device_signed(pg_temp.u('a'), pg_temp.s('a1'), pg_temp.d('a1'), true) ->> 'status', 'approved',
  'the account''s first phone binds its session and approves itself');
select ok((select sync_enrolled_at is not null from public.accounts where id = pg_temp.u('a')),
  'which enrols the account');
select throws_ok($$ select public.bind_device_signed(pg_temp.u('a'), pg_temp.s('a2'), pg_temp.d('a2'), true) $$,
  '42501', 'account_already_enrolled', 'a second phone never approves itself');

-- The session is lost (refresh token revoked); the phone signs in again as a7
-- and proves A1's key: same device row, new session.
select lives_ok($$ select public.bind_device_signed(pg_temp.u('a'), pg_temp.s('a7'), pg_temp.d('a1'), false) $$,
  're-registration: a new session binds to the existing phone that proves its key');
select is((select array_agg(session_id) from public.device_sessions where device_id = pg_temp.d('a1')),
  array[pg_temp.s('a7')], 'and the lost session is unbound');
set local role authenticated;
select pg_temp.as_user(pg_temp.u('a'), pg_temp.s('a1'));
select ok(not private.device_ok(), 'the lost session no longer counts');
select pg_temp.as_user(pg_temp.u('a'), pg_temp.s('a7'));
select ok(private.device_ok(), 'the new session counts, without a second device row');
select lives_ok($$ insert into public.push_tokens (device_id, token) values (pg_temp.d('a1'), 'fcm-a1') $$,
  'and writes the phone''s push token again');
reset role;
select throws_ok($$ select public.bind_device_session(pg_temp.u('a'), pg_temp.s('a9'), pg_temp.d('c1')) $$,
  'P0002', 'unknown_device', 'a session cannot bind another user''s phone');

insert into public.device_challenges (nonce, purpose, user_id, session_id, device_id)
select extensions.gen_random_bytes(32), 'bind', pg_temp.u('a'), pg_temp.s('a2'), pg_temp.d('a2')
from generate_series(1, 20);
set local role authenticated;
select pg_temp.as_user(pg_temp.u('a'), pg_temp.s('a2'));
select throws_ok($$ select public.issue_device_challenge('bind', pg_temp.d('a2')) $$,
  '54000', 'too_many_challenges', 'at most 20 nonces per session per hour');
reset role;

-- Other accounts' first phones.
select public.bind_device_signed(pg_temp.u('b'), pg_temp.s('b1'), pg_temp.d('b1'), true);
select public.bind_device_signed(pg_temp.u('c'), pg_temp.s('c1'), pg_temp.d('c1'), true);

-- =====================================================================================
-- Way 1: an approved phone approves a new one (B3)
-- =====================================================================================
set local role authenticated;
select pg_temp.as_user(pg_temp.u('a'), pg_temp.s('a7'));
insert into vals (k, b) select 'n-approve', decode(public.issue_device_challenge('approve', pg_temp.d('a2')), 'base64');
select is(octet_length(pg_temp.v('n-approve')), 32, 'an approved phone gets a nonce to approve a pending phone');
select throws_ok($$ select public.issue_device_challenge('approve', pg_temp.d('a1')) $$,
  '42501', 'device_not_pending', 'but not to approve itself or an approved phone');
select pg_temp.as_user(pg_temp.u('c'), pg_temp.s('c1'));
select throws_ok($$ select public.issue_device_challenge('approve', pg_temp.d('a2')) $$,
  'P0002', 'unknown_device', 'another account''s approved phone cannot approve it');
reset role;

select is(public.take_device_challenge(pg_temp.u('a'), pg_temp.s('a7'), 'approve', pg_temp.d('a2'),
    pg_temp.v('n-approve')) -> 'signer' ->> 'id', pg_temp.d('a1')::text,
  'the approval is checked against the approving phone''s key, over the new phone''s keys');
select throws_ok($$ select public.approve_device_signed(pg_temp.u('a'), pg_temp.s('a2'), pg_temp.d('a2')) $$,
  '42501', 'approved_device_required', 'an SMS-only session cannot approve, not even its own new phone');
select throws_ok($$ select public.approve_device_signed(pg_temp.u('c'), pg_temp.s('c1'), pg_temp.d('a2')) $$,
  'P0002', 'unknown_device', 'another account''s session cannot approve it');
select is(public.approve_device_signed(pg_temp.u('a'), pg_temp.s('a7'), pg_temp.d('a2'), null, '\x0102'::bytea)
    ->> 'approved_by', pg_temp.d('a1')::text,
  'an approved phone approves the new phone');
select throws_ok($$ select public.approve_device_signed(pg_temp.u('a'), pg_temp.s('a7'), pg_temp.d('a2')) $$,
  '42501', 'device_not_pending', 'approving twice is refused');
set local role authenticated;
select pg_temp.as_user(pg_temp.u('a'), pg_temp.s('a7'));
select is((select count(*)::int from public.pairing_bundles), 0, 'the pairing bundle is not readable by other phones');
select pg_temp.as_user(pg_temp.u('a'), pg_temp.s('a2'));
select is((select bundle from public.pairing_bundles), '\x0102'::bytea,
  'the new phone''s session reads the pairing bundle left for it');
delete from public.pairing_bundles;
reset role;
select is((select count(*)::int from public.pairing_bundles), 0, 'and deletes it once read');
select public.bind_device_signed(pg_temp.u('a'), pg_temp.s('a2'), pg_temp.d('a2'), false);

-- =====================================================================================
-- Way 2: comparison code, commit then reveal (B4)
-- =====================================================================================
set local role authenticated;
select pg_temp.as_user(pg_temp.u('a'), pg_temp.s('a3'));
insert into vals (k, id) select 'p1', public.pairing_start(pg_temp.d('a3'),
  sha256(pg_temp.bytes('11', 32) || pg_temp.key(5) || pg_temp.key(6)));
select ok(pg_temp.id('p1') is not null, 'a pending phone opens a comparison session with its commitment');
select throws_ok($$ select public.pairing_start(pg_temp.d('a1'), pg_temp.bytes('00', 32)) $$,
  '42501', 'forbidden', 'only for the session''s own new phone');
select throws_ok($$ select public.pairing_respond(pg_temp.id('p1'), pg_temp.bytes('22', 32)) $$,
  '42501', 'approved_device_required', 'an SMS-only session cannot respond');
select pg_temp.as_user(pg_temp.u('a'), pg_temp.s('a7'));
select lives_ok($$ select public.pairing_respond(pg_temp.id('p1'), pg_temp.bytes('22', 32)) $$,
  'an approved phone responds with its own nonce');
select throws_ok($$ select public.pairing_respond(pg_temp.id('p1'), pg_temp.bytes('23', 32)) $$,
  'P0002', 'pairing_unavailable', 'a session takes one response');
select pg_temp.as_user(pg_temp.u('a'), pg_temp.s('a3'));
select is(public.pairing_reveal(pg_temp.id('p1'), pg_temp.bytes('33', 32)) ->> 'error', 'commitment_mismatch',
  'a reveal that does not open the commitment fails');
select is((select status from public.pairing_sessions where id = pg_temp.id('p1')), 'failed',
  'and ends the session');
reset role;
select throws_ok($$ select public.approve_device_signed(pg_temp.u('a'), pg_temp.s('a7'), pg_temp.d('a3'),
    pg_temp.id('p1')) $$,
  'P0002', 'pairing_unavailable', 'a failed comparison session cannot approve');

set local role authenticated;
select pg_temp.as_user(pg_temp.u('a'), pg_temp.s('a3'));
insert into vals (k, id) select 'p2', public.pairing_start(pg_temp.d('a3'),
  sha256(pg_temp.bytes('11', 32) || pg_temp.key(5) || pg_temp.key(6)));
select pg_temp.as_user(pg_temp.u('a'), pg_temp.s('a7'));
select public.pairing_respond(pg_temp.id('p2'), pg_temp.bytes('22', 32));
select pg_temp.as_user(pg_temp.u('a'), pg_temp.s('a3'));
select is(public.pairing_reveal(pg_temp.id('p2'), pg_temp.bytes('11', 32)) ->> 'ok', 'true',
  'the right nonce opens the commitment');
insert into vals (k, id) select 'p3', public.pairing_start(pg_temp.d('a3'), pg_temp.bytes('00', 32));
select throws_ok($$ select public.pairing_start(pg_temp.d('a3'), pg_temp.bytes('00', 32)) $$,
  '54000', 'too_many_pairing_sessions', 'at most 3 comparison sessions per account per hour');
select pg_temp.as_user(pg_temp.u('c'), pg_temp.s('c1'));
select is((select count(*)::int from public.pairing_sessions), 0, 'another user sees no pairing sessions');
select throws_ok($$ select public.pairing_cancel(pg_temp.id('p3')) $$,
  '42501', 'forbidden', 'and cannot cancel them');
select pg_temp.as_user(pg_temp.u('a'), pg_temp.s('a3'));
select lives_ok($$ select public.pairing_cancel(pg_temp.id('p3')) $$, 'the new phone cancels a session');
reset role;
select is(public.approve_device_signed(pg_temp.u('a'), pg_temp.s('a7'), pg_temp.d('a3'), pg_temp.id('p2'))
    ->> 'status', 'approved',
  'a revealed comparison session lets the responding phone approve the new phone');
select is((select status from public.pairing_sessions where id = pg_temp.id('p2')), 'done', 'and is closed');
insert into public.pairing_sessions (id, user_id, new_device, commitment, expires_at)
values ('9a000000-0000-4000-8000-000000000004', pg_temp.u('a'), pg_temp.d('a5'), pg_temp.bytes('00', 32),
        now() - interval '1 second');
set local role authenticated;
select pg_temp.as_user(pg_temp.u('a'), pg_temp.s('a7'));
select throws_ok($$ select public.pairing_respond('9a000000-0000-4000-8000-000000000004', pg_temp.bytes('22', 32)) $$,
  'P0002', 'pairing_unavailable', 'an expired comparison session is dead');
reset role;

-- =====================================================================================
-- Way 3: the recovery device (B3)
-- =====================================================================================
set local role authenticated;
select pg_temp.as_user(pg_temp.u('a'), pg_temp.s('a4'));
select throws_ok($$ select public.set_account_recovery(pg_temp.bytes('5a', 16), '{"m":19456,"t":2,"p":1}',
    pg_temp.key(9), pg_temp.key(10)) $$,
  '42501', 'approved_device_required', 'an SMS-only session cannot set the recovery device');
select pg_temp.as_user(pg_temp.u('a'), pg_temp.s('a7'));
insert into vals (k, id) select 'rec', public.set_account_recovery(pg_temp.bytes('5a', 16),
  '{"m":19456,"t":2,"p":1}', pg_temp.key(9), pg_temp.key(10));
select is((select kind || '/' || status || '/' || approved_by_device from public.devices where id = pg_temp.id('rec')),
  'recovery/approved/' || pg_temp.d('a1'), 'an approved phone sets up the recovery device');
select throws_ok($$ select public.set_account_recovery(pg_temp.bytes('5a', 16), '{"m":1048576,"t":2,"p":1}',
    pg_temp.key(25), pg_temp.key(26)) $$,
  '23514', null, 'KDF settings beyond what a phone can run are refused');
select pg_temp.as_user(pg_temp.u('a'), pg_temp.s('a4'));
select is((select salt from public.account_recovery), pg_temp.bytes('5a', 16),
  'a pending phone reads the salt and KDF settings');
insert into vals (k, b) select 'n-recover', decode(public.issue_device_challenge('recover', pg_temp.d('a4')), 'base64');
select is(octet_length(pg_temp.v('n-recover')), 32, 'and gets a recovery nonce for itself');
select throws_ok($$ select public.issue_device_challenge('recover', pg_temp.d('a5')) $$,
  '42501', 'forbidden', 'but not for a phone another session registered');
select pg_temp.as_user(pg_temp.u('c'), pg_temp.s('c1'));
select is((select count(*)::int from public.account_recovery), 0, 'another user reads no recovery settings');
reset role;
select is(public.take_device_challenge(pg_temp.u('a'), pg_temp.s('a4'), 'recover', pg_temp.d('a4'),
    pg_temp.v('n-recover')) -> 'signer' ->> 'id', pg_temp.id('rec')::text,
  'recovery is checked against the recovery device''s key');
select throws_ok($$ select public.recover_device_signed(pg_temp.u('a'), pg_temp.s('a7'), pg_temp.d('a4')) $$,
  '42501', 'forbidden', 'only from the new phone''s own session');
select throws_ok($$ select public.bind_device_session(pg_temp.u('a'), pg_temp.s('a9'), pg_temp.id('rec')) $$,
  'P0002', 'unknown_device', 'the recovery device never gets a session');
select is(public.recover_device_signed(pg_temp.u('a'), pg_temp.s('a4'), pg_temp.d('a4')) ->> 'approved_by',
  pg_temp.id('rec')::text, 'the recovery device approves the new phone');
select public.bind_device_signed(pg_temp.u('a'), pg_temp.s('a4'), pg_temp.d('a4'), false);
insert into public.device_challenges (nonce, purpose, user_id, session_id, device_id)
select extensions.gen_random_bytes(32), 'recover', pg_temp.u('a'), pg_temp.s('a8'), pg_temp.d('a5')
from generate_series(1, 4);
set local role authenticated;
select pg_temp.as_user(pg_temp.u('a'), pg_temp.s('a5'));
select throws_ok($$ select public.issue_device_challenge('recover', pg_temp.d('a5')) $$,
  '54000', 'too_many_recovery_tries', 'at most 5 recovery tries per account per day');
reset role;

-- =====================================================================================
-- The family log: genesis, strict entries, compare-and-set (B5)
-- =====================================================================================
select throws_ok($$ select pg_temp.next(pg_temp.u('a'), pg_temp.s('a5'), 'genesis', pg_temp.d('a1'),
    pg_temp.genesis(jsonb_build_array(pg_temp.dev(pg_temp.d('a1')), pg_temp.dev(pg_temp.id('rec'))))) $$,
  '42501', 'approved_device_required', 'an SMS-only session cannot append');
select throws_ok($$ select pg_temp.next(pg_temp.u('a'), pg_temp.s('a7'), 'genesis', pg_temp.d('c1'),
    pg_temp.genesis(jsonb_build_array(pg_temp.dev(pg_temp.d('a1')), pg_temp.dev(pg_temp.id('rec'))))) $$,
  '42501', 'signer_not_caller', 'a session appends only entries its phone or its recovery device signed');
select throws_ok($$ select pg_temp.next(pg_temp.u('a'), pg_temp.s('a7'), 'genesis', pg_temp.d('a1'),
    pg_temp.genesis(jsonb_build_array(pg_temp.dev(pg_temp.d('a1'))))) $$,
  '22023', 'recovery_device_missing', 'genesis lists the account''s recovery device');
select throws_ok($$ select pg_temp.next(pg_temp.u('a'), pg_temp.s('a7'), 'genesis', pg_temp.d('a1'),
    pg_temp.genesis(jsonb_build_array(pg_temp.dev(pg_temp.d('a1')), pg_temp.dev(pg_temp.id('rec')),
                                      pg_temp.dev(pg_temp.d('a5'))))) $$,
  '42501', 'device_mismatch', 'a pending phone cannot be listed');
select throws_ok($$ select pg_temp.next(pg_temp.u('a'), pg_temp.s('a7'), 'genesis', pg_temp.d('a1'),
    pg_temp.genesis(jsonb_build_array(pg_temp.dev(pg_temp.d('a1')) || jsonb_build_object('kx', pg_temp.b64url(pg_temp.key(99))),
                                      pg_temp.dev(pg_temp.id('rec'))))) $$,
  '42501', 'device_mismatch', 'a device record must carry the registered keys');
select throws_ok($$ select pg_temp.raw(pg_temp.u('a'), pg_temp.s('a7'), convert_to(replace(convert_from(
    pg_temp.entry(1, null, 'genesis', pg_temp.d('a1'), pg_temp.genesis(jsonb_build_array(
      pg_temp.dev(pg_temp.d('a1')), pg_temp.dev(pg_temp.id('rec')))))::bytea, 'UTF8'),
    '"type": "genesis"', '"type": "genesis", "type": "genesis"'), 'UTF8')) $$,
  '22023', 'bad_entry', 'duplicate keys are refused, never "last key wins"');
select throws_ok($$ select pg_temp.next(pg_temp.u('a'), pg_temp.s('a7'), 'genesis', pg_temp.d('a1'),
    pg_temp.genesis(jsonb_build_array(pg_temp.dev(pg_temp.d('a1')), pg_temp.dev(pg_temp.id('rec'))))
    || '{"note":"hi"}') $$,
  '22023', 'bad_entry_fields', 'unknown top-level fields are refused');
select throws_ok($$ select pg_temp.next(pg_temp.u('a'), pg_temp.s('a7'), 'genesis', pg_temp.d('a1'),
    pg_temp.genesis(jsonb_build_array(pg_temp.dev(pg_temp.d('a1')), pg_temp.dev(pg_temp.id('rec'))))
    || '{"kc":[[[[[[[["deep"]]]]]]]]}') $$,
  '22023', 'bad_entry', 'nesting deeper than 8 levels is refused');
select throws_ok($$ select pg_temp.next(pg_temp.u('a'), pg_temp.s('a7'), 'genesis', pg_temp.d('a1'),
    pg_temp.genesis(jsonb_build_array(pg_temp.dev(pg_temp.d('a1')), pg_temp.dev(pg_temp.id('rec'))))
    || '{"key_version":1.0}') $$,
  '22023', 'bad_entry', 'numbers must be plain integers');
select throws_ok($$ select pg_temp.raw(pg_temp.u('a'), pg_temp.s('a7'), '\x7b2276223a312c2261223a22a2227d'::bytea) $$,
  '22023', 'bad_entry', 'invalid UTF-8 is refused');
select throws_ok($$ select pg_temp.next(pg_temp.u('a'), pg_temp.s('a7'), 'genesis', pg_temp.d('a1'),
    pg_temp.genesis(jsonb_build_array(pg_temp.dev(pg_temp.d('a1')), pg_temp.dev(pg_temp.id('rec'))))
    || '{"at":"2026-11-05"}') $$,
  '22023', 'bad_entry', 'the clock is 16 lowercase hex digits');
select is(pg_temp.next(pg_temp.u('a'), pg_temp.s('a7'), 'genesis', pg_temp.d('a1'),
    pg_temp.genesis(jsonb_build_array(pg_temp.dev(pg_temp.d('a1')), pg_temp.dev(pg_temp.d('a2')),
                                      pg_temp.dev(pg_temp.id('rec'))))) ->> 'ok', 'true',
  'a genesis signed by the account''s phone creates the family');
select is((select role from public.family_members where family_id = pg_temp.f() and user_id = pg_temp.u('a')), 'owner',
  'its signer''s account owns it');
select is((select count(*)::int from public.family_devices where family_id = pg_temp.f()), 3,
  'the listed devices are the family''s devices');
select is((select key_commitment from public.family_epochs where family_id = pg_temp.f() and key_version = 1),
  pg_temp.bytes('21', 32), 'and the key commitment of epoch 1 is kept');
select is(public.append_family_log_as(pg_temp.u('a'), pg_temp.s('a7'), pg_temp.f(), 1, null,
    pg_temp.entry(1, null, 'genesis', pg_temp.d('a1'), pg_temp.genesis(jsonb_build_array(
      pg_temp.dev(pg_temp.d('a1')), pg_temp.dev(pg_temp.id('rec'))))), pg_temp.bytes('00', 64)) ->> 'error',
  'head_mismatch', 'a replayed genesis is refused (compare-and-set on the head)');

-- =====================================================================================
-- Invites with a lookup hash, the invitee's devices and MAC (B9)
-- =====================================================================================
set local role authenticated;
select pg_temp.as_user(pg_temp.u('a'), pg_temp.s('a7'));
insert into vals (k, id) select 'inv', public.create_family_invite(pg_temp.f(), 'guardian',
  pg_temp.lookup(pg_temp.bytes('77', 32)));
insert into vals (k, id) select 'inv-old', public.create_family_invite(pg_temp.f(), 'viewer',
  pg_temp.lookup(pg_temp.bytes('78', 32)));
reset role;
update public.family_invites set expires_at = now() - interval '1 second' where id = pg_temp.id('inv-old');

set local role authenticated;
select pg_temp.as_user(pg_temp.u('b'), pg_temp.s('b1'));
select is(public.accept_family_invite(encode(pg_temp.bytes('77', 32), 'hex'),
    jsonb_build_array(pg_temp.dev(pg_temp.d('b1'))), pg_temp.bytes('ab', 32)) ->> 'error', 'invalid_invite',
  'the invite secret itself does not work: only its lookup hash');
select is(public.accept_family_invite(pg_temp.lookup(pg_temp.bytes('78', 32)),
    jsonb_build_array(pg_temp.dev(pg_temp.d('b1'))), pg_temp.bytes('ab', 32)) ->> 'error', 'invalid_invite',
  'an expired invite cannot be accepted');
select throws_ok($$ select public.accept_family_invite(pg_temp.lookup(pg_temp.bytes('77', 32)),
    jsonb_build_array(pg_temp.dev(pg_temp.d('c1'))), pg_temp.bytes('ab', 32)) $$,
  '22023', 'bad_device_record', 'the invitee posts only their own devices');
reset role;
select public.approve_device(pg_temp.d('b2'), pg_temp.d('b1'));
set local role authenticated;
select pg_temp.as_user(pg_temp.u('b'), pg_temp.s('b1'));
select throws_ok($$ select public.accept_family_invite(pg_temp.lookup(pg_temp.bytes('77', 32)),
    jsonb_build_array(pg_temp.dev(pg_temp.d('b2'))), pg_temp.bytes('ab', 32)) $$,
  '22023', 'session_device_missing', 'including the phone that accepts');
select is(public.accept_family_invite(pg_temp.lookup(pg_temp.bytes('77', 32)),
    jsonb_build_array(pg_temp.dev(pg_temp.d('b1'))), pg_temp.bytes('ab', 32)) ->> 'invite_id', pg_temp.id('inv')::text,
  'the invitee accepts with the lookup hash, their device records and the MAC');
select is(public.accept_family_invite(pg_temp.lookup(pg_temp.bytes('77', 32)),
    jsonb_build_array(pg_temp.dev(pg_temp.d('b1'))), pg_temp.bytes('ab', 32)) ->> 'error', 'invalid_invite',
  'an invite is accepted once');
select throws_ok($$ select * from public.pending_family_invites(pg_temp.f()) $$,
  '42501', 'forbidden', 'only the owner lists accepted invites');
select pg_temp.as_user(pg_temp.u('a'), pg_temp.s('a5'));
select throws_ok($$ select * from public.pending_family_invites(pg_temp.f()) $$,
  '42501', 'forbidden', 'and not from an SMS-only session');
select pg_temp.as_user(pg_temp.u('a'), pg_temp.s('a7'));
select is((select phone from public.pending_family_invites(pg_temp.f())), '201000000022',
  'the owner sees the invitee''s phone number before admitting them ("Is this Mona?")');
reset role;
insert into public.invite_accept_attempts (user_id) select pg_temp.u('c') from generate_series(1, 10);
set local role authenticated;
select pg_temp.as_user(pg_temp.u('c'), pg_temp.s('c1'));
select is(public.accept_family_invite(pg_temp.lookup(pg_temp.bytes('79', 32)),
    jsonb_build_array(pg_temp.dev(pg_temp.d('c1'))), pg_temp.bytes('ab', 32)) ->> 'error', 'too_many_attempts',
  'at most 10 accept tries per hour, failed ones included');
reset role;
insert into public.family_invites (family_id, role, code_hash, created_by)
select pg_temp.f(), 'viewer', encode(sha256(('bulk' || i)::bytea), 'hex'), pg_temp.u('a') from generate_series(1, 18) i;
set local role authenticated;
select pg_temp.as_user(pg_temp.u('a'), pg_temp.s('a7'));
select throws_ok($$ select public.create_family_invite(pg_temp.f(), 'viewer', pg_temp.lookup(pg_temp.bytes('7a', 32))) $$,
  '54000', 'too_many_invites', 'at most 20 invites per family per day, revoked ones included');
reset role;

-- add_member must match what the invitee posted
select throws_ok($$ select pg_temp.next(pg_temp.u('a'), pg_temp.s('a7'), 'add_member', pg_temp.d('a1'),
    jsonb_build_object('user', pg_temp.u('b'), 'role', 'guardian', 'invite', pg_temp.id('inv'),
      'mac', pg_temp.b64url(pg_temp.bytes('ac', 32)), 'devices', jsonb_build_array(pg_temp.dev(pg_temp.d('b1'))))) $$,
  '42501', 'invite_mac_mismatch', 'add_member carries the MAC the invitee posted');
select throws_ok($$ select pg_temp.next(pg_temp.u('a'), pg_temp.s('a7'), 'add_member', pg_temp.d('a1'),
    jsonb_build_object('user', pg_temp.u('b'), 'role', 'guardian', 'invite', pg_temp.id('inv'),
      'mac', pg_temp.b64url(pg_temp.bytes('ab', 32)),
      'devices', jsonb_build_array(pg_temp.dev(pg_temp.d('b1')), pg_temp.dev(pg_temp.d('b2'))))) $$,
  '42501', 'invite_devices_mismatch', 'and exactly the devices they posted');
select throws_ok($$ select pg_temp.next(pg_temp.u('a'), pg_temp.s('a7'), 'add_member', pg_temp.d('a1'),
    jsonb_build_object('user', pg_temp.u('b'), 'role', 'cared_for', 'invite', pg_temp.id('inv'),
      'mac', pg_temp.b64url(pg_temp.bytes('ab', 32)), 'devices', jsonb_build_array(pg_temp.dev(pg_temp.d('b1'))))) $$,
  '22023', 'bad_entry_fields', 'a cared-for member needs the profile they are linked to');
select is(pg_temp.next(pg_temp.u('a'), pg_temp.s('a7'), 'add_member', pg_temp.d('a1'),
    jsonb_build_object('user', pg_temp.u('b'), 'role', 'guardian', 'invite', pg_temp.id('inv'),
      'mac', pg_temp.b64url(pg_temp.bytes('ab', 32)), 'devices', jsonb_build_array(pg_temp.dev(pg_temp.d('b1')))))
    ->> 'ok', 'true',
  'the owner''s add_member admits the invitee');
select is((select array_agg(device_id) from public.family_devices
           where family_id = pg_temp.f() and user_id = pg_temp.u('b')), array[pg_temp.d('b1')],
  'with their devices as devices of the family');

-- =====================================================================================
-- Key wraps (B6)
-- =====================================================================================
set local role authenticated;
select pg_temp.as_user(pg_temp.u('b'), pg_temp.s('b1'));
select is(public.put_family_key_wraps(pg_temp.f(), 1, pg_temp.wraps(array[pg_temp.d('b1')])) ->> 'ok', 'true',
  'a current device of the family stores a wrap for a device of the family');
select is(public.put_family_key_wraps(pg_temp.f(), 1, pg_temp.wraps(array[pg_temp.d('b1')])) -> 'results' -> 0 ->> 'stored',
  'false', 'an existing wrap is kept, not overwritten');
select is(public.put_family_key_wraps(pg_temp.f(), 2, pg_temp.wraps(array[pg_temp.d('b1')])) ->> 'error', 'stale_key',
  'only the current key version is wrapped');
select throws_ok($$ select public.put_family_key_wraps(pg_temp.f(), 1, pg_temp.wraps(array[pg_temp.d('c1')])) $$,
  '42501', 'recipient_not_in_family', 'never to a device outside the family');
select pg_temp.as_user(pg_temp.u('a'), pg_temp.s('a7'));
select lives_ok($$ select public.put_family_key_wraps(pg_temp.f(), 1,
    pg_temp.wraps(array[pg_temp.d('a1'), pg_temp.d('a2'), pg_temp.id('rec')])) $$,
  'the owner''s phone wraps the key to its devices');
select is((select count(*)::int from public.family_key_wraps), 2,
  'a phone reads its own wrap and its recovery device''s, nobody else''s');
select pg_temp.as_user(pg_temp.u('b'), pg_temp.s('b1'));
select is((select count(*)::int from public.family_key_wraps), 1, 'the member reads only their own');
delete from public.family_key_wraps;
select pg_temp.as_user(pg_temp.u('a'), pg_temp.s('a7'));
select is((select count(*)::int from public.family_key_wraps), 2, 'deleting reaches only the phone''s own wrap');
select pg_temp.as_user(pg_temp.u('b'), pg_temp.s('b1'));
select is((select count(*)::int from public.family_key_wraps), 0,
  'a phone deletes its own wrap (one it cannot open), so a good one can be stored');
select is(public.put_family_key_wraps(pg_temp.f(), 1, pg_temp.wraps(array[pg_temp.d('b1')])) -> 'results' -> 0 ->> 'stored',
  'true', 'and the key is wrapped to it again');
select pg_temp.as_user(pg_temp.u('c'), pg_temp.s('c1'));
select throws_ok($$ select public.put_family_key_wraps(pg_temp.f(), 1, pg_temp.wraps(array[pg_temp.d('c1')])) $$,
  '42501', 'forbidden', 'a non-member cannot write wraps');
select is((select count(*)::int from public.family_key_wraps) + (select count(*)::int from public.family_epochs), 0,
  'and reads no wraps or epochs');
select pg_temp.as_user(pg_temp.u('a'), pg_temp.s('a5'));
select throws_ok($$ select public.put_family_key_wraps(pg_temp.f(), 1, pg_temp.wraps(array[pg_temp.d('a1')])) $$,
  '42501', 'approved_device_required', 'an SMS-only session cannot write wraps');
select is((select count(*)::int from public.family_key_wraps), 0, 'or read them');
reset role;

-- =====================================================================================
-- Way 3 in the log: the recovered phone adds itself, signed by the recovery device
-- =====================================================================================
select throws_ok($$ select pg_temp.next(pg_temp.u('a'), pg_temp.s('a4'), 'add_device', pg_temp.d('a4'),
    jsonb_build_object('user', pg_temp.u('a'), 'device', pg_temp.dev(pg_temp.d('a4')))) $$,
  '42501', 'signer_not_in_family', 'a phone the log has not added cannot sign for the family');
select is(pg_temp.next(pg_temp.u('a'), pg_temp.s('a4'), 'add_device', pg_temp.id('rec'),
    jsonb_build_object('user', pg_temp.u('a'), 'device', pg_temp.dev(pg_temp.d('a4')))) ->> 'ok', 'true',
  'a recovered phone appends add_device for itself, signed by the recovery device');
set local role authenticated;
select pg_temp.as_user(pg_temp.u('a'), pg_temp.s('a4'));
select is((select count(*)::int from public.family_key_wraps where recipient_device_id = pg_temp.id('rec')), 1,
  'then reads the recovery device''s wrap, to re-wrap the key to itself');
reset role;
select throws_ok($$ select pg_temp.next(pg_temp.u('b'), pg_temp.s('b1'), 'add_device', pg_temp.d('b1'),
    jsonb_build_object('user', pg_temp.u('a'), 'device', pg_temp.dev(pg_temp.d('a3')))) $$,
  '42501', 'forbidden', 'nobody adds devices of another account');
select throws_ok($$ select pg_temp.next(pg_temp.u('a'), pg_temp.s('a7'), 'add_device', pg_temp.d('a1'),
    jsonb_build_object('user', pg_temp.u('a'), 'device', pg_temp.dev(pg_temp.d('a5')))) $$,
  '42501', 'device_mismatch', 'a pending phone cannot be added');
select throws_ok($$ select pg_temp.next(pg_temp.u('a'), pg_temp.s('a7'), 'add_device', pg_temp.d('a1'),
    jsonb_build_object('user', pg_temp.u('a'), 'device', pg_temp.dev(pg_temp.d('a2')))) $$,
  '23505', 'already_in_family', 'a device is added once');

-- =====================================================================================
-- Records need a current device of the family
-- =====================================================================================
set local role authenticated;
select pg_temp.as_user(pg_temp.u('a'), pg_temp.s('a7'));
select is(public.push_e2ee_records(pg_temp.f(), pg_temp.head_seq(), pg_temp.rec('e0000000-0000-4000-8000-000000000001', 1, 0))
    -> 'results' -> 0 ->> 'ok', 'true', 'a current device of the family pushes records');
reset role;
select public.bind_device_signed(pg_temp.u('a'), pg_temp.s('a3'), pg_temp.d('a3'), false);
set local role authenticated;
select pg_temp.as_user(pg_temp.u('a'), pg_temp.s('a3'));
select throws_ok($$ select public.push_e2ee_records(pg_temp.f(), pg_temp.head_seq(),
    pg_temp.rec('e0000000-0000-4000-8000-000000000002', 1, 0)) $$,
  '42501', 'device_not_in_family', 'an approved phone the log has not added cannot push');
select is((select count(*)::int from public.e2ee_records), 0, 'nor read records');
select is((select count(*)::int from public.family_log), pg_temp.head_seq(),
  'but reads the log, to check it before it is added');
select pg_temp.as_user(pg_temp.u('a'), pg_temp.s('a4'));
select is((select count(*)::int from public.e2ee_records), 1, 'the recovered phone, once added, reads records');
reset role;

-- =====================================================================================
-- Rotation: history blob, every wrap, recipient hash, in one transaction (B6)
-- =====================================================================================
select throws_ok($$ select pg_temp.rotate(pg_temp.u('a'), pg_temp.s('a7'), pg_temp.d('a1'), 2,
    p_devices => array(select x from unnest(pg_temp.current_devices()) x where x <> pg_temp.d('b1'))) $$,
  '22023', 'recipients_mismatch', 'a rotation wraps the new key to every current device');
select throws_ok($$ select pg_temp.rotate(pg_temp.u('a'), pg_temp.s('a7'), pg_temp.d('a1'), 2,
    p_recipients => pg_temp.bytes('00', 32)) $$,
  '22023', 'recipients_mismatch', 'and its entry commits to that recipient set');
select throws_ok($$ select pg_temp.rotate(pg_temp.u('a'), pg_temp.s('a7'), pg_temp.d('a1'), 2,
    p_history_hash => pg_temp.bytes('00', 32)) $$,
  '22023', 'history_mismatch', 'and to the history blob it ships');
select throws_ok($$ select pg_temp.rotate(pg_temp.u('a'), pg_temp.s('a7'), pg_temp.d('a1'), 3) $$,
  '22023', 'bad_key_version', 'a rotation goes to the next key version');
select throws_ok($$ select pg_temp.next(pg_temp.u('a'), pg_temp.s('a7'), 'rotate_key', pg_temp.d('a1'),
    jsonb_build_object('key_version', 2, 'kc', pg_temp.b64url(pg_temp.bytes('22', 32)),
      'history', pg_temp.b64url(pg_temp.bytes('00', 32)), 'recipients', pg_temp.b64url(pg_temp.bytes('00', 32)))) $$,
  '22023', 'bad_rotation', 'a rotation without its history and wraps is refused');
select is(pg_temp.rotate(pg_temp.u('b'), pg_temp.s('b1'), pg_temp.d('b1'), 2) ->> 'ok', 'true',
  'any member''s current device rotates the key');
select is((select current_key_version from public.families where id = pg_temp.f()), 2, 'the epoch moves on');
select is((select octet_length(history) from public.family_epochs where family_id = pg_temp.f() and key_version = 2), 72,
  'the history blob is kept with the epoch');
select is((select count(*)::int from public.family_key_wraps where family_id = pg_temp.f() and key_version = 2),
  cardinality(pg_temp.current_devices()), 'every current device has a wrap of the new key');
select is((select count(*)::int from public.family_key_wraps where family_id = pg_temp.f() and key_version = 1), 0,
  'and older wraps are dropped (old keys come from the history chain)');

-- =====================================================================================
-- Revoking devices through the log
-- =====================================================================================
select throws_ok($$ select pg_temp.next(pg_temp.u('b'), pg_temp.s('b1'), 'revoke_device', pg_temp.d('b1'),
    jsonb_build_object('user', pg_temp.u('a'), 'device', pg_temp.d('a2'))) $$,
  '42501', 'forbidden', 'a member cannot revoke another member''s device');
select is(pg_temp.next(pg_temp.u('a'), pg_temp.s('a7'), 'revoke_device', pg_temp.d('a1'),
    jsonb_build_object('user', pg_temp.u('b'), 'device', pg_temp.d('b1'))) ->> 'ok', 'true',
  'the owner removes another member''s device from the family');
select is((select status from public.devices where id = pg_temp.d('b1')), 'approved',
  'it stays approved for its own account');
select ok((select rotation_pending from public.families where id = pg_temp.f()), 'and a rotation is pending');
set local role authenticated;
select pg_temp.as_user(pg_temp.u('b'), pg_temp.s('b1'));
select is((select count(*)::int from public.e2ee_records) + (select count(*)::int from public.family_key_wraps), 0,
  'the removed device reads no records and its wraps are gone');
select throws_ok($$ select public.push_e2ee_records(pg_temp.f(), pg_temp.head_seq(),
    pg_temp.rec('e0000000-0000-4000-8000-000000000003', 2, 0)) $$,
  '42501', 'device_not_in_family', 'and cannot push');
reset role;
select throws_ok($$ select pg_temp.rotate(pg_temp.u('b'), pg_temp.s('b1'), pg_temp.d('b1'), 3) $$,
  '42501', 'signer_not_in_family', 'nor sign log entries for the family');
select is(pg_temp.rotate(pg_temp.u('a'), pg_temp.s('a7'), pg_temp.d('a1'), 3) ->> 'ok', 'true',
  'the remaining devices rotate the key');
select is(pg_temp.next(pg_temp.u('a'), pg_temp.s('a7'), 'revoke_device', pg_temp.d('a1'),
    jsonb_build_object('user', pg_temp.u('a'), 'device', pg_temp.d('a2'))) ->> 'ok', 'true',
  'a person revokes one of their own phones');
select is((select status from public.devices where id = pg_temp.d('a2')), 'revoked',
  'which is final, for every family');
set local role authenticated;
select pg_temp.as_user(pg_temp.u('a'), pg_temp.s('a2'));
select ok(not private.device_ok(), 'and ends its session''s access');
reset role;

-- =====================================================================================
-- Head beacons (section 7)
-- =====================================================================================
select is(public.publish_family_head(pg_temp.u('a'), pg_temp.s('a7'), pg_temp.f(),
    pg_temp.beacon(pg_temp.d('a1'), pg_temp.head_seq(), pg_temp.head()), pg_temp.bytes('00', 64)) ->> 'ok', 'true',
  'a current device publishes its head beacon');
select is(public.publish_family_head(pg_temp.u('a'), pg_temp.s('a7'), pg_temp.f(),
    pg_temp.beacon(pg_temp.d('a1'), 1, (select hash from public.family_log where family_id = pg_temp.f() and seq = 1)),
    pg_temp.bytes('00', 64)) ->> 'error', 'stale_beacon',
  'an older beacon never replaces a newer one');
select is(public.publish_family_head(pg_temp.u('a'), pg_temp.s('a7'), pg_temp.f(),
    pg_temp.beacon(pg_temp.d('a1'), pg_temp.head_seq(), pg_temp.bytes('ee', 32)), pg_temp.bytes('00', 64)) ->> 'error',
  'not_on_log', 'a beacon must name a head on the log');
select throws_ok($$ select public.publish_family_head(pg_temp.u('a'), pg_temp.s('a7'), pg_temp.f(),
    pg_temp.beacon(pg_temp.d('a4'), pg_temp.head_seq(), pg_temp.head()), pg_temp.bytes('00', 64)) $$,
  '22023', 'bad_beacon', 'a phone publishes only its own beacon');
select throws_ok($$ select public.publish_family_head(pg_temp.u('a'), pg_temp.s('a5'), pg_temp.f(),
    pg_temp.beacon(pg_temp.d('a5'), pg_temp.head_seq(), pg_temp.head()), pg_temp.bytes('00', 64)) $$,
  '42501', 'approved_device_required', 'an SMS-only session publishes none');
select throws_ok($$ select public.publish_family_head(pg_temp.u('b'), pg_temp.s('b1'), pg_temp.f(),
    pg_temp.beacon(pg_temp.d('b1'), pg_temp.head_seq(), pg_temp.head()), pg_temp.bytes('00', 64)) $$,
  '42501', 'forbidden', 'nor does a device removed from the family');
set local role authenticated;
select pg_temp.as_user(pg_temp.u('a'), pg_temp.s('a4'));
select is((select count(*)::int from public.family_heads), 1, 'the family''s devices read the beacons');
select pg_temp.as_user(pg_temp.u('b'), pg_temp.s('b1'));
select is((select count(*)::int from public.family_heads), 0, 'a removed device does not');
reset role;

-- =====================================================================================
-- Account reset: 7 days, cancellable from an older phone (B3)
-- =====================================================================================
set local role authenticated;
select pg_temp.as_user(pg_temp.u('d'), pg_temp.s('d1'));
select throws_ok($$ select public.start_account_reset(pg_temp.d('d1')) $$,
  '22023', 'not_enrolled', 'an account that never enrolled has nothing to reset');
select pg_temp.as_user(pg_temp.u('b'), pg_temp.s('b9'));
insert into vals (k, id) select 'reset1', public.start_account_reset(pg_temp.d('b9'));
select ok(pg_temp.id('reset1') is not null, 'an SMS-only session starts a reset of an enrolled account');
select is(public.start_account_reset(pg_temp.d('b9')), pg_temp.id('reset1'), 'starting again returns the open reset');
select is((select count(*)::int from public.account_resets), 1, 'every session of the account sees it (checked on launch)');
select throws_ok($$ select public.cancel_account_reset(pg_temp.id('reset1')) $$,
  '42501', 'approved_device_required', 'an SMS-only session cannot cancel it');
select pg_temp.as_user(pg_temp.u('b'), pg_temp.s('b1'));
select throws_ok($$ select public.cancel_account_reset(pg_temp.id('reset1')) $$,
  '42501', 'cannot_cancel', 'nor can a phone approved less than 7 days before the reset began');
reset role;
update public.devices set approved_at = now() - interval '8 days' where id = pg_temp.d('b1');
set local role authenticated;
select pg_temp.as_user(pg_temp.u('b'), pg_temp.s('b1'));
select lives_ok($$ select public.cancel_account_reset(pg_temp.id('reset1')) $$,
  '"This isn''t me": a phone approved 7+ days earlier cancels it');
select pg_temp.as_user(pg_temp.u('b'), pg_temp.s('b9'));
insert into vals (k, id) select 'reset2', public.start_account_reset(pg_temp.d('b9'));
reset role;
select is(public.complete_account_resets(), 0, 'a reset completes only after 7 days');
update public.account_resets set completes_at = now() - interval '1 minute' where id = pg_temp.id('reset2');
select is(public.complete_account_resets(), 1, 'then it completes');
select is((select string_agg(distinct status, ',') from public.devices
           where user_id = pg_temp.u('b') and id <> pg_temp.d('b9')), 'revoked',
  'every other device of the account is revoked');
select is((select status from public.devices where id = pg_temp.d('b9')), 'pending', 'the phone that started it stays');
select is((select status from public.family_members where family_id = pg_temp.f() and user_id = pg_temp.u('b')), 'reset',
  'memberships are marked reset');
select is(public.bind_device_signed(pg_temp.u('b'), pg_temp.s('b9'), pg_temp.d('b9'), true) ->> 'status', 'approved',
  'the new phone enrols as the account''s first device again');
set local role authenticated;
select pg_temp.as_user(pg_temp.u('b'), pg_temp.s('b9'));
select is((select count(*)::int from public.families) + (select count(*)::int from public.family_log), 0,
  'a reset member reads nothing of the family');
reset role;
select throws_ok($$ select pg_temp.next(pg_temp.u('b'), pg_temp.s('b9'), 'remove_member', pg_temp.d('b9'),
    jsonb_build_object('user', pg_temp.u('a'), 'reason', 'reset')) $$,
  '42501', 'signer_not_member', 'a reset member signs nothing for the family');
select is(pg_temp.next(pg_temp.u('a'), pg_temp.s('a7'), 'remove_member', pg_temp.d('a1'),
    jsonb_build_object('user', pg_temp.u('b'), 'reason', 'reset')) ->> 'ok', 'true',
  'a member records the removal once a person confirmed the reset');
select is((select count(*)::int from public.family_members where family_id = pg_temp.f() and user_id = pg_temp.u('b')), 0,
  'and the membership is gone');

-- =====================================================================================
-- A new recovery key, and housekeeping
-- =====================================================================================
select is(pg_temp.rotate(pg_temp.u('a'), pg_temp.s('a7'), pg_temp.d('a1'), 4) ->> 'ok', 'true', '(rotation after the removal)');
set local role authenticated;
select pg_temp.as_user(pg_temp.u('a'), pg_temp.s('a7'));
insert into vals (k, id) select 'rec2', public.set_account_recovery(pg_temp.bytes('5b', 16),
  '{"m":19456,"t":2,"p":1}', pg_temp.key(17), pg_temp.key(18));
reset role;
select is((select status from public.devices where id = pg_temp.id('rec')), 'revoked',
  'a new recovery key revokes the old recovery device');
select ok((select rotation_pending from public.families where id = pg_temp.f()), 'and makes a rotation pending');
select is((select recovery_device_id from public.account_recovery where user_id = pg_temp.u('a')), pg_temp.id('rec2'),
  'the new recovery device is the one recovery is checked against');

insert into public.devices (id, user_id, platform, public_key, signing_public_key, created_at) values
  (pg_temp.d('a6'), pg_temp.u('a'), 'ios', pg_temp.key(27), pg_temp.key(28), now() - interval '8 days');
insert into public.device_challenges (nonce, purpose, user_id, session_id, device_id, created_at)
values (pg_temp.bytes('99', 32), 'bind', pg_temp.u('a'), pg_temp.s('a9'), pg_temp.d('a1'), now() - interval '3 days');
select lives_ok($$ select public.sync_housekeeping() $$, 'housekeeping runs');
select is((select count(*)::int from public.devices where id = pg_temp.d('a6')), 0,
  'a pending phone nobody approved within a week is removed');
select is((select count(*)::int from public.device_challenges where nonce = pg_temp.bytes('99', 32)), 0,
  'and old nonces are purged');

select * from finish();
rollback;
