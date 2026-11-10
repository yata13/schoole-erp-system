import { useEffect, useState } from 'react'
import { NavLink, Outlet, useLocation } from 'react-router'
import { useAuth } from '../../features/auth/AuthProvider'
import { useMyProfile, useMySchool, useSignOut } from '../../features/auth/hooks'
import { NAV, ROLE_LABEL } from '../../lib/nav'
import { Icon } from '../ui/icons'

function Sidebar({ onNavigate }: { onNavigate?: () => void }) {
  const { roles, hasAnyRole } = useAuth()
  const school = useMySchool()
  const profile = useMyProfile()
  const signOut = useSignOut()
  const items = NAV.filter((i) => !i.roles || hasAnyRole(...i.roles))

  return (
    <div className="flex h-full flex-col bg-gradient-to-b from-[#0b1220] via-[#111a35] to-[#1b1550] text-slate-300">
      <div className="flex items-center gap-3 px-5 pb-5 pt-6">
        <div className="grid h-10 w-10 place-items-center rounded-xl bg-gradient-to-br from-indigo-500 to-blue-500 text-white shadow-lg shadow-indigo-900/40">
          <Icon name="cap" className="h-6 w-6" />
        </div>
        <div className="min-w-0">
          <p className="line-clamp-2 text-[15px] font-extrabold leading-tight tracking-tight text-white">{school.data?.name ?? 'School ERP'}</p>
          <p className="text-[11px] font-semibold uppercase tracking-widest text-indigo-300">{school.data?.code ?? ''} · ERP</p>
        </div>
      </div>

      <nav className="scroll-thin flex-1 space-y-1 overflow-y-auto px-3">
        {items.map((i) => (
          <NavLink
            key={i.to}
            to={i.to}
            end={i.to === '/'}
            onClick={onNavigate}
            className={({ isActive }) =>
              `group flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-semibold transition ${
                isActive
                  ? 'bg-gradient-to-r from-blue-500 to-indigo-500 text-white shadow-lg shadow-indigo-900/40'
                  : 'text-slate-300 hover:bg-white/5 hover:text-white'
              }`
            }
          >
            <Icon name={i.icon} className="h-5 w-5 shrink-0" />
            <span className="flex-1">{i.label}</span>
            {i.note && <span className="text-xs font-normal opacity-70">{i.note}</span>}
          </NavLink>
        ))}
      </nav>

      <div className="m-3 rounded-2xl border border-white/10 bg-white/5 p-4">
        <p className="truncate text-sm font-semibold text-white">{profile.data?.full_name ?? ' '}</p>
        <p className="truncate text-xs text-indigo-200">{roles.map((r) => ROLE_LABEL[r]).join(', ')}</p>
        <button
          onClick={() => signOut.mutate()}
          className="mt-3 flex items-center gap-2 text-xs font-semibold text-slate-300 hover:text-white"
        >
          <Icon name="logout" className="h-4 w-4" /> Sign out
        </button>
      </div>
    </div>
  )
}

export function AppShell() {
  const [open, setOpen] = useState(false)
  const location = useLocation()
  const school = useMySchool()
  useEffect(() => setOpen(false), [location.pathname])

  return (
    <div className="flex min-h-full">
      <aside className="hidden w-64 shrink-0 bg-[#0b1220] lg:block">
        <div className="sticky top-0 h-screen"><Sidebar /></div>
      </aside>

      {/* Phone / tablet drawer */}
      {open && (
        <div className="fixed inset-0 z-40 lg:hidden">
          <div className="absolute inset-0 bg-slate-900/60 backdrop-blur-sm" onClick={() => setOpen(false)} />
          <aside className="rise absolute inset-y-0 left-0 w-72 shadow-2xl">
            <Sidebar onNavigate={() => setOpen(false)} />
          </aside>
        </div>
      )}

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="sticky top-0 z-30 flex items-center gap-3 border-b border-slate-200 bg-white/90 px-4 py-3 backdrop-blur lg:hidden">
          <button onClick={() => setOpen(true)} className="rounded-lg p-1.5 text-slate-700 hover:bg-slate-100" aria-label="Open menu">
            <Icon name="menu" className="h-6 w-6" />
          </button>
          <p className="truncate font-bold">{school.data?.name ?? 'School ERP'}</p>
        </header>
        <main className="mx-auto w-full max-w-[1400px] flex-1 px-4 py-6 md:px-8 md:py-8">
          <Outlet />
        </main>
      </div>
    </div>
  )
}
