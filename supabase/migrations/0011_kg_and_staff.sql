-- 0011_kg_and_staff.sql
-- Whole school, KG to grade 12, and every kind of employee.
--
-- Grades: KG1 = level -2, KG2 = -1, KG3 = 0, then grades 1..12.
-- So "next grade" is always level + 1 (KG3 -> grade 1), and promotion keeps working.
-- stage: kg (KG1-KG3), primary (1-8), secondary (9-12).

alter table public.grades drop constraint grades_level_range;
alter table public.grades add constraint grades_level_range check (level between -2 and 12);
alter table public.grades
  add column stage text generated always as (
    case when level <= 0 then 'kg' when level <= 8 then 'primary' else 'secondary' end
  ) stored;

-- Every kind of employee, not only teachers.
alter type public.staff_position add value if not exists 'accountant';
alter type public.staff_position add value if not exists 'cleaner';
alter type public.staff_position add value if not exists 'guard';
alter type public.staff_position add value if not exists 'driver';
alter type public.staff_position add value if not exists 'cook';
alter type public.staff_position add value if not exists 'nurse';

create type public.employment_type as enum ('full_time', 'part_time', 'contract');

alter table public.staff
  add column employment_type public.employment_type not null default 'full_time',
  add column qualification text,
  add column emergency_contact public.phone_et;

-- ---------------------------------------------------------------------------
-- staff_salaries: kept apart from staff because RLS works per row, not per
-- column. Teachers can read the staff list; only finance, the director, the
-- super admin, and the person themself can read a salary.
-- ---------------------------------------------------------------------------
create table public.staff_salaries (
  school_id      uuid not null references public.schools (id),
  staff_id       uuid not null,
  monthly_salary numeric(12, 2) not null,
  effective_from date not null default current_date,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  created_by     uuid references public.profiles (id) on delete set null,
  constraint staff_salaries_pkey primary key (school_id, staff_id),
  constraint staff_salaries_amount_check check (monthly_salary >= 0),
  constraint staff_salaries_staff_fkey foreign key (school_id, staff_id)
    references public.staff (school_id, id)
);
create index staff_salaries_created_by_idx on public.staff_salaries (created_by);

create trigger staff_salaries_stamp before insert or update on public.staff_salaries
  for each row execute function private.stamp_row();
create trigger staff_salaries_audit after insert or update or delete on public.staff_salaries
  for each row execute function private.audit_row('staff_id');

alter table public.staff_salaries enable row level security;

create policy staff_salaries_select on public.staff_salaries for select to authenticated
  using (
    school_id = (select public.current_school_id())
    and (
      (select public.has_any_role('{super_admin,director,finance}'))
      or staff_id = (select public.current_staff_id())
    )
  );
create policy staff_salaries_insert on public.staff_salaries for insert to authenticated
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,finance}')));
create policy staff_salaries_update on public.staff_salaries for update to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,finance}')))
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,finance}')));

revoke all on public.staff_salaries from anon;
revoke truncate, references, trigger on public.staff_salaries from authenticated;
