import { supabase } from '../../lib/supabase'
import { toE164 } from '../../lib/phone'

export const PAGE_SIZE = 25

export type StudentFilters = { page: number; search: string; gradeLevel: number | null; sectionId: string | null }

// PostgREST filter strings use , ( ) as syntax and % as wildcard.
function cleanSearch(q: string) {
  return q.replace(/[,()%*\\]/g, ' ').trim()
}

export async function listStudents({ page, search, gradeLevel, sectionId }: StudentFilters) {
  let query = supabase
    .from('v_students_current')
    .select('id, student_code, full_name, gender, grade_level, section_id, section_name, stream, status, enrollment_id', { count: 'exact' })
    .is('deleted_at', null)
    .order('grade_level', { ascending: true, nullsFirst: false })
    .order('section_name')
    .order('full_name')
    .range(page * PAGE_SIZE, page * PAGE_SIZE + PAGE_SIZE - 1)

  const q = cleanSearch(search)
  if (q) query = query.or(`full_name.ilike.%${q}%,student_code.ilike.%${q}%`)
  if (gradeLevel != null) query = query.eq('grade_level', gradeLevel)
  if (sectionId) query = query.eq('section_id', sectionId)

  const { data, error, count } = await query
  if (error) throw error
  return { rows: data, total: count ?? 0 }
}

export async function getStudentProfile(studentId: string, semesterId: string | null) {
  const [student, current, links, fines] = await Promise.all([
    supabase.from('students').select('*').eq('id', studentId).single(),
    supabase.from('v_students_current').select('enrollment_id, grade_level, grade_id, section_id, section_name, stream, enrollment_status').eq('id', studentId).maybeSingle(),
    supabase.from('student_guardians').select('guardian_id, relationship, is_primary').eq('student_id', studentId),
    supabase.from('fines').select('id, kind, reason, amount, status, issued_on').eq('student_id', studentId).order('issued_on', { ascending: false }),
  ])
  if (student.error) throw student.error
  for (const r of [current, links, fines]) if (r.error) throw r.error

  const guardianIds = (links.data ?? []).map((l) => l.guardian_id)
  const enrollmentId = current.data?.enrollment_id ?? null

  const [guardians, attendance, results, invoices, misses] = await Promise.all([
    guardianIds.length
      ? supabase.from('guardians').select('id, full_name, phone, occupation').in('id', guardianIds)
      : Promise.resolve({ data: [], error: null }),
    enrollmentId
      ? supabase.from('v_attendance_summary').select('days, present, absent, late, excused, rate').eq('enrollment_id', enrollmentId).maybeSingle()
      : Promise.resolve({ data: null, error: null }),
    enrollmentId && semesterId
      ? supabase.from('v_subject_results').select('subject_id, score, out_of, percent').eq('enrollment_id', enrollmentId).eq('semester_id', semesterId)
      : Promise.resolve({ data: [], error: null }),
    enrollmentId
      ? supabase.from('invoices').select('id, invoice_no, period, period_start, due_date, total, discount, paid, status').eq('enrollment_id', enrollmentId).order('period_start')
      : Promise.resolve({ data: [], error: null }),
    enrollmentId
      ? supabase.from('attendance_records').select('status, session_id').eq('enrollment_id', enrollmentId).neq('status', 'present')
      : Promise.resolve({ data: [], error: null }),
  ])
  for (const r of [guardians, attendance, results, invoices, misses]) if (r.error) throw r.error

  // Dates of the days missed or late.
  const sessionIds = (misses.data ?? []).map((m) => m.session_id)
  const sessions = sessionIds.length
    ? await supabase.from('attendance_sessions').select('id, date').in('id', sessionIds)
    : { data: [] as { id: string; date: string }[], error: null }
  if (sessions.error) throw sessions.error
  const dateBySession = new Map((sessions.data ?? []).map((s) => [s.id, s.date]))

  return {
    student: student.data,
    current: current.data,
    guardians: (guardians.data ?? []).map((g) => ({ ...g, ...(links.data ?? []).find((l) => l.guardian_id === g.id) })),
    attendance: attendance.data,
    results: results.data ?? [],
    invoices: invoices.data ?? [],
    fines: fines.data ?? [],
    missedDays: (misses.data ?? [])
      .map((m) => ({ status: m.status, date: dateBySession.get(m.session_id) ?? '' }))
      .sort((a, b) => b.date.localeCompare(a.date)),
  }
}

export type NewStudent = {
  first_name: string; father_name: string; grandfather_name: string; gender: 'M' | 'F'; birth_date: string
  grade_id: string; section_id: string; year_id: string
  guardian_name: string; guardian_phone: string; relationship: 'father' | 'mother' | 'guardian' | 'other'
}

/** Student + enrollment + guardian (found by phone or created) + link. */
export async function addStudent(schoolId: string, s: NewStudent) {
  const phone = s.guardian_phone ? toE164(s.guardian_phone) : null
  if (s.guardian_phone && !phone) throw new Error('Guardian phone must be an Ethiopian number, e.g. 0911 22 33 44')

  const student = await supabase.from('students').insert({
    school_id: schoolId, student_code: '', first_name: s.first_name.trim(), father_name: s.father_name.trim(),
    grandfather_name: s.grandfather_name.trim() || null, gender: s.gender, birth_date: s.birth_date || null,
  }).select('id, student_code').single()
  if (student.error) throw student.error

  const enr = await supabase.from('enrollments').insert({
    school_id: schoolId, student_id: student.data.id, academic_year_id: s.year_id, grade_id: s.grade_id,
    section_id: s.section_id || null,
  })
  if (enr.error) throw enr.error

  if (phone) {
    const found = await supabase.from('guardians').select('id').eq('phone', phone).maybeSingle()
    if (found.error) throw found.error
    let guardianId = found.data?.id
    if (!guardianId) {
      const g = await supabase.from('guardians').insert({ school_id: schoolId, full_name: s.guardian_name.trim() || 'Guardian', phone })
        .select('id').single()
      if (g.error) throw g.error
      guardianId = g.data.id
    }
    const link = await supabase.from('student_guardians').insert({
      school_id: schoolId, student_id: student.data.id, guardian_id: guardianId, relationship: s.relationship, is_primary: true,
    })
    if (link.error) throw link.error
  }
  return student.data
}
