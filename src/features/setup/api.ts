import { supabase } from '../../lib/supabase'

export async function listAcademicYears() {
  const { data, error } = await supabase
    .from('academic_years')
    .select('id, ec_year, name, start_date, end_date, is_current, status')
    .order('ec_year', { ascending: false })
  if (error) throw error
  return data
}

export async function listGrades() {
  const { data, error } = await supabase
    .from('grades')
    .select('id, level, name, name_am, has_streams')
    .order('level')
  if (error) throw error
  return data
}

export async function listSectionOccupancy(academicYearId: string) {
  const { data, error } = await supabase
    .from('v_section_occupancy')
    .select('section_id, grade_level, name, stream, capacity, active_count, free_seats')
    .eq('academic_year_id', academicYearId)
    .order('grade_level')
  if (error) throw error
  // "9-2" before "9-10"
  return data.sort(
    (a, b) =>
      (a.grade_level ?? 0) - (b.grade_level ?? 0) ||
      (a.name ?? '').localeCompare(b.name ?? '', undefined, { numeric: true }),
  )
}
