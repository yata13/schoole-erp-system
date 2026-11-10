-- 0009_access_without_hook.sql
-- School and roles still work when the login-token hook is off.
--
-- The hook (custom_access_token_hook) always writes a "user_roles" claim, so:
-- * token has "user_roles"  -> the hook ran: trust the token (fast path, as before)
-- * token has no "user_roles" -> the hook is off: read the same facts from
--   the database, with the same rule (inactive login or school gets nothing).
-- Policies call these helpers as (select fn()), so the lookup runs once per
-- query, not once per row.

-- The signed-in user's school, from the database. Internal.
create or replace function private.session_school_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.school_id
  from public.profiles p
  join public.schools s on s.id = p.school_id
  where p.id = auth.uid() and p.is_active and s.is_active
$$;

-- The signed-in user's roles, from the database. Internal.
create or replace function private.session_roles()
returns text[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(ur.role::text order by ur.role), '{}')
  from public.user_roles ur
  where ur.user_id = auth.uid() and ur.school_id = private.session_school_id()
$$;

create or replace function public.current_school_id()
returns uuid
language sql
stable
set search_path = ''
as $$
  select case
    when auth.jwt() ? 'user_roles' then nullif(auth.jwt() ->> 'school_id', '')::uuid
    else private.session_school_id()
  end
$$;

create or replace function public.has_role(p_role public.app_role)
returns boolean
language sql
stable
set search_path = ''
as $$
  select case
    when auth.jwt() ? 'user_roles' then coalesce((auth.jwt() -> 'user_roles') ? p_role::text, false)
    else p_role::text = any (private.session_roles())
  end
$$;

create or replace function public.has_any_role(p_roles public.app_role[])
returns boolean
language sql
stable
set search_path = ''
as $$
  select case
    when auth.jwt() ? 'user_roles' then coalesce((auth.jwt() -> 'user_roles') ?| p_roles::text[], false)
    else p_roles::text[] && private.session_roles()
  end
$$;

-- What the app needs after login: my school and my roles (token or database).
create or replace function public.my_access()
returns jsonb
language sql
stable
set search_path = ''
as $$
  select jsonb_build_object(
    'school_id', public.current_school_id(),
    'user_roles', case
      when auth.jwt() ? 'user_roles' then auth.jwt() -> 'user_roles'
      else to_jsonb(private.session_roles())
    end)
$$;

revoke execute on function private.session_school_id() from public, anon;
revoke execute on function private.session_roles() from public, anon;
grant execute on function private.session_school_id() to authenticated;
grant execute on function private.session_roles() to authenticated;
revoke execute on function public.my_access() from public, anon;
grant execute on function public.my_access() to authenticated, service_role;
