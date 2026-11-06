-- Data integrity across schools, numbering, current year, audit, soft delete,
-- and the login token.
begin;
create extension if not exists pgtap with schema extensions;
\ir support/helpers.psql
select tests.build_fixture();
select plan(33);

-- ---------------------------------------------------------------------------
-- UNIQUE rules are per school
-- ---------------------------------------------------------------------------
select lives_ok(
  format($$insert into public.students (school_id, student_code, first_name, father_name, gender)
           values (%L, (select student_code from public.students where id = %L), 'Same', 'Code', 'M')$$,
         tests.id('school_b'), tests.id('st_a1')),
  'the same student_code can exist in two schools');
select throws_ok(
  format($$insert into public.students (school_id, student_code, first_name, father_name, gender)
           values (%L, (select student_code from public.students where id = %L), 'Same', 'Code', 'M')$$,
         tests.id('school_a'), tests.id('st_a1')),
  '23505', null, 'but not twice in one school');
select lives_ok(
  format($$insert into public.guardians (school_id, full_name, phone) values (%L, 'Other parent', '+251911000001')$$,
         tests.id('school_b')),
  'the same guardian phone can exist in two schools');
select throws_ok(
  format($$insert into public.guardians (school_id, full_name, phone) values (%L, 'Dup', '+251911000001')$$,
         tests.id('school_a')),
  '23505', null, 'but not twice in one school');
select lives_ok(
  format($$insert into public.subjects (school_id, code, name) values (%L, 'MATH', 'Maths'), (%L, 'MATH', 'Maths')$$,
         tests.id('school_a'), tests.id('school_b')),
  'the same subject code can exist in two schools');
select lives_ok(
  format($$insert into public.academic_years (school_id, ec_year, name, start_date, end_date)
           values (%L, 2020, '2020 E.C.', '2027-09-12', '2028-07-06')$$, tests.id('school_b')),
  'the same ec_year can exist in two schools');
select throws_ok(
  format($$insert into public.grades (school_id, level, name) values (%L, 9, 'Again')$$, tests.id('school_a')),
  '23505', null, 'grade level is unique per school');
select throws_ok(
  $$insert into public.guardians (school_id, full_name, phone) values (gen_random_uuid(), 'X', '0911000001')$$,
  '23514', null, 'phones must be +251 and 9 digits');

-- ---------------------------------------------------------------------------
-- A row can never point at another school's row (composite foreign keys)
-- ---------------------------------------------------------------------------
select throws_ok(
  format($$insert into public.enrollments (school_id, student_id, academic_year_id, grade_id, section_id)
           values (%L, %L, %L, %L, %L)$$,
         tests.id('school_a'), tests.id('st_a1'), tests.id('year_a_next'), tests.id('g9_a'), tests.id('s9_1_b')),
  '23503', null, 'an enrollment cannot use another school''s section');
select throws_ok(
  format($$insert into public.student_guardians (school_id, student_id, guardian_id, relationship)
           values (%L, %L, (select id from public.guardians where school_id = %L limit 1), 'other')$$,
         tests.id('school_a'), tests.id('st_a1'), tests.id('school_b')),
  '23503', null, 'a student cannot be linked to another school''s guardian');
select throws_ok(
  format($$update public.students set school_id = %L where id = %L$$, tests.id('school_b'), tests.id('st_a1')),
  '23514', null, 'school_id of a row cannot be changed');

-- ---------------------------------------------------------------------------
-- Student IDs from number_sequences
-- ---------------------------------------------------------------------------
select is((select student_code from public.students where id = tests.id('st_a1')), 'TSA-19-0001', 'first student ID is TSA-19-0001');
select is((select student_code from public.students where id = tests.id('st_a2')), 'TSA-19-0002', 'second is TSA-19-0002');
select is((select student_code from public.students where id = tests.id('st_b1')), 'TSB-19-0001', 'each school counts on its own');
insert into public.students (school_id, student_code, first_name, father_name, gender)
values (tests.id('school_a'), 'TSA-19-0003', 'Imported', 'Code', 'F');
insert into public.students (id, school_id, first_name, father_name, gender)
values (tests.keep('st_auto', gen_random_uuid()), tests.id('school_a'), 'Next', 'One', 'M');
select is((select student_code from public.students where id = tests.id('st_auto')), 'TSA-19-0004',
          'a number already used by an import is skipped');

-- ---------------------------------------------------------------------------
-- Only one current year per school
-- ---------------------------------------------------------------------------
select throws_ok(
  format($$update public.academic_years set is_current = true, status = 'active' where id = %L$$, tests.id('year_a_next')),
  '23505', null, 'two current years are refused');
select tests.login_as('registrar_a');
select lives_ok(format($$select public.set_current_academic_year(%L)$$, tests.id('year_a_next')),
                'set_current_academic_year switches in one step');
select results_eq(
  format($$select id from public.academic_years where is_current and school_id = %L$$, tests.id('school_a')),
  format($$values (%L::uuid)$$, tests.id('year_a_next')),
  'exactly one current year, the new one');
select is((select count(*)::int from public.academic_years where is_current), 1,
          'school B''s current year is not touched (and not visible)');

-- ---------------------------------------------------------------------------
-- created_by, audit log
-- ---------------------------------------------------------------------------
select lives_ok(
  format($$update public.students set first_name = 'Hanna', created_by = null where id = %L$$, tests.id('st_a1')),
  'registrar edits a student name');
select tests.logout();
select results_eq(
  format($$select action, old_data, new_data, changed_by from public.audit_log
           where table_name = 'students' and record_id = %L and action = 'update'$$, tests.id('st_a1')),
  format($$values ('update'::text, '{"first_name": "Hana"}'::jsonb, '{"first_name": "Hanna"}'::jsonb, %L::uuid)$$,
         tests.id('registrar_a')),
  'audit log keeps only the changed column, old and new, and who changed it');
select is((select created_by from public.students where id = tests.id('st_a1')), null::uuid,
          'created_by stays as it was (fixture rows have none)');

select tests.login_as('registrar_a');
insert into public.students (id, school_id, first_name, father_name, gender)
values (tests.keep('st_by_registrar', gen_random_uuid()), tests.id('school_a'), 'Made', 'ByRegistrar', 'F');
select is((select created_by from public.students where id = tests.id('st_by_registrar')), tests.id('registrar_a'),
          'created_by is the signed-in user');

-- ---------------------------------------------------------------------------
-- Soft delete and restore
-- ---------------------------------------------------------------------------
select lives_ok(format($$select public.soft_delete('students', %L)$$, tests.id('st_a1')), 'registrar soft-deletes a student');
select tests.login_as('teacher_a');
select is(tests.count_visible('students'), 0::bigint, 'a soft-deleted student disappears for the teacher');
select tests.login_as('registrar_a');
select isnt((select deleted_at from public.students where id = tests.id('st_a1')), null, 'registrar still sees it, marked deleted');
select lives_ok(format($$select public.restore('students', %L)$$, tests.id('st_a1')), 'registrar restores it');
select throws_ok(format($$select public.soft_delete('enrollments', %L)$$, tests.id('en_a1')),
                 '22023', null, 'soft_delete only works on students, guardians, staff');
select tests.login_as('teacher_a');
select throws_ok(format($$select public.soft_delete('students', %L)$$, tests.id('st_a1')),
                 'P0002', null, 'a teacher cannot soft-delete');
select tests.logout();
select results_eq(
  format($$select action from public.audit_log where table_name = 'students' and record_id = %L
           and action in ('soft_delete', 'restore') order by id$$, tests.id('st_a1')),
  $$values ('soft_delete'::text), ('restore'::text)$$,
  'soft delete and restore are in the audit log');

-- ---------------------------------------------------------------------------
-- Login token
-- ---------------------------------------------------------------------------
do $$ begin perform tests.make_user('teacher_parent', tests.id('school_a'), '{teacher,parent}'); end $$;
select tests.login_as('teacher_parent');
select is(auth.jwt() -> 'user_roles', '["teacher", "parent"]'::jsonb, 'the token lists every role of the user');
select is(auth.jwt() ->> 'school_id', tests.id('school_a')::text, 'the token carries the school');
select ok(public.has_role('parent') and public.has_role('teacher') and not public.has_role('registrar'),
          'has_role reads the token');

select * from finish();
rollback;
