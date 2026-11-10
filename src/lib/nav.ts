import type { AppRole } from './supabase'

export const OFFICE: AppRole[] = ['super_admin', 'director', 'registrar', 'finance']
export const STAFF: AppRole[] = [...OFFICE, 'teacher']
export const FAMILY: AppRole[] = ['student', 'parent']

export type NavItem = { to: string; label: string; icon: string; roles?: AppRole[]; note?: string }

export const NAV: NavItem[] = [
  { to: '/', label: 'Dashboard', icon: 'home' },
  { to: '/students', label: 'Students', icon: 'students', roles: STAFF },
  { to: '/staff', label: 'Staff', icon: 'staff', roles: OFFICE },
  { to: '/classes', label: 'Classes', icon: 'classes', roles: STAFF },
  { to: '/attendance', label: 'Attendance', icon: 'attendance', roles: ['super_admin', 'director', 'registrar', 'teacher'] },
  { to: '/marks', label: 'Marks', icon: 'marks', roles: ['super_admin', 'director', 'registrar', 'teacher'] },
  { to: '/roadmap', label: 'Teaching roadmap', icon: 'roadmap', roles: ['super_admin', 'director', 'teacher'] },
  { to: '/finance', label: 'Finance', icon: 'finance', roles: OFFICE },
  { to: '/fines', label: 'Fines', icon: 'fines', roles: STAFF, note: 'ቅጣት' },
]

export const ROLE_LABEL: Record<AppRole, string> = {
  super_admin: 'Super admin', director: 'Director', registrar: 'Registrar', teacher: 'Teacher',
  finance: 'Finance', student: 'Student', parent: 'Parent',
}
