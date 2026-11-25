-- People, age and consent: everything "Getting in" needs on the server (docs/product/specs/getting-in.md).
--
-- One profile per account, created by the server when the account is. The app never writes a profile directly:
-- it calls the functions below, which check the rules first (age in IST, the under-13 block, the birth-date lock,
-- a parent's consent for 13–17, consent per purpose). No game columns: this is a care app.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- ---------------------------------------------------------------------------------------------
-- Dates in India.
create function private.ist_today()
returns date
language sql
stable
set search_path = ''
as $$ select (now() at time zone 'Asia/Kolkata')::date $$;

-- Whole years old today in IST. With a birth month, assume the birthday hasn't come yet in that month (the cautious
-- side: nobody under 13 slips in, nobody under 18 skips consent). Without one (an estimate), the year alone.
create function private.age_from(p_year int, p_month int)
returns int
language sql
stable
set search_path = ''
as $$
  select extract(year from private.ist_today())::int - p_year
         - case when p_month is null then 0
                when p_month >= extract(month from private.ist_today())::int then 1
                else 0 end
$$;

revoke all on function private.ist_today() from public, anon, authenticated;
revoke all on function private.age_from(int, int) from public, anon, authenticated;

-- ---------------------------------------------------------------------------------------------
-- Profiles.
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  first_name text check (first_name is null or char_length(btrim(first_name)) between 1 and 40),
  last_name text check (last_name is null or char_length(btrim(last_name)) between 1 and 40),
  gender text check (gender in ('woman', 'man', 'another', 'undisclosed')),
  birth_year int,
  birth_month int check (birth_month between 1 and 12),
  -- "Only know your age?" (adults only): the year is worked out from the age, with no month
  birth_estimated boolean not null default false,
  age_band text check (age_band in ('13-17', '18+')),
  parent_consent text not null default 'not_needed'
    check (parent_consent in ('not_needed', 'needed', 'pending', 'granted', 'declined', 'expired')),
  onboarding_step text not null default 'basics'
    check (onboarding_step in ('basics', 'parent', 'data_consent', 'health', 'medicines', 'abha', 'apps',
                               'notifications', 'done')),
  onboarded_at timestamptz,
  first_home_seen_at timestamptz,
  account_status text not null default 'active'
    check (account_status in ('active', 'deletion_scheduled', 'suspended')),
  deletion_scheduled_for timestamptz,
  suspended_reason text,
  last_mode text not null default 'patient' check (last_mode in ('patient', 'pro')),
  -- under 13: this account can't try again until then (GI-41)
  blocked_until timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint estimate_has_no_month check (not birth_estimated or birth_month is null),
  constraint teens_give_month check (age_band is distinct from '13-17' or (birth_month is not null and not birth_estimated)),
  constraint deletion_has_date check (account_status <> 'deletion_scheduled' or deletion_scheduled_for is not null)
);

alter table public.profiles enable row level security;
revoke all on table public.profiles from public, anon, authenticated;
grant select on table public.profiles to authenticated;

create policy "people read their own profile"
  on public.profiles for select to authenticated
  using (id = (select auth.uid()));

-- A profile is born with the account.
create function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id) values (new.id) on conflict (id) do nothing;
  return new;
end;
$$;

revoke all on function private.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- ---------------------------------------------------------------------------------------------
-- Where onboarding goes next. Teens wait for a parent before any health details are collected (DPDP).
create function private.step_after(p_step text, p_teen_waiting boolean)
returns text
language sql
immutable
set search_path = ''
as $$
  select case p_step
    when 'basics' then case when p_teen_waiting then 'parent' else 'data_consent' end
    when 'parent' then case when p_teen_waiting then 'parent' else 'data_consent' end
    when 'data_consent' then 'health'
    when 'health' then 'medicines'
    when 'medicines' then 'abha'
    when 'abha' then 'apps'
    when 'apps' then 'notifications'
    when 'notifications' then 'done'
    else 'done'
  end
$$;

revoke all on function private.step_after(text, boolean) from public, anon, authenticated;

create function private.me()
returns public.profiles
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  p public.profiles;
begin
  if (select auth.uid()) is null then
    raise exception 'Sign in first.' using errcode = '42501';
  end if;
  select * into p from public.profiles where id = (select auth.uid());
  if p.id is null then
    raise exception 'No profile for this account.' using errcode = 'P0002';
  end if;
  if p.account_status = 'suspended' then
    raise exception 'account_on_hold' using errcode = '42501';
  end if;
  return p;
end;
$$;

revoke all on function private.me() from public, anon, authenticated;

-- ---------------------------------------------------------------------------------------------
-- GS3 · G7 About you. Returns {"result": "ok" | "under_13", "next_step": …, "age_band": …}.
-- Errors (the app turns each into plain words): age_blocked, name_needed, gender_needed, birth_needed,
-- birth_invalid, exact_birth_needed (an age under 18 given as an estimate, GI-46), confirm_age (over 100, GI-40),
-- birth_date_locked (GI-42).
create function public.set_basics(
  first_name text,
  last_name text,
  gender text,
  birth_year int default null,
  birth_month int default null,
  age int default null,
  confirm_over_100 boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  p public.profiles := private.me();
  this_year int := extract(year from private.ist_today())::int;
  this_month int := extract(month from private.ist_today())::int;
  y int;
  m int;
  estimated boolean;
  years int;
  band text;
  next text;
begin
  if p.blocked_until is not null and p.blocked_until > now() then
    raise exception 'age_blocked' using errcode = '42501';
  end if;

  -- what they told us about their birth
  if age is not null then
    if birth_year is not null or birth_month is not null then
      raise exception 'birth_invalid' using errcode = '22023';
    end if;
    if age < 0 or age > 120 then
      raise exception 'birth_invalid' using errcode = '22023';
    end if;
    if age < 18 then
      raise exception 'exact_birth_needed' using errcode = '22023';
    end if;
    y := this_year - age;
    m := null;
    estimated := true;
  else
    if birth_year is null or birth_month is null then
      raise exception 'birth_needed' using errcode = '22023';
    end if;
    if birth_month < 1 or birth_month > 12 or birth_year > this_year or birth_year < this_year - 120
       or (birth_year = this_year and birth_month > this_month) then
      raise exception 'birth_invalid' using errcode = '22023';
    end if;
    y := birth_year;
    m := birth_month;
    estimated := false;
  end if;

  -- once saved, the birth date never changes here (support only)
  if p.birth_year is not null
     and (p.birth_year <> y or p.birth_month is distinct from m or p.birth_estimated <> estimated) then
    raise exception 'birth_date_locked' using errcode = '42501';
  end if;

  years := private.age_from(y, m);

  if years < 13 then
    -- nothing about the child is kept; the account waits 24 h (GI-41)
    update public.profiles
       set blocked_until = now() + interval '24 hours', updated_at = now()
     where id = p.id;
    return jsonb_build_object('result', 'under_13', 'blocked_until', now() + interval '24 hours');
  end if;

  if years > 100 and not confirm_over_100 then
    raise exception 'confirm_age' using errcode = '22023';
  end if;

  if first_name is null or char_length(btrim(first_name)) not between 1 and 40 then
    raise exception 'name_needed' using errcode = '22023';
  end if;
  if gender is null or gender not in ('woman', 'man', 'another', 'undisclosed') then
    raise exception 'gender_needed' using errcode = '22023';
  end if;

  band := case when years < 18 then '13-17' else '18+' end;
  next := case when p.onboarding_step = 'basics'
               then private.step_after('basics', band = '13-17' and p.parent_consent <> 'granted')
               else p.onboarding_step end;

  update public.profiles set
    first_name = btrim(set_basics.first_name),
    last_name = nullif(btrim(coalesce(set_basics.last_name, '')), ''),
    gender = set_basics.gender,
    birth_year = y,
    birth_month = m,
    birth_estimated = estimated,
    age_band = band,
    parent_consent = case when band = '18+' then 'not_needed'
                          when p.parent_consent in ('not_needed') then 'needed'
                          else p.parent_consent end,
    onboarding_step = next,
    updated_at = now()
  where id = p.id;

  return jsonb_build_object('result', 'ok', 'next_step', next, 'age_band', band);
end;
$$;

revoke all on function public.set_basics(text, text, text, int, int, int, boolean) from public, anon, authenticated;
grant execute on function public.set_basics(text, text, text, int, int, int, boolean) to authenticated;

-- ---------------------------------------------------------------------------------------------
-- Consent per purpose (DPDP): each with its notice version and time, withdrawable later.
create table public.consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  purpose text not null check (purpose in ('care', 'abha_link', 'connected_apps')),
  notice_version text not null check (char_length(notice_version) between 1 and 40),
  granted_at timestamptz not null default now(),
  withdrawn_at timestamptz
);

create unique index consents_one_active_per_purpose on public.consents (user_id, purpose) where withdrawn_at is null;

alter table public.consents enable row level security;
revoke all on table public.consents from public, anon, authenticated;
grant select on table public.consents to authenticated;

create policy "people read their own consents"
  on public.consents for select to authenticated
  using (user_id = (select auth.uid()));

-- GS5 · G10 (purpose 'care'), GS8 ('abha_link'), GS9 ('connected_apps').
create function public.record_consent(purpose text, notice_version text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  p public.profiles := private.me();
  next text := p.onboarding_step;
begin
  if p.age_band is null then
    raise exception 'basics_first' using errcode = '42501';
  end if;
  if p.age_band = '13-17' and p.parent_consent <> 'granted' then
    raise exception 'parent_consent_needed' using errcode = '42501';
  end if;
  if record_consent.purpose not in ('care', 'abha_link', 'connected_apps') then
    raise exception 'purpose_unknown' using errcode = '22023';
  end if;
  if record_consent.notice_version is null or char_length(record_consent.notice_version) not between 1 and 40 then
    raise exception 'notice_version_needed' using errcode = '22023';
  end if;

  insert into public.consents (user_id, purpose, notice_version)
  values (p.id, record_consent.purpose, record_consent.notice_version)
  on conflict (user_id, purpose) where withdrawn_at is null do nothing;

  if record_consent.purpose = 'care' and p.onboarding_step = 'data_consent' then
    next := private.step_after('data_consent', false);
    update public.profiles set onboarding_step = next, updated_at = now() where id = p.id;
  end if;
  return jsonb_build_object('next_step', next);
end;
$$;

revoke all on function public.record_consent(text, text) from public, anon, authenticated;
grant execute on function public.record_consent(text, text) to authenticated;

create function public.withdraw_consent(purpose text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  p public.profiles := private.me();
begin
  update public.consents set withdrawn_at = now()
   where user_id = p.id and consents.purpose = withdraw_consent.purpose and withdrawn_at is null;
end;
$$;

revoke all on function public.withdraw_consent(text) from public, anon, authenticated;
grant execute on function public.withdraw_consent(text) to authenticated;

-- ---------------------------------------------------------------------------------------------
-- A parent's yes for 13–17 (GS4 · G11). The request is kept here; how it reaches the parent and how the parent
-- proves it is them are decided with the founder, so deciding a request is server-only for now.
create table public.parent_consent_requests (
  id uuid primary key default gen_random_uuid(),
  teen_id uuid not null references auth.users (id) on delete cascade,
  -- E.164 digits without "+", as Supabase stores phones: 91 and ten digits
  parent_phone text not null check (parent_phone ~ '^91[6-9][0-9]{9}$'),
  status text not null default 'pending' check (status in ('pending', 'approved', 'declined', 'expired', 'replaced')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '7 days',
  decided_at timestamptz
);

create index parent_consent_requests_teen on public.parent_consent_requests (teen_id, created_at desc);

alter table public.parent_consent_requests enable row level security;
revoke all on table public.parent_consent_requests from public, anon, authenticated;
grant select on table public.parent_consent_requests to authenticated;

create policy "teens read their own requests"
  on public.parent_consent_requests for select to authenticated
  using (teen_id = (select auth.uid()));

-- Errors: not_a_teen, phone_invalid, own_number (GI-43), wait (resend after 60 s; detail = seconds left),
-- already_granted.
create function public.request_parent_consent(parent_phone text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  p public.profiles := private.me();
  digits text := regexp_replace(coalesce(parent_phone, ''), '[^0-9]', '', 'g');
  mine text;
  last_at timestamptz;
  req public.parent_consent_requests;
begin
  if p.age_band is distinct from '13-17' then
    raise exception 'not_a_teen' using errcode = '42501';
  end if;
  if p.parent_consent = 'granted' then
    raise exception 'already_granted' using errcode = '42501';
  end if;

  -- normalise like the app: 10 digits, or 91 / 0 in front
  if char_length(digits) = 10 then
    digits := '91' || digits;
  elsif char_length(digits) = 11 and left(digits, 1) = '0' then
    digits := '91' || right(digits, 10);
  end if;
  if digits !~ '^91[6-9][0-9]{9}$' then
    raise exception 'phone_invalid' using errcode = '22023';
  end if;

  select regexp_replace(coalesce(u.phone, ''), '[^0-9]', '', 'g') into mine from auth.users u where u.id = p.id;
  if mine = digits then
    raise exception 'own_number' using errcode = '22023';
  end if;

  select max(created_at) into last_at from public.parent_consent_requests where teen_id = p.id;
  if last_at is not null and last_at > now() - interval '60 seconds' then
    raise exception 'wait' using errcode = '22023',
      detail = ceil(extract(epoch from (last_at + interval '60 seconds' - now())))::text;
  end if;

  update public.parent_consent_requests set status = 'replaced'
   where teen_id = p.id and status = 'pending';

  insert into public.parent_consent_requests (teen_id, parent_phone)
  values (p.id, digits)
  returning * into req;

  update public.profiles set parent_consent = 'pending', updated_at = now() where id = p.id;

  return jsonb_build_object('request_id', req.id, 'expires_at', req.expires_at,
                            'resend_after', req.created_at + interval '60 seconds');
end;
$$;

revoke all on function public.request_parent_consent(text) from public, anon, authenticated;
grant execute on function public.request_parent_consent(text) to authenticated;

-- Server only: record the parent's answer.
create function private.decide_parent_consent(request_id uuid, approve boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  req public.parent_consent_requests;
begin
  select * into req from public.parent_consent_requests where id = request_id for update;
  if req.id is null or req.status <> 'pending' or req.expires_at <= now() then
    raise exception 'request_not_open' using errcode = '22023';
  end if;
  update public.parent_consent_requests
     set status = case when approve then 'approved' else 'declined' end, decided_at = now()
   where id = req.id;
  update public.profiles
     set parent_consent = case when approve then 'granted' else 'declined' end,
         onboarding_step = case when approve and onboarding_step = 'parent' then 'data_consent' else onboarding_step end,
         updated_at = now()
   where id = req.teen_id;
end;
$$;

revoke all on function private.decide_parent_consent(uuid, boolean) from public, anon, authenticated;

-- ---------------------------------------------------------------------------------------------
-- Onboarding steps that can be saved later or skipped (GS6–GS10), First-time home, mode, keeping an account.
create function public.finish_onboarding_step(step text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  p public.profiles := private.me();
  next text;
begin
  if step not in ('health', 'medicines', 'abha', 'apps', 'notifications') then
    raise exception 'step_unknown' using errcode = '22023';
  end if;
  if p.onboarding_step <> step then
    raise exception 'step_out_of_order' using errcode = '22023', detail = p.onboarding_step;
  end if;
  next := private.step_after(step, false);
  update public.profiles
     set onboarding_step = next,
         onboarded_at = case when next = 'done' then now() else onboarded_at end,
         updated_at = now()
   where id = p.id;
  return jsonb_build_object('next_step', next);
end;
$$;

revoke all on function public.finish_onboarding_step(text) from public, anon, authenticated;
grant execute on function public.finish_onboarding_step(text) to authenticated;

create function public.mark_first_home_seen()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  p public.profiles := private.me();
begin
  update public.profiles set first_home_seen_at = coalesce(first_home_seen_at, now()), updated_at = now()
   where id = p.id;
end;
$$;

revoke all on function public.mark_first_home_seen() from public, anon, authenticated;
grant execute on function public.mark_first_home_seen() to authenticated;

-- GI-13 "Keep my account".
create function public.keep_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  p public.profiles := private.me();
begin
  if p.account_status = 'deletion_scheduled' and p.deletion_scheduled_for > now() then
    update public.profiles
       set account_status = 'active', deletion_scheduled_for = null, updated_at = now()
     where id = p.id;
  end if;
end;
$$;

revoke all on function public.keep_my_account() from public, anon, authenticated;
grant execute on function public.keep_my_account() to authenticated;

-- ---------------------------------------------------------------------------------------------
-- Teens who turn 18 no longer need a parent (GI-45), and requests older than 7 days expire (GI-44). Daily.
create function private.daily_age_and_consent()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.parent_consent_requests set status = 'expired'
   where status = 'pending' and expires_at <= now();
  update public.profiles p set parent_consent = 'expired', updated_at = now()
   where p.parent_consent = 'pending'
     and not exists (select 1 from public.parent_consent_requests r where r.teen_id = p.id and r.status = 'pending');
  update public.profiles
     set age_band = '18+', parent_consent = 'not_needed',
         onboarding_step = case when onboarding_step = 'parent' then 'data_consent' else onboarding_step end,
         updated_at = now()
   where age_band = '13-17' and private.age_from(birth_year, birth_month) >= 18;
end;
$$;

revoke all on function private.daily_age_and_consent() from public, anon, authenticated;

do $cron$
begin
  create extension if not exists pg_cron;
  -- 00:15 IST
  perform cron.schedule('daily-age-and-consent', '45 18 * * *', 'select private.daily_age_and_consent()');
exception when others then
  raise notice 'pg_cron not available here (%), the daily job is not scheduled', sqlerrm;
end
$cron$;

-- ---------------------------------------------------------------------------------------------
-- The minimum app version (GI-15), readable by anyone; changed by the server only.
create table private.app_config (
  key text primary key,
  value jsonb not null
);

insert into private.app_config (key, value)
values ('min_version', '{"android": "0.1.0", "ios": "0.1.0"}');

create function public.app_requirements()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object('min_version', coalesce((select value from private.app_config where key = 'min_version'),
                                                    '{}'::jsonb))
$$;

revoke all on function public.app_requirements() from public, anon, authenticated;
grant execute on function public.app_requirements() to anon, authenticated;
