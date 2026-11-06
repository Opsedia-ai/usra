-- Usra: sign-in is Google and Apple only, so accounts have an email and no
-- phone number. The one place the schema read a phone number was the owner's
-- list of accepted invites ("Is this Mona?"), which now shows the email.
--
-- Comments in earlier migrations say "SMS-only session": read that as a
-- session that only signed in, not bound to an approved device. The rule is
-- the same whichever way the person signed in.
--
-- The returned column changes name, so the function is dropped and made again.

drop function public.pending_family_invites(uuid);

create function public.pending_family_invites(p_family uuid)
returns table (
  invite_id        uuid,
  role             text,
  user_id          uuid,
  email            text,
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
    select i.id, i.role, i.accepted_by, u.email::text, i.accepted_at, i.invitee_devices,
           private.b64(i.invitee_mac),
           (select max(r.completed_at) from public.account_resets r where r.user_id = i.accepted_by)
    from public.family_invites i
    join auth.users u on u.id = i.accepted_by
    where i.family_id = p_family and i.accepted_at is not null
      and i.used_at is null and i.revoked_at is null
    order by i.accepted_at;
end;
$$;

revoke execute on function public.pending_family_invites(uuid) from public, anon;
grant execute on function public.pending_family_invites(uuid) to authenticated;
