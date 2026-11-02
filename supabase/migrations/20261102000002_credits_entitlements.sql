-- Usra: AI credits (append-only ledger), entitlements and purchase events.
--
-- The balance is the sum of credits_ledger.delta for a user. Every change that
-- can lower the balance runs in a function that first locks the user's
-- accounts row, so concurrent runs are serialised and the balance can never go
-- below zero. A trigger re-checks this as a backstop.
--
-- An AI Doctor run is: reserve (delta -n) -> commit (delta 0) or refund (+n).
-- A reservation can be settled exactly once (unique index below).

create table public.credits_ledger (
  id               bigint generated always as identity primary key,
  user_id          uuid not null references public.accounts (id) on delete cascade,
  delta            integer not null,
  kind             text not null check (kind in (
                     'purchase',            -- consumable credit pack
                     'subscription_grant',  -- monthly Usra Plus credits
                     'reserve',             -- held for an AI run
                     'commit',              -- AI run succeeded; hold becomes final
                     'refund',              -- AI run failed; hold returned
                     'store_refund',        -- store refunded a credit pack
                     'adjustment'           -- support correction
                   )),
  reservation_id   uuid,
  source           text,          -- e.g. 'revenuecat', 'ai-doctor'
  source_event_id  text,          -- external id, for idempotency
  created_at       timestamptz not null default now(),

  constraint ledger_reserve_shape check (
    kind <> 'reserve' or (delta < 0 and reservation_id is not null)),
  constraint ledger_commit_shape check (
    kind <> 'commit' or (delta = 0 and reservation_id is not null)),
  constraint ledger_refund_shape check (
    kind <> 'refund' or (delta > 0 and reservation_id is not null)),
  constraint ledger_credit_shape check (
    kind not in ('purchase', 'subscription_grant') or delta > 0),
  constraint ledger_store_refund_shape check (
    kind <> 'store_refund' or delta <= 0)
);

comment on table public.credits_ledger is
  'Append-only AI credit ledger. Balance = sum(delta). No health data.';

create index credits_ledger_user_idx on public.credits_ledger (user_id, created_at);
create unique index credits_ledger_one_reserve
  on public.credits_ledger (reservation_id) where kind = 'reserve';
create unique index credits_ledger_one_settlement
  on public.credits_ledger (reservation_id) where kind in ('commit', 'refund');
create unique index credits_ledger_source_event
  on public.credits_ledger (source, source_event_id, kind) where source_event_id is not null;

-- Append-only: no updates ever; deletes only when the account itself is being
-- deleted (ON DELETE CASCADE from auth.users -> accounts -> ledger).
create or replace function private.ledger_append_only()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE'
     and not exists (select 1 from public.accounts a where a.id = old.user_id) then
    return old;
  end if;
  raise exception 'credits_ledger is append-only' using errcode = '42501';
end;
$$;

create trigger credits_ledger_no_update
  before update on public.credits_ledger
  for each row execute function private.ledger_append_only();
create trigger credits_ledger_no_delete
  before delete on public.credits_ledger
  for each row execute function private.ledger_append_only();

revoke update, delete, truncate on public.credits_ledger from service_role;

create or replace function private.balance_of(p_user uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(sum(delta), 0)::integer
  from public.credits_ledger
  where user_id = p_user;
$$;

-- Backstop: no insert may leave a balance below zero.
create or replace function private.ledger_non_negative()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.delta < 0 and private.balance_of(new.user_id) < 0 then
    raise exception 'insufficient_credits' using errcode = '23514';
  end if;
  return null;
end;
$$;

create constraint trigger credits_ledger_non_negative
  after insert on public.credits_ledger
  deferrable initially immediate
  for each row execute function private.ledger_non_negative();

-- Serialise balance changes per user.
create or replace function private.lock_account(p_user uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform 1 from public.accounts where id = p_user for update;
  if not found then
    raise exception 'unknown_account' using errcode = 'P0002';
  end if;
end;
$$;

alter table public.credits_ledger enable row level security;

create policy credits_ledger_select_own on public.credits_ledger
  for select to authenticated using (user_id = (select auth.uid()));

grant select on public.credits_ledger to authenticated;

-- ---------------------------------------------------------------------------
-- Balance (readable by the user for themself; any user for service_role)
-- ---------------------------------------------------------------------------
create or replace function public.credit_balance(p_user uuid default auth.uid())
returns integer
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_user is null then
    raise exception 'not_authenticated' using errcode = '42501';
  end if;
  if p_user is distinct from auth.uid()
     and coalesce(auth.jwt() ->> 'role', '') <> 'service_role' then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  return private.balance_of(p_user);
end;
$$;

revoke execute on function public.credit_balance(uuid) from public, anon;
grant execute on function public.credit_balance(uuid) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- reserve / commit / refund (service_role only: called by the ai-doctor
-- Edge Function after it has verified the user's JWT)
-- ---------------------------------------------------------------------------
create or replace function public.reserve_credits(
  p_user uuid,
  p_amount integer,
  p_reservation_id uuid default gen_random_uuid(),
  p_source text default 'ai-doctor'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_balance integer;
begin
  if p_amount is null or p_amount <= 0 then
    raise exception 'amount must be positive' using errcode = '22023';
  end if;

  perform private.lock_account(p_user);

  -- A reservation id is a one-time request id: a retry must not buy a second run.
  if exists (select 1 from public.credits_ledger
             where reservation_id = p_reservation_id and kind = 'reserve') then
    return jsonb_build_object('ok', false, 'error', 'duplicate_request',
                              'balance', private.balance_of(p_user));
  end if;

  v_balance := private.balance_of(p_user);
  if v_balance < p_amount then
    return jsonb_build_object('ok', false, 'error', 'insufficient_credits',
                              'balance', v_balance, 'required', p_amount);
  end if;

  insert into public.credits_ledger (user_id, delta, kind, reservation_id, source)
  values (p_user, -p_amount, 'reserve', p_reservation_id, p_source);

  return jsonb_build_object('ok', true, 'reservation_id', p_reservation_id,
                            'balance', v_balance - p_amount);
end;
$$;

create or replace function private.settle_reservation(p_reservation_id uuid, p_kind text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_reserve public.credits_ledger%rowtype;
  v_settled text;
begin
  select * into v_reserve from public.credits_ledger
  where reservation_id = p_reservation_id and kind = 'reserve';
  if not found then
    return jsonb_build_object('ok', false, 'error', 'unknown_reservation');
  end if;

  perform private.lock_account(v_reserve.user_id);

  select kind into v_settled from public.credits_ledger
  where reservation_id = p_reservation_id and kind in ('commit', 'refund');
  if found then
    return jsonb_build_object('ok', v_settled = p_kind, 'already', v_settled,
                              'balance', private.balance_of(v_reserve.user_id));
  end if;

  insert into public.credits_ledger (user_id, delta, kind, reservation_id, source)
  values (v_reserve.user_id,
          case when p_kind = 'refund' then -v_reserve.delta else 0 end,
          p_kind, p_reservation_id, v_reserve.source);

  return jsonb_build_object('ok', true,
                            'balance', private.balance_of(v_reserve.user_id));
end;
$$;

create or replace function public.commit_credits(p_reservation_id uuid)
returns jsonb
language sql
security definer
set search_path = ''
as $$ select private.settle_reservation(p_reservation_id, 'commit'); $$;

create or replace function public.refund_credits(p_reservation_id uuid)
returns jsonb
language sql
security definer
set search_path = ''
as $$ select private.settle_reservation(p_reservation_id, 'refund'); $$;

-- Refund reservations whose Edge Function died before settling them.
-- Schedule with pg_cron, e.g. every 5 minutes.
create or replace function public.expire_stale_reservations(
  p_older_than interval default interval '15 minutes'
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
  n integer := 0;
begin
  for r in
    select l.reservation_id from public.credits_ledger l
    where l.kind = 'reserve' and l.created_at < now() - p_older_than
      and not exists (select 1 from public.credits_ledger s
                      where s.reservation_id = l.reservation_id
                        and s.kind in ('commit', 'refund'))
  loop
    if (private.settle_reservation(r.reservation_id, 'refund') ->> 'ok')::boolean then
      n := n + 1;
    end if;
  end loop;
  return n;
end;
$$;

revoke execute on function public.reserve_credits(uuid, integer, uuid, text) from public, anon, authenticated;
revoke execute on function public.commit_credits(uuid) from public, anon, authenticated;
revoke execute on function public.refund_credits(uuid) from public, anon, authenticated;
revoke execute on function public.expire_stale_reservations(interval) from public, anon, authenticated;
grant execute on function public.reserve_credits(uuid, integer, uuid, text) to service_role;
grant execute on function public.commit_credits(uuid) to service_role;
grant execute on function public.refund_credits(uuid) to service_role;
grant execute on function public.expire_stale_reservations(interval) to service_role;

revoke execute on all functions in schema private from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- entitlements: what the user has bought (e.g. Usra Plus). Written only by
-- the revenuecat-webhook function.
-- ---------------------------------------------------------------------------
create table public.entitlements (
  user_id      uuid not null references public.accounts (id) on delete cascade,
  entitlement  text not null check (entitlement in ('plus')),
  active       boolean not null,
  product_id   text,
  store        text,
  expires_at   timestamptz,
  event_at     timestamptz not null,   -- time of the store event that set this
  updated_at   timestamptz not null default now(),
  primary key (user_id, entitlement)
);

alter table public.entitlements enable row level security;

create policy entitlements_select_own on public.entitlements
  for select to authenticated using (user_id = (select auth.uid()));

grant select on public.entitlements to authenticated;

-- ---------------------------------------------------------------------------
-- Processed RevenueCat events (idempotency). Ids and outcome only; no payload.
-- ---------------------------------------------------------------------------
create table public.purchase_events (
  event_id      text primary key,
  event_type    text not null,
  user_id       uuid,
  outcome       text not null,
  processed_at  timestamptz not null default now()
);

alter table public.purchase_events enable row level security;
-- No policies: only service_role (which bypasses RLS) reads or writes it.

-- Apply one mapped purchase event atomically and at most once.
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
  insert into public.purchase_events (event_id, event_type, user_id, outcome)
  values (p_event_id, p_event_type, p_user, 'processing')
  on conflict (event_id) do nothing;
  if not found then
    return jsonb_build_object('applied', false, 'duplicate', true);
  end if;

  if p_user is null or not exists (select 1 from public.accounts where id = p_user) then
    update public.purchase_events set outcome = 'unknown_user' where event_id = p_event_id;
    return jsonb_build_object('applied', false, 'error', 'unknown_user');
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

revoke execute on function public.apply_purchase_event(
  text, text, uuid, timestamptz, integer, text, text, boolean, timestamptz, text, text
) from public, anon, authenticated;
grant execute on function public.apply_purchase_event(
  text, text, uuid, timestamptz, integer, text, text, boolean, timestamptz, text, text
) to service_role;
