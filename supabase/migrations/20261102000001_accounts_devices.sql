-- Usra: accounts, devices and push tokens.
-- No health data lives in these tables. Health records stay on the phone (v1)
-- or arrive only as end-to-end-encrypted ciphertext (see e2ee migration).

-- Tables created by `postgres` in `public` are exposed to the API roles by
-- default. Start from nothing and grant only what each table needs.
alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public revoke all on functions from anon, authenticated;
-- (EXECUTE to PUBLIC is a global default and cannot be revoked per schema, so
-- every function below that should not be callable revokes it explicitly.)

-- Internal helpers live in a schema the Data API does not expose.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to service_role;
alter default privileges in schema public revoke all on sequences from anon, authenticated;

-- ---------------------------------------------------------------------------
-- accounts: 1:1 with auth.users
-- ---------------------------------------------------------------------------
create table public.accounts (
  id          uuid primary key references auth.users (id) on delete cascade,
  country     text check (country in ('EG', 'SA', 'AE')),
  locale      text not null default 'ar' check (locale in ('ar', 'en')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table public.accounts is
  'One row per auth user. Holds only app settings; never health data.';

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger accounts_touch before update on public.accounts
  for each row execute function public.touch_updated_at();

-- Create the account row when Supabase Auth creates a user.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.accounts (id) values (new.id) on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

alter table public.accounts enable row level security;

create policy accounts_select_own on public.accounts
  for select to authenticated
  using (id = (select auth.uid()));

create policy accounts_update_own on public.accounts
  for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

grant select on public.accounts to authenticated;
grant update (country, locale) on public.accounts to authenticated;

-- ---------------------------------------------------------------------------
-- devices: one row per installed app. public_key is the device key used to
-- wrap the family encryption key (v2 sync); it is a public key, not a secret.
-- ---------------------------------------------------------------------------
create table public.devices (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.accounts (id) on delete cascade,
  platform      text not null check (platform in ('android', 'ios')),
  app_version   text,
  public_key    bytea check (public_key is null or octet_length(public_key) <= 1024),
  created_at    timestamptz not null default now(),
  last_seen_at  timestamptz not null default now()
);

create index devices_user_idx on public.devices (user_id);

alter table public.devices enable row level security;

create policy devices_select_own on public.devices
  for select to authenticated using (user_id = (select auth.uid()));
create policy devices_insert_own on public.devices
  for insert to authenticated with check (user_id = (select auth.uid()));
create policy devices_update_own on public.devices
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy devices_delete_own on public.devices
  for delete to authenticated using (user_id = (select auth.uid()));

grant select, insert, delete on public.devices to authenticated;
grant update (app_version, public_key, last_seen_at) on public.devices to authenticated;

-- ---------------------------------------------------------------------------
-- push_tokens: FCM tokens (APNs goes through FCM).
-- ---------------------------------------------------------------------------
create table public.push_tokens (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.accounts (id) on delete cascade,
  device_id   uuid not null references public.devices (id) on delete cascade,
  provider    text not null default 'fcm' check (provider in ('fcm')),
  token       text not null unique check (char_length(token) <= 4096),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index push_tokens_user_idx on public.push_tokens (user_id);

create trigger push_tokens_touch before update on public.push_tokens
  for each row execute function public.touch_updated_at();

alter table public.push_tokens enable row level security;

create policy push_tokens_select_own on public.push_tokens
  for select to authenticated using (user_id = (select auth.uid()));
create policy push_tokens_insert_own on public.push_tokens
  for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.devices d
                where d.id = device_id and d.user_id = (select auth.uid()))
  );
create policy push_tokens_update_own on public.push_tokens
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy push_tokens_delete_own on public.push_tokens
  for delete to authenticated using (user_id = (select auth.uid()));

grant select, insert, delete on public.push_tokens to authenticated;
grant update (token) on public.push_tokens to authenticated;
