import { useEffect, useMemo, useState } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Avatar, Badge, Card, Empty, PageHeader, Skeleton } from '../../../components/ui/Card'
import { Button, Field, Select } from '../../../components/ui/Field'
import { ErrorNotice, Notice } from '../../../components/ui/Notice'
import { pct } from '../../../lib/format'
import { useAuth } from '../../auth/AuthProvider'
import { useLookups, useMyTeaching } from '../../school/hooks'
import { getMarkSheet, listAssignments, saveMarks } from '../api'

export function MarksPage() {
  const { schoolId, hasAnyRole } = useAuth()
  const L = useLookups()
  const mine = useMyTeaching()
  const qc = useQueryClient()
  const isTeacher = hasAnyRole('teacher')
  const canEdit = hasAnyRole('teacher', 'super_admin')
  const staffId = isTeacher ? mine.data?.staffId ?? null : null

  const assignments = useQuery({
    queryKey: ['assignments', staffId ?? 'all'],
    queryFn: () => listAssignments(staffId),
    enabled: !!L.data && (!isTeacher || !!mine.data),
  })
  const options = useMemo(() => {
    const lk = L.data
    if (!lk || !assignments.data) return []
    return assignments.data
      .map((a) => ({ ...a, section: lk.sectionById.get(a.section_id), subject: lk.subjectById.get(a.subject_id) }))
      .filter((a) => a.section && a.subject)
      .sort((x, y) => (lk.gradeById.get(x.section!.grade_id)?.level ?? 0) - (lk.gradeById.get(y.section!.grade_id)?.level ?? 0)
        || x.section!.name.localeCompare(y.section!.name, undefined, { numeric: true }) || x.subject!.name.localeCompare(y.subject!.name))
  }, [L.data, assignments.data])

  const [assignmentId, setAssignmentId] = useState('')
  const [assessmentId, setAssessmentId] = useState('')
  useEffect(() => { if (!assignmentId && options[0]) setAssignmentId(options[0].id) }, [options, assignmentId])
  useEffect(() => { if (!assessmentId && L.data?.assessments[0]) setAssessmentId(L.data.assessments[0].id) }, [L.data, assessmentId])

  const current = options.find((o) => o.id === assignmentId)
  const assessment = L.data?.assessments.find((a) => a.id === assessmentId)
  const semesterId = L.data?.semester?.id ?? ''
  const sheet = useQuery({
    queryKey: ['marks_sheet', assignmentId, assessmentId, semesterId],
    queryFn: () => getMarkSheet(current!.section_id, current!.subject_id, semesterId, assessmentId),
    enabled: !!current && !!assessmentId && !!semesterId,
  })

  const [scores, setScores] = useState<Record<string, string>>({})
  useEffect(() => {
    if (sheet.data) setScores(Object.fromEntries(sheet.data.map((r) => [r.enrollment_id, r.score == null ? '' : String(r.score)])))
  }, [sheet.data])

  const max = Number(assessment?.max_score ?? 100)
  const entered = Object.values(scores).filter((v) => v !== '').map(Number)
  const avg = entered.length ? entered.reduce((t, n) => t + n, 0) / entered.length : null
  const invalid = Object.values(scores).some((v) => v !== '' && (Number.isNaN(Number(v)) || Number(v) < 0 || Number(v) > max))

  const save = useMutation({
    mutationFn: () => saveMarks(schoolId!, current!.subject_id, semesterId, assessmentId,
      Object.entries(scores).filter(([, v]) => v !== '').map(([enrollment_id, v]) => ({ enrollment_id, score: Number(v) }))),
    onSuccess: () => { for (const k of ['marks_sheet', 'dashboard', 'student_profile']) qc.invalidateQueries({ queryKey: [k] }) },
  })

  if (L.error) return <ErrorNotice error={L.error} />
  if (assignments.error) return <ErrorNotice error={assignments.error} />

  return (
    <div>
      <PageHeader title="Marks" subtitle={`Semester ${L.data?.semester?.number ?? ''} · enter scores for each assessment`} />
      <Card delay={40}>
        <div className="grid gap-4 sm:grid-cols-3">
          <Field label="Class and subject">
            <Select value={assignmentId} onChange={(e) => setAssignmentId(e.target.value)}>
              {options.map((o) => <option key={o.id} value={o.id}>{o.section!.name} · {o.subject!.name}</option>)}
            </Select>
          </Field>
          <Field label="Assessment">
            <Select value={assessmentId} onChange={(e) => setAssessmentId(e.target.value)}>
              {L.data?.assessments.map((a) => <option key={a.id} value={a.id}>{a.name} (out of {Number(a.max_score)})</option>)}
            </Select>
          </Field>
          <div className="flex items-end gap-2">
            <div className="rounded-xl bg-indigo-50 px-4 py-2 text-sm"><span className="text-slate-500">Class average</span> <span className="ml-1 font-extrabold text-indigo-700">{avg == null ? '—' : `${avg.toFixed(1)} / ${max}`}</span></div>
            <div className="rounded-xl bg-slate-100 px-4 py-2 text-sm"><span className="text-slate-500">Entered</span> <span className="ml-1 font-bold">{entered.length}/{sheet.data?.length ?? 0}</span></div>
          </div>
        </div>
      </Card>

      <Card className="mt-5" bodyClass="p-0" delay={100}
        title={current ? `${current.section!.name} · ${current.subject!.name} · ${assessment?.name ?? ''}` : undefined}>
        {!current ? <Empty>No classes assigned to you yet.</Empty> : !sheet.data ? <Skeleton className="m-4 h-72" /> : sheet.data.length === 0 ? <Empty>No students.</Empty> : (
          <>
            <div className="overflow-x-auto">
              <table className="w-full min-w-[560px] text-left text-sm">
                <thead className="bg-slate-50/70 text-xs uppercase tracking-wide text-slate-500">
                  <tr><th className="px-4 py-3">#</th><th className="px-4 py-3">Student</th><th className="px-4 py-3">Score / {max}</th><th className="px-4 py-3">Subject so far</th></tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {sheet.data.map((r, i) => {
                    const v = scores[r.enrollment_id] ?? ''
                    const bad = v !== '' && (Number.isNaN(Number(v)) || Number(v) < 0 || Number(v) > max)
                    return (
                      <tr key={r.enrollment_id}>
                        <td className="px-4 py-2 text-xs text-slate-400 tabular-nums">{i + 1}</td>
                        <td className="px-4 py-2"><div className="flex items-center gap-3"><Avatar name={r.full_name} /><div><p className="font-semibold">{r.full_name}</p><p className="text-xs text-slate-500">{r.student_code}</p></div></div></td>
                        <td className="px-4 py-2">
                          <input inputMode="decimal" value={v} disabled={!canEdit} aria-label={`Score for ${r.full_name}`}
                            onChange={(e) => setScores((s) => ({ ...s, [r.enrollment_id]: e.target.value.replace(',', '.') }))}
                            className={`w-24 rounded-lg border px-3 py-1.5 text-right font-semibold tabular-nums focus:outline-none focus:ring-2 ${bad ? 'border-rose-400 bg-rose-50 focus:ring-rose-300' : 'border-slate-300 focus:ring-indigo-300'}`} />
                        </td>
                        <td className="px-4 py-2">
                          {r.total ? <Badge tone={Number(r.total.percent) >= 80 ? 'green' : Number(r.total.percent) >= 50 ? 'blue' : 'red'}>{Number(r.total.score)} / {Number(r.total.out_of)} · {pct(r.total.percent)}</Badge> : <span className="text-slate-400">—</span>}
                        </td>
                      </tr>
                    )
                  })}
                </tbody>
              </table>
            </div>
            {canEdit && (
              <div className="sticky bottom-0 flex items-center justify-between gap-3 border-t border-slate-100 bg-white/95 px-4 py-3 backdrop-blur">
                <span className="text-sm">
                  {invalid ? <span className="text-rose-600">Scores must be between 0 and {max}.</span>
                    : save.isSuccess ? <span className="font-semibold text-emerald-600">Saved ✓</span>
                    : save.error ? <span className="text-rose-600">{(save.error as Error).message}</span> : <span className="text-slate-500">Blank = not entered</span>}
                </span>
                <Button onClick={() => save.mutate()} disabled={invalid || save.isPending}>{save.isPending ? 'Saving…' : 'Save marks'}</Button>
              </div>
            )}
          </>
        )}
      </Card>
      {!isTeacher && !hasAnyRole('super_admin') && <div className="mt-4"><Notice>Only the subject's teacher (or the super admin) can change marks.</Notice></div>}
    </div>
  )
}
