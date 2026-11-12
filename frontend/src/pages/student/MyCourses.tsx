import { Award, BookOpen } from "lucide-react";
import { useState } from "react";
import { Link } from "react-router-dom";
import { CourseThumb } from "../../components/Brand";
import { Badge, Card, CardSkeleton, EmptyState, ErrorState, LinkButton, PageHeader, ProgressBar, Tabs } from "../../components/ui";
import { useAsync } from "../../hooks/useAsync";
import { studentApi } from "../../services";
import { assetUrl } from "../../services/api";
import { formatDate } from "../../utils/format";

type Tab = "all" | "progress" | "done";
export default function MyCourses() {
  const { data, loading, error, reloadWithSpinner } = useAsync(studentApi.courses);
  const [tab, setTab] = useState<Tab>("all");
  const list = (data ?? []).filter((c) => tab === "all" || (tab === "done" ? c.is_completed : !c.is_completed));
  return (
    <div>
      <PageHeader title="My courses" subtitle="Everything you're enrolled in." actions={<LinkButton to="/courses" variant="outline">Browse more courses</LinkButton>} />
      <div className="mb-6"><Tabs<Tab> value={tab} onChange={setTab} tabs={[{ id: "all", label: "All", count: data?.length }, { id: "progress", label: "In progress", count: data?.filter((c) => !c.is_completed).length }, { id: "done", label: "Completed", count: data?.filter((c) => c.is_completed).length }]} /></div>
      {error ? <ErrorState message={error} onRetry={reloadWithSpinner} /> : loading ? <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">{Array.from({ length: 3 }).map((_, i) => <CardSkeleton key={i} />)}</div> :
        list.length === 0 ? <EmptyState icon={<BookOpen className="h-7 w-7" />} title={tab === "all" ? "No courses yet" : "Nothing here yet"} message={tab === "all" ? "Enroll in a course to start learning." : "Courses will show up here as you make progress."} action={tab === "all" && <LinkButton to="/courses">Browse courses</LinkButton>} /> : (
          <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
            {list.map((mc) => (
              <Card key={mc.course.id} padded={false} className="flex flex-col overflow-hidden">
                <CourseThumb title={mc.course.title} src={assetUrl(mc.course.thumbnail_url)} category={mc.course.category} className="h-36 w-full" />
                <div className="flex flex-1 flex-col p-4">
                  <div className="mb-1 flex items-center justify-between gap-2"><h3 className="line-clamp-2 font-bold text-slate-900">{mc.course.title}</h3>{mc.is_completed && <Badge tone="green"><Award className="h-3 w-3" />Done</Badge>}</div>
                  <p className="mb-3 text-xs text-slate-500">Enrolled {formatDate(mc.enrolled_at)} · {mc.progress.completed_lessons}/{mc.progress.total_lessons} lessons</p>
                  <ProgressBar value={mc.progress.percentage} showLabel />
                  <div className="mt-4 flex gap-2">
                    <LinkButton to={`/app/learn/${mc.course.id}`} className="flex-1">{mc.is_completed ? "Review course" : mc.progress.completed_lessons ? "Continue learning" : "Start learning"}</LinkButton>
                    {mc.is_completed && <Link to="/app/certificates" className="inline-flex h-10 items-center rounded-xl border border-slate-300 px-3 text-sm font-semibold text-slate-700 hover:bg-white/5" aria-label="Certificate"><Award className="h-4 w-4" /></Link>}
                  </div>
                </div>
              </Card>
            ))}
          </div>)}
    </div>
  );
}
