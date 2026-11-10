import { useEffect, useMemo, useState, type FormEvent } from 'react'
import { useNavigate, useSearchParams } from 'react-router'
import { Avatar, Badge, Card, Empty, PageHeader, Skeleton } from '../../../components/ui/Card'
import { Button, Field, Input, Select } from '../../../components/ui/Field'
import { Modal } from '../../../components/ui/Modal'
import { ErrorNotice, Notice } from '../../../components/ui/Notice'
import { Icon } from '../../../components/ui/icons'
import { useDebounce } from '../../../hooks/useDebounce'
import { num } from '../../../lib/format'
import { useAuth } from '../../auth/AuthProvider'
import { useLookups } from '../../school/hooks'
import { PAGE_SIZE, type NewStudent } from '../api'
import { useAddStudent, useStudents } from '../hooks'

const STATUS: Record<string, { label: string; tone: 'green' | 'amber' | 'blue' | 'red' }> = {
  active: { label: 'Active', tone: 'green' },
  transferred_out: { label: 'Transferred', tone: 'amber' },
  graduated: { label: 'Graduated', tone: 'blue' },
  dropped: { label: 'Dropped', tone: 'red' },
}

export function StudentListPage() {
  const navigate = useNavigate()
  const { hasAnyRole } = useAuth()
  const lookups = useLookups()
  const [search, setSearch] = useState('')
  const [gradeLevel, setGradeLevel] = useState<number | null>(null)
  const [params] = useSearchParams()
  const [sectionId, setSectionId] = useState<string | null>(params.get('section'))
  const [page, setPage] = useState(0)
  const [adding, setAdding] = useState(false)
  const debounced = useDebounce(search)
  const students = useStudents({ page, search: debounced, gradeLevel, sectionId })

  // Opened from a class card (/students?section=...): show that grade too.
  useEffect(() => {
    const id = params.get('section')
    const sec = id ? lookups.data?.sectionById.get(id) : undefined
    if (sec) setGradeLevel(lookups.data!.gradeById.get(sec.grade_id)?.level ?? null)
  }, [params, lookups.data])

  const total = students.data?.total ?? 0
  const pages = Math.max(1, Math.ceil(total / PAGE_SIZE))
  const sectionsForGrade = useMemo(() => {
    const L = lookups.data
    if (!L || gradeLevel == null) return []
    return L.sections.filter((s) => L.gradeById.get(s.grade_id)?.level === gradeLevel)
  }, [lookups.data, gradeLevel])
  const gradeName = (level: number | null) =>
    lookups.data?.grades.find((g) => g.level === level)?.name ?? (level == null ? '—' : `Grade ${level}`)

  return (
    <div>
      <PageHeader
        title="Students"
        subtitle={students.data ? `${num(total)} students${gradeLevel != null ? ` in ${gradeName(gradeLevel)}` : ''}` : ' '}
        actions={hasAnyRole('super_admin', 'registrar') && (
          <Button onClick={() => setAdding(true)}><Icon name="plus" className="h-4 w-4" /> Add student</Button>
        )}
      />

      <Card bodyClass="p-0" delay={60}>
        <div className="flex flex-col gap-3 border-b border-slate-100 p-4 sm:flex-row">
          <div className="relative sm:max-w-xs sm:flex-1">
            <Icon name="search" className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
            <Input type="search" placeholder="Search name or student ID" value={search} className="pl-9"
              onChange={(e) => { setSearch(e.target.value); setPage(0) }} aria-label="Search students" />
          </div>
          <Select value={gradeLevel ?? ''} className="sm:max-w-[11rem]" aria-label="Grade"
            onChange={(e) => { setGradeLevel(e.target.value === '' ? null : Number(e.target.value)); setSectionId(null); setPage(0) }}>
            <option value="">All grades</option>
            {lookups.data?.grades.map((g) => <option key={g.id} value={g.level}>{g.name}</option>)}
          </Select>
          <Select value={sectionId ?? ''} className="sm:max-w-[10rem]" aria-label="Section" disabled={gradeLevel == null}
            onChange={(e) => { setSectionId(e.target.value || null); setPage(0) }}>
            <option value="">All sections</option>
            {sectionsForGrade.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}
          </Select>
        </div>

        {students.isLoading ? (
          <div className="space-y-2 p-4">{Array.from({ length: 8 }).map((_, i) => <Skeleton key={i} className="h-12" />)}</div>
        ) : students.error ? (
          <div className="p-4"><ErrorNotice error={students.error} /></div>
        ) : !students.data?.rows.length ? (
          <Empty>{debounced || gradeLevel != null ? 'No students match.' : 'No students yet.'}</Empty>
        ) : (
          <>
            <div className="hidden md:block">
              <table className="w-full text-left text-sm">
                <thead className="bg-slate-50/70 text-xs uppercase tracking-wide text-slate-500">
                  <tr>
                    <th className="px-4 py-3 font-semibold">Student</th>
                    <th className="px-4 py-3 font-semibold">ID</th>
                    <th className="px-4 py-3 font-semibold">Grade</th>
                    <th className="px-4 py-3 font-semibold">Section</th>
                    <th className="px-4 py-3 font-semibold">Sex</th>
                    <th className="px-4 py-3 font-semibold">Status</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {students.data.rows.map((s) => (
                    <tr key={s.id} onClick={() => navigate(`/students/${s.id}`)} className="cursor-pointer transition hover:bg-indigo-50/40">
                      <td className="px-4 py-2.5">
                        <div className="flex items-center gap-3">
                          <Avatar name={s.full_name ?? ''} tone={s.gender === 'F' ? 'bg-rose-100 text-rose-700' : 'bg-blue-100 text-blue-700'} />
                          <span className="font-semibold">{s.full_name}</span>
                        </div>
                      </td>
                      <td className="px-4 py-2.5 font-mono text-xs text-slate-500">{s.student_code}</td>
                      <td className="px-4 py-2.5">{gradeName(s.grade_level)}</td>
                      <td className="px-4 py-2.5">
                        {s.section_name ?? <span className="text-slate-400">Not placed</span>}
                        {s.stream && <span className="ml-1 text-xs capitalize text-slate-500">({s.stream})</span>}
                      </td>
                      <td className="px-4 py-2.5">{s.gender}</td>
                      <td className="px-4 py-2.5">
                        <Badge tone={STATUS[s.status ?? '']?.tone ?? 'blue'}>{STATUS[s.status ?? '']?.label ?? s.status}</Badge>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <ul className="divide-y divide-slate-100 md:hidden">
              {students.data.rows.map((s) => (
                <li key={s.id}>
                  <button onClick={() => navigate(`/students/${s.id}`)} className="flex w-full items-center gap-3 px-4 py-3 text-left">
                    <Avatar name={s.full_name ?? ''} tone={s.gender === 'F' ? 'bg-rose-100 text-rose-700' : 'bg-blue-100 text-blue-700'} />
                    <div className="min-w-0 flex-1">
                      <p className="truncate font-semibold">{s.full_name}</p>
                      <p className="text-xs text-slate-500">{s.student_code} · {gradeName(s.grade_level)} · {s.section_name ?? 'Not placed'}</p>
                    </div>
                    <Icon name="chevron" className="h-4 w-4 text-slate-400" />
                  </button>
                </li>
              ))}
            </ul>
            <div className="flex items-center justify-between border-t border-slate-100 px-4 py-3 text-sm">
              <span className="text-slate-500">Page {page + 1} of {pages}</span>
              <div className="flex gap-2">
                <Button variant="ghost" disabled={page === 0} onClick={() => setPage((p) => p - 1)}>Previous</Button>
                <Button variant="ghost" disabled={page + 1 >= pages} onClick={() => setPage((p) => p + 1)}>Next</Button>
              </div>
            </div>
          </>
        )}
      </Card>

      <AddStudentModal open={adding} onClose={() => setAdding(false)} />
    </div>
  )
}

function AddStudentModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  const lookups = useLookups()
  const add = useAddStudent()
  const navigate = useNavigate()
  const empty: NewStudent = {
    first_name: '', father_name: '', grandfather_name: '', gender: 'F', birth_date: '', grade_id: '', section_id: '',
    year_id: '', guardian_name: '', guardian_phone: '', relationship: 'father',
  }
  const [f, setF] = useState<NewStudent>(empty)
  const set = <K extends keyof NewStudent>(k: K, v: NewStudent[K]) => setF((x) => ({ ...x, [k]: v }))
  const sections = lookups.data?.sections.filter((s) => s.grade_id === f.grade_id) ?? []

  function submit(e: FormEvent) {
    e.preventDefault()
    add.mutate({ ...f, year_id: lookups.data?.year?.id ?? '' }, {
      onSuccess: (s) => { setF(empty); onClose(); navigate(`/students/${s.id}`) },
    })
  }

  return (
    <Modal open={open} onClose={onClose} title="Add a student" wide>
      <form onSubmit={submit} className="grid gap-4 sm:grid-cols-2">
        <Field label="First name"><Input value={f.first_name} onChange={(e) => set('first_name', e.target.value)} required /></Field>
        <Field label="Father's name"><Input value={f.father_name} onChange={(e) => set('father_name', e.target.value)} required /></Field>
        <Field label="Grandfather's name"><Input value={f.grandfather_name} onChange={(e) => set('grandfather_name', e.target.value)} /></Field>
        <Field label="Sex">
          <Select value={f.gender} onChange={(e) => set('gender', e.target.value as 'M' | 'F')}>
            <option value="F">Female</option><option value="M">Male</option>
          </Select>
        </Field>
        <Field label="Birth date"><Input type="date" value={f.birth_date} onChange={(e) => set('birth_date', e.target.value)} /></Field>
        <Field label="Grade">
          <Select value={f.grade_id} onChange={(e) => { set('grade_id', e.target.value); set('section_id', '') }} required>
            <option value="">Choose…</option>
            {lookups.data?.grades.map((g) => <option key={g.id} value={g.id}>{g.name}</option>)}
          </Select>
        </Field>
        <Field label="Section" hint="The student ID is made automatically.">
          <Select value={f.section_id} onChange={(e) => set('section_id', e.target.value)} disabled={!f.grade_id}>
            <option value="">Not placed yet</option>
            {sections.map((s) => <option key={s.id} value={s.id}>{s.name}{s.stream ? ` (${s.stream})` : ''}</option>)}
          </Select>
        </Field>
        <div className="sm:col-span-2 border-t border-slate-100 pt-3 text-sm font-semibold text-slate-700">Parent or guardian</div>
        <Field label="Full name"><Input value={f.guardian_name} onChange={(e) => set('guardian_name', e.target.value)} /></Field>
        <Field label="Phone" hint="Used for the parent's login"><Input value={f.guardian_phone} onChange={(e) => set('guardian_phone', e.target.value)} placeholder="0911 22 33 44" inputMode="tel" /></Field>
        <Field label="Relationship">
          <Select value={f.relationship} onChange={(e) => set('relationship', e.target.value as NewStudent['relationship'])}>
            <option value="father">Father</option><option value="mother">Mother</option><option value="guardian">Guardian</option><option value="other">Other</option>
          </Select>
        </Field>
        <div className="sm:col-span-2">
          {add.error && <div className="mb-3"><Notice tone="error">{(add.error as Error).message}</Notice></div>}
          <div className="flex justify-end gap-2">
            <Button type="button" variant="ghost" onClick={onClose}>Cancel</Button>
            <Button type="submit" disabled={add.isPending}>{add.isPending ? 'Saving…' : 'Save student'}</Button>
          </div>
        </div>
      </form>
    </Modal>
  )
}
