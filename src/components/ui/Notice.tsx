import type { ReactNode } from 'react'

const tones = {
  info: 'border-blue-200 bg-blue-50 text-blue-900',
  warn: 'border-amber-200 bg-amber-50 text-amber-900',
  error: 'border-red-200 bg-red-50 text-red-900',
}

export function Notice({
  tone = 'info',
  title,
  children,
}: {
  tone?: keyof typeof tones
  title?: string
  children?: ReactNode
}) {
  return (
    <div role={tone === 'error' ? 'alert' : undefined} className={`rounded-lg border p-4 text-sm ${tones[tone]}`}>
      {title && <p className="font-semibold">{title}</p>}
      {children && <div className={title ? 'mt-1' : ''}>{children}</div>}
    </div>
  )
}

export function ErrorNotice({ error }: { error: unknown }) {
  const message = error instanceof Error ? error.message : String(error)
  return <Notice tone="error" title="Something went wrong">{message}</Notice>
}
