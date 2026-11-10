import { useQuery } from '@tanstack/react-query'
import { Link } from 'react-router'
import { Badge, Card, KpiCard, PageHeader, ProgressBar, Skeleton } from '../../../components/ui/Card'
import { ErrorNotice, Notice } from '../../../components/ui/Notice'
import { Icon } from '../../../components/ui/icons'
import { pct } from '../../../lib/format'
import { supabase } from '../../../lib/supabase'
import { useMyProfile } from '../../auth/hooks'
import { useLookups, useMyTeaching } from '../../school/hooks'
import { getRoadmapProgress, listAssignments, sectionsTakenOn } from '../api'

export const todayISO = () => new Date().toISOString().slice(0, 10)

export function TeacherHome() {
  const profile = useMyProfile()
  const L = useLookups()
  const mine = useMyTeaching()
  const staffId = mine.data?.staffId ?? null
  const sectionIds = mine.data?.sectionIds ?? []
  const today = todayISO()

  const assignments = useQuery({ queryKey: ['assignments', staffId], queryFn: () => listAssignments(staffId), enabled: !!staffId })
  const progress = useQuery({ queryKey: ['roadmap_progress', staffId], queryFn: () => getRoadmapProgress(staffId), enabled: !!staffId })
  const taken = useQuery({ queryKey: ['taken', sectionIds, today], queryFn: () => sectionsTakenOn(sectionIds, today), enabled: sectionIds.length > 0 })
  const counts = useQuery({
    queryKey: ['my_section_counts', sectionIds], enabled: sectionIds.length > 0,
    queryFn: async () => {
      const { data, error } = await supabase.from('v_section_occupancy').select('section_id, active_count').in('section_id', sectionIds)
      if (error) throw error
      return new Map(data.map((r) => [r.section_id!, r.active_count ?? 0]))
    },
  })

  for (const q of [L, mine, assignments, progress]) if (q.error) return <ErrorNotice error={q.error} />
  if (!L.data || !mine.data) return <Skeleton className="h-96" />
  if (!staffId) return <Notice tone="warn" title="No staff record">Your login is not linked to a staff record yet.</Notice>

  const lk = L.data
  const sections = sectionIds.map((id) => lk.sectionById.get(id)).filter(Boolean)
    .sort((a, b) => (lk.gradeById.get(a!.grade_id)?.level ?? 0) - (lk.gradeById.get(b!.grade_id)?.level ?? 0))
  const students = counts.data ? [...counts.data.values()].reduce((t, n) => t + n, 0) : null
  const p = progress.data ?? []
  const done = p.reduce((t, r) => t + (r.done ?? 0), 0)
  const due = p.reduce((t, r) => t + (r.due ?? 0), 0)
  const firstName = profile.data?.full_name?.split(' ')[0] ?? ''

  return (
    <div>
      <PageHeader title={`Selam, ${firstName}`} subtitle={`${new Date().toLocaleDateString('en-GB', { weekday: 'long', day: 'numeric', month: 'long' })} · your classes and roadmap`}
        actions={<>
          <Link to="/attendance" className="rounded-xl bg-indigo-600 px-4 py-2 text-sm font-semibold text-white shadow hover:bg-indigo-700">Take attendance</Link>
          <Link to="/marks" className="rounded-xl bg-white px-4 py-2 text-sm font-semibold text-slate-700 ring-1 ring-slate-200 hover:bg-slate-50">Enter marks</Link>
        </>} />

      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <KpiCard tone="blue" label="My sections" value={sections.length} icon={<Icon name="classes" />} sub="Homeroom and subjects" />
        <KpiCard tone="purple" delay={60} label="My students" value={students} icon={<Icon name="students" />} sub="In those sections" />
        <KpiCard tone="teal" delay={120} label="Classes I teach" value={assignments.data?.length ?? null} icon={<Icon name="book" />} sub="Subject × section" />
        <KpiCard tone={done >= due ? 'green' : 'orange'} delay={180} label="Roadmap" value={due ? (100 * Math.min(done, due)) / due : 100}
          format={(n) => `${n.toFixed(0)}%`} icon={<Icon name="roadmap" />} sub={`${done} of ${due} due weeks done`} />
      </div>

      <Card title="My classes today" subtitle="Tap a class to take attendance" className="mt-5" delay={200}>
        <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
          {sections.map((s) => {
            const subjects = (assignments.data ?? []).filter((a) => a.section_id === s!.id)
              .map((a) => lk.subjectById.get(a.subject_id)?.name).filter(Boolean)
            const isTaken = taken.data?.has(s!.id)
            return (
              <Link key={s!.id} to={`/attendance?section=${s!.id}`}
                className="group rounded-2xl border border-slate-100 bg-gradient-to-br from-white to-slate-50 p-4 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md">
                <div className="flex items-center justify-between">
                  <span className="text-xl font-extrabold">{s!.name}</span>
                  {s!.homeroom_teacher_id === staffId && <Badge tone="purple">Homeroom</Badge>}
                </div>
                <p className="mt-1 line-clamp-2 min-h-[2.5rem] text-xs text-slate-500">{subjects.join(', ') || 'Homeroom only'}</p>
                <div className="mt-3 flex items-center justify-between text-sm">
                  <span className="text-slate-600">{counts.data?.get(s!.id) ?? '…'} students</span>
                  {isTaken
                    ? <span className="flex items-center gap-1 font-semibold text-emerald-600"><Icon name="check" className="h-4 w-4" /> Taken</span>
                    : <span className="font-semibold text-indigo-600 group-hover:underline">Take now →</span>}
                </div>
              </Link>
            )
          })}
        </div>
      </Card>

      <Card title="Teaching roadmap progress" subtitle="Weeks done against weeks planned so far" className="mt-5" delay={260}
        action={<Link to="/roadmap" className="text-xs font-semibold text-indigo-600 hover:underline">Open roadmap</Link>}>
        <ul className="space-y-3">
          {p.map((r) => {
            const sec = lk.sectionById.get(r.section_id!)
            const sub = lk.subjectById.get(r.subject_id!)
            const ratio = r.weeks ? (100 * (r.done ?? 0)) / r.weeks : 0
            return (
              <li key={r.teaching_assignment_id} className="flex items-center gap-3 text-sm">
                <span className="w-40 shrink-0 truncate font-semibold">{sub?.name} <span className="font-normal text-slate-500">· {sec?.name}</span></span>
                <ProgressBar value={ratio} tone={(r.behind ?? 0) > 0 ? 'bg-amber-500' : 'bg-emerald-500'} />
                <span className="w-24 shrink-0 text-right text-xs tabular-nums text-slate-600">{r.done}/{r.weeks} · {pct(ratio)}</span>
                {(r.behind ?? 0) > 0 ? <Badge tone="amber">{r.behind} behind</Badge> : <Badge tone="green">On track</Badge>}
              </li>
            )
          })}
        </ul>
      </Card>
    </div>
  )
}
