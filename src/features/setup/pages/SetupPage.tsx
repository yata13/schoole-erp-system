import { Spinner } from '../../../components/ui/Spinner'
import { ErrorNotice, Notice } from '../../../components/ui/Notice'
import { useAcademicYears, useCurrentYear, useGrades, useSectionOccupancy } from '../hooks'

function SeatBar({ used, capacity }: { used: number; capacity: number }) {
  const pct = capacity ? Math.min(100, Math.round((used / capacity) * 100)) : 0
  const color = pct >= 100 ? 'bg-red-600' : pct >= 90 ? 'bg-amber-500' : 'bg-blue-600'
  return (
    <div className="h-1.5 w-full rounded-full bg-slate-100" aria-hidden="true">
      <div className={`h-1.5 rounded-full ${color}`} style={{ width: `${pct}%` }} />
    </div>
  )
}

export function SetupPage() {
  const years = useAcademicYears()
  const current = useCurrentYear()
  const grades = useGrades()
  const sections = useSectionOccupancy(current.data?.id)

  if (years.isLoading || grades.isLoading) return <Spinner full />
  if (years.error) return <ErrorNotice error={years.error} />
  if (grades.error) return <ErrorNotice error={grades.error} />

  return (
    <div className="space-y-8">
      <div>
        <h1 className="text-2xl font-bold">School setup</h1>
        <p className="mt-1 text-sm text-slate-500">Years, grades and sections. Editing comes next.</p>
      </div>

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-slate-500">Academic years</h2>
        {years.data?.length ? (
          <ul className="divide-y divide-slate-200 rounded-xl border border-slate-200 bg-white">
            {years.data.map((y) => (
              <li key={y.id} className="flex items-center justify-between px-4 py-3 text-sm">
                <span className="font-medium">{y.name}</span>
                <span className="text-slate-500">
                  {y.start_date} → {y.end_date}
                  {y.is_current && (
                    <span className="ml-2 rounded-full bg-blue-50 px-2 py-0.5 text-xs font-semibold text-blue-800">
                      Current
                    </span>
                  )}
                </span>
              </li>
            ))}
          </ul>
        ) : (
          <Notice>No academic years yet.</Notice>
        )}
      </section>

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wide text-slate-500">
          Sections {current.data ? `· ${current.data.name}` : ''}
        </h2>
        {!current.data ? (
          <Notice>Set a current academic year to see its sections.</Notice>
        ) : sections.isLoading ? (
          <Spinner />
        ) : sections.error ? (
          <ErrorNotice error={sections.error} />
        ) : (
          <div className="space-y-6">
            {grades.data?.map((g) => {
              const rows = sections.data?.filter((s) => s.grade_level === g.level) ?? []
              return (
                <div key={g.id}>
                  <h3 className="mb-2 font-semibold">{g.name}</h3>
                  {rows.length === 0 ? (
                    <p className="text-sm text-slate-500">No sections.</p>
                  ) : (
                    <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
                      {rows.map((s) => (
                        <div key={s.section_id} className="rounded-xl border border-slate-200 bg-white p-3">
                          <div className="flex items-baseline justify-between">
                            <span className="font-semibold">{s.name}</span>
                            {s.stream && <span className="text-xs capitalize text-slate-500">{s.stream}</span>}
                          </div>
                          <p className="mb-2 mt-1 text-sm tabular-nums text-slate-600">
                            {s.active_count} / {s.capacity}
                          </p>
                          <SeatBar used={s.active_count ?? 0} capacity={s.capacity ?? 0} />
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              )
            })}
          </div>
        )}
      </section>
    </div>
  )
}
