-- Verified doctors and who is online right now (the live count on Welcome).
--
-- Clients never touch these tables directly. Anyone may ask how many verified doctors are online
-- (public.doctors_online); a verified doctor may say they are here or away (public.set_doctor_presence).
-- Doctors are added and verified by the verification process with the service role only.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- ---------------------------------------------------------------------------------------------
-- Directory of doctors. A row is visible to the app only through the functions below.
create table public.doctors (
  id uuid primary key default gen_random_uuid(),
  -- the doctor's own ApneDoctors account, once they have one
  user_id uuid unique references auth.users (id) on delete set null,
  full_name text not null check (char_length(btrim(full_name)) between 2 and 120),
  -- ABDM Healthcare Professionals Registry ID: 14 digits, stored without dashes
  hpr_id text not null unique check (hpr_id ~ '^[0-9]{14}$'),
  -- set only after the doctor's registration has been checked; never by the app
  verified_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.doctors enable row level security;
revoke all on table public.doctors from public, anon, authenticated;
grant select on table public.doctors to authenticated;

create policy "a doctor can read their own directory entry"
  on public.doctors for select to authenticated
  using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------------------------------
-- Presence: a verified doctor's last "I'm here". Online means seen in the last 2 minutes;
-- the doctor's app says so every minute while they are available.
create table public.doctor_presence (
  doctor_id uuid primary key references public.doctors (id) on delete cascade,
  last_seen_at timestamptz not null default now()
);

alter table public.doctor_presence enable row level security;
revoke all on table public.doctor_presence from public, anon, authenticated;

create index doctor_presence_last_seen_at on public.doctor_presence (last_seen_at desc);

-- ---------------------------------------------------------------------------------------------
-- Initials for a doctor's face on the chip: first and last name, without a leading "Dr".
create function private.initials(full_name text)
returns text
language sql
immutable
set search_path = ''
as $$
  with w as (
    select array_remove(
      regexp_split_to_array(btrim(regexp_replace(full_name, '^\s*dr\.?\s+', '', 'i')), '\s+'),
      ''
    ) as parts
  )
  select upper(
    left(parts[1], 1)
    || case when cardinality(parts) > 1 then left(parts[cardinality(parts)], 1) else '' end
  )
  from w;
$$;

revoke all on function private.initials(text) from public, anon, authenticated;

-- ---------------------------------------------------------------------------------------------
-- How many verified doctors are online now, and up to three of them (initials only), newest first.
-- Returns {"count": 0, "faces": []} when nobody is online: the app then shows no chip.
create function public.doctors_online()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with live as (
    select d.id, d.full_name, p.last_seen_at
    from public.doctor_presence p
    join public.doctors d on d.id = p.doctor_id
    where d.verified_at is not null
      and p.last_seen_at > now() - interval '2 minutes'
  ),
  faces as (
    select id, last_seen_at, private.initials(full_name) as initials
    from live
    order by last_seen_at desc, id
    limit 3
  )
  select jsonb_build_object(
    'count', (select count(*) from live),
    'faces', coalesce(
      (select jsonb_agg(jsonb_build_object('id', id, 'initials', initials) order by last_seen_at desc, id) from faces),
      '[]'::jsonb
    )
  );
$$;

revoke all on function public.doctors_online() from public, anon, authenticated;
grant execute on function public.doctors_online() to anon, authenticated;

-- ---------------------------------------------------------------------------------------------
-- A verified doctor says they are here (online = true, every minute) or away (online = false).
create function public.set_doctor_presence(online boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  doctor uuid;
begin
  if me is null then
    raise exception 'Sign in first.' using errcode = '42501';
  end if;

  select id into doctor
  from public.doctors
  where user_id = me and verified_at is not null;

  if doctor is null then
    raise exception 'Only verified doctors can go online.' using errcode = '42501';
  end if;

  if online then
    insert into public.doctor_presence (doctor_id, last_seen_at)
    values (doctor, now())
    on conflict (doctor_id) do update set last_seen_at = excluded.last_seen_at;
  else
    delete from public.doctor_presence where doctor_id = doctor;
  end if;
end;
$$;

revoke all on function public.set_doctor_presence(boolean) from public, anon, authenticated;
grant execute on function public.set_doctor_presence(boolean) to authenticated;
