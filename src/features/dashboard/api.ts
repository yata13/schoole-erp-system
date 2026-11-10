import { supabase } from '../../lib/supabase'

export type DashboardData = {
  year: string | null
  semester: number | null
  students: {
    total: number; male: number; female: number
    by_grade: { grade: string; level: number; stage: string; students: number; male: number; female: number }[]
  }
  seats: { sections: number; capacity: number; placed: number } | null
  staff: { total: number; monthly_payroll: number; by_position: { position: string; count: number }[] }
  finance: {
    this_month: { revenue: number; expenses: number } | null
    monthly: { month: string; revenue: number; expenses: number; net: number }[]
    fees: { paid: number; partial: number; unpaid: number; billed: number; collected: number; outstanding: number } | null
  }
  attendance: {
    days: { date: string; present: number; absent: number; late: number; excused: number; rate: number }[]
    latest: { date: string; present: number; absent: number; late: number; excused: number; rate: number } | null
  }
  results: {
    top: { name: string; grade: string; section: string; average: number }[]
    by_grade: { grade: string; level: number; average: number }[]
  }
  fines: { open: number; open_amount: number; discipline: number; total: number } | null
  recent_payments: { receipt_no: string; amount: number; method: string; paid_on: string; period: string; student_name: string }[]
}

export async function getDashboard(): Promise<DashboardData> {
  const { data, error } = await supabase.rpc('dashboard_overview')
  if (error) throw error
  return data as unknown as DashboardData
}
