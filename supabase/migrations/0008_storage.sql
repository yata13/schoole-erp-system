-- 0008_storage.sql
-- Private storage buckets. Rule: the first folder of every file path is the
-- school_id, so a user can only reach files of their own school.
--   student-photos/{school_id}/{student_id}/photo.jpg
--   staff-photos/{school_id}/{staff_id}/photo.jpg
--   imports/{school_id}/{import_job_id}/file.xlsx
--   documents/{school_id}/{student_id}/transfer-letter.pdf
--   school-assets/{school_id}/logo.png

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('student-photos', 'student-photos', false, 1048576,
     array['image/jpeg', 'image/png', 'image/webp']),
  ('staff-photos', 'staff-photos', false, 1048576,
     array['image/jpeg', 'image/png', 'image/webp']),
  ('imports', 'imports', false, 10485760,
     array['text/csv', 'application/vnd.ms-excel',
           'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']),
  ('documents', 'documents', false, 10485760,
     array['application/pdf', 'image/jpeg', 'image/png']),
  ('school-assets', 'school-assets', false, 2097152,
     array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

-- Read
create policy erp_objects_select on storage.objects for select to authenticated
  using (
    bucket_id in ('student-photos', 'staff-photos', 'imports', 'documents', 'school-assets')
    and (storage.foldername(name))[1] = (select public.current_school_id())::text
    and case bucket_id
      when 'school-assets' then true
      when 'student-photos' then
        (select public.has_any_role('{super_admin,director,registrar,finance}'))
        or (storage.foldername(name))[2] = (select public.current_student_id())::text
        or (storage.foldername(name))[2] = any ((select public.guardian_student_ids())::text[])
        or (storage.foldername(name))[2] = any ((select public.teacher_student_ids())::text[])
      when 'staff-photos' then
        (select public.has_any_role('{super_admin,director,registrar,teacher,finance}'))
      when 'imports' then
        (select public.has_any_role('{super_admin,registrar}'))
      when 'documents' then
        (select public.has_any_role('{super_admin,director,registrar}'))
      else false
    end
  );

-- Upload, replace, remove
create policy erp_objects_insert on storage.objects for insert to authenticated
  with check (
    bucket_id in ('student-photos', 'staff-photos', 'imports', 'documents', 'school-assets')
    and (storage.foldername(name))[1] = (select public.current_school_id())::text
    and case bucket_id
      when 'school-assets'  then (select public.has_role('super_admin'))
      when 'staff-photos'   then (select public.has_role('super_admin'))
      when 'student-photos' then (select public.has_any_role('{super_admin,registrar}'))
      when 'imports'        then (select public.has_any_role('{super_admin,registrar}'))
      when 'documents'      then (select public.has_any_role('{super_admin,registrar}'))
      else false
    end
  );

create policy erp_objects_update on storage.objects for update to authenticated
  using (
    bucket_id in ('student-photos', 'staff-photos', 'imports', 'documents', 'school-assets')
    and (storage.foldername(name))[1] = (select public.current_school_id())::text
    and case bucket_id
      when 'school-assets'  then (select public.has_role('super_admin'))
      when 'staff-photos'   then (select public.has_role('super_admin'))
      when 'student-photos' then (select public.has_any_role('{super_admin,registrar}'))
      when 'imports'        then (select public.has_any_role('{super_admin,registrar}'))
      when 'documents'      then (select public.has_any_role('{super_admin,registrar}'))
      else false
    end
  )
  with check (
    bucket_id in ('student-photos', 'staff-photos', 'imports', 'documents', 'school-assets')
    and (storage.foldername(name))[1] = (select public.current_school_id())::text
    and case bucket_id
      when 'school-assets'  then (select public.has_role('super_admin'))
      when 'staff-photos'   then (select public.has_role('super_admin'))
      when 'student-photos' then (select public.has_any_role('{super_admin,registrar}'))
      when 'imports'        then (select public.has_any_role('{super_admin,registrar}'))
      when 'documents'      then (select public.has_any_role('{super_admin,registrar}'))
      else false
    end
  );

create policy erp_objects_delete on storage.objects for delete to authenticated
  using (
    bucket_id in ('student-photos', 'staff-photos', 'imports', 'documents', 'school-assets')
    and (storage.foldername(name))[1] = (select public.current_school_id())::text
    and case bucket_id
      when 'school-assets'  then (select public.has_role('super_admin'))
      when 'staff-photos'   then (select public.has_role('super_admin'))
      when 'student-photos' then (select public.has_any_role('{super_admin,registrar}'))
      when 'imports'        then (select public.has_any_role('{super_admin,registrar}'))
      when 'documents'      then (select public.has_any_role('{super_admin,registrar}'))
      else false
    end
  );
