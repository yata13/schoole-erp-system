import { useState, type FormEvent } from 'react'
import { Navigate, useLocation } from 'react-router'
import { Button, Field, Input } from '../../../components/ui/Field'
import { Notice } from '../../../components/ui/Notice'
import { Icon } from '../../../components/ui/icons'
import { useAuth } from '../AuthProvider'
import { useSignIn } from '../hooks'

const SCHOOL_CODE_KEY = 'erp.schoolCode'

type DemoAccount = { label: string; school: string; login: string; password: string }

// Test builds only: VITE_DEMO_ACCOUNTS in .env.production adds one-tap demo logins.
function demoAccounts(): DemoAccount[] {
  try {
    const raw = import.meta.env.VITE_DEMO_ACCOUNTS as string | undefined
    return raw ? (JSON.parse(raw) as DemoAccount[]) : []
  } catch {
    return []
  }
}
const DEMO = demoAccounts()

function rememberedCode(): string {
  try {
    return localStorage.getItem(SCHOOL_CODE_KEY) ?? ''
  } catch {
    return ''
  }
}

const FEATURES = [
  { icon: 'students', text: 'Students, classes and enrollment from KG to grade 12' },
  { icon: 'attendance', text: 'Daily attendance and marks, entered by teachers' },
  { icon: 'finance', text: 'Fees, Telebirr and bank payments, expenses and revenue' },
  { icon: 'staff', text: 'Every employee: teachers, cleaners, guards, drivers' },
]

export function LoginPage() {
  const { session } = useAuth()
  const location = useLocation()
  const signIn = useSignIn()
  const [schoolCode, setSchoolCode] = useState(() => DEMO[0]?.school ?? rememberedCode())
  const [loginId, setLoginId] = useState(DEMO[0]?.login ?? '')
  const [password, setPassword] = useState(DEMO[0]?.password ?? '')

  if (session) {
    const from = (location.state as { from?: string } | null)?.from ?? '/'
    return <Navigate to={from} replace />
  }

  function go(code: string, id: string, pw: string) {
    signIn.mutate(
      { schoolCode: code, loginId: id, password: pw },
      {
        onSuccess: () => {
          try {
            localStorage.setItem(SCHOOL_CODE_KEY, code.trim().toUpperCase())
          } catch {
            /* private mode */
          }
        },
      },
    )
  }

  function onSubmit(e: FormEvent) {
    e.preventDefault()
    go(schoolCode, loginId, password)
  }

  return (
    <div className="grid min-h-full lg:grid-cols-[1.1fr_1fr]">
      {/* Brand panel */}
      <div className="relative hidden overflow-hidden bg-gradient-to-br from-[#0b1220] via-[#172554] to-[#4c1d95] p-12 text-white lg:flex lg:flex-col lg:justify-between">
        <div className="absolute -right-24 -top-24 h-80 w-80 rounded-full bg-indigo-500/20 blur-2xl" />
        <div className="absolute -bottom-32 -left-20 h-96 w-96 rounded-full bg-blue-500/20 blur-2xl" />
        <div className="relative flex items-center gap-3">
          <div className="grid h-12 w-12 place-items-center rounded-2xl bg-gradient-to-br from-indigo-400 to-blue-500 shadow-lg">
            <Icon name="cap" className="h-7 w-7" />
          </div>
          <div>
            <p className="text-xl font-extrabold">School ERP</p>
            <p className="text-xs font-semibold uppercase tracking-widest text-indigo-200">Ethiopia · KG–12</p>
          </div>
        </div>
        <div className="relative">
          <h1 className="rise text-4xl font-extrabold leading-tight">Run the whole school<br />from one place.</h1>
          <ul className="mt-8 space-y-4">
            {FEATURES.map((f, i) => (
              <li key={f.text} className="rise flex items-center gap-3 text-indigo-100" style={{ animationDelay: `${120 + i * 90}ms` }}>
                <span className="grid h-9 w-9 place-items-center rounded-xl bg-white/10"><Icon name={f.icon} /></span>
                {f.text}
              </li>
            ))}
          </ul>
        </div>
        <p className="relative text-xs text-indigo-200/80">Each person sees only what their role allows.</p>
      </div>

      {/* Form */}
      <div className="flex items-center justify-center px-4 py-10">
        <div className="rise w-full max-w-sm">
          <div className="mb-6 lg:hidden">
            <div className="grid h-12 w-12 place-items-center rounded-2xl bg-gradient-to-br from-indigo-500 to-blue-500 text-white shadow-lg">
              <Icon name="cap" className="h-7 w-7" />
            </div>
          </div>
          <h2 className="text-2xl font-extrabold">Sign in</h2>
          <p className="mt-1 text-sm text-slate-500">Use your school code and your ID or phone.</p>

          {DEMO.length > 0 && (
            <div className="mt-5 rounded-2xl border border-amber-200 bg-amber-50 p-3">
              <p className="text-xs font-bold uppercase tracking-wide text-amber-800">Demo — tap a role</p>
              <div className="mt-2 grid grid-cols-3 gap-2">
                {DEMO.map((a) => (
                  <button
                    key={a.label}
                    type="button"
                    disabled={signIn.isPending}
                    onClick={() => {
                      setSchoolCode(a.school)
                      setLoginId(a.login)
                      setPassword(a.password)
                      go(a.school, a.login, a.password)
                    }}
                    className="rounded-xl bg-white px-2 py-2 text-xs font-bold text-slate-700 shadow-sm ring-1 ring-amber-200 transition hover:-translate-y-0.5 hover:ring-amber-400 disabled:opacity-50"
                  >
                    {a.label}
                  </button>
                ))}
              </div>
            </div>
          )}

          <form onSubmit={onSubmit} className="mt-5 space-y-4">
            <Field label="School code">
              <Input value={schoolCode} onChange={(e) => setSchoolCode(e.target.value)} placeholder="AHS"
                autoCapitalize="characters" autoComplete="organization" required />
            </Field>
            <Field label="Student ID, staff ID or phone" hint="e.g. AHS-19-0001 or 0911 22 33 44">
              <Input value={loginId} onChange={(e) => setLoginId(e.target.value)} autoCapitalize="characters"
                autoComplete="username" required />
            </Field>
            <Field label="Password">
              <Input type="password" value={password} onChange={(e) => setPassword(e.target.value)}
                autoComplete="current-password" required />
            </Field>
            {signIn.error && <Notice tone="error">{signIn.error.message}</Notice>}
            <Button type="submit" className="w-full !py-2.5" disabled={signIn.isPending}>
              {signIn.isPending ? 'Signing in…' : 'Sign in'}
            </Button>
          </form>
          <p className="mt-4 text-center text-xs text-slate-500">Forgot your password? Ask your school's registrar to reset it.</p>
        </div>
      </div>
    </div>
  )
}
