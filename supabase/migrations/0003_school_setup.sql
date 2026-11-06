-- 0003_school_setup.sql
-- Academic years, semesters, grades, sections, subjects, grade_subjects.

-- ---------------------------------------------------------------------------
-- academic_years: one school year, e.g. 2019 E.C. Dates saved in Gregorian.
-- ---------------------------------------------------------------------------
create table public.academic_years (
  id         uuid primary key default gen_random_uuid(),
  school_id  uuid not null references public.schools (id),
  ec_year    int not null,
  name       text not null,
  start_date date not null,
  end_date   date not null,
  is_current boolean not null default false,
  status     public.academic_year_status not null default 'planning',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.profiles (id) on delete set null,
  constraint academic_years_school_ec_year_key unique (school_id, ec_year),
  constraint academic_years_school_id_id_key unique (school_id, id),
  constraint academic_years_ec_year_range check (ec_year between 1990 and 2200),
  constraint academic_years_dates_check check (end_date > start_date),
  constraint academic_years_current_is_active check (not is_current or status = 'active')
);
-- Only 1 current year per school.
create unique index academic_years_one_current_idx on public.academic_years (school_id) where is_current;
create index academic_years_created_by_idx on public.academic_years (created_by);

-- ---------------------------------------------------------------------------
-- semesters: 2 per year.
-- ---------------------------------------------------------------------------
create table public.semesters (
  id               uuid primary key default gen_random_uuid(),
  school_id        uuid not null references public.schools (id),
  academic_year_id uuid not null,
  number           smallint not null,
  start_date       date not null,
  end_date         date not null,
  is_current       boolean not null default false,
  status           public.semester_status not null default 'open',
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  created_by       uuid references public.profiles (id) on delete set null,
  constraint semesters_school_year_number_key unique (school_id, academic_year_id, number),
  constraint semesters_school_id_id_key unique (school_id, id),
  constraint semesters_number_check check (number in (1, 2)),
  constraint semesters_dates_check check (end_date > start_date),
  constraint semesters_academic_year_fkey foreign key (school_id, academic_year_id)
    references public.academic_years (school_id, id)
);
-- Only 1 current semester per school.
create unique index semesters_one_current_idx on public.semesters (school_id) where is_current;
create index semesters_created_by_idx on public.semesters (created_by);

-- ---------------------------------------------------------------------------
-- grades: 9, 10, 11, 12. Grades 11 and 12 have streams (Natural / Social).
-- ---------------------------------------------------------------------------
create table public.grades (
  id          uuid primary key default gen_random_uuid(),
  school_id   uuid not null references public.schools (id),
  level       smallint not null,
  name        text not null,
  name_am     text,
  has_streams boolean generated always as (level >= 11) stored,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  created_by  uuid references public.profiles (id) on delete set null,
  constraint grades_school_level_key unique (school_id, level),
  constraint grades_school_id_id_key unique (school_id, id),
  constraint grades_level_range check (level between 1 and 12)
);
create index grades_created_by_idx on public.grades (created_by);

-- ---------------------------------------------------------------------------
-- sections: a class group, made again every year. "9-1" ... "12-10".
-- capacity defaults to the school's max_section_size (50).
-- homeroom_teacher_id gets its foreign key in 0004 (staff is made there).
-- ---------------------------------------------------------------------------
create table public.sections (
  id                  uuid primary key default gen_random_uuid(),
  school_id           uuid not null references public.schools (id),
  academic_year_id    uuid not null,
  grade_id            uuid not null,
  name                text not null,
  stream              public.stream,
  homeroom_teacher_id uuid,
  capacity            int not null,
  room                text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  created_by          uuid references public.profiles (id) on delete set null,
  constraint sections_school_year_name_key unique (school_id, academic_year_id, name),
  constraint sections_school_id_id_key unique (school_id, id),
  constraint sections_capacity_check check (capacity > 0),
  constraint sections_academic_year_fkey foreign key (school_id, academic_year_id)
    references public.academic_years (school_id, id),
  constraint sections_grade_fkey foreign key (school_id, grade_id)
    references public.grades (school_id, id)
);
create index sections_school_grade_idx on public.sections (school_id, grade_id);
create index sections_created_by_idx on public.sections (created_by);

-- ---------------------------------------------------------------------------
-- subjects: Maths, Physics, Amharic, English ...
-- ---------------------------------------------------------------------------
create table public.subjects (
  id         uuid primary key default gen_random_uuid(),
  school_id  uuid not null references public.schools (id),
  code       text not null,
  name       text not null,
  name_am    text,
  is_active  boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.profiles (id) on delete set null,
  constraint subjects_school_code_key unique (school_id, code),
  constraint subjects_school_id_id_key unique (school_id, id),
  constraint subjects_code_format check (code = upper(btrim(code)) and code <> '')
);
create index subjects_created_by_idx on public.subjects (created_by);

-- ---------------------------------------------------------------------------
-- grade_subjects: which subjects each grade (and stream) takes.
-- stream null = all streams of that grade.
-- ---------------------------------------------------------------------------
create table public.grade_subjects (
  id                uuid primary key default gen_random_uuid(),
  school_id         uuid not null references public.schools (id),
  grade_id          uuid not null,
  subject_id        uuid not null,
  stream            public.stream,
  periods_per_week  smallint not null default 0,
  counts_in_average boolean not null default true,
  sort_order        smallint not null default 0,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  created_by        uuid references public.profiles (id) on delete set null,
  constraint grade_subjects_school_grade_subject_stream_key
    unique nulls not distinct (school_id, grade_id, subject_id, stream),
  constraint grade_subjects_periods_check check (periods_per_week between 0 and 40),
  constraint grade_subjects_grade_fkey foreign key (school_id, grade_id)
    references public.grades (school_id, id),
  constraint grade_subjects_subject_fkey foreign key (school_id, subject_id)
    references public.subjects (school_id, id)
);
create index grade_subjects_school_subject_idx on public.grade_subjects (school_id, subject_id);
create index grade_subjects_created_by_idx on public.grade_subjects (created_by);

-- ---------------------------------------------------------------------------
-- Stamp triggers
-- ---------------------------------------------------------------------------
create trigger academic_years_stamp before insert or update on public.academic_years
  for each row execute function private.stamp_row();
create trigger semesters_stamp before insert or update on public.semesters
  for each row execute function private.stamp_row();
create trigger grades_stamp before insert or update on public.grades
  for each row execute function private.stamp_row();
create trigger sections_stamp before insert or update on public.sections
  for each row execute function private.stamp_row();
create trigger subjects_stamp before insert or update on public.subjects
  for each row execute function private.stamp_row();
create trigger grade_subjects_stamp before insert or update on public.grade_subjects
  for each row execute function private.stamp_row();

-- ---------------------------------------------------------------------------
-- Section rules
-- * Grades 11-12: a section must have a stream. Grades 9-10: no stream.
-- * capacity defaults to, and may not be above, the school's max_section_size.
-- * Once a section has students, its year, grade and stream are fixed, and
--   its capacity cannot drop below the number of active students.
-- SECURITY DEFINER so it counts every enrollment, not only the ones the
-- caller can see.
-- ---------------------------------------------------------------------------
create or replace function private.check_section()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_has_streams boolean;
  v_max         int;
  v_active      int;
begin
  select g.has_streams into v_has_streams
  from public.grades g
  where g.school_id = new.school_id and g.id = new.grade_id;

  if v_has_streams and new.stream is null then
    raise exception 'Section %: grades 11 and 12 need a stream (natural or social)', new.name
      using errcode = '23514';
  elsif not v_has_streams and new.stream is not null then
    raise exception 'Section %: only grades 11 and 12 have a stream', new.name
      using errcode = '23514';
  end if;

  select s.max_section_size into v_max from public.schools s where s.id = new.school_id;
  if new.capacity is null then
    new.capacity := coalesce(v_max, 50);
  elsif new.capacity > v_max then
    raise exception 'Section %: capacity % is above the school maximum of %', new.name, new.capacity, v_max
      using errcode = '23514';
  end if;

  if tg_op = 'UPDATE' then
    if (new.academic_year_id, new.grade_id, new.stream) is distinct from
       (old.academic_year_id, old.grade_id, old.stream)
       and exists (select 1 from public.enrollments e
                   where e.school_id = old.school_id and e.section_id = old.id)
    then
      raise exception 'Section % already has students. Move them out before changing its year, grade or stream', old.name
        using errcode = '23514';
    end if;

    if new.capacity < old.capacity then
      select count(*) into v_active
      from public.enrollments e
      where e.school_id = new.school_id and e.section_id = new.id and e.status = 'active';
      if v_active > new.capacity then
        raise exception 'Section % has % students, so capacity cannot be %', new.name, v_active, new.capacity
          using errcode = '23514';
      end if;
    end if;
  end if;

  return new;
end;
$$;

create trigger sections_check before insert or update on public.sections
  for each row execute function private.check_section();

-- A stream-specific subject only makes sense for grades 11-12.
create or replace function private.check_grade_subject()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.stream is not null and not exists (
       select 1 from public.grades g
       where g.school_id = new.school_id and g.id = new.grade_id and g.has_streams)
  then
    raise exception 'Only grades 11 and 12 have streams' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger grade_subjects_check before insert or update on public.grade_subjects
  for each row execute function private.check_grade_subject();

-- ---------------------------------------------------------------------------
-- Switch the current year / semester in one step (the "only 1 current" index
-- would refuse two current rows in the middle of the switch).
-- SECURITY INVOKER: RLS decides who may do it (super admin, registrar).
-- ---------------------------------------------------------------------------
create or replace function public.set_current_academic_year(p_academic_year_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_school_id uuid := public.current_school_id();
begin
  update public.academic_years
     set is_current = false
   where school_id = v_school_id and is_current and id <> p_academic_year_id;

  update public.academic_years
     set is_current = true, status = 'active'
   where school_id = v_school_id and id = p_academic_year_id;

  if not found then
    raise exception 'Academic year not found' using errcode = 'P0002';
  end if;
end;
$$;

create or replace function public.set_current_semester(p_semester_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_school_id uuid := public.current_school_id();
begin
  if not exists (
       select 1 from public.semesters se
       join public.academic_years ay on ay.school_id = se.school_id and ay.id = se.academic_year_id
       where se.school_id = v_school_id and se.id = p_semester_id and ay.is_current)
  then
    raise exception 'The semester must belong to the current academic year' using errcode = '23514';
  end if;

  update public.semesters
     set is_current = false
   where school_id = v_school_id and is_current and id <> p_semester_id;

  update public.semesters
     set is_current = true
   where school_id = v_school_id and id = p_semester_id;

  if not found then
    raise exception 'Semester not found' using errcode = 'P0002';
  end if;
end;
$$;

revoke execute on function private.check_section() from public;
revoke execute on function private.check_grade_subject() from public;
