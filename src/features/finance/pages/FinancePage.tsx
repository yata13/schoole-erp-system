import { useMemo, useState, type FormEvent } from 'react'
import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Bar, BarChart, CartesianGrid, Cell, Legend, Pie, PieChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import { Badge, Card, Empty, KpiCard, PageHeader, ProgressBar, Skeleton } from '../../../components/ui/Card'
import { Button, Field, Input, Select } from '../../../components/ui/Field'
import { Modal } from '../../../components/ui/Modal'
import { ErrorNotice, Notice } from '../../../components/ui/Notice'
import { Icon } from '../../../components/ui/icons'
import { C, SERIES, axis, grid, tooltipStyle } from '../../../components/charts/theme'
import { useDebounce } from '../../../hooks/useDebounce'
import { date, etb, etbShort, monthLabel, num, pct, titleCase } from '../../../lib/format'
import type { Tables } from '../../../lib/supabase'
import { useAuth } from '../../auth/AuthProvider'
import { addExpense, findOpenInvoices, getFinanceSummary, listInvoices, listPayments, PAGE_SIZE, recordPayment } from '../api'

const STATUS_TONE = { paid: 'green', partial: 'amber', unpaid: 'red', void: 'slate' } as const
const METHOD_TONE = { telebirr: 'blue', bank: 'purple', cash: 'slate' } as const
const TABS = ['Payments', 'Invoices', 'Expenses'] as const

export function FinancePage() {
  const { schoolId, hasAnyRole } = useAuth()
  const canEdit = hasAnyRole('super_admin', 'finance')
  const summary = useQuery({ queryKey: ['finance_summary', schoolId], queryFn: getFinanceSummary })
  const [tab, setTab] = useState<(typeof TABS)[number]>('Payments')
  const [paying, setPaying] = useState(false)
  const [spending, setSpending] = useState(false)

  const s = summary.data
  const totals = useMemo(() => {
    if (!s) return null
    const billed = s.periods.reduce((t, p) => t + Number(p.billed), 0)
    const collected = s.periods.reduce((t, p) => t + Number(p.collected), 0)
    const outstanding = s.periods.reduce((t, p) => t + Number(p.outstanding), 0)
    const spent = s.expenses.reduce((t, e) => t + Number(e.amount), 0)
    return { billed, collected, outstanding, spent, net: collected - spent }
  }, [s])
  const byCategory = useMemo(() => {
    const m = new Map<string, number>()
    for (const e of s?.expenses ?? []) m.set(e.category, (m.get(e.category) ?? 0) + Number(e.amount))
    return [...m.entries()].map(([name, value]) => ({ name: titleCase(name), value })).sort((a, b) => b.value - a.value)
  }, [s])
  const monthly = (s?.months ?? []).map((m) => ({ ...m, label: monthLabel(String(m.month).slice(0, 7)), revenue: Number(m.revenue), expenses: Number(m.expenses) }))

  return (
    <div>
      <PageHeader title="Finance" subtitle="Fees, payments, expenses and monthly revenue (ETB)"
        actions={canEdit && (
          <>
            <Button variant="ghost" onClick={() => setSpending(true)}><Icon name="wallet" className="h-4 w-4" /> Add expense</Button>
            <Button onClick={() => setPaying(true)}><Icon name="cash" className="h-4 w-4" /> Record payment</Button>
          </>
        )} />

      {summary.error && <ErrorNotice error={summary.error} />}
      <div className="grid grid-cols-2 gap-3 lg:grid-cols-5">
        <KpiCard tone="indigo" label="Billed this year" value={totals?.billed ?? null} format={etbShort} icon={<Icon name="book" />} sub="All invoices" />
        <KpiCard tone="green" delay={60} label="Collected" value={totals?.collected ?? null} format={etbShort} icon={<Icon name="check" />}
          sub={totals ? `${pct((100 * totals.collected) / (totals.billed || 1))} of billed` : ''} />
        <KpiCard tone="rose" delay={120} label="Still owed" value={totals?.outstanding ?? null} format={etbShort} icon={<Icon name="clock" />} sub="Unpaid + partial" />
        <KpiCard tone="orange" delay={180} label="Expenses" value={totals?.spent ?? null} format={etbShort} icon={<Icon name="wallet" />} sub="Since Hamle" />
        <KpiCard tone="teal" delay={240} label="Net" value={totals?.net ?? null} format={etbShort} icon={<Icon name="trend" />} sub="Collected − expenses" />
      </div>

      <div className="mt-5 grid gap-5 xl:grid-cols-3">
        <Card title="Monthly revenue and expenses" className="xl:col-span-2" delay={120}>
          <div className="h-72">
            {!s ? <Skeleton className="h-full" /> : (
              <ResponsiveContainer>
                <BarChart data={monthly} margin={{ top: 10, right: 10, left: 0, bottom: 0 }}>
                  <CartesianGrid stroke={grid} vertical={false} />
                  <XAxis dataKey="label" tick={axis} axisLine={false} tickLine={false} />
                  <YAxis tick={axis} axisLine={false} tickLine={false} tickFormatter={etbShort} width={48} />
                  <Tooltip {...tooltipStyle} formatter={(v) => etb(Number(v))} />
                  <Legend wrapperStyle={{ fontSize: 12 }} />
                  <Bar dataKey="revenue" name="Revenue" fill={C.green} radius={[6, 6, 0, 0]} animationDuration={1000} />
                  <Bar dataKey="expenses" name="Expenses" fill={C.orange} radius={[6, 6, 0, 0]} animationDuration={1000} />
                </BarChart>
              </ResponsiveContainer>
            )}
          </div>
        </Card>
        <Card title="Where the money goes" subtitle="Expenses by category" delay={180}>
          {!s ? <Skeleton className="h-72" /> : (
            <>
              <div className="h-44">
                <ResponsiveContainer>
                  <PieChart>
                    <Pie data={byCategory} dataKey="value" nameKey="name" innerRadius={45} outerRadius={72} paddingAngle={2} stroke="none" animationDuration={1000}>
                      {byCategory.map((_, i) => <Cell key={i} fill={SERIES[i % SERIES.length]} />)}
                    </Pie>
                    <Tooltip {...tooltipStyle} formatter={(v) => etb(Number(v))} />
                  </PieChart>
                </ResponsiveContainer>
              </div>
              <ul className="mt-2 space-y-1 text-sm">
                {byCategory.map((c, i) => (
                  <li key={c.name} className="flex items-center justify-between">
                    <span className="flex items-center gap-2"><span className="h-2.5 w-2.5 rounded-full" style={{ background: SERIES[i % SERIES.length] }} />{c.name}</span>
                    <span className="font-semibold tabular-nums">{etb(c.value)}</span>
                  </li>
                ))}
              </ul>
            </>
          )}
        </Card>
      </div>

      <Card title="Fee collection by month" subtitle="How much of each month's fees is paid" className="mt-5" delay={220}>
        {!s ? <Skeleton className="h-40" /> : (
          <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
            {s.periods.map((p) => {
              const rate = Number(p.billed) ? (100 * Number(p.collected)) / Number(p.billed) : 0
              return (
                <div key={p.period} className="rounded-2xl border border-slate-100 bg-slate-50/60 p-4">
                  <p className="text-sm font-bold">{p.period}</p>
                  <p className="mt-1 text-2xl font-extrabold tabular-nums">{pct(rate)}</p>
                  <ProgressBar className="mt-2" value={rate} tone={rate >= 90 ? 'bg-emerald-500' : rate >= 60 ? 'bg-indigo-500' : 'bg-amber-500'} />
                  <p className="mt-2 text-xs text-slate-500">
                    <span className="font-semibold text-emerald-700">{num(p.paid)} paid</span> · <span className="text-amber-700">{num(p.partial)} partial</span> · <span className="text-rose-700">{num(p.unpaid)} unpaid</span>
                  </p>
                  <p className="text-xs text-slate-500">{etb(p.collected)} of {etb(p.billed)}</p>
                </div>
              )
            })}
          </div>
        )}
      </Card>

      <div className="mt-5 flex gap-2">
        {TABS.map((t) => (
          <button key={t} onClick={() => setTab(t)}
            className={`rounded-xl px-4 py-2 text-sm font-semibold transition ${tab === t ? 'bg-slate-900 text-white shadow' : 'bg-white text-slate-600 ring-1 ring-slate-200 hover:bg-slate-50'}`}>{t}</button>
        ))}
      </div>
      <div className="mt-3">
        {tab === 'Payments' && <PaymentsTable />}
        {tab === 'Invoices' && <InvoicesTable periods={(s?.periods ?? []).map((p) => p.period!)} />}
        {tab === 'Expenses' && <ExpensesTable rows={s?.expenses ?? []} />}
      </div>

      {canEdit && <PaymentModal open={paying} onClose={() => setPaying(false)} />}
      {canEdit && <ExpenseModal open={spending} onClose={() => setSpending(false)} />}
    </div>
  )
}

function Pager({ page, total, setPage }: { page: number; total: number; setPage: (n: number) => void }) {
  const pages = Math.max(1, Math.ceil(total / PAGE_SIZE))
  return (
    <div className="flex items-center justify-between border-t border-slate-100 px-4 py-3 text-sm">
      <span className="text-slate-500">{num(total)} rows · page {page + 1} of {pages}</span>
      <div className="flex gap-2">
        <Button variant="ghost" disabled={page === 0} onClick={() => setPage(page - 1)}>Previous</Button>
        <Button variant="ghost" disabled={page + 1 >= pages} onClick={() => setPage(page + 1)}>Next</Button>
      </div>
    </div>
  )
}

function PaymentsTable() {
  const [page, setPage] = useState(0)
  const [search, setSearch] = useState('')
  const q = useDebounce(search)
  const r = useQuery({ queryKey: ['payments', page, q], queryFn: () => listPayments(page, q), placeholderData: keepPreviousData })
  return (
    <Card bodyClass="p-0">
      <div className="border-b border-slate-100 p-4">
        <Input type="search" placeholder="Search student, ID or receipt" value={search} onChange={(e) => { setSearch(e.target.value); setPage(0) }} className="max-w-sm" />
      </div>
      {r.error ? <div className="p-4"><ErrorNotice error={r.error} /></div> : !r.data ? <Skeleton className="m-4 h-60" /> : r.data.rows.length === 0 ? <Empty>No payments.</Empty> : (
        <div className="overflow-x-auto">
          <table className="w-full min-w-[720px] text-left text-sm">
            <thead className="bg-slate-50/70 text-xs uppercase tracking-wide text-slate-500">
              <tr><th className="px-4 py-3">Receipt</th><th className="px-4 py-3">Student</th><th className="px-4 py-3">For</th><th className="px-4 py-3">Method</th><th className="px-4 py-3">Paid on</th><th className="px-4 py-3 text-right">Amount</th></tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {r.data.rows.map((p) => (
                <tr key={p.id} className={p.voided_at ? 'opacity-50 line-through' : ''}>
                  <td className="px-4 py-2.5 font-mono text-xs">{p.receipt_no}</td>
                  <td className="px-4 py-2.5"><p className="font-semibold">{p.student_name}</p><p className="text-xs text-slate-500">{p.student_code} · {p.section_name}</p></td>
                  <td className="px-4 py-2.5 text-slate-600">{p.period}</td>
                  <td className="px-4 py-2.5"><Badge tone={METHOD_TONE[p.method as keyof typeof METHOD_TONE]}>{titleCase(p.method)}</Badge>{p.reference_no && <div className="font-mono text-[11px] text-slate-400">{p.reference_no}</div>}</td>
                  <td className="px-4 py-2.5 text-slate-600">{date(p.paid_on)}</td>
                  <td className="px-4 py-2.5 text-right font-bold tabular-nums">{etb(p.amount)}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <Pager page={page} total={r.data.total} setPage={setPage} />
        </div>
      )}
    </Card>
  )
}

function InvoicesTable({ periods }: { periods: string[] }) {
  const [page, setPage] = useState(0)
  const [search, setSearch] = useState('')
  const [status, setStatus] = useState('')
  const [period, setPeriod] = useState('')
  const q = useDebounce(search)
  const r = useQuery({ queryKey: ['invoices', page, q, status, period], queryFn: () => listInvoices(page, q, status, period), placeholderData: keepPreviousData })
  return (
    <Card bodyClass="p-0">
      <div className="flex flex-col gap-3 border-b border-slate-100 p-4 sm:flex-row">
        <Input type="search" placeholder="Search student, ID or invoice" value={search} onChange={(e) => { setSearch(e.target.value); setPage(0) }} className="sm:max-w-sm" />
        <Select value={period} onChange={(e) => { setPeriod(e.target.value); setPage(0) }} className="sm:max-w-[12rem]">
          <option value="">All months</option>{periods.map((p) => <option key={p}>{p}</option>)}
        </Select>
        <Select value={status} onChange={(e) => { setStatus(e.target.value); setPage(0) }} className="sm:max-w-[10rem]">
          <option value="">Any status</option><option value="unpaid">Unpaid</option><option value="partial">Partial</option><option value="paid">Paid</option>
        </Select>
      </div>
      {r.error ? <div className="p-4"><ErrorNotice error={r.error} /></div> : !r.data ? <Skeleton className="m-4 h-60" /> : r.data.rows.length === 0 ? <Empty>No invoices match.</Empty> : (
        <div className="overflow-x-auto">
          <table className="w-full min-w-[760px] text-left text-sm">
            <thead className="bg-slate-50/70 text-xs uppercase tracking-wide text-slate-500">
              <tr><th className="px-4 py-3">Invoice</th><th className="px-4 py-3">Student</th><th className="px-4 py-3">For</th><th className="px-4 py-3">Due</th><th className="px-4 py-3 text-right">Amount</th><th className="px-4 py-3 text-right">Balance</th><th className="px-4 py-3">Status</th></tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {r.data.rows.map((i) => (
                <tr key={i.id}>
                  <td className="px-4 py-2.5 font-mono text-xs">{i.invoice_no}</td>
                  <td className="px-4 py-2.5"><p className="font-semibold">{i.student_name}</p><p className="text-xs text-slate-500">{i.student_code} · {i.section_name}</p></td>
                  <td className="px-4 py-2.5 text-slate-600">{i.period}</td>
                  <td className="px-4 py-2.5 text-slate-600">{date(i.due_date)}</td>
                  <td className="px-4 py-2.5 text-right tabular-nums">{etb(Number(i.total) - Number(i.discount))}</td>
                  <td className="px-4 py-2.5 text-right font-semibold tabular-nums">{Number(i.balance) > 0 ? <span className="text-rose-600">{etb(i.balance)}</span> : '—'}</td>
                  <td className="px-4 py-2.5"><Badge tone={STATUS_TONE[i.status as keyof typeof STATUS_TONE]}>{titleCase(i.status)}</Badge></td>
                </tr>
              ))}
            </tbody>
          </table>
          <Pager page={page} total={r.data.total} setPage={setPage} />
        </div>
      )}
    </Card>
  )
}

function ExpensesTable({ rows }: { rows: Pick<Tables<'expenses'>, 'id' | 'category' | 'description' | 'amount' | 'spent_on' | 'paid_to' | 'method'>[] }) {
  return (
    <Card bodyClass="p-0">
      {rows.length === 0 ? <Empty>No expenses yet.</Empty> : (
        <div className="overflow-x-auto">
          <table className="w-full min-w-[640px] text-left text-sm">
            <thead className="bg-slate-50/70 text-xs uppercase tracking-wide text-slate-500">
              <tr><th className="px-4 py-3">Date</th><th className="px-4 py-3">What</th><th className="px-4 py-3">Category</th><th className="px-4 py-3">Paid to</th><th className="px-4 py-3 text-right">Amount</th></tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {rows.map((e) => (
                <tr key={e.id}>
                  <td className="px-4 py-2.5 text-slate-600">{date(e.spent_on)}</td>
                  <td className="px-4 py-2.5 font-medium">{e.description}</td>
                  <td className="px-4 py-2.5"><Badge>{titleCase(e.category)}</Badge></td>
                  <td className="px-4 py-2.5 text-slate-600">{e.paid_to ?? '—'}</td>
                  <td className="px-4 py-2.5 text-right font-bold tabular-nums">{etb(e.amount)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </Card>
  )
}

function PaymentModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { schoolId } = useAuth()
  const qc = useQueryClient()
  const [search, setSearch] = useState('')
  const q = useDebounce(search)
  const found = useQuery({ queryKey: ['open_invoices', q], queryFn: () => findOpenInvoices(q), enabled: open && q.length >= 2 })
  const [invoiceId, setInvoiceId] = useState('')
  const [amount, setAmount] = useState('')
  const [method, setMethod] = useState<Tables<'payments'>['method']>('telebirr')
  const [ref, setRef] = useState('')
  const [done, setDone] = useState<string | null>(null)
  const invoice = found.data?.find((i) => i.id === invoiceId)
  const save = useMutation({
    mutationFn: () => recordPayment(schoolId!, { invoice_id: invoiceId, amount: Number(amount), method, reference_no: ref }),
    onSuccess: (r) => {
      setDone(r.receipt_no)
      for (const k of ['payments', 'invoices', 'finance_summary', 'dashboard', 'open_invoices', 'student_profile']) qc.invalidateQueries({ queryKey: [k] })
    },
  })
  function reset() { setSearch(''); setInvoiceId(''); setAmount(''); setRef(''); setDone(null); save.reset(); onClose() }
  function submit(e: FormEvent) { e.preventDefault(); save.mutate() }

  return (
    <Modal open={open} onClose={reset} title="Record a payment" wide>
      {done ? (
        <div className="py-6 text-center">
          <div className="mx-auto grid h-14 w-14 place-items-center rounded-full bg-emerald-100 text-emerald-600"><Icon name="check" className="h-7 w-7" /></div>
          <p className="mt-3 text-lg font-bold">Payment saved</p>
          <p className="text-slate-500">Receipt <span className="font-mono font-semibold text-slate-800">{done}</span></p>
          <Button className="mt-5" onClick={reset}>Done</Button>
        </div>
      ) : (
        <form onSubmit={submit} className="space-y-4">
          <Field label="Student" hint="Type a name or student ID, then pick the invoice">
            <Input type="search" value={search} onChange={(e) => { setSearch(e.target.value); setInvoiceId('') }} placeholder="e.g. Liya or AHS-19-0100" autoFocus />
          </Field>
          {q.length >= 2 && (
            <div className="scroll-thin max-h-56 overflow-y-auto rounded-xl border border-slate-200">
              {found.isLoading ? <p className="p-3 text-sm text-slate-500">Searching…</p> : !found.data?.length ? <p className="p-3 text-sm text-slate-500">No open invoices for that student.</p> : (
                found.data.map((i) => (
                  <label key={i.id} className={`flex cursor-pointer items-center gap-3 border-b border-slate-100 px-3 py-2 text-sm last:border-0 ${invoiceId === i.id ? 'bg-indigo-50' : 'hover:bg-slate-50'}`}>
                    <input type="radio" name="invoice" checked={invoiceId === i.id} onChange={() => { setInvoiceId(i.id!); setAmount(String(i.balance)) }} />
                    <span className="flex-1"><span className="font-semibold">{i.student_name}</span> <span className="text-slate-500">· {i.section_name} · {i.period}</span></span>
                    <span className="font-semibold text-rose-600 tabular-nums">{etb(i.balance)}</span>
                  </label>
                ))
              )}
            </div>
          )}
          <div className="grid gap-4 sm:grid-cols-3">
            <Field label="Amount (ETB)"><Input type="number" min="1" step="0.01" value={amount} onChange={(e) => setAmount(e.target.value)} required disabled={!invoice} /></Field>
            <Field label="Method">
              <Select value={method} onChange={(e) => setMethod(e.target.value as Tables<'payments'>['method'])}>
                <option value="telebirr">Telebirr</option><option value="bank">Bank</option><option value="cash">Cash</option>
              </Select>
            </Field>
            <Field label="Reference no."><Input value={ref} onChange={(e) => setRef(e.target.value)} placeholder={method === 'cash' ? 'optional' : 'Telebirr / bank slip'} /></Field>
          </div>
          {save.error && <Notice tone="error">{(save.error as Error).message}</Notice>}
          <div className="flex justify-end gap-2">
            <Button type="button" variant="ghost" onClick={reset}>Cancel</Button>
            <Button type="submit" disabled={!invoice || save.isPending}>{save.isPending ? 'Saving…' : 'Save payment'}</Button>
          </div>
        </form>
      )}
    </Modal>
  )
}

function ExpenseModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { schoolId } = useAuth()
  const qc = useQueryClient()
  const today = new Date().toISOString().slice(0, 10)
  const [f, setF] = useState({ category: 'supplies' as Tables<'expenses'>['category'], description: '', amount: '', spent_on: today, paid_to: '', method: 'bank' as Tables<'expenses'>['method'] })
  const save = useMutation({
    mutationFn: () => addExpense(schoolId!, { ...f, amount: Number(f.amount) }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['finance_summary'] }); qc.invalidateQueries({ queryKey: ['dashboard'] }); setF({ ...f, description: '', amount: '', paid_to: '' }); onClose() },
  })
  return (
    <Modal open={open} onClose={onClose} title="Add an expense">
      <form onSubmit={(e) => { e.preventDefault(); save.mutate() }} className="space-y-4">
        <Field label="What for"><Input value={f.description} onChange={(e) => setF({ ...f, description: e.target.value })} placeholder="e.g. Electricity — Hidar" required /></Field>
        <div className="grid grid-cols-2 gap-4">
          <Field label="Category">
            <Select value={f.category} onChange={(e) => setF({ ...f, category: e.target.value as Tables<'expenses'>['category'] })}>
              {['salary', 'utilities', 'supplies', 'maintenance', 'transport', 'food', 'rent', 'other'].map((c) => <option key={c} value={c}>{titleCase(c)}</option>)}
            </Select>
          </Field>
          <Field label="Amount (ETB)"><Input type="number" min="1" step="0.01" value={f.amount} onChange={(e) => setF({ ...f, amount: e.target.value })} required /></Field>
          <Field label="Date"><Input type="date" value={f.spent_on} onChange={(e) => setF({ ...f, spent_on: e.target.value })} required /></Field>
          <Field label="Paid by">
            <Select value={f.method} onChange={(e) => setF({ ...f, method: e.target.value as Tables<'expenses'>['method'] })}>
              <option value="bank">Bank</option><option value="telebirr">Telebirr</option><option value="cash">Cash</option>
            </Select>
          </Field>
        </div>
        <Field label="Paid to"><Input value={f.paid_to} onChange={(e) => setF({ ...f, paid_to: e.target.value })} placeholder="optional" /></Field>
        {save.error && <Notice tone="error">{(save.error as Error).message}</Notice>}
        <div className="flex justify-end gap-2">
          <Button type="button" variant="ghost" onClick={onClose}>Cancel</Button>
          <Button type="submit" disabled={save.isPending}>{save.isPending ? 'Saving…' : 'Save expense'}</Button>
        </div>
      </form>
    </Modal>
  )
}
