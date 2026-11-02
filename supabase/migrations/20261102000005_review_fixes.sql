-- Usra: fixes from the PR #2 review (schema not yet deployed anywhere).
--
-- 1. A purchase for an account that doesn't exist yet is no longer marked
--    processed, so RevenueCat's retry can apply it later.
-- 2. reservation_status() lets ai-doctor tell a paid-and-finished request from
--    one still running, so a network retry is not charged twice or lost.
-- 3. Stale credit holds are released every 5 minutes (pg_cron).
-- 4. ai_runs can record a failed commit and a free retry.
-- 5. Encrypted-record sync uses a commit-safe change cursor.
-- 6. Cloud OCR: database-backed burst limit, and a failed read gives its
--    quota back.
-- 7. Family membership only through an invite the person accepts.

-- ---------------------------------------------------------------------------
-- 1. apply_purchase_event: check the user before recording the event
-- ---------------------------------------------------------------------------
create or replace function public.apply_purchase_event(
  p_event_id            text,
  p_event_type          text,
  p_user                uuid,
  p_event_at            timestamptz,
  p_credit_delta        integer default 0,
  p_credit_kind         text default null,
  p_entitlement         text default null,
  p_entitlement_active  boolean default null,
  p_expires_at          timestamptz default null,
  p_product_id          text default null,
  p_store               text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_delta integer := coalesce(p_credit_delta, 0);
  v_balance integer;
begin
  -- Raise (nothing is recorded) so the webhook answers 5xx and RevenueCat
  -- retries; the account may simply not exist yet.
  if p_user is null or not exists (select 1 from public.accounts where id = p_user) then
    raise exception 'unknown_user' using errcode = 'P0002';
  end if;

  insert into public.purchase_events (event_id, event_type, user_id, outcome)
  values (p_event_id, p_event_type, p_user, 'processing')
  on conflict (event_id) do nothing;
  if not found then
    return jsonb_build_object('applied', false, 'duplicate', true);
  end if;

  perform private.lock_account(p_user);

  if v_delta <> 0 then
    if v_delta < 0 then
      -- A store refund can only take back what is left; never go negative.
      v_balance := private.balance_of(p_user);
      v_delta := -least(-v_delta, greatest(v_balance, 0));
    end if;
    if v_delta <> 0 or p_credit_kind = 'store_refund' then
      insert into public.credits_ledger (user_id, delta, kind, source, source_event_id)
      values (p_user, v_delta, p_credit_kind, 'revenuecat', p_event_id);
    end if;
  end if;

  if p_entitlement is not null then
    insert into public.entitlements as e
      (user_id, entitlement, active, product_id, store, expires_at, event_at)
    values (p_user, p_entitlement, coalesce(p_entitlement_active, false),
            p_product_id, p_store, p_expires_at, p_event_at)
    on conflict (user_id, entitlement) do update
      set active = excluded.active,
          product_id = coalesce(excluded.product_id, e.product_id),
          store = coalesce(excluded.store, e.store),
          expires_at = excluded.expires_at,
          event_at = excluded.event_at,
          updated_at = now()
      where e.event_at <= excluded.event_at;   -- ignore out-of-order older events
  end if;

  update public.purchase_events set outcome = 'applied' where event_id = p_event_id;
  return jsonb_build_object('applied', true, 'credit_delta', v_delta,
                            'balance', private.balance_of(p_user));
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. reservation_status: 'reserved' | 'commit' | 'refund' | 'unknown'
--    ('unknown' also when the reservation belongs to someone else)
-- ---------------------------------------------------------------------------
create or replace function public.reservation_status(p_user uuid, p_reservation_id uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select s.kind from public.credits_ledger s
      where s.reservation_id = p_reservation_id and s.user_id = p_user
        and s.kind in ('commit', 'refund')),
    (select 'reserved' from public.credits_ledger r
      where r.reservation_id = p_reservation_id and r.user_id = p_user
        and r.kind = 'reserve'),
    'unknown');
$$;

revoke execute on function public.reservation_status(uuid, uuid) from public, anon, authenticated;
grant execute on function public.reservation_status(uuid, uuid) to service_role;

-- ---------------------------------------------------------------------------
-- 3. Release credit holds left by a function that died mid-run
-- ---------------------------------------------------------------------------
create extension if not exists pg_cron with schema pg_catalog;

select cron.schedule(
  'usra-expire-stale-credit-holds',
  '*/5 * * * *',
  $$ select public.expire_stale_reservations(); $$
);

-- ---------------------------------------------------------------------------
-- 4. ai_runs statuses
-- ---------------------------------------------------------------------------
alter table public.ai_runs drop constraint ai_runs_status_check;
alter table public.ai_runs add constraint ai_runs_status_check
  check (status in ('ok', 'provider_error', 'invalid_output', 'commit_failed', 'free_retry'));

-- ---------------------------------------------------------------------------
-- 5. Commit-safe sync cursor for e2ee_records
--
-- Each write stores its transaction id. A pull returns only rows from
-- transactions that finished before the pull's snapshot (txid below the
-- snapshot's xmin), ordered by (change_txid, record_id). A transaction that
-- commits late can never land behind a cursor a phone has already stored.
-- ---------------------------------------------------------------------------
alter table public.e2ee_records
  add column change_txid xid8 not null default pg_current_xact_id();

create index e2ee_records_change_idx
  on public.e2ee_records (family_id, change_txid, record_id);

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
    new.record_id := old.record_id;
  end if;
  return new;
end;
$$;

create or replace function public.pull_e2ee_changes(
  p_family       uuid,
  p_after_txid   xid8 default '0',
  p_after_record uuid default null,
  p_limit        integer default 500
)
returns table (
  record_id    uuid,
  key_version  integer,
  ciphertext   bytea,
  updated_at   timestamptz,
  deleted_at   timestamptz,
  change_txid  xid8
)
language sql
stable
security invoker   -- row-level security decides what the caller may read
set search_path = ''
as $$
  select r.record_id, r.key_version, r.ciphertext, r.updated_at, r.deleted_at, r.change_txid
  from public.e2ee_records r
  where r.family_id = p_family
    and r.change_txid < pg_snapshot_xmin(pg_current_snapshot())
    and (r.change_txid > p_after_txid
         or (r.change_txid = p_after_txid and p_after_record is not null
             and r.record_id > p_after_record))
  order by r.change_txid, r.record_id
  limit least(greatest(coalesce(p_limit, 500), 1), 1000);
$$;

revoke execute on function public.pull_e2ee_changes(uuid, xid8, uuid, integer) from public, anon;
grant execute on function public.pull_e2ee_changes(uuid, xid8, uuid, integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Cloud OCR quota: burst limit in the database + give back on failure
-- ---------------------------------------------------------------------------
drop function public.consume_ocr_quota(uuid, integer, interval);

create function public.consume_ocr_quota(
  p_user          uuid,
  p_limit         integer default 20,
  p_window        interval default interval '30 days',
  p_burst         integer default 5,
  p_burst_window  interval default interval '1 minute'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_used integer;
  v_recent integer;
  v_oldest timestamptz;
  v_id bigint;
begin
  perform private.lock_account(p_user);

  select count(*), min(created_at),
         count(*) filter (where created_at > now() - p_burst_window)
    into v_used, v_oldest, v_recent
  from public.ocr_requests
  where user_id = p_user and created_at > now() - p_window;

  if v_recent >= p_burst then
    return jsonb_build_object('allowed', false, 'reason', 'burst', 'used', v_used,
                              'limit', p_limit);
  end if;
  if v_used >= p_limit then
    return jsonb_build_object('allowed', false, 'reason', 'quota', 'used', v_used,
                              'limit', p_limit, 'resets_at', v_oldest + p_window);
  end if;

  insert into public.ocr_requests (user_id) values (p_user) returning id into v_id;
  return jsonb_build_object('allowed', true, 'used', v_used + 1, 'limit', p_limit,
                            'request_id', v_id);
end;
$$;

-- Gives a quota slot back when the cloud read failed.
create or replace function public.release_ocr_quota(p_user uuid, p_request_id bigint)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.ocr_requests where id = p_request_id and user_id = p_user;
  return found;
end;
$$;

revoke execute on function public.consume_ocr_quota(uuid, integer, interval, integer, interval)
  from public, anon, authenticated;
grant execute on function public.consume_ocr_quota(uuid, integer, interval, integer, interval)
  to service_role;
revoke execute on function public.release_ocr_quota(uuid, bigint) from public, anon, authenticated;
grant execute on function public.release_ocr_quota(uuid, bigint) to service_role;

-- ---------------------------------------------------------------------------
-- 7. Family invites: nobody is added to a family without accepting
-- ---------------------------------------------------------------------------
drop policy family_members_insert_owner on public.family_members;
revoke insert on public.family_members from authenticated;

create table public.family_invites (
  id           uuid primary key default gen_random_uuid(),
  family_id    uuid not null references public.families (id) on delete cascade,
  role         text not null check (role in ('guardian', 'cared_for', 'viewer')),
  -- sha256 (hex) of the one-time code shared by QR or link; the code itself is never stored
  code_hash    text not null unique check (code_hash ~ '^[0-9a-f]{64}$'),
  created_by   uuid not null references public.accounts (id) on delete cascade,
  created_at   timestamptz not null default now(),
  expires_at   timestamptz not null default now() + interval '7 days',
  accepted_by  uuid references public.accounts (id) on delete set null,
  accepted_at  timestamptz
);

create index family_invites_family_idx on public.family_invites (family_id);

alter table public.family_invites enable row level security;

create policy family_invites_select_owner on public.family_invites
  for select to authenticated using (private.family_role(family_id) = 'owner');
create policy family_invites_insert_owner on public.family_invites
  for insert to authenticated
  with check (private.family_role(family_id) = 'owner' and created_by = (select auth.uid()));
create policy family_invites_delete_owner on public.family_invites
  for delete to authenticated using (private.family_role(family_id) = 'owner');

grant select, delete on public.family_invites to authenticated;
grant insert (family_id, role, code_hash, created_by, expires_at) on public.family_invites to authenticated;

-- Called by the invited person with the code from the QR or link.
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

  select * into v_invite from public.family_invites
  where code_hash = encode(sha256(convert_to(coalesce(p_code, ''), 'UTF8')), 'hex')
    and accepted_at is null and expires_at > now()
  for update;
  if not found then
    raise exception 'invalid_invite' using errcode = 'P0002';
  end if;

  insert into public.family_members (family_id, user_id, role)
  values (v_invite.family_id, v_user, v_invite.role)
  on conflict (family_id, user_id) do nothing;

  update public.family_invites
     set accepted_by = v_user, accepted_at = now()
   where id = v_invite.id;

  return v_invite.family_id;
end;
$$;

revoke execute on function public.accept_family_invite(text) from public, anon;
grant execute on function public.accept_family_invite(text) to authenticated;
