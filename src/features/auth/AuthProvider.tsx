import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'
import type { Session } from '@supabase/supabase-js'
import { useQueryClient } from '@tanstack/react-query'
import { supabase, type AppRole } from '../../lib/supabase'

// school_id and user_roles are put into the token by custom_access_token_hook.
type Claims = { school_id?: string; user_roles?: AppRole[] }

function readClaims(session: Session | null): Claims {
  if (!session) return {}
  try {
    const payload = session.access_token.split('.')[1]
    const json = atob(payload.replace(/-/g, '+').replace(/_/g, '/'))
    return JSON.parse(json) as Claims
  } catch {
    return {}
  }
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

  const value = useMemo<AuthState>(() => {
    const claims = readClaims(session ?? null)
    const roles = claims.user_roles ?? []
    return {
      loading: session === undefined,
      session: session ?? null,
      userId: session?.user.id ?? null,
      schoolId: claims.school_id ?? null,
      roles,
      hasAnyRole: (...wanted) => wanted.some((r) => roles.includes(r)),
    }
  }, [session])

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used inside <AuthProvider>')
  return ctx
}
