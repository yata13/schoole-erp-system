-- Structural rules that every table, view, policy and function must follow.
-- These also guard future migrations (Phase 2+).
begin;
create extension if not exists pgtap with schema extensions;
select plan(10);

-- 1. RLS is on for every table in public.
select is_empty(
  $$ select c.relname::text from pg_class c
     where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and not c.relrowsecurity $$,
  'every public table has RLS enabled'
);

-- 2. Every UNIQUE rule includes school_id
--    (tables that have school_id; plain primary keys on id are not "rules").
select is_empty(
  $$ select i.indexrelid::regclass::text
     from pg_index i
     join pg_class t on t.oid = i.indrelid
     where t.relnamespace = 'public'::regnamespace
       and i.indisunique
       and exists (select 1 from pg_attribute a
                   where a.attrelid = t.oid and a.attname = 'school_id' and not a.attisdropped)
       and not (i.indisprimary and i.indnkeyatts = 1)
       and not exists (select 1 from pg_attribute a
                       where a.attrelid = t.oid and a.attname = 'school_id'
                         and a.attnum = any (i.indkey::int2[])) $$,
  'every UNIQUE rule includes school_id'
);

-- 3. Every view is security_invoker, so RLS applies through it.
select is_empty(
  $$ select c.relname::text from pg_class c
     where c.relnamespace = 'public'::regnamespace and c.relkind in ('v', 'm')
       and not exists (select 1 from unnest(coalesce(c.reloptions, '{}')) o
                       where lower(o) in ('security_invoker=true', 'security_invoker=on', 'security_invoker=1')) $$,
  'every view is created WITH (security_invoker = true)'
);

-- 4. Every table with school_id has an index that starts with school_id.
select is_empty(
  $$ select t.relname::text from pg_class t
     join pg_attribute a on a.attrelid = t.oid and a.attname = 'school_id' and not a.attisdropped
     where t.relnamespace = 'public'::regnamespace and t.relkind = 'r'
       and not exists (select 1 from pg_index i where i.indrelid = t.oid and i.indkey[0] = a.attnum) $$,
  'every table with school_id has an index starting with school_id'
);

-- 5. Every foreign key has an index whose first columns are the FK columns.
select is_empty(
  $$ select format('%s.%s', c.conrelid::regclass, c.conname)
     from pg_constraint c
     where c.contype = 'f'
       and c.connamespace = 'public'::regnamespace
       and not exists (
         select 1 from pg_index i
         where i.indrelid = c.conrelid
           and (select array_agg(k order by k) from unnest(c.conkey) k)
             = (select array_agg(k order by k)
                from unnest((i.indkey::int2[])[0:cardinality(c.conkey) - 1]) k)) $$,
  'every foreign key column is indexed'
);

-- 6. Policies call the helpers through (select ...), never once per row.
select is_empty(
  $$ select format('%s.%s.%s', schemaname, tablename, policyname)
     from pg_policies
     where schemaname in ('public', 'storage')
       and regexp_replace(
             regexp_replace(coalesce(qual, '') || ' ' || coalesce(with_check, ''),
                            'SELECT (public\.|auth\.)?(current_school_id|has_role|has_any_role|is_platform_admin|current_staff_id|current_student_id|current_guardian_id|guardian_student_ids|teacher_section_ids|teacher_student_ids|teacher_assignment_ids|my_student_ids|uid|jwt)\(',
                            '', 'g'),
             '\s+', ' ', 'g')
           ~ '(current_school_id|has_role|has_any_role|is_platform_admin|current_staff_id|current_student_id|current_guardian_id|guardian_student_ids|teacher_section_ids|teacher_student_ids|teacher_assignment_ids|my_student_ids|auth\.uid|auth\.jwt|uid|jwt)\(' $$,
  'every policy calls helpers as (select fn())'
);

-- 7. Every function we own has a fixed search_path.
select is_empty(
  $$ select p.oid::regprocedure::text from pg_proc p
     where p.pronamespace in ('public'::regnamespace, 'private'::regnamespace)
       and p.prokind = 'f'
       and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%') $$,
  'every function sets search_path'
);

-- 8. Signed-out visitors (anon) have no rights on any table or view.
select is_empty(
  $$ select distinct table_name::text from information_schema.role_table_grants
     where grantee = 'anon' and table_schema = 'public' $$,
  'anon has no table privileges in public'
);

-- 10. Signed-out visitors (anon) cannot run any of our functions.
select is_empty(
  $$ select p.oid::regprocedure::text from pg_proc p
     where p.pronamespace in ('public'::regnamespace, 'private'::regnamespace)
       and p.prokind = 'f'
       and has_function_privilege('anon', p.oid, 'execute') $$,
  'anon cannot execute any public or private function'
);

-- 9. Nobody but the auth server can run the login-token hook.
select ok(
  not has_function_privilege('authenticated', 'public.custom_access_token_hook(jsonb)', 'execute')
  and not has_function_privilege('anon', 'public.custom_access_token_hook(jsonb)', 'execute')
  and has_function_privilege('supabase_auth_admin', 'public.custom_access_token_hook(jsonb)', 'execute'),
  'only supabase_auth_admin can run custom_access_token_hook'
);

select * from finish();
rollback;
