-- seed.sql: 1 school, 4 grades, 40 sections, the subjects and what each grade takes.
-- Runs after the migrations on `supabase db reset`. No logins here: make the
-- first super admin with the create-users Edge Function.
-- Fixed ids so local links and tests stay stable.

insert into public.schools (id, code, name, name_am, phone, address, pass_mark, max_section_size, default_locale)
values ('00000000-0000-4000-a000-000000000001', 'AHS', 'Addis Demo High School',
        'አዲስ ማሳያ ሁለተኛ ደረጃ ትምህርት ቤት', '+251111234567', 'Addis Ababa', 50, 50, 'en');

-- 2019 E.C. = Meskerem 1, 2019 (11 Sep 2026) to Sene 30, 2019 (7 Jul 2027).
insert into public.academic_years (id, school_id, ec_year, name, start_date, end_date, is_current, status)
values ('00000000-0000-4000-a000-000000002019', '00000000-0000-4000-a000-000000000001',
        2019, '2019 E.C.', '2026-09-11', '2027-07-07', true, 'active');

insert into public.semesters (school_id, academic_year_id, number, start_date, end_date, is_current, status)
values
  ('00000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-000000002019', 1, '2026-09-11', '2027-01-31', true,  'open'),
  ('00000000-0000-4000-a000-000000000001', '00000000-0000-4000-a000-000000002019', 2, '2027-02-01', '2027-07-07', false, 'open');

insert into public.grades (id, school_id, level, name, name_am)
values
  ('00000000-0000-4000-a000-000000000009', '00000000-0000-4000-a000-000000000001',  9, 'Grade 9',  '9ኛ ክፍል'),
  ('00000000-0000-4000-a000-000000000010', '00000000-0000-4000-a000-000000000001', 10, 'Grade 10', '10ኛ ክፍል'),
  ('00000000-0000-4000-a000-000000000011', '00000000-0000-4000-a000-000000000001', 11, 'Grade 11', '11ኛ ክፍል'),
  ('00000000-0000-4000-a000-000000000012', '00000000-0000-4000-a000-000000000001', 12, 'Grade 12', '12ኛ ክፍል');

-- 10 sections per grade: 9-1 ... 12-10. Grades 11-12: sections 1-6 Natural, 7-10 Social.
insert into public.sections (school_id, academic_year_id, grade_id, name, stream, room)
select '00000000-0000-4000-a000-000000000001',
       '00000000-0000-4000-a000-000000002019',
       g.id,
       g.level || '-' || n,
       case when g.level < 11 then null
            when n <= 6 then 'natural'::public.stream
            else 'social'::public.stream end,
       'Room ' || g.level || lpad(n::text, 2, '0')
from public.grades g
cross join generate_series(1, 10) as n
where g.school_id = '00000000-0000-4000-a000-000000000001';

insert into public.subjects (school_id, code, name, name_am)
values
  ('00000000-0000-4000-a000-000000000001', 'AMH',  'Amharic',                     'አማርኛ'),
  ('00000000-0000-4000-a000-000000000001', 'ENG',  'English',                     'እንግሊዝኛ'),
  ('00000000-0000-4000-a000-000000000001', 'MATH', 'Mathematics',                 'ሂሳብ'),
  ('00000000-0000-4000-a000-000000000001', 'PHY',  'Physics',                     'ፊዚክስ'),
  ('00000000-0000-4000-a000-000000000001', 'CHEM', 'Chemistry',                   'ኬሚስትሪ'),
  ('00000000-0000-4000-a000-000000000001', 'BIO',  'Biology',                     'ባዮሎጂ'),
  ('00000000-0000-4000-a000-000000000001', 'GEO',  'Geography',                   'ጂኦግራፊ'),
  ('00000000-0000-4000-a000-000000000001', 'HIST', 'History',                     'ታሪክ'),
  ('00000000-0000-4000-a000-000000000001', 'CIT',  'Citizenship',                 'የዜግነት ትምህርት'),
  ('00000000-0000-4000-a000-000000000001', 'ICT',  'Information Technology',      'የመረጃ ቴክኖሎጂ'),
  ('00000000-0000-4000-a000-000000000001', 'HPE',  'Health and Physical Education', 'ጤናና የሰውነት ማጎልመሻ'),
  ('00000000-0000-4000-a000-000000000001', 'ECON', 'Economics',                   'ኢኮኖሚክስ'),
  ('00000000-0000-4000-a000-000000000001', 'AGRI', 'Agriculture',                 'ግብርና'),
  ('00000000-0000-4000-a000-000000000001', 'BUS',  'General Business',            'ጠቅላላ ንግድ');

-- What each grade (and stream) takes. sort_order = order on the report card.
with plan(levels, stream, code, periods, sort_order) as (
  values
    (array[9, 10],  null::public.stream, 'AMH',  4, 1),
    (array[9, 10],  null,                'ENG',  5, 2),
    (array[9, 10],  null,                'MATH', 5, 3),
    (array[9, 10],  null,                'PHY',  3, 4),
    (array[9, 10],  null,                'CHEM', 3, 5),
    (array[9, 10],  null,                'BIO',  3, 6),
    (array[9, 10],  null,                'GEO',  3, 7),
    (array[9, 10],  null,                'HIST', 3, 8),
    (array[9, 10],  null,                'CIT',  2, 9),
    (array[9, 10],  null,                'ICT',  2, 10),
    (array[9, 10],  null,                'HPE',  2, 11),
    (array[11, 12], null,                'ENG',  5, 1),
    (array[11, 12], null,                'MATH', 5, 2),
    (array[11, 12], null,                'CIT',  2, 3),
    (array[11, 12], null,                'ICT',  2, 4),
    (array[11, 12], null,                'HPE',  2, 5),
    (array[11, 12], 'natural',           'PHY',  4, 6),
    (array[11, 12], 'natural',           'CHEM', 4, 7),
    (array[11, 12], 'natural',           'BIO',  4, 8),
    (array[11, 12], 'natural',           'AGRI', 3, 9),
    (array[11, 12], 'social',            'GEO',  4, 6),
    (array[11, 12], 'social',            'HIST', 4, 7),
    (array[11, 12], 'social',            'ECON', 4, 8),
    (array[11, 12], 'social',            'BUS',  3, 9)
)
insert into public.grade_subjects (school_id, grade_id, subject_id, stream, periods_per_week, sort_order)
select g.school_id, g.id, s.id, p.stream, p.periods, p.sort_order
from plan p
join public.grades g on g.school_id = '00000000-0000-4000-a000-000000000001' and g.level = any (p.levels)
join public.subjects s on s.school_id = g.school_id and s.code = p.code;
