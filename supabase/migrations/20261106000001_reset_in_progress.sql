-- Usra: an account that isn't enrolled can't be joined into someone else's
-- open reset (follow-up to 20261105000002_sync_log_devices.sql, PR #11).
--
-- When the last completed reset can't be claimed, any pending phone may start
-- a new reset. If one is already open, a phone that didn't start it used to
-- get its id back, as if the reset were its own; only the phone that started
-- it can enrol afterwards. Now it gets `reset_in_progress`, so the app can say
-- "a reset is already running" instead (docs/sync-design.md, section 8).

create or replace function public.start_account_reset(p_device uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_id uuid;
  v_enrolled timestamptz;
  v_started uuid;
  v_completed timestamptz;
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
  select sync_enrolled_at into v_enrolled from public.accounts where id = v_user for update;
  if v_enrolled is null then
    -- Not enrolled: there is nothing to reset, unless the last reset can no
    -- longer be claimed (its phone was revoked or purged, or 72 hours passed
    -- without it enrolling). Then a new reset starts, with the full wait, so
    -- this never shortens the delay.
    select r.started_device, r.completed_at into v_started, v_completed
    from public.account_resets r
    where r.user_id = v_user and r.completed_at is not null
    order by r.completed_at desc, r.started_at desc limit 1;
    if v_completed is null
       or (v_completed >= now() - interval '72 hours'
           and exists (select 1 from public.devices d where d.id = v_started and d.status = 'pending')) then
      raise exception 'not_enrolled' using errcode = '22023';
    end if;
  end if;
  select id, started_device into v_id, v_started from public.account_resets
  where user_id = v_user and cancelled_at is null and completed_at is null;
  -- An unenrolled account's open reset belongs to the phone that started it:
  -- another phone (the person's or a SIM-swapper's) is told, not joined in.
  if v_id is not null and v_enrolled is null and v_started is distinct from p_device then
    raise exception 'reset_in_progress' using errcode = '55000';
  end if;
  if v_id is null then
    insert into public.account_resets (user_id, started_device)
    values (v_user, p_device) returning id into v_id;
  end if;
  return v_id;
end;
$$;

revoke execute on function public.start_account_reset(uuid) from public, anon;
grant execute on function public.start_account_reset(uuid) to authenticated;
