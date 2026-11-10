import { useMutation, useQuery } from '@tanstack/react-query'
import { getMyProfile, getMySchool, signIn, signOut } from './api'
import { useAuth } from './AuthProvider'

export function useSignIn() {
  return useMutation({
    mutationFn: (v: { schoolCode: string; loginId: string; password: string }) =>
      signIn(v.schoolCode, v.loginId, v.password),
  })
}

export function useSignOut() {
  return useMutation({ mutationFn: signOut })
}

export function useMyProfile() {
  const { userId, schoolId } = useAuth()
  return useQuery({
    queryKey: ['profile', userId],
    queryFn: () => getMyProfile(userId!),
    enabled: !!userId && !!schoolId,
  })
}

export function useMySchool() {
  const { schoolId } = useAuth()
  return useQuery({
    queryKey: ['school', schoolId],
    queryFn: getMySchool,
    enabled: !!schoolId,
    staleTime: 10 * 60 * 1000,
  })
}
