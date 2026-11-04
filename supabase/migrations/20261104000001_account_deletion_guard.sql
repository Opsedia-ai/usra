-- Usra: guard for in-app account deletion.
--
-- Deleting an account cascades to the families it created
-- (families.created_by), and with them every member's encrypted records.
-- Until ownership can be handed over (v2 sync), the delete-account function
-- refuses while the account created a family that has other members.

create or replace function public.account_deletion_blockers(p_user uuid)
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::int
  from public.families f
  where f.created_by = p_user
    and exists (
      select 1 from public.family_members m
      where m.family_id = f.id and m.user_id <> p_user
    );
$$;

comment on function public.account_deletion_blockers(uuid) is
  'Families the user created that have other members; deleting the account would delete them.';

revoke execute on function public.account_deletion_blockers(uuid) from public, anon, authenticated;
grant execute on function public.account_deletion_blockers(uuid) to service_role;
