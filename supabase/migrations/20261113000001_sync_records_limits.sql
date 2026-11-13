-- Encrypted record push/pull: the cost rules and limits of docs/sync-design.md
-- section 22 (two parents who both write, 13 Nov 2026), the rest of B7 and the
-- record half of B12.
--
-- * A server switch for record sync (section 17's kill switch), off until
--   someone turns it on: `update private.sync_switch set records_enabled = true;`
-- * `sync_pull`: one call per app open returns the record page and, read
--   after it, the family log suffix, epochs, this phone's wraps and the head
--   beacons (rule 11).
-- * Pulls return ciphertext as base64 text instead of PostgREST's hex (rule 12).
-- * Limits kept in Postgres (rule 1, B12): 60 sync calls a minute per phone,
--   20,000 record writes a day and 20,000 live records per family.
-- * Tombstones are purged after a year (B7); counters after two days.
--
-- Portability (section 23): new code reads the caller only through
-- private.caller_user() / private.caller_session() and the existing device
-- helpers built on them, and uses no Supabase-only feature.

-- ---------------------------------------------------------------------------
-- 1. The caller (the only place a different auth layer has to change)
-- ---------------------------------------------------------------------------
create or replace function private.caller_user()
returns uuid
language sql
stable
set search_path = ''
as $$ select auth.uid(); $$;

create or replace function private.caller_session()
returns uuid
language sql
stable
set search_path = ''
as $$ select private.jwt_session_id(); $$;

comment on function private.caller_user() is
  'The signed-in user. Supabase Auth today; replace this (and caller_session) to move to another auth layer.';

-- ---------------------------------------------------------------------------
-- 2. Server switch
-- ---------------------------------------------------------------------------
create table private.sync_switch (
  id               boolean primary key default true constraint sync_switch_one_row check (id),
  records_enabled  boolean not null default false,
  updated_at       timestamptz not null default now()
);
insert into private.sync_switch default values;
comment on table private.sync_switch is
  'Kill switch for record sync (docs/sync-design.md section 17). Off until turned on by an admin.';

create or replace function private.sync_records_on()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$ select coalesce((select records_enabled from private.sync_switch), false); $$;

-- ---------------------------------------------------------------------------
-- 3. Limits
-- ---------------------------------------------------------------------------
create table private.sync_call_counts (
  device_id  uuid not null,
  minute     timestamptz not null,
  calls      integer not null,
  primary key (device_id, minute)
);

create table private.family_write_counts (
  family_id  uuid not null,
  day        date not null,
  writes     integer not null,
  primary key (family_id, day)
);

-- Counts one sync call for the session's phone; more than 60 in a minute is
-- refused with HTTP 429 (PostgREST maps SQLSTATE PTxxx to status xxx). A
-- refused call rolls back its own count.
create or replace function private.count_sync_call()
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_device uuid := private.session_device();
  v_calls integer;
begin
  if v_device is null then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  insert into private.sync_call_counts as c (device_id, minute, calls)
  values (v_device, date_trunc('minute', now()), 1)
  on conflict (device_id, minute) do update set calls = c.calls + 1
  returning calls into v_calls;
  if v_calls > 60 then
    raise exception 'rate_limited' using errcode = 'PT429';
  end if;
end;
$$;

create index if not exists e2ee_records_tombstone_idx
  on public.e2ee_records (deleted_at) where deleted_at is not null;
create index if not exists e2ee_records_live_idx
  on public.e2ee_records (family_id) where deleted_at is null;

-- ---------------------------------------------------------------------------
-- 4. Push: the switch and the limits on top of the existing checks
-- ---------------------------------------------------------------------------
-- p_records: [{ "sync_id": uuid v4, "key_version": int, "ciphertext": base64,
--               "deleted": bool, "expected_revision": int }]
-- Whole-batch answers: sync_disabled, no_log, stale_log, rotation_pending,
-- daily_limit, family_full. Per record: stale_key, revision_conflict.
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
  v_written   integer := 0;
  v_new_live  integer;
  v_live      bigint;
  v_today     integer;
  v_cur       public.e2ee_records%rowtype;
  v_results   jsonb := '[]'::jsonb;
begin
  if private.caller_user() is null then
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
  if not private.sync_records_on() then
    return jsonb_build_object('ok', false, 'error', 'sync_disabled');
  end if;
  perform private.count_sync_call();
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

  -- Daily writes and live records per family, checked for the whole batch.
  select coalesce(sum(writes), 0) into v_today from private.family_write_counts
  where family_id = p_family and day = current_date;
  if v_today + jsonb_array_length(p_records) > 20000 then
    return jsonb_build_object('ok', false, 'error', 'daily_limit');
  end if;
  select count(*) into v_new_live from jsonb_array_elements(p_records) e
  where (e.value ->> 'expected_revision') = '0'
    and coalesce((e.value ->> 'deleted')::boolean, false) = false;
  if v_new_live > 0 then
    select count(*) into v_live from public.e2ee_records r
    where r.family_id = p_family and r.deleted_at is null;
    if v_live + v_new_live > 20000 then
      return jsonb_build_object('ok', false, 'error', 'family_full');
    end if;
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
      v_written := v_written + 1;
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

  if v_written > 0 then
    insert into private.family_write_counts as c (family_id, day, writes)
    values (p_family, current_date, v_written)
    on conflict (family_id, day) do update set writes = c.writes + excluded.writes;
  end if;

  return jsonb_build_object('ok', true, 'head_seq', v_head, 'results', v_results);
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Pull a page of records: base64 ciphertext, the switch and the call limit
-- ---------------------------------------------------------------------------
drop function public.pull_e2ee_changes(uuid, xid8, uuid, integer);

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
  ciphertext   text,          -- base64 (PostgREST would send bytea as hex)
  deleted_at   timestamptz,
  change_txid  xid8
)
language plpgsql
volatile
security invoker   -- row-level security decides what the caller may read
set search_path = ''
as $$
begin
  if not private.family_device_ok(p_family) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if not private.sync_records_on() then
    raise exception 'sync_disabled' using errcode = 'PT503';
  end if;
  perform private.count_sync_call();
  return query
    select r.sync_id, r.revision, r.key_version, private.b64(r.ciphertext), r.deleted_at, r.change_txid
    from public.e2ee_records r
    where r.family_id = p_family
      and r.change_txid < pg_snapshot_xmin(pg_current_snapshot())
      and (r.change_txid > p_after_txid
           or (r.change_txid = p_after_txid and p_after_sync is not null
               and r.sync_id > p_after_sync))
    order by r.change_txid, r.sync_id
    limit least(greatest(coalesce(p_limit, 500), 1), 1000);
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. sync_pull: everything an app open needs, in one call
-- ---------------------------------------------------------------------------
-- Records are read first and the log, epochs and wraps after them, so every
-- key version a returned record uses is already in the returned log and
-- epochs (an append between the two reads only adds newer entries).
-- Binary values are base64. `records_more` / `log_more` say another page
-- waits: call again with the returned cursors.
create or replace function public.sync_pull(
  p_family      uuid,
  p_after_seq   integer default 0,
  p_after_txid  xid8 default '0',
  p_after_sync  uuid default null,
  p_limit       integer default 500
)
returns jsonb
language plpgsql
volatile
security invoker   -- row-level security decides what the caller may read
set search_path = ''
as $$
declare
  v_limit    integer := least(greatest(coalesce(p_limit, 500), 1), 1000);
  v_after    integer := greatest(coalesce(p_after_seq, 0), 0);
  v_records  jsonb;
  v_count    integer;
  v_last     jsonb;
  v_log      jsonb;
  v_log_n    integer;
  v_family   record;
begin
  if not private.family_device_ok(p_family) then
    raise exception 'forbidden' using errcode = '42501';
  end if;
  if not private.sync_records_on() then
    return jsonb_build_object('ok', false, 'error', 'sync_disabled');
  end if;
  perform private.count_sync_call();

  select coalesce(jsonb_agg(jsonb_build_object(
           'sync_id', r.sync_id, 'revision', r.revision, 'key_version', r.key_version,
           'ciphertext', private.b64(r.ciphertext), 'deleted', r.deleted_at is not null,
           'txid', r.change_txid::text) order by r.change_txid, r.sync_id), '[]'::jsonb),
         count(*)
    into v_records, v_count
  from (
    select r.* from public.e2ee_records r
    where r.family_id = p_family
      and r.change_txid < pg_snapshot_xmin(pg_current_snapshot())
      and (r.change_txid > coalesce(p_after_txid, '0'::xid8)
           or (r.change_txid = p_after_txid and p_after_sync is not null
               and r.sync_id > p_after_sync))
    order by r.change_txid, r.sync_id
    limit v_limit
  ) r;
  v_last := v_records -> -1;

  select coalesce(jsonb_agg(jsonb_build_object(
           'seq', l.seq, 'entry', private.b64(l.entry), 'sig', private.b64(l.sig))
           order by l.seq), '[]'::jsonb),
         count(*)
    into v_log, v_log_n
  from (
    select l.* from public.family_log l
    where l.family_id = p_family and l.seq > v_after
    order by l.seq
    limit 100
  ) l;

  select f.current_key_version, f.rotation_pending into v_family
  from public.families f where f.id = p_family;

  return jsonb_build_object(
    'ok', true,
    'head_seq', (select max(l.seq) from public.family_log l where l.family_id = p_family),
    'key_version', v_family.current_key_version,
    'rotation_pending', v_family.rotation_pending,
    'log', v_log,
    'log_more', v_log_n = 100,
    'epochs', (select coalesce(jsonb_agg(jsonb_build_object(
                 'key_version', e.key_version, 'log_seq', e.log_seq,
                 'kc', private.b64(e.key_commitment), 'history', private.b64(e.history))
                 order by e.key_version), '[]'::jsonb)
               from public.family_epochs e
               where e.family_id = p_family and e.log_seq > v_after),
    'wraps', (select coalesce(jsonb_agg(jsonb_build_object(
                'key_version', w.key_version, 'recipient', w.recipient_device_id,
                'sender', w.sender_device_id, 'enc', private.b64(w.enc),
                'ct', private.b64(w.ct), 'sig', private.b64(w.sig))
                order by w.key_version, w.recipient_device_id), '[]'::jsonb)
              from public.family_key_wraps w where w.family_id = p_family),
    'heads', (select coalesce(jsonb_agg(jsonb_build_object(
                'device', h.device_id, 'beacon', private.b64(h.beacon), 'sig', private.b64(h.sig))
                order by h.device_id), '[]'::jsonb)
              from public.family_heads h where h.family_id = p_family),
    'records', v_records,
    'records_more', v_count = v_limit,
    'after_txid', coalesce(v_last ->> 'txid', coalesce(p_after_txid, '0'::xid8)::text),
    'after_sync', case when v_last is null then p_after_sync else (v_last ->> 'sync_id')::uuid end
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. Housekeeping: the existing jobs, plus tombstones after a year and old
--    counters
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
  -- Pending phones nobody approved within a week (left by older sessions),
  -- except the phone of an open reset or of one completed less than 72 hours
  -- ago (it may still enrol).
  delete from public.devices d
  where d.status = 'pending' and d.created_at < now() - interval '7 days'
    and not exists (select 1 from public.account_resets r
                    where r.started_device = d.id and r.cancelled_at is null
                      and (r.completed_at is null or r.completed_at >= now() - interval '72 hours'));
  -- Revoked rows after 90 days, unless a family log lists them (its marker
  -- keeps them) or they are an account's recovery device.
  delete from public.devices d
  where d.status = 'revoked' and d.revoked_at < now() - interval '90 days'
    and not exists (select 1 from public.family_devices fd where fd.device_id = d.id)
    and not exists (select 1 from public.account_recovery r where r.recovery_device_id = d.id);
  -- Signed tombstones are kept a year (a phone offline longer does a full
  -- resync, section 12).
  delete from public.e2ee_records where deleted_at < now() - interval '1 year';
  delete from private.sync_call_counts where minute < now() - interval '2 days';
  delete from private.family_write_counts where day < current_date - 2;
end;
$$;

-- ---------------------------------------------------------------------------
-- 8. Privileges
-- ---------------------------------------------------------------------------
revoke all on private.sync_switch, private.sync_call_counts, private.family_write_counts
  from public, anon, authenticated;
revoke execute on function private.caller_user() from public, anon;
revoke execute on function private.caller_session() from public, anon;
revoke execute on function private.sync_records_on() from public, anon;
revoke execute on function private.count_sync_call() from public, anon;
grant execute on function private.caller_user() to authenticated, service_role;
grant execute on function private.caller_session() to authenticated, service_role;
grant execute on function private.sync_records_on() to authenticated, service_role;
grant execute on function private.count_sync_call() to authenticated, service_role;

revoke execute on function public.sync_housekeeping() from public, anon, authenticated;
grant execute on function public.sync_housekeeping() to service_role;
revoke execute on function public.push_e2ee_records(uuid, integer, jsonb) from public, anon;
grant execute on function public.push_e2ee_records(uuid, integer, jsonb) to authenticated;
revoke execute on function public.pull_e2ee_changes(uuid, xid8, uuid, integer) from public, anon;
grant execute on function public.pull_e2ee_changes(uuid, xid8, uuid, integer) to authenticated;
revoke execute on function public.sync_pull(uuid, integer, xid8, uuid, integer) from public, anon;
grant execute on function public.sync_pull(uuid, integer, xid8, uuid, integer) to authenticated;
-- The pulls run as the caller (row-level security) and encode with this.
grant execute on function private.b64(bytea) to authenticated;
