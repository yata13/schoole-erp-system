-- 0017_no_anon_functions.sql
-- Signed-out visitors (anon) must not run any of our functions.
-- Supabase gives new functions to anon through a *global* default privilege,
-- which the schema-level revoke in 0007 does not remove, so functions made
-- after 0007 (my_student_ids, teacher_assignment_ids, save_attendance) were
-- executable by anon. They returned nothing without a login, but close it:
-- revoke now, and drop the global default so later functions start closed.

-- PUBLIC (everyone, including anon) gets EXECUTE on every new function by default.
revoke execute on all functions in schema public from public, anon;
revoke execute on all functions in schema private from public, anon;
alter default privileges revoke execute on functions from anon;
alter default privileges revoke execute on functions from public;

-- Signed-in users keep what the app calls (RLS helpers in private included).
grant execute on all functions in schema public to authenticated, service_role;
revoke execute on function public.custom_access_token_hook(jsonb) from authenticated, service_role;
grant execute on function private.login_is_student_or_parent(uuid) to authenticated;
grant execute on function private.session_school_id() to authenticated;
grant execute on function private.session_roles() to authenticated;
grant execute on function private.teaches(uuid, uuid) to authenticated;
