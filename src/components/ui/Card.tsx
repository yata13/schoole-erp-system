import { useEffect, useRef, useState, type ReactNode } from 'react'

/** White panel with an optional title row. `delay` staggers the entrance animation (ms). */
export function Card({
  title, subtitle, action, children, className = '', delay = 0, bodyClass = 'p-5',
}: {
  title?: ReactNode
  subtitle?: ReactNode
  action?: ReactNode
  children: ReactNode
  className?: string
  delay?: number
  bodyClass?: string
}) {
  return (
    <section
      className={`rise rounded-2xl border border-slate-200/70 bg-white shadow-[0_1px_2px_rgba(16,24,40,0.04),0_8px_24px_-12px_rgba(16,24,40,0.12)] ${className}`}
      style={{ animationDelay: `${delay}ms` }}
    >
      {(title || action) && (
        <header className="flex items-start justify-between gap-3 px-5 pt-4">
          <div>
            {title && <h2 className="text-[13px] font-bold uppercase tracking-wide text-slate-700">{title}</h2>}
            {subtitle && <p className="mt-0.5 text-xs text-slate-500">{subtitle}</p>}
          </div>
          {action}
        </header>
      )}
      <div className={bodyClass}>{children}</div>
    </section>
  )
}

/** Animated number that counts up when it first appears. */
export function CountUp({ value, format = (n: number) => Math.round(n).toLocaleString('en-US'), ms = 900 }: {
  value: number
  format?: (n: number) => string
  ms?: number
}) {
  const [shown, setShown] = useState(0)
  const from = useRef(0)
  useEffect(() => {
    const start = performance.now()
    const begin = from.current
    let raf = 0
    const tick = (t: number) => {
      const k = Math.min(1, (t - start) / ms)
      const eased = 1 - Math.pow(1 - k, 3)
      setShown(begin + (value - begin) * eased)
      if (k < 1) raf = requestAnimationFrame(tick)
      else from.current = value
    }
    raf = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(raf)
  }, [value, ms])
  return <>{format(shown)}</>
}

const GRADIENTS = {
  blue:   'from-[#3b82f6] to-[#2563eb]',
  green:  'from-[#22c55e] to-[#15803d]',
  purple: 'from-[#8b5cf6] to-[#6d28d9]',
  orange: 'from-[#fb923c] to-[#ea580c]',
  teal:   'from-[#14b8a6] to-[#0e7490]',
  rose:   'from-[#f43f5e] to-[#be123c]',
  indigo: 'from-[#6366f1] to-[#4338ca]',
  amber:  'from-[#f59e0b] to-[#b45309]',
} as const
export type Tone = keyof typeof GRADIENTS

/** Colourful KPI tile like the reference dashboards. */
export function KpiCard({
  label, value, format, sub, icon, tone = 'blue', delay = 0,
}: {
  label: string
  value: number | null | undefined
  format?: (n: number) => string
  sub?: ReactNode
  icon: ReactNode
  tone?: Tone
  delay?: number
}) {
  return (
    <div
      className={`rise relative overflow-hidden rounded-2xl bg-gradient-to-br ${GRADIENTS[tone]} p-4 text-white shadow-lg shadow-slate-900/10`}
      style={{ animationDelay: `${delay}ms` }}
    >
      <div className="absolute -right-6 -top-6 h-24 w-24 rounded-full bg-white/10" aria-hidden="true" />
      <div className="absolute -bottom-8 right-6 h-20 w-20 rounded-full bg-white/10" aria-hidden="true" />
      <div className="relative flex items-start gap-3">
        <div className="grid h-11 w-11 shrink-0 place-items-center rounded-full bg-white/95 text-slate-800 shadow-sm">
          {icon}
        </div>
        <div className="min-w-0">
          <p className="text-[11px] font-semibold uppercase leading-tight tracking-wider text-white/85">{label}</p>
          <p className="mt-0.5 text-2xl font-extrabold tabular-nums leading-tight">
            {value == null ? '—' : <CountUp value={value} format={format} />}
          </p>
          {sub && <p className="mt-0.5 text-xs leading-snug text-white/85">{sub}</p>}
        </div>
      </div>
    </div>
  )
}

export function Badge({ children, tone = 'slate' }: { children: ReactNode; tone?: 'slate' | 'green' | 'red' | 'amber' | 'blue' | 'purple' }) {
  const t = {
    slate: 'bg-slate-100 text-slate-700',
    green: 'bg-emerald-50 text-emerald-700 ring-emerald-600/20',
    red: 'bg-rose-50 text-rose-700 ring-rose-600/20',
    amber: 'bg-amber-50 text-amber-800 ring-amber-600/20',
    blue: 'bg-blue-50 text-blue-700 ring-blue-600/20',
    purple: 'bg-violet-50 text-violet-700 ring-violet-600/20',
  }[tone]
  return <span className={`inline-flex items-center whitespace-nowrap rounded-full px-2 py-0.5 text-xs font-semibold ring-1 ring-inset ring-transparent ${t}`}>{children}</span>
}

export function ProgressBar({ value, tone = 'bg-indigo-500', className = '' }: { value: number; tone?: string; className?: string }) {
  const v = Math.max(0, Math.min(100, value))
  return (
    <div className={`h-2 w-full overflow-hidden rounded-full bg-slate-100 ${className}`}>
      <div className={`grow h-2 rounded-full ${tone}`} style={{ width: `${v}%` }} />
    </div>
  )
}

export function Avatar({ name, tone = 'bg-indigo-100 text-indigo-700' }: { name: string; tone?: string }) {
  const parts = name.trim().split(/\s+/)
  const ini = ((parts[0]?.[0] ?? '') + (parts[1]?.[0] ?? '')).toUpperCase()
  return <span className={`grid h-9 w-9 shrink-0 place-items-center rounded-full text-xs font-bold ${tone}`}>{ini}</span>
}

export function PageHeader({ title, subtitle, actions }: { title: string; subtitle?: ReactNode; actions?: ReactNode }) {
  return (
    <div className="rise mb-6 flex flex-wrap items-end justify-between gap-3">
      <div>
        <h1 className="text-2xl font-extrabold tracking-tight text-slate-900 md:text-[28px]">{title}</h1>
        {subtitle && <p className="mt-1 text-sm text-slate-500">{subtitle}</p>}
      </div>
      {actions && <div className="flex flex-wrap gap-2">{actions}</div>}
    </div>
  )
}

export function Skeleton({ className = '' }: { className?: string }) {
  return <div className={`skeleton rounded-xl ${className}`} />
}

export function Empty({ children }: { children: ReactNode }) {
  return <p className="py-8 text-center text-sm text-slate-500">{children}</p>
}
