-- seed-demo.sql — a full demo school for showing the system. TEST DATA ONLY.
--
-- Builds Addis Demo High School (code AHS), year 2019 E.C.:
--   KG1-KG3, grades 1-12, sections A and B (11-12: A natural, B social), max 30
--   ~60 staff (teachers, cleaners, guards, drivers, cooks, nurse, office)
--   ~780 students with guardians, attendance since 14 Sep 2026, marks,
--   fees + invoices + payments, expenses, fines, teaching roadmaps
--   demo logins (password Demo@1234; admin Admin@1234):
--     ADMIN, DIRECTOR, REGISTRAR, FINANCE, T-001 (teacher), AHS-19-0100 (student), 0911000001 (parent)
--
-- Run after the migrations and seed.sql, on a school with no students yet:
--   psql ... -f supabase/seed-demo.sql
-- Deterministic: setseed() makes every run produce the same data.

begin;

select setseed(0.2019);

-- Bulk load: skip the per-row audit log (the load itself is the "change").
do $$
declare r record;
begin
  for r in select tgrelid::regclass as tbl, tgname from pg_trigger
           where not tgisinternal and tgname like '%\_audit' and tgrelid::regclass::text like 'public.%'
  loop
    execute format('alter table %s disable trigger %I', r.tbl, r.tgname);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Login helper (temporary): auth user + identity + profile + roles.
-- ---------------------------------------------------------------------------
create function pg_temp.make_login(p_school uuid, p_login text, p_name text, p_password text, p_roles text[])
returns uuid language plpgsql as $$
declare
  v_id    uuid;
  v_code  text := (select lower(code) from public.schools where id = p_school);
  v_local text := lower(regexp_replace(upper(btrim(p_login)), '^\+', ''));
  v_email text := v_local || '@' || v_code || '.erp.local';
begin
  select id into v_id from auth.users where email = v_email;
  if v_id is null then
    v_id := gen_random_uuid();
    insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                            raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                            confirmation_token, recovery_token, email_change, email_change_token_new)
    values ('00000000-0000-0000-0000-000000000000', v_id, 'authenticated', 'authenticated', v_email,
            extensions.crypt(p_password, extensions.gen_salt('bf')), now(),
            '{"provider": "email", "providers": ["email"]}', '{}', now(), now(), '', '', '', '');
    insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
    values (gen_random_uuid(), v_id, v_id::text,
            jsonb_build_object('sub', v_id::text, 'email', v_email, 'email_verified', true), 'email', now(), now(), now());
  end if;
  insert into public.profiles (id, school_id, login_id, full_name)
  values (v_id, p_school, upper(btrim(p_login)), p_name)
  on conflict (id) do update set full_name = excluded.full_name, is_active = true;
  insert into public.user_roles (school_id, user_id, role)
  select p_school, v_id, r::public.app_role from unnest(p_roles) r
  on conflict do nothing;
  return v_id;
end $$;

create function pg_temp.pick(arr text[]) returns text language sql volatile as $$
  select arr[1 + floor(random() * array_length(arr, 1))::int]
$$;

-- ---------------------------------------------------------------------------
-- School, year, semesters
-- ---------------------------------------------------------------------------
insert into public.schools (id, code, name, name_am, phone, address, pass_mark, max_section_size)
values ('00000000-0000-4000-a000-000000000001', 'AHS', 'Addis Demo High School',
        'አዲስ ማሳያ ትምህርት ቤት', '+251111234567', 'Bole, Addis Ababa', 50, 30)
on conflict (code) do update set max_section_size = 30, address = excluded.address;

create temp table demo (k text primary key, v uuid) on commit drop;
insert into demo values ('school', (select id from public.schools where code = 'AHS'));

do $$
begin
  if exists (select 1 from public.students where school_id = (select v from demo where k = 'school')) then
    raise exception 'The demo school already has students. Load the demo only once, on an empty school.';
  end if;
end $$;

insert into public.academic_years (school_id, ec_year, name, start_date, end_date, is_current, status)
select v, 2019, '2019 E.C.', '2026-09-11', '2027-07-07', true, 'active' from demo where k = 'school'
on conflict (school_id, ec_year) do nothing;
insert into demo select 'year', id from public.academic_years
where school_id = (select v from demo where k = 'school') and ec_year = 2019;

insert into public.semesters (school_id, academic_year_id, number, start_date, end_date, is_current)
select (select v from demo where k = 'school'), (select v from demo where k = 'year'), n,
       case n when 1 then date '2026-09-11' else date '2027-02-01' end,
       case n when 1 then date '2027-01-31' else date '2027-07-07' end, n = 1
from generate_series(1, 2) n
on conflict (school_id, academic_year_id, number) do nothing;
insert into demo select 'sem1', id from public.semesters
where school_id = (select v from demo where k = 'school') and academic_year_id = (select v from demo where k = 'year') and number = 1;

-- Clear the old 9-12 setup from seed.sql (nothing depends on it yet).
delete from public.grade_subjects where school_id = (select v from demo where k = 'school');
delete from public.sections       where school_id = (select v from demo where k = 'school');
delete from public.grades         where school_id = (select v from demo where k = 'school');
delete from public.subjects       where school_id = (select v from demo where k = 'school');

-- ---------------------------------------------------------------------------
-- Grades KG1-KG3, 1-12 and sections A/B
-- ---------------------------------------------------------------------------
insert into public.grades (school_id, level, name, name_am)
select (select v from demo where k = 'school'), l,
       case when l <= 0 then 'KG' || (l + 3) else 'Grade ' || l end,
       case when l <= 0 then 'ኬጂ ' || (l + 3) else l || 'ኛ ክፍል' end
from generate_series(-2, 12) l;

insert into public.sections (school_id, academic_year_id, grade_id, name, stream, room, capacity)
select g.school_id, (select v from demo where k = 'year'), g.id,
       case when g.level <= 0 then 'KG' || (g.level + 3) || '-' || s else g.level || s end,
       case when g.level < 11 then null when s = 'A' then 'natural'::public.stream else 'social'::public.stream end,
       'Room ' || (case when g.level <= 0 then 'K' || (g.level + 3) else g.level::text end) || s,
       30
from public.grades g cross join unnest(array['A', 'B']) s
where g.school_id = (select v from demo where k = 'school');

-- ---------------------------------------------------------------------------
-- Subjects and what each grade takes
-- ---------------------------------------------------------------------------
insert into public.subjects (school_id, code, name, name_am)
select (select v from demo where k = 'school'), c, n, a from (values
  ('AMH', 'Amharic', 'አማርኛ'), ('ENG', 'English', 'እንግሊዝኛ'), ('MATH', 'Mathematics', 'ሂሳብ'),
  ('ENV', 'Environmental Science', 'አካባቢ ሳይንስ'), ('ART', 'Art and Music', 'ኪነ ጥበብ'),
  ('HPE', 'Health and Physical Education', 'ጤናና የሰውነት ማጎልመሻ'), ('GSC', 'General Science', 'አጠቃላይ ሳይንስ'),
  ('SSC', 'Social Studies', 'ማህበራዊ ሳይንስ'), ('CIT', 'Citizenship', 'የዜግነት ትምህርት'), ('ICT', 'Information Technology', 'የመረጃ ቴክኖሎጂ'),
  ('PHY', 'Physics', 'ፊዚክስ'), ('CHEM', 'Chemistry', 'ኬሚስትሪ'), ('BIO', 'Biology', 'ባዮሎጂ'),
  ('GEO', 'Geography', 'ጂኦግራፊ'), ('HIST', 'History', 'ታሪክ'), ('ECON', 'Economics', 'ኢኮኖሚክስ'),
  ('BUS', 'General Business', 'ጠቅላላ ንግድ'), ('AGRI', 'Agriculture', 'ግብርና')
) x(c, n, a);

with plan(lo, hi, stream, codes) as (values
  (-2,  0, null::public.stream, array['ENG', 'AMH', 'MATH', 'ENV', 'ART']),
  ( 1,  4, null,                array['AMH', 'ENG', 'MATH', 'ENV', 'ART', 'HPE']),
  ( 5,  8, null,                array['AMH', 'ENG', 'MATH', 'GSC', 'SSC', 'CIT', 'ICT', 'HPE']),
  ( 9, 10, null,                array['AMH', 'ENG', 'MATH', 'PHY', 'CHEM', 'BIO', 'GEO', 'HIST', 'CIT', 'ICT', 'HPE']),
  (11, 12, null,                array['ENG', 'MATH', 'CIT', 'ICT', 'HPE']),
  (11, 12, 'natural',           array['PHY', 'CHEM', 'BIO', 'AGRI']),
  (11, 12, 'social',            array['GEO', 'HIST', 'ECON', 'BUS'])
)
insert into public.grade_subjects (school_id, grade_id, subject_id, stream, periods_per_week, sort_order)
select g.school_id, g.id, sub.id, p.stream, case when sub.code in ('MATH', 'ENG') then 5 else 3 end, c.ord
from plan p
join public.grades g on g.school_id = (select v from demo where k = 'school') and g.level between p.lo and p.hi
cross join lateral unnest(p.codes) with ordinality c(code, ord)
join public.subjects sub on sub.school_id = g.school_id and sub.code = c.code;

-- ---------------------------------------------------------------------------
-- Staff: teachers by subject, office, and support staff, with salaries
-- ---------------------------------------------------------------------------
create temp table staff_seed (code text, first text, father text, gender text, position text,
                              salary numeric, spec text[], qual text) on commit drop;
insert into staff_seed values
  ('D-001', 'Mulugeta', 'Assefa',  'M', 'director',   25000, '{}', 'MA Educational Leadership'),
  ('R-001', 'Tigist',   'Bekele',  'F', 'registrar',  14000, '{}', 'BA Management'),
  ('F-001', 'Selamawit','Haile',   'F', 'accountant', 13500, '{}', 'BA Accounting'),
  ('F-002', 'Daniel',   'Getachew','M', 'cashier',     9000, '{}', 'Diploma Accounting'),
  ('L-001', 'Rahel',    'Tesfaye', 'F', 'librarian',   8000, '{}', 'Diploma Library Science'),
  ('N-001', 'Meron',    'Desta',   'F', 'nurse',       9500, '{}', 'BSc Nursing'),
  ('T-001', 'Yonas',    'Girma',   'M', 'teacher',    13000, '{MATH}', 'BSc Mathematics'),
  ('T-002', 'Hana',     'Alemu',   'F', 'teacher',    12000, '{MATH}', 'BSc Mathematics'),
  ('T-003', 'Biruk',    'Tadesse', 'M', 'teacher',    11500, '{MATH}', 'BEd Mathematics'),
  ('T-004', 'Selam',    'Kebede',  'F', 'teacher',    11000, '{MATH}', 'BEd Mathematics'),
  ('T-005', 'Dawit',    'Mekonnen','M', 'teacher',    12500, '{ENG}', 'BA English'),
  ('T-006', 'Bethlehem','Wolde',   'F', 'teacher',    11500, '{ENG}', 'BA English'),
  ('T-007', 'Samuel',   'Ayele',   'M', 'teacher',    11000, '{ENG}', 'BEd English'),
  ('T-008', 'Liya',     'Mengistu','F', 'teacher',    10500, '{ENG}', 'BEd English'),
  ('T-009', 'Tewodros', 'Abera',   'M', 'teacher',    11000, '{AMH}', 'BA Amharic'),
  ('T-010', 'Mahlet',   'Lemma',   'F', 'teacher',    10500, '{AMH}', 'BA Amharic'),
  ('T-011', 'Henok',    'Gebre',   'M', 'teacher',    10000, '{AMH}', 'BEd Amharic'),
  ('T-012', 'Kalkidan', 'Negash',  'F', 'teacher',    11000, '{ENV,GSC}', 'BSc Biology'),
  ('T-013', 'Eyob',     'Teshome', 'M', 'teacher',    11000, '{ENV,GSC}', 'BSc Chemistry'),
  ('T-014', 'Ruth',     'Worku',   'F', 'teacher',    10500, '{SSC,CIT}', 'BA Civics'),
  ('T-015', 'Natnael',  'Yilma',   'M', 'teacher',    10500, '{SSC,CIT}', 'BA History'),
  ('T-016', 'Abel',     'Zewdu',   'M', 'teacher',    13500, '{PHY}', 'MSc Physics'),
  ('T-017', 'Helen',    'Fikre',   'F', 'teacher',    13000, '{CHEM}', 'MSc Chemistry'),
  ('T-018', 'Robel',    'Hailu',   'M', 'teacher',    12500, '{BIO,AGRI}', 'BSc Biology'),
  ('T-019', 'Saron',    'Berhanu', 'F', 'teacher',    12000, '{GEO}', 'BA Geography'),
  ('T-020', 'Ermias',   'Shiferaw','M', 'teacher',    12000, '{HIST}', 'BA History'),
  ('T-021', 'Tsion',    'Tilahun', 'F', 'teacher',    12500, '{ECON,BUS}', 'BA Economics'),
  ('T-022', 'Kidus',    'Asfaw',   'M', 'teacher',    11500, '{ICT}', 'BSc Computer Science'),
  ('T-023', 'Eden',     'Demissie','F', 'teacher',    11000, '{ICT}', 'BSc Information Systems'),
  ('T-024', 'Yared',    'Assefa',  'M', 'teacher',    10000, '{HPE}', 'BSc Sport Science'),
  ('T-025', 'Feven',    'Girma',   'F', 'teacher',     9500, '{HPE}', 'Diploma Sport Science'),
  ('T-026', 'Mikiyas',  'Tesfaye', 'M', 'teacher',     9500, '{ART}', 'BA Fine Arts'),
  ('K-001', 'Hiwot',    'Bekele',  'F', 'teacher',     9000, '{KG}', 'Diploma Early Childhood'),
  ('K-002', 'Blen',     'Alemu',   'F', 'teacher',     9000, '{KG}', 'Diploma Early Childhood'),
  ('K-003', 'Tsehay',   'Haile',   'F', 'teacher',     9000, '{KG}', 'Diploma Early Childhood'),
  ('K-004', 'Meskerem', 'Kebede',  'F', 'teacher',     8500, '{KG}', 'Diploma Early Childhood'),
  ('K-005', 'Genet',    'Tadesse', 'F', 'teacher',     8500, '{KG}', 'Diploma Early Childhood'),
  ('K-006', 'Almaz',    'Desta',   'F', 'teacher',     8500, '{KG}', 'Diploma Early Childhood'),
  ('C-001', 'Tsige',    'Ayana',   'F', 'cleaner',     4200, '{}', null),
  ('C-002', 'Aster',    'Gutema',  'F', 'cleaner',     4200, '{}', null),
  ('C-003', 'Workitu',  'Beyene',  'F', 'cleaner',     4000, '{}', null),
  ('C-004', 'Zewditu',  'Mola',    'F', 'cleaner',     4000, '{}', null),
  ('C-005', 'Abebe',    'Kassa',   'M', 'cleaner',     4000, '{}', null),
  ('G-001', 'Tesfaye',  'Bogale',  'M', 'guard',       5000, '{}', null),
  ('G-002', 'Getahun',  'Ali',     'M', 'guard',       4800, '{}', null),
  ('G-003', 'Shimelis', 'Dagne',   'M', 'guard',       4800, '{}', null),
  ('G-004', 'Fekadu',   'Tola',    'M', 'guard',       4800, '{}', null),
  ('V-001', 'Mesfin',   'Wondimu', 'M', 'driver',      6500, '{}', 'Driving licence grade 4'),
  ('V-002', 'Solomon',  'Hailu',   'M', 'driver',      6500, '{}', 'Driving licence grade 4'),
  ('O-001', 'Askale',   'Mamo',    'F', 'cook',        4800, '{}', null),
  ('O-002', 'Belaynesh','Tefera',  'F', 'cook',        4800, '{}', null);

insert into public.staff (school_id, staff_code, first_name, father_name, gender, phone, position,
                          hire_date, qualification, employment_type)
select (select v from demo where k = 'school'), s.code, s.first, s.father, s.gender::public.gender,
       '+2519' || lpad((20000000 + row_number() over (order by s.code))::text, 8, '0'),
       s.position::public.staff_position,
       date '2026-09-01' - (365 * (1 + floor(random() * 9)))::int,
       s.qual,
       case when s.position in ('cleaner', 'cook') and random() < 0.3 then 'part_time'::public.employment_type
            else 'full_time' end
from staff_seed s;

insert into public.staff_salaries (school_id, staff_id, monthly_salary, effective_from)
select st.school_id, st.id, s.salary, '2026-09-01'
from staff_seed s join public.staff st on st.school_id = (select v from demo where k = 'school') and st.staff_code = s.code;

-- ---------------------------------------------------------------------------
-- Homeroom teachers: KG teachers take KG sections; the others the rest.
-- T-001 (Maths) is the homeroom teacher of 8A, the demo student's class.
-- ---------------------------------------------------------------------------
with kg_sections as (
  select sec.id, row_number() over (order by g.level, sec.name) rn
  from public.sections sec join public.grades g on g.id = sec.grade_id
  where sec.school_id = (select v from demo where k = 'school') and g.level <= 0
), kg_teachers as (
  select st.id, row_number() over (order by st.staff_code) rn
  from public.staff st where st.school_id = (select v from demo where k = 'school') and st.staff_code like 'K-%'
)
update public.sections s set homeroom_teacher_id = t.id
from kg_sections k join kg_teachers t on t.rn = k.rn
where s.id = k.id;

with other_sections as (
  select sec.id, row_number() over (order by (sec.name = '8A') desc, g.level, sec.name) rn
  from public.sections sec join public.grades g on g.id = sec.grade_id
  where sec.school_id = (select v from demo where k = 'school') and g.level >= 1
), teachers as (
  select st.id, row_number() over (order by st.staff_code) rn, count(*) over () cnt
  from public.staff st where st.school_id = (select v from demo where k = 'school') and st.staff_code like 'T-%'
)
update public.sections s set homeroom_teacher_id = t.id
from other_sections o join teachers t on t.rn = o.rn
where s.id = o.id;

-- ---------------------------------------------------------------------------
-- Who teaches what: KG teachers teach their own class; others by subject, in turn.
-- ---------------------------------------------------------------------------
insert into public.teaching_assignments (school_id, staff_id, section_id, subject_id)
select sec.school_id, sec.homeroom_teacher_id, sec.id, gs.subject_id
from public.sections sec
join public.grades g on g.id = sec.grade_id
join public.grade_subjects gs on gs.school_id = sec.school_id and gs.grade_id = sec.grade_id
where sec.school_id = (select v from demo where k = 'school') and g.level <= 0;

with need as (
  select sec.id as section_id, sub.id as subject_id, sub.code,
         row_number() over (partition by sub.code order by g.level, sec.name) as rn
  from public.sections sec
  join public.grades g on g.id = sec.grade_id
  join public.grade_subjects gs on gs.school_id = sec.school_id and gs.grade_id = sec.grade_id
                                and (gs.stream is null or gs.stream = sec.stream)
  join public.subjects sub on sub.id = gs.subject_id
  where sec.school_id = (select v from demo where k = 'school') and g.level >= 1
), spec as (
  select st.id as staff_id, c.code,
         row_number() over (partition by c.code order by st.staff_code) - 1 as idx,
         count(*) over (partition by c.code) as cnt
  from staff_seed s
  cross join lateral unnest(s.spec) c(code)
  join public.staff st on st.school_id = (select v from demo where k = 'school') and st.staff_code = s.code
  where c.code <> 'KG'
)
insert into public.teaching_assignments (school_id, staff_id, section_id, subject_id)
select (select v from demo where k = 'school'), spec.staff_id, need.section_id, need.subject_id
from need join spec on spec.code = need.code and spec.idx = (need.rn - 1) % spec.cnt;

-- The demo teacher teaches Maths in 8A and 8B.
update public.teaching_assignments ta set staff_id = (select id from public.staff where school_id = ta.school_id and staff_code = 'T-001')
from public.sections sec, public.subjects sub
where ta.school_id = (select v from demo where k = 'school')
  and sec.id = ta.section_id and sec.name in ('8A', '8B')
  and sub.id = ta.subject_id and sub.code = 'MATH';

-- ---------------------------------------------------------------------------
-- Students, guardians, enrollments
-- ---------------------------------------------------------------------------
create temp table names (male text[], female text[], father text[]) on commit drop;
insert into names values (
  array['Abebe','Dawit','Yonas','Samuel','Biruk','Henok','Natnael','Kaleb','Eyob','Abel','Dagim','Nahom','Mikiyas',
        'Bereket','Fitsum','Robel','Yared','Tewodros','Ermias','Amanuel','Leul','Kidus','Elias','Mesfin','Daniel',
        'Yohannes','Haile','Surafel','Barok','Nebiyu','Kirubel','Yosef','Abenezer','Matiyas','Siraj'],
  array['Hana','Selam','Bethlehem','Meron','Tigist','Liya','Ruth','Mahlet','Saron','Helen','Hiwot','Eden','Blen',
        'Kalkidan','Rahel','Tsion','Mekdes','Yordanos','Bezawit','Feven','Selamawit','Lidya','Marta','Sara',
        'Netsanet','Kidist','Firehiwot','Abigail','Hermela','Nardos','Arsema','Ruhama','Soliyana','Maya','Edom'],
  array['Alemu','Bekele','Tesfaye','Girma','Kebede','Haile','Tadesse','Mulugeta','Getachew','Wolde','Desta','Asfaw',
        'Mengistu','Abera','Lemma','Gebre','Ayele','Assefa','Demissie','Negash','Teshome','Worku','Yilma','Zewdu',
        'Fikre','Hailu','Berhanu','Mekonnen','Shiferaw','Tilahun','Gutema','Tola','Ali','Mohammed','Dagne']);

-- The demo student (fixed ID so the demo login is known): Liya Tesfaye, 8A.
insert into public.students (school_id, student_code, first_name, father_name, grandfather_name, gender,
                             birth_date, sub_city, woreda, admission_date)
values ((select v from demo where k = 'school'), 'AHS-19-0100', 'Liya', 'Tesfaye', 'Alemu', 'F',
        '2012-05-14', 'Bole', '03', '2020-09-10');
insert into demo select 'demo_student', id from public.students where student_code = 'AHS-19-0100'
  and school_id = (select v from demo where k = 'school');
insert into public.enrollments (school_id, student_id, academic_year_id, grade_id, section_id, enrolled_on)
select sec.school_id, (select v from demo where k = 'demo_student'), sec.academic_year_id, sec.grade_id, sec.id, '2026-09-11'
from public.sections sec where sec.school_id = (select v from demo where k = 'school') and sec.name = '8A';

-- Everyone else: 22-30 per section (8A gets one fewer, the demo student is in it).
create temp table new_students on commit drop as
select sec.id as section_id, sec.grade_id, g.level, n,
       case when random() < 0.5 then 'M' else 'F' end as gender
from public.sections sec
join public.grades g on g.id = sec.grade_id
cross join lateral generate_series(1, 22 + floor(random() * 9)::int - case when sec.name = '8A' then 1 else 0 end) n
where sec.school_id = (select v from demo where k = 'school');

alter table new_students add column first text, add column father text, add column grandfather text, add column student_id uuid;
update new_students set
  first = case when gender = 'M' then pg_temp.pick((select male from names)) else pg_temp.pick((select female from names)) end,
  father = pg_temp.pick((select father from names)),
  grandfather = pg_temp.pick((select father from names));

-- One row at a time keeps student IDs in class order (KG1-A first).
do $$
declare r record; v_id uuid;
begin
  for r in select ns.ctid as rid, ns.* from new_students ns order by ns.level, ns.section_id, ns.n loop
    insert into public.students (school_id, first_name, father_name, grandfather_name, gender, birth_date,
                                 sub_city, woreda, admission_date)
    values ((select v from demo where k = 'school'), r.first, r.father, r.grandfather, r.gender::public.gender,
            make_date(2020 - r.level - 1, 1 + floor(random() * 12)::int, 1 + floor(random() * 28)::int),
            (array['Bole','Yeka','Kirkos','Arada','Lideta','Kolfe Keranio','Nifas Silk-Lafto','Akaky Kaliti'])[1 + floor(random() * 8)::int],
            lpad((1 + floor(random() * 14))::text, 2, '0'),
            make_date(2026 - greatest(0, floor(random() * (r.level + 3))::int), 9, 10))
    returning id into v_id;
    update new_students set student_id = v_id where ctid = r.rid;
  end loop;
end $$;

insert into public.enrollments (school_id, student_id, academic_year_id, grade_id, section_id, enrolled_on)
select (select v from demo where k = 'school'), ns.student_id, (select v from demo where k = 'year'), ns.grade_id, ns.section_id, '2026-09-11'
from new_students ns order by ns.level, ns.section_id, ns.n;

-- Guardians: one per student (father or mother). The demo parent has phone 0911000001.
insert into public.guardians (school_id, full_name, phone, occupation)
values ((select v from demo where k = 'school'), 'Tesfaye Alemu', '+251911000001', 'Engineer');
insert into public.student_guardians (school_id, student_id, guardian_id, relationship, is_primary)
select g.school_id, (select v from demo where k = 'demo_student'), g.id, 'father', true
from public.guardians g where g.school_id = (select v from demo where k = 'school') and g.phone = '+251911000001';

with s as (
  select st.id as student_id, st.father_name, st.grandfather_name,
         row_number() over (order by st.student_code) as rn, random() as r
  from public.students st
  where st.school_id = (select v from demo where k = 'school') and st.student_code <> 'AHS-19-0100'
), g as (
  insert into public.guardians (school_id, full_name, phone, occupation)
  select (select v from demo where k = 'school'),
         case when s.r < 0.7 then s.father_name || ' ' || s.grandfather_name
              else pg_temp.pick((select female from names)) || ' ' || pg_temp.pick((select father from names)) end,
         '+2519' || lpad((11000001 + s.rn)::text, 8, '0'),
         pg_temp.pick(array['Teacher','Merchant','Engineer','Nurse','Driver','Civil servant','Doctor','Accountant','Farmer','Business owner'])
  from s
  returning id, phone
)
insert into public.student_guardians (school_id, student_id, guardian_id, relationship, is_primary)
select (select v from demo where k = 'school'), s.student_id, g.id,
       case when s.r < 0.7 then 'father'::public.guardian_relationship
            when s.r < 0.95 then 'mother' else 'guardian' end, true
from s join g on g.phone = '+2519' || lpad((11000001 + s.rn)::text, 8, '0');

-- ---------------------------------------------------------------------------
-- Attendance: every school day from 14 Sep 2026 to 10 Nov 2026
-- ---------------------------------------------------------------------------
create temp table ability on commit drop as
select e.id as enrollment_id, e.section_id, e.student_id,
       0.55 + random() * 0.4 as skill,
       0.01 + random() * 0.07 as absent_rate
from public.enrollments e
where e.school_id = (select v from demo where k = 'school');
update ability set skill = 0.93, absent_rate = 0.02 where student_id = (select v from demo where k = 'demo_student');

insert into public.attendance_sessions (school_id, section_id, date, taken_by)
select sec.school_id, sec.id, d::date, null
from public.sections sec
cross join generate_series(date '2026-09-14', date '2026-11-10', interval '1 day') d
where sec.school_id = (select v from demo where k = 'school') and extract(isodow from d) <= 5;

insert into public.attendance_records (school_id, session_id, enrollment_id, status)
select x.school_id, x.session_id, x.enrollment_id,
       case when x.r < x.absent_rate then 'absent'::public.attendance_status
            when x.r < x.absent_rate + 0.03 then 'late'
            when x.r < x.absent_rate + 0.035 then 'excused'
            else 'present' end
from (select s.school_id, s.id as session_id, a.enrollment_id, a.absent_rate, random() as r   -- random() per row
      from public.attendance_sessions s
      join ability a on a.section_id = s.section_id
      where s.school_id = (select v from demo where k = 'school')) x;

-- ---------------------------------------------------------------------------
-- Marks: semester 1 Quiz, Assignment, Test and Mid exam are in (60 of 100)
-- ---------------------------------------------------------------------------
insert into public.assessment_types (school_id, name, name_am, max_score, sort_order)
select (select v from demo where k = 'school'), n, a, m, o from (values
  ('Quiz', 'ፈተና (አጭር)', 10, 1), ('Assignment', 'የቤት ሥራ', 10, 2), ('Test', 'ፈተና', 15, 3),
  ('Mid exam', 'የመካከለኛ ፈተና', 25, 4), ('Final exam', 'የመጨረሻ ፈተና', 40, 5)
) x(n, a, m, o)
on conflict (school_id, name) do nothing;

insert into public.marks (school_id, enrollment_id, semester_id, subject_id, assessment_type_id, score)
select e.school_id, e.id, (select v from demo where k = 'sem1'), gs.subject_id, at.id,
       least(at.max_score, greatest(0, round((at.max_score * (a.skill + (random() - 0.5) * 0.3)) * 2) / 2))
from public.enrollments e
join ability a on a.enrollment_id = e.id
join public.sections sec on sec.id = e.section_id
join public.grade_subjects gs on gs.school_id = e.school_id and gs.grade_id = e.grade_id
                              and (gs.stream is null or gs.stream = sec.stream)
join public.assessment_types at on at.school_id = e.school_id and at.name in ('Quiz', 'Assignment', 'Test', 'Mid exam')
where e.school_id = (select v from demo where k = 'school');

-- ---------------------------------------------------------------------------
-- Fees, invoices, payments
-- ---------------------------------------------------------------------------
insert into public.fee_types (school_id, name, name_am, frequency) values
  ((select v from demo where k = 'school'), 'Registration', 'ምዝገባ', 'once'),
  ((select v from demo where k = 'school'), 'Tuition', 'የትምህርት ክፍያ', 'monthly');

insert into public.fee_structures (school_id, academic_year_id, grade_id, fee_type_id, amount)
select g.school_id, (select v from demo where k = 'year'), g.id, ft.id,
       case when ft.name = 'Registration' then 1000
            when g.level <= 0 then 1500 when g.level <= 4 then 1800 when g.level <= 8 then 2200
            when g.level <= 10 then 2800 else 3200 end
from public.grades g cross join public.fee_types ft
where g.school_id = (select v from demo where k = 'school') and ft.school_id = g.school_id;

create temp table bill on commit drop as
select e.id as enrollment_id, ft.id as fee_type_id, ft.name as fee_name, fs.amount,
       m.period, m.period_start, m.due_date, m.pay_rate, m.pay_from, m.pay_to,
       case when ft.name = 'Tuition' and a.skill > 0.9 and random() < 0.5 then round(fs.amount * 0.1) else 0 end as discount
from public.enrollments e
join ability a on a.enrollment_id = e.id
join public.fee_structures fs on fs.school_id = e.school_id and fs.grade_id = e.grade_id
join public.fee_types ft on ft.id = fs.fee_type_id
join (values
  ('Registration', 'Registration 2019', date '2026-08-01', date '2026-09-10', 1.00, date '2026-08-10', date '2026-09-10'),
  ('Tuition', 'Meskerem 2019', date '2026-09-01', date '2026-09-20', 0.97, date '2026-09-12', date '2026-09-28'),
  ('Tuition', 'Tikimt 2019',   date '2026-10-01', date '2026-10-20', 0.90, date '2026-10-05', date '2026-10-28'),
  ('Tuition', 'Hidar 2019',    date '2026-11-01', date '2026-11-20', 0.55, date '2026-11-01', date '2026-11-10')
) m(fee, period, period_start, due_date, pay_rate, pay_from, pay_to) on m.fee = ft.name
where e.school_id = (select v from demo where k = 'school');

insert into public.invoices (school_id, enrollment_id, fee_type_id, period, period_start, due_date, total, discount)
select (select v from demo where k = 'school'), b.enrollment_id, b.fee_type_id, b.period, b.period_start, b.due_date, b.amount, b.discount
from bill b order by b.period_start, b.enrollment_id;

insert into public.payments (school_id, invoice_id, amount, method, reference_no, paid_on)
select x.school_id, x.invoice_id,
       case when x.r < x.pay_rate then x.owed else round(x.owed / 2) end,
       x.method,
       case when x.method = 'cash' then null
            when x.method = 'telebirr' then 'TB' || upper(substr(md5(x.invoice_id::text), 1, 10))
            else 'CBE-' || upper(substr(md5(x.invoice_id::text), 11, 8)) end,
       x.paid_on
from (select i.school_id, i.id as invoice_id, i.total - i.discount as owed, b.pay_rate,
             random() as r,                                                                  -- random() per row
             (array['telebirr','telebirr','bank','bank','cash'])[1 + floor(random() * 5)::int]::public.payment_method as method,
             b.pay_from + floor(random() * (b.pay_to - b.pay_from + 1))::int as paid_on
      from public.invoices i
      join bill b on b.enrollment_id = i.enrollment_id and b.period = i.period
      where i.school_id = (select v from demo where k = 'school')) x
where x.r < x.pay_rate + 0.04
order by x.paid_on;

-- ---------------------------------------------------------------------------
-- Expenses: salaries, power, water, internet, fuel, food, supplies, repairs
-- ---------------------------------------------------------------------------
insert into public.expenses (school_id, category, description, amount, spent_on, paid_to, method)
select (select v from demo where k = 'school'), c::public.expense_category, d, a, s, p, 'bank'
from (values
  ('salary',      'Staff salaries — Hamle',     (select sum(salary) from staff_seed), date '2026-08-28', 'All staff'),
  ('salary',      'Staff salaries — Meskerem',  (select sum(salary) from staff_seed), date '2026-09-30', 'All staff'),
  ('salary',      'Staff salaries — Tikimt',    (select sum(salary) from staff_seed), date '2026-10-30', 'All staff'),
  ('maintenance', 'Classroom painting (summer)', 46000, date '2026-08-12', 'Abay Painting PLC'),
  ('supplies',    'Textbooks and exercise books', 82000, date '2026-08-20', 'Mega Book Store'),
  ('supplies',    'Chalk, markers, paper',          9800, date '2026-09-08', 'Bole Stationery'),
  ('supplies',    'Lab chemicals',                 14500, date '2026-10-06', 'Ethio Lab Supply'),
  ('utilities',   'Electricity — Meskerem',          5200, date '2026-10-02', 'Ethiopian Electric Utility'),
  ('utilities',   'Electricity — Tikimt',            5650, date '2026-11-02', 'Ethiopian Electric Utility'),
  ('utilities',   'Water — Meskerem',                1850, date '2026-10-03', 'AAWSA'),
  ('utilities',   'Water — Tikimt',                  1920, date '2026-11-03', 'AAWSA'),
  ('utilities',   'Internet — Meskerem',             3500, date '2026-09-05', 'Ethio Telecom'),
  ('utilities',   'Internet — Tikimt',               3500, date '2026-10-05', 'Ethio Telecom'),
  ('utilities',   'Internet — Hidar',                3500, date '2026-11-05', 'Ethio Telecom'),
  ('transport',   'School bus fuel — Meskerem',     12800, date '2026-09-29', 'Total Energies'),
  ('transport',   'School bus fuel — Tikimt',       13400, date '2026-10-29', 'Total Energies'),
  ('transport',   'Bus service and tyres',           9200, date '2026-10-14', 'Moenco'),
  ('food',        'Cafeteria supplies — Meskerem',  18500, date '2026-09-25', 'Shola Market traders'),
  ('food',        'Cafeteria supplies — Tikimt',    19200, date '2026-10-24', 'Shola Market traders'),
  ('maintenance', 'Plumbing repair, block B',        4300, date '2026-10-19', 'Local technician'),
  ('rent',        'Sports field rent',               6000, date '2026-09-15', 'Kebele 07')
) x(c, d, a, s, p);

-- ---------------------------------------------------------------------------
-- Fines and discipline (ቅጣት)
-- ---------------------------------------------------------------------------
insert into public.fines (school_id, student_id, kind, reason, amount, issued_on, status, resolved_on)
select i.school_id, e.student_id, 'late_payment', 'Late payment — ' || i.period || ' (' || i.invoice_no || ')', 100,
       date '2026-10-25', case when random() < 0.35 then 'paid'::public.fine_status else 'open' end, null
from public.invoices i join public.enrollments e on e.id = i.enrollment_id
where i.school_id = (select v from demo where k = 'school') and i.period = 'Tikimt 2019' and i.status <> 'paid';

insert into public.fines (school_id, student_id, kind, reason, amount, issued_on, status)
select a.school_id, a.student_id, k.kind::public.fine_kind, k.reason, k.amount,
       date '2026-09-20' + floor(random() * 50)::int,
       case when random() < 0.4 then 'paid'::public.fine_status when random() < 0.2 then 'waived' else 'open' end
from (select e.school_id, e.student_id, row_number() over (order by random()) rn
      from public.enrollments e join public.grades g on g.id = e.grade_id
      where e.school_id = (select v from demo where k = 'school') and g.level >= 3
        and e.student_id <> (select v from demo where k = 'demo_student')) a
join (values
  (1, 'discipline', 'Late to class many times', 0), (2, 'discipline', 'Uniform not worn', 0),
  (3, 'discipline', 'Mobile phone in class', 0), (4, 'discipline', 'Fighting in the playground', 0),
  (5, 'discipline', 'Skipped class', 0), (6, 'discipline', 'Disrespect to a teacher', 0),
  (7, 'discipline', 'Homework not done (repeated)', 0), (8, 'discipline', 'Late to class many times', 0),
  (9, 'discipline', 'Uniform not worn', 0), (10, 'discipline', 'Mobile phone in class', 0),
  (11, 'discipline', 'Skipped class', 0), (12, 'discipline', 'Late to class many times', 0),
  (13, 'damage', 'Broken chair in classroom', 350), (14, 'damage', 'Broken window, block A', 600),
  (15, 'damage', 'Damaged lab equipment', 450), (16, 'damage', 'Writing on desks', 150),
  (17, 'lost_item', 'Lost library book', 250), (18, 'lost_item', 'Lost library book', 250),
  (19, 'lost_item', 'Lost sports kit', 300), (20, 'other', 'Replacement ID card', 50)
) k(rn, kind, reason, amount) on k.rn = a.rn;

update public.fines set resolved_on = issued_on + 5 where status in ('paid', 'waived') and resolved_on is null;

-- ---------------------------------------------------------------------------
-- Teaching roadmap: 16 weeks per class and subject; 8 done, week 9 in progress
-- ---------------------------------------------------------------------------
insert into public.lesson_plans (school_id, teaching_assignment_id, week_no, planned_on, topic, objectives, status, done_on)
select ta.school_id, ta.id, w,
       date '2026-09-14' + (w - 1) * 7,
       sub.name || ' — Unit ' || ((w + 1) / 2) || ': ' ||
         (case sub.code
           when 'MATH' then (array['Numbers and operations','Fractions and decimals','Algebraic expressions','Equations','Geometry basics','Measurement','Data and graphs','Ratio and proportion'])
           when 'ENG'  then (array['Reading for meaning','Grammar: tenses','Vocabulary building','Speaking practice','Writing paragraphs','Listening skills','Poems and stories','Letter writing'])
           when 'AMH'  then (array['ንባብ','ሰዋስው','የቃላት ጥናት','መናገር','ድርሰት','ማዳመጥ','ግጥም','ደብዳቤ'])
           when 'PHY'  then (array['Measurement','Motion','Forces','Work and energy','Heat','Waves','Electricity','Magnetism'])
           when 'CHEM' then (array['Matter','Atomic structure','Periodic table','Chemical bonding','Reactions','Acids and bases','Solutions','Organic basics'])
           when 'BIO'  then (array['Cells','Classification','Plants','Human body','Nutrition','Genetics','Ecology','Health'])
           else (array['Introduction','Key ideas','Practice','Project work','Review','Applications','Group work','Assessment'])
         end)[1 + ((w + 1) / 2 - 1) % 8],
       'Students can explain and apply the main ideas of this lesson.',
       case when w <= 8 - (case when random() < 0.25 then 1 else 0 end) then 'done'::public.lesson_status
            when w = 9 then 'in_progress' else 'planned' end,
       case when w <= 8 then date '2026-09-14' + (w - 1) * 7 + 4 end
from public.teaching_assignments ta
join public.subjects sub on sub.id = ta.subject_id
cross join generate_series(1, 16) w
where ta.school_id = (select v from demo where k = 'school');
update public.lesson_plans set done_on = null where status <> 'done';

-- ---------------------------------------------------------------------------
-- Demo logins (password Demo@1234; admin Admin@1234)
-- ---------------------------------------------------------------------------
select pg_temp.make_login((select v from demo where k = 'school'), 'ADMIN', 'Test Admin', 'Admin@1234', array['super_admin']);
update public.staff set profile_id = pg_temp.make_login(school_id, 'DIRECTOR', 'Mulugeta Assefa', 'Demo@1234', array['director'])
 where school_id = (select v from demo where k = 'school') and staff_code = 'D-001';
update public.staff set profile_id = pg_temp.make_login(school_id, 'REGISTRAR', 'Tigist Bekele', 'Demo@1234', array['registrar'])
 where school_id = (select v from demo where k = 'school') and staff_code = 'R-001';
update public.staff set profile_id = pg_temp.make_login(school_id, 'FINANCE', 'Selamawit Haile', 'Demo@1234', array['finance'])
 where school_id = (select v from demo where k = 'school') and staff_code = 'F-001';
update public.staff set profile_id = pg_temp.make_login(school_id, 'T-001', 'Yonas Girma', 'Demo@1234', array['teacher'])
 where school_id = (select v from demo where k = 'school') and staff_code = 'T-001';
update public.students set profile_id = pg_temp.make_login(school_id, 'AHS-19-0100', 'Liya Tesfaye', 'Demo@1234', array['student'])
 where id = (select v from demo where k = 'demo_student');
update public.guardians set profile_id = pg_temp.make_login(school_id, '+251911000001', 'Tesfaye Alemu', 'Demo@1234', array['parent'])
 where school_id = (select v from demo where k = 'school') and phone = '+251911000001';

-- Audit log back on.
do $$
declare r record;
begin
  for r in select tgrelid::regclass as tbl, tgname from pg_trigger
           where not tgisinternal and tgname like '%\_audit' and tgrelid::regclass::text like 'public.%'
  loop
    execute format('alter table %s enable trigger %I', r.tbl, r.tgname);
  end loop;
end $$;

commit;

select (select count(*) from public.students) as students,
       (select count(*) from public.staff) as staff,
       (select count(*) from public.sections) as sections,
       (select count(*) from public.attendance_records) as attendance,
       (select count(*) from public.marks) as marks,
       (select count(*) from public.invoices) as invoices,
       (select count(*) from public.payments) as payments,
       (select count(*) from public.lesson_plans) as lesson_plans,
       (select count(*) from public.fines) as fines;
