-- 0004_people.sql
-- Staff, students, guardians, student_guardians, and the "who am I" helpers
-- that RLS uses for teacher / student / parent rows.

-- ---------------------------------------------------------------------------
-- staff: teachers and other workers (more columns in Phase 3).
-- ---------------------------------------------------------------------------
create table public.staff (
  id               uuid primary key default gen_random_uuid(),
  school_id        uuid not null references public.schools (id),
  profile_id       uuid,
  staff_code       text not null,
  first_name       text not null,
  father_name      text not null,
  grandfather_name text,
  gender           public.gender not null,
  phone            public.phone_et,
  position         public.staff_position not null default 'teacher',
  hire_date        date,
  photo_path       text,
  status           public.staff_status not null default 'active',
  deleted_at       timestamptz,
  deleted_by       uuid references public.profiles (id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  created_by       uuid references public.profiles (id) on delete set null,
  constraint staff_school_staff_code_key unique (school_id, staff_code),
  constraint staff_school_profile_key unique (school_id, profile_id),
  constraint staff_school_id_id_key unique (school_id, id),
  constraint staff_code_format check (staff_code = upper(btrim(staff_code)) and staff_code <> ''),
  constraint staff_profile_fkey foreign key (school_id, profile_id)
    references public.profiles (school_id, id) on delete set null (profile_id)
);
create index staff_created_by_idx on public.staff (created_by);
create index staff_deleted_by_idx on public.staff (deleted_by);

alter table public.sections
  add constraint sections_homeroom_teacher_fkey foreign key (school_id, homeroom_teacher_id)
  references public.staff (school_id, id) on delete set null (homeroom_teacher_id);
create index sections_school_homeroom_teacher_idx on public.sections (school_id, homeroom_teacher_id);

-- ---------------------------------------------------------------------------
-- students: one row per student, kept for life. student_code is filled from
-- number_sequences when left empty (AHS-19-0001).
-- ---------------------------------------------------------------------------
create table public.students (
  id                  uuid primary key default gen_random_uuid(),
  school_id           uuid not null references public.schools (id),
  student_code        text not null,
  profile_id          uuid,
  first_name          text not null,
  father_name         text not null,
  grandfather_name    text,
  first_name_am       text,
  father_name_am      text,
  grandfather_name_am text,
  gender              public.gender not null,
  birth_date          date,
  photo_path          text,
  phone               public.phone_et,
  sub_city            text,
  woreda              text,
  kebele              text,
  previous_school     text,
  admission_date      date not null default current_date,
  status              public.student_status not null default 'active',
  deleted_at          timestamptz,
  deleted_by          uuid references public.profiles (id) on delete set null,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  created_by          uuid references public.profiles (id) on delete set null,
  constraint students_school_student_code_key unique (school_id, student_code),
  constraint students_school_profile_key unique (school_id, profile_id),
  constraint students_school_id_id_key unique (school_id, id),
  constraint students_code_format check (student_code = upper(btrim(student_code)) and student_code <> ''),
  constraint students_profile_fkey foreign key (school_id, profile_id)
    references public.profiles (school_id, id) on delete set null (profile_id)
);
create index students_created_by_idx on public.students (created_by);
create index students_deleted_by_idx on public.students (deleted_by);

-- ---------------------------------------------------------------------------
-- guardians: parents and guardians. phone is unique per school (parent login).
-- ---------------------------------------------------------------------------
create table public.guardians (
  id           uuid primary key default gen_random_uuid(),
  school_id    uuid not null references public.schools (id),
  profile_id   uuid,
  full_name    text not null,
  full_name_am text,
  phone        public.phone_et not null,
  alt_phone    public.phone_et,
  occupation   text,
  deleted_at   timestamptz,
  deleted_by   uuid references public.profiles (id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  created_by   uuid references public.profiles (id) on delete set null,
  constraint guardians_school_phone_key unique (school_id, phone),
  constraint guardians_school_profile_key unique (school_id, profile_id),
  constraint guardians_school_id_id_key unique (school_id, id),
  constraint guardians_profile_fkey foreign key (school_id, profile_id)
    references public.profiles (school_id, id) on delete set null (profile_id)
);
create index guardians_created_by_idx on public.guardians (created_by);
create index guardians_deleted_by_idx on public.guardians (deleted_by);

-- ---------------------------------------------------------------------------
-- student_guardians: students <-> guardians (many to many).
-- ---------------------------------------------------------------------------
create table public.student_guardians (
  school_id    uuid not null references public.schools (id),
  student_id   uuid not null,
  guardian_id  uuid not null,
  relationship public.guardian_relationship not null,
  is_primary   boolean not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  created_by   uuid references public.profiles (id) on delete set null,
  constraint student_guardians_pkey primary key (school_id, student_id, guardian_id),
  constraint student_guardians_student_fkey foreign key (school_id, student_id)
    references public.students (school_id, id),
  constraint student_guardians_guardian_fkey foreign key (school_id, guardian_id)
    references public.guardians (school_id, id)
);
create index student_guardians_school_guardian_idx on public.student_guardians (school_id, guardian_id);
create index student_guardians_created_by_idx on public.student_guardians (created_by);
-- At most one main contact per student.
create unique index student_guardians_one_primary_idx
  on public.student_guardians (school_id, student_id) where is_primary;

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------
create trigger staff_stamp before insert or update on public.staff
  for each row execute function private.stamp_row();
create trigger students_stamp before insert or update on public.students
  for each row execute function private.stamp_row();
create trigger guardians_stamp before insert or update on public.guardians
  for each row execute function private.stamp_row();
create trigger student_guardians_stamp before insert or update on public.student_guardians
  for each row execute function private.stamp_row();

-- Fill student_code when it is left empty. Skips numbers already taken by
-- imported students who came with their own code.
create or replace function private.fill_student_code()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.student_code is null or btrim(new.student_code) = '' then
    loop
      new.student_code := private.next_number(new.school_id, 'student');
      exit when not exists (
        select 1 from public.students s
        where s.school_id = new.school_id and s.student_code = new.student_code);
    end loop;
  end if;
  return new;
end;
$$;

create trigger students_fill_code before insert on public.students
  for each row execute function private.fill_student_code();

revoke execute on function private.fill_student_code() from public;

-- ---------------------------------------------------------------------------
-- "Who am I" helpers for RLS. Each one checks the role in the token AND the
-- link in the data, and only ever returns the caller's own rows.
-- SECURITY DEFINER so they do not loop back into the RLS of the same tables.
-- ---------------------------------------------------------------------------
create or replace function public.current_staff_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select s.id
  from public.staff s
  where s.school_id = public.current_school_id()
    and s.profile_id = auth.uid()
    and s.deleted_at is null
$$;

create or replace function public.current_student_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select s.id
  from public.students s
  where public.has_role('student')
    and s.school_id = public.current_school_id()
    and s.profile_id = auth.uid()
    and s.deleted_at is null
$$;

create or replace function public.current_guardian_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select g.id
  from public.guardians g
  where public.has_role('parent')
    and g.school_id = public.current_school_id()
    and g.profile_id = auth.uid()
    and g.deleted_at is null
$$;

-- The parent's children.
create or replace function public.guardian_student_ids()
returns uuid[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(sg.student_id), '{}')
  from public.student_guardians sg
  where sg.school_id = public.current_school_id()
    and sg.guardian_id = public.current_guardian_id()
$$;

-- The teacher's sections. Phase 1: homeroom sections.
-- Phase 2 adds the sections from teaching_assignments here.
create or replace function public.teacher_section_ids()
returns uuid[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(sec.id), '{}')
  from public.sections sec
  where public.has_role('teacher')
    and sec.school_id = public.current_school_id()
    and sec.homeroom_teacher_id = public.current_staff_id()
$$;
