-- 0007_rls_policies.sql
-- Who sees what (board 2). Rules:
-- * Every rule starts with school_id = (select current_school_id()).
-- * Helpers are always called as (select fn()), so Postgres runs them once
--   per query (an "initplan"), not once per row.
-- * One policy per table per action, so Postgres never has to OR several
--   permissive policies together.
-- * No DELETE policy on students, guardians, staff (soft delete only), and
--   none on audit_log.

alter table public.schools           enable row level security;
alter table public.profiles          enable row level security;
alter table public.user_roles        enable row level security;
alter table public.platform_admins   enable row level security;
alter table public.number_sequences  enable row level security;
alter table public.audit_log         enable row level security;
alter table public.academic_years    enable row level security;
alter table public.semesters         enable row level security;
alter table public.grades            enable row level security;
alter table public.sections          enable row level security;
alter table public.subjects          enable row level security;
alter table public.grade_subjects    enable row level security;
alter table public.staff             enable row level security;
alter table public.students          enable row level security;
alter table public.guardians         enable row level security;
alter table public.student_guardians enable row level security;
alter table public.enrollments       enable row level security;
alter table public.section_changes   enable row level security;
alter table public.student_transfers enable row level security;
alter table public.promotion_runs    enable row level security;
alter table public.import_jobs       enable row level security;

-- ===========================================================================
-- Access & system
-- ===========================================================================

-- schools: members read their own school; the super admin edits it;
-- platform admins create and edit schools.
create policy schools_select on public.schools for select to authenticated
  using (id = (select public.current_school_id()) or (select public.is_platform_admin()));
create policy schools_insert on public.schools for insert to authenticated
  with check ((select public.is_platform_admin()));
create policy schools_update on public.schools for update to authenticated
  using ((id = (select public.current_school_id()) and (select public.has_role('super_admin')))
         or (select public.is_platform_admin()))
  with check ((id = (select public.current_school_id()) and (select public.has_role('super_admin')))
              or (select public.is_platform_admin()));

-- profiles: self; super admin and director all; registrar only logins that
-- belong to students and parents. Logins are created by the create-users
-- Edge Function (service key), so there is no INSERT / DELETE policy.
create policy profiles_select on public.profiles for select to authenticated
  using (
    school_id = (select public.current_school_id())
    and (
      id = (select auth.uid())
      or (select public.has_any_role('{super_admin,director}'))
      or ((select public.has_role('registrar')) and private.login_is_student_or_parent(id))
    )
  );
create policy profiles_update on public.profiles for update to authenticated
  using (
    school_id = (select public.current_school_id())
    and (
      id = (select auth.uid())
      or (select public.has_role('super_admin'))
      or ((select public.has_role('registrar')) and private.login_is_student_or_parent(id))
    )
  )
  with check (
    school_id = (select public.current_school_id())
    and (
      id = (select auth.uid())
      or (select public.has_role('super_admin'))
      or ((select public.has_role('registrar')) and private.login_is_student_or_parent(id))
    )
  );

-- user_roles: self; super admin and director all; registrar student/parent roles.
create policy user_roles_select on public.user_roles for select to authenticated
  using (
    school_id = (select public.current_school_id())
    and (
      user_id = (select auth.uid())
      or (select public.has_any_role('{super_admin,director}'))
      or ((select public.has_role('registrar')) and role in ('student', 'parent'))
    )
  );
create policy user_roles_insert on public.user_roles for insert to authenticated
  with check (
    school_id = (select public.current_school_id())
    and (
      (select public.has_role('super_admin'))
      or ((select public.has_role('registrar')) and role in ('student', 'parent'))
    )
  );
create policy user_roles_delete on public.user_roles for delete to authenticated
  using (
    school_id = (select public.current_school_id())
    and (
      (select public.has_role('super_admin'))
      or ((select public.has_role('registrar')) and role in ('student', 'parent'))
    )
  );

-- platform_admins: you can see your own row only. Managed with SQL.
create policy platform_admins_select on public.platform_admins for select to authenticated
  using (user_id = (select auth.uid()));

-- number_sequences: written only by next_number(); the super admin can look.
create policy number_sequences_select on public.number_sequences for select to authenticated
  using (school_id = (select public.current_school_id()) and (select public.has_role('super_admin')));

-- audit_log: super admin and director read. Written only by the audit trigger.
create policy audit_log_select on public.audit_log for select to authenticated
  using (
    school_id = (select public.current_school_id())
    and (select public.has_any_role('{super_admin,director}'))
  );

-- The login-token hook runs as supabase_auth_admin and must read these.
create policy schools_auth_admin_select on public.schools for select to supabase_auth_admin
  using (true);
create policy profiles_auth_admin_select on public.profiles for select to supabase_auth_admin
  using (true);
create policy user_roles_auth_admin_select on public.user_roles for select to supabase_auth_admin
  using (true);

-- ===========================================================================
-- School setup: everyone in the school reads; super admin and registrar edit.
-- ===========================================================================
create policy academic_years_select on public.academic_years for select to authenticated
  using (school_id = (select public.current_school_id()));
create policy academic_years_insert on public.academic_years for insert to authenticated
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,registrar}')));
create policy academic_years_update on public.academic_years for update to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,registrar}')))
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,registrar}')));
create policy academic_years_delete on public.academic_years for delete to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,registrar}')));

create policy semesters_select on public.semesters for select to authenticated
  using (school_id = (select public.current_school_id()));
create policy semesters_insert on public.semesters for insert to authenticated
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,registrar}')));
create policy semesters_update on public.semesters for update to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,registrar}')))
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,registrar}')));
create policy semesters_delete on public.semesters for delete to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,registrar}')));

create policy grades_select on public.grades for select to authenticated
  using (school_id = (select public.current_school_id()));
create policy grades_insert on public.grades for insert to authenticated
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,registrar}')));
create policy grades_update on public.grades for update to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,registrar}')))
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,registrar}')));
create policy grades_delete on public.grades for delete to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,registrar}')));

create policy sections_select on public.sections for select to authenticated
  using (school_id = (select public.current_school_id()));
create policy sections_insert on public.sections for insert to authenticated
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,registrar}')));
create policy sections_update on public.sections for update to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,registrar}')))
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,registrar}')));
create policy sections_delete on public.sections for delete to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,registrar}')));

create policy subjects_select on public.subjects for select to authenticated
  using (school_id = (select public.current_school_id()));
create policy subjects_insert on public.subjects for insert to authenticated
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,registrar}')));
create policy subjects_update on public.subjects for update to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,registrar}')))
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,registrar}')));
create policy subjects_delete on public.subjects for delete to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,registrar}')));

create policy grade_subjects_select on public.grade_subjects for select to authenticated
  using (school_id = (select public.current_school_id()));
create policy grade_subjects_insert on public.grade_subjects for insert to authenticated
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,registrar}')));
create policy grade_subjects_update on public.grade_subjects for update to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,registrar}')))
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,registrar}')));
create policy grade_subjects_delete on public.grade_subjects for delete to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,registrar}')));

-- ===========================================================================
-- People
-- ===========================================================================

-- staff: school staff roles read; the super admin edits. Everyone sees their own row.
create policy staff_select on public.staff for select to authenticated
  using (
    school_id = (select public.current_school_id())
    and (
      (select public.has_any_role('{super_admin,director,registrar,teacher,finance}'))
      or profile_id = (select auth.uid())
    )
  );
create policy staff_insert on public.staff for insert to authenticated
  with check (school_id = (select public.current_school_id())
              and (select public.has_role('super_admin')));
create policy staff_update on public.staff for update to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_role('super_admin')))
  with check (school_id = (select public.current_school_id())
              and (select public.has_role('super_admin')));

-- students: super admin, director, registrar, finance read all; teacher own
-- classes; student self; parent own children. Super admin and registrar edit.
create policy students_select on public.students for select to authenticated
  using (
    school_id = (select public.current_school_id())
    and (
      (select public.has_any_role('{super_admin,director,registrar,finance}'))
      or (
        deleted_at is null
        and (
          id = (select public.current_student_id())
          or id = any ((select public.guardian_student_ids())::uuid[])
          or id = any ((select public.teacher_student_ids())::uuid[])
        )
      )
    )
  );
create policy students_insert on public.students for insert to authenticated
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,registrar}')));
create policy students_update on public.students for update to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,registrar}')))
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,registrar}')));

-- guardians: like students. A parent sees their own guardian row; a student
-- and a teacher see the guardians linked to their students.
create policy guardians_select on public.guardians for select to authenticated
  using (
    school_id = (select public.current_school_id())
    and (
      (select public.has_any_role('{super_admin,director,registrar,finance}'))
      or (
        deleted_at is null
        and (
          id = (select public.current_guardian_id())
          or exists (
            select 1 from public.student_guardians sg
            where sg.school_id = guardians.school_id
              and sg.guardian_id = guardians.id
              and (sg.student_id = (select public.current_student_id())
                   or sg.student_id = any ((select public.teacher_student_ids())::uuid[]))
          )
        )
      )
    )
  );
create policy guardians_insert on public.guardians for insert to authenticated
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,registrar}')));
create policy guardians_update on public.guardians for update to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,registrar}')))
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,registrar}')));

create policy student_guardians_select on public.student_guardians for select to authenticated
  using (
    school_id = (select public.current_school_id())
    and (
      (select public.has_any_role('{super_admin,director,registrar,finance}'))
      or student_id = (select public.current_student_id())
      or student_id = any ((select public.guardian_student_ids())::uuid[])
      or student_id = any ((select public.teacher_student_ids())::uuid[])
    )
  );
create policy student_guardians_insert on public.student_guardians for insert to authenticated
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,registrar}')));
create policy student_guardians_update on public.student_guardians for update to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,registrar}')))
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,registrar}')));
create policy student_guardians_delete on public.student_guardians for delete to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,registrar}')));

-- ===========================================================================
-- Enrollment & registrar
-- ===========================================================================
create policy enrollments_select on public.enrollments for select to authenticated
  using (
    school_id = (select public.current_school_id())
    and (
      (select public.has_any_role('{super_admin,director,registrar,finance}'))
      or student_id = (select public.current_student_id())
      or student_id = any ((select public.guardian_student_ids())::uuid[])
      or section_id = any ((select public.teacher_section_ids())::uuid[])
    )
  );
create policy enrollments_insert on public.enrollments for insert to authenticated
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,registrar}')));
create policy enrollments_update on public.enrollments for update to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,registrar}')))
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,registrar}')));
create policy enrollments_delete on public.enrollments for delete to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,registrar}')));

-- Registrar records: super admin and registrar edit, director reads.
create policy section_changes_select on public.section_changes for select to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,director,registrar}')));
create policy section_changes_insert on public.section_changes for insert to authenticated
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,registrar}')));

create policy student_transfers_select on public.student_transfers for select to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,director,registrar}')));
create policy student_transfers_insert on public.student_transfers for insert to authenticated
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,registrar}')));
create policy student_transfers_update on public.student_transfers for update to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,registrar}')))
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,registrar}')));

create policy promotion_runs_select on public.promotion_runs for select to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,director,registrar}')));
create policy promotion_runs_insert on public.promotion_runs for insert to authenticated
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,registrar}')));
create policy promotion_runs_update on public.promotion_runs for update to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,registrar}')))
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,registrar}')));

create policy import_jobs_select on public.import_jobs for select to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,director,registrar}')));
create policy import_jobs_insert on public.import_jobs for insert to authenticated
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,registrar}')));
create policy import_jobs_update on public.import_jobs for update to authenticated
  using (school_id = (select public.current_school_id())
         and (select public.has_any_role('{super_admin,registrar}')))
  with check (school_id = (select public.current_school_id())
              and (select public.has_any_role('{super_admin,registrar}')));

-- ===========================================================================
-- Grants. RLS is the gate; these remove what the API should never offer.
-- ===========================================================================
-- Signed-out visitors (anon) get nothing. Logging in goes through Supabase Auth.
revoke all on all tables in schema public from anon;
revoke execute on all functions in schema public from public, anon;
-- TRUNCATE skips RLS, so the API roles may not use it.
revoke truncate, references, trigger on all tables in schema public from authenticated;
-- The audit log is insert-only even for server code.
revoke insert, update, delete, truncate on public.audit_log from authenticated, service_role;
grant execute on all functions in schema public to authenticated, service_role;
revoke execute on function public.custom_access_token_hook(jsonb) from authenticated, service_role;

-- Same rules for tables and functions made by later migrations.
alter default privileges in schema public revoke all on tables from anon;
alter default privileges in schema public revoke truncate, references, trigger on tables from authenticated;
alter default privileges in schema public revoke execute on functions from public, anon;

-- Internal functions: only what RLS itself calls is executable by API users.
revoke execute on all functions in schema private from public, anon, authenticated;
grant execute on function private.login_is_student_or_parent(uuid) to authenticated;
