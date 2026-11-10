import { supabase, type Tables } from '../../lib/supabase'
import { toE164 } from '../../lib/phone'

export async function listStaff() {
  const [staff, salaries, assignments] = await Promise.all([
    supabase.from('staff')
      .select('id, staff_code, first_name, father_name, gender, phone, position, hire_date, status, employment_type, qualification')
      .is('deleted_at', null).order('staff_code'),
    supabase.from('staff_salaries').select('staff_id, monthly_salary'),   // RLS: only finance, director, super admin (and self)
    supabase.from('teaching_assignments').select('staff_id'),
  ])
  for (const r of [staff, salaries, assignments]) if (r.error) throw r.error
  const salary = new Map((salaries.data ?? []).map((s) => [s.staff_id, Number(s.monthly_salary)]))
  const classes = new Map<string, number>()
  for (const a of assignments.data ?? []) classes.set(a.staff_id, (classes.get(a.staff_id) ?? 0) + 1)
  return {
    rows: (staff.data ?? []).map((s) => ({ ...s, salary: salary.get(s.id) ?? null, classes: classes.get(s.id) ?? 0 })),
    canSeeSalaries: (salaries.data ?? []).length > 1,
  }
}

export type NewStaff = {
  staff_code: string; first_name: string; father_name: string; gender: 'M' | 'F'
  position: Tables<'staff'>['position']; phone: string; employment_type: Tables<'staff'>['employment_type']
  qualification: string; salary: string
}

export async function addStaff(schoolId: string, s: NewStaff) {
  const phone = s.phone ? toE164(s.phone) : null
  if (s.phone && !phone) throw new Error('Phone must be an Ethiopian number, e.g. 0911 22 33 44')
  const row = await supabase.from('staff').insert({
    school_id: schoolId, staff_code: s.staff_code.trim().toUpperCase(), first_name: s.first_name.trim(),
    father_name: s.father_name.trim(), gender: s.gender, position: s.position, phone,
    employment_type: s.employment_type, qualification: s.qualification.trim() || null, hire_date: new Date().toISOString().slice(0, 10),
  }).select('id').single()
  if (row.error) throw row.error
  if (s.salary) {
    const sal = await supabase.from('staff_salaries').insert({ school_id: schoolId, staff_id: row.data.id, monthly_salary: Number(s.salary) })
    if (sal.error) throw sal.error
  }
  return row.data
}
