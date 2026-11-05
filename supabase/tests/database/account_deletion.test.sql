-- pgTAP: deleting an account (what the delete-account function does) removes
-- everything that user owns, and nothing of anyone else's. A family the user
-- created but handed over stays (B0.7). Run with: supabase test db
begin;
select plan(20);

insert into auth.users (id, phone) values
  ('33333333-3333-3333-3333-333333333333', '201000000003'),
  ('44444444-4444-4444-4444-444444444444', '201000000004');

select set_config('request.jwt.claims', '{"role":"service_role"}', true);

insert into public.devices (id, user_id, platform, app_version, public_key) values
  ('dddddddd-0000-0000-0000-000000000003', '33333333-3333-3333-3333-333333333333', 'android', '1.0.0',
   decode(repeat('01', 32), 'hex')),
  ('dddddddd-0000-0000-0000-000000000004', '44444444-4444-4444-4444-444444444444', 'ios', '1.0.0',
   decode(repeat('02', 32), 'hex'));
insert into public.push_tokens (user_id, device_id, token) values
  ('33333333-3333-3333-3333-333333333333', 'dddddddd-0000-0000-0000-000000000003', 'fcm-3');
select public.apply_purchase_event('evt-del-3', 'NON_RENEWING_PURCHASE',
  '33333333-3333-3333-3333-333333333333', now(), 5, 'purchase');
select public.apply_purchase_event('evt-del-4', 'NON_RENEWING_PURCHASE',
  '44444444-4444-4444-4444-444444444444', now(), 5, 'purchase');

-- Family 3: user 3 alone. Family 4: user 4 owns, user 3 is a guardian.
-- Family 5: created by user 3, who later handed ownership to user 4.
-- (Seeded as the table owner; the app can only change membership through the log.)
insert into public.families (id, created_by) values
  ('ffffffff-0000-0000-0000-000000000003', '33333333-3333-3333-3333-333333333333'),
  ('ffffffff-0000-0000-0000-000000000004', '44444444-4444-4444-4444-444444444444'),
  ('ffffffff-0000-0000-0000-000000000005', '33333333-3333-3333-3333-333333333333');
-- (each creator becomes the owner member by trigger)
update public.family_members set role = 'guardian'
  where family_id = 'ffffffff-0000-0000-0000-000000000005'
    and user_id = '33333333-3333-3333-3333-333333333333';
insert into public.family_members (family_id, user_id, role) values
  ('ffffffff-0000-0000-0000-000000000004', '33333333-3333-3333-3333-333333333333', 'guardian'),
  ('ffffffff-0000-0000-0000-000000000005', '44444444-4444-4444-4444-444444444444', 'owner');
insert into public.e2ee_records (family_id, sync_id, ciphertext) values
  ('ffffffff-0000-0000-0000-000000000003', 'eeeeeeee-0000-4000-8000-000000000003', decode(repeat('ab', 296), 'hex')),
  ('ffffffff-0000-0000-0000-000000000004', 'eeeeeeee-0000-4000-8000-000000000004', decode(repeat('ab', 296), 'hex')),
  ('ffffffff-0000-0000-0000-000000000005', 'eeeeeeee-0000-4000-8000-000000000005', decode(repeat('ab', 296), 'hex'));

-- The delete-account function refuses while a family the user OWNS has other
-- members (it would leave them without an owner).
select is(public.account_deletion_blockers('44444444-4444-4444-4444-444444444444'), 2,
  'owner of families with other members is blocked');
select is(public.account_deletion_blockers('33333333-3333-3333-3333-333333333333'), 0,
  'creating a family that was handed over, a family alone, and memberships do not block');
select ok(not has_function_privilege('authenticated', 'public.account_deletion_blockers(uuid)', 'execute'),
  'apps cannot call the blocker check');
select ok(not has_function_privilege('anon', 'public.account_deletion_blockers(uuid)', 'execute'),
  'anonymous callers cannot call the blocker check');

select lives_ok($$ delete from auth.users where id = '33333333-3333-3333-3333-333333333333' $$,
  'deleting the auth user succeeds even though the credits ledger is append-only');

select is((select count(*)::int from public.accounts where id = '33333333-3333-3333-3333-333333333333'), 0,
  'account row is gone');
select is((select count(*)::int from public.devices where user_id = '33333333-3333-3333-3333-333333333333'), 0,
  'devices are gone');
select is((select count(*)::int from public.push_tokens where user_id = '33333333-3333-3333-3333-333333333333'), 0,
  'push tokens are gone');
select is((select count(*)::int from public.credits_ledger where user_id = '33333333-3333-3333-3333-333333333333'), 0,
  'credit movements are gone');
select is((select count(*)::int from public.families where id = 'ffffffff-0000-0000-0000-000000000003'), 0,
  'a family left with no members is gone');
select is((select count(*)::int from public.e2ee_records where family_id = 'ffffffff-0000-0000-0000-000000000003'), 0,
  'that family''s ciphertext is gone');
select is((select count(*)::int from public.family_members where user_id = '33333333-3333-3333-3333-333333333333'), 0,
  'their memberships in other families are gone');

select is((select count(*)::int from public.family_members where family_id = 'ffffffff-0000-0000-0000-000000000004'), 1,
  'the other family keeps its owner');
select is((select count(*)::int from public.e2ee_records where family_id = 'ffffffff-0000-0000-0000-000000000004'), 1,
  'the other family keeps its records');

select is((select count(*)::int from public.families where id = 'ffffffff-0000-0000-0000-000000000005'), 1,
  'a family the user created but handed over is kept');
select ok((select created_by is null from public.families where id = 'ffffffff-0000-0000-0000-000000000005'),
  'its created_by is cleared, not cascaded');
select is((select role from public.family_members
           where family_id = 'ffffffff-0000-0000-0000-000000000005'
             and user_id = '44444444-4444-4444-4444-444444444444'), 'owner',
  'its new owner stays owner');
select is((select count(*)::int from public.e2ee_records where family_id = 'ffffffff-0000-0000-0000-000000000005'), 1,
  'and its records stay');

select is((select count(*)::int from public.devices where user_id = '44444444-4444-4444-4444-444444444444'), 1,
  'other users keep their devices');
select is(public.credit_balance('44444444-4444-4444-4444-444444444444'), 5,
  'other users keep their credits');

select * from finish();
rollback;
