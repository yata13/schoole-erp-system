import { useEffect, useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useSearchParams } from 'react-router'
import { Avatar, Badge, Card, Empty, PageHeader, Skeleton } from '../../../components/ui/Card'
import { Button, Field, Input, Select } from '../../../components/ui/Field'
import { ErrorNotice, Notice } from '../../../components/ui/Notice'
import { Icon } from '../../../components/ui/icons'
import { useAuth } from '../../auth/AuthProvider'
import { useLookups, useMyTeaching } from '../../school/hooks'
import { getSectionDay, saveAttendance, type AttendanceStatus } from '../api'

const OPTIONS: { value: AttendanceStatus; label: string; short: string; on: string }[] = [
  { value: 'present', label: 'Present', short: 'P', on: 'bg-emerald-500 text-white' },
  { value: 'late', label: 'Late', short: 'L', on: 'bg-amber-500 text-white' },
  { value: 'absent', label: 'Absent', short: 'A', on: 'bg-rose-500 text-white' },
  { value: 'excused', label: 'Excused', short: 'E', on: 'bg-slate-500 text-white' },
]

export function AttendancePage() {
  const { hasAnyRole } = useAuth()
  const L = useLookups()
  const mine = useMyTeaching()
  const qc = useQueryClient()
  const [params, setParams] = useSearchParams()
  const isTeacher = hasAnyRole('teacher') && !hasAnyRole('super_admin', 'registrar', 'director')
  const canEdit = hasAnyRole('super_admin', 'registrar', 'teacher')

  const sections = useMemo(() => {
    if (!L.data) return []
    return isTeacher ? L.data.sections.filter((s) => mine.data?.sectionIds.includes(s.id)) : L.data.sections
  }, [L.data, mine.data, isTeacher])

  const sectionId = params.get('section') ?? sections[0]?.id ?? ''
  const day = params.get('date') ?? new Date().toISOString().slice(0, 10)
  const setParam = (k: string, v: string) => { const p = new URLSearchParams(params); p.set(k, v); setParams(p, { replace: true }) }

  const sheet = useQuery({ queryKey: ['attendance_day', sectionId, day], queryFn: () => getSectionDay(sectionId, day), enabled: !!sectionId })
  const [marks, setMarks] = useState<Record<string, AttendanceStatus>>({})
  useEffect(() => {
    if (!sheet.data) return
    setMarks(Object.fromEntries(sheet.data.students.map((s) => [s.enrollment_id!, s.status ?? 'present'])))
  }, [sheet.data])

  const save = useMutation({
    mutationFn: () => saveAttendance(sectionId, day, Object.entries(marks).map(([enrollment_id, status]) => ({ enrollment_id, status }))),
    onSuccess: () => { for (const k of ['attendance_day', 'taken', 'dashboard', 'student_profile']) qc.invalidateQueries({ queryKey: [k] }) },
  })

  const counts = OPTIONS.map((o) => ({ ...o, n: Object.values(marks).filter((v) => v === o.value).length }))
  const weekend = [0, 6].includes(new Date(day + 'T00:00:00').getDay())
  const section = L.data?.sectionById.get(sectionId)

  if (L.error) return <ErrorNotice error={L.error} />

  return (
    <div>
      <PageHeader title="Attendance" subtitle="Mark the whole class in one go, then save" />
      <Card delay={40}>
        <div className="grid gap-4 sm:grid-cols-3">
          <Field label="Class">
            <Select value={sectionId} onChange={(e) => setParam('section', e.target.value)}>
              {sections.map((s) => <option key={s.id} value={s.id}>{s.name}{s.stream ? ` (${s.stream})` : ''}</option>)}
            </Select>
          </Field>
          <Field label="Date"><Input type="date" value={day} max={new Date().toISOString().slice(0, 10)} onChange={(e) => setParam('date', e.target.value)} /></Field>
          <div className="flex flex-wrap items-end gap-2">
            {counts.map((c) => (
              <span key={c.value} className={`rounded-xl px-3 py-2 text-sm font-bold ${c.on}`}>{c.label} {c.n}</span>
            ))}
          </div>
        </div>
      </Card>

      {weekend && <div className="mt-4"><Notice tone="warn">That day is a weekend.</Notice></div>}

      <Card className="mt-5" bodyClass="p-0" delay={100}
        title={section ? `${section.name} · ${new Date(day + 'T00:00:00').toLocaleDateString('en-GB', { weekday: 'long', day: 'numeric', month: 'short' })}` : undefined}
        action={sheet.data && <Badge tone={sheet.data.taken ? 'green' : 'amber'}>{sheet.data.taken ? 'Saved before — you can update it' : 'Not taken yet'}</Badge>}>
        {!sectionId ? <Empty>No class to show.</Empty> : sheet.error ? <div className="p-4"><ErrorNotice error={sheet.error} /></div> : !sheet.data ? <Skeleton className="m-4 h-72" /> : sheet.data.students.length === 0 ? <Empty>No students in this class.</Empty> : (
          <>
            {canEdit && (
              <div className="flex flex-wrap gap-2 border-b border-slate-100 px-4 py-3">
                <Button variant="ghost" className="!py-1.5 text-xs" onClick={() => setMarks(Object.fromEntries(Object.keys(marks).map((k) => [k, 'present'])))}>
                  <Icon name="check" className="h-4 w-4" /> Everyone present
                </Button>
              </div>
            )}
            <ul className="divide-y divide-slate-100">
              {sheet.data.students.map((s, i) => (
                <li key={s.enrollment_id} className="flex flex-wrap items-center gap-3 px-4 py-2.5">
                  <span className="w-6 text-right text-xs text-slate-400 tabular-nums">{i + 1}</span>
                  <Avatar name={s.full_name ?? ''} tone={s.gender === 'F' ? 'bg-rose-100 text-rose-700' : 'bg-blue-100 text-blue-700'} />
                  <div className="min-w-0 flex-1"><p className="truncate font-semibold">{s.full_name}</p><p className="text-xs text-slate-500">{s.student_code}</p></div>
                  <div className="flex gap-1" role="radiogroup" aria-label={`Attendance for ${s.full_name}`}>
                    {OPTIONS.map((o) => {
                      const active = marks[s.enrollment_id!] === o.value
                      return (
                        <button key={o.value} type="button" role="radio" aria-checked={active} title={o.label} disabled={!canEdit}
                          onClick={() => setMarks((m) => ({ ...m, [s.enrollment_id!]: o.value }))}
                          className={`h-9 w-9 rounded-lg text-sm font-bold transition ${active ? `${o.on} scale-105 shadow` : 'bg-slate-100 text-slate-500 hover:bg-slate-200'}`}>
                          {o.short}
                        </button>
                      )
                    })}
                  </div>
                </li>
              ))}
            </ul>
            {canEdit && (
              <div className="sticky bottom-0 flex items-center justify-between gap-3 border-t border-slate-100 bg-white/95 px-4 py-3 backdrop-blur">
                <span className="text-sm text-slate-500">
                  {save.isSuccess ? <span className="font-semibold text-emerald-600">Saved ✓</span> : save.error ? <span className="text-rose-600">{(save.error as Error).message}</span> : `${Object.keys(marks).length} students`}
                </span>
                <Button onClick={() => save.mutate()} disabled={save.isPending}>{save.isPending ? 'Saving…' : 'Save attendance'}</Button>
              </div>
            )}
          </>
        )}
      </Card>
    </div>
  )
}
