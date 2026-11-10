import { useState } from 'react'
import { Button, Input, Select } from '../../../components/ui/Field'
import { ErrorNotice, Notice } from '../../../components/ui/Notice'
import { Spinner } from '../../../components/ui/Spinner'
import { useDebounce } from '../../../hooks/useDebounce'
import { useGrades } from '../../setup/hooks'
import { PAGE_SIZE } from '../api'
import { useStudents } from '../hooks'

const STATUS_LABEL: Record<string, string> = {
  active: 'Active',
  transferred_out: 'Transferred',
  graduated: 'Graduated',
  dropped: 'Dropped',
}

export function StudentListPage() {
  const [search, setSearch] = useState('')
  const [gradeLevel, setGradeLevel] = useState<number | null>(null)
  const [page, setPage] = useState(0)
  const debounced = useDebounce(search)
  const grades = useGrades()
  const students = useStudents({ page, search: debounced, gradeLevel })

  const total = students.data?.total ?? 0
  const pages = Math.max(1, Math.ceil(total / PAGE_SIZE))

  return (
    <div className="space-y-5">
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold">Students</h1>
          <p className="mt-1 text-sm text-slate-500">{students.data ? `${total} students` : ' '}</p>
        </div>
      </div>

      <div className="flex flex-col gap-3 sm:flex-row">
        <Input
          type="search"
          placeholder="Search name or student ID"
          value={search}
          onChange={(e) => {
            setSearch(e.target.value)
            setPage(0)
          }}
          className="sm:max-w-xs"
          aria-label="Search students"
        />
        <Select
          value={gradeLevel ?? ''}
          onChange={(e) => {
            setGradeLevel(e.target.value ? Number(e.target.value) : null)
            setPage(0)
          }}
          className="sm:max-w-[10rem]"
          aria-label="Grade"
        >
          <option value="">All grades</option>
          {grades.data?.map((g) => (
            <option key={g.id} value={g.level}>
              {g.name}
            </option>
          ))}
        </Select>
      </div>

      {students.isLoading ? (
        <Spinner full />
      ) : students.error ? (
        <ErrorNotice error={students.error} />
      ) : !students.data?.rows.length ? (
        <Notice>{debounced || gradeLevel ? 'No students match.' : 'No students yet.'}</Notice>
      ) : (
        <>
          {/* Table on wide screens */}
          <div className="hidden overflow-hidden rounded-xl border border-slate-200 bg-white md:block">
            <table className="w-full text-left text-sm">
              <thead className="bg-slate-50 text-xs uppercase tracking-wide text-slate-500">
                <tr>
                  <th className="px-4 py-3 font-semibold">Student ID</th>
                  <th className="px-4 py-3 font-semibold">Name</th>
                  <th className="px-4 py-3 font-semibold">Sex</th>
                  <th className="px-4 py-3 font-semibold">Grade</th>
                  <th className="px-4 py-3 font-semibold">Section</th>
                  <th className="px-4 py-3 font-semibold">Status</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100">
                {students.data.rows.map((s) => (
                  <tr key={s.id}>
                    <td className="px-4 py-3 font-mono text-xs">{s.student_code}</td>
                    <td className="px-4 py-3 font-medium">{s.full_name}</td>
                    <td className="px-4 py-3">{s.gender}</td>
                    <td className="px-4 py-3">{s.grade_level ?? '—'}</td>
                    <td className="px-4 py-3">
                      {s.section_name ?? <span className="text-slate-400">Not placed</span>}
                      {s.stream && <span className="ml-1 text-xs capitalize text-slate-500">({s.stream})</span>}
                    </td>
                    <td className="px-4 py-3">{STATUS_LABEL[s.status ?? ''] ?? s.status}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* Cards on phones */}
          <ul className="space-y-2 md:hidden">
            {students.data.rows.map((s) => (
              <li key={s.id} className="rounded-xl border border-slate-200 bg-white p-3">
                <div className="flex items-baseline justify-between gap-2">
                  <span className="font-medium">{s.full_name}</span>
                  <span className="font-mono text-xs text-slate-500">{s.student_code}</span>
                </div>
                <p className="mt-1 text-sm text-slate-600">
                  Grade {s.grade_level ?? '—'} · {s.section_name ?? 'Not placed'}
                  {s.stream ? ` · ${s.stream}` : ''} · {STATUS_LABEL[s.status ?? ''] ?? s.status}
                </p>
              </li>
            ))}
          </ul>

          <div className="flex items-center justify-between text-sm">
            <span className="text-slate-500">
              Page {page + 1} of {pages}
            </span>
            <div className="flex gap-2">
              <Button variant="ghost" disabled={page === 0} onClick={() => setPage((p) => p - 1)}>
                Previous
              </Button>
              <Button variant="ghost" disabled={page + 1 >= pages} onClick={() => setPage((p) => p + 1)}>
                Next
              </Button>
            </div>
          </div>
        </>
      )}
    </div>
  )
}
