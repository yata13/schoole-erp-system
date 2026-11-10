import { keepPreviousData, useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useAuth } from '../auth/AuthProvider'
import { useLookups } from '../school/hooks'
import { addStudent, getStudentProfile, listStudents, type NewStudent, type StudentFilters } from './api'

export function useStudents(filters: StudentFilters) {
  return useQuery({ queryKey: ['students', filters], queryFn: () => listStudents(filters), placeholderData: keepPreviousData })
}

export function useStudentProfile(studentId: string | null | undefined) {
  const lookups = useLookups()
  const semesterId = lookups.data?.semester?.id ?? null
  return useQuery({
    queryKey: ['student_profile', studentId, semesterId],
    queryFn: () => getStudentProfile(studentId!, semesterId),
    enabled: !!studentId && lookups.isSuccess,
  })
}

export function useAddStudent() {
  const { schoolId } = useAuth()
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (s: NewStudent) => addStudent(schoolId!, s),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['students'] })
      qc.invalidateQueries({ queryKey: ['dashboard'] })
      qc.invalidateQueries({ queryKey: ['classes'] })
    },
  })
}
