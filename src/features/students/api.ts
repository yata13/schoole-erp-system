import { supabase } from '../../lib/supabase'

export const PAGE_SIZE = 25

export type StudentFilters = {
  page: number
  search: string
  gradeLevel: number | null
}

// PostgREST filter strings use , ( ) as syntax and % as wildcard.
function cleanSearch(q: string) {
  return q.replace(/[,()%*\\]/g, ' ').trim()
}

export async function listStudents({ page, search, gradeLevel }: StudentFilters) {
  let query = supabase
    .from('v_students_current')
    .select('id, student_code, full_name, gender, grade_level, section_name, stream, status', { count: 'exact' })
    .is('deleted_at', null)
    .order('full_name')
    .range(page * PAGE_SIZE, page * PAGE_SIZE + PAGE_SIZE - 1)

  const q = cleanSearch(search)
  if (q) query = query.or(`full_name.ilike.%${q}%,student_code.ilike.%${q}%`)
  if (gradeLevel) query = query.eq('grade_level', gradeLevel)

  const { data, error, count } = await query
  if (error) throw error
  return { rows: data, total: count ?? 0 }
}
