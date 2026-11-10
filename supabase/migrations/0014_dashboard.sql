-- 0014_dashboard.sql
-- dashboard_overview(): every number and chart series of the director's
-- dashboard in one call. SECURITY INVOKER, so RLS still decides what each
-- caller's totals are made of (a teacher's call only counts their classes).

create or replace function public.dashboard_overview()
returns jsonb
language sql
stable
set search_path = ''
as $$
with
cs as (select public.current_school_id() as id),
yr as (
  select ay.id, ay.name from public.academic_years ay, cs
  where ay.school_id = cs.id and ay.is_current
),
sem as (
  select se.id, se.number from public.semesters se, cs
  where se.school_id = cs.id and se.is_current
),
enr as (
  select e.id, e.student_id, e.section_id, g.level, g.name as grade_name, g.stage, st.gender,
         concat_ws(' ', st.first_name, st.father_name) as student_name, sec.name as section_name
  from public.enrollments e
  join yr on yr.id = e.academic_year_id
  join public.grades g on g.school_id = e.school_id and g.id = e.grade_id
  join public.students st on st.school_id = e.school_id and st.id = e.student_id
  left join public.sections sec on sec.school_id = e.school_id and sec.id = e.section_id
  where e.status = 'active' and st.deleted_at is null
),
by_grade as (
  select coalesce(jsonb_agg(jsonb_build_object(
           'grade', grade_name, 'level', level, 'stage', stage,
           'students', n, 'male', m, 'female', f) order by level), '[]') as j
  from (select grade_name, level, stage, count(*) as n,
               count(*) filter (where gender = 'M') as m, count(*) filter (where gender = 'F') as f
        from enr group by grade_name, level, stage) x
),
seats as (
  select count(*)::int as sections, coalesce(sum(o.capacity), 0)::int as capacity,
         coalesce(sum(o.active_count), 0)::int as placed
  from public.v_section_occupancy o join yr on yr.id = o.academic_year_id
),
staff_pos as (
  select coalesce(jsonb_agg(jsonb_build_object('position', position, 'count', n) order by n desc), '[]') as j,
         coalesce(sum(n), 0)::int as total
  from (select s.position::text as position, count(*) as n
        from public.staff s, cs
        where s.school_id = cs.id and s.deleted_at is null and s.status = 'active'
        group by s.position) x
),
payroll as (
  select coalesce(sum(ss.monthly_salary), 0)::numeric(14, 2) as monthly
  from public.staff_salaries ss
  join public.staff s on s.school_id = ss.school_id and s.id = ss.staff_id
  where s.deleted_at is null and s.status = 'active'
),
months as (
  select coalesce(jsonb_agg(jsonb_build_object(
           'month', to_char(m.month, 'YYYY-MM'), 'revenue', m.revenue,
           'expenses', m.expenses, 'net', m.net) order by m.month), '[]') as j
  from public.v_monthly_finance m, cs
  where m.school_id = cs.id and m.month >= (date_trunc('month', current_date) - interval '5 months')::date
),
this_month as (
  select coalesce(sum(m.revenue), 0)::numeric(14, 2) as revenue, coalesce(sum(m.expenses), 0)::numeric(14, 2) as expenses
  from public.v_monthly_finance m, cs
  where m.school_id = cs.id and m.month = date_trunc('month', current_date)::date
),
fees as (
  select count(*) filter (where i.status = 'paid')::int    as paid,
         count(*) filter (where i.status = 'partial')::int as partial,
         count(*) filter (where i.status = 'unpaid')::int  as unpaid,
         coalesce(sum(i.total - i.discount) filter (where i.status <> 'void'), 0)::numeric(14, 2) as billed,
         coalesce(sum(i.paid) filter (where i.status <> 'void'), 0)::numeric(14, 2) as collected,
         coalesce(sum(i.total - i.discount - i.paid) filter (where i.status in ('unpaid', 'partial')), 0)::numeric(14, 2) as outstanding
  from public.invoices i join enr on enr.id = i.enrollment_id
),
att as (
  select s.date,
         count(*) filter (where r.status = 'present')::int as present,
         count(*) filter (where r.status = 'absent')::int  as absent,
         count(*) filter (where r.status = 'late')::int    as late,
         count(*) filter (where r.status = 'excused')::int as excused,
         round(100.0 * count(*) filter (where r.status in ('present', 'late')) / nullif(count(*), 0), 1) as rate
  from public.attendance_sessions s
  join public.attendance_records r on r.school_id = s.school_id and r.session_id = s.id
  join cs on cs.id = s.school_id
  where s.date > current_date - 30
  group by s.date
),
att_json as (
  select coalesce(jsonb_agg(to_jsonb(a) order by a.date), '[]') as j,
         (select to_jsonb(l) from att l order by l.date desc limit 1) as latest
  from att a
),
results as (
  select r.enrollment_id, round(avg(r.percent), 1) as average
  from public.v_subject_results r join sem on sem.id = r.semester_id
  group by r.enrollment_id
),
top as (
  select coalesce(jsonb_agg(jsonb_build_object(
           'name', enr.student_name, 'grade', enr.grade_name, 'section', enr.section_name,
           'average', results.average) order by results.average desc), '[]') as j
  from (select * from results order by average desc limit 5) results
  join enr on enr.id = results.enrollment_id
),
stage_avg as (
  select coalesce(jsonb_agg(jsonb_build_object('grade', grade_name, 'level', level, 'average', average) order by level), '[]') as j
  from (select enr.grade_name, enr.level, round(avg(results.average), 1) as average
        from results join enr on enr.id = results.enrollment_id
        group by enr.grade_name, enr.level) x
),
fine_sum as (
  select count(*) filter (where f.status = 'open')::int as open,
         coalesce(sum(f.amount) filter (where f.status = 'open'), 0)::numeric(14, 2) as open_amount,
         count(*) filter (where f.kind = 'discipline')::int as discipline,
         count(*)::int as total
  from public.fines f, cs where f.school_id = cs.id
),
recent as (
  select coalesce(jsonb_agg(x order by x.created_at desc), '[]') as j
  from (select p.receipt_no, p.amount, p.method, p.paid_on, p.created_at, i.period, enr.student_name
        from public.payments p
        join public.invoices i on i.school_id = p.school_id and i.id = p.invoice_id
        join enr on enr.id = i.enrollment_id
        where p.voided_at is null
        order by p.created_at desc limit 6) x
)
select jsonb_build_object(
  'year', (select name from yr),
  'semester', (select number from sem),
  'students', jsonb_build_object(
     'total', (select count(*) from enr),
     'male', (select count(*) from enr where gender = 'M'),
     'female', (select count(*) from enr where gender = 'F'),
     'by_grade', (select j from by_grade)),
  'seats', (select to_jsonb(seats) from seats),
  'staff', jsonb_build_object('total', (select total from staff_pos), 'by_position', (select j from staff_pos),
                              'monthly_payroll', (select monthly from payroll)),
  'finance', jsonb_build_object(
     'this_month', (select to_jsonb(this_month) from this_month),
     'monthly', (select j from months),
     'fees', (select to_jsonb(fees) from fees)),
  'attendance', jsonb_build_object('days', (select j from att_json), 'latest', (select latest from att_json)),
  'results', jsonb_build_object('top', (select j from top), 'by_grade', (select j from stage_avg)),
  'fines', (select to_jsonb(fine_sum) from fine_sum),
  'recent_payments', (select j from recent)
)
$$;

revoke execute on function public.dashboard_overview() from public, anon;
grant execute on function public.dashboard_overview() to authenticated, service_role;
