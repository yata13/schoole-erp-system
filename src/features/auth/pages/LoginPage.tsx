import { useState, type FormEvent } from 'react'
import { Navigate, useLocation } from 'react-router'
import { Button, Field, Input } from '../../../components/ui/Field'
import { Notice } from '../../../components/ui/Notice'
import { useAuth } from '../AuthProvider'
import { useSignIn } from '../hooks'

const SCHOOL_CODE_KEY = 'erp.schoolCode'

function rememberedCode(): string {
  try {
    return localStorage.getItem(SCHOOL_CODE_KEY) ?? ''
  } catch {
    return ''
  }
}

export function LoginPage() {
  const { session } = useAuth()
  const location = useLocation()
  const signIn = useSignIn()
  const [schoolCode, setSchoolCode] = useState(rememberedCode)
  const [loginId, setLoginId] = useState('')
  const [password, setPassword] = useState('')

  if (session) {
    const from = (location.state as { from?: string } | null)?.from ?? '/'
    return <Navigate to={from} replace />
  }

  function onSubmit(e: FormEvent) {
    e.preventDefault()
    signIn.mutate(
      { schoolCode, loginId, password },
      {
        onSuccess: () => {
          try {
            localStorage.setItem(SCHOOL_CODE_KEY, schoolCode.trim().toUpperCase())
          } catch {
            /* private mode: nothing to remember */
          }
        },
      },
    )
  }

  return (
    <div className="flex min-h-full items-center justify-center px-4 py-10">
      <div className="w-full max-w-sm">
        <div className="mb-6 text-center">
          <img src="/favicon.svg" alt="" className="mx-auto h-12 w-12" />
          <h1 className="mt-3 text-2xl font-bold">School ERP</h1>
          <p className="mt-1 text-sm text-slate-500">Sign in with your school code and your ID or phone.</p>
        </div>

        <form onSubmit={onSubmit} className="space-y-4 rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
          <Field label="School code">
            <Input
              value={schoolCode}
              onChange={(e) => setSchoolCode(e.target.value)}
              placeholder="AHS"
              autoCapitalize="characters"
              autoComplete="organization"
              required
            />
          </Field>
          <Field label="Student ID, staff ID or phone" hint="e.g. AHS-19-0001 or 0911 22 33 44">
            <Input
              value={loginId}
              onChange={(e) => setLoginId(e.target.value)}
              autoCapitalize="characters"
              autoComplete="username"
              required
            />
          </Field>
          <Field label="Password">
            <Input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete="current-password"
              required
            />
          </Field>

          {signIn.error && <Notice tone="error">{signIn.error.message}</Notice>}

          <Button type="submit" className="w-full" disabled={signIn.isPending}>
            {signIn.isPending ? 'Signing in…' : 'Sign in'}
          </Button>
        </form>

        <p className="mt-4 text-center text-xs text-slate-500">
          Forgot your password? Ask your school's registrar to reset it.
        </p>
      </div>
    </div>
  )
}
