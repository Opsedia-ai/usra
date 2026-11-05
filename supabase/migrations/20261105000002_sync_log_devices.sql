-- Usra: sync backend, signed family log, invites, key wraps (B5, B6, B9) and
-- device approval, session binding, recovery and account reset (B1–B4) from
-- docs/sync-design.md, sections 7–10 and 20.
--
-- Builds on 20261105000001_sync_blockers_b0.sql. Nothing is deployed yet.
--
-- * Every function that trusts an Ed25519 signature stays service-role only.
--   Its Edge Function (bind-device, approve-device, recover-device,
--   append-family-log, publish-head) checks the signature strictly and passes
--   the caller's user id and Auth session id, which these functions check
--   against device_sessions themselves.
-- * Server nonces for signatures are single-use, bound to the user, the Auth
--   session, the purpose and the device, and live 5 minutes.
-- * Access to a family's records, wraps, key history and head beacons needs a
--   session bound to an approved device that the family log lists as a current
--   device of an active member (family_devices). An SMS-only session, a pending
--   or revoked device, or a device the owner removed from the family get nothing.
-- * The log is parsed strictly here too (UTF-8, no duplicate keys, depth <= 8,
--   no unknown top-level keys per entry type) and mirrored into family_members,
--   family_devices, family_epochs (key commitments, history blobs) and wraps.
--   These are honest-server checks; the phones' checks are the real ones.

-- ---------------------------------------------------------------------------
-- 0. Helpers
-- ---------------------------------------------------------------------------

-- Unpadded base64url to bytes; null unless the input is canonical.
create or replace function private.unb64url(p text)
returns bytea
language plpgsql
immutable
set search_path = ''
as $$
declare
  v bytea;
begin
  if p is null or p !~ '^[A-Za-z0-9_-]*$' or length(p) % 4 = 1 then
    return null;
  end if;
  v := decode(translate(p, '-_', '+/') || repeat('=', (4 - length(p) % 4) % 4), 'base64');
  if private.b64url(v) <> p then
    return null;  -- non-zero padding bits: not the canonical encoding
  end if;
  return v;
exception when others then
  return null;
end;
$$;

create or replace function private.uuid_bytes(p uuid)
returns bytea
language sql
immutable
set search_path = ''
as $$ select decode(replace(p::text, '-', ''), 'hex'); $$;

create or replace function private.is_uuid(p text)
returns boolean
language sql
immutable
set search_path = ''
as $$ select coalesce(p ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', false); $$;

-- A JSON string member, or null if missing or not a string.
create or replace function private.jstr(p jsonb, k text)
returns text
language sql
immutable
set search_path = ''
as $$ select case when jsonb_typeof(p -> k) = 'string' then p ->> k end; $$;

-- A JSON integer member, or null if missing or not an integer.
create or replace function private.jint(p jsonb, k text)
returns bigint
language sql
immutable
set search_path = ''
as $$
  select case when jsonb_typeof(p -> k) = 'number' and (p ->> k) ~ '^-?[0-9]{1,15}$'
              then (p ->> k)::bigint end;
$$;

-- Keys of a JSON object, sorted bytewise.
create or replace function private.jkeys(p jsonb)
returns text[]
language sql
immutable
set search_path = ''
as $$
  select coalesce(array_agg(k collate "C" order by k collate "C"), '{}')
  from jsonb_object_keys(case when jsonb_typeof(p) = 'object' then p else '{}'::jsonb end) k;
$$;

-- No duplicate object keys, at most 8 levels of nesting, integers only. Uses `json`,
-- which keeps duplicates that `jsonb` would silently drop ("last key wins").
create or replace function private.json_strict_shape(p json, p_depth integer)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  v json;
begin
  case json_typeof(p)
  when 'object' then
    if p_depth > 8 or (select count(*) <> count(distinct k) from json_object_keys(p) k) then
      return false;
    end if;
    for v in select value from json_each(p) loop
      if not private.json_strict_shape(v, p_depth + 1) then return false; end if;
    end loop;
  when 'array' then
    if p_depth > 8 then return false; end if;
    for v in select value from json_array_elements(p) loop
      if not private.json_strict_shape(v, p_depth + 1) then return false; end if;
    end loop;
  when 'number' then
    -- Plain safe integers only (no fraction or exponent), as on the phones.
    if p::text !~ '^-?(0|[1-9][0-9]{0,15})$' or abs(p::text::numeric) > 9007199254740991 then
      return false;
    end if;
  else
    null;
  end case;
  return true;
end;
$$;

-- Strict parse of signed JSON bytes (section 5): valid UTF-8, a JSON object,
-- no duplicate keys, depth <= 8, at most p_max bytes. Null if any rule fails.
create or replace function private.strict_json(p bytea, p_max integer)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_text text;
  v jsonb;
begin
  if p is null or octet_length(p) > p_max then
    return null;
  end if;
  v_text := convert_from(p, 'UTF8');
  if not private.json_strict_shape(v_text::json, 1) then
    return null;
  end if;
  v := v_text::jsonb;
  if jsonb_typeof(v) <> 'object' then
    return null;
  end if;
  return v;
exception when others then
  return null;
end;
$$;

-- ---------------------------------------------------------------------------
-- 1. devices: phones and recovery devices; sessions bound by key proof
-- ---------------------------------------------------------------------------
alter table public.devices
  add column kind text not null default 'phone'
    constraint devices_kind_check check (kind in ('phone', 'recovery'));
alter table public.devices alter column platform drop not null;
alter table public.devices
  add constraint devices_platform_kind check ((kind = 'phone') = (platform is not null));
comment on column public.devices.kind is
  'phone: an app install. recovery: the key pair derived from the recovery key; never has a session.';
alter table public.devices add column first_bound_at timestamptz;
comment on column public.devices.first_bound_at is
  'When a session was first bound to this phone. Before that, the session that registered it may act for it.';

-- B0's guard, plus: kind is part of the identity.
create or replace function private.devices_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.status := 'pending';
    new.approved_at := null;
    new.approved_by_device := null;
    new.revoked_at := null;
    return new;
  end if;

  if new.id <> old.id or new.user_id <> old.user_id
     or new.platform is distinct from old.platform or new.kind <> old.kind
     or new.created_at <> old.created_at
     or new.created_session_id is distinct from old.created_session_id then
    raise exception 'device_identity_immutable' using errcode = '42501';
  end if;
  if new.public_key is distinct from old.public_key
     or new.signing_public_key is distinct from old.signing_public_key then
    raise exception 'device_keys_immutable' using errcode = '42501';
  end if;
  if (new.status, new.approved_at, new.approved_by_device, new.revoked_at)
     is distinct from (old.status, old.approved_at, old.approved_by_device, old.revoked_at) then
    if current_user in ('anon', 'authenticated', 'service_role') then
      raise exception 'device_trust_only_through_functions' using errcode = '42501';
    end if;
    if old.status = 'revoked' then
      raise exception 'device_revoked' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

-- The phone a given (user, Auth session) is bound to and that isn't revoked.
-- The service-role functions below get user and session from their Edge
-- Function instead of a JWT.
create or replace function private.bound_device(p_user uuid, p_session uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select s.device_id
  from public.device_sessions s
  join public.devices d on d.id = s.device_id
  where s.session_id = p_session and s.user_id = p_user
    and d.user_id = p_user and d.status <> 'revoked' and d.kind = 'phone';
$$;

-- Is p_device "this session's own device"? A bound session: only the phone it
-- is bound to. A session not bound (yet): only a pending phone it registered
-- that was never bound to any session. A session that lost its binding (its
-- phone was revoked, or re-bound to a newer session) gets nothing back, not
-- even rows it once created.
create or replace function private.session_may_act_for(p_user uuid, p_session uuid, p_device uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when p_user is null or p_session is null then false
    when exists (select 1 from public.device_sessions s where s.session_id = p_session)
      then coalesce(p_device = private.bound_device(p_user, p_session), false)
    else exists (select 1 from public.devices d
                 where d.id = p_device and d.user_id = p_user
                   and d.created_session_id = p_session
                   and d.status = 'pending' and d.kind = 'phone' and d.first_bound_at is null)
  end;
$$;

-- B0's helper, now the same rule as above for the JWT's user and session.
create or replace function private.is_session_device(p_device uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$ select private.session_may_act_for(auth.uid(), private.jwt_session_id(), p_device); $$;

-- Ends Auth sessions on the server (their refresh tokens go with them), so a
-- session that lost its phone can't be refreshed. An access token already
-- issued lives until it expires, with no device rights.
create or replace function private.end_auth_sessions(p_sessions uuid[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if coalesce(cardinality(p_sessions), 0) = 0 then
    return;
  end if;
  delete from auth.refresh_tokens where session_id = any (p_sessions);
  delete from auth.sessions where id = any (p_sessions);
end;
$$;

-- An approved phone bound to this session, or null.
create or replace function private.approved_bound_device(p_user uuid, p_session uuid)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select d.id from public.devices d
  where d.id = private.bound_device(p_user, p_session) and d.status = 'approved';
$$;

-- B0's binding, plus: recovery devices never get a session, and binding a new
-- session to a device unbinds its older ones (a re-registration after a lost
-- session replaces the lost one).
create or replace function public.bind_device_session(p_user uuid, p_session uuid, p_device uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bound uuid;
  v_old uuid[];
begin
  perform 1 from public.devices
  where id = p_device and user_id = p_user and status <> 'revoked' and kind = 'phone'
  for update;
  if not found then
    raise exception 'unknown_device' using errcode = 'P0002';
  end if;

  insert into public.device_sessions (session_id, device_id, user_id)
  values (p_session, p_device, p_user)
  on conflict (session_id) do nothing;

  select device_id into v_bound from public.device_sessions where session_id = p_session;
  if v_bound is distinct from p_device then
    raise exception 'session_already_bound' using errcode = '42501';
  end if;
  with gone as (
    delete from public.device_sessions where device_id = p_device and session_id <> p_session
    returning session_id)
  select array_agg(session_id) into v_old from gone;
  perform private.end_auth_sessions(v_old);
  update public.devices set first_bound_at = coalesce(first_bound_at, now()) where id = p_device;
end;
$$;

-- B0's approval, plus: only phones are approved this way (recovery devices are
-- created approved by set_account_recovery).
create or replace function public.approve_device(p_device uuid, p_approved_by uuid default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_device public.devices%rowtype;
  v_enrolled timestamptz;
begin
  select * into v_device from public.devices where id = p_device for update;
  if not found then
    raise exception 'unknown_device' using errcode = 'P0002';
  end if;
  if v_device.status <> 'pending' or v_device.kind <> 'phone' then
    raise exception 'device_not_pending' using errcode = '42501';
  end if;
  if v_device.public_key is null or v_device.signing_public_key is null then
    raise exception 'device_keys_missing' using errcode = '22023';
  end if;

  select sync_enrolled_at into v_enrolled
  from public.accounts where id = v_device.user_id for update;

  if p_approved_by is null then
    if v_enrolled is not null then
      raise exception 'account_already_enrolled' using errcode = '42501';
    end if;
    -- After a completed reset, the phone that started it is the one that
    -- enrols first (a SIM-swapper's later phone can't take its place).
    if exists (select 1 from public.account_resets r
               where r.user_id = v_device.user_id and r.completed_at is not null
                 and r.started_device is not null and r.started_device <> p_device
                 and r.completed_at = (select max(completed_at) from public.account_resets
                                       where user_id = v_device.user_id)) then
      raise exception 'reset_device_only' using errcode = '42501';
    end if;
    update public.accounts set sync_enrolled_at = now() where id = v_device.user_id;
  else
    perform 1 from public.devices a
    where a.id = p_approved_by and a.id <> p_device
      and a.user_id = v_device.user_id and a.status = 'approved';
    if not found then
      raise exception 'approver_not_approved' using errcode = '42501';
    end if;
  end if;

  update public.devices
     set status = 'approved', approved_at = now(), approved_by_device = p_approved_by
   where id = p_device;
end;
$$;

-- Approved, revoked and recovery devices are never deleted (B10): they are
-- revoked, which flags key rotations and keeps the trail. Pending phones may be
-- deleted, and every device goes when its account is deleted.
create or replace function private.devices_no_delete()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.status <> 'pending' and exists (select 1 from public.accounts a where a.id = old.user_id) then
    raise exception 'revoke_instead' using errcode = '42501';
  end if;
  return old;
end;
$$;

create trigger devices_no_delete before delete on public.devices
  for each row execute function private.devices_no_delete();

-- ---------------------------------------------------------------------------
-- 2. Single-use server nonces for device signatures (B2, B3)
-- ---------------------------------------------------------------------------
create table public.device_challenges (
  nonce       bytea primary key check (octet_length(nonce) = 32),
  purpose     text not null check (purpose in ('bind', 'approve', 'recover')),
  user_id     uuid not null references public.accounts (id) on delete cascade,
  session_id  uuid not null,
  device_id   uuid not null references public.devices (id) on delete cascade,
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null default now() + interval '5 minutes',
  used_at     timestamptz
);

create index device_challenges_user_idx on public.device_challenges (user_id, purpose, created_at);
create index device_challenges_session_idx on public.device_challenges (session_id, created_at);
create index device_challenges_device_idx on public.device_challenges (device_id);

alter table public.device_challenges enable row level security;
-- No policies and no grants: read only through the functions below.

-- ---------------------------------------------------------------------------
-- 3. Recovery device (B3, way 3)
-- ---------------------------------------------------------------------------
create table public.account_recovery (
  user_id             uuid primary key references public.accounts (id) on delete cascade,
  recovery_device_id  uuid not null unique references public.devices (id) on delete cascade,
  salt                bytea not null check (octet_length(salt) = 16),
  -- Argon2id settings, bounded like the app's BackupKdf.isReasonable, so a
  -- hostile value can't run a 2 GB phone out of memory.
  kdf                 jsonb not null check (
    jsonb_typeof(kdf) = 'object' and private.jkeys(kdf) = array['m', 'p', 't']
    and private.jint(kdf, 'm') between 8192 and 262144          -- KiB
    and private.jint(kdf, 't') between 1 and 10
    and private.jint(kdf, 'p') between 1 and 8),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

comment on table public.account_recovery is
  'Salt, KDF settings and the recovery device of an account. The recovery key itself never leaves the phone.';

alter table public.account_recovery enable row level security;
-- Readable by the account's own sessions, SMS-only included: a new phone needs
-- the salt to derive the recovery device. Recovery tries are counted when the
-- challenge is issued.
create policy account_recovery_select_own on public.account_recovery
  for select to authenticated using (user_id = (select auth.uid()));
grant select on public.account_recovery to authenticated;

-- An approved phone sets (or replaces) the recovery device: a new devices row
-- of kind 'recovery', approved by the calling phone. The old recovery device is
-- revoked, which flags a key rotation in every family of the user; the phone
-- then appends revoke_device / add_device and rotates (section 6).
create or replace function public.set_account_recovery(
  p_salt bytea, p_kdf jsonb, p_kx bytea, p_sig bytea
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_old uuid;
  v_new uuid;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  if not private.device_ok() then
    raise exception 'approved_device_required' using errcode = '42501';
  end if;
  perform 1 from public.accounts where id = v_user for update;
  if (select count(*) from public.devices
      where user_id = v_user and kind = 'recovery' and created_at > now() - interval '1 day') >= 3 then
    raise exception 'too_many_recovery_changes' using errcode = '54000';
  end if;

  select recovery_device_id into v_old from public.account_recovery where user_id = v_user;

  if p_kx is null or p_sig is null then
    raise exception 'device_keys_missing' using errcode = '22023';
  end if;
  -- No created_session_id: no session ever acts for the recovery device.
  insert into public.devices (user_id, kind, platform, public_key, signing_public_key, created_session_id)
  values (v_user, 'recovery', null, p_kx, p_sig, null)
  returning id into v_new;
  update public.devices
     set status = 'approved', approved_at = now(), approved_by_device = private.session_device()
   where id = v_new;

  insert into public.account_recovery (user_id, recovery_device_id, salt, kdf)
  values (v_user, v_new, p_salt, p_kdf)
  on conflict (user_id) do update
    set recovery_device_id = excluded.recovery_device_id, salt = excluded.salt,
        kdf = excluded.kdf, updated_at = now();

  if v_old is not null then
    perform public.revoke_device(v_old);
  end if;
  return v_new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Comparison-code pairing relay (B4, way 2): commit, respond, reveal
-- ---------------------------------------------------------------------------
create table public.pairing_sessions (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references public.accounts (id) on delete cascade,
  new_device       uuid not null references public.devices (id) on delete cascade,
  commitment       bytea not null check (octet_length(commitment) = 32),  -- SHA-256(n_N || dkx_N || dsig_N)
  responder_device uuid references public.devices (id) on delete cascade,
  responder_nonce  bytea check (responder_nonce is null or octet_length(responder_nonce) = 32),
  new_nonce        bytea check (new_nonce is null or octet_length(new_nonce) = 32),
  status           text not null default 'committed'
    check (status in ('committed', 'responded', 'revealed', 'done', 'failed', 'cancelled')),
  created_at       timestamptz not null default now(),
  expires_at       timestamptz not null default now() + interval '10 minutes'
);

create index pairing_sessions_user_idx on public.pairing_sessions (user_id, created_at);
create index pairing_sessions_device_idx on public.pairing_sessions (new_device);
create index pairing_sessions_responder_idx on public.pairing_sessions (responder_device);

alter table public.pairing_sessions enable row level security;
-- The new phone's own session, and the account's approved phones.
create policy pairing_sessions_select on public.pairing_sessions
  for select to authenticated
  using (user_id = (select auth.uid())
         and (private.is_session_device(new_device) or (select private.device_ok())));
grant select on public.pairing_sessions to authenticated;

-- Step 1 (new phone N, may be SMS-only): commit to its nonce. At most 3 per
-- account per hour.
create or replace function public.pairing_start(p_device uuid, p_commitment bytea)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_id uuid;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  if not private.is_session_device(p_device) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  perform 1 from public.devices
  where id = p_device and user_id = v_user and status = 'pending' and kind = 'phone'
    and public_key is not null and signing_public_key is not null;
  if not found then
    raise exception 'device_not_pending' using errcode = '42501';
  end if;
  perform 1 from public.accounts where id = v_user for update;  -- serialises the limit
  if (select count(*) from public.pairing_sessions
      where user_id = v_user and created_at > now() - interval '1 hour') >= 3 then
    raise exception 'too_many_pairing_sessions' using errcode = '54000';
  end if;
  insert into public.pairing_sessions (user_id, new_device, commitment)
  values (v_user, p_device, p_commitment)
  returning id into v_id;
  return v_id;
end;
$$;

-- Step 2 (approved phone E): post its nonce. E's keys are its devices row.
create or replace function public.pairing_respond(p_pairing uuid, p_nonce bytea)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  if not private.device_ok() then
    raise exception 'approved_device_required' using errcode = '42501';
  end if;
  if p_nonce is null or octet_length(p_nonce) <> 32 then
    raise exception 'bad_nonce' using errcode = '22023';
  end if;
  update public.pairing_sessions
     set responder_device = private.session_device(), responder_nonce = p_nonce, status = 'responded'
   where id = p_pairing and user_id = v_user and status = 'committed' and expires_at > now()
     and new_device <> private.session_device();
  if not found then
    raise exception 'pairing_unavailable' using errcode = 'P0002';
  end if;
end;
$$;

-- Step 3 (new phone N): reveal its nonce. A wrong reveal ends the session.
create or replace function public.pairing_reveal(p_pairing uuid, p_nonce bytea)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_pairing public.pairing_sessions%rowtype;
  v_device public.devices%rowtype;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  select * into v_pairing from public.pairing_sessions
  where id = p_pairing and user_id = v_user for update;
  if not found or not private.is_session_device(v_pairing.new_device) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if v_pairing.status <> 'responded' or v_pairing.expires_at <= now() then
    raise exception 'pairing_unavailable' using errcode = 'P0002';
  end if;
  select * into v_device from public.devices where id = v_pairing.new_device;
  if p_nonce is null or octet_length(p_nonce) <> 32
     or sha256(p_nonce || v_device.public_key || v_device.signing_public_key) <> v_pairing.commitment then
    update public.pairing_sessions set status = 'failed' where id = p_pairing;
    return jsonb_build_object('ok', false, 'error', 'commitment_mismatch');
  end if;
  update public.pairing_sessions set new_nonce = p_nonce, status = 'revealed' where id = p_pairing;
  return jsonb_build_object('ok', true);
end;
$$;

-- Either phone ends the session (codes don't match, or the person gave up).
create or replace function public.pairing_cancel(p_pairing uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_pairing public.pairing_sessions%rowtype;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  select * into v_pairing from public.pairing_sessions
  where id = p_pairing and user_id = v_user for update;
  if not found or not (private.is_session_device(v_pairing.new_device) or private.device_ok()) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  update public.pairing_sessions set status = 'cancelled'
  where id = p_pairing and status in ('committed', 'responded', 'revealed');
end;
$$;

-- The pairing bundle E sends N (HPKE: PSK mode for way 1, base mode for way 2).
create table public.pairing_bundles (
  device_id    uuid primary key references public.devices (id) on delete cascade,
  user_id      uuid not null references public.accounts (id) on delete cascade,
  from_device  uuid not null,
  bundle       bytea not null check (octet_length(bundle) between 1 and 65536),
  created_at   timestamptz not null default now()
);

alter table public.pairing_bundles enable row level security;
create policy pairing_bundles_select_own on public.pairing_bundles
  for select to authenticated
  using (user_id = (select auth.uid()) and private.is_session_device(device_id));
create policy pairing_bundles_delete_own on public.pairing_bundles
  for delete to authenticated
  using (user_id = (select auth.uid()) and private.is_session_device(device_id));
grant select, delete on public.pairing_bundles to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Challenges and the signed device actions (B2, B3)
-- ---------------------------------------------------------------------------

-- Any signed-in session asks for a nonce:
--   bind:    to bind this session to p_device (its own phone, any status but
--            revoked; also re-registers after a lost session);
--   approve: from an approved phone, to approve p_device (pending, same user);
--   recover: from the session that registered or is bound to p_device
--            (pending), to approve it with the recovery device; 5 per phone
--            per day.
-- Returns the nonce in base64. At most 20 nonces per session per hour.
create or replace function public.issue_device_challenge(p_purpose text, p_device uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_session uuid := private.jwt_session_id();
  v_device public.devices%rowtype;
  v_nonce bytea := extensions.gen_random_bytes(32);
begin
  if v_user is null or v_session is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  perform 1 from public.accounts where id = v_user for update;  -- serialises the limits
  if (select count(*) from public.device_challenges
      where session_id = v_session and created_at > now() - interval '1 hour') >= 20 then
    raise exception 'too_many_challenges' using errcode = '54000';
  end if;

  select * into v_device from public.devices
  where id = p_device and user_id = v_user and kind = 'phone';
  if not found or v_device.status = 'revoked' then
    raise exception 'unknown_device' using errcode = 'P0002';
  end if;

  case p_purpose
  when 'bind' then
    null;
  when 'approve' then
    if not private.device_ok() then
      raise exception 'approved_device_required' using errcode = '42501';
    end if;
    if v_device.status <> 'pending' or p_device = private.session_device() then
      raise exception 'device_not_pending' using errcode = '42501';
    end if;
  when 'recover' then
    if not private.is_session_device(p_device) then
      raise exception 'forbidden' using errcode = '42501';
    end if;
    if v_device.status <> 'pending' then
      raise exception 'device_not_pending' using errcode = '42501';
    end if;
    perform 1 from public.account_recovery where user_id = v_user;
    if not found then
      raise exception 'no_recovery' using errcode = 'P0002';
    end if;
    -- Per phone, so an SMS-only session can't use up another phone's tries.
    if (select count(*) from public.device_challenges
        where device_id = p_device and purpose = 'recover'
          and created_at > now() - interval '1 day') >= 5 then
      raise exception 'too_many_recovery_tries' using errcode = '54000';
    end if;
  else
    raise exception 'bad_purpose' using errcode = '22023';
  end case;

  insert into public.device_challenges (nonce, purpose, user_id, session_id, device_id)
  values (v_nonce, p_purpose, v_user, v_session, p_device);
  return private.b64(v_nonce);
end;
$$;

-- Service role: uses up a nonce (whatever the signature check then says) and
-- returns the public keys the Edge Function needs:
--   device:  the device the action is about (id, kx, sig);
--   signer:  whose Ed25519 key must have signed (bind: the device itself;
--            approve: the session's approved phone; recover: the account's
--            recovery device).
create or replace function public.take_device_challenge(
  p_user uuid, p_session uuid, p_purpose text, p_device uuid, p_nonce bytea
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_device public.devices%rowtype;
  v_signer public.devices%rowtype;
begin
  update public.device_challenges
     set used_at = now()
   where nonce = p_nonce and user_id = p_user and session_id = p_session
     and purpose = p_purpose and device_id = p_device
     and used_at is null and expires_at > now();
  if not found then
    raise exception 'bad_challenge' using errcode = '42501';
  end if;

  select * into v_device from public.devices where id = p_device;
  case p_purpose
  when 'bind' then
    v_signer := v_device;
  when 'approve' then
    select * into v_signer from public.devices
    where id = private.approved_bound_device(p_user, p_session);
    if not found then
      raise exception 'approved_device_required' using errcode = '42501';
    end if;
  when 'recover' then
    select d.* into v_signer from public.account_recovery r
    join public.devices d on d.id = r.recovery_device_id
    where r.user_id = p_user and d.status = 'approved';
  end case;
  if v_signer.id is null or v_signer.signing_public_key is null
     or v_device.public_key is null or v_device.signing_public_key is null then
    raise exception 'device_keys_missing' using errcode = '22023';
  end if;

  return jsonb_build_object(
    'device', jsonb_build_object('id', v_device.id, 'kx', private.b64(v_device.public_key),
                                 'sig', private.b64(v_device.signing_public_key)),
    'signer', jsonb_build_object('id', v_signer.id, 'sig', private.b64(v_signer.signing_public_key)));
end;
$$;

-- Service role (bind-device, after checking the device's signature over
-- "usra/v1/bind-session" || 0x00 || session id || nonce): binds the session.
-- p_enroll: the account's very first device approves itself (once ever).
create or replace function public.bind_device_signed(
  p_user uuid, p_session uuid, p_device uuid, p_enroll boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
begin
  perform public.bind_device_session(p_user, p_session, p_device);
  if p_enroll then
    perform public.approve_device(p_device, null);
  end if;
  select status into v_status from public.devices where id = p_device;
  return jsonb_build_object('device_id', p_device, 'status', v_status);
end;
$$;

-- Service role (approve-device, after checking the approving phone's signature
-- over "usra/v1/approve-device" || 0x00 || user || device || dkx || dsig ||
-- nonce): approves p_device from the session's approved phone. With a pairing
-- session (way 2) it must be revealed, by this approver, for this device.
create or replace function public.approve_device_signed(
  p_user uuid, p_session uuid, p_device uuid,
  p_pairing uuid default null, p_bundle bytea default null, p_signer uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_approver uuid := private.approved_bound_device(p_user, p_session);
begin
  if v_approver is null then
    raise exception 'approved_device_required' using errcode = '42501';
  end if;
  -- The phone whose signature the Edge Function checked must still be the
  -- session's phone (it could have been re-bound in between).
  if p_signer is not null and p_signer <> v_approver then
    raise exception 'approver_changed' using errcode = '42501';
  end if;
  perform 1 from public.devices where id = p_device and user_id = p_user;
  if not found then
    raise exception 'unknown_device' using errcode = 'P0002';
  end if;
  if p_pairing is not null then
    update public.pairing_sessions set status = 'done'
    where id = p_pairing and user_id = p_user and new_device = p_device
      and responder_device = v_approver and status = 'revealed' and expires_at > now();
    if not found then
      raise exception 'pairing_unavailable' using errcode = 'P0002';
    end if;
  end if;
  perform public.approve_device(p_device, v_approver);
  update public.pairing_sessions set status = 'cancelled'
  where new_device = p_device and status in ('committed', 'responded', 'revealed');
  if p_bundle is not null then
    insert into public.pairing_bundles (device_id, user_id, from_device, bundle)
    values (p_device, p_user, v_approver, p_bundle)
    on conflict (device_id) do update
      set from_device = excluded.from_device, bundle = excluded.bundle, created_at = now();
  end if;
  return jsonb_build_object('device_id', p_device, 'status', 'approved', 'approved_by', v_approver);
end;
$$;

-- Service role (recover-device, after checking the recovery device's signature
-- over the same approve-device message): approves p_device with the recovery
-- device. Only from the session that registered or is bound to p_device.
create or replace function public.recover_device_signed(
  p_user uuid, p_session uuid, p_device uuid, p_signer uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_recovery uuid;
begin
  if not private.session_may_act_for(p_user, p_session, p_device) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  select r.recovery_device_id into v_recovery
  from public.account_recovery r join public.devices d on d.id = r.recovery_device_id
  where r.user_id = p_user and d.status = 'approved';
  if v_recovery is null then
    raise exception 'no_recovery' using errcode = 'P0002';
  end if;
  -- The key the Edge Function checked must still be the recovery device's.
  if p_signer is not null and p_signer <> v_recovery then
    raise exception 'approver_changed' using errcode = '42501';
  end if;
  perform public.approve_device(p_device, v_recovery);
  update public.pairing_sessions set status = 'cancelled'
  where new_device = p_device and status in ('committed', 'responded', 'revealed');
  return jsonb_build_object('device_id', p_device, 'status', 'approved', 'approved_by', v_recovery);
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. Membership status and per-family devices (B5)
-- ---------------------------------------------------------------------------
alter table public.family_members
  add column status text not null default 'active'
    constraint family_members_status_check check (status in ('active', 'reset'));
comment on column public.family_members.status is
  'reset: the account was reset (section 8); the member keeps no access until another member confirms the removal.';

-- Only active members have a role.
create or replace function private.family_role(p_family uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select role from public.family_members
  where family_id = p_family and user_id = auth.uid() and status = 'active';
$$;

-- An exact mirror of the devices the family log lists (phones and recovery
-- devices), changed only by log entries: added by genesis / add_member /
-- add_device, marked revoked (revoked_seq) by revoke_device, dropped when their
-- member is removed. A revoked marker stays, so that device can never be added
-- to this family again. An account-wide revocation only marks the device
-- revoked in `devices`; the family's next rotation then needs a revoke_device
-- entry first. Wraps and head beacons hang off the rows.
create table public.family_devices (
  family_id    uuid not null references public.families (id) on delete cascade,
  device_id    uuid not null references public.devices (id) on delete cascade,
  user_id      uuid not null,
  added_seq    integer not null check (added_seq > 0),
  revoked_seq  integer check (revoked_seq is null or revoked_seq > added_seq),
  primary key (family_id, device_id)
);

create index family_devices_device_idx on public.family_devices (device_id);
create index family_devices_member_idx on public.family_devices (family_id, user_id);

alter table public.family_devices enable row level security;
create policy family_devices_select_member on public.family_devices
  for select to authenticated
  using ((select private.device_ok()) and private.family_role(family_id) is not null);
grant select on public.family_devices to authenticated;

-- True only for a session bound to an approved phone that is a current device
-- of this family, of an active member.
create or replace function private.family_device_ok(p_family uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.device_ok() and exists (
    select 1
    from public.family_devices fd
    join public.family_members m on m.family_id = fd.family_id and m.user_id = fd.user_id
    where fd.family_id = p_family
      and fd.device_id = private.session_device()
      and fd.user_id = auth.uid()
      and fd.revoked_seq is null
      and m.status = 'active');
$$;

-- Key epochs: the commitment KC_v from the genesis / rotate_key entry and the
-- history blob that encrypts FK_{v-1} under FK_v (section 6).
create table public.family_epochs (
  family_id       uuid not null references public.families (id) on delete cascade,
  key_version     integer not null check (key_version > 0),
  log_seq         integer not null check (log_seq > 0),
  key_commitment  bytea not null check (octet_length(key_commitment) = 32),
  history         bytea check (history is null or octet_length(history) = 72),  -- nonce 24 + key 32 + tag 16
  created_at      timestamptz not null default now(),
  primary key (family_id, key_version),
  constraint family_epochs_history check ((key_version = 1) = (history is null))
);

alter table public.family_epochs enable row level security;
create policy family_epochs_select on public.family_epochs
  for select to authenticated using (private.family_device_ok(family_id));
grant select on public.family_epochs to authenticated;

-- Family key wraps: FK_v sealed with HPKE to one device, signed by the sender.
create table public.family_key_wraps (
  family_id            uuid not null,
  key_version          integer not null check (key_version > 0),
  recipient_device_id  uuid not null,
  sender_device_id     uuid not null,      -- no FK: the trail stays if the sender goes
  enc                  bytea not null check (octet_length(enc) = 32),
  ct                   bytea not null check (octet_length(ct) = 48),   -- key 32 + tag 16
  sig                  bytea not null check (octet_length(sig) = 64),
  created_at           timestamptz not null default now(),
  primary key (family_id, key_version, recipient_device_id),
  foreign key (family_id, recipient_device_id)
    references public.family_devices (family_id, device_id) on delete cascade
);

alter table public.family_key_wraps enable row level security;
-- A phone reads its own wraps, and (way 3) the wraps of its account's
-- recovery device.
create policy family_key_wraps_select_own on public.family_key_wraps
  for select to authenticated
  using (private.family_device_ok(family_id)
         and (recipient_device_id = private.session_device()
              or recipient_device_id = (select r.recovery_device_id from public.account_recovery r
                                        where r.user_id = (select auth.uid()))));
-- A phone may delete its own wraps (one it can't open, say), so a member's
-- phone can store a good one: existing wraps are never overwritten.
create policy family_key_wraps_delete_own on public.family_key_wraps
  for delete to authenticated
  using (private.family_device_ok(family_id) and recipient_device_id = private.session_device());
grant select, delete on public.family_key_wraps to authenticated;

-- Signed head beacons, newest per device (section 7).
create table public.family_heads (
  family_id   uuid not null,
  device_id   uuid not null,
  seq         integer not null check (seq > 0),
  head_hash   bytea not null check (octet_length(head_hash) = 32),
  beacon      bytea not null check (octet_length(beacon) <= 1024),
  sig         bytea not null check (octet_length(sig) = 64),
  updated_at  timestamptz not null default now(),
  primary key (family_id, device_id),
  foreign key (family_id, device_id)
    references public.family_devices (family_id, device_id) on delete cascade
);

alter table public.family_heads enable row level security;
create policy family_heads_select on public.family_heads
  for select to authenticated using (private.family_device_ok(family_id));
grant select on public.family_heads to authenticated;

-- B0's revoke, plus: a revoked device leaves every family at once (its wraps
-- and beacons go with it) and its pairing state is dropped.
create or replace function public.revoke_device(p_device uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
  v_created uuid;
  v_sessions uuid[];
begin
  select status, created_session_id into v_status, v_created
  from public.devices where id = p_device for update;
  if not found then
    raise exception 'unknown_device' using errcode = 'P0002';
  end if;
  if v_status <> 'revoked' then
    update public.devices set status = 'revoked', revoked_at = now() where id = p_device;
  end if;
  -- Every family whose log lists it must rotate (after a revoke_device entry,
  -- which only the log can add: the per-family list isn't touched here).
  update public.families f set rotation_pending = true
  where exists (select 1 from public.family_devices fd
                where fd.family_id = f.id and fd.device_id = p_device and fd.revoked_seq is null);
  delete from public.family_key_wraps where recipient_device_id = p_device;
  delete from public.family_heads where device_id = p_device;
  -- End its Auth sessions: the bound ones, and the one that registered it
  -- unless that session is bound to another phone.
  with gone as (
    delete from public.device_sessions where device_id = p_device returning session_id)
  select array_agg(session_id) into v_sessions from gone;
  if v_created is not null
     and not exists (select 1 from public.device_sessions where session_id = v_created) then
    v_sessions := coalesce(v_sessions, '{}') || v_created;
  end if;
  perform private.end_auth_sessions(v_sessions);
  delete from public.push_tokens where device_id = p_device;
  delete from public.pairing_bundles where device_id = p_device;
  update public.pairing_sessions set status = 'cancelled'
  where (new_device = p_device or responder_device = p_device)
    and status in ('committed', 'responded', 'revealed');
end;
$$;

-- Sign-out with sync (B10): a session revokes its own phone instead of
-- deleting the row. Revoked is final; the app wipes its keys and session.
create or replace function public.revoke_own_device(p_device uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  if not private.is_session_device(p_device) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  perform public.revoke_device(p_device);
end;
$$;

-- Records: reads need a current device of the family.
drop policy e2ee_select_member on public.e2ee_records;
create policy e2ee_select_member on public.e2ee_records
  for select to authenticated using (private.family_device_ok(family_id));

-- Families are created only by a genesis entry (append_family_log).
drop policy families_insert_self on public.families;
revoke insert on public.families from authenticated;

-- ---------------------------------------------------------------------------
-- 7. Invites with a lookup hash and the invitee's devices + MAC (B9)
-- ---------------------------------------------------------------------------
alter table public.family_invites
  add column invitee_devices jsonb,
  add column invitee_mac bytea constraint family_invites_mac_check
    check (invitee_mac is null or octet_length(invitee_mac) = 32);
comment on column public.family_invites.code_hash is
  'hex(SHA-256("usra/v1/invite-lookup" || 0x00 || invite_secret)). The secret never reaches the server.';
comment on column public.family_invites.invitee_devices is
  'Device records the invitee posted when accepting; the owner checks their MAC before add_member.';

create table public.invite_accept_attempts (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references public.accounts (id) on delete cascade,
  created_at  timestamptz not null default now()
);
create index invite_accept_attempts_user_idx on public.invite_accept_attempts (user_id, created_at);
alter table public.invite_accept_attempts enable row level security;

-- A device record inside a log entry or invite: { id, user, kind, kx, sig }
-- that matches an approved devices row of p_user. Returns the device id.
create or replace function private.log_device(p jsonb, p_user uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_id text := private.jstr(p, 'id');
begin
  if jsonb_typeof(p) is distinct from 'object'
     or private.jkeys(p) <> array['id', 'kind', 'kx', 'sig', 'user']
     or not private.is_uuid(v_id)
     or private.jstr(p, 'user') is distinct from p_user::text
     or coalesce(private.jstr(p, 'kind'), '') not in ('phone', 'recovery') then
    raise exception 'bad_device_record' using errcode = '22023';
  end if;
  perform 1 from public.devices d
  where d.id = v_id::uuid and d.user_id = p_user and d.kind = private.jstr(p, 'kind')
    and d.status = 'approved'
    and d.public_key = private.unb64url(private.jstr(p, 'kx'))
    and d.signing_public_key = private.unb64url(private.jstr(p, 'sig'));
  if not found then
    raise exception 'device_mismatch' using errcode = '42501';
  end if;
  return v_id::uuid;
end;
$$;

-- A list of device records for p_user: non-empty, no duplicates, all
-- approved, and including the account's current recovery device if it has one.
create or replace function private.log_devices(p jsonb, p_user uuid)
returns uuid[]
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_ids uuid[];
  v_recovery uuid;
begin
  if jsonb_typeof(p) is distinct from 'array' or jsonb_array_length(p) not between 1 and 20 then
    raise exception 'bad_device_record' using errcode = '22023';
  end if;
  select array_agg(private.log_device(e, p_user)) into v_ids from jsonb_array_elements(p) e;
  if cardinality(v_ids) <> (select count(distinct x) from unnest(v_ids) x) then
    raise exception 'bad_device_record' using errcode = '22023';
  end if;
  select recovery_device_id into v_recovery from public.account_recovery where user_id = p_user;
  if v_recovery is not null and not (v_recovery = any (v_ids)) then
    raise exception 'recovery_device_missing' using errcode = '22023';
  end if;
  return v_ids;
end;
$$;

-- Step 2–3 of section 9, on an approved phone: the invitee sends the lookup
-- hash (never the secret), their device records and the MAC over them. They
-- become a member only when the owner's phone appends add_member. Ten tries
-- per hour; failed tries count, so they are answered, not raised.
drop function public.accept_family_invite(text);
create function public.accept_family_invite(p_lookup text, p_devices jsonb, p_mac bytea)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_invite public.family_invites%rowtype;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  if not private.device_ok() then
    raise exception 'approved_device_required' using errcode = '42501';
  end if;
  perform 1 from public.accounts where id = v_user for update;
  if (select count(*) from public.invite_accept_attempts
      where user_id = v_user and created_at > now() - interval '1 hour') >= 10 then
    return jsonb_build_object('ok', false, 'error', 'too_many_attempts');
  end if;
  insert into public.invite_accept_attempts (user_id) values (v_user);

  select * into v_invite from public.family_invites
  where code_hash = lower(coalesce(p_lookup, ''))
    and accepted_at is null and revoked_at is null and expires_at > now()
  for update;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'invalid_invite');
  end if;
  if exists (select 1 from public.family_members
             where family_id = v_invite.family_id and user_id = v_user) then
    return jsonb_build_object('ok', false, 'error', 'invalid_invite');
  end if;
  if p_mac is null or octet_length(p_mac) <> 32 then
    raise exception 'bad_mac' using errcode = '22023';
  end if;
  if not (private.session_device() = any (private.log_devices(p_devices, v_user))) then
    raise exception 'session_device_missing' using errcode = '22023';
  end if;

  update public.family_invites
     set accepted_by = v_user, accepted_at = now(), invitee_devices = p_devices, invitee_mac = p_mac
   where id = v_invite.id;
  return jsonb_build_object('ok', true, 'family_id', v_invite.family_id, 'invite_id', v_invite.id);
end;
$$;

-- For the owner's phone: accepted invites waiting for add_member, with the
-- invitee's phone number ("Is this Mona?") and when their account was last
-- reset (in-person re-invite only, section 9).
create or replace function public.pending_family_invites(p_family uuid)
returns table (
  invite_id        uuid,
  role             text,
  user_id          uuid,
  phone            text,
  accepted_at      timestamptz,
  devices          jsonb,
  mac              text,
  last_reset_at    timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not private.device_ok() or private.family_role(p_family) is distinct from 'owner' then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  return query
    select i.id, i.role, i.accepted_by, u.phone::text, i.accepted_at, i.invitee_devices,
           private.b64(i.invitee_mac),
           (select max(r.completed_at) from public.account_resets r where r.user_id = i.accepted_by)
    from public.family_invites i
    join auth.users u on u.id = i.accepted_by
    where i.family_id = p_family and i.accepted_at is not null
      and i.used_at is null and i.revoked_at is null
    order by i.accepted_at;
end;
$$;

-- ---------------------------------------------------------------------------
-- 8. Account reset (B3): 7 days, cancellable from an older approved phone
-- ---------------------------------------------------------------------------
create table public.account_resets (
  id                   uuid primary key default gen_random_uuid(),
  user_id              uuid not null references public.accounts (id) on delete cascade,
  started_device       uuid references public.devices (id) on delete set null,
  started_at           timestamptz not null default now(),
  completes_at         timestamptz not null default now() + interval '7 days',
  cancelled_at         timestamptz,
  cancelled_by_device  uuid,
  completed_at         timestamptz,
  constraint account_resets_once check (cancelled_at is null or completed_at is null)
);

create unique index account_resets_open_idx on public.account_resets (user_id)
  where cancelled_at is null and completed_at is null;

alter table public.account_resets enable row level security;
-- Every session of the account sees its resets, so the app checks on launch.
create policy account_resets_select_own on public.account_resets
  for select to authenticated using (user_id = (select auth.uid()));
grant select on public.account_resets to authenticated;

-- An SMS-only session may start a reset of an enrolled account, naming the
-- pending phone it registered: that phone is the one that stays.
create or replace function public.start_account_reset(p_device uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_id uuid;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  if not private.is_session_device(p_device) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  perform 1 from public.devices
  where id = p_device and user_id = v_user and status = 'pending' and kind = 'phone';
  if not found then
    raise exception 'device_not_pending' using errcode = '42501';
  end if;
  perform 1 from public.accounts where id = v_user and sync_enrolled_at is not null for update;
  if not found then
    raise exception 'not_enrolled' using errcode = '22023';
  end if;
  select id into v_id from public.account_resets
  where user_id = v_user and cancelled_at is null and completed_at is null;
  if v_id is null then
    insert into public.account_resets (user_id, started_device)
    values (v_user, p_device) returning id into v_id;
  end if;
  return v_id;
end;
$$;

-- "This isn't me": only from an approved phone enrolled 7+ days before the
-- reset started, so a phone an attacker just added can't cancel it.
create or replace function public.cancel_account_reset(p_reset uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  if not private.device_ok() then
    raise exception 'approved_device_required' using errcode = '42501';
  end if;
  update public.account_resets r
     set cancelled_at = now(), cancelled_by_device = private.session_device()
   where r.id = p_reset and r.user_id = v_user
     and r.cancelled_at is null and r.completed_at is null
     and exists (select 1 from public.devices d
                 where d.id = private.session_device()
                   and d.approved_at <= r.started_at - interval '7 days');
  if not found then
    raise exception 'cannot_cancel' using errcode = '42501';
  end if;
end;
$$;

-- Service role (housekeeping): finishes resets that ran 7 days. Revokes every
-- device of the account but the one that started the reset (recovery device
-- included), forgets the recovery settings, marks the memberships 'reset' and
-- flags a rotation; the account can enrol a first device again.
create or replace function public.complete_account_resets()
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reset public.account_resets%rowtype;
  v_device uuid;
  v_count integer := 0;
begin
  for v_reset in
    select * from public.account_resets
    where cancelled_at is null and completed_at is null and completes_at <= now()
    for update skip locked
  loop
    for v_device in
      select id from public.devices
      where user_id = v_reset.user_id and status <> 'revoked'
        and id is distinct from v_reset.started_device
    loop
      perform public.revoke_device(v_device);
    end loop;
    delete from public.account_recovery where user_id = v_reset.user_id;
    update public.family_members set status = 'reset' where user_id = v_reset.user_id;
    update public.families f set rotation_pending = true
    where exists (select 1 from public.family_members m
                  where m.family_id = f.id and m.user_id = v_reset.user_id);
    update public.accounts set sync_enrolled_at = null where id = v_reset.user_id;
    update public.account_resets set completed_at = now() where id = v_reset.id;
    v_count := v_count + 1;
  end loop;
  return v_count;
end;
$$;

-- ---------------------------------------------------------------------------
-- 9. The family log: strict entries, mirrored into members, devices, epochs
--    and wraps (B5, B6). Replaces B0's append_family_log.
-- ---------------------------------------------------------------------------

-- Stores wraps for one epoch. p_strict: every insert must be new (rotation).
create or replace function private.store_wraps(
  p_family uuid, p_key_version integer, p_sender uuid, p_wraps jsonb, p_strict boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_wrap jsonb;
  v_recipient text;
  v_results jsonb := '[]'::jsonb;
begin
  if jsonb_typeof(p_wraps) is distinct from 'array'
     or jsonb_array_length(p_wraps) not between 1 and 1000 then
    raise exception 'bad_wraps' using errcode = '22023';
  end if;
  for v_wrap in select value from jsonb_array_elements(p_wraps) loop
    v_recipient := private.jstr(v_wrap, 'recipient');
    if jsonb_typeof(v_wrap) <> 'object' or private.jkeys(v_wrap) <> array['ct', 'enc', 'recipient', 'sig']
       or not private.is_uuid(v_recipient) then
      raise exception 'bad_wraps' using errcode = '22023';
    end if;
    perform 1 from public.family_devices fd join public.devices d on d.id = fd.device_id
    where fd.family_id = p_family and fd.device_id = v_recipient::uuid
      and fd.revoked_seq is null and d.status = 'approved';
    if not found then
      raise exception 'recipient_not_in_family' using errcode = '42501';
    end if;
    insert into public.family_key_wraps
      (family_id, key_version, recipient_device_id, sender_device_id, enc, ct, sig)
    values (p_family, p_key_version, v_recipient::uuid, p_sender,
            decode(private.jstr(v_wrap, 'enc'), 'base64'),
            decode(private.jstr(v_wrap, 'ct'), 'base64'),
            decode(private.jstr(v_wrap, 'sig'), 'base64'))
    on conflict (family_id, key_version, recipient_device_id) do nothing;
    if not found and p_strict then
      raise exception 'bad_wraps' using errcode = '22023';
    end if;
    v_results := v_results || jsonb_build_object('recipient', v_recipient, 'stored', found);
  end loop;
  return v_results;
end;
$$;

drop function public.append_family_log(uuid, integer, bytea, bytea, bytea);

-- Service role, after append-family-log checked the Ed25519 signature
-- ("usra/v1/log-entry" || 0x00 || entry) with the key of the entry's "by"
-- device. Appends only on top of the current head (compare-and-set) and
-- mirrors the entry. rotate_key also takes the history blob and every wrap of
-- the new epoch, stored in the same transaction.
create function public.append_family_log(
  p_family     uuid,
  p_seq        integer,
  p_prev_hash  bytea,
  p_entry      bytea,
  p_sig        bytea,
  p_history    bytea default null,
  p_wraps      jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entry       jsonb;
  v_type        text;
  v_keys        text[];
  v_allowed     text[];
  v_family      public.families%rowtype;
  v_head_seq    integer;
  v_head_hash   bytea;
  v_signer      public.devices%rowtype;
  v_signer_role text;
  v_user        uuid;
  v_role        text;
  v_target      public.family_members%rowtype;
  v_device      uuid;
  v_devices     uuid[];
  v_invite      public.family_invites%rowtype;
  v_kc          bytea;
  v_recipients  uuid[];
  v_current     uuid[];
begin
  if p_sig is null or octet_length(p_sig) <> 64 then
    raise exception 'bad_entry' using errcode = '22023';
  end if;
  v_entry := private.strict_json(p_entry, 16384);
  if v_entry is null then
    raise exception 'bad_entry' using errcode = '22023';
  end if;
  if v_entry -> 'v' is distinct from '1'::jsonb
     or private.jstr(v_entry, 'family') is distinct from p_family::text
     or v_entry -> 'seq' is distinct from to_jsonb(p_seq)
     or v_entry -> 'prev' is distinct from coalesce(to_jsonb(private.b64url(p_prev_hash)), 'null'::jsonb) then
    raise exception 'entry_mismatch' using errcode = '22023';
  end if;
  v_type := private.jstr(v_entry, 'type');
  if not private.is_uuid(private.jstr(v_entry, 'by'))
     or coalesce(private.jstr(v_entry, 'at'), '') !~ '^[0-9a-f]{16}$' then
    raise exception 'bad_entry' using errcode = '22023';
  end if;

  -- Exactly the fields of the type; unknown top-level keys are rejected.
  v_allowed := case v_type
    when 'genesis' then array['devices', 'kc', 'key_version', 'user']
    when 'add_member' then array['devices', 'invite', 'mac', 'role', 'user']
      || case when private.jstr(v_entry, 'role') = 'cared_for' then array['profile'] else '{}' end
    when 'change_role' then array['role', 'user']
      || case when private.jstr(v_entry, 'role') = 'cared_for' then array['profile'] else '{}' end
    when 'transfer_owner' then array['user']
    when 'remove_member' then array['reason', 'user']
    when 'add_device' then array['device', 'user']
    when 'revoke_device' then array['device', 'user']
    when 'rotate_key' then array['history', 'kc', 'key_version', 'recipients']
    end;
  if v_allowed is null then
    raise exception 'unknown_entry_type' using errcode = '22023';
  end if;
  v_allowed := v_allowed || array['at', 'by', 'family', 'prev', 'seq', 'type', 'v'];
  select array_agg(k collate "C" order by k collate "C") into v_allowed from unnest(v_allowed) k;
  v_keys := private.jkeys(v_entry);
  if v_keys <> v_allowed then
    raise exception 'bad_entry_fields' using errcode = '22023';
  end if;
  if v_entry ? 'user' and not private.is_uuid(private.jstr(v_entry, 'user')) then
    raise exception 'bad_entry' using errcode = '22023';
  end if;
  if v_entry ? 'profile' and not private.is_uuid(private.jstr(v_entry, 'profile')) then
    raise exception 'bad_entry' using errcode = '22023';
  end if;
  if (v_type = 'rotate_key') <> (p_history is not null or p_wraps is not null) then
    raise exception 'bad_rotation' using errcode = '22023';
  end if;
  if (v_type = 'genesis') <> (p_seq = 1) then
    raise exception 'genesis_first' using errcode = '22023';
  end if;

  -- Locked so a concurrent revoke_device can't land between check and append.
  select * into v_signer from public.devices
  where id = private.jstr(v_entry, 'by')::uuid for share;
  if not found or v_signer.status <> 'approved' then
    raise exception 'signer_not_approved' using errcode = '42501';
  end if;

  -- Before locking the family or saying anything about its head: the signer's
  -- account must be an active member (or, for a new family, it is a genesis).
  -- A family the signer isn't in looks the same as one that doesn't exist.
  if exists (select 1 from public.families where id = p_family)
       <> exists (select 1 from public.family_members m
                  where m.family_id = p_family and m.user_id = v_signer.user_id and m.status = 'active')
     or (v_type <> 'genesis' and not exists (select 1 from public.families where id = p_family)) then
    raise exception 'signer_not_member' using errcode = '42501';
  end if;

  -- Serialises appends and record pushes for this family. A genesis creates
  -- the family (the trigger makes its signer's account the owner).
  select * into v_family from public.families where id = p_family for update;
  if not found then
    if v_type <> 'genesis' then
      raise exception 'signer_not_member' using errcode = '42501';
    end if;
    if private.jstr(v_entry, 'user') is distinct from v_signer.user_id::text then
      raise exception 'forbidden' using errcode = '42501';
    end if;
    insert into public.families (id, created_by) values (p_family, v_signer.user_id);
    select * into v_family from public.families where id = p_family for update;
  end if;

  select l.seq, l.hash into v_head_seq, v_head_hash
  from public.family_log l where l.family_id = p_family
  order by l.seq desc limit 1;
  if p_seq <> coalesce(v_head_seq, 0) + 1 or p_prev_hash is distinct from v_head_hash then
    return jsonb_build_object('ok', false, 'error', 'head_mismatch',
                              'head_seq', coalesce(v_head_seq, 0),
                              'head_hash', private.b64url(v_head_hash));
  end if;

  -- The signer: a current device of this family, of an active member.
  select m.role into v_signer_role from public.family_members m
  where m.family_id = p_family and m.user_id = v_signer.user_id and m.status = 'active';
  if v_signer_role is null then
    raise exception 'signer_not_member' using errcode = '42501';
  end if;
  if v_type <> 'genesis' then
    perform 1 from public.family_devices
    where family_id = p_family and device_id = v_signer.id and revoked_seq is null;
    if not found then
      raise exception 'signer_not_in_family' using errcode = '42501';
    end if;
  end if;

  v_user := private.jstr(v_entry, 'user')::uuid;
  v_role := private.jstr(v_entry, 'role');

  case v_type
  when 'genesis' then
    if v_signer_role <> 'owner' or v_user <> v_signer.user_id or v_signer.kind <> 'phone' then
      raise exception 'forbidden' using errcode = '42501';
    end if;
    v_kc := private.unb64url(private.jstr(v_entry, 'kc'));
    if v_entry -> 'key_version' is distinct from '1'::jsonb or octet_length(v_kc) is distinct from 32 then
      raise exception 'bad_entry' using errcode = '22023';
    end if;
    v_devices := private.log_devices(v_entry -> 'devices', v_user);
    if not (v_signer.id = any (v_devices)) then
      raise exception 'signer_not_listed' using errcode = '22023';
    end if;
    insert into public.family_devices (family_id, device_id, user_id, added_seq)
    select p_family, d, v_user, p_seq from unnest(v_devices) d;
    insert into public.family_epochs (family_id, key_version, log_seq, key_commitment)
    values (p_family, 1, p_seq, v_kc);
    update public.families set current_key_version = 1, rotation_pending = false where id = p_family;

  when 'add_member', 'change_role' then
    if v_signer_role <> 'owner' then
      raise exception 'forbidden' using errcode = '42501';
    end if;
    if v_role is null or v_role not in ('guardian', 'cared_for', 'viewer') or v_user = v_signer.user_id then
      raise exception 'bad_role' using errcode = '22023';
    end if;
    if v_type = 'add_member' then
      -- Nobody joins without accepting an invite to this family: the entry
      -- names the invite they accepted, for that role, with the devices and
      -- MAC they posted, and the invite is neither revoked nor used.
      if not private.is_uuid(private.jstr(v_entry, 'invite')) then
        raise exception 'bad_entry' using errcode = '22023';
      end if;
      select * into v_invite from public.family_invites i
      where i.id = private.jstr(v_entry, 'invite')::uuid and i.family_id = p_family
        and i.accepted_by = v_user and i.accepted_at is not null and i.role = v_role
        and i.revoked_at is null and i.used_at is null
      for update;
      if not found then
        raise exception 'no_accepted_invite' using errcode = '42501';
      end if;
      if private.unb64url(private.jstr(v_entry, 'mac')) is distinct from v_invite.invitee_mac then
        raise exception 'invite_mac_mismatch' using errcode = '42501';
      end if;
      v_devices := private.log_devices(v_entry -> 'devices', v_user);
      if (select array_agg(x order by x) from unnest(v_devices) x)
         is distinct from (select array_agg((e ->> 'id')::uuid order by (e ->> 'id')::uuid)
                           from jsonb_array_elements(v_invite.invitee_devices) e) then
        raise exception 'invite_devices_mismatch' using errcode = '42501';
      end if;
      if exists (select 1 from public.family_devices
                 where family_id = p_family and device_id = any (v_devices) and revoked_seq is not null) then
        raise exception 'device_revoked_in_family' using errcode = '42501';
      end if;
      update public.family_invites set used_at = now() where id = v_invite.id;
      insert into public.family_members (family_id, user_id, role)
      values (p_family, v_user, v_role)
      on conflict (family_id, user_id) do nothing;
      if not found then
        raise exception 'already_member' using errcode = '23505';
      end if;
      insert into public.family_devices (family_id, device_id, user_id, added_seq)
      select p_family, d, v_user, p_seq from unnest(v_devices) d;
    else
      update public.family_members set role = v_role
      where family_id = p_family and user_id = v_user and status = 'active' and role <> 'owner';
      if not found then
        raise exception 'not_a_member' using errcode = 'P0002';
      end if;
    end if;

  when 'transfer_owner' then
    if v_signer_role <> 'owner' then
      raise exception 'forbidden' using errcode = '42501';
    end if;
    if v_user = v_signer.user_id then
      raise exception 'bad_target' using errcode = '22023';
    end if;
    perform 1 from public.family_members
    where family_id = p_family and user_id = v_user and status = 'active';
    if not found then
      raise exception 'not_a_member' using errcode = 'P0002';
    end if;
    -- Demote first: one owner per family (family_members_one_owner).
    update public.family_members set role = 'guardian'
    where family_id = p_family and user_id = v_signer.user_id;
    update public.family_members set role = 'owner'
    where family_id = p_family and user_id = v_user;

  when 'remove_member' then
    select * into v_target from public.family_members m
    where m.family_id = p_family and m.user_id = v_user;
    case private.jstr(v_entry, 'reason')
    when 'account_deleted' then
      -- Any member may record it (a person confirmed it on their phone), but
      -- only for an account that is really gone. Its membership row went with
      -- the account (and flagged the rotation), so there may be nothing left.
      -- Its last add_member (or genesis) in this log must be later than its
      -- last removal. One answer for every refusal, so it isn't an oracle for
      -- which accounts exist.
      if exists (select 1 from public.accounts a where a.id = v_user)
         or coalesce((select max(l.seq) from public.family_log l
                      where l.family_id = p_family
                        and convert_from(l.entry, 'UTF8')::jsonb ->> 'user' = v_user::text
                        and convert_from(l.entry, 'UTF8')::jsonb ->> 'type' in ('genesis', 'add_member')), 0)
            <= coalesce((select max(l.seq) from public.family_log l
                         where l.family_id = p_family
                           and convert_from(l.entry, 'UTF8')::jsonb ->> 'user' = v_user::text
                           and convert_from(l.entry, 'UTF8')::jsonb ->> 'type' = 'remove_member'), 0) then
        raise exception 'bad_target' using errcode = '42501';
      end if;
    when 'reset' then
      -- Any member, once a person confirmed it, for an account whose reset
      -- completed (its membership is marked 'reset').
      if v_target.status is distinct from 'reset' then
        raise exception 'not_reset' using errcode = '42501';
      end if;
    when 'removed', 'left' then
      if v_target.user_id is null or v_target.status <> 'active' then
        raise exception 'not_a_member' using errcode = 'P0002';
      end if;
      if (private.jstr(v_entry, 'reason') = 'removed' and v_signer_role <> 'owner')
         or (private.jstr(v_entry, 'reason') = 'left' and v_user <> v_signer.user_id) then
        raise exception 'forbidden' using errcode = '42501';
      end if;
    else
      raise exception 'bad_reason' using errcode = '22023';
    end case;
    -- Never the owner, whatever the reason: they hand over first, and a family
    -- whose owner reset stays frozen (section 11).
    if v_target.role = 'owner' then
      raise exception 'owner_cannot_be_removed' using errcode = '42501';
    end if;
    -- Its current devices leave the family (wraps and beacons cascade); revoked
    -- markers stay. The membership delete trigger flags the rotation.
    delete from public.family_devices
    where family_id = p_family and user_id = v_user and revoked_seq is null;
    delete from public.family_members where family_id = p_family and user_id = v_user;

  when 'add_device' then
    if v_user <> v_signer.user_id then
      raise exception 'forbidden' using errcode = '42501';
    end if;
    v_device := private.log_device(v_entry -> 'device', v_user);
    -- Revoked is final: a device revoked in this family never comes back.
    if exists (select 1 from public.family_devices
               where family_id = p_family and device_id = v_device and revoked_seq is not null) then
      raise exception 'device_revoked_in_family' using errcode = '42501';
    end if;
    insert into public.family_devices (family_id, device_id, user_id, added_seq)
    values (p_family, v_device, v_user, p_seq)
    on conflict (family_id, device_id) do nothing;
    if not found then
      raise exception 'already_in_family' using errcode = '23505';
    end if;

  when 'revoke_device' then
    if v_user <> v_signer.user_id and v_signer_role <> 'owner' then
      raise exception 'forbidden' using errcode = '42501';
    end if;
    if not private.is_uuid(private.jstr(v_entry, 'device')) then
      raise exception 'bad_entry' using errcode = '22023';
    end if;
    v_device := private.jstr(v_entry, 'device')::uuid;
    -- Marked revoked in this family (it can't be added back); its wraps and
    -- beacon here go.
    update public.family_devices set revoked_seq = p_seq
    where family_id = p_family and device_id = v_device and user_id = v_user and revoked_seq is null;
    if not found then
      raise exception 'device_not_in_family' using errcode = 'P0002';
    end if;
    delete from public.family_key_wraps where family_id = p_family and recipient_device_id = v_device;
    delete from public.family_heads where family_id = p_family and device_id = v_device;
    -- A person's own revocation is final everywhere (it flags the rotation in
    -- every family that lists the device); the owner's revocation of someone
    -- else's device is final in this family.
    if v_user = v_signer.user_id then
      perform public.revoke_device(v_device);
    end if;
    update public.families set rotation_pending = true where id = p_family;

  when 'rotate_key' then
    if v_entry -> 'key_version' is distinct from to_jsonb(v_family.current_key_version + 1) then
      raise exception 'bad_key_version' using errcode = '22023';
    end if;
    v_kc := private.unb64url(private.jstr(v_entry, 'kc'));
    if octet_length(v_kc) is distinct from 32 then
      raise exception 'bad_entry' using errcode = '22023';
    end if;
    -- The entry commits to SHA-256 of the history blob it ships with.
    if p_history is null or octet_length(p_history) <> 72
       or private.unb64url(private.jstr(v_entry, 'history')) is distinct from sha256(p_history) then
      raise exception 'history_mismatch' using errcode = '22023';
    end if;
    -- One wrap for every current device of every active member, and the
    -- entry's recipient hash is SHA-256 of their sorted 16-byte ids.
    if jsonb_typeof(p_wraps) is distinct from 'array' then
      raise exception 'bad_wraps' using errcode = '22023';
    end if;
    select array_agg(x order by x) into v_recipients
    from (select (w ->> 'recipient')::uuid x from jsonb_array_elements(p_wraps) w) s;
    -- A device revoked account-wide but still listed here needs its
    -- revoke_device entry first, so the server's list stays the log's.
    if exists (select 1 from public.family_devices fd join public.devices d on d.id = fd.device_id
               where fd.family_id = p_family and fd.revoked_seq is null and d.status = 'revoked') then
      raise exception 'revoked_device_listed' using errcode = '55000';
    end if;
    select array_agg(fd.device_id order by fd.device_id) into v_current
    from public.family_devices fd
    join public.family_members m on m.family_id = fd.family_id and m.user_id = fd.user_id
    where fd.family_id = p_family and fd.revoked_seq is null and m.status = 'active';
    if v_recipients is distinct from v_current
       or private.unb64url(private.jstr(v_entry, 'recipients')) is distinct from
          (select sha256(string_agg(private.uuid_bytes(x), ''::bytea order by x)) from unnest(v_current) x) then
      raise exception 'recipients_mismatch' using errcode = '22023';
    end if;
    insert into public.family_epochs (family_id, key_version, log_seq, key_commitment, history)
    values (p_family, v_family.current_key_version + 1, p_seq, v_kc, p_history);
    perform private.store_wraps(p_family, v_family.current_key_version + 1, v_signer.id, p_wraps, true);
    -- Only the current epoch is wrapped; older keys come from the history chain.
    delete from public.family_key_wraps
    where family_id = p_family and key_version <= v_family.current_key_version;
    update public.families
       set current_key_version = v_family.current_key_version + 1, rotation_pending = false
     where id = p_family;
  end case;

  insert into public.family_log (family_id, seq, prev_hash, entry, sig, signer_device)
  values (p_family, p_seq, p_prev_hash, p_entry, p_sig, v_signer.id);

  return jsonb_build_object('ok', true, 'seq', p_seq, 'hash', private.b64url(sha256(p_entry)));
end;
$$;

-- Service role: the signing key the Edge Function checks an entry against.
create or replace function public.device_signing_key(p_device uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$ select private.b64(signing_public_key) from public.devices where id = p_device; $$;

-- Service role (append-family-log): the caller's own checks, then the append.
-- The caller's session must be bound to an approved phone of p_user, and the
-- entry signed by that phone or by p_user's recovery device (way 3: a
-- recovered phone appends add_device for itself, signed with rsig).
create or replace function public.append_family_log_as(
  p_user       uuid,
  p_session    uuid,
  p_family     uuid,
  p_seq        integer,
  p_prev_hash  bytea,
  p_entry      bytea,
  p_sig        bytea,
  p_history    bytea default null,
  p_wraps      jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_session_device uuid := private.approved_bound_device(p_user, p_session);
  v_by text;
begin
  if v_session_device is null then
    raise exception 'approved_device_required' using errcode = '42501';
  end if;
  v_by := private.jstr(private.strict_json(p_entry, 16384), 'by');
  if not private.is_uuid(v_by) then
    raise exception 'bad_entry' using errcode = '22023';
  end if;
  if v_by::uuid <> v_session_device
     and not exists (select 1 from public.account_recovery r
                     where r.user_id = p_user and r.recovery_device_id = v_by::uuid) then
    raise exception 'signer_not_caller' using errcode = '42501';
  end if;
  return public.append_family_log(p_family, p_seq, p_prev_hash, p_entry, p_sig, p_history, p_wraps);
end;
$$;

-- Re-wraps of the current key, by a current device of the family: to a new
-- phone or member after add_device / add_member, or to itself (way 3).
-- p_wraps: [{ recipient: uuid, enc, ct, sig: base64 }]. Existing wraps are
-- kept (reported as stored = false).
create or replace function public.put_family_key_wraps(p_family uuid, p_key_version integer, p_wraps jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_current integer;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  if not private.device_ok() then
    raise exception 'approved_device_required' using errcode = '42501';
  end if;
  if not private.family_device_ok(p_family) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  select current_key_version into v_current from public.families where id = p_family for share;
  if p_key_version is distinct from v_current then
    return jsonb_build_object('ok', false, 'error', 'stale_key', 'current_key_version', v_current);
  end if;
  if jsonb_typeof(p_wraps) is distinct from 'array' or jsonb_array_length(p_wraps) > 100 then
    raise exception 'bad_wraps' using errcode = '22023';
  end if;
  return jsonb_build_object('ok', true, 'results',
    private.store_wraps(p_family, p_key_version, private.session_device(), p_wraps, false));
end;
$$;

-- Service role (publish-head): the session's phone and its signing key.
create or replace function public.session_device_key(p_user uuid, p_session uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object('device_id', d.id, 'sig', private.b64(d.signing_public_key))
  from public.devices d where d.id = private.approved_bound_device(p_user, p_session);
$$;

-- Service role (publish-head, after checking the beacon's signature with the
-- session phone's key over "usra/v1/head" || 0x00 || beacon): keeps the
-- newest beacon per device. The beacon must name this phone and a (seq, hash)
-- on the server's log.
create or replace function public.publish_family_head(
  p_user uuid, p_session uuid, p_family uuid, p_beacon bytea, p_sig bytea
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_device uuid := private.approved_bound_device(p_user, p_session);
  v_beacon jsonb := private.strict_json(p_beacon, 1024);
  v_seq bigint;
  v_hash bytea;
begin
  if v_device is null then
    raise exception 'approved_device_required' using errcode = '42501';
  end if;
  perform 1 from public.family_devices fd
  join public.family_members m on m.family_id = fd.family_id and m.user_id = fd.user_id
  where fd.family_id = p_family and fd.device_id = v_device and fd.revoked_seq is null
    and m.status = 'active';
  if not found then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  v_seq := private.jint(v_beacon, 'seq');
  if v_beacon is null or p_sig is null or octet_length(p_sig) <> 64
     or private.jkeys(v_beacon) <> array['at', 'device', 'family', 'h', 'seq', 'v']
     or v_beacon -> 'v' is distinct from '1'::jsonb
     or private.jstr(v_beacon, 'family') is distinct from p_family::text
     or private.jstr(v_beacon, 'device') is distinct from v_device::text
     or coalesce(private.jstr(v_beacon, 'at'), '') !~ '^[0-9a-f]{16}$'
     or v_seq is null or v_seq < 1 or v_seq > 2147483647 then
    raise exception 'bad_beacon' using errcode = '22023';
  end if;
  select hash into v_hash from public.family_log where family_id = p_family and seq = v_seq;
  if v_hash is null or private.unb64url(private.jstr(v_beacon, 'h')) is distinct from v_hash then
    return jsonb_build_object('ok', false, 'error', 'not_on_log');
  end if;
  insert into public.family_heads (family_id, device_id, seq, head_hash, beacon, sig)
  values (p_family, v_device, v_seq, v_hash, p_beacon, p_sig)
  on conflict (family_id, device_id) do update
    set seq = excluded.seq, head_hash = excluded.head_hash, beacon = excluded.beacon,
        sig = excluded.sig, updated_at = now()
    where public.family_heads.seq <= excluded.seq;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'stale_beacon');
  end if;
  return jsonb_build_object('ok', true, 'seq', v_seq);
end;
$$;

-- ---------------------------------------------------------------------------
-- 10. Record pushes need a current device of the family (B0's function, plus
--     the family_device_ok check)
-- ---------------------------------------------------------------------------
create or replace function public.push_e2ee_records(
  p_family    uuid,
  p_log_seq   integer,
  p_records   jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_family    public.families%rowtype;
  v_head      integer;
  v_rec       jsonb;
  v_sync      uuid;
  v_kv        integer;
  v_ct        bytea;
  v_deleted   boolean;
  v_expected  bigint;
  v_revision  bigint;
  v_total     bigint := 0;
  v_cur       public.e2ee_records%rowtype;
  v_results   jsonb := '[]'::jsonb;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  if not private.device_ok() then
    raise exception 'approved_device_required' using errcode = '42501';
  end if;
  if coalesce(private.family_role(p_family), '') not in ('owner', 'guardian') then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if not private.family_device_ok(p_family) then
    raise exception 'device_not_in_family' using errcode = '42501';
  end if;
  select * into v_family from public.families where id = p_family for share;
  if jsonb_typeof(p_records) is distinct from 'array'
     or jsonb_array_length(p_records) not between 1 and 100 then
    raise exception 'bad_batch' using errcode = '22023';
  end if;

  select max(l.seq) into v_head from public.family_log l where l.family_id = p_family;
  if v_head is null then
    return jsonb_build_object('ok', false, 'error', 'no_log');
  end if;
  if p_log_seq is distinct from v_head then
    return jsonb_build_object('ok', false, 'error', 'stale_log', 'head_seq', v_head);
  end if;
  if v_family.rotation_pending then
    return jsonb_build_object('ok', false, 'error', 'rotation_pending', 'head_seq', v_head);
  end if;

  for v_rec in select value from jsonb_array_elements(p_records) loop
    v_sync := (v_rec ->> 'sync_id')::uuid;
    v_kv := (v_rec ->> 'key_version')::integer;
    v_ct := decode(v_rec ->> 'ciphertext', 'base64');
    v_deleted := coalesce((v_rec ->> 'deleted')::boolean, false);
    v_expected := (v_rec ->> 'expected_revision')::bigint;
    if v_sync is null or v_kv is null or v_ct is null or v_expected is null or v_expected < 0 then
      raise exception 'bad_record' using errcode = '22023';
    end if;
    v_total := v_total + octet_length(v_ct);
    if v_total > 2097152 then
      raise exception 'batch_too_large' using errcode = '22023';
    end if;

    if v_kv <> v_family.current_key_version then
      v_results := v_results || jsonb_build_object(
        'sync_id', v_sync, 'ok', false, 'error', 'stale_key',
        'current_key_version', v_family.current_key_version);
      continue;
    end if;

    if v_expected = 0 then
      insert into public.e2ee_records (family_id, sync_id, key_version, ciphertext, deleted_at)
      values (p_family, v_sync, v_kv, v_ct, case when v_deleted then now() end)
      on conflict (family_id, sync_id) do nothing
      returning revision into v_revision;
    else
      update public.e2ee_records r
         set key_version = v_kv,
             ciphertext = v_ct,
             deleted_at = case when v_deleted then coalesce(r.deleted_at, now()) end,
             revision = r.revision + 1
       where r.family_id = p_family and r.sync_id = v_sync and r.revision = v_expected
      returning r.revision into v_revision;
    end if;

    if found then
      v_results := v_results || jsonb_build_object('sync_id', v_sync, 'ok', true, 'revision', v_revision);
    else
      select * into v_cur from public.e2ee_records r
      where r.family_id = p_family and r.sync_id = v_sync;
      v_results := v_results || jsonb_build_object(
        'sync_id', v_sync, 'ok', false, 'error', 'revision_conflict',
        'current', case when found then jsonb_build_object(
          'revision', v_cur.revision, 'key_version', v_cur.key_version,
          'ciphertext', private.b64(v_cur.ciphertext),
          'deleted', v_cur.deleted_at is not null) end);
    end if;
  end loop;

  return jsonb_build_object('ok', true, 'head_seq', v_head, 'results', v_results);
end;
$$;

-- ---------------------------------------------------------------------------
-- 11. Housekeeping (pg_cron, every 15 minutes)
-- ---------------------------------------------------------------------------
create or replace function public.sync_housekeeping()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.complete_account_resets();
  -- Recovery tries are counted per day, so challenges are kept two days.
  delete from public.device_challenges where created_at < now() - interval '2 days';
  delete from public.pairing_sessions where expires_at < now() - interval '1 day';
  delete from public.pairing_bundles where created_at < now() - interval '1 day';
  delete from public.invite_accept_attempts where created_at < now() - interval '1 day';
  -- Pending phones nobody approved within a week (left by older sessions).
  delete from public.devices d
  where d.status = 'pending' and d.created_at < now() - interval '7 days'
    and not exists (select 1 from public.account_resets r
                    where r.started_device = d.id and r.cancelled_at is null);
end;
$$;

select cron.schedule('sync-housekeeping', '*/15 * * * *', 'select public.sync_housekeeping()');

-- ---------------------------------------------------------------------------
-- 12. Function privileges
-- ---------------------------------------------------------------------------
revoke execute on all functions in schema private from public, anon, authenticated;
grant execute on function private.family_role(uuid) to authenticated, service_role;
grant execute on function private.jwt_session_id() to authenticated, service_role;
grant execute on function private.device_ok() to authenticated, service_role;
grant execute on function private.session_device() to authenticated, service_role;
grant execute on function private.is_session_device(uuid) to authenticated, service_role;
grant execute on function private.family_device_ok(uuid) to authenticated, service_role;

-- Service role only: each trusts a signature its Edge Function checked, or
-- runs from pg_cron.
do $$
declare
  f text;
begin
  foreach f in array array[
    'public.bind_device_session(uuid, uuid, uuid)',
    'public.approve_device(uuid, uuid)',
    'public.revoke_device(uuid)',
    'public.append_family_log(uuid, integer, bytea, bytea, bytea, bytea, jsonb)',
    'public.append_family_log_as(uuid, uuid, uuid, integer, bytea, bytea, bytea, bytea, jsonb)',
    'public.take_device_challenge(uuid, uuid, text, uuid, bytea)',
    'public.bind_device_signed(uuid, uuid, uuid, boolean)',
    'public.approve_device_signed(uuid, uuid, uuid, uuid, bytea, uuid)',
    'public.recover_device_signed(uuid, uuid, uuid, uuid)',
    'public.device_signing_key(uuid)',
    'public.session_device_key(uuid, uuid)',
    'public.publish_family_head(uuid, uuid, uuid, bytea, bytea)',
    'public.complete_account_resets()',
    'public.sync_housekeeping()'
  ] loop
    execute format('revoke execute on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;

  -- Signed-in users; each checks the session, device and role itself.
  foreach f in array array[
    'public.issue_device_challenge(text, uuid)',
    'public.set_account_recovery(bytea, jsonb, bytea, bytea)',
    'public.pairing_start(uuid, bytea)',
    'public.pairing_respond(uuid, bytea)',
    'public.pairing_reveal(uuid, bytea)',
    'public.pairing_cancel(uuid)',
    'public.accept_family_invite(text, jsonb, bytea)',
    'public.pending_family_invites(uuid)',
    'public.start_account_reset(uuid)',
    'public.cancel_account_reset(uuid)',
    'public.put_family_key_wraps(uuid, integer, jsonb)',
    'public.revoke_own_device(uuid)'
  ] loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end;
$$;
