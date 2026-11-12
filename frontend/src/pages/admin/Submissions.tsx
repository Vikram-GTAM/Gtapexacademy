import { ClipboardCheck, Download, Search } from "lucide-react";
import { useState, type FormEvent } from "react";
import { useSearchParams } from "react-router-dom";
import { Badge, Button, EmptyState, ErrorState, Input, Modal, PageHeader, Pagination, Select, Table, Textarea } from "../../components/ui";
import { useToast } from "../../context/ToastContext";
import { useAsync } from "../../hooks/useAsync";
import { useDebounce } from "../../hooks/useDebounce";
import { adminApi } from "../../services";
import { assetUrl, getErrorMessage } from "../../services/api";
import type { AdminSubmission } from "../../types";
import { formatDateTime } from "../../utils/format";

export default function AdminSubmissions() {
  const toast = useToast();
  const [sp] = useSearchParams();
  const assignment = sp.get("assignment") ?? "";
  const [status, setStatus] = useState("");
  const [search, setSearch] = useState("");
  const [page, setPage] = useState(1);
  const q = useDebounce(search, 300);
  const { data, loading, error, reload, reloadWithSpinner } = useAsync(
    () => adminApi.submissions({ page, page_size: 15, status: status || undefined, search: q || undefined, assignment_id: assignment || undefined }), [page, status, q, assignment]);
  const [active, setActive] = useState<AdminSubmission | null>(null);
  const [marks, setMarks] = useState("");
  const [feedback, setFeedback] = useState("");
  const [saving, setSaving] = useState(false);

  function open(s: AdminSubmission) { setActive(s); setMarks(s.marks != null ? String(s.marks) : ""); setFeedback(s.feedback ?? ""); }
  async function grade(e: FormEvent) {
    e.preventDefault();
    if (!active) return;
    const m = Number(marks);
    if (marks === "" || Number.isNaN(m) || m < 0 || m > active.max_marks) { toast.error(`Marks must be between 0 and ${active.max_marks}`); return; }
    setSaving(true);
    try { await adminApi.grade(active.id, { marks: m, feedback }); toast.success("Grade saved — student notified"); setActive(null); reload(); }
    catch (e2) { toast.error(getErrorMessage(e2)); } finally { setSaving(false); }
  }
  async function markReviewed() {
    if (!active) return; setSaving(true);
    try { await adminApi.markReviewed(active.id); toast.success("Marked as reviewed"); setActive(null); reload(); }
    catch (e) { toast.error(getErrorMessage(e)); } finally { setSaving(false); }
  }

  return (
    <div>
      <PageHeader title="Submissions" subtitle="Review student work, grade it and leave feedback." />
      <div className="mb-4 flex flex-col gap-3 sm:flex-row">
        <div className="flex-1 sm:max-w-sm"><Input aria-label="Search" placeholder="Search student or assignment…" icon={<Search className="h-4 w-4" />} value={search} onChange={(e) => { setSearch(e.target.value); setPage(1); }} /></div>
        <div className="sm:w-48"><Select aria-label="Status" value={status} onChange={(e) => { setStatus(e.target.value); setPage(1); }}><option value="">All statuses</option><option value="submitted">Needs review</option><option value="reviewed">Reviewed</option></Select></div>
      </div>
      {error ? <ErrorState message={error} onRetry={reloadWithSpinner} /> : (
        <>
          <Table<AdminSubmission> loading={loading} rows={data?.items ?? []} rowKey={(s) => s.id} onRowClick={open}
            empty={<EmptyState icon={<ClipboardCheck className="h-7 w-7" />} title="No submissions" message="Student submissions will appear here." />}
            columns={[
              { key: "s", header: "Student", render: (s) => <div><p className="font-semibold text-slate-900">{s.student_name}</p><p className="text-xs text-slate-500">{s.student_email}</p></div> },
              { key: "a", header: "Assignment", render: (s) => <div><p className="text-sm">{s.assignment_title}</p><p className="text-xs text-slate-500">{s.course_title}</p></div>, hideOnMobile: true },
              { key: "d", header: "Submitted", render: (s) => <span className="text-sm">{formatDateTime(s.submitted_at)}{s.is_late && <Badge tone="amber" className="ml-2">Late</Badge>}</span>, hideOnMobile: true },
              { key: "g", header: "Status", render: (s) => s.status === "reviewed" ? <Badge tone="green">{s.marks ?? "–"}/{s.max_marks}</Badge> : <Badge tone="blue">Needs review</Badge> },
            ]} />
          {data && <div className="mt-4"><Pagination page={data.page} pages={data.pages} onChange={setPage} /></div>}
        </>
      )}
      <Modal open={!!active} onClose={() => setActive(null)} title="Review submission" size="lg"
        footer={<><Button variant="outline" onClick={() => setActive(null)}>Close</Button>{active?.status === "submitted" && <Button variant="secondary" onClick={markReviewed} loading={saving}>Mark reviewed</Button>}<Button type="submit" form="grade-form" loading={saving}>Save grade</Button></>}>
        {active && (
          <div className="space-y-4">
            <div className="rounded-xl bg-slate-50 p-3 text-sm"><p className="font-semibold text-slate-900">{active.student_name} <span className="font-normal text-slate-500">· {active.student_email}</span></p><p className="text-slate-600">{active.assignment_title} — {active.course_title}</p><p className="text-xs text-slate-500">Submitted {formatDateTime(active.submitted_at)}{active.is_late && " (late)"}</p></div>
            <div><p className="mb-1 text-xs font-semibold uppercase tracking-wide text-slate-500">Written answer</p>{active.text_answer ? <p className="whitespace-pre-line rounded-xl border border-slate-200 p-3 text-sm text-slate-700">{active.text_answer}</p> : <p className="text-sm text-slate-400">No written answer.</p>}</div>
            {active.file_url && <a href={assetUrl(active.file_url)} target="_blank" rel="noopener noreferrer" className="inline-flex items-center gap-2 rounded-lg border border-slate-200 px-3 py-2 text-sm font-medium text-slate-700 hover:bg-white/5"><Download className="h-4 w-4" />Download submitted file</a>}
            <form id="grade-form" onSubmit={grade} className="grid gap-4 border-t border-slate-100 pt-4 sm:grid-cols-4">
              <Input label={`Marks (max ${active.max_marks})`} type="number" min={0} max={active.max_marks} step="0.5" value={marks} onChange={(e) => setMarks(e.target.value)} required />
              <div className="sm:col-span-3"><Textarea label="Feedback" rows={3} value={feedback} onChange={(e) => setFeedback(e.target.value)} placeholder="Share what went well and what to improve…" /></div>
            </form>
          </div>
        )}
      </Modal>
    </div>
  );
}
