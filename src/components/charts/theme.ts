// Chart colours (match the KPI tiles) and shared axis/tooltip styling.
export const C = {
  blue: '#3b82f6',
  indigo: '#6366f1',
  violet: '#8b5cf6',
  green: '#22c55e',
  emerald: '#10b981',
  orange: '#f97316',
  amber: '#f59e0b',
  rose: '#f43f5e',
  teal: '#14b8a6',
  sky: '#0ea5e9',
  slate: '#94a3b8',
}

export const SERIES = [C.indigo, C.green, C.orange, C.rose, C.teal, C.violet, C.amber, C.sky, C.blue, C.emerald, C.slate]

export const axis = { fontSize: 11, fill: '#64748b' }
export const grid = '#eef2f7'

export const tooltipStyle = {
  contentStyle: { borderRadius: 12, border: '1px solid #e2e8f0', boxShadow: '0 10px 30px -10px rgba(15,23,42,.25)', fontSize: 12 },
  labelStyle: { fontWeight: 700, color: '#0f172a' },
}
