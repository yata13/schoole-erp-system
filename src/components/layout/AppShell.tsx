import { NavLink, Outlet } from 'react-router'
import type { AppRole } from '../../lib/supabase'
import { useAuth } from '../../features/auth/AuthProvider'
import { useMyProfile, useMySchool, useSignOut } from '../../features/auth/hooks'

type NavItem = { to: string; label: string; icon: string; roles?: AppRole[] }

export const NAV: NavItem[] = [
  { to: '/', label: 'Home', icon: 'M3 11l9-7 9 7v9a1 1 0 01-1 1h-5v-6H9v6H4a1 1 0 01-1-1z' },
  {
    to: '/students',
    label: 'Students',
    icon: 'M16 11a4 4 0 10-8 0 4 4 0 008 0zM4 21a8 8 0 0116 0',
    roles: ['super_admin', 'director', 'registrar', 'teacher', 'finance'],
  },
  { to: '/setup', label: 'School setup', icon: 'M4 6h16M4 12h16M4 18h10' },
]

const ROLE_LABEL: Record<AppRole, string> = {
  super_admin: 'Super admin',
  director: 'Director',
  registrar: 'Registrar',
  teacher: 'Teacher',
  finance: 'Finance',
  student: 'Student',
  parent: 'Parent',
}

function Icon({ d }: { d: string }) {
  return (
    <svg viewBox="0 0 24 24" className="h-5 w-5" fill="none" stroke="currentColor" strokeWidth="1.8"
      strokeLinecap="round" strokeLinejoin="round" aria-hidden="true">
      <path d={d} />
    </svg>
  )
}

export function AppShell() {
  const { roles, hasAnyRole } = useAuth()
  const school = useMySchool()
  const profile = useMyProfile()
  const signOut = useSignOut()
  const items = NAV.filter((i) => !i.roles || hasAnyRole(...i.roles))

  const link = ({ isActive }: { isActive: boolean }) =>
    `flex items-center gap-3 rounded-lg px-3 py-2 text-sm font-medium ${
      isActive ? 'bg-blue-50 text-blue-800' : 'text-slate-600 hover:bg-slate-100'
    }`

  return (
    <div className="flex min-h-full">
      {/* Sidebar (tablet and up) */}
      <aside className="hidden w-60 shrink-0 flex-col border-r border-slate-200 bg-white md:flex">
        <div className="border-b border-slate-200 px-4 py-4">
          <p className="text-xs font-semibold uppercase tracking-wide text-slate-500">{school.data?.code ?? '…'}</p>
          <p className="mt-0.5 font-semibold leading-snug">{school.data?.name ?? ' '}</p>
        </div>
        <nav className="flex-1 space-y-1 p-3">
          {items.map((i) => (
            <NavLink key={i.to} to={i.to} end={i.to === '/'} className={link}>
              <Icon d={i.icon} />
              {i.label}
            </NavLink>
          ))}
        </nav>
        <div className="border-t border-slate-200 p-4 text-sm">
          <p className="font-medium">{profile.data?.full_name ?? ' '}</p>
          <p className="text-slate-500">{roles.map((r) => ROLE_LABEL[r]).join(', ')}</p>
          <button className="mt-2 font-medium text-blue-700 hover:underline" onClick={() => signOut.mutate()}>
            Sign out
          </button>
        </div>
      </aside>

      <div className="flex min-w-0 flex-1 flex-col">
        {/* Top bar (phone) */}
        <header className="flex items-center justify-between border-b border-slate-200 bg-white px-4 py-3 md:hidden">
          <p className="truncate font-semibold">{school.data?.name ?? 'School ERP'}</p>
          <button className="text-sm font-medium text-blue-700" onClick={() => signOut.mutate()}>
            Sign out
          </button>
        </header>

        <main className="flex-1 px-4 pb-24 pt-5 md:px-8 md:pb-8 md:pt-8">
          <Outlet />
        </main>

        {/* Bottom nav (phone) */}
        <nav className="fixed inset-x-0 bottom-0 flex border-t border-slate-200 bg-white md:hidden">
          {items.map((i) => (
            <NavLink
              key={i.to}
              to={i.to}
              end={i.to === '/'}
              className={({ isActive }) =>
                `flex flex-1 flex-col items-center gap-0.5 py-2 text-xs ${isActive ? 'text-blue-700' : 'text-slate-500'}`
              }
            >
              <Icon d={i.icon} />
              {i.label}
            </NavLink>
          ))}
        </nav>
      </div>
    </div>
  )
}
