import { useState, type FormEvent } from 'react'
import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Badge, Card, Empty, KpiCard, PageHeader, Skeleton } from '../../../components/ui/Card'
import { Button, Field, Input, Select } from '../../../components/ui/Field'
import { Modal } from '../../../components/ui/Modal'
import { ErrorNotice, Notice } from '../../../components/ui/Notice'
import { Icon } from '../../../components/ui/icons'
import { useDebounce } from '../../../hooks/useDebounce'
import { date, etb, FINE_KIND_LABEL, num, titleCase } from '../../../lib/format'
import { supabase, type Tables } from '../../../lib/supabase'
import { useAuth } from '../../auth/AuthProvider'

type Kind = Tables<'fines'>['kind']
type Status = Tables<'fines'>['status']
const PAGE = 20
const KIND_TONE: Record<Kind, 'red' | 'purple' | 'amber' | 'blue' | 'slate'> = {
  late_payment: 'amber', discipline: 'purple', damage: 'red', lost_item: 'blue', other: 'slate',
}
const STATUS_TONE: Record<Status, 'red' | 'green' | 'slate'> = { open: 'red', paid: 'green', waived: 'slate' }
const clean = (q: string) => q.replace(/[,()%*\\]/g, ' ').trim()

async function getFineStats() {
  const { data, error } = await supabase.from('fines').select('kind, status, amount')
  if (error) throw error
  const open = data.filter((f) => f.status === 'open')
  return {
    open: open.length,
    openAmount: open.reduce((t, f) => t + Number(f.amount), 0),
    discipline: data.filter((f) => f.kind === 'discipline').length,
    paidAmount: data.filter((f) => f.status === 'paid').reduce((t, f) => t + Number(f.amount), 0),
    byKind: Object.keys(FINE_KIND_LABEL).map((k) => ({ kind: k as Kind, count: data.filter((f) => f.kind === k).length })),
  }
}

async function listFines(page: number, kind: string, status: string, search: string) {
  let q = supabase.from('v_fine_details')
    .select('id, kind, reason, amount, issued_on, status, student_name, student_code, section_name', { count: 'exact' })
    .order('issued_on', { ascending: false })
    .range(page * PAGE, page * PAGE + PAGE - 1)
  if (kind) q = q.eq('kind', kind as Kind)
  if (status) q = q.eq('status', status as Status)
  const s = clean(search)
  if (s) q = q.or(`student_name.ilike.%${s}%,student_code.ilike.%${s}%,reason.ilike.%${s}%`)
  const { data, error, count } = await q
  if (error) throw error
  return { rows: data ?? [], total: count ?? 0 }
}

export function FinesPage() {
  const { schoolId, hasAnyRole } = useAuth()
  const canResolve = hasAnyRole('super_admin', 'registrar', 'finance')
  const qc = useQueryClient()
  const [kind, setKind] = useState('')
  const [status, setStatus] = useState('')
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(0)
  const [adding, setAdding] = useState(false)
  const q = useDebounce(search)
  const stats = useQuery({ queryKey: ['fine_stats', schoolId], queryFn: getFineStats })
  const list = useQuery({ queryKey: ['fines', page, kind, status, q], queryFn: () => listFines(page, kind, status, q), placeholderData: keepPreviousData })
  const resolve = useMutation({
    mutationFn: async ({ id, to }: { id: string; to: Status }) => {
      const { error } = await supabase.from('fines').update({ status: to, resolved_on: new Date().toISOString().slice(0, 10) }).eq('id', id)
      if (error) throw error
    },
    onSuccess: () => { for (const k of ['fines', 'fine_stats', 'dashboard', 'student_profile']) qc.invalidateQueries({ queryKey: [k] }) },
  })
  const pages = Math.max(1, Math.ceil((list.data?.total ?? 0) / PAGE))

  return (
    <div>
      <PageHeader title="Fines & discipline · ቅጣት" subtitle="Late-payment fines, discipline cases, damage and lost items"
        actions={<Button onClick={() => setAdding(true)}><Icon name="plus" className="h-4 w-4" /> Add fine</Button>} />

      <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        <KpiCard tone="rose" label="Open" value={stats.data?.open ?? null} icon={<Icon name="fines" />} sub="Not yet paid or closed" />
        <KpiCard tone="orange" delay={60} label="Open amount" value={stats.data?.openAmount ?? null} format={(n) => etb(n)} icon={<Icon name="wallet" />} sub="Money still owed" />
        <KpiCard tone="purple" delay={120} label="Discipline cases" value={stats.data?.discipline ?? null} icon={<Icon name="shield" />} sub="This year" />
        <KpiCard tone="green" delay={180} label="Fines paid" value={stats.data?.paidAmount ?? null} format={(n) => etb(n)} icon={<Icon name="check" />} sub="Collected" />
      </div>

      <Card className="mt-5" bodyClass="p-0" delay={200}>
        <div className="flex flex-col gap-3 border-b border-slate-100 p-4">
          <div className="flex flex-wrap gap-2">
            <button onClick={() => { setKind(''); setPage(0) }} className={`rounded-full px-3.5 py-1.5 text-sm font-semibold ${kind === '' ? 'bg-indigo-600 text-white' : 'bg-slate-100 text-slate-600'}`}>All</button>
            {stats.data?.byKind.map((k) => (
              <button key={k.kind} onClick={() => { setKind(k.kind); setPage(0) }}
                className={`rounded-full px-3.5 py-1.5 text-sm font-semibold ${kind === k.kind ? 'bg-indigo-600 text-white' : 'bg-slate-100 text-slate-600'}`}>
                {FINE_KIND_LABEL[k.kind]} <span className="opacity-70">{k.count}</span>
              </button>
            ))}
          </div>
          <div className="flex flex-col gap-3 sm:flex-row">
            <Input type="search" placeholder="Search student or reason" value={search} onChange={(e) => { setSearch(e.target.value); setPage(0) }} className="sm:max-w-sm" />
            <Select value={status} onChange={(e) => { setStatus(e.target.value); setPage(0) }} className="sm:max-w-[10rem]">
              <option value="">Any status</option><option value="open">Open</option><option value="paid">Paid</option><option value="waived">Waived</option>
            </Select>
          </div>
        </div>
        {list.error ? <div className="p-4"><ErrorNotice error={list.error} /></div> : !list.data ? <Skeleton className="m-4 h-60" /> : list.data.rows.length === 0 ? <Empty>No fines match.</Empty> : (
          <>
            <ul className="divide-y divide-slate-100">
              {list.data.rows.map((f) => (
                <li key={f.id} className="flex flex-wrap items-center gap-3 px-4 py-3">
                  <div className={`grid h-10 w-10 shrink-0 place-items-center rounded-xl ${f.kind === 'discipline' ? 'bg-violet-100 text-violet-600' : f.kind === 'late_payment' ? 'bg-amber-100 text-amber-600' : 'bg-rose-100 text-rose-600'}`}>
                    <Icon name={f.kind === 'discipline' ? 'shield' : f.kind === 'late_payment' ? 'clock' : 'fines'} />
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="font-semibold">{f.student_name} <span className="font-normal text-slate-500">· {f.student_code}{f.section_name ? ` · ${f.section_name}` : ''}</span></p>
                    <p className="truncate text-sm text-slate-600">{f.reason}</p>
                  </div>
                  <Badge tone={KIND_TONE[f.kind as Kind]}>{FINE_KIND_LABEL[f.kind!]}</Badge>
                  <span className="w-24 text-right text-sm text-slate-500">{date(f.issued_on)}</span>
                  <span className="w-24 text-right font-bold tabular-nums">{Number(f.amount) > 0 ? etb(f.amount) : '—'}</span>
                  <Badge tone={STATUS_TONE[f.status as Status]}>{titleCase(f.status)}</Badge>
                  {canResolve && f.status === 'open' && (
                    <div className="flex gap-1">
                      {Number(f.amount) > 0 && <Button variant="ghost" className="!px-2.5 !py-1 text-xs" disabled={resolve.isPending} onClick={() => resolve.mutate({ id: f.id!, to: 'paid' })}>Mark paid</Button>}
                      <Button variant="ghost" className="!px-2.5 !py-1 text-xs" disabled={resolve.isPending} onClick={() => resolve.mutate({ id: f.id!, to: 'waived' })}>{Number(f.amount) > 0 ? 'Waive' : 'Close'}</Button>
                    </div>
                  )}
                </li>
              ))}
            </ul>
            <div className="flex items-center justify-between border-t border-slate-100 px-4 py-3 text-sm">
              <span className="text-slate-500">{num(list.data.total)} records · page {page + 1} of {pages}</span>
              <div className="flex gap-2">
                <Button variant="ghost" disabled={page === 0} onClick={() => setPage(page - 1)}>Previous</Button>
                <Button variant="ghost" disabled={page + 1 >= pages} onClick={() => setPage(page + 1)}>Next</Button>
              </div>
            </div>
          </>
        )}
      </Card>

      <AddFineModal open={adding} onClose={() => setAdding(false)} />
    </div>
  )
}

function AddFineModal({ open, onClose }: { open: boolean; onClose: () => void }) {
  const { schoolId } = useAuth()
  const qc = useQueryClient()
  const [search, setSearch] = useState('')
  const q = useDebounce(search)
  const found = useQuery({
    queryKey: ['fine_student_search', q], enabled: open && clean(q).length >= 2,
    queryFn: async () => {
      const s = clean(q)
      const { data, error } = await supabase.from('v_students_current').select('id, full_name, student_code, section_name')
        .or(`full_name.ilike.%${s}%,student_code.ilike.%${s}%`).is('deleted_at', null).limit(8)
      if (error) throw error
      return data
    },
  })
  const [studentId, setStudentId] = useState('')
  const [kind, setKind] = useState<Kind>('discipline')
  const [reason, setReason] = useState('')
  const [amount, setAmount] = useState('0')
  const save = useMutation({
    mutationFn: async () => {
      const { error } = await supabase.from('fines').insert({ school_id: schoolId!, student_id: studentId, kind, reason: reason.trim(), amount: Number(amount || 0) })
      if (error) throw error
    },
    onSuccess: () => { for (const k of ['fines', 'fine_stats', 'dashboard', 'student_profile']) qc.invalidateQueries({ queryKey: [k] }); setSearch(''); setStudentId(''); setReason(''); setAmount('0'); onClose() },
  })
  function submit(e: FormEvent) { e.preventDefault(); save.mutate() }

  return (
    <Modal open={open} onClose={onClose} title="Add a fine or discipline record">
      <form onSubmit={submit} className="space-y-4">
        <Field label="Student"><Input type="search" value={search} onChange={(e) => { setSearch(e.target.value); setStudentId('') }} placeholder="Name or student ID" autoFocus /></Field>
        {clean(q).length >= 2 && (
          <div className="scroll-thin max-h-44 overflow-y-auto rounded-xl border border-slate-200">
            {!found.data?.length ? <p className="p-3 text-sm text-slate-500">{found.isLoading ? 'Searching…' : 'No student found (teachers see only their own students).'}</p> : found.data.map((s) => (
              <label key={s.id} className={`flex cursor-pointer items-center gap-3 border-b border-slate-100 px-3 py-2 text-sm last:border-0 ${studentId === s.id ? 'bg-indigo-50' : 'hover:bg-slate-50'}`}>
                <input type="radio" name="student" checked={studentId === s.id} onChange={() => setStudentId(s.id!)} />
                <span className="font-semibold">{s.full_name}</span><span className="text-slate-500">{s.student_code} · {s.section_name}</span>
              </label>
            ))}
          </div>
        )}
        <div className="grid grid-cols-2 gap-4">
          <Field label="Kind">
            <Select value={kind} onChange={(e) => { const k = e.target.value as Kind; setKind(k); if (k === 'discipline') setAmount('0') }}>
              {Object.entries(FINE_KIND_LABEL).map(([k, v]) => <option key={k} value={k}>{v}</option>)}
            </Select>
          </Field>
          <Field label="Amount (ETB)" hint="0 = discipline record only"><Input type="number" min="0" step="1" value={amount} onChange={(e) => setAmount(e.target.value)} /></Field>
        </div>
        <Field label="Reason"><Input value={reason} onChange={(e) => setReason(e.target.value)} placeholder="e.g. Late to class many times" required /></Field>
        {save.error && <Notice tone="error">{(save.error as Error).message}</Notice>}
        <div className="flex justify-end gap-2">
          <Button type="button" variant="ghost" onClick={onClose}>Cancel</Button>
          <Button type="submit" disabled={!studentId || save.isPending}>{save.isPending ? 'Saving…' : 'Save'}</Button>
        </div>
      </form>
    </Modal>
  )
}
