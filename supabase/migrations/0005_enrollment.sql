-- 0005_enrollment.sql
-- Enrollments (the heart of the system), section moves, transfers,
-- year-end promotion, bulk import, and the Phase 1 views.

-- ---------------------------------------------------------------------------
-- promotion_runs: year-end "move everyone to the next grade".
-- (Made before enrollments because enrollments.promotion_run_id points here.)
-- ---------------------------------------------------------------------------
create table public.promotion_runs (
  id           uuid primary key default gen_random_uuid(),
  school_id    uuid not null references public.schools (id),
  from_year_id uuid not null,
  to_year_id   uuid not null,
  promoted     int not null default 0,
  repeated     int not null default 0,
  graduated    int not null default 0,
  undecided    int not null default 0,  -- active students with no year_result yet
  status       public.promotion_status not null default 'preview',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  created_by   uuid references public.profiles (id) on delete set null,
  constraint promotion_runs_school_id_id_key unique (school_id, id),
  constraint promotion_runs_years_differ check (from_year_id <> to_year_id),
  constraint promotion_runs_from_year_fkey foreign key (school_id, from_year_id)
    references public.academic_years (school_id, id),
  constraint promotion_runs_to_year_fkey foreign key (school_id, to_year_id)
    references public.academic_years (school_id, id)
);
create index promotion_runs_school_from_year_idx on public.promotion_runs (school_id, from_year_id);
create index promotion_runs_school_to_year_idx on public.promotion_runs (school_id, to_year_id);
create index promotion_runs_created_by_idx on public.promotion_runs (created_by);
-- A year can be promoted only once (unless that run is undone).
create unique index promotion_runs_one_done_idx
  on public.promotion_runs (school_id, from_year_id) where status = 'done';

-- ---------------------------------------------------------------------------
-- enrollments: a student in one school year. Marks, attendance and fees all
-- link here. section_id null = not placed in a section yet.
-- ---------------------------------------------------------------------------
create table public.enrollments (
  id               uuid primary key default gen_random_uuid(),
  school_id        uuid not null references public.schools (id),
  student_id       uuid not null,
  academic_year_id uuid not null,
  grade_id         uuid not null,
  section_id       uuid,
  stream           public.stream,
  roll_no          smallint,
  status           public.enrollment_status not null default 'active',
  year_result      public.year_result,
  enrolled_on      date not null default current_date,
  left_on          date,
  promotion_run_id uuid,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  created_by       uuid references public.profiles (id) on delete set null,
  constraint enrollments_school_student_year_key unique (school_id, student_id, academic_year_id),
  -- Checked at the end of each statement, so roll numbers can be renumbered in one UPDATE.
  constraint enrollments_school_section_roll_no_key unique (school_id, section_id, roll_no)
    deferrable initially immediate,
  constraint enrollments_school_id_id_key unique (school_id, id),
  constraint enrollments_roll_no_check check (roll_no > 0),
  constraint enrollments_left_on_check check (left_on is null or left_on >= enrolled_on),
  constraint enrollments_student_fkey foreign key (school_id, student_id)
    references public.students (school_id, id),
  constraint enrollments_academic_year_fkey foreign key (school_id, academic_year_id)
    references public.academic_years (school_id, id),
  constraint enrollments_grade_fkey foreign key (school_id, grade_id)
    references public.grades (school_id, id),
  constraint enrollments_section_fkey foreign key (school_id, section_id)
    references public.sections (school_id, id),
  constraint enrollments_promotion_run_fkey foreign key (school_id, promotion_run_id)
    references public.promotion_runs (school_id, id) on delete set null (promotion_run_id)
);
-- The most common filter: one year, one section.
create index enrollments_school_year_section_idx
  on public.enrollments (school_id, academic_year_id, section_id);
create index enrollments_school_grade_idx on public.enrollments (school_id, grade_id);
create index enrollments_school_promotion_run_idx on public.enrollments (school_id, promotion_run_id);
create index enrollments_created_by_idx on public.enrollments (created_by);

-- ---------------------------------------------------------------------------
-- section_changes: moving a student to another section (filled by trigger).
-- ---------------------------------------------------------------------------
create table public.section_changes (
  id              uuid primary key default gen_random_uuid(),
  school_id       uuid not null references public.schools (id),
  enrollment_id   uuid not null,
  from_section_id uuid not null,
  to_section_id   uuid,             -- null = taken out of the section
  reason          text,
  changed_at      timestamptz not null default now(),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  created_by      uuid references public.profiles (id) on delete set null,
  -- Move history belongs to its enrollment (the audit log keeps a copy).
  constraint section_changes_enrollment_fkey foreign key (school_id, enrollment_id)
    references public.enrollments (school_id, id) on delete cascade,
  constraint section_changes_from_section_fkey foreign key (school_id, from_section_id)
    references public.sections (school_id, id),
  constraint section_changes_to_section_fkey foreign key (school_id, to_section_id)
    references public.sections (school_id, id)
);
create index section_changes_school_enrollment_idx on public.section_changes (school_id, enrollment_id);
create index section_changes_school_from_section_idx on public.section_changes (school_id, from_section_id);
create index section_changes_school_to_section_idx on public.section_changes (school_id, to_section_id);
create index section_changes_created_by_idx on public.section_changes (created_by);

-- ---------------------------------------------------------------------------
-- student_transfers: leaving to / coming from another school.
-- ---------------------------------------------------------------------------
create table public.student_transfers (
  id            uuid primary key default gen_random_uuid(),
  school_id     uuid not null references public.schools (id),
  student_id    uuid not null,
  direction     public.transfer_direction not null,
  other_school  text not null,
  transfer_date date not null,
  reason        text,
  document_path text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  created_by    uuid references public.profiles (id) on delete set null,
  constraint student_transfers_student_fkey foreign key (school_id, student_id)
    references public.students (school_id, id)
);
create index student_transfers_school_student_idx on public.student_transfers (school_id, student_id);
create index student_transfers_created_by_idx on public.student_transfers (created_by);

-- ---------------------------------------------------------------------------
-- import_jobs: bulk import from CSV / Excel.
-- ---------------------------------------------------------------------------
create table public.import_jobs (
  id          uuid primary key default gen_random_uuid(),
  school_id   uuid not null references public.schools (id),
  file_path   text,
  status      public.import_status not null default 'checking',
  total_rows  int not null default 0,
  ok_rows     int not null default 0,
  error_rows  int not null default 0,
  errors      jsonb not null default '[]'::jsonb,   -- [{ "row": 12, "message": "..." }]
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  created_by  uuid references public.profiles (id) on delete set null,
  constraint import_jobs_counts_check check (total_rows >= 0 and ok_rows >= 0 and error_rows >= 0)
);
create index import_jobs_school_created_at_idx on public.import_jobs (school_id, created_at desc);
create index import_jobs_created_by_idx on public.import_jobs (created_by);

-- ---------------------------------------------------------------------------
-- Stamp triggers
-- ---------------------------------------------------------------------------
create trigger promotion_runs_stamp before insert or update on public.promotion_runs
  for each row execute function private.stamp_row();
create trigger enrollments_stamp before insert or update on public.enrollments
  for each row execute function private.stamp_row();
create trigger section_changes_stamp before insert or update on public.section_changes
  for each row execute function private.stamp_row();
create trigger student_transfers_stamp before insert or update on public.student_transfers
  for each row execute function private.stamp_row();
create trigger import_jobs_stamp before insert or update on public.import_jobs
  for each row execute function private.stamp_row();

-- ---------------------------------------------------------------------------
-- Enrollment rules (run on insert, and on update of the columns they read):
-- 1. The section must be in the same year and grade as the enrollment.
-- 2. Grades 11-12: enrollments.stream must equal sections.stream. If the
--    stream is empty when the student is placed, it is taken from the section.
--    Grades 9-10: no stream.
-- 3. Section capacity: the section row is locked (SELECT ... FOR UPDATE)
--    before counting, so two inserts at the same time are counted one after
--    the other and the 51st student is always refused.
--    (Relies on READ COMMITTED, the Postgres and Supabase default, where each
--    statement after the lock sees rows committed while it waited.)
-- SECURITY DEFINER so the count includes every enrollment, not only the rows
-- the caller is allowed to see.
-- ---------------------------------------------------------------------------
create or replace function private.check_enrollment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_has_streams boolean;
  v_section     record;
  v_taken       int;
begin
  select g.has_streams into v_has_streams
  from public.grades g
  where g.school_id = new.school_id and g.id = new.grade_id;

  if new.section_id is not null then
    select s.name, s.academic_year_id, s.grade_id, s.stream, s.capacity
      into v_section
    from public.sections s
    where s.school_id = new.school_id and s.id = new.section_id
    for update;

    if found then
      if v_section.academic_year_id <> new.academic_year_id or v_section.grade_id <> new.grade_id then
        raise exception 'Section % is in another year or grade than this enrollment', v_section.name
          using errcode = '23514';
      end if;

      if new.stream is null and v_has_streams then
        new.stream := v_section.stream;
      end if;
      if new.stream is distinct from v_section.stream then
        raise exception 'Stream % does not match section % (%)',
          coalesce(new.stream::text, 'none'), v_section.name, coalesce(v_section.stream::text, 'no stream')
          using errcode = '23514';
      end if;

      if new.status = 'active'
         and (tg_op = 'INSERT'
              or old.section_id is distinct from new.section_id
              or old.status <> 'active')
      then
        select count(*) into v_taken
        from public.enrollments e
        where e.school_id = new.school_id
          and e.section_id = new.section_id
          and e.status = 'active'
          and e.id <> new.id;

        if v_taken >= v_section.capacity then
          raise exception 'Section % is full (% / %)', v_section.name, v_taken, v_section.capacity
            using errcode = '23514', hint = 'section_full';
        end if;
      end if;
    end if;
  end if;

  if not coalesce(v_has_streams, false) and new.stream is not null then
    raise exception 'Only grades 11 and 12 have a stream' using errcode = '23514';
  end if;

  return new;
end;
$$;

create trigger enrollments_check
  before insert or update of section_id, stream, grade_id, academic_year_id, status
  on public.enrollments
  for each row execute function private.check_enrollment();

-- Every move out of a section is written to section_changes, whoever does it.
-- The reason comes from move_student_section() (or is empty).
create or replace function private.log_section_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.section_id is not null and old.section_id is distinct from new.section_id then
    insert into public.section_changes (school_id, enrollment_id, from_section_id, to_section_id, reason)
    values (new.school_id, new.id, old.section_id, new.section_id,
            nullif(current_setting('app.section_change_reason', true), ''));
  end if;
  return null;
end;
$$;

create trigger enrollments_log_section_change
  after update of section_id on public.enrollments
  for each row execute function private.log_section_change();

-- Transfer out: the student and the active enrollment are marked
-- transferred_out in the same transaction.
create or replace function private.apply_transfer()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.direction = 'out' then
    update public.students
       set status = 'transferred_out'
     where school_id = new.school_id and id = new.student_id;

    update public.enrollments
       set status = 'transferred_out', left_on = greatest(new.transfer_date, enrolled_on)
     where school_id = new.school_id and student_id = new.student_id and status = 'active';
  else
    update public.students
       set previous_school = coalesce(previous_school, new.other_school)
     where school_id = new.school_id and id = new.student_id;
  end if;
  return null;
end;
$$;

create trigger student_transfers_apply
  after insert on public.student_transfers
  for each row execute function private.apply_transfer();

revoke execute on function private.check_enrollment() from public;
revoke execute on function private.log_section_change() from public;
revoke execute on function private.apply_transfer() from public;

-- ---------------------------------------------------------------------------
-- The teacher's students (enrolled in one of the teacher's sections).
-- ---------------------------------------------------------------------------
create or replace function public.teacher_student_ids()
returns uuid[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(distinct e.student_id), '{}')
  from public.enrollments e
  where e.school_id = public.current_school_id()
    and e.section_id = any (public.teacher_section_ids())
$$;

-- ---------------------------------------------------------------------------
-- move_student_section(): move to another section (or out, with null).
-- Capacity and stream are checked by the enrollment trigger; the move is
-- logged in section_changes with the reason. RLS decides who may do it.
-- ---------------------------------------------------------------------------
create or replace function public.move_student_section(
  p_enrollment_id uuid,
  p_to_section_id uuid,
  p_reason        text default null
)
returns public.enrollments
language plpgsql
set search_path = ''
as $$
declare
  v_row public.enrollments;
begin
  perform set_config('app.section_change_reason', coalesce(p_reason, ''), true);

  update public.enrollments
     set section_id = p_to_section_id,
         roll_no = null
   where school_id = public.current_school_id() and id = p_enrollment_id
  returning * into v_row;

  perform set_config('app.section_change_reason', '', true);

  if v_row.id is null then
    raise exception 'Enrollment not found' using errcode = 'P0002';
  end if;
  return v_row;
end;
$$;

-- ---------------------------------------------------------------------------
-- promote_students(): year-end promotion. Preview first (p_apply = false),
-- then run (p_apply = true). Uses each active enrollment's year_result:
--   promoted  -> new enrollment in the next grade (not placed in a section)
--   repeat    -> new enrollment in the same grade
--   graduated -> student status 'graduated'
-- Every active enrollment of the old year becomes 'completed'.
-- SECURITY INVOKER: RLS decides who may do it (super admin, registrar).
-- ---------------------------------------------------------------------------
create or replace function public.promote_students(
  p_from_year_id uuid,
  p_to_year_id   uuid,
  p_apply        boolean default false
)
returns public.promotion_runs
language plpgsql
set search_path = ''
as $$
declare
  v_school_id uuid := public.current_school_id();
  v_from      public.academic_years;
  v_to        public.academic_years;
  v_run       public.promotion_runs;
  v_promoted  int;
  v_repeated  int;
  v_graduated int;
  v_undecided int;
  v_top_grade text;
  v_already   int;
begin
  if not public.has_any_role('{super_admin,registrar}') then
    raise exception 'Only the super admin or the registrar can promote students' using errcode = '42501';
  end if;

  select * into v_from from public.academic_years where school_id = v_school_id and id = p_from_year_id;
  select * into v_to   from public.academic_years where school_id = v_school_id and id = p_to_year_id;
  if v_from.id is null or v_to.id is null then
    raise exception 'Academic year not found' using errcode = 'P0002';
  end if;
  if v_to.ec_year <> v_from.ec_year + 1 then
    raise exception 'Promote into the next year (% -> %)', v_from.ec_year, v_from.ec_year + 1
      using errcode = '23514';
  end if;
  if v_to.status = 'closed' then
    raise exception 'Year % is closed', v_to.ec_year using errcode = '23514';
  end if;

  select count(*) filter (where e.year_result = 'promoted'),
         count(*) filter (where e.year_result = 'repeat'),
         count(*) filter (where e.year_result = 'graduated'),
         count(*) filter (where e.year_result is null)
    into v_promoted, v_repeated, v_graduated, v_undecided
  from public.enrollments e
  where e.school_id = v_school_id and e.academic_year_id = p_from_year_id and e.status = 'active';

  insert into public.promotion_runs
    (school_id, from_year_id, to_year_id, promoted, repeated, graduated, undecided, status)
  values
    (v_school_id, p_from_year_id, p_to_year_id, v_promoted, v_repeated, v_graduated, v_undecided, 'preview')
  returning * into v_run;

  if not p_apply then
    return v_run;
  end if;

  if v_undecided > 0 then
    raise exception '% students have no year result yet', v_undecided using errcode = '23514';
  end if;

  select string_agg(distinct g.name, ', ') into v_top_grade
  from public.enrollments e
  join public.grades g on g.school_id = e.school_id and g.id = e.grade_id
  where e.school_id = v_school_id and e.academic_year_id = p_from_year_id
    and e.status = 'active' and e.year_result = 'promoted'
    and not exists (select 1 from public.grades n where n.school_id = g.school_id and n.level = g.level + 1);
  if v_top_grade is not null then
    raise exception 'No next grade after %. Mark those students graduated instead', v_top_grade
      using errcode = '23514';
  end if;

  select count(*) into v_already
  from public.enrollments e
  join public.enrollments n on n.school_id = e.school_id and n.student_id = e.student_id
                           and n.academic_year_id = p_to_year_id
  where e.school_id = v_school_id and e.academic_year_id = p_from_year_id
    and e.status = 'active' and e.year_result in ('promoted', 'repeat');
  if v_already > 0 then
    raise exception '% students are already enrolled in %', v_already, v_to.name using errcode = '23505';
  end if;

  insert into public.enrollments
    (school_id, student_id, academic_year_id, grade_id, stream, status, enrolled_on, promotion_run_id)
  select e.school_id,
         e.student_id,
         p_to_year_id,
         case when e.year_result = 'promoted' then n.id else e.grade_id end,
         case when e.year_result = 'promoted' and not n.has_streams then null else e.stream end,
         'active',
         v_to.start_date,
         v_run.id
  from public.enrollments e
  join public.grades g on g.school_id = e.school_id and g.id = e.grade_id
  left join public.grades n on n.school_id = g.school_id and n.level = g.level + 1
  where e.school_id = v_school_id and e.academic_year_id = p_from_year_id
    and e.status = 'active' and e.year_result in ('promoted', 'repeat');

  update public.students s
     set status = 'graduated'
   where s.school_id = v_school_id
     and s.id in (select e.student_id from public.enrollments e
                  where e.school_id = v_school_id and e.academic_year_id = p_from_year_id
                    and e.status = 'active' and e.year_result = 'graduated');

  update public.enrollments e
     set status = 'completed', left_on = greatest(v_from.end_date, e.enrolled_on)
   where e.school_id = v_school_id and e.academic_year_id = p_from_year_id and e.status = 'active';

  update public.promotion_runs set status = 'done' where id = v_run.id
  returning * into v_run;
  return v_run;
end;
$$;

-- undo_promotion(): only while none of the new enrollments is placed in a section.
create or replace function public.undo_promotion(p_run_id uuid)
returns public.promotion_runs
language plpgsql
set search_path = ''
as $$
declare
  v_school_id uuid := public.current_school_id();
  v_run       public.promotion_runs;
begin
  if not public.has_any_role('{super_admin,registrar}') then
    raise exception 'Only the super admin or the registrar can undo a promotion' using errcode = '42501';
  end if;

  select * into v_run from public.promotion_runs
  where school_id = v_school_id and id = p_run_id and status = 'done'
  for update;
  if v_run.id is null then
    raise exception 'No finished promotion run with that id' using errcode = 'P0002';
  end if;

  if exists (select 1 from public.enrollments
             where school_id = v_school_id and promotion_run_id = p_run_id and section_id is not null) then
    raise exception 'Some promoted students are already placed in sections. Take them out first'
      using errcode = '23514';
  end if;

  delete from public.enrollments where school_id = v_school_id and promotion_run_id = p_run_id;

  update public.students s
     set status = 'active'
   where s.school_id = v_school_id and s.status = 'graduated'
     and s.id in (select e.student_id from public.enrollments e
                  where e.school_id = v_school_id and e.academic_year_id = v_run.from_year_id
                    and e.status = 'completed' and e.year_result = 'graduated');

  update public.enrollments
     set status = 'active', left_on = null
   where school_id = v_school_id and academic_year_id = v_run.from_year_id and status = 'completed';

  update public.promotion_runs set status = 'undone' where id = p_run_id
  returning * into v_run;
  return v_run;
end;
$$;

-- ---------------------------------------------------------------------------
-- import_students(): bulk import, at most 200 rows per call.
-- p_rows is a JSON array. Each row may have:
--   student_code, first_name*, father_name*, grandfather_name,
--   first_name_am, father_name_am, grandfather_name_am, gender* (M/F),
--   birth_date (YYYY-MM-DD, Gregorian), phone (+251...), sub_city, woreda,
--   kebele, previous_school, admission_date, grade* (9-12), section ("9-1"),
--   stream (natural/social), guardian_name, guardian_phone,
--   guardian_relationship (father/mother/guardian/other), row (row number in the file)
-- Each row is saved on its own: a bad row is reported and the rest still go in.
-- p_dry_run = true runs every check (capacity, duplicates, ...) and then undoes
-- everything, so "check" and "import" always agree.
-- Returns { "ok": n, "errors": [ { "row": n, "message": "..." } ] }.
-- SECURITY INVOKER: RLS decides who may do it (super admin, registrar).
-- ---------------------------------------------------------------------------
create or replace function public.import_students(
  p_job_id  uuid,
  p_rows    jsonb,
  p_dry_run boolean default true
)
returns jsonb
language plpgsql
set search_path = ''
as $$
declare
  v_school_id   uuid := public.current_school_id();
  v_year_id     uuid;
  v_row         jsonb;
  v_idx         int;
  v_row_no      int;
  v_ok          int := 0;
  v_errors      jsonb := '[]'::jsonb;
  v_student_id  uuid;
  v_grade_id    uuid;
  v_section_id  uuid;
  v_guardian_id uuid;
  v_phone       text;
begin
  if not public.has_any_role('{super_admin,registrar}') then
    raise exception 'Only the super admin or the registrar can import students' using errcode = '42501';
  end if;
  if jsonb_typeof(p_rows) <> 'array' then
    raise exception 'p_rows must be a JSON array' using errcode = '22023';
  end if;
  if jsonb_array_length(p_rows) > 200 then
    raise exception 'Send at most 200 rows per call' using errcode = '22023';
  end if;
  if not p_dry_run and not exists (select 1 from public.import_jobs where school_id = v_school_id and id = p_job_id) then
    raise exception 'Import job not found' using errcode = 'P0002';
  end if;

  select id into v_year_id from public.academic_years where school_id = v_school_id and is_current;
  if v_year_id is null then
    raise exception 'Set a current academic year before importing' using errcode = '23514';
  end if;

  begin  -- whole batch; undone at the end of a dry run
    for v_row, v_idx in select r.value, r.ordinality from jsonb_array_elements(p_rows) with ordinality r loop
      v_row_no := coalesce((v_row ->> 'row')::int, v_idx);
      begin  -- one row
        if nullif(btrim(v_row ->> 'first_name'), '') is null
           or nullif(btrim(v_row ->> 'father_name'), '') is null then
          raise exception 'first_name and father_name are required' using errcode = '23502';
        end if;
        if nullif(btrim(v_row ->> 'gender'), '') is null then
          raise exception 'gender is required (M or F)' using errcode = '23502';
        end if;

        select g.id into v_grade_id from public.grades g
        where g.school_id = v_school_id and g.level = (v_row ->> 'grade')::smallint;
        if v_grade_id is null then
          raise exception 'grade "%" does not exist', coalesce(v_row ->> 'grade', '') using errcode = '23503';
        end if;

        v_section_id := null;
        if nullif(btrim(v_row ->> 'section'), '') is not null then
          select s.id into v_section_id from public.sections s
          where s.school_id = v_school_id and s.academic_year_id = v_year_id
            and s.name = btrim(v_row ->> 'section');
          if v_section_id is null then
            raise exception 'section "%" does not exist this year', btrim(v_row ->> 'section') using errcode = '23503';
          end if;
        end if;

        insert into public.students (
          school_id, student_code, first_name, father_name, grandfather_name,
          first_name_am, father_name_am, grandfather_name_am, gender, birth_date, phone,
          sub_city, woreda, kebele, previous_school, admission_date)
        values (
          v_school_id,
          upper(nullif(btrim(v_row ->> 'student_code'), '')),
          btrim(v_row ->> 'first_name'),
          btrim(v_row ->> 'father_name'),
          nullif(btrim(v_row ->> 'grandfather_name'), ''),
          nullif(btrim(v_row ->> 'first_name_am'), ''),
          nullif(btrim(v_row ->> 'father_name_am'), ''),
          nullif(btrim(v_row ->> 'grandfather_name_am'), ''),
          upper(left(btrim(v_row ->> 'gender'), 1))::public.gender,
          nullif(btrim(v_row ->> 'birth_date'), '')::date,
          nullif(btrim(v_row ->> 'phone'), '')::public.phone_et,
          nullif(btrim(v_row ->> 'sub_city'), ''),
          nullif(btrim(v_row ->> 'woreda'), ''),
          nullif(btrim(v_row ->> 'kebele'), ''),
          nullif(btrim(v_row ->> 'previous_school'), ''),
          coalesce(nullif(btrim(v_row ->> 'admission_date'), '')::date, current_date))
        returning id into v_student_id;

        insert into public.enrollments (school_id, student_id, academic_year_id, grade_id, section_id, stream)
        values (v_school_id, v_student_id, v_year_id, v_grade_id, v_section_id,
                nullif(btrim(lower(v_row ->> 'stream')), '')::public.stream);

        v_phone := nullif(btrim(v_row ->> 'guardian_phone'), '');
        if v_phone is not null then
          select g.id into v_guardian_id from public.guardians g
          where g.school_id = v_school_id and g.phone = v_phone;
          if v_guardian_id is null then
            if nullif(btrim(v_row ->> 'guardian_name'), '') is null then
              raise exception 'guardian_name is required for a new guardian phone' using errcode = '23502';
            end if;
            insert into public.guardians (school_id, full_name, phone)
            values (v_school_id, btrim(v_row ->> 'guardian_name'), v_phone::public.phone_et)
            returning id into v_guardian_id;
          end if;
          insert into public.student_guardians (school_id, student_id, guardian_id, relationship, is_primary)
          values (v_school_id, v_student_id, v_guardian_id,
                  coalesce(nullif(btrim(lower(v_row ->> 'guardian_relationship')), ''), 'guardian')::public.guardian_relationship,
                  true);
        end if;

        v_ok := v_ok + 1;
      exception when others then
        v_errors := v_errors || jsonb_build_object('row', v_row_no, 'message', sqlerrm);
      end;
    end loop;

    if p_dry_run then
      raise exception using errcode = 'UDRY1', message = 'dry run';
    end if;
  exception when sqlstate 'UDRY1' then
    null;  -- dry run: every row above is undone
  end;

  if not p_dry_run then
    update public.import_jobs
       set total_rows = total_rows + jsonb_array_length(p_rows),
           ok_rows    = ok_rows + v_ok,
           error_rows = error_rows + jsonb_array_length(v_errors),
           errors     = errors || v_errors
     where school_id = v_school_id and id = p_job_id;
  end if;

  return jsonb_build_object('ok', v_ok, 'errors', v_errors);
end;
$$;

-- ---------------------------------------------------------------------------
-- Views. Always WITH (security_invoker = true): the caller's RLS applies to
-- every table underneath, exactly as if they queried the tables directly.
-- ---------------------------------------------------------------------------

-- Seats used per section ("48 / 50"). Meant for registrar / admin screens:
-- like any invoker view it counts only the enrollments the caller can see.
create view public.v_section_occupancy
with (security_invoker = true)
as
select s.id                as section_id,
       s.school_id,
       s.academic_year_id,
       s.grade_id,
       g.level             as grade_level,
       s.name,
       s.stream,
       s.homeroom_teacher_id,
       s.capacity,
       count(e.id) filter (where e.status = 'active')::int              as active_count,
       (s.capacity - count(e.id) filter (where e.status = 'active'))::int as free_seats
from public.sections s
join public.grades g on g.school_id = s.school_id and g.id = s.grade_id
left join public.enrollments e on e.school_id = s.school_id and e.section_id = s.id
group by s.id, g.level;

-- Student list with this year's grade and section. Search and filters run in
-- the database (lists load 25 rows a page).
create view public.v_students_current
with (security_invoker = true)
as
select st.id,
       st.school_id,
       st.student_code,
       concat_ws(' ', st.first_name, st.father_name, st.grandfather_name)          as full_name,
       concat_ws(' ', st.first_name_am, st.father_name_am, st.grandfather_name_am) as full_name_am,
       st.first_name,
       st.father_name,
       st.grandfather_name,
       st.gender,
       st.phone,
       st.photo_path,
       st.status,
       st.deleted_at,
       e.id               as enrollment_id,
       e.academic_year_id,
       e.grade_id,
       g.level            as grade_level,
       e.section_id,
       sec.name           as section_name,
       e.stream,
       e.roll_no,
       e.status           as enrollment_status
from public.students st
left join public.academic_years ay
       on ay.school_id = st.school_id and ay.is_current
left join public.enrollments e
       on e.school_id = st.school_id and e.student_id = st.id and e.academic_year_id = ay.id
left join public.grades g
       on g.school_id = e.school_id and g.id = e.grade_id
left join public.sections sec
       on sec.school_id = e.school_id and sec.id = e.section_id;
