-- Enrollment rules: section capacity, stream = section stream (grades 11-12),
-- year/grade match, section moves, transfers.
begin;
create extension if not exists pgtap with schema extensions;
\ir support/helpers.psql
select tests.build_fixture();
select plan(30);

create function tests.enroll(p_kid text, p_grade text, p_section text, p_stream text default null)
returns void language sql as $$
  insert into public.enrollments (school_id, student_id, academic_year_id, grade_id, section_id, stream)
  values (tests.id('school_a'), tests.id(p_kid), tests.id('year_a'), tests.id(p_grade),
          tests.id(p_section), p_stream::public.stream)
$$;
grant execute on function tests.enroll(text, text, text, text) to authenticated;

select tests.login_as('registrar_a');

-- 60 new students to work with: kid1 ... kid60
with s as (
  insert into public.students (school_id, first_name, father_name, gender)
  select tests.id('school_a'), 'Kid' || n, 'Family', 'F' from generate_series(1, 60) n
  returning id, first_name
)
insert into tests.ids select lower(first_name), id from s;


-- ---------------------------------------------------------------------------
-- Capacity: 9-2 already has 1 student; 49 more make 50; the 51st is refused.
-- ---------------------------------------------------------------------------
select lives_ok(
  $$ select tests.enroll('kid' || n, 'g9_a', 's9_2_a') from generate_series(1, 49) n $$,
  '49 more students fill section 9-2 to 50 / 50');
select is((select active_count from public.v_section_occupancy where section_id = tests.id('s9_2_a')), 50,
          'occupancy view shows 50');
select throws_ok($$ select tests.enroll('kid50', 'g9_a', 's9_2_a') $$,
                 '23514', 'Section 9-2 is full (50 / 50)', 'the 51st student is refused');
select throws_ok(
  format($$update public.enrollments set section_id = %L where id = %L$$, tests.id('s9_2_a'), tests.id('en_a1')),
  '23514', 'Section 9-2 is full (50 / 50)', 'moving a student into a full section is refused');

select lives_ok(
  format($$update public.enrollments set status = 'dropped' where student_id = %L$$, tests.id('kid1')),
  'a dropped student frees the seat');
select lives_ok($$ select tests.enroll('kid50', 'g9_a', 's9_2_a') $$, 'so another student fits');
select throws_ok(
  format($$update public.enrollments set status = 'active' where student_id = %L$$, tests.id('kid1')),
  '23514', 'Section 9-2 is full (50 / 50)', 'the dropped student cannot come back while the section is full');

-- Roll numbers are unique per section, and can be renumbered in one statement.
select lives_ok(
  format($$update public.enrollments e set roll_no = r.n
           from (select id, row_number() over (order by id) as n from public.enrollments
                 where section_id = %L and status = 'active') r
           where e.id = r.id$$, tests.id('s9_2_a')),
  'number the section 1..50');
select lives_ok(
  format($$update public.enrollments set roll_no = 51 - roll_no where section_id = %L and roll_no is not null$$,
         tests.id('s9_2_a')),
  'renumber the whole section in one UPDATE');
select throws_ok(
  format($$update public.enrollments set roll_no = 1 where section_id = %L and roll_no = 2$$, tests.id('s9_2_a')),
  '23505', null, 'two students cannot share a roll number in a section');

-- Capacity changes
select throws_ok(
  format($$update public.sections set capacity = 40 where id = %L$$, tests.id('s9_2_a')),
  '23514', 'Section 9-2 has 50 students, so capacity cannot be 40', 'capacity cannot drop below the students in it');
select throws_ok(
  format($$insert into public.sections (school_id, academic_year_id, grade_id, name, capacity) values (%L, %L, %L, '9-9', 60)$$,
         tests.id('school_a'), tests.id('year_a'), tests.id('g9_a')),
  '23514', 'Section 9-9: capacity 60 is above the school maximum of 50', 'capacity cannot be above the school maximum');
select is(
  (select capacity from public.sections where id = tests.id('s9_1_a')), 50,
  'capacity defaults to the school maximum (50)');

-- ---------------------------------------------------------------------------
-- Streams (grades 11-12): enrollments.stream must equal sections.stream.
-- ---------------------------------------------------------------------------
select throws_ok($$ select tests.enroll('kid51', 'g11_a', 's11_1_a', 'social') $$,
                 '23514', 'Stream social does not match section 11-1 (natural)',
                 'grade 11: a social student cannot go into a natural section');
select lives_ok($$ select tests.enroll('kid51', 'g11_a', 's11_1_a') $$,
                'grade 11: placing a student with no stream yet');
select is((select stream::text from public.enrollments where student_id = tests.id('kid51')), 'natural',
          'the stream is taken from the section');
select throws_ok(
  format($$update public.enrollments set stream = 'social' where student_id = %L$$, tests.id('kid51')),
  '23514', 'Stream social does not match section 11-1 (natural)',
  'grade 11: the stream cannot change while the student sits in a natural section');
select throws_ok(
  format($$update public.enrollments set section_id = %L where student_id = %L$$, tests.id('s11_2_a'), tests.id('kid51')),
  '23514', 'Stream natural does not match section 11-2 (social)',
  'grade 11: a natural student cannot move into a social section');
select lives_ok(
  format($$update public.enrollments set section_id = %L, stream = 'social' where student_id = %L$$,
         tests.id('s11_2_a'), tests.id('kid51')),
  'grade 11: changing stream and section together is allowed');
select lives_ok($$ select tests.enroll('kid52', 'g11_a', null) $$,
                'grade 11: not placed yet, stream can wait');
select throws_ok($$ select tests.enroll('kid53', 'g9_a', null, 'natural') $$,
                 '23514', 'Only grades 11 and 12 have a stream', 'grade 9: no stream');
select throws_ok($$ select tests.enroll('kid54', 'g9_a', 's11_1_a') $$,
                 '23514', 'Section 11-1 is in another year or grade than this enrollment',
                 'the section must be in the same grade');

-- Section stream rules
select throws_ok(
  format($$insert into public.sections (school_id, academic_year_id, grade_id, name) values (%L, %L, %L, '11-9')$$,
         tests.id('school_a'), tests.id('year_a'), tests.id('g11_a')),
  '23514', null, 'a grade 11 section needs a stream');
select throws_ok(
  format($$insert into public.sections (school_id, academic_year_id, grade_id, name, stream) values (%L, %L, %L, '9-9', 'natural')$$,
         tests.id('school_a'), tests.id('year_a'), tests.id('g9_a')),
  '23514', null, 'a grade 9 section has no stream');
select throws_ok(
  format($$update public.sections set stream = 'natural' where id = %L$$, tests.id('s11_2_a')),
  '23514', null, 'a section with students cannot change stream');

-- ---------------------------------------------------------------------------
-- Moving sections is logged with the reason.
-- ---------------------------------------------------------------------------
insert into public.sections (school_id, academic_year_id, grade_id, name)
values (tests.id('school_a'), tests.id('year_a'), tests.id('g9_a'), '9-3');
select lives_ok(
  format($$select public.move_student_section(%L, (select id from public.sections where name = '9-3' and school_id = %L), 'parent request')$$,
         tests.id('en_a1'), tests.id('school_a')),
  'move a student from 9-1 to 9-3');
select results_eq(
  format($$select s1.name, s2.name, sc.reason from public.section_changes sc
           join public.sections s1 on s1.id = sc.from_section_id
           join public.sections s2 on s2.id = sc.to_section_id
           where sc.enrollment_id = %L$$, tests.id('en_a1')),
  $$values ('9-1'::text, '9-3'::text, 'parent request'::text)$$,
  'section_changes has the move and the reason');

select tests.login_as('teacher_a');
select is(tests.count_visible('students'), 0::bigint, 'the 9-1 homeroom teacher no longer sees the moved student');

-- ---------------------------------------------------------------------------
-- Transfer out marks the student and the enrollment.
-- ---------------------------------------------------------------------------
select tests.login_as('registrar_a');
insert into public.student_transfers (school_id, student_id, direction, other_school, transfer_date, reason)
values (tests.id('school_a'), tests.id('st_a2'), 'out', 'Bole Secondary School', '2026-12-01', 'family moved');
select is((select status::text from public.students where id = tests.id('st_a2')), 'transferred_out',
          'transfer out marks the student');
select results_eq(
  format($$select status::text, left_on from public.enrollments where id = %L$$, tests.id('en_a2')),
  $$values ('transferred_out'::text, '2026-12-01'::date)$$,
  'transfer out closes the enrollment');

select * from finish();
rollback;
