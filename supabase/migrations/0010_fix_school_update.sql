-- 0010_fix_school_update.sql
-- Fix: every UPDATE on public.schools failed with
--   record "new" has no field "school_id"
-- because stamp_row() read new.school_id in the same IF that skipped the
-- schools table (PL/pgSQL resolves every field of an expression up front).
-- The schools check now lives in its own IF, so the field is never read there.

create or replace function private.stamp_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.created_at := now();
    new.updated_at := new.created_at;
    if auth.uid() is not null then
      new.created_by := (select p.id from public.profiles p where p.id = auth.uid());
    end if;
  else
    new.created_at := old.created_at;
    new.created_by := old.created_by;
    new.updated_at := now();
    if tg_table_name <> 'schools' then
      if new.school_id is distinct from old.school_id then
        raise exception 'school_id cannot be changed on %', tg_table_name
          using errcode = '23514';
      end if;
    end if;
  end if;
  return new;
end;
$$;

revoke execute on function private.stamp_row() from public, anon, authenticated;
