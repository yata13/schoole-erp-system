-- 0016_roadmap_progress.sql
-- Teaching roadmap progress per class and subject, for the director's
-- "who is behind" table and the teacher's home page.
-- due = weeks whose planned week has already ended; behind = due - done.

create view public.v_roadmap_progress
with (security_invoker = true)
as
select ta.school_id,
       ta.id as teaching_assignment_id,
       ta.staff_id,
       ta.section_id,
       ta.subject_id,
       count(lp.id)::int                                                        as weeks,
       count(lp.id) filter (where lp.status = 'done')::int                      as done,
       count(lp.id) filter (where lp.status = 'in_progress')::int               as in_progress,
       count(lp.id) filter (where lp.planned_on <= current_date - 5)::int       as due,
       greatest(0, count(lp.id) filter (where lp.planned_on <= current_date - 5)
                 - count(lp.id) filter (where lp.status = 'done'))::int          as behind
from public.teaching_assignments ta
left join public.lesson_plans lp on lp.school_id = ta.school_id and lp.teaching_assignment_id = ta.id
group by ta.school_id, ta.id;

revoke all on public.v_roadmap_progress from anon;
