-- Who sees what (board 2), checked as each role through RLS.
begin;
create extension if not exists pgtap with schema extensions;
\ir support/helpers.psql
select tests.build_fixture();
select plan(64);

-- ---------------------------------------------------------------------------
-- Students: admins all; teacher own classes; student self; parent own children.
-- ---------------------------------------------------------------------------
select tests.login_as('super_admin_a'); select is(tests.count_visible('students'), 2::bigint, 'super admin sees all students of the school');
select tests.login_as('director_a');    select is(tests.count_visible('students'), 2::bigint, 'director sees all students');
select tests.login_as('registrar_a');   select is(tests.count_visible('students'), 2::bigint, 'registrar sees all students');
select tests.login_as('finance_a');     select is(tests.count_visible('students'), 2::bigint, 'finance sees all students');
select tests.login_as('teacher_a');     select is(tests.count_visible('students'), 1::bigint, 'homeroom teacher sees only their class');
select tests.login_as('teacher_a2');    select is(tests.count_visible('students'), 0::bigint, 'teacher without classes sees no students');
select tests.login_as('student_a1');    select is(tests.count_visible('students'), 1::bigint, 'student sees only self');
select tests.login_as('parent_a1');     select is(tests.count_visible('students'), 1::bigint, 'parent sees only own child');
select tests.login_as('super_admin_b'); select is(tests.count_visible('students'), 1::bigint, 'school B sees only school B');

select tests.login_as('student_a1');
select is((select id from public.students), tests.id('st_a1'), 'the one row a student sees is their own');
select tests.login_as('parent_a2');
select is((select id from public.students), tests.id('st_a2'), 'the one row a parent sees is their child');

-- ---------------------------------------------------------------------------
-- Enrollments
-- ---------------------------------------------------------------------------
select tests.login_as('registrar_a'); select is(tests.count_visible('enrollments'), 2::bigint, 'registrar sees all enrollments');
select tests.login_as('finance_a');   select is(tests.count_visible('enrollments'), 2::bigint, 'finance sees all enrollments');
select tests.login_as('teacher_a');   select is(tests.count_visible('enrollments'), 1::bigint, 'teacher sees enrollments of own sections');
select tests.login_as('teacher_a2');  select is(tests.count_visible('enrollments'), 0::bigint, 'teacher without sections sees none');
select tests.login_as('student_a1');  select is(tests.count_visible('enrollments'), 1::bigint, 'student sees own enrollment');
select tests.login_as('parent_a1');   select is(tests.count_visible('enrollments'), 1::bigint, 'parent sees child enrollment');

-- ---------------------------------------------------------------------------
-- Guardians and links
-- ---------------------------------------------------------------------------
select tests.login_as('registrar_a'); select is(tests.count_visible('guardians'), 2::bigint, 'registrar sees all guardians');
select tests.login_as('teacher_a');   select is(tests.count_visible('guardians'), 1::bigint, 'teacher sees guardians of own students');
select tests.login_as('teacher_a2');  select is(tests.count_visible('guardians'), 0::bigint, 'teacher without students sees no guardians');
select tests.login_as('student_a1');  select is(tests.count_visible('guardians'), 1::bigint, 'student sees own guardians');
select tests.login_as('parent_a1');   select is(tests.count_visible('guardians'), 1::bigint, 'parent sees own guardian row');
select tests.login_as('parent_a1');   select is(tests.count_visible('student_guardians'), 1::bigint, 'parent sees own links');
select tests.login_as('teacher_a');   select is(tests.count_visible('student_guardians'), 1::bigint, 'teacher sees links of own students');

-- ---------------------------------------------------------------------------
-- Users & roles
-- ---------------------------------------------------------------------------
select tests.login_as('super_admin_a'); select is(tests.count_visible('profiles'), 10::bigint, 'super admin sees all logins');
select tests.login_as('director_a');    select is(tests.count_visible('profiles'), 10::bigint, 'director sees all logins');
select tests.login_as('registrar_a');   select is(tests.count_visible('profiles'), 5::bigint, 'registrar sees self + student and parent logins');
select tests.login_as('teacher_a');     select is(tests.count_visible('profiles'), 1::bigint, 'teacher sees own login only');
select tests.login_as('student_a1');    select is(tests.count_visible('profiles'), 1::bigint, 'student sees own login only');
select tests.login_as('registrar_a');   select is(tests.count_visible('user_roles'), 5::bigint, 'registrar sees own role + student and parent roles');
select tests.login_as('teacher_a');     select is(tests.count_visible('user_roles'), 1::bigint, 'teacher sees own roles only');

-- ---------------------------------------------------------------------------
-- School setup, staff, audit log
-- ---------------------------------------------------------------------------
select tests.login_as('student_a1');    select is(tests.count_visible('sections'), 5::bigint, 'everyone in the school reads sections');
select tests.login_as('super_admin_b'); select is(tests.count_visible('sections'), 1::bigint, 'school B reads only its own sections');
select tests.login_as('parent_a1');     select is(tests.count_visible('schools'), 1::bigint, 'a user sees only their own school');
select tests.login_as('teacher_a');     select is(tests.count_visible('staff'), 2::bigint, 'teachers read the staff list');
select tests.login_as('student_a1');    select is(tests.count_visible('staff'), 0::bigint, 'students do not read staff');
select tests.login_as('super_admin_a'); select ok(tests.count_visible('audit_log') > 0, 'super admin reads the audit log');
select tests.login_as('director_a');    select ok(tests.count_visible('audit_log') > 0, 'director reads the audit log');
select tests.login_as('registrar_a');   select is(tests.count_visible('audit_log'), 0::bigint, 'registrar cannot read the audit log');

-- ---------------------------------------------------------------------------
-- Views apply the caller's RLS (security_invoker)
-- ---------------------------------------------------------------------------
select tests.login_as('teacher_a');   select is(tests.count_visible('v_students_current'), 1::bigint, 'view: teacher sees own class only');
select tests.login_as('parent_a1');   select is(tests.count_visible('v_students_current'), 1::bigint, 'view: parent sees own child only');
select tests.login_as('registrar_a'); select is(tests.count_visible('v_students_current'), 2::bigint, 'view: registrar sees all');
select tests.login_as('super_admin_b'); select is(tests.count_visible('v_section_occupancy'), 1::bigint, 'view: school B sees only its sections');
select tests.login_as('registrar_a');
select is((select active_count from public.v_section_occupancy where section_id = tests.id('s9_1_a')), 1,
          'view: section 9-1 shows 1 / 50');

-- ---------------------------------------------------------------------------
-- Writes
-- ---------------------------------------------------------------------------
select tests.login_as('teacher_a');
select throws_ok(
  format($$insert into public.students (school_id, first_name, father_name, gender) values (%L, 'X', 'Y', 'M')$$, tests.id('school_a')),
  '42501', null, 'teacher cannot add a student');

select tests.login_as('registrar_a');
select lives_ok(
  format($$insert into public.students (school_id, first_name, father_name, gender) values (%L, 'New', 'Student', 'M')$$, tests.id('school_a')),
  'registrar can add a student');
select throws_ok(
  format($$insert into public.students (school_id, first_name, father_name, gender) values (%L, 'X', 'Y', 'M')$$, tests.id('school_b')),
  '42501', null, 'registrar cannot add a student to another school');
select throws_ok(
  format($$insert into public.user_roles (school_id, user_id, role) values (%L, %L, 'super_admin')$$, tests.id('school_a'), tests.id('registrar_a')),
  '42501', null, 'registrar cannot give anyone the super_admin role');
select is(
  tests.rows_affected(format($$update public.profiles set is_active = false where id = %L$$, tests.id('parent_a1'))),
  1, 'registrar can switch off a parent login');
select is(
  tests.rows_affected(format($$update public.profiles set is_active = false where id = %L$$, tests.id('teacher_a'))),
  0, 'registrar cannot touch a teacher login');

select tests.login_as('director_a');
select is(
  tests.rows_affected(format($$update public.students set first_name = 'Changed' where id = %L$$, tests.id('st_a1'))),
  0, 'director cannot edit students (read only)');

select tests.login_as('super_admin_a');
select is(
  tests.rows_affected(format($$delete from public.students where id = %L$$, tests.id('st_a1'))),
  0, 'nobody can delete a student through the API');
select throws_ok(
  $$update public.audit_log set action = 'insert'$$,
  '42501', null, 'audit log cannot be edited');
select throws_ok(
  $$delete from public.audit_log$$,
  '42501', null, 'audit log cannot be deleted');

-- Profile: a user may change their own settings, not their login ID.
select tests.login_as('student_a1');
select is(tests.rows_affected($$update public.profiles set locale = 'am' where id = auth.uid()$$), 1,
          'a user can change their own language');
select throws_ok($$update public.profiles set login_id = 'HACKED' where id = auth.uid()$$,
                 '42501', null, 'a user cannot change their own login ID');
select is(tests.rows_affected(format($$update public.students set first_name = 'Me' where id = %L$$, tests.id('st_a1'))), 0,
          'a student cannot edit their own record');

-- ---------------------------------------------------------------------------
-- Inactive logins and platform admins
-- ---------------------------------------------------------------------------
select tests.logout();
update public.profiles set is_active = false where id = tests.id('teacher_a2');
select tests.login_as('teacher_a2');
select ok(auth.jwt() ->> 'school_id' is null, 'an inactive login gets no school in its token');
select is(tests.count_visible('sections'), 0::bigint, 'an inactive login sees nothing');

select tests.logout();
insert into auth.users (id, email) values (tests.keep('platform', gen_random_uuid()), 'platform@test.local');
insert into public.platform_admins (user_id) values (tests.id('platform'));
select tests.login_as('platform');
select ok(tests.count_visible('schools') >= 2, 'platform admin sees every school');
select lives_ok($$insert into public.schools (code, name) values ('NEW', 'New School')$$, 'platform admin can create a school');
select is(tests.count_visible('students'), 0::bigint, 'platform admin is not inside any school');

select tests.login_as('super_admin_a');
select throws_ok($$insert into public.schools (code, name) values ('NOPE', 'No')$$, '42501', null,
                 'a school super admin cannot create schools');

select tests.logout();
select throws_ok(format($$delete from public.students where id = %L$$, tests.id('st_a1')), '42501', null,
                 'even server code cannot hard-delete a student');

select * from finish();
rollback;
