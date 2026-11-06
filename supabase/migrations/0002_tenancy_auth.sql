-- 0002_tenancy_auth.sql
-- Schools (the tenant), logins, roles, platform admins, number sequences,
-- the audit log table, the RLS helper functions and the login-token hook.
--
-- Multi-school rules used in every migration:
-- * Every UNIQUE rule includes school_id (except schools.code, which is the
--   school's own global login code, and plain uuid primary keys).
-- * Every table that other tables point at has UNIQUE (school_id, id), and
--   foreign keys are composite: (school_id, x_id) -> x (school_id, id).
--   So a row can never point at another school's row.
-- * school_id leads every composite index, so the "school_id = my school"
--   filter that RLS adds to every query can use the index.

-- ---------------------------------------------------------------------------
-- schools: one row per school. Has no school_id.
-- ---------------------------------------------------------------------------
create table public.schools (
  id               uuid primary key default gen_random_uuid(),
  code             text not null,
  name             text not null,
  name_am          text,
  phone            public.phone_et,
  address          text,
  logo_path        text,
  pass_mark        numeric(5, 2) not null default 50,
  max_section_size int not null default 50,
  default_locale   public.locale_code not null default 'en',
  is_active        boolean not null default true,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  created_by       uuid,
  constraint schools_code_key unique (code),
  constraint schools_code_format check (code ~ '^[A-Z][A-Z0-9]{1,9}$'),
  constraint schools_pass_mark_range check (pass_mark between 0 and 100),
  constraint schools_max_section_size_range check (max_section_size between 1 and 200)
);

-- ---------------------------------------------------------------------------
-- profiles: one login account per person, linked to auth.users.
-- ---------------------------------------------------------------------------
create table public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  school_id     uuid not null references public.schools (id),
  login_id      text not null,
  full_name     text not null,
  full_name_am  text,
  phone         public.phone_et,
  locale        public.locale_code not null default 'en',
  date_display  public.date_display not null default 'ec',
  is_active     boolean not null default true,
  last_login_at timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  created_by    uuid references public.profiles (id) on delete set null,
  constraint profiles_school_login_id_key unique (school_id, login_id),
  constraint profiles_school_id_id_key unique (school_id, id),
  -- Student IDs are upper case and phones have no letters, so one spelling only.
  constraint profiles_login_id_format check (login_id = upper(btrim(login_id)) and login_id <> '')
);
create index profiles_created_by_idx on public.profiles (created_by);

alter table public.schools
  add constraint schools_created_by_fkey
  foreign key (created_by) references public.profiles (id) on delete set null;
create index schools_created_by_idx on public.schools (created_by);

-- ---------------------------------------------------------------------------
-- user_roles: one user can have more than one role.
-- ---------------------------------------------------------------------------
create table public.user_roles (
  school_id  uuid not null references public.schools (id),
  user_id    uuid not null,
  role       public.app_role not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.profiles (id) on delete set null,
  constraint user_roles_pkey primary key (school_id, user_id, role),
  constraint user_roles_user_fkey foreign key (school_id, user_id)
    references public.profiles (school_id, id) on delete cascade
);
create index user_roles_created_by_idx on public.user_roles (created_by);

-- ---------------------------------------------------------------------------
-- platform_admins: Sefed Studio staff. Create schools. Not inside any school.
-- ---------------------------------------------------------------------------
create table public.platform_admins (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- number_sequences: next student ID, invoice no., receipt no.
-- One row per (school, kind, E.C. year); bumped with a single upsert, so two
-- people saving at the same moment can never get the same number.
-- ---------------------------------------------------------------------------
create table public.number_sequences (
  school_id  uuid not null references public.schools (id),
  name       text not null,
  year       int not null,
  last_value int not null default 0,
  updated_at timestamptz not null default now(),
  constraint number_sequences_pkey primary key (school_id, name, year),
  constraint number_sequences_name_check check (name in ('student', 'invoice', 'receipt')),
  constraint number_sequences_last_value_check check (last_value >= 0)
);

-- ---------------------------------------------------------------------------
-- audit_log: who changed what. Insert only (see 0006).
-- changed_by is the auth user id. It has no foreign key on purpose: an audit
-- row must never be blocked, and platform admins have no profile.
-- ---------------------------------------------------------------------------
create table public.audit_log (
  id         bigint generated always as identity primary key,
  school_id  uuid not null references public.schools (id),
  table_name text not null,
  record_id  uuid,
  action     text not null,
  old_data   jsonb,
  new_data   jsonb,
  changed_by uuid,
  changed_at timestamptz not null default now(),
  constraint audit_log_action_check
    check (action in ('insert', 'update', 'delete', 'soft_delete', 'restore'))
);
create index audit_log_school_changed_at_idx on public.audit_log (school_id, changed_at desc);
create index audit_log_school_record_idx on public.audit_log (school_id, table_name, record_id);

-- ---------------------------------------------------------------------------
-- Stamp triggers
-- ---------------------------------------------------------------------------
create trigger schools_stamp before insert or update on public.schools
  for each row execute function private.stamp_row();
create trigger profiles_stamp before insert or update on public.profiles
  for each row execute function private.stamp_row();
create trigger user_roles_stamp before insert or update on public.user_roles
  for each row execute function private.stamp_row();

-- ---------------------------------------------------------------------------
-- RLS helpers. Policies call them as (select fn()) so Postgres runs each one
-- once per query, not once per row.
-- school_id and user_roles come from the login token (custom_access_token_hook).
-- ---------------------------------------------------------------------------
create or replace function public.current_school_id()
returns uuid
language sql
stable
set search_path = ''
as $$
  select nullif(auth.jwt() ->> 'school_id', '')::uuid
$$;

create or replace function public.has_role(p_role public.app_role)
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce((auth.jwt() -> 'user_roles') ? p_role::text, false)
$$;

create or replace function public.has_any_role(p_roles public.app_role[])
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce((auth.jwt() -> 'user_roles') ?| p_roles::text[], false)
$$;

create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (select 1 from public.platform_admins pa where pa.user_id = auth.uid())
$$;

-- True when the login belongs only to students and/or parents.
-- Lets a registrar manage those logins and nobody else's.
create or replace function private.login_is_student_or_parent(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
           select 1 from public.user_roles ur
           where ur.user_id = p_user_id and ur.role in ('student', 'parent'))
     and not exists (
           select 1 from public.user_roles ur
           where ur.user_id = p_user_id and ur.role not in ('student', 'parent'))
$$;

-- ---------------------------------------------------------------------------
-- A user may not change their own login_id or switch themselves on/off.
-- (RLS decides WHICH rows can be updated; this decides which columns.)
-- ---------------------------------------------------------------------------
create or replace function private.guard_profile_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if auth.uid() is not null
     and old.id = auth.uid()
     and not public.has_role('super_admin')
     and (new.login_id is distinct from old.login_id or new.is_active is distinct from old.is_active)
  then
    raise exception 'You cannot change your own login ID or active status'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

create trigger profiles_guard_update before update on public.profiles
  for each row execute function private.guard_profile_update();

-- ---------------------------------------------------------------------------
-- next_number(): AHS-19-0001 style student IDs, INV-/RCP- numbers later.
-- Internal: called by triggers, not by the app.
-- ---------------------------------------------------------------------------
create or replace function private.next_number(p_school_id uuid, p_kind text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code  text;
  v_year  int;
  v_value int;
begin
  select s.code into v_code from public.schools s where s.id = p_school_id;
  if v_code is null then
    raise exception 'Unknown school %', p_school_id using errcode = '23503';
  end if;

  select ay.ec_year into v_year
  from public.academic_years ay
  where ay.school_id = p_school_id and ay.is_current;
  if v_year is null then
    raise exception 'Set a current academic year before creating % numbers', p_kind
      using errcode = '23514';
  end if;

  insert into public.number_sequences as ns (school_id, name, year, last_value)
  values (p_school_id, p_kind, v_year, 1)
  on conflict (school_id, name, year)
    do update set last_value = ns.last_value + 1, updated_at = now()
  returning ns.last_value into v_value;

  return case p_kind
    when 'student' then format('%s-%s-%s', v_code, lpad((v_year % 100)::text, 2, '0'),
                               lpad(v_value::text, greatest(4, length(v_value::text)), '0'))
    when 'invoice' then format('INV-%s-%s', v_year, lpad(v_value::text, greatest(6, length(v_value::text)), '0'))
    when 'receipt' then format('RCP-%s-%s', v_year, lpad(v_value::text, greatest(6, length(v_value::text)), '0'))
  end;
end;
$$;

-- ---------------------------------------------------------------------------
-- custom_access_token_hook: puts school_id and the user's roles into the
-- login token. An inactive login or school gets no school and no roles, so
-- every RLS rule refuses it.
-- Enabled in supabase/config.toml ([auth.hook.custom_access_token]) and, on
-- the hosted project, under Authentication > Hooks.
-- ---------------------------------------------------------------------------
create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
set search_path = ''
as $$
declare
  v_user_id   uuid := (event ->> 'user_id')::uuid;
  v_claims    jsonb := coalesce(event -> 'claims', '{}'::jsonb);
  v_school_id uuid;
  v_roles     jsonb;
begin
  select p.school_id into v_school_id
  from public.profiles p
  join public.schools s on s.id = p.school_id
  where p.id = v_user_id and p.is_active and s.is_active;

  if v_school_id is null then
    v_claims := (v_claims - 'school_id') || jsonb_build_object('user_roles', '[]'::jsonb);
  else
    select coalesce(jsonb_agg(ur.role::text order by ur.role), '[]'::jsonb)
      into v_roles
    from public.user_roles ur
    where ur.school_id = v_school_id and ur.user_id = v_user_id;

    v_claims := v_claims || jsonb_build_object('school_id', v_school_id, 'user_roles', v_roles);
  end if;

  return jsonb_set(event, '{claims}', v_claims);
end;
$$;

grant usage on schema public to supabase_auth_admin;
grant execute on function public.custom_access_token_hook(jsonb) to supabase_auth_admin;
revoke execute on function public.custom_access_token_hook(jsonb) from public, anon, authenticated;
grant select on table public.schools, public.profiles, public.user_roles to supabase_auth_admin;

revoke execute on function private.next_number(uuid, text) from public;
revoke execute on function private.guard_profile_update() from public;
revoke execute on function private.login_is_student_or_parent(uuid) from public;
grant execute on function private.login_is_student_or_parent(uuid) to authenticated;
