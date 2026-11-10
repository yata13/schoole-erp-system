-- 0012_academics.sql
-- Who teaches what, attendance, marks, and the teaching roadmap.
-- Teachers write only for their own sections and subjects; students and
-- parents read only their own rows.

create type public.attendance_status as enum ('present', 'absent', 'late', 'excused');
create type public.lesson_status as enum ('planned', 'in_progress', 'done', 'skipped');

-- ---------------------------------------------------------------------------
-- teaching_assignments: which teacher teaches which subject in which section.
-- ---------------------------------------------------------------------------
create table public.teaching_assignments (
  id               uuid primary key default gen_random_uuid(),
  school_id        uuid not null references public.schools (id),
  academic_year_id uuid not null,
  staff_id         uuid not null,
  section_id       uuid not null,
  subject_id       uuid not null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  created_by       uuid references public.profiles (id) on delete set null,
  constraint teaching_assignments_school_section_subject_key unique (school_id, section_id, subject_id),
  constraint teaching_assignments_school_id_id_key unique (school_id, id),
  constraint teaching_assignments_year_fkey foreign key (school_id, academic_year_id)
    references public.academic_years (school_id, id),
  constraint teaching_assignments_staff_fkey foreign key (school_id, staff_id)
    references public.staff (school_id, id),
  constraint teaching_assignments_section_fkey foreign key (school_id, section_id)
    references public.sections (school_id, id),
  constraint teaching_assignments_subject_fkey foreign key (school_id, subject_id)
    references public.subjects (school_id, id)
);
create index teaching_assignments_school_staff_idx on public.teaching_assignments (school_id, staff_id);
create index teaching_assignments_school_subject_idx on public.teaching_assignments (school_id, subject_id);
create index teaching_assignments_school_year_idx on public.teaching_assignments (school_id, academic_year_id);
create index teaching_assignments_created_by_idx on public.teaching_assignments (created_by);

-- The year always comes from the section.
create or replace function private.fill_assignment_year()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  select s.academic_year_id into new.academic_year_id
  from public.sections s
  where s.school_id = new.school_id and s.id = new.section_id;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- attendance: one session per section per day, one record per student.
-- ---------------------------------------------------------------------------
create table public.attendance_sessions (
  id         uuid primary key default gen_random_uuid(),
  school_id  uuid not null references public.schools (id),
  section_id uuid not null,
  date       date not null,
  taken_by   uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.profiles (id) on delete set null,
  -- Also serves the (section_id, date) filter.
  constraint attendance_sessions_school_section_date_key unique (school_id, section_id, date),
  constraint attendance_sessions_school_id_id_key unique (school_id, id),
  constraint attendance_sessions_section_fkey foreign key (school_id, section_id)
    references public.sections (school_id, id)
);
create index attendance_sessions_school_date_idx on public.attendance_sessions (school_id, date);
create index attendance_sessions_taken_by_idx on public.attendance_sessions (taken_by);
create index attendance_sessions_created_by_idx on public.attendance_sessions (created_by);

create table public.attendance_records (
  id            uuid primary key default gen_random_uuid(),
  school_id     uuid not null references public.schools (id),
  session_id    uuid not null,
  enrollment_id uuid not null,
  status        public.attendance_status not null default 'present',
  note          text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  created_by    uuid references public.profiles (id) on delete set null,
  constraint attendance_records_school_session_enrollment_key unique (school_id, session_id, enrollment_id),
  constraint attendance_records_session_fkey foreign key (school_id, session_id)
    references public.attendance_sessions (school_id, id) on delete cascade,
  constraint attendance_records_enrollment_fkey foreign key (school_id, enrollment_id)
    references public.enrollments (school_id, id)
);
create index attendance_records_school_enrollment_idx on public.attendance_records (school_id, enrollment_id);
create index attendance_records_created_by_idx on public.attendance_records (created_by);

-- ---------------------------------------------------------------------------
-- marks: one score per student, semester, subject and assessment.
-- assessment_types.max_score is the weight (all types add up to 100).
-- ---------------------------------------------------------------------------
create table public.assessment_types (
  id         uuid primary key default gen_random_uuid(),
  school_id  uuid not null references public.schools (id),
  name       text not null,
  name_am    text,
  max_score  numeric(5, 2) not null,
  sort_order smallint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.profiles (id) on delete set null,
  constraint assessment_types_school_name_key unique (school_id, name),
  constraint assessment_types_school_id_id_key unique (school_id, id),
  constraint assessment_types_max_score_check check (max_score > 0 and max_score <= 100)
);
create index assessment_types_created_by_idx on public.assessment_types (created_by);

create table public.marks (
  id                 uuid primary key default gen_random_uuid(),
  school_id          uuid not null references public.schools (id),
  enrollment_id      uuid not null,
  semester_id        uuid not null,
  subject_id         uuid not null,
  assessment_type_id uuid not null,
  score              numeric(5, 2) not null,
  entered_by         uuid references public.profiles (id) on delete set null,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  created_by         uuid references public.profiles (id) on delete set null,
  constraint marks_school_enrollment_semester_subject_type_key
    unique (school_id, enrollment_id, semester_id, subject_id, assessment_type_id),
  constraint marks_score_check check (score >= 0),
  constraint marks_enrollment_fkey foreign key (school_id, enrollment_id)
    references public.enrollments (school_id, id),
  constraint marks_semester_fkey foreign key (school_id, semester_id)
    references public.semesters (school_id, id),
  constraint marks_subject_fkey foreign key (school_id, subject_id)
    references public.subjects (school_id, id),
  constraint marks_assessment_type_fkey foreign key (school_id, assessment_type_id)
    references public.assessment_types (school_id, id)
);
create index marks_school_semester_subject_idx on public.marks (school_id, semester_id, subject_id);
create index marks_school_subject_idx on public.marks (school_id, subject_id);
create index marks_school_assessment_type_idx on public.marks (school_id, assessment_type_id);
create index marks_entered_by_idx on public.marks (entered_by);
create index marks_created_by_idx on public.marks (created_by);

-- A score cannot be above the assessment's maximum. Who entered it is the signed-in user.
create or replace function private.check_mark()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_max numeric;
begin
  select a.max_score into v_max
  from public.assessment_types a
  where a.school_id = new.school_id and a.id = new.assessment_type_id;
  if new.score > v_max then
    raise exception 'Score % is above the maximum of %', trim_scale(new.score), trim_scale(v_max) using errcode = '23514';
  end if;
  if auth.uid() is not null then
    new.entered_by := (select p.id from public.profiles p where p.id = auth.uid());
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- lesson_plans: the teaching roadmap, week by week, per assignment.
-- ---------------------------------------------------------------------------
create table public.lesson_plans (
  id                     uuid primary key default gen_random_uuid(),
  school_id              uuid not null references public.schools (id),
  teaching_assignment_id uuid not null,
  week_no                smallint not null,
  planned_on             date,
  topic                  text not null,
  objectives             text,
  status                 public.lesson_status not null default 'planned',
  done_on                date,
  note                   text,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  created_by             uuid references public.profiles (id) on delete set null,
  constraint lesson_plans_week_check check (week_no between 1 and 60),
  constraint lesson_plans_assignment_fkey foreign key (school_id, teaching_assignment_id)
    references public.teaching_assignments (school_id, id) on delete cascade
);
create index lesson_plans_school_assignment_idx on public.lesson_plans (school_id, teaching_assignment_id, week_no);
create index lesson_plans_created_by_idx on public.lesson_plans (created_by);

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------
create trigger teaching_assignments_stamp before insert or update on public.teaching_assignments
  for each row execute function private.stamp_row();
create trigger teaching_assignments_year before insert or update of section_id on public.teaching_assignments
  for each row execute function private.fill_assignment_year();
create trigger attendance_sessions_stamp before insert or update on public.attendance_sessions
  for each row execute function private.stamp_row();
create trigger attendance_records_stamp before insert or update on public.attendance_records
  for each row execute function private.stamp_row();
create trigger assessment_types_stamp before insert or update on public.assessment_types
  for each row execute function private.stamp_row();
create trigger marks_stamp before insert or update on public.marks
  for each row execute function private.stamp_row();
create trigger marks_check before insert or update on public.marks
  for each row execute function private.check_mark();
create trigger lesson_plans_stamp before insert or update on public.lesson_plans
  for each row execute function private.stamp_row();

create trigger teaching_assignments_audit after insert or update or delete on public.teaching_assignments
  for each row execute function private.audit_row();
create trigger marks_audit after insert or update or delete on public.marks
  for each row execute function private.audit_row();

revoke execute on function private.fill_assignment_year() from public, anon, authenticated;
revoke execute on function private.check_mark() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- A teacher's sections now include the sections they teach a subject in.
-- ---------------------------------------------------------------------------
create or replace function public.teacher_section_ids()
returns uuid[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(distinct x.id), '{}')
  from (
    select sec.id
    from public.sections sec
    where sec.school_id = public.current_school_id()
      and sec.homeroom_teacher_id = public.current_staff_id()
    union
    select ta.section_id
    from public.teaching_assignments ta
    where ta.school_id = public.current_school_id()
      and ta.staff_id = public.current_staff_id()
  ) x
  where public.has_role('teacher')
$$;

-- The teacher's own assignment ids (for marks and the roadmap).
create or replace function public.teacher_assignment_ids()
returns uuid[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(ta.id), '{}')
  from public.teaching_assignments ta
  where public.has_role('teacher')
    and ta.school_id = public.current_school_id()
    and ta.staff_id = public.current_staff_id()
$$;

-- True when the signed-in teacher teaches this subject to this enrollment's section.
create or replace function private.teaches(p_enrollment_id uuid, p_subject_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.enrollments e
    join public.teaching_assignments ta
      on ta.school_id = e.school_id and ta.section_id = e.section_id
    where public.has_role('teacher')
      and e.school_id = public.current_school_id()
      and e.id = p_enrollment_id
      and ta.subject_id = p_subject_id
      and ta.staff_id = public.current_staff_id()
  )
$$;
revoke execute on function private.teaches(uuid, uuid) from public, anon;
grant execute on function private.teaches(uuid, uuid) to authenticated;

-- The student ids of the signed-in student or parent (empty for anyone else).
create or replace function public.my_student_ids()
returns uuid[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(x.id), '{}')
  from (
    select public.current_student_id() as id
    union
    select unnest(public.guardian_student_ids())
  ) x
  where x.id is not null
$$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.teaching_assignments enable row level security;
alter table public.attendance_sessions  enable row level security;
alter table public.attendance_records   enable row level security;
alter table public.assessment_types     enable row level security;
alter table public.marks                enable row level security;
alter table public.lesson_plans         enable row level security;

-- teaching_assignments: everyone on staff reads; super admin and registrar edit.
create policy teaching_assignments_select on public.teaching_assignments for select to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,director,registrar,teacher,finance}')));
create policy teaching_assignments_insert on public.teaching_assignments for insert to authenticated
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,registrar}')));
create policy teaching_assignments_update on public.teaching_assignments for update to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,registrar}')))
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,registrar}')));
create policy teaching_assignments_delete on public.teaching_assignments for delete to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,registrar}')));

-- attendance_sessions: admins all; teacher own sections; students/parents read theirs.
create policy attendance_sessions_select on public.attendance_sessions for select to authenticated
  using (
    school_id = (select public.current_school_id())
    and (
      (select public.has_any_role('{super_admin,director,registrar}'))
      or section_id = any ((select public.teacher_section_ids())::uuid[])
      or exists (select 1 from public.enrollments e
                 where e.school_id = attendance_sessions.school_id
                   and e.section_id = attendance_sessions.section_id
                   and e.student_id = any ((select public.my_student_ids())::uuid[]))
    )
  );
create policy attendance_sessions_insert on public.attendance_sessions for insert to authenticated
  with check (school_id = (select public.current_school_id())
              and ((select public.has_any_role('{super_admin,registrar}'))
                   or section_id = any ((select public.teacher_section_ids())::uuid[])));
create policy attendance_sessions_update on public.attendance_sessions for update to authenticated
  using (school_id = (select public.current_school_id())
         and ((select public.has_any_role('{super_admin,registrar}'))
              or section_id = any ((select public.teacher_section_ids())::uuid[])))
  with check (school_id = (select public.current_school_id())
              and ((select public.has_any_role('{super_admin,registrar}'))
                   or section_id = any ((select public.teacher_section_ids())::uuid[])));

-- attendance_records follow their session's section.
create policy attendance_records_select on public.attendance_records for select to authenticated
  using (
    school_id = (select public.current_school_id())
    and (
      (select public.has_any_role('{super_admin,director,registrar}'))
      or exists (select 1 from public.attendance_sessions s
                 where s.school_id = attendance_records.school_id and s.id = attendance_records.session_id
                   and s.section_id = any ((select public.teacher_section_ids())::uuid[]))
      or exists (select 1 from public.enrollments e
                 where e.school_id = attendance_records.school_id and e.id = attendance_records.enrollment_id
                   and e.student_id = any ((select public.my_student_ids())::uuid[]))
    )
  );
create policy attendance_records_insert on public.attendance_records for insert to authenticated
  with check (
    school_id = (select public.current_school_id())
    and (
      (select public.has_any_role('{super_admin,registrar}'))
      or exists (select 1 from public.attendance_sessions s
                 where s.school_id = attendance_records.school_id and s.id = attendance_records.session_id
                   and s.section_id = any ((select public.teacher_section_ids())::uuid[]))
    )
  );
create policy attendance_records_update on public.attendance_records for update to authenticated
  using (
    school_id = (select public.current_school_id())
    and (
      (select public.has_any_role('{super_admin,registrar}'))
      or exists (select 1 from public.attendance_sessions s
                 where s.school_id = attendance_records.school_id and s.id = attendance_records.session_id
                   and s.section_id = any ((select public.teacher_section_ids())::uuid[]))
    )
  )
  with check (
    school_id = (select public.current_school_id())
    and (
      (select public.has_any_role('{super_admin,registrar}'))
      or exists (select 1 from public.attendance_sessions s
                 where s.school_id = attendance_records.school_id and s.id = attendance_records.session_id
                   and s.section_id = any ((select public.teacher_section_ids())::uuid[]))
    )
  );

-- assessment_types: everyone reads; super admin and registrar edit.
create policy assessment_types_select on public.assessment_types for select to authenticated
  using (school_id = (select public.current_school_id()));
create policy assessment_types_insert on public.assessment_types for insert to authenticated
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,registrar}')));
create policy assessment_types_update on public.assessment_types for update to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,registrar}')))
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,registrar}')));

-- marks: admins read; teacher reads own classes and edits own subject; student/parent read own.
create policy marks_select on public.marks for select to authenticated
  using (
    school_id = (select public.current_school_id())
    and (
      (select public.has_any_role('{super_admin,director,registrar}'))
      or exists (select 1 from public.enrollments e
                 where e.school_id = marks.school_id and e.id = marks.enrollment_id
                   and (e.section_id = any ((select public.teacher_section_ids())::uuid[])
                        or e.student_id = any ((select public.my_student_ids())::uuid[])))
    )
  );
create policy marks_insert on public.marks for insert to authenticated
  with check (school_id = (select public.current_school_id())
              and ((select public.has_role('super_admin')) or private.teaches(enrollment_id, subject_id)));
create policy marks_update on public.marks for update to authenticated
  using (school_id = (select public.current_school_id())
         and ((select public.has_role('super_admin')) or private.teaches(enrollment_id, subject_id)))
  with check (school_id = (select public.current_school_id())
              and ((select public.has_role('super_admin')) or private.teaches(enrollment_id, subject_id)));
create policy marks_delete on public.marks for delete to authenticated
  using (school_id = (select public.current_school_id())
         and ((select public.has_role('super_admin')) or private.teaches(enrollment_id, subject_id)));

-- lesson_plans: admins read; the teacher of the assignment edits.
create policy lesson_plans_select on public.lesson_plans for select to authenticated
  using (
    school_id = (select public.current_school_id())
    and ((select public.has_any_role('{super_admin,director,registrar}'))
         or teaching_assignment_id = any ((select public.teacher_assignment_ids())::uuid[]))
  );
create policy lesson_plans_insert on public.lesson_plans for insert to authenticated
  with check (
    school_id = (select public.current_school_id())
    and ((select public.has_role('super_admin'))
         or teaching_assignment_id = any ((select public.teacher_assignment_ids())::uuid[]))
  );
create policy lesson_plans_update on public.lesson_plans for update to authenticated
  using (
    school_id = (select public.current_school_id())
    and ((select public.has_role('super_admin'))
         or teaching_assignment_id = any ((select public.teacher_assignment_ids())::uuid[]))
  )
  with check (
    school_id = (select public.current_school_id())
    and ((select public.has_role('super_admin'))
         or teaching_assignment_id = any ((select public.teacher_assignment_ids())::uuid[]))
  );
create policy lesson_plans_delete on public.lesson_plans for delete to authenticated
  using (
    school_id = (select public.current_school_id())
    and ((select public.has_role('super_admin'))
         or teaching_assignment_id = any ((select public.teacher_assignment_ids())::uuid[]))
  );

-- ---------------------------------------------------------------------------
-- An attendance record must be for a student of that session's section.
-- ---------------------------------------------------------------------------
create or replace function private.check_attendance_record()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
       select 1
       from public.attendance_sessions s
       join public.enrollments e on e.school_id = s.school_id and e.section_id = s.section_id
       where s.school_id = new.school_id and s.id = new.session_id and e.id = new.enrollment_id)
  then
    raise exception 'This student is not in that section' using errcode = '23514';
  end if;
  return new;
end;
$$;
create trigger attendance_records_check before insert or update of session_id, enrollment_id on public.attendance_records
  for each row execute function private.check_attendance_record();
revoke execute on function private.check_attendance_record() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- save_attendance(): one call saves a whole section's day (create or update).
-- p_records: [{ "enrollment_id": "...", "status": "present|absent|late|excused", "note": "..." }]
-- SECURITY INVOKER: RLS decides who may (admins, or the section's teacher).
-- ---------------------------------------------------------------------------
create or replace function public.save_attendance(p_section_id uuid, p_date date, p_records jsonb)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
  v_school_id uuid := public.current_school_id();
  v_session   uuid;
begin
  insert into public.attendance_sessions (school_id, section_id, date, taken_by)
  values (v_school_id, p_section_id, p_date, (select p.id from public.profiles p where p.id = auth.uid()))
  on conflict (school_id, section_id, date) do update set taken_by = excluded.taken_by
  returning id into v_session;

  insert into public.attendance_records (school_id, session_id, enrollment_id, status, note)
  select v_school_id, v_session, (r ->> 'enrollment_id')::uuid,
         coalesce(r ->> 'status', 'present')::public.attendance_status, nullif(btrim(r ->> 'note'), '')
  from jsonb_array_elements(p_records) r
  on conflict (school_id, session_id, enrollment_id)
    do update set status = excluded.status, note = excluded.note;

  return v_session;
end;
$$;

-- ---------------------------------------------------------------------------
-- Views (security_invoker: the caller's RLS applies underneath)
-- ---------------------------------------------------------------------------

-- Attendance per enrollment.
create view public.v_attendance_summary
with (security_invoker = true)
as
select e.id as enrollment_id,
       e.school_id,
       e.student_id,
       e.section_id,
       count(r.id)::int                                     as days,
       count(r.id) filter (where r.status = 'present')::int as present,
       count(r.id) filter (where r.status = 'absent')::int  as absent,
       count(r.id) filter (where r.status = 'late')::int    as late,
       count(r.id) filter (where r.status = 'excused')::int as excused,
       case when count(r.id) = 0 then null
            else round(100.0 * count(r.id) filter (where r.status in ('present', 'late')) / count(r.id), 1)
       end as rate
from public.enrollments e
left join public.attendance_records r on r.school_id = e.school_id and r.enrollment_id = e.id
group by e.id;

-- Score per enrollment, semester and subject, and how much of 100 is entered so far.
create view public.v_subject_results
with (security_invoker = true)
as
select m.school_id,
       m.enrollment_id,
       m.semester_id,
       m.subject_id,
       sum(m.score)::numeric(6, 2)     as score,
       sum(a.max_score)::numeric(6, 2) as out_of,
       round(100 * sum(m.score) / nullif(sum(a.max_score), 0), 1) as percent
from public.marks m
join public.assessment_types a on a.school_id = m.school_id and a.id = m.assessment_type_id
group by m.school_id, m.enrollment_id, m.semester_id, m.subject_id;
