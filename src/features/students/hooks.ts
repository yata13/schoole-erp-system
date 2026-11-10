import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { listStudents, type StudentFilters } from './api'

export function useStudents(filters: StudentFilters) {
  return useQuery({
    queryKey: ['students', filters],
    queryFn: () => listStudents(filters),
    placeholderData: keepPreviousData,
  })
}
