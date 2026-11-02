-- pgTAP tests for credits, entitlements and RLS. Run with: supabase test db
begin;
select plan(33);

insert into auth.users (id, phone) values
  ('11111111-1111-1111-1111-111111111111', '201000000001'),
  ('22222222-2222-2222-2222-222222222222', '201000000002');

select is((select count(*)::int from public.accounts), 2, 'account row created per auth user');

-- Act as the Edge Functions do (service role) until the RLS section below.
select set_config('request.jwt.claims', '{"role":"service_role"}', true);

-- Purchases are idempotent by event id -----------------------------------------
select is(public.apply_purchase_event('evt1', 'NON_RENEWING_PURCHASE',
  '11111111-1111-1111-1111-111111111111', now(), 5, 'purchase') ->> 'applied', 'true',
  'credit pack applied');
select is(public.apply_purchase_event('evt1', 'NON_RENEWING_PURCHASE',
  '11111111-1111-1111-1111-111111111111', now(), 5, 'purchase') ->> 'duplicate', 'true',
  'same event id is ignored');
select is(public.credit_balance('11111111-1111-1111-1111-111111111111'), 5, 'balance is 5');

-- A purchase for an account that doesn't exist yet is not recorded (so it can be retried)
select throws_ok($$ select public.apply_purchase_event('evt-early', 'NON_RENEWING_PURCHASE',
  '99999999-9999-9999-9999-999999999999', now(), 5, 'purchase') $$,
  'P0002', null, 'unknown user raises instead of being marked processed');
select is((select count(*)::int from public.purchase_events where event_id = 'evt-early'), 0,
  'the early event id is not recorded');

-- Reserve / commit / refund ------------------------------------------------------
select is(public.reserve_credits('11111111-1111-1111-1111-111111111111', 3,
  'aaaaaaaa-0000-0000-0000-000000000001') ->> 'balance', '2', 'reserve holds credits');
select is(public.reserve_credits('11111111-1111-1111-1111-111111111111', 3,
  'aaaaaaaa-0000-0000-0000-000000000002') ->> 'error', 'insufficient_credits',
  'cannot reserve more than the balance');
select is(public.reservation_status('11111111-1111-1111-1111-111111111111',
  'aaaaaaaa-0000-0000-0000-000000000001'), 'reserved', 'status of an open hold is reserved');
select is(public.reservation_status('22222222-2222-2222-2222-222222222222',
  'aaaaaaaa-0000-0000-0000-000000000001'), 'unknown', 'another user cannot see the reservation');
select is(public.refund_credits('aaaaaaaa-0000-0000-0000-000000000001') ->> 'balance', '5',
  'refund returns the hold');
select is(public.commit_credits('aaaaaaaa-0000-0000-0000-000000000001') ->> 'ok', 'false',
  'a refunded reservation cannot be committed');
select is(public.refund_credits('aaaaaaaa-0000-0000-0000-000000000001') ->> 'balance', '5',
  'a second refund is a no-op');

select public.reserve_credits('11111111-1111-1111-1111-111111111111', 2,
  'aaaaaaaa-0000-0000-0000-000000000003');
select public.commit_credits('aaaaaaaa-0000-0000-0000-000000000003');
select is(public.credit_balance('11111111-1111-1111-1111-111111111111'), 3, 'commit keeps the debit');
select is(public.reservation_status('11111111-1111-1111-1111-111111111111',
  'aaaaaaaa-0000-0000-0000-000000000003'), 'commit', 'status after commit');

-- Cloud OCR: burst limit and giving a slot back ------------------------------------
select is(public.consume_ocr_quota('22222222-2222-2222-2222-222222222222', 20, '30 days', 1) ->> 'allowed',
  'true', 'first OCR request allowed');
select is(public.consume_ocr_quota('22222222-2222-2222-2222-222222222222', 20, '30 days', 1) ->> 'reason',
  'burst', 'second request within a minute hits the burst limit');
select ok(public.release_ocr_quota('22222222-2222-2222-2222-222222222222',
  (select max(id) from public.ocr_requests where user_id = '22222222-2222-2222-2222-222222222222')),
  'a failed read gives its slot back');

-- Never negative ------------------------------------------------------------------
select public.apply_purchase_event('evt2', 'CANCELLATION',
  '11111111-1111-1111-1111-111111111111', now(), -10, 'store_refund');
select is(public.credit_balance('11111111-1111-1111-1111-111111111111'), 0,
  'store refund is clamped at zero');
select throws_ok($$ insert into public.credits_ledger (user_id, delta, kind)
  values ('11111111-1111-1111-1111-111111111111', -1, 'adjustment') $$,
  '23514', null, 'direct negative insert is rejected');
select throws_ok($$ update public.credits_ledger set delta = 100 $$,
  '42501', null, 'ledger is append-only');

-- Entitlements ignore older events --------------------------------------------------
select public.apply_purchase_event('evt3', 'INITIAL_PURCHASE',
  '11111111-1111-1111-1111-111111111111', now(), 30, 'subscription_grant',
  'plus', true, now() + interval '30 days', 'usra_plus_monthly', 'app_store');
select public.apply_purchase_event('evt4', 'EXPIRATION',
  '11111111-1111-1111-1111-111111111111', now() - interval '1 day', 0, null,
  'plus', false);
select ok((select active from public.entitlements
           where user_id = '11111111-1111-1111-1111-111111111111'),
  'out-of-order expiration does not override a newer purchase');

-- RLS as user 1 ---------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

select is(public.credit_balance(), 30, 'user reads own balance');
select throws_ok($$ select public.credit_balance('22222222-2222-2222-2222-222222222222') $$,
  '42501', null, 'user cannot read another balance');
select throws_ok($$ select public.reserve_credits('11111111-1111-1111-1111-111111111111', 1) $$,
  '42501', null, 'reserve is service-role only');

insert into public.families (id, created_by)
  values ('ffffffff-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111');
select throws_ok($$ insert into public.family_members (family_id, user_id, role)
  values ('ffffffff-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'viewer') $$,
  '42501', null, 'an owner cannot add someone without an invite');
insert into public.family_invites (family_id, role, code_hash, created_by)
  values ('ffffffff-0000-0000-0000-000000000001', 'viewer',
          encode(sha256(convert_to('invite-code-1', 'UTF8')), 'hex'),
          '11111111-1111-1111-1111-111111111111');
insert into public.e2ee_records (family_id, record_id, ciphertext)
  values ('ffffffff-0000-0000-0000-000000000001', gen_random_uuid(), '\xdeadbeef');

-- RLS as user 2 (invited viewer) ------------------------------------------------------
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);

select throws_ok($$ select public.accept_family_invite('wrong-code') $$,
  'P0002', null, 'a wrong invite code is refused');
select is(public.accept_family_invite('invite-code-1'), 'ffffffff-0000-0000-0000-000000000001'::uuid,
  'accepting the invite joins the family');
select throws_ok($$ select public.accept_family_invite('invite-code-1') $$,
  'P0002', null, 'an invite works only once');

select is((select count(*)::int from public.e2ee_records), 1, 'viewer can read family ciphertext');
select is((select count(*)::int from public.credits_ledger), 0, 'viewer cannot see other ledgers');
select is((select count(*)::int from public.pull_e2ee_changes('ffffffff-0000-0000-0000-000000000001')), 0,
  'a pull never returns rows from a transaction that has not finished');
select throws_ok($$ insert into public.e2ee_records (family_id, record_id, ciphertext)
  values ('ffffffff-0000-0000-0000-000000000001', gen_random_uuid(), '\x00') $$,
  '42501', null, 'viewer cannot write records');

select * from finish();
rollback;
