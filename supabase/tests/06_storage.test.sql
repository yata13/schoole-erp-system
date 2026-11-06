-- Storage: first folder must be my school_id; then per-bucket role rules.
begin;
create extension if not exists pgtap with schema extensions;
\ir support/helpers.psql
select tests.build_fixture();
select plan(9);

create function tests.photo_path(p_school text, p_student text) returns text
language sql stable as $$ select tests.id(p_school) || '/' || tests.id(p_student) || '/photo.jpg' $$;
grant execute on function tests.photo_path(text, text) to authenticated;

select tests.login_as('registrar_a');
select lives_ok(
  $$insert into storage.objects (bucket_id, name) values ('student-photos', tests.photo_path('school_a', 'st_a1'))$$,
  'registrar uploads a student photo into their school folder');
select throws_ok(
  $$insert into storage.objects (bucket_id, name) values ('student-photos', tests.photo_path('school_b', 'st_b1'))$$,
  '42501', null, 'registrar cannot upload into another school''s folder');
select throws_ok(
  $$insert into storage.objects (bucket_id, name) values ('school-assets', tests.id('school_a') || '/logo.png')$$,
  '42501', null, 'only the super admin uploads the school logo');

select tests.login_as('teacher_a');
select is(tests.count_visible_objects(), 1::bigint, 'homeroom teacher sees the photo of a student in their class');
select tests.login_as('teacher_a2');
select is(tests.count_visible_objects(), 0::bigint, 'another teacher does not');
select tests.login_as('student_a1');
select is(tests.count_visible_objects(), 1::bigint, 'the student sees their own photo');
select tests.login_as('parent_a1');
select is(tests.count_visible_objects(), 1::bigint, 'the parent sees their child''s photo');
select tests.login_as('parent_a2');
select is(tests.count_visible_objects(), 0::bigint, 'another parent does not');
select tests.login_as('super_admin_b');
select is(tests.count_visible_objects(), 0::bigint, 'another school sees nothing');

select * from finish();
rollback;
