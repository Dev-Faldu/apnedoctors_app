-- Pro sign-up (PR0–PR5 · P1–P4): doctors, pharmacies, labs, hospitals and clinics apply, upload their documents to
-- a private bucket, and the verification team decides. Pro is a role added to the same account (one person, one
-- account). Clients never set a status or a role: the functions below check the rules, and deciding is server-only.

create table public.pro_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  kind text not null check (kind in ('doctor', 'pharmacy', 'lab', 'hospital')),
  status text not null default 'draft'
    check (status in ('draft', 'submitted', 'checking', 'needs_changes', 'approved', 'rejected')),
  details jsonb not null default '{}'::jsonb check (jsonb_typeof(details) = 'object'),
  -- needs changes: only these fields (or document kinds) may be edited before resubmitting
  fix_fields text[] not null default '{}',
  reason text check (reason is null or char_length(reason) between 1 and 500),
  submitted_at timestamptz,
  decided_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, kind)
);

create table public.pro_documents (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null references public.pro_applications (id) on delete cascade,
  kind text not null check (kind in ('certificate', 'government_id', 'selfie')),
  storage_path text not null unique,
  mime text not null check (mime in ('application/pdf', 'image/jpeg', 'image/png')),
  bytes int not null check (bytes between 1 and 10485760),
  uploaded_at timestamptz not null default now()
);

create table public.user_roles (
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null check (role in ('doctor', 'pharmacy', 'lab', 'hospital')),
  granted_at timestamptz not null default now(),
  primary key (user_id, role)
);

alter table public.pro_applications enable row level security;
alter table public.pro_documents enable row level security;
alter table public.user_roles enable row level security;
revoke all on table public.pro_applications, public.pro_documents, public.user_roles from public, anon, authenticated;
grant select on table public.pro_applications, public.pro_documents, public.user_roles to authenticated;

create policy "applicants read their own applications"
  on public.pro_applications for select to authenticated
  using (user_id = (select auth.uid()));

create policy "applicants read their own documents"
  on public.pro_documents for select to authenticated
  using (exists (select 1 from public.pro_applications a
                 where a.id = application_id and a.user_id = (select auth.uid())));

create policy "people read their own roles"
  on public.user_roles for select to authenticated
  using (user_id = (select auth.uid()));

-- ---------------------------------------------------------------------------------------------
-- What each kind of partner tells us (PR3). pattern: a regular expression the value must match.
create function private.pro_fields(p_kind text)
returns table (field text, required boolean, pattern text)
language sql
immutable
set search_path = ''
as $$
  select f.field, f.required, f.pattern
  from (values
    ('doctor',   'full_name',               true,  '^.{2,120}$'),
    ('doctor',   'council',                 true,  '^.{2,80}$'),
    ('doctor',   'registration_number',     true,  '^[A-Za-z0-9/ .-]{3,24}$'),
    ('doctor',   'registration_year',       true,  '^(19[5-9][0-9]|20[0-9][0-9])$'),
    ('doctor',   'speciality',              true,  '^.{2,80}$'),
    ('doctor',   'hpr_id',                  false, '^[0-9]{14}$'),
    ('pharmacy', 'store_name',              true,  '^.{2,120}$'),
    ('pharmacy', 'drug_licence_20',         true,  '^[A-Za-z0-9/ .-]{3,40}$'),
    ('pharmacy', 'drug_licence_21',         true,  '^[A-Za-z0-9/ .-]{3,40}$'),
    ('pharmacy', 'gstin',                   true,  '^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$'),
    ('pharmacy', 'pharmacist_registration', true,  '^[A-Za-z0-9/ .-]{3,40}$'),
    ('lab',      'lab_name',                true,  '^.{2,120}$'),
    ('lab',      'licence',                 true,  '^[A-Za-z0-9/ .-]{3,40}$'),
    ('lab',      'nabl_number',             false, '^[A-Za-z0-9/ .-]{3,40}$'),
    ('hospital', 'name',                    true,  '^.{2,120}$'),
    ('hospital', 'hfr_id',                  false, '^[A-Za-z0-9]{8,20}$'),
    ('hospital', 'registration_number',     true,  '^[A-Za-z0-9/ .-]{3,40}$'),
    ('hospital', 'contact_person',          true,  '^.{2,80}$')
  ) as f(kind, field, required, pattern)
  where f.kind = p_kind
$$;

revoke all on function private.pro_fields(text) from public, anon, authenticated;

-- Raises field_unknown / field_invalid (detail = the field) for the given values.
create function private.check_pro_values(p_kind text, p_values jsonb)
returns void
language plpgsql
stable
set search_path = ''
as $$
declare
  k text;
  v jsonb;
  pat text;
begin
  for k, v in select key, value from jsonb_each(p_values) loop
    select f.pattern into pat from private.pro_fields(p_kind) f where f.field = k;
    if pat is null then
      raise exception 'field_unknown' using errcode = '22023', detail = k;
    end if;
    if jsonb_typeof(v) = 'null' then
      continue;
    end if;
    if jsonb_typeof(v) <> 'string' or btrim(v #>> '{}') !~ pat then
      raise exception 'field_invalid' using errcode = '22023', detail = k;
    end if;
  end loop;
end;
$$;

revoke all on function private.check_pro_values(text, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------------------------------
-- PR3: save details (a draft, or the fields that need changes). Null removes an optional field.
create function public.save_pro_application(kind text, details jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  p public.profiles := private.me();
  app public.pro_applications;
  k text;
  merged jsonb;
begin
  if save_pro_application.kind not in ('doctor', 'pharmacy', 'lab', 'hospital') then
    raise exception 'kind_unknown' using errcode = '22023';
  end if;
  if save_pro_application.details is null or jsonb_typeof(save_pro_application.details) <> 'object' then
    raise exception 'field_invalid' using errcode = '22023';
  end if;
  perform private.check_pro_values(save_pro_application.kind, save_pro_application.details);

  select * into app from public.pro_applications
   where user_id = p.id and pro_applications.kind = save_pro_application.kind for update;

  if app.id is null then
    insert into public.pro_applications (user_id, kind) values (p.id, save_pro_application.kind)
    returning * into app;
  elsif app.status not in ('draft', 'needs_changes') then
    raise exception 'application_locked' using errcode = '42501';
  elsif app.status = 'needs_changes' then
    for k in select jsonb_object_keys(save_pro_application.details) loop
      if not (k = any (app.fix_fields)) and (app.details -> k) is distinct from (save_pro_application.details -> k) then
        raise exception 'field_locked' using errcode = '42501', detail = k;
      end if;
    end loop;
  end if;

  merged := jsonb_strip_nulls(app.details || save_pro_application.details);
  update public.pro_applications set details = merged, updated_at = now() where id = app.id;
  return jsonb_build_object('id', app.id, 'kind', app.kind, 'status', app.status);
end;
$$;

revoke all on function public.save_pro_application(text, jsonb) from public, anon, authenticated;
grant execute on function public.save_pro_application(text, jsonb) to authenticated;

-- PR4: after uploading a file to pro-docs/<your id>/..., attach it to the application.
create function public.attach_pro_document(application_id uuid, kind text, storage_path text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  p public.profiles := private.me();
  app public.pro_applications;
  obj record;
  doc_id uuid;
begin
  select * into app from public.pro_applications where id = attach_pro_document.application_id for update;
  if app.id is null or app.user_id <> p.id then
    raise exception 'application_not_found' using errcode = 'P0002';
  end if;
  if app.status not in ('draft', 'needs_changes') then
    raise exception 'application_locked' using errcode = '42501';
  end if;
  if app.status = 'needs_changes' and not (attach_pro_document.kind = any (app.fix_fields)) then
    raise exception 'field_locked' using errcode = '42501', detail = attach_pro_document.kind;
  end if;
  if attach_pro_document.kind not in ('certificate', 'government_id', 'selfie') then
    raise exception 'document_kind_unknown' using errcode = '22023';
  end if;
  if split_part(attach_pro_document.storage_path, '/', 1) <> p.id::text then
    raise exception 'document_not_yours' using errcode = '42501';
  end if;

  select o.metadata into obj from storage.objects o
   where o.bucket_id = 'pro-docs' and o.name = attach_pro_document.storage_path;
  if obj.metadata is null then
    raise exception 'document_not_uploaded' using errcode = 'P0002';
  end if;

  insert into public.pro_documents (application_id, kind, storage_path, mime, bytes)
  values (app.id, attach_pro_document.kind, attach_pro_document.storage_path,
          obj.metadata ->> 'mimetype', (obj.metadata ->> 'size')::int)
  returning id into doc_id;
  update public.pro_applications set updated_at = now() where id = app.id;
  return doc_id;
exception
  when check_violation then
    raise exception 'document_invalid' using errcode = '22023';
end;
$$;

revoke all on function public.attach_pro_document(uuid, text, text) from public, anon, authenticated;
grant execute on function public.attach_pro_document(uuid, text, text) to authenticated;

-- PR4 → PR5: everything required is there, so it goes to the verification team.
create function public.submit_pro_application(application_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  p public.profiles := private.me();
  app public.pro_applications;
  missing text;
begin
  select * into app from public.pro_applications where id = submit_pro_application.application_id for update;
  if app.id is null or app.user_id <> p.id then
    raise exception 'application_not_found' using errcode = 'P0002';
  end if;
  if app.status not in ('draft', 'needs_changes') then
    raise exception 'application_locked' using errcode = '42501';
  end if;

  select f.field into missing from private.pro_fields(app.kind) f
   where f.required and coalesce(btrim(app.details ->> f.field), '') = ''
   limit 1;
  if missing is not null then
    raise exception 'field_missing' using errcode = '22023', detail = missing;
  end if;

  select d.kind into missing from (values ('certificate'), ('government_id'), ('selfie')) as d(kind)
   where not exists (select 1 from public.pro_documents x where x.application_id = app.id and x.kind = d.kind)
   limit 1;
  if missing is not null then
    raise exception 'document_missing' using errcode = '22023', detail = missing;
  end if;

  update public.pro_applications
     set status = 'submitted', submitted_at = now(), fix_fields = '{}', reason = null, updated_at = now()
   where id = app.id;
  return jsonb_build_object('id', app.id, 'status', 'submitted');
end;
$$;

revoke all on function public.submit_pro_application(uuid) from public, anon, authenticated;
grant execute on function public.submit_pro_application(uuid) to authenticated;

-- Server only: the verification team's decision. Approval adds the role.
create function private.decide_pro_application(application_id uuid, decision text, reason text default null,
                                               fix_fields text[] default '{}')
returns void
language plpgsql
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  app public.pro_applications;
begin
  select * into app from public.pro_applications where id = decide_pro_application.application_id for update;
  if app.id is null or app.status not in ('submitted', 'checking') then
    raise exception 'application_not_open' using errcode = '22023';
  end if;
  if decide_pro_application.decision not in ('checking', 'needs_changes', 'approved', 'rejected') then
    raise exception 'decision_unknown' using errcode = '22023';
  end if;
  if decide_pro_application.decision in ('needs_changes', 'rejected') and coalesce(btrim(decide_pro_application.reason), '') = '' then
    raise exception 'reason_needed' using errcode = '22023';
  end if;
  if decide_pro_application.decision = 'needs_changes' and cardinality(decide_pro_application.fix_fields) = 0 then
    raise exception 'fix_fields_needed' using errcode = '22023';
  end if;

  update public.pro_applications set
    status = decide_pro_application.decision,
    reason = case when decide_pro_application.decision in ('needs_changes', 'rejected') then decide_pro_application.reason end,
    fix_fields = case when decide_pro_application.decision = 'needs_changes' then decide_pro_application.fix_fields else '{}' end,
    decided_at = case when decide_pro_application.decision = 'checking' then null else now() end,
    updated_at = now()
  where id = app.id;

  if decide_pro_application.decision = 'approved' then
    insert into public.user_roles (user_id, role) values (app.user_id, app.kind) on conflict do nothing;
  end if;
end;
$$;

revoke all on function private.decide_pro_application(uuid, text, text, text[]) from public, anon, authenticated;

-- Patient or pro mode (GI-09). Pro mode needs an approved role.
create function public.set_mode(mode text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  p public.profiles := private.me();
begin
  if mode not in ('patient', 'pro') then
    raise exception 'mode_unknown' using errcode = '22023';
  end if;
  if mode = 'pro' and not exists (select 1 from public.user_roles r where r.user_id = p.id) then
    raise exception 'not_a_pro' using errcode = '42501';
  end if;
  update public.profiles set last_mode = mode, updated_at = now() where id = p.id;
end;
$$;

revoke all on function public.set_mode(text) from public, anon, authenticated;
grant execute on function public.set_mode(text) to authenticated;

-- ---------------------------------------------------------------------------------------------
-- Everything the launch router needs, in one call (docs/product/specs/getting-in.md, section 1).
-- Works for suspended accounts too, so the app can show "Account on hold" instead of failing.
create function public.my_launch_state()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  me uuid := (select auth.uid());
  p public.profiles;
  app record;
begin
  if me is null then
    raise exception 'Sign in first.' using errcode = '42501';
  end if;
  select * into p from public.profiles where id = me;
  if p.id is null then
    return null;
  end if;
  select a.id, a.kind, a.status, a.reason, a.fix_fields into app
    from public.pro_applications a where a.user_id = me order by a.updated_at desc limit 1;
  return jsonb_build_object(
    'first_name', p.first_name,
    'onboarding_step', p.onboarding_step,
    'age_band', p.age_band,
    'parent_consent', p.parent_consent,
    'account_status', p.account_status,
    'deletion_scheduled_for', p.deletion_scheduled_for,
    'suspended_reason', p.suspended_reason,
    'blocked_until', p.blocked_until,
    'first_home_seen', p.first_home_seen_at is not null,
    'last_mode', p.last_mode,
    'roles', coalesce((select jsonb_agg(r.role order by r.role) from public.user_roles r where r.user_id = me), '[]'::jsonb),
    'pro_application', case when app.id is null then null
                            else jsonb_build_object('id', app.id, 'kind', app.kind, 'status', app.status,
                                                    'reason', app.reason, 'fix_fields', to_jsonb(app.fix_fields)) end
  );
end;
$$;

revoke all on function public.my_launch_state() from public, anon, authenticated;
grant execute on function public.my_launch_state() to authenticated;

-- ---------------------------------------------------------------------------------------------
-- The private pro-docs bucket: 10 MB, PDF / JPG / PNG, each person in their own folder.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('pro-docs', 'pro-docs', false, 10485760, array['application/pdf', 'image/jpeg', 'image/png'])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit,
                               allowed_mime_types = excluded.allowed_mime_types;

create policy "pro docs: people upload into their own folder"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'pro-docs' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "pro docs: people read their own files"
  on storage.objects for select to authenticated
  using (bucket_id = 'pro-docs' and (storage.foldername(name))[1] = (select auth.uid())::text);
