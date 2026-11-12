import { Award, BookOpen, CalendarDays, ClipboardList, PlayCircle, Sparkles } from "lucide-react";
import { Link } from "react-router-dom";
import { CourseThumb } from "../../components/Brand";
import { AssignmentRow, LiveClassCard } from "../../components/Cards";
import { Card, EmptyState, ErrorState, LinkButton, ProgressBar, Skeleton, StatCard } from "../../components/ui";
import { useAuth } from "../../context/AuthContext";
import { useAsync } from "../../hooks/useAsync";
import { studentApi } from "../../services";
import { assetUrl } from "../../services/api";
import { timeAgo } from "../../utils/format";

export default function Dashboard() {
  const { user } = useAuth();
  const { data, loading, error, reloadWithSpinner } = useAsync(studentApi.dashboard);
  if (error) return <ErrorState message={error} onRetry={reloadWithSpinner} />;
  const hour = new Date().getHours();
  const greet = hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening";

  return (
    <div className="space-y-8">
      <div className="glass relative overflow-hidden rounded-3xl p-6 sm:p-8"><div className="grid-bg pointer-events-none absolute inset-0 opacity-40" /><div className="pointer-events-none absolute -right-16 -top-16 h-64 w-64 rounded-full bg-brand-500/25 blur-3xl" />
        <p className="relative flex items-center gap-2 text-sm font-medium text-brand-600"><Sparkles className="h-4 w-4" />Your growth workspace</p>
        <h1 className="relative mt-1 text-2xl font-extrabold text-white sm:text-3xl">{greet}, {user?.name.split(" ")[0]}!</h1>
        <p className="relative mt-1 text-slate-500">{data && data.stats.enrolled > 0 ? "Pick up where you left off." : "Enroll in a course to get started."}</p>
      </div>

      <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        {loading || !data ? Array.from({ length: 4 }).map((_, i) => <Skeleton key={i} className="h-24" />) : <>
          <StatCard label="Enrolled courses" value={data.stats.enrolled} icon={<BookOpen className="h-6 w-6" />} />
          <StatCard label="In progress" value={data.stats.in_progress} icon={<PlayCircle className="h-6 w-6" />} tone="blue" />
          <StatCard label="Completed" value={data.stats.completed} icon={<Award className="h-6 w-6" />} tone="green" />
          <StatCard label="Pending assignments" value={data.stats.pending_assignments} icon={<ClipboardList className="h-6 w-6" />} tone="amber" />
        </>}
      </div>

      <section>
        <div className="mb-4 flex items-center justify-between"><h2 className="text-lg font-bold text-slate-900">Continue learning</h2><Link to="/app/courses" className="text-sm font-semibold text-brand-600 hover:underline">All my courses</Link></div>
        {loading || !data ? <Skeleton className="h-40" /> : data.courses.length === 0 ? (
          <EmptyState icon={<BookOpen className="h-7 w-7" />} title="You haven't enrolled in any courses yet" message="Browse the catalogue and start your first course today." action={<LinkButton to="/courses">Browse courses</LinkButton>} />
        ) : (
          <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
            {data.courses.slice(0, 4).map((mc) => (
              <Card key={mc.course.id} className="flex gap-4 !p-3">
                <CourseThumb title={mc.course.title} src={assetUrl(mc.course.thumbnail_url)} className="h-24 w-28 shrink-0 rounded-xl" />
                <div className="flex min-w-0 flex-1 flex-col justify-between">
                  <div><h3 className="truncate font-bold text-slate-900">{mc.course.title}</h3><p className="text-xs text-slate-500">{mc.progress.completed_lessons}/{mc.progress.total_lessons} lessons</p></div>
                  <ProgressBar value={mc.progress.percentage} showLabel size="sm" />
                  <LinkButton to={`/app/learn/${mc.course.id}`} size="sm" className="mt-2 self-start">{mc.is_completed ? "Review" : "Continue"}</LinkButton>
                </div>
              </Card>
            ))}
          </div>
        )}
      </section>

      <div className="grid grid-cols-1 gap-8 lg:grid-cols-2">
        <section>
          <div className="mb-4 flex items-center justify-between"><h2 className="text-lg font-bold text-slate-900">Pending assignments</h2><Link to="/app/assignments" className="text-sm font-semibold text-brand-600 hover:underline">View all</Link></div>
          {loading || !data ? <Skeleton className="h-28" /> : data.pending_assignments.length === 0 ? <EmptyState icon={<ClipboardList className="h-7 w-7" />} title="Nothing due" message="You're all caught up on assignments." /> : <div className="space-y-3">{data.pending_assignments.map((a) => <AssignmentRow key={a.id} a={a} />)}</div>}
        </section>
        <section>
          <div className="mb-4 flex items-center justify-between"><h2 className="text-lg font-bold text-slate-900">Upcoming live classes</h2><Link to="/app/live" className="text-sm font-semibold text-brand-600 hover:underline">View all</Link></div>
          {loading || !data ? <Skeleton className="h-28" /> : data.upcoming_live_classes.length === 0 ? <EmptyState icon={<CalendarDays className="h-7 w-7" />} title="No live classes scheduled" message="Scheduled sessions for your courses will show up here." /> : <div className="space-y-3">{data.upcoming_live_classes.slice(0, 2).map((l) => <LiveClassCard key={l.id} lc={l} compact />)}</div>}
        </section>
      </div>

      <section>
        <h2 className="mb-4 text-lg font-bold text-slate-900">Recent activity</h2>
        {loading || !data ? <Skeleton className="h-28" /> : data.recent_activity.length === 0 ? <p className="text-sm text-slate-500">Your activity will appear here as you learn.</p> : (
          <Card padded={false}><ul className="divide-y divide-slate-100">{data.recent_activity.map((a, i) => <li key={i} className="flex items-center justify-between gap-4 px-5 py-3.5 text-sm"><span className="text-slate-700">{a.title}</span><span className="shrink-0 text-xs text-slate-400">{timeAgo(a.at)}</span></li>)}</ul></Card>
        )}
      </section>
    </div>
  );
}
