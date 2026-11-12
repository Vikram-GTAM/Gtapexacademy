import { ArrowLeft, UserCheck, UserX } from "lucide-react";
import { useState } from "react";
import { Link, useParams } from "react-router-dom";
import { Badge, Button, Card, ConfirmationModal, ErrorState, PageHeader, PageLoader, ProgressBar } from "../../components/ui";
import { useToast } from "../../context/ToastContext";
import { useAsync } from "../../hooks/useAsync";
import { adminApi } from "../../services";
import { getErrorMessage } from "../../services/api";
import { formatDate, initials } from "../../utils/format";

export default function AdminStudentDetail() {
  const { id = "" } = useParams();
  const toast = useToast();
  const { data: s, loading, error, reload, reloadWithSpinner } = useAsync(() => adminApi.student(id), [id]);
  const [confirm, setConfirm] = useState(false);
  const [busy, setBusy] = useState(false);
  if (loading) return <PageLoader />;
  if (error || !s) return <ErrorState message={error ?? "Student not found"} onRetry={reloadWithSpinner} />;

  async function toggle() {
    if (!s) return; setBusy(true);
    try { await adminApi.setStudentStatus(s.id, !s.is_active); toast.success(s.is_active ? "Account disabled" : "Account enabled"); setConfirm(false); reload(); }
    catch (e) { toast.error(getErrorMessage(e)); } finally { setBusy(false); }
  }
  return (
    <div>
      <Link to="/admin/students" className="mb-4 inline-flex items-center gap-1.5 text-sm font-medium text-slate-500 hover:text-slate-800"><ArrowLeft className="h-4 w-4" />All students</Link>
      <PageHeader title={s.name} subtitle={`${s.email} · joined ${formatDate(s.joined_at)}`}
        actions={<Button variant={s.is_active ? "danger" : "success"} icon={s.is_active ? <UserX className="h-4 w-4" /> : <UserCheck className="h-4 w-4" />} onClick={() => setConfirm(true)}>{s.is_active ? "Disable account" : "Enable account"}</Button>} />
      <div className="mb-6 flex items-center gap-3"><div className="flex h-12 w-12 items-center justify-center rounded-full bg-neon font-bold text-brand-ink">{initials(s.name)}</div><Badge tone={s.is_active ? "green" : "red"} dot>{s.is_active ? "Active" : "Disabled"}</Badge></div>
      <div className="grid gap-6 lg:grid-cols-2">
        <Card className="lg:col-span-2">
          <h2 className="mb-3 font-bold text-slate-900">Course progress</h2>
          {s.courses.length === 0 ? <p className="text-sm text-slate-500">Not enrolled in any course.</p> : (
            <div className="space-y-4">{s.courses.map((c) => (
              <div key={c.course_id}><div className="mb-1 flex items-center justify-between text-sm"><span className="font-medium text-slate-900">{c.title}{c.learning_mode && <Badge tone={c.learning_mode === "offline" ? "green" : "blue"} className="ml-2 capitalize">{c.learning_mode}</Badge>}</span><span className="text-xs text-slate-500">{c.completed_lessons}/{c.total_lessons} lessons{c.completed_at && " · completed"}</span></div><ProgressBar value={c.percentage} showLabel /></div>))}</div>
          )}
        </Card>
        <Card>
          <h2 className="mb-3 font-bold text-slate-900">Assignments</h2>
          {s.assignments.length === 0 ? <p className="text-sm text-slate-500">No submissions.</p> : <ul className="divide-y divide-slate-100">{s.assignments.map((a) => <li key={a.id} className="flex items-center justify-between gap-2 py-2 text-sm"><span className="truncate">{a.title}{a.is_late && <Badge tone="amber" className="ml-2">Late</Badge>}</span>{a.status === "reviewed" ? <Badge tone="green">{a.marks}/{a.max_marks}</Badge> : <Badge tone="blue">Pending</Badge>}</li>)}</ul>}
        </Card>
        <Card>
          <h2 className="mb-3 font-bold text-slate-900">Quiz results</h2>
          {s.quizzes.length === 0 ? <p className="text-sm text-slate-500">No quiz attempts.</p> : <ul className="divide-y divide-slate-100">{s.quizzes.map((q) => <li key={q.id} className="flex items-center justify-between gap-2 py-2 text-sm"><span className="truncate">{q.title}<span className="ml-2 text-xs text-slate-400">{formatDate(q.submitted_at)}</span></span><Badge tone="brand">{q.score}/{q.total_marks}</Badge></li>)}</ul>}
        </Card>
      </div>
      <ConfirmationModal open={confirm} danger={s.is_active} title={s.is_active ? "Disable account?" : "Enable account?"} message={s.is_active ? `${s.name} will be signed out and unable to log in until re-enabled.` : `${s.name} will be able to log in again.`} confirmLabel={s.is_active ? "Disable" : "Enable"} loading={busy} onConfirm={toggle} onCancel={() => setConfirm(false)} />
    </div>
  );
}
