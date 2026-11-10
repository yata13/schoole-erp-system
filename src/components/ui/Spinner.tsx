export function Spinner({ full = false }: { full?: boolean }) {
  const dot = (
    <span
      role="status"
      aria-label="Loading"
      className="inline-block h-6 w-6 animate-spin rounded-full border-2 border-slate-300 border-t-blue-700"
    />
  )
  return full ? <div className="flex h-full min-h-[50vh] items-center justify-center">{dot}</div> : dot
}
