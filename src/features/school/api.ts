import { supabase } from '../../lib/supabase'

// Small lists every page needs. Loaded once, kept for 10 minutes.
export async function getLookups() {
  const [years, semesters, grades, sections, subjects, staff, assessments] = await Promise.all([
    supabase.from('academic_years').select('id, name, ec_year, is_current, start_date, end_date').order('ec_year', { ascending: false }),
    supabase.from('semesters').select('id, academic_year_id, number, is_current, start_date, end_date'),
    supabase.from('grades').select('id, level, name, name_am, stage, has_streams').order('level'),
    supabase.from('sections').select('id, academic_year_id, grade_id, name, stream, capacity, homeroom_teacher_id, room'),
    supabase.from('subjects').select('id, code, name, name_am').order('name'),
    supabase.from('staff').select('id, staff_code, first_name, father_name, position, profile_id').is('deleted_at', null),
    supabase.from('assessment_types').select('id, name, max_score, sort_order').order('sort_order'),
  ])
  for (const r of [years, semesters, grades, sections, subjects, staff, assessments]) if (r.error) throw r.error

  const year = years.data!.find((y) => y.is_current) ?? null
  const semester = semesters.data!.find((s) => s.is_current) ?? null
  const gradeById = new Map(grades.data!.map((g) => [g.id, g]))
  const sectionsThisYear = sections.data!
    .filter((s) => !year || s.academic_year_id === year.id)
    .sort((a, b) => (gradeById.get(a.grade_id)?.level ?? 0) - (gradeById.get(b.grade_id)?.level ?? 0)
      || a.name.localeCompare(b.name, undefined, { numeric: true }))

  return {
    year,
    semester,
    grades: grades.data!,
    gradeById,
    sections: sectionsThisYear,
    sectionById: new Map(sections.data!.map((s) => [s.id, s])),
    subjects: subjects.data!,
    subjectById: new Map(subjects.data!.map((s) => [s.id, s])),
    staff: staff.data!,
    staffById: new Map(staff.data!.map((s) => [s.id, s])),
    assessments: assessments.data!,
  }
}

export type Lookups = Awaited<ReturnType<typeof getLookups>>

/** The signed-in teacher's own staff id and sections (empty for others). */
export async function getMyTeaching() {
  const [staffId, sectionIds, assignmentIds] = await Promise.all([
    supabase.rpc('current_staff_id'),
    supabase.rpc('teacher_section_ids'),
    supabase.rpc('teacher_assignment_ids'),
  ])
  for (const r of [staffId, sectionIds, assignmentIds]) if (r.error) throw r.error
  return {
    staffId: (staffId.data as string | null) ?? null,
    sectionIds: (sectionIds.data as string[] | null) ?? [],
    assignmentIds: (assignmentIds.data as string[] | null) ?? [],
  }
}
