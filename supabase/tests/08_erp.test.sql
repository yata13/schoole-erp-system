-- ERP features: KG grades, teaching assignments, attendance, marks, roadmap,
-- salaries, invoices and payments, expenses, fines, dashboard.
begin;
create extension if not exists pgtap with schema extensions;
\ir support/helpers.psql
select tests.build_fixture();
select plan(39);

-- Extra setup (as the migration owner)
insert into public.semesters (id, school_id, academic_year_id, number, start_date, end_date, is_current)
values (tests.keep('sem_a', gen_random_uuid()), tests.id('school_a'), tests.id('year_a'), 1, '2026-09-11', '2027-01-31', true);
insert into public.subjects (id, school_id, code, name) values
  (tests.keep('math_a', gen_random_uuid()), tests.id('school_a'), 'MATH', 'Mathematics'),
  (tests.keep('eng_a',  gen_random_uuid()), tests.id('school_a'), 'ENG', 'English');
insert into public.assessment_types (id, school_id, name, max_score)
values (tests.keep('quiz_a', gen_random_uuid()), tests.id('school_a'), 'Quiz', 10);
-- teacher_a2 teaches Maths in 9-2 (where student_a2 is)
insert into public.teaching_assignments (id, school_id, staff_id, section_id, subject_id)
values (tests.keep('ta_math_9_2', gen_random_uuid()), tests.id('school_a'), tests.id('staff_teacher_a2'),
        tests.id('s9_2_a'), tests.id('math_a'));
insert into public.staff_salaries (school_id, staff_id, monthly_salary) values
  (tests.id('school_a'), tests.id('staff_teacher_a'), 9000),
  (tests.id('school_a'), tests.id('staff_teacher_a2'), 9500);
insert into public.fee_types (id, school_id, name, frequency)
values (tests.keep('tuition', gen_random_uuid()), tests.id('school_a'), 'Tuition', 'monthly');

-- ---------------------------------------------------------------------------
-- KG grades
-- ---------------------------------------------------------------------------
insert into public.grades (id, school_id, level, name) values (tests.keep('kg1_a', gen_random_uuid()), tests.id('school_a'), -2, 'KG1');
select is((select stage from public.grades where id = tests.id('kg1_a')), 'kg', 'KG1 is level -2, stage kg');
select is((select stage from public.grades where id = tests.id('g9_a')), 'secondary', 'grade 9 is secondary');

-- ---------------------------------------------------------------------------
-- Teaching assignments widen the teacher's classes
-- ---------------------------------------------------------------------------
select tests.login_as('teacher_a2');
select is(tests.count_visible('students'), 1::bigint, 'a subject teacher sees the students of the section they teach');
select is((select academic_year_id from public.teaching_assignments where id = tests.id('ta_math_9_2')), tests.id('year_a'),
          'the assignment year comes from the section');

-- ---------------------------------------------------------------------------
-- Marks
-- ---------------------------------------------------------------------------
select lives_ok(
  format($$insert into public.marks (school_id, enrollment_id, semester_id, subject_id, assessment_type_id, score)
           values (%L, %L, %L, %L, %L, 8.5)$$,
         tests.id('school_a'), tests.id('en_a2'), tests.id('sem_a'), tests.id('math_a'), tests.id('quiz_a')),
  'the maths teacher enters a maths mark for their section');
select is((select entered_by from public.marks where enrollment_id = tests.id('en_a2')), tests.id('teacher_a2'),
          'entered_by is the teacher');
select throws_ok(
  format($$insert into public.marks (school_id, enrollment_id, semester_id, subject_id, assessment_type_id, score)
           values (%L, %L, %L, %L, %L, 7)$$,
         tests.id('school_a'), tests.id('en_a2'), tests.id('sem_a'), tests.id('eng_a'), tests.id('quiz_a')),
  '42501', null, 'but not an English mark (not their subject)');
select throws_ok(
  format($$insert into public.marks (school_id, enrollment_id, semester_id, subject_id, assessment_type_id, score)
           values (%L, %L, %L, %L, %L, 7)$$,
         tests.id('school_a'), tests.id('en_a1'), tests.id('sem_a'), tests.id('math_a'), tests.id('quiz_a')),
  '42501', null, 'and not for a student in another section');
select throws_ok(
  format($$update public.marks set score = 11 where enrollment_id = %L$$, tests.id('en_a2')),
  '23514', 'Score 11 is above the maximum of 10', 'a score cannot be above the maximum');

select tests.login_as('student_a2');
select is((select percent from public.v_subject_results where enrollment_id = tests.id('en_a2')), 85.0,
          'the student sees their own result (8.5 / 10 = 85%)');
select tests.login_as('student_a1');
select is(tests.count_visible('marks'), 0::bigint, 'another student sees no one else''s marks');

-- ---------------------------------------------------------------------------
-- Attendance
-- ---------------------------------------------------------------------------
select tests.login_as('teacher_a');
select lives_ok(
  format($$select public.save_attendance(%L, '2026-11-09', jsonb_build_array(jsonb_build_object('enrollment_id', %L, 'status', 'absent')))$$,
         tests.id('s9_1_a'), tests.id('en_a1')),
  'the homeroom teacher takes attendance for their section');
select throws_ok(
  format($$select public.save_attendance(%L, '2026-11-09', jsonb_build_array(jsonb_build_object('enrollment_id', %L, 'status', 'absent')))$$,
         tests.id('s9_1_a'), tests.id('en_a2')),
  '23514', 'This student is not in that section', 'attendance only for students of that section');
select throws_ok(
  format($$insert into public.attendance_sessions (school_id, section_id, date) values (%L, %L, '2026-11-09')$$,
         tests.id('school_a'), tests.id('s9_2_a')),
  '42501', null, 'but not for another section');
select tests.login_as('parent_a1');
select is((select absent from public.v_attendance_summary where enrollment_id = tests.id('en_a1')), 1,
          'the parent sees their child''s absence');
select tests.login_as('parent_a2');
select is(tests.count_visible('attendance_records'), 0::bigint, 'another parent sees nothing');

-- ---------------------------------------------------------------------------
-- Teaching roadmap
-- ---------------------------------------------------------------------------
select tests.login_as('teacher_a2');
select lives_ok(
  format($$insert into public.lesson_plans (school_id, teaching_assignment_id, week_no, topic) values (%L, %L, 1, 'Linear equations')$$,
         tests.id('school_a'), tests.id('ta_math_9_2')),
  'a teacher adds a week to their own roadmap');
select tests.login_as('teacher_a');
select throws_ok(
  format($$insert into public.lesson_plans (school_id, teaching_assignment_id, week_no, topic) values (%L, %L, 2, 'Not mine')$$,
         tests.id('school_a'), tests.id('ta_math_9_2')),
  '42501', null, 'but not to another teacher''s roadmap');
select tests.login_as('director_a');
select is(tests.count_visible('lesson_plans'), 1::bigint, 'the director reads every roadmap');

-- ---------------------------------------------------------------------------
-- Salaries
-- ---------------------------------------------------------------------------
select tests.login_as('teacher_a');
select is(tests.count_visible('staff'), 2::bigint, 'teachers read the staff list');
select is((select monthly_salary from public.staff_salaries), 9000.00, 'but only their own salary');
select tests.login_as('finance_a');
select is(tests.count_visible('staff_salaries'), 2::bigint, 'finance reads every salary');
select tests.login_as('registrar_a');
select is(tests.count_visible('staff_salaries'), 0::bigint, 'the registrar reads no salaries');

-- ---------------------------------------------------------------------------
-- Invoices and payments
-- ---------------------------------------------------------------------------
select tests.login_as('finance_a');
with i as (
  insert into public.invoices (school_id, enrollment_id, fee_type_id, period, period_start, due_date, total)
  values (tests.id('school_a'), tests.id('en_a1'), tests.id('tuition'), 'Hidar 2019', '2026-11-01', '2026-11-15', 2000)
  returning id, invoice_no)
insert into tests.ids select 'inv1', id from i;
select is((select invoice_no from public.invoices where id = tests.id('inv1')), 'INV-2019-000001', 'invoice numbers come from the sequence');

with p as (
  insert into public.payments (school_id, invoice_id, amount, method) values (tests.id('school_a'), tests.id('inv1'), 1500, 'telebirr')
  returning id)
insert into tests.ids select 'pay1', id from p;
select results_eq(
  format($$select i.status::text, i.paid, p.receipt_no from public.invoices i, public.payments p
           where i.id = %L and p.id = %L$$, tests.id('inv1'), tests.id('pay1')),
  $$values ('partial'::text, 1500.00::numeric(12,2), 'RCP-2019-000001'::text)$$,
  'a payment makes the invoice partial and gets a receipt number');
select throws_ok(
  format($$insert into public.payments (school_id, invoice_id, amount, method) values (%L, %L, 600, 'cash')$$,
         tests.id('school_a'), tests.id('inv1')),
  '23514', null, 'paying more than is owed is refused');
select lives_ok(
  format($$insert into public.payments (school_id, invoice_id, amount, method) values (%L, %L, 500, 'cash')$$,
         tests.id('school_a'), tests.id('inv1')),
  'paying the rest');
select is((select status::text from public.invoices where id = tests.id('inv1')), 'paid', 'the invoice is paid');
select throws_ok(format($$update public.payments set amount = 100 where id = %L$$, tests.id('pay1')),
                 '42501', null, 'a payment cannot be changed');
select throws_ok(format($$update public.payments set voided_at = now() where id = %L$$, tests.id('pay1')),
                 '23514', null, 'voiding needs a reason');
select lives_ok(format($$update public.payments set voided_at = now(), void_reason = 'Wrong student' where id = %L$$, tests.id('pay1')),
                'voiding with a reason');
select results_eq(format($$select status::text, paid from public.invoices where id = %L$$, tests.id('inv1')),
                  $$values ('partial'::text, 500.00::numeric(12,2))$$, 'the voided payment no longer counts');
select is(tests.rows_affected(format($$delete from public.payments where id = %L$$, tests.id('pay1'))), 0,
          'nobody can delete a payment through the API');

select tests.login_as('student_a1');
select is(tests.count_visible('invoices'), 1::bigint, 'the student sees their own invoice');
select tests.login_as('parent_a2');
select is(tests.count_visible('payments'), 0::bigint, 'another parent sees none of those payments');

-- ---------------------------------------------------------------------------
-- Expenses and fines
-- ---------------------------------------------------------------------------
select tests.login_as('finance_a');
insert into public.expenses (school_id, category, description, amount) values (tests.id('school_a'), 'utilities', 'Electricity', 4200);
select tests.login_as('teacher_a');
select is(tests.count_visible('expenses'), 0::bigint, 'teachers do not see expenses');
select lives_ok(
  format($$insert into public.fines (school_id, student_id, kind, reason) values (%L, %L, 'discipline', 'Late to class 3 times')$$,
         tests.id('school_a'), tests.id('st_a1')),
  'a teacher records a discipline case for their own student');
select throws_ok(
  format($$insert into public.fines (school_id, student_id, kind, reason) values (%L, %L, 'discipline', 'Not my student')$$,
         tests.id('school_a'), tests.id('st_a2')),
  '42501', null, 'but not for someone else''s student');

-- ---------------------------------------------------------------------------
-- Dashboard
-- ---------------------------------------------------------------------------
select tests.login_as('super_admin_a');
select is((public.dashboard_overview() -> 'students' ->> 'total')::int, 2, 'dashboard counts the school''s students');

select * from finish();
rollback;
