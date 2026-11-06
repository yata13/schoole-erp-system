-- 0006_audit_soft_delete.sql
-- Audit triggers, the read-only audit log, no hard DELETE on people,
-- soft_delete() and restore().

-- ---------------------------------------------------------------------------
-- audit_row(): writes one audit_log row per insert / update / delete.
-- Updates store only the columns that changed. Setting deleted_at is logged
-- as 'soft_delete', clearing it as 'restore'.
-- Trigger argument = the key column to store as record_id (default 'id').
-- ---------------------------------------------------------------------------
create or replace function private.audit_row()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old     jsonb := case when tg_op in ('UPDATE', 'DELETE') then to_jsonb(old) end;
  v_new     jsonb := case when tg_op in ('INSERT', 'UPDATE') then to_jsonb(new) end;
  v_row     jsonb := coalesce(to_jsonb(new), to_jsonb(old));
  v_key     text := coalesce(tg_argv[0], 'id');
  v_action  text := lower(tg_op);
  v_old_chg jsonb;
  v_new_chg jsonb;
begin
  if tg_op = 'UPDATE' then
    select jsonb_object_agg(n.key, o.value), jsonb_object_agg(n.key, n.value)
      into v_old_chg, v_new_chg
    from jsonb_each(v_new) n
    join jsonb_each(v_old) o on o.key = n.key
    where n.value is distinct from o.value
      and n.key not in ('updated_at', 'last_login_at');

    if v_new_chg is null then
      return null;  -- nothing worth logging changed
    end if;

    if v_old ? 'deleted_at' then
      if v_old ->> 'deleted_at' is null and v_new ->> 'deleted_at' is not null then
        v_action := 'soft_delete';
      elsif v_old ->> 'deleted_at' is not null and v_new ->> 'deleted_at' is null then
        v_action := 'restore';
      end if;
    end if;

    v_old := v_old_chg;
    v_new := v_new_chg;
  end if;

  insert into public.audit_log (school_id, table_name, record_id, action, old_data, new_data, changed_by)
  values (
    (case when tg_table_name = 'schools' then v_row ->> 'id' else v_row ->> 'school_id' end)::uuid,
    tg_table_name,
    (v_row ->> v_key)::uuid,
    v_action,
    v_old,
    v_new,
    auth.uid()
  );
  return null;
end;
$$;

create trigger schools_audit after insert or update or delete on public.schools
  for each row execute function private.audit_row();
create trigger profiles_audit after insert or update or delete on public.profiles
  for each row execute function private.audit_row();
create trigger user_roles_audit after insert or update or delete on public.user_roles
  for each row execute function private.audit_row('user_id');
create trigger academic_years_audit after insert or update or delete on public.academic_years
  for each row execute function private.audit_row();
create trigger semesters_audit after insert or update or delete on public.semesters
  for each row execute function private.audit_row();
create trigger grades_audit after insert or update or delete on public.grades
  for each row execute function private.audit_row();
create trigger sections_audit after insert or update or delete on public.sections
  for each row execute function private.audit_row();
create trigger subjects_audit after insert or update or delete on public.subjects
  for each row execute function private.audit_row();
create trigger grade_subjects_audit after insert or update or delete on public.grade_subjects
  for each row execute function private.audit_row();
create trigger staff_audit after insert or update or delete on public.staff
  for each row execute function private.audit_row();
create trigger students_audit after insert or update or delete on public.students
  for each row execute function private.audit_row();
create trigger guardians_audit after insert or update or delete on public.guardians
  for each row execute function private.audit_row();
create trigger student_guardians_audit after insert or update or delete on public.student_guardians
  for each row execute function private.audit_row('student_id');
create trigger enrollments_audit after insert or update or delete on public.enrollments
  for each row execute function private.audit_row();
create trigger student_transfers_audit after insert or update or delete on public.student_transfers
  for each row execute function private.audit_row();
create trigger promotion_runs_audit after insert or update or delete on public.promotion_runs
  for each row execute function private.audit_row();

-- ---------------------------------------------------------------------------
-- audit_log is insert only. Nobody can edit or remove it, not even the
-- service key: these triggers refuse UPDATE, DELETE and TRUNCATE.
-- ---------------------------------------------------------------------------
create or replace function private.refuse_audit_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'audit_log is read-only' using errcode = '42501';
end;
$$;

create trigger audit_log_no_update_delete before update or delete on public.audit_log
  for each row execute function private.refuse_audit_change();
create trigger audit_log_no_truncate before truncate on public.audit_log
  for each statement execute function private.refuse_audit_change();

-- ---------------------------------------------------------------------------
-- No hard DELETE on students, guardians and staff. Soft delete only.
-- ---------------------------------------------------------------------------
create or replace function private.refuse_hard_delete()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'Rows in % cannot be deleted. Use soft_delete() instead', tg_table_name
    using errcode = '42501';
end;
$$;

create trigger students_no_delete before delete on public.students
  for each row execute function private.refuse_hard_delete();
create trigger guardians_no_delete before delete on public.guardians
  for each row execute function private.refuse_hard_delete();
create trigger staff_no_delete before delete on public.staff
  for each row execute function private.refuse_hard_delete();

-- ---------------------------------------------------------------------------
-- soft_delete() / restore(). SECURITY INVOKER: RLS decides who may do it.
-- p_table is one of: students, guardians, staff.
-- ---------------------------------------------------------------------------
create or replace function public.soft_delete(p_table text, p_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_count int;
begin
  if p_table not in ('students', 'guardians', 'staff') then
    raise exception 'Soft delete is not available for %', p_table using errcode = '22023';
  end if;

  execute format(
    'update public.%I
        set deleted_at = now(),
            deleted_by = (select p.id from public.profiles p where p.id = auth.uid())
      where school_id = public.current_school_id() and id = $1 and deleted_at is null',
    p_table)
  using p_id;

  get diagnostics v_count = row_count;
  if v_count = 0 then
    raise exception 'Nothing to delete: not found, not allowed, or already deleted' using errcode = 'P0002';
  end if;
end;
$$;

create or replace function public.restore(p_table text, p_id uuid)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_count int;
begin
  if p_table not in ('students', 'guardians', 'staff') then
    raise exception 'Restore is not available for %', p_table using errcode = '22023';
  end if;

  execute format(
    'update public.%I
        set deleted_at = null, deleted_by = null
      where school_id = public.current_school_id() and id = $1 and deleted_at is not null',
    p_table)
  using p_id;

  get diagnostics v_count = row_count;
  if v_count = 0 then
    raise exception 'Nothing to restore: not found, not allowed, or not deleted' using errcode = 'P0002';
  end if;
end;
$$;

revoke execute on function private.audit_row() from public;
revoke execute on function private.refuse_audit_change() from public;
revoke execute on function private.refuse_hard_delete() from public;
