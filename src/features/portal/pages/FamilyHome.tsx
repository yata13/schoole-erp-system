import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { PageHeader, Skeleton } from '../../../components/ui/Card'
import { ErrorNotice, Notice } from '../../../components/ui/Notice'
import { supabase } from '../../../lib/supabase'
import { useAuth } from '../../auth/AuthProvider'
import { useMyProfile } from '../../auth/hooks'
import { StudentProfileView } from '../../students/components/StudentProfileView'

async function getMyChildren() {
  const { data, error } = await supabase
    .from('v_students_current')
    .select('id, full_name, grade_level, section_name')
    .is('deleted_at', null)
    .order('full_name')
  if (error) throw error
  return data
}

/** Students see themselves; parents see each of their children. RLS returns only those rows. */
export function FamilyHome() {
  const { userId, hasAnyRole } = useAuth()
  const profile = useMyProfile()
  const kids = useQuery({ queryKey: ['my_children', userId], queryFn: getMyChildren })
  const [pick, setPick] = useState<string | null>(null)

  if (kids.error) return <ErrorNotice error={kids.error} />
  if (!kids.data) return <Skeleton className="h-64" />
  if (kids.data.length === 0) return <Notice tone="warn" title="No student linked">Ask the school office to link your account to a student.</Notice>

  const isParent = hasAnyRole('parent')
  const current = pick ?? kids.data[0].id

  return (
    <div>
      <PageHeader
        title={isParent ? `Welcome, ${profile.data?.full_name ?? ''}` : 'My school'}
        subtitle={isParent ? 'Grades, attendance, fees and fines for your children' : 'Your grades, attendance, fees and fines'}
      />
      {kids.data.length > 1 && (
        <div className="rise mb-5 flex flex-wrap gap-2">
          {kids.data.map((k) => (
            <button key={k.id ?? ''} onClick={() => setPick(k.id)}
              className={`rounded-xl px-4 py-2 text-sm font-semibold shadow-sm ${current === k.id ? 'bg-indigo-600 text-white' : 'bg-white text-slate-700 ring-1 ring-slate-200'}`}>
              {k.full_name} <span className="opacity-70">· {k.section_name}</span>
            </button>
          ))}
        </div>
      )}
      {current && <StudentProfileView studentId={current} />}
    </div>
  )
}
