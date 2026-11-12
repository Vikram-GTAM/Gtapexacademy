import { Clock, HelpCircle, ListChecks, Trophy } from "lucide-react";
import { Link } from "react-router-dom";
import { Badge, Card, EmptyState, ErrorState, LinkButton, PageHeader, Skeleton } from "../../components/ui";
import { useAsync } from "../../hooks/useAsync";
import { quizApi } from "../../services";
import { formatDate } from "../../utils/format";

export default function Quizzes() {
  const { data, loading, error, reloadWithSpinner } = useAsync(quizApi.list);
  return (
    <div>
      <PageHeader title="Quizzes" subtitle="Test your knowledge. You can retake any quiz." />
      {error ? <ErrorState message={error} onRetry={reloadWithSpinner} /> : loading ? (
        <div className="grid gap-4 md:grid-cols-2">{Array.from({ length: 4 }).map((_, i) => <Skeleton key={i} className="h-44 w-full" />)}</div>
      ) : !data || data.length === 0 ? (
        <EmptyState icon={<HelpCircle className="h-7 w-7" />} title="No quizzes yet" message="Quizzes from your enrolled courses will appear here." />
      ) : (
        <div className="grid gap-4 md:grid-cols-2">
          {data.map((q) => {
            const la = q.last_attempt;
            const pct = la && la.total_marks ? Math.round((la.score / la.total_marks) * 100) : null;
            return (
              <Card key={q.id} className="flex flex-col">
                <div className="mb-2 flex items-center justify-between"><Badge tone="brand">{q.course_title}</Badge>{pct !== null && <Badge tone={pct >= 60 ? "green" : "amber"}><Trophy className="h-3 w-3" />{pct}%</Badge>}</div>
                <Link to={`/app/quizzes/${q.id}`} className="text-lg font-bold text-slate-900 hover:text-brand-700">{q.title}</Link>
                {q.description && <p className="mt-1 line-clamp-2 text-sm text-slate-500">{q.description}</p>}
                <div className="mt-3 flex flex-wrap gap-4 text-sm text-slate-600">
                  <span className="flex items-center gap-1.5"><ListChecks className="h-4 w-4 text-slate-400" />{q.question_count} questions</span>
                  <span className="flex items-center gap-1.5"><Clock className="h-4 w-4 text-slate-400" />{q.time_limit_minutes ? `${q.time_limit_minutes} min` : "No time limit"}</span>
                </div>
                {la?.submitted_at && <p className="mt-2 text-xs text-slate-400">Last attempt {formatDate(la.submitted_at)}: {la.score}/{la.total_marks}</p>}
                <div className="mt-4 flex-1 content-end"><LinkButton to={`/app/quizzes/${q.id}`} variant={la ? "outline" : "primary"} className="w-full">{la ? "Retake quiz" : "Start quiz"}</LinkButton></div>
              </Card>
            );
          })}
        </div>
      )}
    </div>
  );
}
