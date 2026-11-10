import { lazy, Suspense, type ComponentType } from 'react'
import { Navigate, Route, Routes } from 'react-router'
import { AppShell } from '../components/layout/AppShell'
import { Spinner } from '../components/ui/Spinner'
import { RequireAuth } from '../features/auth/RequireAuth'
import { useAuth } from '../features/auth/AuthProvider'
import { LoginPage } from '../features/auth/pages/LoginPage'
import { OFFICE, STAFF } from '../lib/nav'

// Each module downloads only when it is opened.
function page<T extends string>(load: () => Promise<Record<T, ComponentType>>, name: T) {
  return lazy(() => load().then((m) => ({ default: m[name] })))
}
const OverviewDashboard = page(() => import('../features/dashboard/pages/OverviewDashboard'), 'OverviewDashboard')
const TeacherHome = page(() => import('../features/teacher/pages/TeacherHome'), 'TeacherHome')
const FamilyHome = page(() => import('../features/portal/pages/FamilyHome'), 'FamilyHome')
const StudentListPage = page(() => import('../features/students/pages/StudentListPage'), 'StudentListPage')
const StudentProfilePage = page(() => import('../features/students/pages/StudentProfilePage'), 'StudentProfilePage')
const StaffPage = page(() => import('../features/staff/pages/StaffPage'), 'StaffPage')
const ClassesPage = page(() => import('../features/classes/pages/ClassesPage'), 'ClassesPage')
const AttendancePage = page(() => import('../features/teacher/pages/AttendancePage'), 'AttendancePage')
const MarksPage = page(() => import('../features/teacher/pages/MarksPage'), 'MarksPage')
const RoadmapPage = page(() => import('../features/teacher/pages/RoadmapPage'), 'RoadmapPage')
const FinancePage = page(() => import('../features/finance/pages/FinancePage'), 'FinancePage')
const FinesPage = page(() => import('../features/fines/pages/FinesPage'), 'FinesPage')

/** "/" shows each role its own home. */
function RoleHome() {
  const { hasAnyRole } = useAuth()
  if (hasAnyRole(...OFFICE)) return <OverviewDashboard />
  if (hasAnyRole('teacher')) return <TeacherHome />
  return <FamilyHome />
}

export function AppRoutes() {
  return (
    <Suspense fallback={<Spinner full />}>
      <Routes>
        <Route path="/login" element={<LoginPage />} />
        <Route element={<RequireAuth><AppShell /></RequireAuth>}>
          <Route index element={<RoleHome />} />
          <Route path="students" element={<RequireAuth roles={STAFF}><StudentListPage /></RequireAuth>} />
          <Route path="students/:id" element={<RequireAuth><StudentProfilePage /></RequireAuth>} />
          <Route path="staff" element={<RequireAuth roles={OFFICE}><StaffPage /></RequireAuth>} />
          <Route path="classes" element={<RequireAuth roles={STAFF}><ClassesPage /></RequireAuth>} />
          <Route path="attendance" element={<RequireAuth roles={['super_admin', 'director', 'registrar', 'teacher']}><AttendancePage /></RequireAuth>} />
          <Route path="marks" element={<RequireAuth roles={['super_admin', 'director', 'registrar', 'teacher']}><MarksPage /></RequireAuth>} />
          <Route path="roadmap" element={<RequireAuth roles={['super_admin', 'director', 'teacher']}><RoadmapPage /></RequireAuth>} />
          <Route path="finance" element={<RequireAuth roles={OFFICE}><FinancePage /></RequireAuth>} />
          <Route path="fines" element={<RequireAuth roles={STAFF}><FinesPage /></RequireAuth>} />
        </Route>
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </Suspense>
  )
}
