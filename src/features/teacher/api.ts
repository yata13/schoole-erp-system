import { supabase, type Tables } from '../../lib/supabase'

export type AttendanceStatus = Tables<'attendance_records'>['status']

export async function listAssignments(staffId: string | null) {
  let q = supabase.from('teaching_assignments').select('id, staff_id, section_id, subject_id')
  if (staffId) q = q.eq('staff_id', staffId)
  const { data, error } = await q
  if (error) throw error
  return data ?? []
}

export async function getRoadmapProgress(staffId: string | null) {
  let q = supabase.from('v_roadmap_progress').select('teaching_assignment_id, staff_id, section_id, subject_id, weeks, done, in_progress, due, behind')
  if (staffId) q = q.eq('staff_id', staffId)
  const { data, error } = await q
  if (error) throw error
  return data ?? []
}

/** Students of a section with their attendance status on a day (if taken). */
export async function getSectionDay(sectionId: string, day: string) {
  const [students, session] = await Promise.all([
    supabase.from('v_students_current').select('id, enrollment_id, full_name, student_code, gender, roll_no')
      .eq('section_id', sectionId).eq('enrollment_status', 'active').is('deleted_at', null).order('full_name'),
    supabase.from('attendance_sessions').select('id').eq('section_id', sectionId).eq('date', day).maybeSingle(),
  ])
  if (students.error) throw students.error
  if (session.error) throw session.error
  let records: { enrollment_id: string; status: AttendanceStatus }[] = []
  if (session.data) {
    const r = await supabase.from('attendance_records').select('enrollment_id, status').eq('session_id', session.data.id)
    if (r.error) throw r.error
    records = r.data ?? []
  }
  const byEnrollment = new Map(records.map((r) => [r.enrollment_id, r.status]))
  return {
    taken: !!session.data,
    students: (students.data ?? []).map((s) => ({ ...s, status: byEnrollment.get(s.enrollment_id ?? '') ?? null })),
  }
}

export async function saveAttendance(sectionId: string, day: string, records: { enrollment_id: string; status: AttendanceStatus }[]) {
  const { error } = await supabase.rpc('save_attendance', { p_section_id: sectionId, p_date: day, p_records: records })
  if (error) throw error
}

/** Which of these sections already have attendance for a day. */
export async function sectionsTakenOn(sectionIds: string[], day: string) {
  if (!sectionIds.length) return new Set<string>()
  const { data, error } = await supabase.from('attendance_sessions').select('section_id').in('section_id', sectionIds).eq('date', day)
  if (error) throw error
  return new Set((data ?? []).map((s) => s.section_id))
}

/** Students of the assignment's section with their score for one assessment. */
export async function getMarkSheet(sectionId: string, subjectId: string, semesterId: string, assessmentId: string) {
  const students = await supabase.from('v_students_current').select('enrollment_id, full_name, student_code')
    .eq('section_id', sectionId).eq('enrollment_status', 'active').is('deleted_at', null).order('full_name')
  if (students.error) throw students.error
  const ids = (students.data ?? []).map((s) => s.enrollment_id!).filter(Boolean)
  const [marks, totals] = await Promise.all([
    ids.length ? supabase.from('marks').select('enrollment_id, score').eq('subject_id', subjectId).eq('semester_id', semesterId)
      .eq('assessment_type_id', assessmentId).in('enrollment_id', ids) : Promise.resolve({ data: [], error: null }),
    ids.length ? supabase.from('v_subject_results').select('enrollment_id, score, out_of, percent').eq('subject_id', subjectId)
      .eq('semester_id', semesterId).in('enrollment_id', ids) : Promise.resolve({ data: [], error: null }),
  ])
  if (marks.error) throw marks.error
  if (totals.error) throw totals.error
  const score = new Map((marks.data ?? []).map((m) => [m.enrollment_id, Number(m.score)]))
  const total = new Map((totals.data ?? []).map((t) => [t.enrollment_id, t]))
  return (students.data ?? []).map((s) => ({
    enrollment_id: s.enrollment_id!, full_name: s.full_name!, student_code: s.student_code!,
    score: score.get(s.enrollment_id!) ?? null, total: total.get(s.enrollment_id!) ?? null,
  }))
}

export async function saveMarks(schoolId: string, subjectId: string, semesterId: string, assessmentId: string,
  rows: { enrollment_id: string; score: number }[]) {
  if (!rows.length) return
  const { error } = await supabase.from('marks').upsert(
    rows.map((r) => ({ school_id: schoolId, enrollment_id: r.enrollment_id, semester_id: semesterId, subject_id: subjectId,
      assessment_type_id: assessmentId, score: r.score })),
    { onConflict: 'school_id,enrollment_id,semester_id,subject_id,assessment_type_id' },
  )
  if (error) throw error
}

export async function listLessonPlans(assignmentId: string) {
  const { data, error } = await supabase.from('lesson_plans')
    .select('id, week_no, planned_on, topic, objectives, status, done_on, note')
    .eq('teaching_assignment_id', assignmentId).order('week_no')
  if (error) throw error
  return data ?? []
}

export async function setLessonStatus(id: string, status: Tables<'lesson_plans'>['status']) {
  const { error } = await supabase.from('lesson_plans')
    .update({ status, done_on: status === 'done' ? new Date().toISOString().slice(0, 10) : null }).eq('id', id)
  if (error) throw error
}

export async function addLessonPlan(schoolId: string, assignmentId: string, p: { week_no: number; planned_on: string; topic: string; objectives: string }) {
  const { error } = await supabase.from('lesson_plans').insert({
    school_id: schoolId, teaching_assignment_id: assignmentId, week_no: p.week_no, planned_on: p.planned_on || null,
    topic: p.topic.trim(), objectives: p.objectives.trim() || null,
  })
  if (error) throw error
}
