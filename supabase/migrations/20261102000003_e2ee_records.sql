-- Usra: end-to-end-encrypted family records (v2 sync).
--
-- Each record is encrypted on the phone with the family key (AES-256-GCM)
-- before upload. The server stores only ids, a key version, timestamps and
-- ciphertext; it never sees plaintext health data, nor the record type.
-- Conflicts are last-writer-wins per record using the server's updated_at.

create table public.families (
  id          uuid primary key default gen_random_uuid(),
  created_by  uuid not null references public.accounts (id) on delete cascade,
  created_at  timestamptz not null default now()
);

create table public.family_members (
  family_id  uuid not null references public.families (id) on delete cascade,
  user_id    uuid not null references public.accounts (id) on delete cascade,
  role       text not null check (role in ('owner', 'guardian', 'cared_for', 'viewer')),
  added_at   timestamptz not null default now(),
  primary key (family_id, user_id)
);

create index family_members_user_idx on public.family_members (user_id);

create table public.e2ee_records (
  family_id    uuid not null references public.families (id) on delete cascade,
  record_id    uuid not null,              -- UUID v7 from the phone
  key_version  integer not null default 1 check (key_version > 0),
  ciphertext   bytea check (ciphertext is null or octet_length(ciphertext) <= 2097152),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz,
  primary key (family_id, record_id),
  constraint e2ee_tombstone check (ciphertext is not null or deleted_at is not null)
);

comment on table public.e2ee_records is
  'Ciphertext only. Encrypted on the phone with the family key; the server cannot read it.';

create index e2ee_records_pull_idx on public.e2ee_records (family_id, updated_at);

-- Server clock decides "last writer"; clients cannot set updated_at.
create or replace function private.e2ee_stamp()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := clock_timestamp();
  if tg_op = 'UPDATE' then
    new.family_id := old.family_id;
    new.record_id := old.record_id;
  end if;
  return new;
end;
$$;

create trigger e2ee_records_stamp
  before insert or update on public.e2ee_records
  for each row execute function private.e2ee_stamp();

-- The creator becomes the family's owner.
create or replace function private.family_add_owner()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.family_members (family_id, user_id, role)
  values (new.id, new.created_by, 'owner');
  return new;
end;
$$;

create trigger families_add_owner
  after insert on public.families
  for each row execute function private.family_add_owner();

-- Role lookup for RLS. SECURITY DEFINER avoids recursive RLS on family_members.
create or replace function private.family_role(p_family uuid)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select role from public.family_members
  where family_id = p_family and user_id = auth.uid();
$$;

grant usage on schema private to authenticated;
revoke execute on all functions in schema private from public, anon, authenticated;
grant execute on function private.family_role(uuid) to authenticated;

-- families -------------------------------------------------------------------
alter table public.families enable row level security;

create policy families_select_member on public.families
  for select to authenticated
  using (private.family_role(id) is not null);
create policy families_insert_self on public.families
  for insert to authenticated
  with check (created_by = (select auth.uid()));
create policy families_delete_owner on public.families
  for delete to authenticated
  using (private.family_role(id) = 'owner');

grant select, insert, delete on public.families to authenticated;

-- family_members -------------------------------------------------------------
alter table public.family_members enable row level security;

create policy family_members_select on public.family_members
  for select to authenticated
  using (private.family_role(family_id) is not null);
create policy family_members_insert_owner on public.family_members
  for insert to authenticated
  with check (private.family_role(family_id) = 'owner' and role <> 'owner');
create policy family_members_update_owner on public.family_members
  for update to authenticated
  using (private.family_role(family_id) = 'owner' and user_id <> (select auth.uid()))
  with check (role <> 'owner');
create policy family_members_delete on public.family_members
  for delete to authenticated
  using (
    (private.family_role(family_id) = 'owner' and user_id <> (select auth.uid()))
    or (user_id = (select auth.uid()) and role <> 'owner')   -- leave a family
  );

grant select, insert, delete on public.family_members to authenticated;
grant update (role) on public.family_members to authenticated;

-- e2ee_records ---------------------------------------------------------------
-- Every member can read; owners and guardians can write. No hard deletes from
-- the app: deleting a record sets deleted_at (and may drop the ciphertext).
alter table public.e2ee_records enable row level security;

create policy e2ee_select_member on public.e2ee_records
  for select to authenticated
  using (private.family_role(family_id) is not null);
create policy e2ee_insert_writer on public.e2ee_records
  for insert to authenticated
  with check (private.family_role(family_id) in ('owner', 'guardian'));
create policy e2ee_update_writer on public.e2ee_records
  for update to authenticated
  using (private.family_role(family_id) in ('owner', 'guardian'))
  with check (private.family_role(family_id) in ('owner', 'guardian'));

grant select, insert on public.e2ee_records to authenticated;
grant update (key_version, ciphertext, deleted_at) on public.e2ee_records to authenticated;
