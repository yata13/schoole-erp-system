# Phase 1 tables (updated)

Board 4 with the five review fixes applied. The SQL is in `supabase/migrations/0001`–`0008`, and the pgTAP tests in `supabase/tests/` check every rule below.

## The five fixes

| # | Fix | Where it lives | Checked by |
|---|-----|----------------|------------|
| 1 | Every UNIQUE rule includes `school_id` | every table below | `01_schema_rules` scans every unique index |
| 2 | Views are `WITH (security_invoker = true)` | `v_section_occupancy`, `v_students_current` (0005) | `01_schema_rules` scans every view, `02_rls_access` queries them per role |
| 3 | Index on `school_id` and every FK; composite filter indexes; helpers called as `(select fn())` | every table; policies in 0007, 0008 | `01_schema_rules`: every FK indexed, every table has a `school_id`-first index, no unwrapped helper in any policy |
| 4 | Capacity trigger locks the section row (`SELECT … FOR UPDATE`) before counting | `private.check_enrollment()` (0005) | `03_enrollment_rules` (51st refused) and `scripts/db/section-race-check.sh` (two sessions at once) |
| 5 | Grades 11–12: `enrollments.stream` = `sections.stream` | `private.check_enrollment()` (0005) | `03_enrollment_rules` |

The race check was also run without the lock: the section ended at 51 / 50. With the lock it stays at 50 / 50.

## Also changed while applying the fixes

- **Composite foreign keys.** Every link between school tables is `(school_id, x_id) → x (school_id, id)`. A row can never point at another school's row, even with a leaked UUID. RLS alone can't promise that, because foreign-key checks skip RLS. Each linked table gets `UNIQUE (school_id, id)` as the target. The composite FK indexes also serve as the `school_id` and FK indexes from fix 3.
- `grades.has_streams` is generated from `level >= 11`, so it can't disagree with the level.
- `sections.capacity` defaults to `schools.max_section_size` and may not exceed it.
- Section moves are written to `section_changes` by a trigger, so no move goes unlogged.
- Fields added: `promotion_runs.undecided` (students with no year result yet) and `enrollments.promotion_run_id` (makes undo possible).
- Phones use a `phone_et` type (`+251` and 9 digits). `login_id`, `student_code`, `staff_code` and `subjects.code` are stored upper case, so there is one spelling only.
- `audit_log.changed_by` has no FK: an audit row must never be blocked, and platform admins have no profile.
- The current year in the seed is **2019 E.C.** (11 Sep 2026 – 7 Jul 2027), so the first ID is `AHS-19-0001`.

---

Every table also has `id uuid PK`, `school_id → schools`, `created_at`, `updated_at`, `created_by → profiles`. The soft-delete tables (students, guardians, staff) also have `deleted_at` and `deleted_by → profiles`.
`created_by` and `deleted_by` each have their own index (they are FKs too). They are left out of the index lists below.

## Access & system

### schools — the tenant (no `school_id`)
`code`, `name`, `name_am`, `phone`, `address`, `logo_path`, `pass_mark` (50), `max_section_size` (50), `default_locale` (en | am), `is_active`
- UNIQUE `(code)`: the one global unique rule. It is the school code typed at login.

### profiles — one login per person (`id` = `auth.users.id`)
`login_id`, `full_name`, `full_name_am`, `phone`, `locale`, `date_display` (ec | gc), `is_active`, `last_login_at`
- UNIQUE `(school_id, login_id)`, UNIQUE `(school_id, id)`
- A user cannot change their own `login_id` or `is_active`.

### user_roles
`user_id`, `role` (super_admin | director | registrar | teacher | finance | student | parent)
- PK `(school_id, user_id, role)`; FK `(school_id, user_id) → profiles`

### platform_admins
`user_id` PK → `auth.users`. Not inside any school.

### number_sequences
`name` (student | invoice | receipt), `year` (E.C.), `last_value`
- PK `(school_id, name, year)`. Bumped with one upsert, so two saves at the same moment never get the same number.

### audit_log — insert only
`id bigint`, `table_name`, `record_id`, `action` (insert | update | delete | soft_delete | restore), `old_data`, `new_data` (only the changed columns on update), `changed_by`, `changed_at`
- INDEX `(school_id, changed_at desc)`, INDEX `(school_id, table_name, record_id)`
- UPDATE, DELETE and TRUNCATE are refused by trigger, even for the service key.

## School setup

### academic_years
`ec_year`, `name`, `start_date`, `end_date` (Gregorian), `is_current`, `status` (planning | active | closed)
- UNIQUE `(school_id, ec_year)`, UNIQUE `(school_id, id)`
- UNIQUE `(school_id) WHERE is_current`: only 1 current year per school

### semesters
`academic_year_id`, `number` (1 | 2), `start_date`, `end_date`, `is_current`, `status` (open | closed)
- UNIQUE `(school_id, academic_year_id, number)`, UNIQUE `(school_id, id)`
- UNIQUE `(school_id) WHERE is_current`: only 1 current semester per school

### grades
`level` (9–12), `name`, `name_am`, `has_streams` (generated: level ≥ 11)
- UNIQUE `(school_id, level)`, UNIQUE `(school_id, id)`

### sections
`academic_year_id`, `grade_id`, `name` ("9-1"), `stream` (natural | social | null), `homeroom_teacher_id → staff`, `capacity`, `room`
- UNIQUE `(school_id, academic_year_id, name)`, UNIQUE `(school_id, id)`
- INDEX `(school_id, grade_id)`, INDEX `(school_id, homeroom_teacher_id)`
- Grades 11–12 must have a stream; grades 9–10 must not.

### subjects
`code` ("MATH"), `name`, `name_am`, `is_active`
- UNIQUE `(school_id, code)`, UNIQUE `(school_id, id)`

### grade_subjects
`grade_id`, `subject_id`, `stream` (null = all streams), `periods_per_week`, `counts_in_average`, `sort_order`
- UNIQUE NULLS NOT DISTINCT `(school_id, grade_id, subject_id, stream)`
- INDEX `(school_id, subject_id)`

## People

### students — kept for life
`student_code` (auto: AHS-19-0001), `profile_id`, `first_name`, `father_name`, `grandfather_name`, the same three in Amharic, `gender` (M | F), `birth_date`, `photo_path`, `phone`, `sub_city`, `woreda`, `kebele`, `previous_school`, `admission_date`, `status` (active | transferred_out | graduated | dropped), soft delete
- UNIQUE `(school_id, student_code)`, UNIQUE `(school_id, profile_id)`, UNIQUE `(school_id, id)`

### guardians
`profile_id`, `full_name`, `full_name_am`, `phone`, `alt_phone`, `occupation`, soft delete
- UNIQUE `(school_id, phone)`, UNIQUE `(school_id, profile_id)`, UNIQUE `(school_id, id)`

### student_guardians
`student_id`, `guardian_id`, `relationship` (father | mother | guardian | other), `is_primary`
- PK `(school_id, student_id, guardian_id)`, INDEX `(school_id, guardian_id)`
- UNIQUE `(school_id, student_id) WHERE is_primary`: one main contact per student

### staff
`profile_id`, `staff_code`, `first_name`, `father_name`, `grandfather_name`, `gender`, `phone`, `position`, `hire_date`, `photo_path`, `status` (active | left), soft delete
- UNIQUE `(school_id, staff_code)`, UNIQUE `(school_id, profile_id)`, UNIQUE `(school_id, id)`

## Enrollment & registrar

### enrollments — the heart of the system
`student_id`, `academic_year_id`, `grade_id`, `section_id` (null = not placed), `stream`, `roll_no`, `status` (active | transferred_out | dropped | completed), `year_result` (promoted | repeat | graduated), `enrolled_on`, `left_on`, `promotion_run_id`
- UNIQUE `(school_id, student_id, academic_year_id)`
- UNIQUE `(school_id, section_id, roll_no)`: deferrable, checked at the end of each statement, so a whole section can be renumbered in one UPDATE
- UNIQUE `(school_id, id)`
- INDEX `(school_id, academic_year_id, section_id)`: the common "this year, this section" filter
- INDEX `(school_id, grade_id)`, INDEX `(school_id, promotion_run_id)`
- Trigger rules:
  1. The section must be in the same year and grade.
  2. Grades 11–12: `stream` must equal the section's stream. If the stream is empty when the student is placed, it is copied from the section. Grades 9–10: no stream.
  3. The section row is locked with `SELECT … FOR UPDATE`, then the active students are counted. The 51st is refused with "Section 9-1 is full (50 / 50)".

### section_changes (filled by trigger)
`enrollment_id`, `from_section_id`, `to_section_id` (null = taken out), `reason`, `changed_at`
- INDEX `(school_id, enrollment_id)`, `(school_id, from_section_id)`, `(school_id, to_section_id)`

### student_transfers
`student_id`, `direction` (in | out), `other_school`, `transfer_date`, `reason`, `document_path`
- INDEX `(school_id, student_id)`
- Out: the student and the active enrollment become `transferred_out` in the same transaction.

### promotion_runs
`from_year_id`, `to_year_id`, `promoted`, `repeated`, `graduated`, `undecided`, `status` (preview | done | undone)
- UNIQUE `(school_id, id)`, UNIQUE `(school_id, from_year_id) WHERE status = 'done'` (a year is promoted once)
- INDEX `(school_id, from_year_id)`, `(school_id, to_year_id)`

### import_jobs
`file_path`, `status` (checking | ready | done | failed), `total_rows`, `ok_rows`, `error_rows`, `errors` (`[{row, message}]`)
- INDEX `(school_id, created_at desc)`

## Views (all `WITH (security_invoker = true)`)
- `v_section_occupancy`: seats per section ("48 / 50"): `active_count`, `free_seats`.
- `v_students_current`: student list with this year's grade, section, stream and roll no, for paged search.

## Database functions
| Function | Who | What |
|---|---|---|
| `current_school_id()`, `has_role()`, `has_any_role()` | RLS | read `school_id` / `user_roles` from the login token |
| `current_staff_id()`, `current_student_id()`, `current_guardian_id()`, `guardian_student_ids()`, `teacher_section_ids()`, `teacher_student_ids()` | RLS | "my" rows; check the role in the token and the link in the data |
| `custom_access_token_hook(event)` | Supabase Auth | puts `school_id` + `user_roles` in the token; an inactive login or school gets none |
| `set_current_academic_year(id)`, `set_current_semester(id)` | super admin, registrar | switch the current year or semester in one step |
| `move_student_section(enrollment, section, reason)` | super admin, registrar | move or take out; logged |
| `promote_students(from, to, apply)` | super admin, registrar | preview, then run |
| `undo_promotion(run)` | super admin, registrar | only while no promoted student is placed |
| `import_students(job, rows, dry_run)` | super admin, registrar | ≤ 200 rows per call; the dry run runs every check, then undoes it |
| `soft_delete(table, id)`, `restore(table, id)` | as RLS allows | students, guardians, staff |
| `private.next_number(school, kind)` | triggers only | AHS-19-0001, INV-2019-000001, RCP-2019-000001 |

## RLS (board 2), as built
One policy per table per action. Every one starts with `school_id = (select current_school_id())`.

| Data | Super admin | Director | Registrar | Teacher | Finance | Student | Parent |
|---|---|---|---|---|---|---|---|
| School setup | Edit | Read | Edit | Read | Read | Read | Read |
| Logins & roles | Edit | Read | Student + parent logins | Self | Self | Self | Self |
| Students & guardians | Edit | Read | Edit | Own classes | Read | Self | Own children |
| Enrollment | Edit | Read | Edit | Own classes | Read | Self | Own children |
| Staff list | Edit | Read | Read | Read | Read | — | — |
| Moves, transfers, promotion, imports | Edit | Read | Edit | — | — | — | — |
| Audit log | Read | Read | — | — | — | — | — |

Phase 1 "own classes" = homeroom sections. Phase 2 adds `teaching_assignments` to `teacher_section_ids()`, and every policy picks it up.

## Phase 2–4 keys (planned now so the fixes carry forward)
| Table | Unique rule | Extra index |
|---|---|---|
| attendance_sessions | `(school_id, section_id, date)` | also serves the `(section_id, date)` filter |
| attendance_records | `(school_id, session_id, enrollment_id)` | `(school_id, enrollment_id)` |
| teaching_assignments | `(school_id, section_id, subject_id)` | `(school_id, staff_id)` |
| marks | `(school_id, enrollment_id, semester_id, subject_id, assessment_type_id)` | `(school_id, semester_id, subject_id)` |
| invoices | `(school_id, invoice_no)` | `(school_id, enrollment_id)` |
| payments | `(school_id, receipt_no)` | `(school_id, invoice_id)` |
| book_copies | `(school_id, accession_no)` | `(school_id, book_id)` |
| timetable_entries | `(school_id, section_id, day, period_id)`, `(school_id, staff_id, day, period_id)` | |

The structural tests in `01_schema_rules` run against every future migration too, so a Phase 2 table that breaks fixes 1–3 fails the tests.
