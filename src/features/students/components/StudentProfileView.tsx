import { Bar, BarChart, CartesianGrid, Cell, Pie, PieChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import { Avatar, Badge, Card, Empty, KpiCard, Skeleton } from '../../../components/ui/Card'
import { ErrorNotice } from '../../../components/ui/Notice'
import { Icon } from '../../../components/ui/icons'
import { C, axis, grid, tooltipStyle } from '../../../components/charts/theme'
import { date, etb, FINE_KIND_LABEL, pct, shortDate, titleCase } from '../../../lib/format'
import { formatPhone } from '../../../lib/phone'
import { useLookups } from '../../school/hooks'
import { useStudentProfile } from '../hooks'

const INVOICE_TONE = { paid: 'green', partial: 'amber', unpaid: 'red', void: 'slate' } as const
const FINE_TONE = { open: 'red', paid: 'green', waived: 'slate' } as const

/** Everything about one student: used by staff (profile page) and by the student or parent (portal). */
export function StudentProfileView({ studentId }: { studentId: string }) {
  const lookups = useLookups()
  const q = useStudentProfile(studentId)

  if (q.error) return <ErrorNotice error={q.error} />
  if (!q.data || !lookups.data) {
    return <div className="space-y-4"><Skeleton className="h-36" /><Skeleton className="h-24" /><Skeleton className="h-80" /></div>
  }
  const { student: s, current, guardians, attendance, results, invoices, fines, missedDays } = q.data
  const L = lookups.data
  const fullName = [s.first_name, s.father_name, s.grandfather_name].filter(Boolean).join(' ')
  const fullNameAm = [s.first_name_am, s.father_name_am, s.grandfather_name_am].filter(Boolean).join(' ')
  const gradeName = L.grades.find((g) => g.level === current?.grade_level)?.name
  const subjectRows = results
    .map((r) => ({ ...r, name: L.subjectById.get(r.subject_id ?? '')?.name ?? '?' }))
    .sort((a, b) => (b.percent ?? 0) - (a.percent ?? 0))
  const average = subjectRows.length ? subjectRows.reduce((t, r) => t + Number(r.percent ?? 0), 0) / subjectRows.length : null
  const balance = invoices.filter((i) => i.status !== 'void').reduce((t, i) => t + Number(i.total) - Number(i.discount) - Number(i.paid), 0)
  const openFines = fines.filter((f) => f.status === 'open')
  const attDonut = attendance ? [
    { name: 'Present', value: attendance.present ?? 0, color: C.green },
    { name: 'Late', value: attendance.late ?? 0, color: C.amber },
    { name: 'Absent', value: attendance.absent ?? 0, color: C.rose },
    { name: 'Excused', value: attendance.excused ?? 0, color: C.slate },
  ] : []

  return (
    <div className="space-y-5">
      {/* Identity */}
      <Card delay={0}>
        <div className="flex flex-wrap items-start gap-4">
          <div className="grid h-16 w-16 place-items-center rounded-2xl bg-gradient-to-br from-indigo-500 to-blue-500 text-xl font-extrabold text-white shadow-lg">
            {(s.first_name[0] ?? '') + (s.father_name[0] ?? '')}
          </div>
          <div className="min-w-0 flex-1">
            <h1 className="text-2xl font-extrabold tracking-tight">{fullName}</h1>
            {fullNameAm && <p className="text-slate-500">{fullNameAm}</p>}
            <div className="mt-2 flex flex-wrap gap-2 text-xs">
              <Badge tone="purple">{s.student_code}</Badge>
              {gradeName && <Badge tone="blue">{gradeName}{current?.section_name ? ` · ${current.section_name}` : ''}</Badge>}
              {current?.stream && <Badge tone="slate">{titleCase(current.stream)} stream</Badge>}
              <Badge tone={s.status === 'active' ? 'green' : 'amber'}>{titleCase(s.status)}</Badge>
            </div>
          </div>
          <dl className="grid grid-cols-2 gap-x-6 gap-y-1 text-sm">
            <dt className="text-slate-500">Sex</dt><dd className="font-medium">{s.gender === 'F' ? 'Female' : 'Male'}</dd>
            <dt className="text-slate-500">Born</dt><dd className="font-medium">{date(s.birth_date)}</dd>
            <dt className="text-slate-500">Address</dt><dd className="font-medium">{[s.sub_city, s.woreda && `Woreda ${s.woreda}`].filter(Boolean).join(', ') || '—'}</dd>
            <dt className="text-slate-500">Admitted</dt><dd className="font-medium">{date(s.admission_date)}</dd>
          </dl>
        </div>
        {guardians.length > 0 && (
          <div className="mt-4 flex flex-wrap gap-3 border-t border-slate-100 pt-4">
            {guardians.map((g) => (
              <div key={g.id} className="flex items-center gap-3 rounded-xl bg-slate-50 px-3 py-2">
                <Avatar name={g.full_name} tone="bg-amber-100 text-amber-700" />
                <div className="text-sm">
                  <p className="font-semibold">{g.full_name} <span className="font-normal text-slate-500">· {titleCase(g.relationship)}</span></p>
                  <p className="text-slate-500">{formatPhone(g.phone)}{g.occupation ? ` · ${g.occupation}` : ''}</p>
                </div>
              </div>
            ))}
          </div>
        )}
      </Card>

      {/* KPIs */}
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <KpiCard tone="indigo" delay={60} label="Average so far" value={average} format={(n) => `${n.toFixed(1)}%`} sub="Semester 1" icon={<Icon name="award" />} />
        <KpiCard tone="teal" delay={120} label="Attendance" value={attendance?.rate ?? null} format={(n) => `${n.toFixed(1)}%`}
          sub={attendance ? `${attendance.absent} absent · ${attendance.late} late` : 'No records'} icon={<Icon name="attendance" />} />
        <KpiCard tone={balance > 0 ? 'orange' : 'green'} delay={180} label="Fee balance" value={balance} format={(n) => etb(n)}
          sub={balance > 0 ? 'Still to pay' : 'All paid'} icon={<Icon name="wallet" />} />
        <KpiCard tone="rose" delay={240} label="Fines · ቅጣት" value={openFines.length}
          sub={openFines.length ? etb(openFines.reduce((t, f) => t + Number(f.amount), 0)) + ' open' : 'None open'} icon={<Icon name="fines" />} />
      </div>

      <div className="grid gap-5 xl:grid-cols-3">
        <Card title="Results by subject" subtitle="Percent of the marks entered so far" className="xl:col-span-2" delay={180}>
          {subjectRows.length === 0 ? <Empty>No marks yet.</Empty> : (
            <div style={{ height: Math.max(220, subjectRows.length * 34) }}>
              <ResponsiveContainer>
                <BarChart data={subjectRows} layout="vertical" margin={{ top: 0, right: 30, left: 10, bottom: 0 }}>
                  <CartesianGrid stroke={grid} horizontal={false} />
                  <XAxis type="number" domain={[0, 100]} tick={axis} axisLine={false} tickLine={false} tickFormatter={(v) => `${v}%`} />
                  <YAxis type="category" dataKey="name" tick={axis} axisLine={false} tickLine={false} width={150} />
                  <Tooltip {...tooltipStyle} formatter={(v) => `${v}%`} />
                  <Bar dataKey="percent" name="Score" radius={[0, 6, 6, 0]} animationDuration={1000} label={{ position: 'right', fontSize: 11, fill: '#334155', formatter: (v: number) => `${v}%` }}>
                    {subjectRows.map((r) => (
                      <Cell key={r.subject_id} fill={Number(r.percent) >= 80 ? C.green : Number(r.percent) >= 60 ? C.indigo : C.orange} />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            </div>
          )}
        </Card>

        <Card title="Attendance" subtitle={attendance ? `${attendance.days} school days` : undefined} delay={220}>
          {!attendance || !attendance.days ? <Empty>No attendance yet.</Empty> : (
            <>
              <div className="relative h-44">
                <ResponsiveContainer>
                  <PieChart>
                    <Pie data={attDonut} dataKey="value" innerRadius={52} outerRadius={74} paddingAngle={2} stroke="none" animationDuration={1000}>
                      {attDonut.map((a) => <Cell key={a.name} fill={a.color} />)}
                    </Pie>
                    <Tooltip {...tooltipStyle} />
                  </PieChart>
                </ResponsiveContainer>
                <div className="pointer-events-none absolute inset-0 grid place-items-center text-center">
                  <div><p className="text-xl font-extrabold">{pct(attendance.rate)}</p><p className="text-[10px] font-semibold uppercase text-slate-500">present</p></div>
                </div>
              </div>
              <p className="mb-1 mt-2 text-xs font-semibold uppercase text-slate-500">Days missed or late</p>
              {missedDays.length === 0 ? <p className="text-sm text-slate-500">Never — well done!</p> : (
                <ul className="scroll-thin max-h-36 space-y-1 overflow-y-auto text-sm">
                  {missedDays.slice(0, 12).map((m, i) => (
                    <li key={i} className="flex justify-between">
                      <span>{shortDate(m.date)}</span>
                      <Badge tone={m.status === 'absent' ? 'red' : m.status === 'late' ? 'amber' : 'slate'}>{titleCase(m.status)}</Badge>
                    </li>
                  ))}
                </ul>
              )}
            </>
          )}
        </Card>
      </div>

      <div className="grid gap-5 xl:grid-cols-2">
        <Card title="Fees" subtitle="Invoices this year" delay={240} bodyClass="p-0 pt-2">
          {invoices.length === 0 ? <Empty>No invoices.</Empty> : (
            <table className="w-full text-left text-sm">
              <thead className="text-xs uppercase tracking-wide text-slate-500">
                <tr><th className="px-5 py-2 font-semibold">For</th><th className="px-5 py-2 font-semibold">Due</th><th className="px-5 py-2 text-right font-semibold">Amount</th><th className="px-5 py-2 font-semibold">Status</th></tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {invoices.map((i) => (
                  <tr key={i.id}>
                    <td className="px-5 py-2.5"><span className="font-medium">{i.period}</span><div className="font-mono text-[11px] text-slate-400">{i.invoice_no}</div></td>
                    <td className="px-5 py-2.5 text-slate-600">{date(i.due_date)}</td>
                    <td className="px-5 py-2.5 text-right tabular-nums">
                      {etb(Number(i.total) - Number(i.discount))}
                      {Number(i.discount) > 0 && <div className="text-[11px] text-emerald-600">−{etb(i.discount)} discount</div>}
                    </td>
                    <td className="px-5 py-2.5"><Badge tone={INVOICE_TONE[i.status]}>{titleCase(i.status)}</Badge></td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </Card>

        <Card title="Fines & discipline · ቅጣት" delay={280} bodyClass="p-0 pt-2">
          {fines.length === 0 ? <Empty>No fines or discipline records.</Empty> : (
            <ul className="divide-y divide-slate-100">
              {fines.map((f) => (
                <li key={f.id} className="flex items-center gap-3 px-5 py-3 text-sm">
                  <div className="min-w-0 flex-1">
                    <p className="font-medium">{f.reason}</p>
                    <p className="text-xs text-slate-500">{FINE_KIND_LABEL[f.kind]} · {date(f.issued_on)}</p>
                  </div>
                  {Number(f.amount) > 0 && <span className="font-semibold tabular-nums">{etb(f.amount)}</span>}
                  <Badge tone={FINE_TONE[f.status]}>{titleCase(f.status)}</Badge>
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>
    </div>
  )
}
