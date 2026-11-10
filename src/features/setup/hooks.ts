import { useQuery } from '@tanstack/react-query'
import { listAcademicYears, listGrades, listSectionOccupancy } from './api'

export function useAcademicYears() {
  return useQuery({ queryKey: ['academic_years'], queryFn: listAcademicYears })
}

export function useCurrentYear() {
  const years = useAcademicYears()
  return { ...years, data: years.data?.find((y) => y.is_current) ?? null }
}

export function useGrades() {
  return useQuery({ queryKey: ['grades'], queryFn: listGrades, staleTime: 10 * 60 * 1000 })
}

export function useSectionOccupancy(academicYearId: string | null | undefined) {
  return useQuery({
    queryKey: ['section_occupancy', academicYearId],
    queryFn: () => listSectionOccupancy(academicYearId!),
    enabled: !!academicYearId,
  })
}
