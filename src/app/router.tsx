import { lazy, Suspense } from 'react'
import { Navigate, Route, Routes } from 'react-router'
import { AppShell } from '../components/layout/AppShell'
import { Spinner } from '../components/ui/Spinner'
import { RequireAuth } from '../features/auth/RequireAuth'
import { LoginPage } from '../features/auth/pages/LoginPage'

// Each module downloads only when it is opened.
const HomePage = lazy(() => import('../features/home/pages/HomePage').then((m) => ({ default: m.HomePage })))
const SetupPage = lazy(() => import('../features/setup/pages/SetupPage').then((m) => ({ default: m.SetupPage })))
const StudentListPage = lazy(() =>
  import('../features/students/pages/StudentListPage').then((m) => ({ default: m.StudentListPage })),
)

export function AppRoutes() {
  return (
    <Suspense fallback={<Spinner full />}>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route
          element={
            <RequireAuth>
              <AppShell />
            </RequireAuth>
          }
        >
          <Route index element={<HomePage />} />
          <Route path="setup" element={<SetupPage />} />
          <Route
            path="students"
            element={
              <RequireAuth roles={['super_admin', 'director', 'registrar', 'teacher', 'finance']}>
                <StudentListPage />
              </RequireAuth>
            }
          />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </Suspense>
  )
}
