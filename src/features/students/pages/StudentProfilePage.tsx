import { Link, useParams } from 'react-router'
import { Icon } from '../../../components/ui/icons'
import { StudentProfileView } from '../components/StudentProfileView'

export function StudentProfilePage() {
  const { id } = useParams()
  return (
    <div>
      <Link to="/students" className="rise mb-4 inline-flex items-center gap-1 text-sm font-semibold text-indigo-600 hover:underline">
        <Icon name="chevron" className="h-4 w-4 rotate-180" /> All students
      </Link>
      {id && <StudentProfileView studentId={id} />}
    </div>
  )
}
