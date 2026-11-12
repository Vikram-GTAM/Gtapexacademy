import { AlertTriangle, ArrowLeft, CheckCircle2, Download, Paperclip } from "lucide-react";
import { useState } from "react";
import { Link, useParams } from "react-router-dom";
import { Badge, Button, Card, ErrorState, FileUploader, PageLoader, Textarea } from "../../components/ui";
import { assignmentState } from "../../components/Cards";
import { useToast } from "../../context/ToastContext";
import { useAsync } from "../../hooks/useAsync";
import { studentApi } from "../../services";
import { assetUrl, getErrorMessage } from "../../services/api";
import { formatDateTime } from "../../utils/format";

export default function AssignmentDetail() {
  const { id = "" } = useParams();
  const toast = useToast();
  const { data: a, loading, error, reload, reloadWithSpinner } = useAsync(() => studentApi.assignment(id), [id]);
  const [text, setText] = useState<string | null>(null);
  const [file, setFile] = useState<File | null>(null);
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  if (loading) return <PageLoader />;
  if (error || !a) return <ErrorState message={error ?? "Assignment not found"} onRetry={reloadWithSpinner} />;

  const st = assignmentState(a);
  const sub = a.submission;
  const closed = a.is_past_deadline && !a.allow_late;
  const graded = sub?.status === "reviewed";
  const canSubmit = !closed && !graded;
  const value = text ?? sub?.text_answer ?? "";

  async function submit() {
    setErr(null);
    if (!value.trim() && !file && !sub?.file_url) { setErr("Add a written answer or attach a file."); return; }
    const f = new FormData();
    f.append("text_answer", value);
    if (file) f.append("file", file);
    setBusy(true);
    try {
      await studentApi.submit(id, f);
      toast.success(sub ? "Submission updated" : "Assignment submitted");
      setFile(null); setText(null);
      reload();
    } catch (e) { setErr(getErrorMessage(e)); } finally { setBusy(false); }
  }

  return (
    <div className="mx-auto max-w-3xl">
      <Link to="/app/assignments" className="mb-4 inline-flex items-center gap-1.5 text-sm font-medium text-slate-500 hover:text-slate-800"><ArrowLeft className="h-4 w-4" />All assignments</Link>
      <Card>
        <div className="mb-1 flex flex-wrap items-center gap-2"><Badge tone={st.tone}>{st.label}</Badge>{sub?.is_late && <Badge tone="amber">Late submission</Badge>}</div>
        <h1 className="text-2xl font-bold text-slate-900">{a.title}</h1>
        <p className="mt-1 text-sm font-medium text-brand-600">{a.course_title}</p>
        <dl className="mt-4 grid grid-cols-2 gap-4 rounded-xl bg-slate-50 p-4 text-sm">
          <div><dt className="text-slate-500">Deadline</dt><dd className="font-semibold text-slate-900">{formatDateTime(a.deadline)}</dd></div>
          <div><dt className="text-slate-500">Max marks</dt><dd className="font-semibold text-slate-900">{a.max_marks}</dd></div>
          <div><dt className="text-slate-500">Late submissions</dt><dd className="font-semibold text-slate-900">{a.allow_late ? "Allowed" : "Not allowed"}</dd></div>
        </dl>
        <h2 className="mb-1 mt-6 text-sm font-semibold uppercase tracking-wide text-slate-500">Instructions</h2>
        <p className="whitespace-pre-line text-slate-700">{a.instructions || "No additional instructions."}</p>
        {a.attachment_url && (
          <a href={assetUrl(a.attachment_url)} target="_blank" rel="noopener noreferrer" className="mt-4 inline-flex items-center gap-2 rounded-lg border border-slate-200 px-3 py-2 text-sm font-medium text-slate-700 hover:bg-white/5"><Download className="h-4 w-4" />Download attachment</a>
        )}
      </Card>

      {graded && sub && (
        <Card className="mt-6 border-emerald-200 bg-emerald-50/50">
          <div className="flex items-center gap-2 text-emerald-700"><CheckCircle2 className="h-5 w-5" /><h2 className="font-bold">Graded</h2></div>
          <p className="mt-2 text-3xl font-extrabold text-slate-900">{sub.marks ?? 0}<span className="text-lg font-semibold text-slate-400"> / {a.max_marks}</span></p>
          {sub.feedback && <div className="mt-3"><p className="text-xs font-semibold uppercase tracking-wide text-slate-500">Feedback</p><p className="mt-1 whitespace-pre-line text-slate-700">{sub.feedback}</p></div>}
        </Card>
      )}

      <Card className="mt-6">
        <h2 className="mb-3 text-lg font-bold text-slate-900">{sub ? "Your submission" : "Submit your work"}</h2>
        {closed && !sub && <div className="mb-4 flex items-start gap-2 rounded-xl bg-rose-50 p-3 text-sm text-rose-700"><AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />The deadline has passed and late submissions are not accepted for this assignment.</div>}
        {a.is_past_deadline && a.allow_late && canSubmit && <div className="mb-4 flex items-start gap-2 rounded-xl bg-amber-50 p-3 text-sm text-amber-800"><AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />The deadline has passed. Your submission will be marked as late.</div>}
        {sub && <p className="mb-3 text-xs text-slate-500">Submitted {formatDateTime(sub.submitted_at)}</p>}
        {canSubmit ? (
          <div className="space-y-4">
            <Textarea label="Written answer" rows={6} value={value} onChange={(e) => setText(e.target.value)} placeholder="Type your answer here…" />
            <div>
              <FileUploader label="Attach a file (optional)" accept=".pdf,.doc,.docx,.zip,.txt,.png,.jpg,.jpeg" maxMB={25} onSelect={setFile} hint="PDF, DOC, ZIP, image or text — up to 25 MB" />
              {sub?.file_url && !file && <a href={assetUrl(sub.file_url)} target="_blank" rel="noopener noreferrer" className="mt-2 inline-flex items-center gap-1.5 text-sm text-brand-600 hover:underline"><Paperclip className="h-4 w-4" />Current file</a>}
            </div>
            {err && <p role="alert" className="text-sm text-rose-600">{err}</p>}
            <Button onClick={submit} loading={busy}>{sub ? "Resubmit" : "Submit assignment"}</Button>
          </div>
        ) : sub ? (
          <div className="space-y-3">
            {sub.text_answer && <p className="whitespace-pre-line rounded-xl bg-slate-50 p-4 text-slate-700">{sub.text_answer}</p>}
            {sub.file_url && <a href={assetUrl(sub.file_url)} target="_blank" rel="noopener noreferrer" className="inline-flex items-center gap-1.5 text-sm text-brand-600 hover:underline"><Paperclip className="h-4 w-4" />Submitted file</a>}
          </div>
        ) : null}
      </Card>
    </div>
  );
}
