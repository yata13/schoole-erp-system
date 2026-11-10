import { useQuery } from '@tanstack/react-query'
import { Link } from 'react-router'
import { Badge, Card, KpiCard, PageHeader, ProgressBar, Skeleton } from '../../../components/ui/Card'
import { ErrorNotice } from '../../../components/ui/Notice'
import { Icon } from '../../../components/ui/icons'
import { num } from '../../../lib/format'
import { supabase } from '../../../lib/supabase'
import { useAuth } from '../../auth/AuthProvider'
import { staffName, useLookups } from '../../school/hooks'

const STAGES = [
  { key: 'kg', label: 'Kindergarten', sub: 'KG1 – KG3', tone: 'from-pink-500 to-rose-500' },
  { key: 'primary', label: 'Primary', sub: 'Grades 1 – 8', tone: 'from-sky-500 to-blue-600' },
  { key: 'secondary', label: 'Secondary', sub: 'Grades 9 – 12', tone: 'from-violet-500 to-indigo-600' },
]

export function ClassesPage() {
  const { schoolId } = useAuth()
  const lookups = useLookups()
  const occ = useQuery({
    queryKey: ['classes', schoolId, lookups.data?.year?.id],
    enabled: !!lookups.data?.year,
    queryFn: async () => {
      const { data, error } = await supabase.from('v_section_occupancy').select('section_id, active_count, capacity')
        .eq('academic_year_id', lookups.data!.year!.id)
      if (error) throw error
      return new Map(data.map((r) => [r.section_id!, r]))
    },
  })

  if (lookups.error) return <ErrorNotice error={lookups.error} />
  if (occ.error) return <ErrorNotice error={occ.error} />
  const L = lookups.data
  const totalSeats = L?.sections.reduce((t, s) => t + s.capacity, 0) ?? 0
  const placed = occ.data ? [...occ.data.values()].reduce((t, r) => t + (r.active_count ?? 0), 0) : 0

  return (
    <div>
      <PageHeader title="Classes" subtitle={L?.year ? `Grades and sections · ${L.year.name}` : ' '} />
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <KpiCard tone="indigo" label="Grades" value={L ? L.grades.length : null} icon={<Icon name="classes" />} sub="KG1 to Grade 12" />
        <KpiCard tone="blue" delay={60} label="Sections" value={L ? L.sections.length : null} icon={<Icon name="students" />} sub="Two per grade" />
        <KpiCard tone="green" delay={120} label="Students placed" value={occ.data ? placed : null} icon={<Icon name="check" />} sub={`of ${num(totalSeats)} seats`} />
        <KpiCard tone="orange" delay={180} label="Free seats" value={occ.data ? totalSeats - placed : null} icon={<Icon name="plus" />} sub="Max 30 per section" />
      </div>

      {!L || !occ.data ? <Skeleton className="mt-5 h-96" /> : STAGES.map((stage, si) => {
        const grades = L.grades.filter((g) => g.stage === stage.key)
        return (
          <Card key={stage.key} className="mt-5" delay={200 + si * 80}
            title={<span className="flex items-center gap-2"><span className={`h-3 w-3 rounded-full bg-gradient-to-br ${stage.tone}`} />{stage.label}</span>}
            subtitle={stage.sub}>
            <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
              {grades.map((g) => (
                <div key={g.id} className="rounded-2xl border border-slate-100 bg-slate-50/60 p-3">
                  <p className="mb-2 flex items-center justify-between text-sm font-bold">
                    {g.name} <span className="font-normal text-slate-400">{g.name_am}</span>
                  </p>
                  <div className="grid grid-cols-2 gap-2">
                    {L.sections.filter((s) => s.grade_id === g.id).map((s) => {
                      const o = occ.data!.get(s.id)
                      const used = o?.active_count ?? 0
                      const p = s.capacity ? (100 * used) / s.capacity : 0
                      return (
                        <Link key={s.id} to={`/students?section=${s.id}`}
                          className="rounded-xl bg-white p-3 shadow-sm ring-1 ring-slate-100 transition hover:-translate-y-0.5 hover:shadow-md">
                          <div className="flex items-baseline justify-between">
                            <span className="text-base font-extrabold">{s.name}</span>
                            {s.stream && <Badge tone={s.stream === 'natural' ? 'green' : 'purple'}>{s.stream}</Badge>}
                          </div>
                          <p className="mt-1 truncate text-xs text-slate-500">{staffName(L.staffById.get(s.homeroom_teacher_id ?? ''))}</p>
                          <p className="mt-2 text-xs font-semibold tabular-nums text-slate-700">{used} / {s.capacity} <span className="font-normal text-slate-400">· {s.room}</span></p>
                          <ProgressBar className="mt-1" value={p} tone={p >= 100 ? 'bg-rose-500' : p >= 90 ? 'bg-amber-500' : 'bg-indigo-500'} />
                        </Link>
                      )
                    })}
                  </div>
                </div>
              ))}
            </div>
          </Card>
        )
      })}
    </div>
  )
}
