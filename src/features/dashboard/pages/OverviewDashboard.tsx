import { useQuery } from '@tanstack/react-query'
import { Link } from 'react-router'
import {
  Area, AreaChart, Bar, BarChart, CartesianGrid, Cell, Legend, Line, LineChart, Pie, PieChart,
  ResponsiveContainer, Tooltip, XAxis, YAxis,
} from 'recharts'
import { Avatar, Badge, Card, KpiCard, PageHeader, ProgressBar, Skeleton } from '../../../components/ui/Card'
import { ErrorNotice } from '../../../components/ui/Notice'
import { Icon } from '../../../components/ui/icons'
import { C, SERIES, axis, grid, tooltipStyle } from '../../../components/charts/theme'
import { etb, etbShort, monthLabel, num, pct, POSITION_LABEL, shortDate, titleCase } from '../../../lib/format'
import { useAuth } from '../../auth/AuthProvider'
import { useMySchool } from '../../auth/hooks'
import { getDashboard } from '../api'

export function OverviewDashboard() {
  const { schoolId } = useAuth()
  const school = useMySchool()
  const q = useQuery({ queryKey: ['dashboard', schoolId], queryFn: getDashboard, staleTime: 60_000 })

  if (q.error) return <ErrorNotice error={q.error} />
  const d = q.data

  const fees = d?.finance.fees
  const collectionRate = fees && fees.billed > 0 ? (100 * fees.collected) / fees.billed : 0
  const feeDonut = fees ? [
    { name: 'Paid', value: fees.paid, color: C.green },
    { name: 'Partial', value: fees.partial, color: C.amber },
    { name: 'Unpaid', value: fees.unpaid, color: C.rose },
  ] : []
  const monthly = (d?.finance.monthly ?? []).map((m) => ({ ...m, label: monthLabel(m.month) }))
  const att = (d?.attendance.days ?? []).map((a) => ({ ...a, label: shortDate(a.date) }))
  const staffPos = (d?.staff.by_position ?? []).map((p) => ({ name: POSITION_LABEL[p.position] ?? titleCase(p.position), value: p.count }))
  const thisMonth = d?.finance.this_month

  return (
    <div>
      <PageHeader
        title="Overview"
        subtitle={<>School performance at a glance · {school.data?.name}</>}
        actions={d && (
          <>
            <span className="rise rounded-xl border border-slate-200 bg-white px-3 py-2 text-xs font-semibold text-slate-600 shadow-sm">
              Academic year <span className="ml-1 text-slate-900">{d.year}</span>
            </span>
            <span className="rise rounded-xl border border-slate-200 bg-white px-3 py-2 text-xs font-semibold text-slate-600 shadow-sm">
              Semester <span className="ml-1 text-slate-900">{d.semester ?? '—'}</span>
            </span>
          </>
        )}
      />

      {/* KPI tiles */}
      <div className="grid grid-cols-2 gap-3 md:grid-cols-3 2xl:grid-cols-6">
        {!d ? Array.from({ length: 6 }).map((_, i) => <Skeleton key={i} className="h-[92px]" />) : (
          <>
            <KpiCard tone="blue" delay={0} label="Total students" value={d.students.total}
              sub={<>♂ {num(d.students.male)} · ♀ {num(d.students.female)}</>} icon={<Icon name="students" />} />
            <KpiCard tone="purple" delay={60} label="Staff" value={d.staff.total}
              sub={<>Payroll {etbShort(d.staff.monthly_payroll)} / month</>} icon={<Icon name="staff" />} />
            <KpiCard tone="green" delay={120} label="Revenue this month" value={thisMonth?.revenue ?? 0} format={etbShort}
              sub="Fees collected, ETB" icon={<Icon name="trend" />} />
            <KpiCard tone="orange" delay={180} label="Expenses this month" value={thisMonth?.expenses ?? 0} format={etbShort}
              sub="Spent, ETB" icon={<Icon name="wallet" />} />
            <KpiCard tone="teal" delay={240} label="Attendance today" value={d.attendance.latest?.rate ?? 0}
              format={(n) => `${n.toFixed(1)}%`}
              sub={d.attendance.latest ? <>{num(d.attendance.latest.absent)} absent · {num(d.attendance.latest.late)} late</> : '—'}
              icon={<Icon name="attendance" />} />
            <KpiCard tone="rose" delay={300} label="Open fines · ቅጣት" value={d.fines?.open ?? 0}
              sub={<>{etb(d.fines?.open_amount)} unpaid</>} icon={<Icon name="fines" />} />
          </>
        )}
      </div>

      <div className="mt-5 grid gap-5 xl:grid-cols-3">
        {/* Revenue vs expenses */}
        <Card title="Revenue vs expenses" subtitle="Money in and out per month (ETB)" className="xl:col-span-2" delay={120}>
          <div className="h-72">
            {!d ? <Skeleton className="h-full" /> : (
              <ResponsiveContainer>
                <AreaChart data={monthly} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
                  <defs>
                    <linearGradient id="rev" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor={C.green} stopOpacity={0.35} />
                      <stop offset="100%" stopColor={C.green} stopOpacity={0} />
                    </linearGradient>
                    <linearGradient id="exp" x1="0" y1="0" x2="0" y2="1">
                      <stop offset="0%" stopColor={C.orange} stopOpacity={0.3} />
                      <stop offset="100%" stopColor={C.orange} stopOpacity={0} />
                    </linearGradient>
                  </defs>
                  <CartesianGrid stroke={grid} vertical={false} />
                  <XAxis dataKey="label" tick={axis} axisLine={false} tickLine={false} />
                  <YAxis tick={axis} axisLine={false} tickLine={false} tickFormatter={etbShort} width={48} />
                  <Tooltip {...tooltipStyle} formatter={(v) => etb(Number(v))} />
                  <Legend wrapperStyle={{ fontSize: 12 }} />
                  <Area type="monotone" dataKey="revenue" name="Revenue" stroke={C.green} strokeWidth={2.5} fill="url(#rev)" animationDuration={1200} />
                  <Area type="monotone" dataKey="expenses" name="Expenses" stroke={C.orange} strokeWidth={2.5} fill="url(#exp)" animationDuration={1200} />
                </AreaChart>
              </ResponsiveContainer>
            )}
          </div>
        </Card>

        {/* Fee status donut */}
        <Card title="Fee collection" subtitle="All invoices this year" delay={180}>
          {!d || !fees ? <Skeleton className="h-72" /> : (
            <>
              <div className="relative h-52">
                <ResponsiveContainer>
                  <PieChart>
                    <Pie data={feeDonut} dataKey="value" nameKey="name" innerRadius={62} outerRadius={88} paddingAngle={2}
                      animationDuration={1100} stroke="none">
                      {feeDonut.map((s) => <Cell key={s.name} fill={s.color} />)}
                    </Pie>
                    <Tooltip {...tooltipStyle} formatter={(v) => `${num(Number(v))} invoices`} />
                  </PieChart>
                </ResponsiveContainer>
                <div className="pointer-events-none absolute inset-0 grid place-items-center text-center">
                  <div>
                    <p className="text-2xl font-extrabold">{pct(collectionRate)}</p>
                    <p className="text-[11px] font-semibold uppercase text-slate-500">collected</p>
                  </div>
                </div>
              </div>
              <ul className="mt-2 space-y-1.5 text-sm">
                {feeDonut.map((s) => (
                  <li key={s.name} className="flex items-center justify-between">
                    <span className="flex items-center gap-2"><span className="h-2.5 w-2.5 rounded-full" style={{ background: s.color }} />{s.name}</span>
                    <span className="font-semibold tabular-nums">{num(s.value)}</span>
                  </li>
                ))}
                <li className="flex items-center justify-between border-t border-slate-100 pt-1.5">
                  <span className="text-slate-500">Still owed</span>
                  <span className="font-bold text-rose-600 tabular-nums">{etb(fees.outstanding)}</span>
                </li>
              </ul>
            </>
          )}
        </Card>
      </div>

      <div className="mt-5 grid gap-5 xl:grid-cols-3">
        {/* Students by grade */}
        <Card title="Students by grade" subtitle="Boys and girls, KG to grade 12" className="xl:col-span-2" delay={200}>
          <div className="h-72">
            {!d ? <Skeleton className="h-full" /> : (
              <ResponsiveContainer>
                <BarChart data={d.students.by_grade} margin={{ top: 10, right: 10, left: -10, bottom: 0 }}>
                  <CartesianGrid stroke={grid} vertical={false} />
                  <XAxis dataKey="grade" tick={axis} axisLine={false} tickLine={false} tickFormatter={(g: string) => g.replace('Grade ', 'G')} />
                  <YAxis tick={axis} axisLine={false} tickLine={false} />
                  <Tooltip {...tooltipStyle} />
                  <Legend wrapperStyle={{ fontSize: 12 }} />
                  <Bar dataKey="male" name="Boys" stackId="s" fill={C.blue} radius={[0, 0, 0, 0]} animationDuration={1000} />
                  <Bar dataKey="female" name="Girls" stackId="s" fill={C.rose} radius={[6, 6, 0, 0]} animationDuration={1000} />
                </BarChart>
              </ResponsiveContainer>
            )}
          </div>
        </Card>

        {/* Staff by position */}
        <Card title="Staff by role" subtitle="Teachers, office and support staff" delay={240}>
          {!d ? <Skeleton className="h-72" /> : (
            <div className="h-72">
              <ResponsiveContainer>
                <BarChart data={staffPos} layout="vertical" margin={{ top: 0, right: 20, left: 10, bottom: 0 }}>
                  <CartesianGrid stroke={grid} horizontal={false} />
                  <XAxis type="number" tick={axis} axisLine={false} tickLine={false} allowDecimals={false} />
                  <YAxis type="category" dataKey="name" tick={axis} axisLine={false} tickLine={false} width={78} />
                  <Tooltip {...tooltipStyle} />
                  <Bar dataKey="value" name="People" radius={[0, 6, 6, 0]} animationDuration={1000}>
                    {staffPos.map((_, i) => <Cell key={i} fill={SERIES[i % SERIES.length]} />)}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            </div>
          )}
        </Card>
      </div>

      <div className="mt-5 grid gap-5 xl:grid-cols-3">
        {/* Attendance trend */}
        <Card title="Attendance trend" subtitle="% present each school day (last 30 days)" className="xl:col-span-2" delay={260}>
          <div className="h-64 xl:h-[25rem]">
            {!d ? <Skeleton className="h-full" /> : (
              <ResponsiveContainer>
                <LineChart data={att} margin={{ top: 10, right: 10, left: -10, bottom: 0 }}>
                  <CartesianGrid stroke={grid} vertical={false} />
                  <XAxis dataKey="label" tick={axis} axisLine={false} tickLine={false} interval="preserveStartEnd" />
                  <YAxis tick={axis} axisLine={false} tickLine={false} domain={[80, 100]} tickFormatter={(v) => `${v}%`} />
                  <Tooltip {...tooltipStyle} formatter={(v, n) => (n === 'Rate' ? `${v}%` : v)} />
                  <Line type="monotone" dataKey="rate" name="Rate" stroke={C.teal} strokeWidth={3} dot={false} animationDuration={1300} />
                </LineChart>
              </ResponsiveContainer>
            )}
          </div>
        </Card>

        {/* Results by grade */}
        <Card title="Average score by grade" subtitle="Semester 1 so far" delay={300}>
          {!d ? <Skeleton className="h-64" /> : (
            <ul className="space-y-2.5">
              {d.results.by_grade.map((g) => (
                <li key={g.grade} className="flex items-center gap-3 text-sm">
                  <span className="w-16 shrink-0 font-semibold text-slate-700">{g.grade.replace('Grade ', 'Gr ')}</span>
                  <ProgressBar value={g.average} tone={g.average >= 80 ? 'bg-emerald-500' : g.average >= 65 ? 'bg-indigo-500' : 'bg-amber-500'} />
                  <span className="w-12 shrink-0 text-right font-bold tabular-nums">{g.average}%</span>
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>

      <div className="mt-5 grid gap-5 xl:grid-cols-2">
        <Card title="Top performing students" subtitle="Highest averages this semester" delay={320}
          action={<Link to="/students" className="text-xs font-semibold text-indigo-600 hover:underline">All students</Link>}>
          {!d ? <Skeleton className="h-56" /> : (
            <ol className="divide-y divide-slate-100">
              {d.results.top.map((s, i) => (
                <li key={s.name + i} className="flex items-center gap-3 py-2.5">
                  <span className={`grid h-7 w-7 place-items-center rounded-full text-xs font-bold ${
                    i === 0 ? 'bg-amber-100 text-amber-700' : i === 1 ? 'bg-slate-200 text-slate-700' : i === 2 ? 'bg-orange-100 text-orange-700' : 'bg-slate-100 text-slate-500'}`}>{i + 1}</span>
                  <Avatar name={s.name} />
                  <div className="min-w-0 flex-1">
                    <p className="truncate font-semibold">{s.name}</p>
                    <p className="text-xs text-slate-500">{s.grade} · {s.section}</p>
                  </div>
                  <span className="font-bold text-emerald-600 tabular-nums">{s.average}%</span>
                </li>
              ))}
            </ol>
          )}
        </Card>

        <Card title="Recent payments" subtitle="Latest fee payments" delay={360}
          action={<Link to="/finance" className="text-xs font-semibold text-indigo-600 hover:underline">Finance</Link>}>
          {!d ? <Skeleton className="h-56" /> : (
            <div className="overflow-x-auto">
              <table className="w-full text-left text-sm">
                <thead className="text-xs uppercase tracking-wide text-slate-500">
                  <tr><th className="py-2 font-semibold">Student</th><th className="py-2 font-semibold">For</th><th className="py-2 font-semibold">Method</th><th className="py-2 text-right font-semibold">Amount</th></tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {d.recent_payments.map((p) => (
                    <tr key={p.receipt_no}>
                      <td className="py-2.5 font-medium">{p.student_name}<div className="font-mono text-[11px] text-slate-400">{p.receipt_no}</div></td>
                      <td className="py-2.5 text-slate-600">{p.period}</td>
                      <td className="py-2.5"><Badge tone={p.method === 'telebirr' ? 'blue' : p.method === 'bank' ? 'purple' : 'slate'}>{titleCase(p.method)}</Badge></td>
                      <td className="py-2.5 text-right font-bold tabular-nums">{etb(p.amount)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </Card>
      </div>

      {d?.seats && (
        <p className="mt-6 text-center text-xs text-slate-400">
          {num(d.seats.sections)} sections · {num(d.seats.placed)} of {num(d.seats.capacity)} seats used · data updates live
        </p>
      )}
    </div>
  )
}
