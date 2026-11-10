// Formatting helpers: money in ETB, numbers, dates, and labels.

const nf = new Intl.NumberFormat('en-US')
const nf1 = new Intl.NumberFormat('en-US', { maximumFractionDigits: 1 })

export function num(n: number | string | null | undefined): string {
  return n == null || n === '' ? '—' : nf.format(Number(n))
}

export function pct(n: number | string | null | undefined): string {
  return n == null || n === '' ? '—' : `${nf1.format(Number(n))}%`
}

export function etb(n: number | string | null | undefined): string {
  return n == null || n === '' ? '—' : `${nf.format(Math.round(Number(n)))} ETB`
}

/** 1.25M, 480K: short money for cards and chart axes. */
export function etbShort(n: number | string | null | undefined): string {
  if (n == null || n === '') return '—'
  const v = Number(n)
  if (Math.abs(v) >= 1_000_000) return `${nf1.format(v / 1_000_000)}M`
  if (Math.abs(v) >= 1_000) return `${nf1.format(v / 1_000)}K`
  return nf.format(v)
}

export function date(d: string | null | undefined): string {
  if (!d) return '—'
  return new Date(d + (d.length === 10 ? 'T00:00:00' : '')).toLocaleDateString('en-GB', {
    day: 'numeric', month: 'short', year: 'numeric',
  })
}

export function shortDate(d: string): string {
  return new Date(d + 'T00:00:00').toLocaleDateString('en-GB', { day: 'numeric', month: 'short' })
}

// Gregorian month (YYYY-MM) -> the Ethiopian month that mostly covers it.
const EC_BY_GREG_MONTH = ['Tir', 'Yekatit', 'Megabit', 'Miyazya', 'Ginbot', 'Sene',
  'Hamle', 'Nehase', 'Meskerem', 'Tikimt', 'Hidar', 'Tahsas']
export function monthLabel(ym: string): string {
  const [y, m] = ym.split('-').map(Number)
  const g = new Date(y, m - 1, 1).toLocaleDateString('en-GB', { month: 'short' })
  return `${g} · ${EC_BY_GREG_MONTH[m - 1]}`
}

export function titleCase(s: string | null | undefined): string {
  if (!s) return ''
  return s.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase())
}

export function initials(name: string | null | undefined): string {
  if (!name) return '?'
  const parts = name.trim().split(/\s+/)
  return ((parts[0]?.[0] ?? '') + (parts[1]?.[0] ?? '')).toUpperCase()
}

export const POSITION_LABEL: Record<string, string> = {
  director: 'Director', registrar: 'Registrar', teacher: 'Teacher', cashier: 'Cashier',
  librarian: 'Librarian', accountant: 'Accountant', cleaner: 'Cleaner', guard: 'Guard',
  driver: 'Driver', cook: 'Cook', nurse: 'Nurse', other: 'Other',
}

export const FINE_KIND_LABEL: Record<string, string> = {
  late_payment: 'Late payment', discipline: 'Discipline', damage: 'Damage', lost_item: 'Lost item', other: 'Other',
}
