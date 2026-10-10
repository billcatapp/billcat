-- BillCat subscription licences.
-- Run once in Supabase → SQL Editor.

create table if not exists public.licences (
  user_id         uuid primary key references auth.users(id) on delete cascade,
  status          text not null default 'trial',   -- trial | active | expired
  trial_ends_at   timestamptz not null default (now() + interval '30 days'),
  paid_until      timestamptz,
  plan            text not null default 'annual',
  last_payment_id text,
  updated_at      timestamptz not null default now()
);

alter table public.licences enable row level security;

-- A shop may READ its own licence and nothing else. Deliberately no insert,
-- update or delete policy: if the app could write here, unlocking the software
-- would be a one-line change in a client anyone can inspect. Only the webhook,
-- which uses the service role and bypasses RLS, is allowed to grant time.
do $$
begin
  create policy "read own licence" on public.licences
    for select to authenticated
    using (auth.uid() = user_id);
exception when duplicate_object then null;
end $$;

-- Every new signup starts a 30-day trial automatically.
create or replace function public.start_trial()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.licences (user_id)
  values (new.id)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_licence on auth.users;
create trigger on_auth_user_created_licence
  after insert on auth.users
  for each row execute function public.start_trial();

-- Existing shops: 30 days from TODAY, not from when they signed up.
-- Without this, everyone already using BillCat would hit an expired licence the
-- moment they installed the update and lose billing mid-trading-day.
insert into public.licences (user_id, status, trial_ends_at)
select id, 'trial', now() + interval '30 days'
from auth.users
on conflict (user_id) do nothing;
