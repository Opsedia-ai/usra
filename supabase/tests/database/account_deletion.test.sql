-- pgTAP: deleting an account (what the delete-account function does) removes
-- everything that user owns, and nothing of anyone else's. Run with: supabase test db
begin;
select plan(12);

insert into auth.users (id, phone) values
  ('33333333-3333-3333-3333-333333333333', '201000000003'),
  ('44444444-4444-4444-4444-444444444444', '201000000004');

select set_config('request.jwt.claims', '{"role":"service_role"}', true);

insert into public.devices (id, user_id, platform, app_version, public_key) values
  ('dddddddd-0000-0000-0000-000000000003', '33333333-3333-3333-3333-333333333333', 'android', '1.0.0', '\x01'),
  ('dddddddd-0000-0000-0000-000000000004', '44444444-4444-4444-4444-444444444444', 'ios', '1.0.0', '\x02');
insert into public.push_tokens (user_id, device_id, token) values
  ('33333333-3333-3333-3333-333333333333', 'dddddddd-0000-0000-0000-000000000003', 'fcm-3');
select public.apply_purchase_event('evt-del-3', 'NON_RENEWING_PURCHASE',
  '33333333-3333-3333-3333-333333333333', now(), 5, 'purchase');
select public.apply_purchase_event('evt-del-4', 'NON_RENEWING_PURCHASE',
  '44444444-4444-4444-4444-444444444444', now(), 5, 'purchase');
insert into public.families (id, created_by) values
  ('ffffffff-0000-0000-0000-000000000003', '33333333-3333-3333-3333-333333333333');
-- (the creator becomes its owner member by trigger)
-- User 3 is also a guardian in user 4's family.
insert into public.families (id, created_by) values
  ('ffffffff-0000-0000-0000-000000000004', '44444444-4444-4444-4444-444444444444');
insert into public.family_members (family_id, user_id, role) values
  ('ffffffff-0000-0000-0000-000000000004', '33333333-3333-3333-3333-333333333333', 'guardian');
insert into public.e2ee_records (family_id, record_id, ciphertext) values
  ('ffffffff-0000-0000-0000-000000000004', 'eeeeeeee-0000-0000-0000-000000000004', '\xcafe');
insert into public.e2ee_records (family_id, record_id, ciphertext) values
  ('ffffffff-0000-0000-0000-000000000003', 'eeeeeeee-0000-0000-0000-000000000001', '\xdeadbeef');

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
  'families they created are gone');
select is((select count(*)::int from public.e2ee_records where family_id = 'ffffffff-0000-0000-0000-000000000003'), 0,
  'that family''s ciphertext is gone');

select is((select count(*)::int from public.family_members where user_id = '33333333-3333-3333-3333-333333333333'), 0,
  'their memberships in other families are gone');
select is((select count(*)::int from public.family_members where family_id = 'ffffffff-0000-0000-0000-000000000004'), 1,
  'the other family keeps its owner');
select is((select count(*)::int from public.e2ee_records where family_id = 'ffffffff-0000-0000-0000-000000000004'), 1,
  'the other family keeps its records');
select is((select count(*)::int from public.devices where user_id = '44444444-4444-4444-4444-444444444444'), 1,
  'other users keep their devices');
select is(public.credit_balance('44444444-4444-4444-4444-444444444444'), 5,
  'other users keep their credits');

select * from finish();
rollback;
