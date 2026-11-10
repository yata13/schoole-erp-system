-- With the login-token hook off, school and roles come from the database,
-- and every rule gives the same answer as with the hook on.
begin;
create extension if not exists pgtap with schema extensions;
\ir support/helpers.psql
select tests.build_fixture();
select plan(11);

select tests.login_without_hook('registrar_a');
select is(public.current_school_id(), tests.id('school_a'), 'no hook: school comes from the database');
select ok(public.has_role('registrar') and not public.has_role('super_admin'), 'no hook: roles come from the database');
select is(public.my_access(), jsonb_build_object('school_id', tests.id('school_a'), 'user_roles', '["registrar"]'::jsonb),
          'no hook: my_access() returns school and roles');
select is(tests.count_visible('students'), 2::bigint, 'no hook: registrar sees all students of the school');

select tests.login_without_hook('teacher_a');
select is(tests.count_visible('students'), 1::bigint, 'no hook: teacher still sees only their class');
select tests.login_without_hook('parent_a1');
select is(tests.count_visible('students'), 1::bigint, 'no hook: parent still sees only their child');
select tests.login_without_hook('super_admin_b');
select is(tests.count_visible('students'), 1::bigint, 'no hook: school B still sees only school B');

select tests.login_as('registrar_a');
select is(public.my_access(), jsonb_build_object('school_id', tests.id('school_a'), 'user_roles', '["registrar"]'::jsonb),
          'with hook: my_access() reads the token');

select tests.logout();
update public.profiles set is_active = false where id = tests.id('teacher_a2');
select tests.login_without_hook('teacher_a2');
select is(public.current_school_id(), null, 'no hook: an inactive login gets no school');
select is(tests.count_visible('sections'), 0::bigint, 'no hook: an inactive login sees nothing');

select tests.logout();
update public.schools set is_active = false where id = tests.id('school_b');
select tests.login_without_hook('super_admin_b');
select is(tests.count_visible('sections'), 0::bigint, 'no hook: a login of an inactive school sees nothing');

select * from finish();
rollback;
