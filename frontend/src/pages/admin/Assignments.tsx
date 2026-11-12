import { ClipboardList, Pencil, Plus, Trash2 } from "lucide-react";
import { useState, type FormEvent } from "react";
import { Link } from "react-router-dom";
import { Badge, Button, Checkbox, ConfirmationModal, EmptyState, ErrorState, FileUploader, Input, Modal, PageHeader, Select, Table, Textarea } from "../../components/ui";
import { useToast } from "../../context/ToastContext";
import { useAsync } from "../../hooks/useAsync";
import { adminApi } from "../../services";
import { getErrorMessage } from "../../services/api";
import type { AdminAssignment } from "../../types";
import { formatDateTime, fromLocalInput, toLocalInput } from "../../utils/format";

interface Form { course_id: string; title: string; instructions: string; deadline: string; max_marks: string; allow_late: boolean; attachment_url: string | null }

export default function AdminAssignments() {
  const toast = useToast();
  const list = useAsync(adminApi.assignments);
  const courses = useAsync(() => adminApi.courses());
  const [editing, setEditing] = useState<{ id: string | null } | null>(null);
  const [form, setForm] = useState<Form>({ course_id: "", title: "", instructions: "", deadline: "", max_marks: "100", allow_late: false, attachment_url: null });
  const [saving, setSaving] = useState(false);
  const [del, setDel] = useState<AdminAssignment | null>(null);
  const [deleting, setDeleting] = useState(false);

  function open(a?: AdminAssignment) {
    const d = new Date(Date.now() + 7 * 86400000); d.setHours(23, 59, 0, 0);
    setForm(a ? { course_id: a.course_id, title: a.title, instructions: a.instructions, deadline: toLocalInput(a.deadline), max_marks: String(a.max_marks), allow_late: a.allow_late, attachment_url: a.attachment_url }
      : { course_id: courses.data?.[0]?.id ?? "", title: "", instructions: "", deadline: toLocalInput(d.toISOString()), max_marks: "100", allow_late: false, attachment_url: null });
    setEditing({ id: a?.id ?? null });
  }
  async function save(e: FormEvent) {
    e.preventDefault();
    const marks = Number(form.max_marks);
    if (!form.course_id) { toast.error("Choose a course"); return; }
    if (!Number.isInteger(marks) || marks < 1) { toast.error("Max marks must be a whole number ≥ 1"); return; }
    const body = { ...form, max_marks: marks, deadline: fromLocalInput(form.deadline) };
    setSaving(true);
    try {
      if (editing?.id) await adminApi.updateAssignment(editing.id, body); else await adminApi.createAssignment(body);
      toast.success(editing?.id ? "Assignment updated" : "Assignment created"); setEditing(null); list.reload();
    } catch (e2) { toast.error(getErrorMessage(e2)); } finally { setSaving(false); }
  }
  async function remove() {
    if (!del) return; setDeleting(true);
    try { await adminApi.deleteAssignment(del.id); toast.success("Assignment deleted"); setDel(null); list.reload(); }
    catch (e) { toast.error(getErrorMessage(e)); } finally { setDeleting(false); }
  }
  const set = <K extends keyof Form>(k: K, v: Form[K]) => setForm((f) => ({ ...f, [k]: v }));

  return (
    <div>
      <PageHeader title="Assignments" subtitle="Create assignments and set deadlines." actions={<Button icon={<Plus className="h-4 w-4" />} onClick={() => open()}>New assignment</Button>} />
      {list.error ? <ErrorState message={list.error} onRetry={list.reloadWithSpinner} /> : (
        <Table<AdminAssignment> loading={list.loading} rows={list.data ?? []} rowKey={(a) => a.id}
          empty={<EmptyState icon={<ClipboardList className="h-7 w-7" />} title="No assignments" message="Create an assignment for one of your courses." />}
          columns={[
            { key: "t", header: "Assignment", render: (a) => <div><p className="font-semibold text-slate-900">{a.title}</p><p className="text-xs text-slate-500">{a.course_title}</p></div> },
            { key: "d", header: "Deadline", render: (a) => <span className="text-sm">{formatDateTime(a.deadline)}{a.allow_late && <Badge tone="amber" className="ml-2">Late OK</Badge>}</span>, hideOnMobile: true },
            { key: "m", header: "Marks", render: (a) => a.max_marks, hideOnMobile: true },
            { key: "s", header: "Submissions", render: (a) => <Link className="text-brand-600 hover:underline" to={`/admin/submissions?assignment=${a.id}`}>{a.submission_count}{a.pending_count > 0 && <Badge tone="amber" className="ml-2">{a.pending_count} to review</Badge>}</Link> },
            { key: "a", header: "", className: "text-right", render: (a) => <div className="flex justify-end gap-1"><Button size="sm" variant="ghost" aria-label="Edit" onClick={() => open(a)}><Pencil className="h-4 w-4" /></Button><Button size="sm" variant="ghost" aria-label="Delete" onClick={() => setDel(a)}><Trash2 className="h-4 w-4 text-rose-600" /></Button></div> },
          ]} />
      )}
      <Modal open={!!editing} onClose={() => setEditing(null)} title={editing?.id ? "Edit assignment" : "New assignment"} size="lg"
        footer={<><Button variant="outline" onClick={() => setEditing(null)}>Cancel</Button><Button type="submit" form="asg-form" loading={saving}>Save</Button></>}>
        <form id="asg-form" onSubmit={save} className="space-y-4">
          <Select label="Course" value={form.course_id} onChange={(e) => set("course_id", e.target.value)} required>{courses.data?.map((c) => <option key={c.id} value={c.id}>{c.title}</option>)}</Select>
          <Input label="Title" value={form.title} onChange={(e) => set("title", e.target.value)} required minLength={3} />
          <Textarea label="Instructions" rows={4} value={form.instructions} onChange={(e) => set("instructions", e.target.value)} />
          <div className="grid gap-4 sm:grid-cols-2">
            <Input label="Deadline" type="datetime-local" value={form.deadline} onChange={(e) => set("deadline", e.target.value)} required />
            <Input label="Max marks" type="number" min={1} max={1000} value={form.max_marks} onChange={(e) => set("max_marks", e.target.value)} required />
          </div>
          <Checkbox label="Allow late submissions" hint="Late work is accepted and flagged" checked={form.allow_late} onChange={(v) => set("allow_late", v)} />
          <FileUploader label="Attachment (optional)" accept=".pdf,.doc,.docx,.zip,.txt,.png,.jpg" maxMB={25} value={form.attachment_url} onChange={(u) => set("attachment_url", u)} onUpload={async (f) => (await adminApi.upload("attachment", f)).url} />
        </form>
      </Modal>
      <ConfirmationModal open={!!del} danger title="Delete assignment?" message={<>Delete <strong>{del?.title}</strong> and all {del?.submission_count} submission(s)?</>} confirmLabel="Delete" loading={deleting} onConfirm={remove} onCancel={() => setDel(null)} />
    </div>
  );
}
