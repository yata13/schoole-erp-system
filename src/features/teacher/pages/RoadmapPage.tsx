import { useEffect, useMemo, useState, type FormEvent } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Badge, Card, Empty, KpiCard, PageHeader, ProgressBar, Skeleton } from '../../../components/ui/Card'
import { Button, Field, Input } from '../../../components/ui/Field'
import { Modal } from '../../../components/ui/Modal'
import { ErrorNotice, Notice } from '../../../components/ui/Notice'
import { Icon } from '../../../components/ui/icons'
import { date, pct } from '../../../lib/format'
import type { Tables } from '../../../lib/supabase'
import { useAuth } from '../../auth/AuthProvider'
import { staffName, useLookups, useMyTeaching } from '../../school/hooks'
import { addLessonPlan, getRoadmapProgress, listLessonPlans, setLessonStatus } from '../api'

type LessonStatus = Tables<'lesson_plans'>['status']
const STATUS: Record<LessonStatus, { label: string; tone: 'green' | 'blue' | 'slate' | 'amber'; dot: string }> = {
  done: { label: 'Done', tone: 'green', dot: 'bg-emerald-500' },
  in_progress: { label: 'In progress', tone: 'blue', dot: 'bg-indigo-500' },
  planned: { label: 'Planned', tone: 'slate', dot: 'bg-slate-300' },
  skipped: { label: 'Skipped', tone: 'amber', dot: 'bg-amber-400' },
}

export function RoadmapPage() {
  const { schoolId, hasAnyRole } = useAuth()
  const isTeacher = hasAnyRole('teacher')
  const canEdit = hasAnyRole('teacher', 'super_admin')
  const L = useLookups()
  const mine = useMyTeaching()
  const qc = useQueryClient()
  const staffId = isTeacher ? mine.data?.staffId ?? null : null
  const progress = useQuery({
    queryKey: ['roadmap_progress', staffId ?? 'all'],
    queryFn: () => getRoadmapProgress(staffId),
    enabled: !isTeacher || !!mine.data,
  })
  const [selected, setSelected] = useState<string | null>(null)
  const [onlyBehind, setOnlyBehind] = useState(false)
  const [adding, setAdding] = useState(false)

  const rows = useMemo(() => {
    const lk = L.data
    if (!lk || !progress.data) return []
    return progress.data
      .map((r) => ({ ...r, section: lk.sectionById.get(r.section_id!), subject: lk.subjectById.get(r.subject_id!), teacher: lk.staffById.get(r.staff_id!) }))
      .sort((a, b) => (b.behind ?? 0) - (a.behind ?? 0) || (a.section?.name ?? '').localeCompare(b.section?.name ?? '', undefined, { numeric: true }))
  }, [L.data, progress.data])
  useEffect(() => { if (isTeacher && !selected && rows[0]) setSelected(rows[0].teaching_assignment_id) }, [rows, selected, isTeacher])

  const plans = useQuery({ queryKey: ['lesson_plans', selected], queryFn: () => listLessonPlans(selected!), enabled: !!selected })
  const setStatus = useMutation({
    mutationFn: ({ id, status }: { id: string; status: LessonStatus }) => setLessonStatus(id, status),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['lesson_plans'] }); qc.invalidateQueries({ queryKey: ['roadmap_progress'] }) },
  })

  const totals = rows.reduce((t, r) => ({ weeks: t.weeks + (r.weeks ?? 0), done: t.done + (r.done ?? 0), due: t.due + (r.due ?? 0), behind: t.behind + ((r.behind ?? 0) > 0 ? 1 : 0) }),
    { weeks: 0, done: 0, due: 0, behind: 0 })
  const sel = rows.find((r) => r.teaching_assignment_id === selected)
  const shown = onlyBehind ? rows.filter((r) => (r.behind ?? 0) > 0) : rows

  if (progress.error) return <ErrorNotice error={progress.error} />

  return (
    <div>
      <PageHeader title="Teaching roadmap" subtitle={isTeacher ? 'Your plan for each class, week by week' : 'Every class and subject: who is on track and who is behind'} />

      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <KpiCard tone="indigo" label={isTeacher ? 'My classes' : 'Classes'} value={progress.data ? rows.length : null} icon={<Icon name="book" />} sub="Subject × section" />
        <KpiCard tone="green" delay={60} label="Weeks done" value={progress.data ? totals.done : null} icon={<Icon name="check" />} sub={`of ${totals.weeks} planned`} />
        <KpiCard tone="teal" delay={120} label="On schedule" value={progress.data ? (totals.due ? (100 * Math.min(totals.done, totals.due)) / totals.due : 100) : null}
          format={(n) => `${n.toFixed(0)}%`} icon={<Icon name="trend" />} sub="Done vs due by today" />
        <KpiCard tone="orange" delay={180} label="Behind" value={progress.data ? totals.behind : null} icon={<Icon name="clock" />} sub="Classes behind plan" />
      </div>

      <div className="mt-5 grid gap-5 xl:grid-cols-[minmax(0,1fr)_minmax(0,1.2fr)]">
        <Card title={isTeacher ? 'My classes' : 'Progress by class'} delay={160} bodyClass="p-0 pt-3"
          action={!isTeacher && (
            <label className="flex items-center gap-2 text-xs font-semibold text-slate-600">
              <input type="checkbox" checked={onlyBehind} onChange={(e) => setOnlyBehind(e.target.checked)} /> Only behind
            </label>
          )}>
          {!progress.data || !L.data ? <Skeleton className="m-4 h-72" /> : shown.length === 0 ? <Empty>Nothing to show.</Empty> : (
            <ul className="scroll-thin max-h-[560px] divide-y divide-slate-100 overflow-y-auto">
              {shown.map((r) => {
                const ratio = r.weeks ? (100 * (r.done ?? 0)) / r.weeks : 0
                return (
                  <li key={r.teaching_assignment_id}>
                    <button onClick={() => setSelected(r.teaching_assignment_id)}
                      className={`w-full px-4 py-3 text-left transition ${selected === r.teaching_assignment_id ? 'bg-indigo-50' : 'hover:bg-slate-50'}`}>
                      <div className="flex items-center justify-between gap-2">
                        <p className="truncate text-sm font-semibold">{r.subject?.name} <span className="font-normal text-slate-500">· {r.section?.name}</span></p>
                        {(r.behind ?? 0) > 0 ? <Badge tone="amber">{r.behind} behind</Badge> : <Badge tone="green">On track</Badge>}
                      </div>
                      {!isTeacher && <p className="text-xs text-slate-500">{staffName(r.teacher)}</p>}
                      <div className="mt-2 flex items-center gap-2">
                        <ProgressBar value={ratio} tone={(r.behind ?? 0) > 0 ? 'bg-amber-500' : 'bg-emerald-500'} />
                        <span className="w-20 shrink-0 text-right text-xs tabular-nums text-slate-500">{r.done}/{r.weeks} · {pct(ratio)}</span>
                      </div>
                    </button>
                  </li>
                )
              })}
            </ul>
          )}
        </Card>

        <Card delay={220} title={sel ? `${sel.subject?.name} · ${sel.section?.name}` : 'Weeks'}
          subtitle={sel && !isTeacher ? staffName(sel.teacher) : undefined}
          action={sel && canEdit && <Button className="!py-1.5 text-xs" onClick={() => setAdding(true)}><Icon name="plus" className="h-4 w-4" /> Add week</Button>}>
          {!selected ? <Empty>Pick a class to see its weeks.</Empty> : !plans.data ? <Skeleton className="h-72" /> : plans.data.length === 0 ? <Empty>No weeks planned yet.</Empty> : (
            <ol className="relative ml-3 border-l-2 border-slate-100">
              {plans.data.map((p) => (
                <li key={p.id} className="relative mb-4 pl-6">
                  <span className={`absolute -left-[9px] top-1.5 h-4 w-4 rounded-full ring-4 ring-white ${STATUS[p.status].dot}`} />
                  <div className="flex flex-wrap items-start justify-between gap-2">
                    <div className="min-w-0">
                      <p className="text-xs font-semibold uppercase tracking-wide text-slate-400">Week {p.week_no} · {date(p.planned_on)}</p>
                      <p className="font-semibold">{p.topic}</p>
                      {p.objectives && <p className="text-sm text-slate-500">{p.objectives}</p>}
                      {p.done_on && <p className="text-xs text-emerald-600">Done on {date(p.done_on)}</p>}
                    </div>
                    {canEdit ? (
                      <div className="flex gap-1">
                        {(['done', 'in_progress', 'planned'] as LessonStatus[]).map((s) => (
                          <button key={s} disabled={setStatus.isPending} onClick={() => setStatus.mutate({ id: p.id, status: s })}
                            className={`rounded-lg px-2 py-1 text-xs font-semibold transition ${p.status === s ? 'bg-slate-900 text-white' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}`}>
                            {STATUS[s].label}
                          </button>
                        ))}
                      </div>
                    ) : <Badge tone={STATUS[p.status].tone}>{STATUS[p.status].label}</Badge>}
                  </div>
                </li>
              ))}
            </ol>
          )}
        </Card>
      </div>

      {selected && canEdit && (
        <AddWeekModal open={adding} onClose={() => setAdding(false)} assignmentId={selected} schoolId={schoolId!}
          nextWeek={(plans.data?.reduce((m, p) => Math.max(m, p.week_no), 0) ?? 0) + 1} />
      )}
      {!isTeacher && !hasAnyRole('super_admin') && <div className="mt-4"><Notice>Teachers update their own roadmaps; you can follow progress here.</Notice></div>}
    </div>
  )
}

function AddWeekModal({ open, onClose, assignmentId, schoolId, nextWeek }: { open: boolean; onClose: () => void; assignmentId: string; schoolId: string; nextWeek: number }) {
  const qc = useQueryClient()
  const [f, setF] = useState({ topic: '', objectives: '', planned_on: '' })
  const save = useMutation({
    mutationFn: () => addLessonPlan(schoolId, assignmentId, { week_no: nextWeek, ...f }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['lesson_plans'] }); qc.invalidateQueries({ queryKey: ['roadmap_progress'] }); setF({ topic: '', objectives: '', planned_on: '' }); onClose() },
  })
  return (
    <Modal open={open} onClose={onClose} title={`Add week ${nextWeek}`}>
      <form onSubmit={(e: FormEvent) => { e.preventDefault(); save.mutate() }} className="space-y-4">
        <Field label="Topic"><Input value={f.topic} onChange={(e) => setF({ ...f, topic: e.target.value })} placeholder="e.g. Unit 9: Probability" required /></Field>
        <Field label="Objectives"><Input value={f.objectives} onChange={(e) => setF({ ...f, objectives: e.target.value })} placeholder="What students will be able to do" /></Field>
        <Field label="Planned week starting"><Input type="date" value={f.planned_on} onChange={(e) => setF({ ...f, planned_on: e.target.value })} /></Field>
        {save.error && <Notice tone="error">{(save.error as Error).message}</Notice>}
        <div className="flex justify-end gap-2">
          <Button type="button" variant="ghost" onClick={onClose}>Cancel</Button>
          <Button type="submit" disabled={save.isPending}>{save.isPending ? 'Saving…' : 'Add week'}</Button>
        </div>
      </form>
    </Modal>
  )
}
