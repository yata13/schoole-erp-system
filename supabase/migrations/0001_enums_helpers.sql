-- 0001_enums_helpers.sql
-- Enums, shared domains, the "private" schema, and the row-stamp trigger
-- (created_at / updated_at / created_by) that every table uses.

-- Internal functions live in "private". It is not exposed by the API.
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
create type public.app_role as enum
  ('super_admin', 'director', 'registrar', 'teacher', 'finance', 'student', 'parent');
create type public.academic_year_status as enum ('planning', 'active', 'closed');
create type public.semester_status      as enum ('open', 'closed');
create type public.stream               as enum ('natural', 'social');
create type public.gender               as enum ('M', 'F');
create type public.student_status       as enum ('active', 'transferred_out', 'graduated', 'dropped');
create type public.enrollment_status    as enum ('active', 'transferred_out', 'dropped', 'completed');
create type public.year_result          as enum ('promoted', 'repeat', 'graduated');
create type public.guardian_relationship as enum ('father', 'mother', 'guardian', 'other');
create type public.staff_position       as enum ('teacher', 'director', 'registrar', 'cashier', 'librarian', 'other');
create type public.staff_status         as enum ('active', 'left');
create type public.transfer_direction   as enum ('in', 'out');
create type public.promotion_status     as enum ('preview', 'done', 'undone');
create type public.import_status        as enum ('checking', 'ready', 'done', 'failed');
create type public.date_display         as enum ('ec', 'gc');

-- ---------------------------------------------------------------------------
-- Domains
-- ---------------------------------------------------------------------------
-- Ethiopian phone number, stored as +251 and 9 digits (the app formats input).
create domain public.phone_et as text
  check (value ~ '^\+251[1-9][0-9]{8}$');

create domain public.locale_code as text
  check (value in ('en', 'am'));

-- ---------------------------------------------------------------------------
-- Row stamp: fills created_at / updated_at / created_by and keeps them honest.
-- * INSERT: created_by is the signed-in user's profile (or what server code
--   passed in when there is no signed-in user, e.g. the service key).
-- * UPDATE: created_at / created_by cannot change; school_id cannot change.
-- SECURITY DEFINER so it can read profiles whatever the caller's RLS is.
-- ---------------------------------------------------------------------------
create or replace function private.stamp_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.created_at := now();
    new.updated_at := new.created_at;
    if auth.uid() is not null then
      new.created_by := (select p.id from public.profiles p where p.id = auth.uid());
    end if;
  else
    new.created_at := old.created_at;
    new.created_by := old.created_by;
    new.updated_at := now();
    if tg_table_name <> 'schools' and new.school_id is distinct from old.school_id then
      raise exception 'school_id cannot be changed on %', tg_table_name
        using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;

revoke execute on function private.stamp_row() from public;
