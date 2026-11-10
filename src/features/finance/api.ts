import { supabase, type Tables } from '../../lib/supabase'

export const PAGE_SIZE = 20

function clean(q: string) {
  return q.replace(/[,()%*\\]/g, ' ').trim()
}

export async function getFinanceSummary() {
  const [months, periods, expenses] = await Promise.all([
    supabase.from('v_monthly_finance').select('month, revenue, expenses, net').order('month'),
    supabase.from('v_invoice_periods').select('*').order('period_start'),
    supabase.from('expenses').select('id, category, description, amount, spent_on, paid_to, method').order('spent_on', { ascending: false }),
  ])
  for (const r of [months, periods, expenses]) if (r.error) throw r.error
  return { months: months.data ?? [], periods: periods.data ?? [], expenses: expenses.data ?? [] }
}

export async function listPayments(page: number, search: string) {
  let q = supabase.from('v_payment_details')
    .select('id, receipt_no, amount, method, reference_no, paid_on, voided_at, period, student_name, student_code, grade_name, section_name', { count: 'exact' })
    .order('paid_on', { ascending: false }).order('receipt_no', { ascending: false })
    .range(page * PAGE_SIZE, page * PAGE_SIZE + PAGE_SIZE - 1)
  const s = clean(search)
  if (s) q = q.or(`student_name.ilike.%${s}%,student_code.ilike.%${s}%,receipt_no.ilike.%${s}%`)
  const { data, error, count } = await q
  if (error) throw error
  return { rows: data ?? [], total: count ?? 0 }
}

export async function listInvoices(page: number, search: string, status: string, period: string) {
  let q = supabase.from('v_invoice_details')
    .select('id, invoice_no, period, due_date, total, discount, paid, balance, status, student_name, student_code, grade_name, section_name', { count: 'exact' })
    .order('period_start', { ascending: false }).order('student_name')
    .range(page * PAGE_SIZE, page * PAGE_SIZE + PAGE_SIZE - 1)
  const s = clean(search)
  if (s) q = q.or(`student_name.ilike.%${s}%,student_code.ilike.%${s}%,invoice_no.ilike.%${s}%`)
  if (status) q = q.eq('status', status as Tables<'invoices'>['status'])
  if (period) q = q.eq('period', period)
  const { data, error, count } = await q
  if (error) throw error
  return { rows: data ?? [], total: count ?? 0 }
}

/** Open invoices of students matching a name or ID (for "Record payment"). */
export async function findOpenInvoices(search: string) {
  const s = clean(search)
  if (s.length < 2) return []
  const { data, error } = await supabase.from('v_invoice_details')
    .select('id, invoice_no, period, balance, status, student_name, student_code, grade_name, section_name')
    .in('status', ['unpaid', 'partial'])
    .or(`student_name.ilike.%${s}%,student_code.ilike.%${s}%`)
    .order('student_name').order('period_start').limit(20)
  if (error) throw error
  return data ?? []
}

export async function recordPayment(schoolId: string, p: { invoice_id: string; amount: number; method: Tables<'payments'>['method']; reference_no: string }) {
  const { data, error } = await supabase.from('payments').insert({
    school_id: schoolId, receipt_no: '', invoice_id: p.invoice_id, amount: p.amount, method: p.method,
    reference_no: p.reference_no.trim() || null,
  }).select('receipt_no').single()
  if (error) throw error
  return data
}

export async function addExpense(schoolId: string, e: { category: Tables<'expenses'>['category']; description: string; amount: number; spent_on: string; paid_to: string; method: Tables<'expenses'>['method'] }) {
  const { error } = await supabase.from('expenses').insert({ school_id: schoolId, ...e, paid_to: e.paid_to.trim() || null })
  if (error) throw error
}
