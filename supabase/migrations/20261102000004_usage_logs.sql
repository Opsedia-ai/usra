-- Usra: usage logs for AI Doctor and cloud OCR.
-- Only counts, token numbers and status are kept. Never the snapshot, the
-- image, the prompt or the model's reply.

create table public.ai_runs (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.accounts (id) on delete cascade,
  reservation_id  uuid,
  provider        text not null,
  model           text not null,
  input_tokens    integer,
  output_tokens   integer,
  status          text not null check (status in ('ok', 'provider_error', 'invalid_output')),
  created_at      timestamptz not null default now()
);

create index ai_runs_user_idx on public.ai_runs (user_id, created_at);

alter table public.ai_runs enable row level security;

create policy ai_runs_select_own on public.ai_runs
  for select to authenticated using (user_id = (select auth.uid()));

grant select on public.ai_runs to authenticated;

create table public.ocr_requests (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references public.accounts (id) on delete cascade,
  created_at  timestamptz not null default now()
);

create index ocr_requests_user_idx on public.ocr_requests (user_id, created_at);

alter table public.ocr_requests enable row level security;

create policy ocr_requests_select_own on public.ocr_requests
  for select to authenticated using (user_id = (select auth.uid()));

grant select on public.ocr_requests to authenticated;

-- Atomically check and count one cloud OCR request against a quota
-- (default: 20 per 30 days, per the technical design).
create or replace function public.consume_ocr_quota(
  p_user uuid,
  p_limit integer default 20,
  p_window interval default interval '30 days'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_used integer;
  v_oldest timestamptz;
begin
  perform private.lock_account(p_user);

  select count(*), min(created_at) into v_used, v_oldest
  from public.ocr_requests
  where user_id = p_user and created_at > now() - p_window;

  if v_used >= p_limit then
    return jsonb_build_object('allowed', false, 'used', v_used, 'limit', p_limit,
                              'resets_at', v_oldest + p_window);
  end if;

  insert into public.ocr_requests (user_id) values (p_user);
  return jsonb_build_object('allowed', true, 'used', v_used + 1, 'limit', p_limit);
end;
$$;

revoke execute on function public.consume_ocr_quota(uuid, integer, interval) from public, anon, authenticated;
grant execute on function public.consume_ocr_quota(uuid, integer, interval) to service_role;
