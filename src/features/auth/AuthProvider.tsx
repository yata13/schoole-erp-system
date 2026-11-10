import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import type { Session } from '@supabase/supabase-js'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase, type AppRole } from '../../lib/supabase'

// My school and roles. The database answers from the login token when the
// access-token hook is on, and from its own tables when it is off (0009).
type Access = { school_id: string | null; user_roles: AppRole[] }

async function fetchAccess(): Promise<Access> {
  const { data, error } = await supabase.rpc('my_access')
  if (error) throw error
  const a = (data ?? {}) as Partial<Access>
  return { school_id: a.school_id ?? null, user_roles: a.user_roles ?? [] }
}

type AuthState = {
  loading: boolean
  session: Session | null
  userId: string | null
  schoolId: string | null
  roles: AppRole[]
  hasAnyRole: (...roles: AppRole[]) => boolean
}

const AuthContext = createContext<AuthState | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const queryClient = useQueryClient()
  const [session, setSession] = useState<Session | null | undefined>(undefined)

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => setSession(data.session))
    const { data } = supabase.auth.onAuthStateChange((event, next) => {
      setSession(next)
      // A different user must never see the last user's cached data.
      if (event === 'SIGNED_OUT' || event === 'SIGNED_IN') queryClient.clear()
    })
    return () => data.subscription.unsubscribe()
  }, [queryClient])

  const userId = session?.user.id ?? null
  const access = useQuery({
    queryKey: ['my_access', userId],
    queryFn: fetchAccess,
    enabled: !!userId,
    staleTime: 5 * 60 * 1000,
  })

  const value = useMemo<AuthState>(() => {
    const roles = access.data?.user_roles ?? []
    return {
      loading: session === undefined || (!!userId && access.isLoading),
      session: session ?? null,
      userId,
      schoolId: access.data?.school_id ?? null,
      roles,
      hasAnyRole: (...wanted) => wanted.some((r) => roles.includes(r)),
    }
  }, [session, userId, access.data, access.isLoading])

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used inside <AuthProvider>')
  return ctx
}
