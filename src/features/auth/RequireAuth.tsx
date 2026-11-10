import type { ReactNode } from 'react'
import { Navigate, useLocation } from 'react-router'
import type { AppRole } from '../../lib/supabase'
import { Spinner } from '../../components/ui/Spinner'
import { Notice } from '../../components/ui/Notice'
import { useAuth } from './AuthProvider'
import { useSignOut } from './hooks'

/** Signed in, linked to a school, and (optionally) holding one of `roles`. */
export function RequireAuth({ roles, children }: { roles?: AppRole[]; children: ReactNode }) {
  const { loading, session, schoolId, hasAnyRole } = useAuth()
  const location = useLocation()
  const signOut = useSignOut()

  if (loading) return <Spinner full />
  if (!session) return <Navigate to="/login" replace state={{ from: location.pathname }} />

  if (!schoolId) {
    return (
      <div className="mx-auto max-w-md p-6 pt-20">
        <Notice tone="warn" title="Your account is not linked to a school">
          You are signed in, but your login has no active school or role. Ask your school's admin to check
          your account.
        </Notice>
        <button
          className="mt-4 text-sm font-medium text-blue-700 hover:underline"
          onClick={() => signOut.mutate()}
        >
          Sign out
        </button>
      </div>
    )
  }

  if (roles && !hasAnyRole(...roles)) {
    return (
      <div className="p-6">
        <Notice tone="warn" title="No access">Your role cannot open this page.</Notice>
      </div>
    )
  }

  return <>{children}</>
}
