-- Year-end promotion (preview, run, undo) and bulk import (check, then import).
begin;
create extension if not exists pgtap with schema extensions;
\ir support/helpers.psql
select tests.build_fixture();
select plan(24);

-- More students in school A: one in grade 10, one in 11-1 (natural), one in 12-1.
insert into public.students (id, school_id, first_name, father_name, gender) values
  (tests.keep('st_g10', gen_random_uuid()), tests.id('school_a'), 'Ten',    'Grade', 'M'),
  (tests.keep('st_g11', gen_random_uuid()), tests.id('school_a'), 'Eleven', 'Grade', 'F'),
  (tests.keep('st_g12', gen_random_uuid()), tests.id('school_a'), 'Twelve', 'Grade', 'M');
insert into public.sections (id, school_id, academic_year_id, grade_id, name)
values (tests.keep('s10_1_a', gen_random_uuid()), tests.id('school_a'), tests.id('year_a'), tests.id('g10_a'), '10-1');
insert into public.enrollments (school_id, student_id, academic_year_id, grade_id, section_id) values
  (tests.id('school_a'), tests.id('st_g10'), tests.id('year_a'), tests.id('g10_a'), tests.id('s10_1_a')),
  (tests.id('school_a'), tests.id('st_g11'), tests.id('year_a'), tests.id('g11_a'), tests.id('s11_1_a')),
  (tests.id('school_a'), tests.id('st_g12'), tests.id('year_a'), tests.id('g12_a'), tests.id('s12_1_a'));

-- ---------------------------------------------------------------------------
-- Promotion
-- ---------------------------------------------------------------------------
select tests.login_as('teacher_a');
select throws_ok(format($$select public.promote_students(%L, %L)$$, tests.id('year_a'), tests.id('year_a_next')),
                 '42501', null, 'a teacher cannot promote');

select tests.login_as('registrar_a');
update public.enrollments set year_result = 'promoted' where student_id in (tests.id('st_a1'), tests.id('st_g10'), tests.id('st_g11'));
update public.enrollments set year_result = 'graduated' where student_id = tests.id('st_g12');
-- st_a2 has no result yet

select results_eq(
  format($$select promoted, repeated, graduated, undecided, status::text
           from public.promote_students(%L, %L)$$, tests.id('year_a'), tests.id('year_a_next')),
  $$values (3, 0, 1, 1, 'preview'::text)$$,
  'preview counts promoted / repeat / graduated / no result');
select throws_ok(format($$select public.promote_students(%L, %L, true)$$, tests.id('year_a'), tests.id('year_a_next')),
                 '23514', '1 students have no year result yet', 'cannot run while a student has no result');

update public.enrollments set year_result = 'repeat' where student_id = tests.id('st_a2');
select results_eq(
  format($$select promoted, repeated, graduated, undecided, status::text
           from public.promote_students(%L, %L, true)$$, tests.id('year_a'), tests.id('year_a_next')),
  $$values (3, 1, 1, 0, 'done'::text)$$,
  'run promotes 3, repeats 1, graduates 1');
select results_eq(
  format($$select st.first_name, g.level, e.stream::text, e.section_id is null
           from public.enrollments e join public.students st on st.id = e.student_id
           join public.grades g on g.id = e.grade_id
           where e.academic_year_id = %L order by g.level, st.first_name$$, tests.id('year_a_next')),
  $$values ('Dawit'::text, 9::smallint, null::text, true),
           ('Hana', 10::smallint, null, true),
           ('Ten', 11::smallint, null, true),
           ('Eleven', 12::smallint, 'natural', true)$$,
  'new enrollments: next grade (or same for repeat), not placed yet, grade 11->12 keeps the stream');
select is((select status::text from public.students where id = tests.id('st_g12')), 'graduated', 'grade 12 student is graduated');
select is((select count(*)::int from public.enrollments where academic_year_id = tests.id('year_a') and status = 'active'), 0,
          'every enrollment of the old year is completed');
select throws_ok(format($$select public.promote_students(%L, %L, true)$$, tests.id('year_a'), tests.id('year_a_next')),
                 '23505', null, 'a year cannot be promoted twice');
select throws_ok(format($$select public.promote_students(%L, %L)$$, tests.id('year_a_next'), tests.id('year_a')),
                 '23514', null, 'promotion only goes to the next year');

-- Undo: refused once someone is placed in a section of the new year.
insert into public.sections (id, school_id, academic_year_id, grade_id, name)
values (tests.keep('s10_1_next', gen_random_uuid()), tests.id('school_a'), tests.id('year_a_next'), tests.id('g10_a'), '10-1');
update public.enrollments set section_id = tests.id('s10_1_next')
 where student_id = tests.id('st_a1') and academic_year_id = tests.id('year_a_next');
select throws_ok(
  format($$select public.undo_promotion((select id from public.promotion_runs where status = 'done' and school_id = %L))$$,
         tests.id('school_a')),
  '23514', null, 'undo is refused once a promoted student is placed');
update public.enrollments set section_id = null
 where student_id = tests.id('st_a1') and academic_year_id = tests.id('year_a_next');
select is(
  (select status::text from public.undo_promotion(
     (select id from public.promotion_runs where status = 'done' and school_id = tests.id('school_a')))),
  'undone', 'undo works while nobody is placed');
select is((select count(*)::int from public.enrollments where academic_year_id = tests.id('year_a_next')), 0,
          'undo removes the new enrollments');
select is((select count(*)::int from public.enrollments where academic_year_id = tests.id('year_a') and status = 'active'), 5,
          'undo makes the old enrollments active again');
select is((select status::text from public.students where id = tests.id('st_g12')), 'active', 'undo un-graduates');

-- ---------------------------------------------------------------------------
-- Import
-- ---------------------------------------------------------------------------
with j as (
  insert into public.import_jobs (school_id, file_path) values (tests.id('school_a'), 'imports/x/students.xlsx') returning id)
insert into tests.ids select 'job', id from j;

create temp table import_rows on commit drop as
select $json$[
  {"row": 2, "first_name": "Meron", "father_name": "Ayele", "gender": "F", "grade": 9, "section": "9-1",
   "guardian_name": "Ayele Bekele", "guardian_phone": "+251922000001", "guardian_relationship": "Father"},
  {"row": 3, "first_name": "", "father_name": "NoName", "gender": "M", "grade": 9},
  {"row": 4, "first_name": "Lost", "father_name": "Section", "gender": "M", "grade": 9, "section": "9-99"},
  {"row": 5, "first_name": "Biruk", "father_name": "Ayele", "gender": "m", "grade": 11, "section": "11-2",
   "guardian_phone": "+251922000001", "guardian_relationship": "father"},
  {"row": 6, "first_name": "Wrong", "father_name": "Stream", "gender": "F", "grade": 11, "section": "11-1", "stream": "social"},
  {"row": 7, "first_name": "Bad", "father_name": "Date", "gender": "F", "grade": 9, "birth_date": "31/02/2010"}
]$json$::jsonb as rows;
grant select on import_rows to authenticated;

select is(
  (select public.import_students(tests.id('job'), (select rows from import_rows), true) -> 'ok'),
  '2'::jsonb, 'check: 2 good rows');
select is(
  (select jsonb_agg(e -> 'row' order by (e ->> 'row')::int)
   from jsonb_array_elements(public.import_students(tests.id('job'), (select rows from import_rows), true) -> 'errors') e),
  '[3, 4, 6, 7]'::jsonb, 'check: rows 3, 4, 6, 7 are reported with their file row numbers');
select is(tests.count_visible('students'), 5::bigint, 'check saves nothing (still the 5 students)');

select is(
  (select public.import_students(tests.id('job'), (select rows from import_rows), false) -> 'ok'),
  '2'::jsonb, 'import: the 2 good rows go in');
select is((select count(*)::int from public.students where first_name in ('Meron', 'Biruk')), 2, 'both students are saved');
select is((select count(*)::int from public.guardians where phone = '+251922000001'), 1, 'one guardian, found again by phone');
select is((select count(*)::int from public.student_guardians sg join public.guardians g on g.id = sg.guardian_id
           where g.phone = '+251922000001'), 2, 'linked to both children');
select is((select stream::text from public.enrollments e join public.students s on s.id = e.student_id where s.first_name = 'Biruk'),
          'social', 'grade 11 stream is taken from the section');
select results_eq(
  format($$select total_rows, ok_rows, error_rows from public.import_jobs where id = %L$$, tests.id('job')),
  $$values (6, 2, 4)$$, 'the import job keeps the totals');

select tests.login_as('teacher_a');
select throws_ok(format($$select public.import_students(%L, '[]'::jsonb, false)$$, tests.id('job')),
                 '42501', null, 'a teacher cannot import');

select * from finish();
rollback;
