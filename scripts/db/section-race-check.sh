#!/usr/bin/env bash
# Two sessions race for the last seat of a section (49 / 50 taken).
# Session A takes seat 50 and holds its transaction open for 2 seconds;
# session B tries seat 51 at the same moment. Because the enrollment trigger
# locks the section row (SELECT ... FOR UPDATE) before counting, B waits for A,
# then counts 50 and is refused.
#
#   PGHOST=/var/run/postgresql PGPORT=54322 PGUSER=postgres scripts/db/section-race-check.sh [db]
set -euo pipefail
DB="${1:-school_erp_dev}"
export PGUSER="${PGUSER:-postgres}"
q() { psql -X -q -v ON_ERROR_STOP=1 -d "$DB" "$@"; }

q <<'SQL'
delete from public.enrollments where school_id = (select id from public.schools where code = 'RACE');
SQL
q <<'SQL' > /dev/null
insert into public.schools (id, code, name) values ('00000000-0000-4000-b000-000000000001', 'RACE', 'Race Test')
  on conflict (code) do nothing;
insert into public.academic_years (id, school_id, ec_year, name, start_date, end_date, is_current, status)
  values ('00000000-0000-4000-b000-000000000002', '00000000-0000-4000-b000-000000000001', 2019, '2019 E.C.',
          '2026-09-11', '2027-07-07', true, 'active') on conflict do nothing;
insert into public.grades (id, school_id, level, name)
  values ('00000000-0000-4000-b000-000000000003', '00000000-0000-4000-b000-000000000001', 9, 'Grade 9')
  on conflict do nothing;
insert into public.sections (id, school_id, academic_year_id, grade_id, name)
  values ('00000000-0000-4000-b000-000000000004', '00000000-0000-4000-b000-000000000001',
          '00000000-0000-4000-b000-000000000002', '00000000-0000-4000-b000-000000000003', '9-1')
  on conflict do nothing;
insert into public.students (id, school_id, student_code, first_name, father_name, gender)
  select ('00000000-0000-4000-c000-' || lpad(n::text, 12, '0'))::uuid, '00000000-0000-4000-b000-000000000001',
         'RACE-' || n, 'Racer', 'N' || n, 'M'
  from generate_series(1, 51) n
  on conflict do nothing;
insert into public.enrollments (school_id, student_id, academic_year_id, grade_id, section_id)
  select '00000000-0000-4000-b000-000000000001', ('00000000-0000-4000-c000-' || lpad(n::text, 12, '0'))::uuid,
         '00000000-0000-4000-b000-000000000002', '00000000-0000-4000-b000-000000000003',
         '00000000-0000-4000-b000-000000000004'
  from generate_series(1, 49) n;
SQL
echo "before: $(q -Atc "select count(*) from public.enrollments where section_id = '00000000-0000-4000-b000-000000000004'") / 50"

enroll() {
  cat <<SQL
begin;
insert into public.enrollments (school_id, student_id, academic_year_id, grade_id, section_id)
values ('00000000-0000-4000-b000-000000000001', '00000000-0000-4000-c000-$(printf '%012d' "$1")',
        '00000000-0000-4000-b000-000000000002', '00000000-0000-4000-b000-000000000003',
        '00000000-0000-4000-b000-000000000004');
select pg_sleep($2);
commit;
SQL
}

( enroll 50 2 | psql -X -q -d "$DB" > /tmp/race_a.log 2>&1; echo "A exit $?" >> /tmp/race_a.log ) &
sleep 0.5
( enroll 51 0 | psql -X -q -d "$DB" > /tmp/race_b.log 2>&1; echo "B exit $?" >> /tmp/race_b.log ) &
wait

echo "--- session A (seat 50)"; cat /tmp/race_a.log
echo "--- session B (seat 51)"; cat /tmp/race_b.log
COUNT=$(q -Atc "select count(*) from public.enrollments where section_id = '00000000-0000-4000-b000-000000000004'")
echo "after: ${COUNT} / 50"
if [ "$COUNT" -ne 50 ]; then echo "FAIL: section has ${COUNT} students"; exit 1; fi
grep -q 'is full (50 / 50)' /tmp/race_b.log || { echo "FAIL: session B was not refused"; exit 1; }
echo "PASS: the 51st student was refused while the 50th was still being saved"
