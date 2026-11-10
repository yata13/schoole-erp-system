import { Link } from 'react-router'
import { useAuth } from '../../auth/AuthProvider'
import { useMyProfile, useMySchool } from '../../auth/hooks'
import { useCurrentYear, useSectionOccupancy } from '../../setup/hooks'
import { Notice } from '../../../components/ui/Notice'

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border border-slate-200 bg-white p-4">
      <p className="text-sm text-slate-500">{label}</p>
      <p className="mt-1 text-2xl font-bold tabular-nums">{value}</p>
    </div>
  )
}

export function HomePage() {
  const { hasAnyRole } = useAuth()
  const profile = useMyProfile()
  const school = useMySchool()
  const year = useCurrentYear()
  const sections = useSectionOccupancy(year.data?.id)
  const staffView = hasAnyRole('super_admin', 'director', 'registrar', 'finance')

  const placed = sections.data?.reduce((n, s) => n + (s.active_count ?? 0), 0) ?? 0
  const seats = sections.data?.reduce((n, s) => n + (s.capacity ?? 0), 0) ?? 0

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Welcome{profile.data ? `, ${profile.data.full_name}` : ''}</h1>
        <p className="mt-1 text-sm text-slate-500">
          {school.data?.name}
          {year.data ? ` · ${year.data.name}` : ''}
        </p>
      </div>

      {!year.isLoading && !year.data && (
        <Notice tone="warn" title="No current academic year">
          The registrar or super admin needs to set up the current year before students can be enrolled.
        </Notice>
      )}

      {staffView && year.data && (
        <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
          <Stat label="Sections" value={sections.data ? String(sections.data.length) : '…'} />
          <Stat label="Students placed" value={sections.data ? String(placed) : '…'} />
          <Stat label="Free seats" value={sections.data ? String(seats - placed) : '…'} />
          <Stat label="Year" value={year.data.name} />
        </div>
      )}

      <div className="flex flex-wrap gap-3 text-sm font-medium">
        {hasAnyRole('super_admin', 'director', 'registrar', 'teacher', 'finance') && (
          <Link to="/students" className="rounded-lg bg-blue-700 px-4 py-2 text-white hover:bg-blue-800">
            Students
          </Link>
        )}
        <Link to="/setup" className="rounded-lg border border-slate-300 bg-white px-4 py-2 hover:bg-slate-50">
          School setup
        </Link>
      </div>
    </div>
  )
}
