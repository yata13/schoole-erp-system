import { useMemo, useState, type FormEvent } from 'react'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Avatar, Badge, Card, Empty, KpiCard, PageHeader, Skeleton } from '../../../components/ui/Card'
import { Button, Field, Input, Select } from '../../../components/ui/Field'
import { Modal } from '../../../components/ui/Modal'
import { ErrorNotice, Notice } from '../../../components/ui/Notice'
import { Icon } from '../../../components/ui/icons'
import { date, etb, etbShort, num, POSITION_LABEL, titleCase } from '../../../lib/format'
import { formatPhone } from '../../../lib/phone'
import { useAuth } from '../../auth/AuthProvider'
import { addStaff, listStaff, type NewStaff } from '../api'

const GROUPS: { key: string; label: string; positions: string[] }[] = [
  { key: 'all', label: 'Everyone', positions: [] },
  { key: 'teacher', label: 'Teachers', positions: ['teacher'] },
  { key: 'office', label: 'Office', positions: ['director', 'registrar', 'accountant', 'cashier', 'librarian', 'nurse'] },
  { key: 'support', label: 'Support', positions: ['cleaner', 'guard', 'driver', 'cook', 'other'] },
]
const POSITION_TONE: Record<string, 'blue' | 'purple' | 'green' | 'amber' | 'slate' | 'red'> = {
  teacher: 'blue', director: 'purple', registrar: 'purple', accountant: 'purple', cashier: 'purple',
  librarian: 'green', nurse: 'green', cleaner: 'amber', guard: 'slate', driver: 'slate', cook: 'amber', other: 'slate',
}

export function StaffPage() {
  const { schoolId, hasAnyRole } = useAuth()
  const q = useQuery({ queryKey: ['staff', schoolId], queryFn: listStaff })
  const [group, setGroup] = useState('all')
  const [search, setSearch] = useState('')
  const [adding, setAdding] = useState(false)

  const rows = useMemo(() => {
    const g = GROUPS.find((x) => x.key === group)!
    const s = search.trim().toLowerCase()
    return (q.data?.rows ?? []).filter((r) =>
      (g.positions.length === 0 || g.positions.includes(r.position)) &&
      (!s || `${r.first_name} ${r.father_name} ${r.staff_code}`.toLowerCase().includes(s)))
  }, [q.data, group, search])

  const all = q.data?.rows ?? []
  const payroll = all.reduce((t, r) => t + (r.salary ?? 0), 0)
  const count = (key: string) => {
    const g = GROUPS.find((x) => x.key === key)!
    return g.positions.length ? all.filter((r) => g.positions.includes(r.position)).length : all.length
  }

  return (
    <div>
      <PageHeader title="Staff" subtitle="Teachers, office and support staff — everyone who works at the school"
        actions={hasAnyRole('super_admin') && <Button onClick={() => setAdding(true)}><Icon name="plus" className="h-4 w-4" /> Add employee</Button>} />

      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <KpiCard tone="indigo" label="All staff" value={q.data ? all.length : null} icon={<Icon name="staff" />} sub="Active employees" />
        <KpiCard tone="blue" delay={60} label="Teachers" value={q.data ? count('teacher') : null} icon={<Icon name="book" />} sub="Including KG" />
        <KpiCard tone="amber" delay={120} label="Support staff" value={q.data ? count('support') : null} icon={<Icon name="shield" />} sub="Cleaners, guards, drivers, cooks" />
        <KpiCard tone="green" delay={180} label="Monthly payroll" value={q.data?.canSeeSalaries ? payroll : null} format={etbShort}
          icon={<Icon name="cash" />} sub={q.data?.canSeeSalaries ? 'Salaries, ETB' : 'Finance only'} />
      </div>

      <Card className="mt-5" bodyClass="p-0" delay={200}>
        <div className="flex flex-col gap-3 border-b border-slate-100 p-4 md:flex-row md:items-center md:justify-between">
          <div className="flex flex-wrap gap-2">
            {GROUPS.map((g) => (
              <button key={g.key} onClick={() => setGroup(g.key)}
                className={`rounded-full px-3.5 py-1.5 text-sm font-semibold transition ${group === g.key ? 'bg-indigo-600 text-white shadow' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'}`}>
                {g.label} <span className="opacity-70">{q.data ? count(g.key) : ''}</span>
              </button>
            ))}
          </div>
          <Input type="search" placeholder="Search name or code" value={search} onChange={(e) => setSearch(e.target.value)} className="md:max-w-xs" aria-label="Search staff" />
        </div>
        {q.isLoading ? <div className="space-y-2 p-4">{Array.from({ length: 8 }).map((_, i) => <Skeleton key={i} className="h-12" />)}</div>
          : q.error ? <div className="p-4"><ErrorNotice error={q.error} /></div>
          : rows.length === 0 ? <Empty>No one matches.</Empty> : (
            <div className="overflow-x-auto">
              <table className="w-full min-w-[720px] text-left text-sm">
                <thead className="bg-slate-50/70 text-xs uppercase tracking-wide text-slate-500">
                  <tr>
                    <th className="px-4 py-3 font-semibold">Name</th>
                    <th className="px-4 py-3 font-semibold">Role</th>
                    <th className="px-4 py-3 font-semibold">Phone</th>
                    <th className="px-4 py-3 font-semibold">Type</th>
                    <th className="px-4 py-3 font-semibold">Hired</th>
                    <th className="px-4 py-3 font-semibold">Classes</th>
                    {q.data?.canSeeSalaries && <th className="px-4 py-3 text-right font-semibold">Salary / month</th>}
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {rows.map((r) => (
                    <tr key={r.id} className="hover:bg-slate-50/60">
                      <td className="px-4 py-2.5">
                        <div className="flex items-center gap-3">
                          <Avatar name={`${r.first_name} ${r.father_name}`} />
                          <div><p className="font-semibold">{r.first_name} {r.father_name}</p><p className="font-mono text-[11px] text-slate-400">{r.staff_code}{r.qualification ? ` · ${r.qualification}` : ''}</p></div>
                        </div>
                      </td>
                      <td className="px-4 py-2.5"><Badge tone={POSITION_TONE[r.position] ?? 'slate'}>{POSITION_LABEL[r.position] ?? r.position}</Badge></td>
                      <td className="px-4 py-2.5 text-slate-600">{formatPhone(r.phone) || '—'}</td>
                      <td className="px-4 py-2.5 text-slate-600">{titleCase(r.employment_type)}</td>
                      <td className="px-4 py-2.5 text-slate-600">{date(r.hire_date)}</td>
                      <td className="px-4 py-2.5 tabular-nums">{r.classes ? num(r.classes) : '—'}</td>
                      {q.data?.canSeeSalaries && <td className="px-4 py-2.5 text-right font-semibold tabular-nums">{etb(r.salary)}</td>}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
      </Card>

      <AddStaffModal open={adding} onClose={() => setAdding(false)} />
    </div>
  )
}

function AddStaffModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { schoolId } = useAuth()
  const qc = useQueryClient()
  const empty: NewStaff = { staff_code: '', first_name: '', father_name: '', gender: 'F', position: 'teacher', phone: '', employment_type: 'full_time', qualification: '', salary: '' }
  const [f, setF] = useState<NewStaff>(empty)
  const set = <K extends keyof NewStaff>(k: K, v: NewStaff[K]) => setF((x) => ({ ...x, [k]: v }))
  const add = useMutation({
    mutationFn: () => addStaff(schoolId!, f),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['staff'] }); qc.invalidateQueries({ queryKey: ['dashboard'] }); qc.invalidateQueries({ queryKey: ['lookups'] }); setF(empty); onClose() },
  })
  function submit(e: FormEvent) { e.preventDefault(); add.mutate() }

  return (
    <Modal open={open} onClose={onClose} title="Add an employee" wide>
      <form onSubmit={submit} className="grid gap-4 sm:grid-cols-2">
        <Field label="First name"><Input value={f.first_name} onChange={(e) => set('first_name', e.target.value)} required /></Field>
        <Field label="Father's name"><Input value={f.father_name} onChange={(e) => set('father_name', e.target.value)} required /></Field>
        <Field label="Role">
          <Select value={f.position} onChange={(e) => set('position', e.target.value as NewStaff['position'])}>
            {Object.entries(POSITION_LABEL).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
          </Select>
        </Field>
        <Field label="Staff code" hint="e.g. T-027, C-006, G-005"><Input value={f.staff_code} onChange={(e) => set('staff_code', e.target.value)} required /></Field>
        <Field label="Sex">
          <Select value={f.gender} onChange={(e) => set('gender', e.target.value as 'M' | 'F')}><option value="F">Female</option><option value="M">Male</option></Select>
        </Field>
        <Field label="Phone"><Input value={f.phone} onChange={(e) => set('phone', e.target.value)} placeholder="0911 22 33 44" inputMode="tel" /></Field>
        <Field label="Employment">
          <Select value={f.employment_type} onChange={(e) => set('employment_type', e.target.value as NewStaff['employment_type'])}>
            <option value="full_time">Full time</option><option value="part_time">Part time</option><option value="contract">Contract</option>
          </Select>
        </Field>
        <Field label="Monthly salary (ETB)"><Input type="number" min="0" step="50" value={f.salary} onChange={(e) => set('salary', e.target.value)} /></Field>
        <div className="sm:col-span-2"><Field label="Qualification"><Input value={f.qualification} onChange={(e) => set('qualification', e.target.value)} placeholder="e.g. BSc Mathematics" /></Field></div>
        <div className="sm:col-span-2">
          {add.error && <div className="mb-3"><Notice tone="error">{(add.error as Error).message}</Notice></div>}
          <div className="flex justify-end gap-2">
            <Button type="button" variant="ghost" onClick={onClose}>Cancel</Button>
            <Button type="submit" disabled={add.isPending}>{add.isPending ? 'Saving…' : 'Save employee'}</Button>
          </div>
        </div>
      </form>
    </Modal>
  )
}
