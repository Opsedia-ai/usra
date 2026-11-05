-- Usra: sync backend blockers (B0.1–B0.7 in docs/sync-design.md, section 20).
--
-- Closes the grant and RLS gaps found in the S14 review before any sync code
-- is written. Nothing is deployed yet, so tables change in place.
--
-- The model, from the design:
-- * A session counts for sync only when it is bound to an approved device
--   (`device_sessions`, `private.device_ok()`). A session that has only proved
--   an SMS code reads and writes no ciphertext or log, and can't touch other
--   devices, push tokens, families, members or invites.
-- * Device keys never change after insert; a new key is a new device row.
--   Trust fields (`status`, `approved_*`, `revoked_at`) change only inside
--   `approve_device` / `revoke_device`.
-- * Membership changes only through the family log (`append_family_log`,
--   compare-and-set on the log head). Records only through `push_e2ee_records`
--   (log head + per-record revision compare-and-set). Invites and family
--   deletion only through functions that need an approved device.
-- * Ed25519 can't be checked in Postgres, so every function that trusts a
--   signature (binding a session, approving a device, appending to the log)
--   is service-role only: its Edge Function (B2, B3, B5) verifies the
--   signature first and then calls it.

-- ---------------------------------------------------------------------------
-- 0. Helpers
-- ---------------------------------------------------------------------------

-- The Auth session id from the JWT (stable across token refreshes).
create or replace function private.jwt_session_id()
returns uuid
language plpgsql
stable
set search_path = ''
as $$
begin
  return nullif(auth.jwt() ->> 'session_id', '')::uuid;
exception when invalid_text_representation then
  return null;
end;
$$;

-- Unpadded base64url, as used inside log entries.
create or replace function private.b64url(p bytea)
returns text
language sql
immutable
set search_path = ''
as $$ select rtrim(translate(encode(p, 'base64'), E'+/\n', '-_'), '='); $$;

-- Standard base64 without line breaks, for jsonb replies.
create or replace function private.b64(p bytea)
returns text
language sql
immutable
set search_path = ''
as $$ select replace(encode(p, 'base64'), E'\n', ''); $$;

-- ---------------------------------------------------------------------------
-- 1. devices: immutable keys, trust only through functions (B0.1, B0.2)
-- ---------------------------------------------------------------------------
alter table public.accounts add column sync_enrolled_at timestamptz;
comment on column public.accounts.sync_enrolled_at is
  'Set when the first device self-approved. After that no device can self-approve, even if every device row is gone.';

alter table public.devices drop constraint devices_public_key_check;
alter table public.devices
  add constraint devices_public_key_check
    check (public_key is null or octet_length(public_key) = 32),   -- X25519
  add column signing_public_key bytea
    constraint devices_signing_public_key_check
    check (signing_public_key is null or octet_length(signing_public_key) = 32),  -- Ed25519
  add column status text not null default 'pending'
    constraint devices_status_check check (status in ('pending', 'approved', 'revoked')),
  add column approved_at timestamptz,
  add column approved_by_device uuid,          -- no FK: ids are never reused, keep the trail
  add column revoked_at timestamptz,
  -- The Auth session that registered the row: before a session is bound, it may
  -- write push tokens only for devices it registered itself (B0.3).
  add column created_session_id uuid default private.jwt_session_id(),
  add constraint devices_status_shape check (
    (status = 'pending' and approved_at is null and revoked_at is null)
    or (status = 'approved' and approved_at is not null and revoked_at is null)
    or (status = 'revoked' and revoked_at is not null));
alter table public.devices alter column user_id set default auth.uid();

create or replace function private.devices_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    -- Every device starts pending, whoever inserts it.
    new.status := 'pending';
    new.approved_at := null;
    new.approved_by_device := null;
    new.revoked_at := null;
    return new;
  end if;

  if new.id <> old.id or new.user_id <> old.user_id or new.platform <> old.platform
     or new.created_at <> old.created_at
     or new.created_session_id is distinct from old.created_session_id then
    raise exception 'device_identity_immutable' using errcode = '42501';
  end if;
  -- A new key is a new device (B0.1), for every role including the service role.
  if new.public_key is distinct from old.public_key
     or new.signing_public_key is distinct from old.signing_public_key then
    raise exception 'device_keys_immutable' using errcode = '42501';
  end if;
  if (new.status, new.approved_at, new.approved_by_device, new.revoked_at)
     is distinct from (old.status, old.approved_at, old.approved_by_device, old.revoked_at) then
    -- Only inside approve_device / revoke_device, which run as their owner.
    -- The API roles, the service role included, can't change these directly.
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

create trigger devices_guard before insert or update on public.devices
  for each row execute function private.devices_guard();

-- device_sessions: Auth session -> device, written by bind-device (B2) only.
create table public.device_sessions (
  session_id  uuid primary key,
  device_id   uuid not null references public.devices (id) on delete cascade,
  user_id     uuid not null references public.accounts (id) on delete cascade,
  bound_at    timestamptz not null default now()
);

create index device_sessions_device_idx on public.device_sessions (device_id);

alter table public.device_sessions enable row level security;
-- No policies and no grants: only the service role reads or writes it.

-- The device this session is bound to (not revoked), or null.
create or replace function private.session_device()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select s.device_id
  from public.device_sessions s
  join public.devices d on d.id = s.device_id
  where s.session_id = private.jwt_session_id()
    and s.user_id = auth.uid()
    and d.user_id = auth.uid()
    and d.status <> 'revoked';
$$;

-- True only for a session bound to an approved device of the caller.
create or replace function private.device_ok()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.device_sessions s
    join public.devices d on d.id = s.device_id
    where s.session_id = private.jwt_session_id()
      and s.user_id = auth.uid()
      and d.user_id = auth.uid()
      and d.status = 'approved');
$$;

-- Is p_device "this session's own device"? A bound session: only the bound
-- device. A session not bound yet: only device rows it registered itself.
create or replace function private.is_session_device(p_device uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when exists (select 1 from public.device_sessions s
                 where s.session_id = private.jwt_session_id())
      then coalesce(p_device = private.session_device(), false)
    else exists (select 1 from public.devices d
                 where d.id = p_device
                   and d.user_id = auth.uid()
                   and d.created_session_id = private.jwt_session_id()
                   and d.status <> 'revoked')
  end;
$$;

-- Policies: write only this session's own device; delete others only from an
-- approved device (B10 adds "revoke instead of delete" once sync is on).
drop policy devices_insert_own on public.devices;
drop policy devices_update_own on public.devices;
drop policy devices_delete_own on public.devices;

create policy devices_insert_own on public.devices
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy devices_update_own on public.devices
  for update to authenticated
  using (user_id = (select auth.uid()) and private.is_session_device(id))
  with check (user_id = (select auth.uid()));
create policy devices_delete_own on public.devices
  for delete to authenticated
  using (user_id = (select auth.uid())
         and (private.is_session_device(id) or (select private.device_ok())));

revoke insert, update on public.devices from authenticated;
grant insert (user_id, platform, app_version, public_key, signing_public_key)
  on public.devices to authenticated;
grant update (app_version, last_seen_at) on public.devices to authenticated;

-- Service role: called by bind-device (B2) after checking the device's
-- signature over the session id and a server nonce.
create or replace function public.bind_device_session(p_user uuid, p_session uuid, p_device uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_bound uuid;
begin
  perform 1 from public.devices
  where id = p_device and user_id = p_user and status <> 'revoked';
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
end;
$$;

-- Service role: called by approve-device / recover-device (B3) after checking
-- the approving device's signature. p_approved_by null = the account's very
-- first device approving itself, allowed once per account, ever.
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
  if v_device.status <> 'pending' then
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

-- Service role (and append_family_log): revoked is final. Unbinds its
-- sessions, drops its push tokens and flags a key rotation in its user's
-- families. (Hard delete of other devices from an approved device: B10.)
create or replace function public.revoke_device(p_device uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
  v_user uuid;
begin
  select status, user_id into v_status, v_user from public.devices where id = p_device for update;
  if not found then
    raise exception 'unknown_device' using errcode = 'P0002';
  end if;
  if v_status <> 'revoked' then
    update public.devices set status = 'revoked', revoked_at = now() where id = p_device;
  end if;
  -- An approved device may hold family keys: every family of its user must
  -- rotate before anyone writes again.
  if v_status = 'approved' then
    update public.families f set rotation_pending = true
    where exists (select 1 from public.family_members m
                  where m.family_id = f.id and m.user_id = v_user);
  end if;
  delete from public.device_sessions where device_id = p_device;
  delete from public.push_tokens where device_id = p_device;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. push_tokens: only this session's own device (B0.3)
-- ---------------------------------------------------------------------------
drop policy push_tokens_select_own on public.push_tokens;
drop policy push_tokens_insert_own on public.push_tokens;
drop policy push_tokens_update_own on public.push_tokens;
drop policy push_tokens_delete_own on public.push_tokens;

alter table public.push_tokens alter column user_id set default auth.uid();

create policy push_tokens_select_own on public.push_tokens
  for select to authenticated
  using (user_id = (select auth.uid()) and private.is_session_device(device_id));
create policy push_tokens_insert_own on public.push_tokens
  for insert to authenticated
  with check (user_id = (select auth.uid()) and private.is_session_device(device_id));
create policy push_tokens_update_own on public.push_tokens
  for update to authenticated
  using (user_id = (select auth.uid()) and private.is_session_device(device_id))
  with check (user_id = (select auth.uid()) and private.is_session_device(device_id));
create policy push_tokens_delete_own on public.push_tokens
  for delete to authenticated
  using (user_id = (select auth.uid()) and private.is_session_device(device_id));

revoke insert on public.push_tokens from authenticated;
grant insert (user_id, device_id, provider, token) on public.push_tokens to authenticated;

-- ---------------------------------------------------------------------------
-- 3. families: deletion through a function; creator's account delete no
--    longer cascades (B0.4, B0.7). Key epoch state mirrored from the log.
-- ---------------------------------------------------------------------------
alter table public.families drop constraint families_created_by_fkey;
alter table public.families alter column created_by drop not null;
alter table public.families
  add constraint families_created_by_fkey foreign key (created_by)
    references public.accounts (id) on delete set null,
  add column current_key_version integer not null default 1
    constraint families_key_version_check check (current_key_version > 0),
  add column rotation_pending boolean not null default false;

comment on column public.families.created_by is
  'Who created the family. Not the owner (see family_members.role); null once that account is deleted.';

drop policy families_insert_self on public.families;
drop policy families_delete_owner on public.families;

create policy families_insert_self on public.families
  for insert to authenticated
  with check (created_by = (select auth.uid()) and (select private.device_ok()));

revoke insert, delete on public.families from authenticated;
grant insert (created_by) on public.families to authenticated;

-- Any membership that goes (removal through the log, or the member's account
-- deleted) makes a key rotation pending. A family with no members left is
-- removed with its ciphertext. The owner can't leave or be removed, so a
-- family with other members always keeps an owner.
create or replace function private.family_drop_if_empty()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.families set rotation_pending = true where id = old.family_id;
  delete from public.families f
  where f.id = old.family_id
    and not exists (select 1 from public.family_members m where m.family_id = old.family_id);
  return null;
end;
$$;

-- The owner's row can't go while other members remain (an account delete
-- from the dashboard included): hand over first. Deleting the family itself
-- (its row is already gone when the cascade runs) is allowed.
create or replace function private.family_keep_owner()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.role = 'owner'
     and exists (select 1 from public.families f where f.id = old.family_id)
     and exists (select 1 from public.family_members m
                 where m.family_id = old.family_id and m.user_id <> old.user_id) then
    raise exception 'family_has_members' using errcode = '42501';
  end if;
  return old;
end;
$$;

create trigger family_members_keep_owner
  before delete on public.family_members
  for each row execute function private.family_keep_owner();

create trigger family_members_drop_empty
  after delete on public.family_members
  for each row execute function private.family_drop_if_empty();

create or replace function public.delete_family(p_family uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  if not private.device_ok() then
    raise exception 'approved_device_required' using errcode = '42501';
  end if;
  if private.family_role(p_family) is distinct from 'owner' then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  perform 1 from public.families where id = p_family for update;
  -- (B8 adds deleting the family's Storage objects.)
  delete from public.families where id = p_family;
end;
$$;

-- Keyed on the owner role, not the creator: after an ownership transfer the
-- creator can delete their account without taking the family with them.
create or replace function public.account_deletion_blockers(p_user uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::int
  from public.family_members o
  where o.user_id = p_user
    and o.role = 'owner'
    and exists (
      select 1 from public.family_members m
      where m.family_id = o.family_id and m.user_id <> p_user
    );
$$;

comment on function public.account_deletion_blockers(uuid) is
  'Families the user owns that have other members; the owner must hand over first.';

-- ---------------------------------------------------------------------------
-- 4. family_log: signed, hash-chained membership log; the only way to change
--    membership after creation (B0.5, sketch of B5)
-- ---------------------------------------------------------------------------
create table public.family_log (
  family_id      uuid not null references public.families (id) on delete cascade,
  seq            integer not null check (seq > 0),
  prev_hash      bytea check (prev_hash is null or octet_length(prev_hash) = 32),
  entry          bytea not null check (octet_length(entry) <= 16384),
  sig            bytea not null check (octet_length(sig) = 64),
  hash           bytea not null generated always as (sha256(entry)) stored,
  signer_device  uuid not null,
  created_at     timestamptz not null default now(),
  primary key (family_id, seq),
  constraint family_log_chain check ((seq = 1) = (prev_hash is null))
);

comment on table public.family_log is
  'Signed family log. Phones verify every entry; the server''s checks only keep its mirror tables tidy.';

alter table public.family_log enable row level security;

create policy family_log_select_member on public.family_log
  for select to authenticated
  using ((select private.device_ok()) and private.family_role(family_id) is not null);

grant select on public.family_log to authenticated;

-- Service role: called by append-family-log (B5) after it has checked the
-- Ed25519 signature and strict JSON. Appends only on top of the current head
-- (compare-and-set on seq and prev hash), checks who may write each entry
-- type against the server's mirror, and mirrors the entry into
-- family_members, devices and families in the same transaction.
create or replace function public.append_family_log(
  p_family     uuid,
  p_seq        integer,
  p_prev_hash  bytea,
  p_entry      bytea,
  p_sig        bytea
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entry       jsonb;
  v_type        text;
  v_family      public.families%rowtype;
  v_head_seq    integer;
  v_head_hash   bytea;
  v_signer      public.devices%rowtype;
  v_signer_role text;
  v_user        uuid;
  v_role        text;
  v_target_role text;
  v_device      uuid;
  v_invite      uuid;
begin
  if p_entry is null or octet_length(p_entry) > 16384
     or p_sig is null or octet_length(p_sig) <> 64 then
    raise exception 'bad_entry' using errcode = '22023';
  end if;
  v_entry := convert_from(p_entry, 'UTF8')::jsonb;
  if jsonb_typeof(v_entry) is distinct from 'object'
     or v_entry ->> 'v' is distinct from '1'
     or v_entry ->> 'family' is distinct from p_family::text
     or v_entry ->> 'seq' is distinct from p_seq::text
     or v_entry ->> 'prev' is distinct from private.b64url(p_prev_hash) then
    raise exception 'entry_mismatch' using errcode = '22023';
  end if;
  v_type := v_entry ->> 'type';

  -- Serialises appends and record pushes for this family.
  select * into v_family from public.families where id = p_family for update;
  if not found then
    raise exception 'unknown_family' using errcode = 'P0002';
  end if;

  select l.seq, l.hash into v_head_seq, v_head_hash
  from public.family_log l where l.family_id = p_family
  order by l.seq desc limit 1;
  if p_seq <> coalesce(v_head_seq, 0) + 1 or p_prev_hash is distinct from v_head_hash then
    return jsonb_build_object('ok', false, 'error', 'head_mismatch',
                              'head_seq', coalesce(v_head_seq, 0),
                              'head_hash', private.b64url(v_head_hash));
  end if;

  -- Locked so a concurrent revoke_device can't land between check and append.
  select * into v_signer from public.devices where id = (v_entry ->> 'by')::uuid for share;
  if not found or v_signer.status <> 'approved' then
    raise exception 'signer_not_approved' using errcode = '42501';
  end if;
  select m.role into v_signer_role from public.family_members m
  where m.family_id = p_family and m.user_id = v_signer.user_id;
  if v_signer_role is null then
    raise exception 'signer_not_member' using errcode = '42501';
  end if;

  if (v_type = 'genesis') <> (p_seq = 1) then
    raise exception 'genesis_first' using errcode = '22023';
  end if;

  case v_type
  when 'genesis' then
    if v_signer_role <> 'owner' then
      raise exception 'forbidden' using errcode = '42501';
    end if;

  when 'add_member', 'change_role' then
    v_user := (v_entry ->> 'user')::uuid;
    v_role := v_entry ->> 'role';
    if v_signer_role <> 'owner' then
      raise exception 'forbidden' using errcode = '42501';
    end if;
    if v_role is null or v_role not in ('guardian', 'cared_for', 'viewer')
       or v_user is null or v_user = v_signer.user_id then
      raise exception 'bad_role' using errcode = '22023';
    end if;
    if v_type = 'add_member' then
      -- Nobody joins without accepting an invite to this family: the entry
      -- names the invite, which that person accepted, for that role, and
      -- which is neither revoked nor used.
      v_invite := (v_entry ->> 'invite')::uuid;
      update public.family_invites i set used_at = now()
      where i.id = v_invite and i.family_id = p_family and i.accepted_by = v_user
        and i.accepted_at is not null and i.role = v_role
        and i.revoked_at is null and i.used_at is null;
      if not found then
        raise exception 'no_accepted_invite' using errcode = '42501';
      end if;
      insert into public.family_members (family_id, user_id, role)
      values (p_family, v_user, v_role)
      on conflict (family_id, user_id) do nothing;
      if not found then
        raise exception 'already_member' using errcode = '23505';
      end if;
    else
      update public.family_members set role = v_role
      where family_id = p_family and user_id = v_user;
      if not found then
        raise exception 'not_a_member' using errcode = 'P0002';
      end if;
    end if;

  when 'transfer_owner' then
    v_user := (v_entry ->> 'user')::uuid;
    if v_signer_role <> 'owner' then
      raise exception 'forbidden' using errcode = '42501';
    end if;
    if v_user is null or v_user = v_signer.user_id then
      raise exception 'bad_target' using errcode = '22023';
    end if;
    -- Demote first: one owner per family (family_members_one_owner).
    update public.family_members set role = 'guardian'
    where family_id = p_family and user_id = v_signer.user_id;
    update public.family_members set role = 'owner'
    where family_id = p_family and user_id = v_user;
    if not found then
      raise exception 'not_a_member' using errcode = 'P0002';
    end if;

  when 'remove_member' then
    v_user := (v_entry ->> 'user')::uuid;
    if v_user is null then
      raise exception 'bad_target' using errcode = '22023';
    end if;
    select m.role into v_target_role from public.family_members m
    where m.family_id = p_family and m.user_id = v_user;
    case v_entry ->> 'reason'
    when 'account_deleted' then
      -- Any member may record it (a person confirmed it on their phone), but
      -- only for an account that is really gone. Its membership row went with
      -- the account (and flagged the rotation), so there may be nothing left.
      if exists (select 1 from public.accounts a where a.id = v_user) then
        raise exception 'account_exists' using errcode = '42501';
      end if;
    when 'reset' then
      -- Needs account_resets (B3) to check that a reset really happened.
      raise exception 'reset_not_supported' using errcode = '0A000';
    when 'removed', 'left' then
      if v_target_role is null then
        raise exception 'not_a_member' using errcode = 'P0002';
      end if;
      if v_target_role = 'owner' then
        raise exception 'owner_cannot_be_removed' using errcode = '42501';
      end if;
      if (v_entry ->> 'reason' = 'removed' and v_signer_role <> 'owner')
         or (v_entry ->> 'reason' = 'left' and v_user <> v_signer.user_id) then
        raise exception 'forbidden' using errcode = '42501';
      end if;
    else
      raise exception 'bad_reason' using errcode = '22023';
    end case;
    -- (The membership delete trigger flags the rotation.)
    delete from public.family_members where family_id = p_family and user_id = v_user;

  when 'add_device', 'revoke_device' then
    v_user := (v_entry ->> 'user')::uuid;
    if v_user is distinct from v_signer.user_id
       and not (v_type = 'revoke_device' and v_signer_role = 'owner') then
      raise exception 'forbidden' using errcode = '42501';
    end if;
    if v_type = 'revoke_device' then
      v_device := (v_entry ->> 'device')::uuid;
      perform 1 from public.devices where id = v_device and user_id = v_user;
      if not found then
        raise exception 'unknown_device' using errcode = 'P0002';
      end if;
      -- A person's own revocation is final everywhere; an owner's only
      -- removes the device from this family's key (the rotation below).
      if v_user = v_signer.user_id then
        perform public.revoke_device(v_device);
      end if;
      update public.families set rotation_pending = true where id = p_family;
    end if;

  when 'rotate_key' then
    if v_entry ->> 'key_version' is distinct from (v_family.current_key_version + 1)::text then
      raise exception 'bad_key_version' using errcode = '22023';
    end if;
    update public.families
       set current_key_version = v_family.current_key_version + 1, rotation_pending = false
     where id = p_family;

  else
    raise exception 'unknown_entry_type' using errcode = '22023';
  end case;

  insert into public.family_log (family_id, seq, prev_hash, entry, sig, signer_device)
  values (p_family, p_seq, p_prev_hash, p_entry, p_sig, v_signer.id);

  return jsonb_build_object('ok', true, 'seq', p_seq, 'hash', private.b64url(sha256(p_entry)));
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. family_members, family_invites: no direct writes (B0.5)
-- ---------------------------------------------------------------------------
create unique index family_members_one_owner on public.family_members (family_id)
  where role = 'owner';

drop policy family_members_update_owner on public.family_members;
drop policy family_members_delete on public.family_members;
revoke insert, update, delete on public.family_members from authenticated;

alter table public.family_invites
  add column revoked_at timestamptz,
  add column used_at timestamptz;   -- set by the add_member entry that used it
comment on column public.family_invites.revoked_at is
  'Revoked invites are kept, so they still count towards the daily limit.';

drop policy family_invites_select_owner on public.family_invites;
drop policy family_invites_insert_owner on public.family_invites;
create policy family_invites_select_owner on public.family_invites
  for select to authenticated
  using ((select private.device_ok()) and private.family_role(family_id) = 'owner');
drop policy family_invites_delete_owner on public.family_invites;
revoke insert, delete on public.family_invites from authenticated;

create or replace function public.create_family_invite(
  p_family     uuid,
  p_role       text,
  p_code_hash  text,
  p_expires_at timestamptz default null
)
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
  if not private.device_ok() then
    raise exception 'approved_device_required' using errcode = '42501';
  end if;
  if private.family_role(p_family) is distinct from 'owner' then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  perform 1 from public.families where id = p_family for update;  -- serialises the limit
  if p_expires_at is not null
     and (p_expires_at <= now() or p_expires_at > now() + interval '7 days') then
    raise exception 'bad_expiry' using errcode = '22023';
  end if;
  if (select count(*) from public.family_invites
      where family_id = p_family and created_at > now() - interval '1 day') >= 20 then
    raise exception 'too_many_invites' using errcode = '54000';
  end if;

  insert into public.family_invites (family_id, role, code_hash, created_by, expires_at)
  values (p_family, p_role, p_code_hash, v_user,
          coalesce(p_expires_at, now() + interval '7 days'))
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.revoke_family_invite(p_invite uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_family uuid;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  if not private.device_ok() then
    raise exception 'approved_device_required' using errcode = '42501';
  end if;
  select family_id into v_family from public.family_invites where id = p_invite;
  if not found or private.family_role(v_family) is distinct from 'owner' then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  update public.family_invites set revoked_at = now()
  where id = p_invite and revoked_at is null;
end;
$$;

-- Accepting needs an approved device (B10) and only marks the invite
-- accepted: the person becomes a member when the owner's phone appends a
-- signed add_member entry naming this invite. (B9 replaces the code with a
-- lookup hash and adds the invitee's key upload.)
create or replace function public.accept_family_invite(p_code text)
returns uuid
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

  select * into v_invite from public.family_invites
  where code_hash = encode(sha256(convert_to(coalesce(p_code, ''), 'UTF8')), 'hex')
    and accepted_at is null and revoked_at is null and expires_at > now()
  for update;
  if not found then
    raise exception 'invalid_invite' using errcode = 'P0002';
  end if;

  update public.family_invites
     set accepted_by = v_user, accepted_at = now()
   where id = v_invite.id;

  return v_invite.family_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. e2ee_records: random sync ids, required padded ciphertext, revisions,
--    writes only through push_e2ee_records (B0.6, and the table half of B7)
-- ---------------------------------------------------------------------------
drop function public.pull_e2ee_changes(uuid, xid8, uuid, integer);
drop policy e2ee_select_member on public.e2ee_records;
drop policy e2ee_insert_writer on public.e2ee_records;
drop policy e2ee_update_writer on public.e2ee_records;
revoke insert, update on public.e2ee_records from authenticated;

drop index public.e2ee_records_pull_idx;  -- pulls page by change_txid
alter table public.e2ee_records rename column record_id to sync_id;
alter table public.e2ee_records drop constraint e2ee_tombstone;
alter table public.e2ee_records drop constraint e2ee_records_ciphertext_check;
alter table public.e2ee_records alter column ciphertext set not null;
alter table public.e2ee_records
  add column revision bigint not null default 1 constraint e2ee_revision_check check (revision > 0),
  add column format smallint not null default 1 constraint e2ee_format_check check (format = 1),
  -- Signed tombstones keep their ciphertext. Plaintext is padded to a power
  -- of two from 256 B to 64 KiB; +40 = 24-byte nonce + 16-byte tag.
  add constraint e2ee_padded check (
    octet_length(ciphertext) - 40 between 256 and 65536
    and ((octet_length(ciphertext) - 40) & (octet_length(ciphertext) - 41)) = 0),
  -- The server id is a random UUID v4, never the phone's time-ordered v7.
  add constraint e2ee_sync_id_v4 check (
    substr(sync_id::text, 15, 1) = '4' and substr(sync_id::text, 20, 1) in ('8', '9', 'a', 'b'));

comment on table public.e2ee_records is
  'Ciphertext only, under a random sync id. Written only through push_e2ee_records.';

create or replace function private.e2ee_stamp()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := clock_timestamp();
  new.change_txid := pg_current_xact_id();
  if tg_op = 'UPDATE' then
    new.family_id := old.family_id;
    new.sync_id := old.sync_id;
  end if;
  return new;
end;
$$;

create policy e2ee_select_member on public.e2ee_records
  for select to authenticated
  using ((select private.device_ok()) and private.family_role(family_id) is not null);

-- Writes a batch of records for one family. Refuses the whole batch unless
-- the writer's log head is the server's head (so it has seen every removal
-- and rotation) and no rotation is pending; then, per record, writes only
-- under the current key version and only if the stored revision is the one
-- the writer merged (0 = new). Honest-server checks: readers verify
-- signatures and clocks themselves.
--
-- p_records: [{ "sync_id": uuid v4, "key_version": int, "ciphertext": base64,
--               "deleted": bool, "expected_revision": int }]
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
  -- Shares the family row with other pushes; waits for a log append.
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
    -- Bad sizes and non-v4 ids fail the table's checks (23514): a client bug.

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

create function public.pull_e2ee_changes(
  p_family      uuid,
  p_after_txid  xid8 default '0',
  p_after_sync  uuid default null,
  p_limit       integer default 500
)
returns table (
  sync_id      uuid,
  revision     bigint,
  key_version  integer,
  ciphertext   bytea,
  deleted_at   timestamptz,
  change_txid  xid8
)
language sql
stable
security invoker   -- row-level security decides what the caller may read
set search_path = ''
as $$
  select r.sync_id, r.revision, r.key_version, r.ciphertext, r.deleted_at, r.change_txid
  from public.e2ee_records r
  where r.family_id = p_family
    and r.change_txid < pg_snapshot_xmin(pg_current_snapshot())
    and (r.change_txid > p_after_txid
         or (r.change_txid = p_after_txid and p_after_sync is not null
             and r.sync_id > p_after_sync))
  order by r.change_txid, r.sync_id
  limit least(greatest(coalesce(p_limit, 500), 1), 1000);
$$;

-- ---------------------------------------------------------------------------
-- 7. Families and members are read only from an approved device too
-- ---------------------------------------------------------------------------
drop policy families_select_member on public.families;
create policy families_select_member on public.families
  for select to authenticated
  using ((select private.device_ok()) and private.family_role(id) is not null);
drop policy family_members_select on public.family_members;
create policy family_members_select on public.family_members
  for select to authenticated
  using ((select private.device_ok()) and private.family_role(family_id) is not null);

-- ---------------------------------------------------------------------------
-- 8. Function privileges
-- ---------------------------------------------------------------------------
revoke execute on all functions in schema private from public, anon, authenticated;
-- Used by RLS policies and column defaults evaluated as the caller.
grant execute on function private.family_role(uuid) to authenticated;
grant execute on function private.jwt_session_id() to authenticated;
grant execute on function private.device_ok() to authenticated;
grant execute on function private.is_session_device(uuid) to authenticated;
-- The service role inserts devices too (column default) and may call these.
grant execute on function private.jwt_session_id() to service_role;
grant execute on function private.device_ok() to service_role;
grant execute on function private.is_session_device(uuid) to service_role;
grant execute on function private.family_role(uuid) to service_role;

-- Service role only: each trusts a signature its Edge Function checked.
revoke execute on function public.bind_device_session(uuid, uuid, uuid) from public, anon, authenticated;
revoke execute on function public.approve_device(uuid, uuid) from public, anon, authenticated;
revoke execute on function public.revoke_device(uuid) from public, anon, authenticated;
revoke execute on function public.append_family_log(uuid, integer, bytea, bytea, bytea) from public, anon, authenticated;
grant execute on function public.bind_device_session(uuid, uuid, uuid) to service_role;
grant execute on function public.approve_device(uuid, uuid) to service_role;
grant execute on function public.revoke_device(uuid) to service_role;
grant execute on function public.append_family_log(uuid, integer, bytea, bytea, bytea) to service_role;

-- Signed-in users; each checks device_ok() and the role itself.
revoke execute on function public.delete_family(uuid) from public, anon;
revoke execute on function public.create_family_invite(uuid, text, text, timestamptz) from public, anon;
revoke execute on function public.revoke_family_invite(uuid) from public, anon;
revoke execute on function public.push_e2ee_records(uuid, integer, jsonb) from public, anon;
revoke execute on function public.pull_e2ee_changes(uuid, xid8, uuid, integer) from public, anon;
grant execute on function public.delete_family(uuid) to authenticated;
grant execute on function public.create_family_invite(uuid, text, text, timestamptz) to authenticated;
grant execute on function public.revoke_family_invite(uuid) to authenticated;
grant execute on function public.push_e2ee_records(uuid, integer, jsonb) to authenticated;
grant execute on function public.pull_e2ee_changes(uuid, xid8, uuid, integer) to authenticated;
