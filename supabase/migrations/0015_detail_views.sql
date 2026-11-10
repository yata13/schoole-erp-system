-- 0015_detail_views.sql
-- List views for the finance and fines screens: each row already carries the
-- student's name, grade and section, so a page is one small request.
-- All WITH (security_invoker = true): the caller's RLS applies underneath.

create view public.v_invoice_details
with (security_invoker = true)
as
select i.id, i.school_id, i.invoice_no, i.enrollment_id, i.fee_type_id, i.period, i.period_start, i.due_date,
       i.total, i.discount, i.paid, (i.total - i.discount - i.paid)::numeric(12, 2) as balance, i.status,
       st.id as student_id, st.student_code,
       concat_ws(' ', st.first_name, st.father_name, st.grandfather_name) as student_name,
       g.name as grade_name, g.level as grade_level, sec.name as section_name
from public.invoices i
join public.enrollments e on e.school_id = i.school_id and e.id = i.enrollment_id
join public.students st on st.school_id = e.school_id and st.id = e.student_id
join public.grades g on g.school_id = e.school_id and g.id = e.grade_id
left join public.sections sec on sec.school_id = e.school_id and sec.id = e.section_id;

create view public.v_payment_details
with (security_invoker = true)
as
select p.id, p.school_id, p.receipt_no, p.invoice_id, p.amount, p.method, p.reference_no, p.paid_on,
       p.voided_at, p.void_reason, p.created_at,
       i.invoice_no, i.period, i.student_id, i.student_code, i.student_name, i.grade_name, i.section_name
from public.payments p
join public.v_invoice_details i on i.school_id = p.school_id and i.id = p.invoice_id;

-- Per billing period: how many invoices are paid, partial, unpaid, and the money.
create view public.v_invoice_periods
with (security_invoker = true)
as
select i.school_id, i.period, min(i.period_start) as period_start,
       count(*) filter (where i.status = 'paid')::int    as paid,
       count(*) filter (where i.status = 'partial')::int as partial,
       count(*) filter (where i.status = 'unpaid')::int  as unpaid,
       coalesce(sum(i.total - i.discount) filter (where i.status <> 'void'), 0)::numeric(14, 2) as billed,
       coalesce(sum(i.paid) filter (where i.status <> 'void'), 0)::numeric(14, 2) as collected,
       coalesce(sum(i.total - i.discount - i.paid) filter (where i.status in ('unpaid', 'partial')), 0)::numeric(14, 2) as outstanding
from public.invoices i
group by i.school_id, i.period;

create view public.v_fine_details
with (security_invoker = true)
as
select f.id, f.school_id, f.student_id, f.kind, f.reason, f.amount, f.issued_on, f.status, f.resolved_on, f.issued_by,
       st.student_code, concat_ws(' ', st.first_name, st.father_name) as student_name,
       sc.grade_level, sc.section_name
from public.fines f
join public.students st on st.school_id = f.school_id and st.id = f.student_id
left join public.v_students_current sc on sc.school_id = f.school_id and sc.id = f.student_id;

revoke all on public.v_invoice_details, public.v_payment_details, public.v_invoice_periods, public.v_fine_details from anon;
