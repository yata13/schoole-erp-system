import { useQuery } from '@tanstack/react-query'
import { useAuth } from '../auth/AuthProvider'
import { getLookups, getMyTeaching } from './api'

export function useLookups() {
  const { schoolId } = useAuth()
  return useQuery({ queryKey: ['lookups', schoolId], queryFn: getLookups, enabled: !!schoolId, staleTime: 10 * 60 * 1000 })
}

export function useMyTeaching() {
  const { userId, hasAnyRole } = useAuth()
  return useQuery({
    queryKey: ['my_teaching', userId],
    queryFn: getMyTeaching,
    enabled: !!userId && hasAnyRole('teacher'),
    staleTime: 10 * 60 * 1000,
  })
}

export function staffName(s: { first_name: string; father_name: string } | undefined | null) {
  return s ? `${s.first_name} ${s.father_name}` : '—'
}
