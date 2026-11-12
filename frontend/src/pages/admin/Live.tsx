import { CalendarDays, Pencil, Plus, Trash2 } from "lucide-react";
import { useState, type FormEvent } from "react";
import { Badge, Button, ConfirmationModal, EmptyState, ErrorState, Input, Modal, PageHeader, Select, Table, Textarea } from "../../components/ui";
import { useToast } from "../../context/ToastContext";
import { useAsync } from "../../hooks/useAsync";
import { adminApi } from "../../services";
import { getErrorMessage } from "../../services/api";
import type { LiveClass } from "../../types";
import { formatDateTime, fromLocalInput, toLocalInput } from "../../utils/format";

interface Form { course_id: string; title: string; description: string; starts_at: string; ends_at: string; meeting_url: string; platform: string }
const tone = { upcoming: "blue", live: "red", completed: "slate" } as const;

export default function AdminLive() {
  const toast = useToast();
  const list = useAsync(adminApi.liveClasses);
  const courses = useAsync(() => adminApi.courses());
  const [editing, setEditing] = useState<{ id: string | null } | null>(null);
  const [form, setForm] = useState<Form>({ course_id: "", title: "", description: "", starts_at: "", ends_at: "", meeting_url: "", platform: "Zoom" });
  const [saving, setSaving] = useState(false);
  const [del, setDel] = useState<LiveClass | null>(null);
  const [deleting, setDeleting] = useState(false);

  function open(c?: LiveClass) {
    const start = new Date(Date.now() + 86400000); start.setMinutes(0, 0, 0);
    const end = new Date(start.getTime() + 3600000);
    setForm(c ? { course_id: c.course_id, title: c.title, description: c.description, starts_at: toLocalInput(c.starts_at), ends_at: toLocalInput(c.ends_at), meeting_url: c.meeting_url ?? "", platform: c.platform }
      : { course_id: courses.data?.[0]?.id ?? "", title: "", description: "", starts_at: toLocalInput(start.toISOString()), ends_at: toLocalInput(end.toISOString()), meeting_url: "", platform: "Zoom" });
    setEditing({ id: c?.id ?? null });
  }
  async function save(e: FormEvent) {
    e.preventDefault();
    if (!form.course_id) { toast.error("Choose a course"); return; }
    if (new Date(form.ends_at) <= new Date(form.starts_at)) { toast.error("End time must be after start time"); return; }
    const body = { ...form, starts_at: fromLocalInput(form.starts_at), ends_at: fromLocalInput(form.ends_at) };
    setSaving(true);
    try {
      if (editing?.id) await adminApi.updateLive(editing.id, body); else await adminApi.createLive(body);
      toast.success(editing?.id ? "Live class updated" : "Live class scheduled"); setEditing(null); list.reload();
    } catch (e2) { toast.error(getErrorMessage(e2)); } finally { setSaving(false); }
  }
  async function remove() {
    if (!del) return; setDeleting(true);
    try { await adminApi.deleteLive(del.id); toast.success("Live class deleted"); setDel(null); list.reload(); }
    catch (e) { toast.error(getErrorMessage(e)); } finally { setDeleting(false); }
  }
  const set = <K extends keyof Form>(k: K, v: Form[K]) => setForm((f) => ({ ...f, [k]: v }));

  return (
    <div>
      <PageHeader title="Live classes" subtitle="Schedule sessions. Students get a reminder and the join link unlocks 15 minutes early." actions={<Button icon={<Plus className="h-4 w-4" />} onClick={() => open()}>Schedule class</Button>} />
      {list.error ? <ErrorState message={list.error} onRetry={list.reloadWithSpinner} /> : (
        <Table<LiveClass> loading={list.loading} rows={list.data ?? []} rowKey={(c) => c.id}
          empty={<EmptyState icon={<CalendarDays className="h-7 w-7" />} title="No live classes" message="Schedule your first live session." />}
          columns={[
            { key: "t", header: "Class", render: (c) => <div><p className="font-semibold text-slate-900">{c.title}</p><p className="text-xs text-slate-500">{c.course_title}</p></div> },
            { key: "w", header: "When", render: (c) => <span className="text-sm">{formatDateTime(c.starts_at)}<br /><span className="text-xs text-slate-500">{c.duration_minutes} min · {c.platform}</span></span> },
            { key: "s", header: "Status", render: (c) => <Badge tone={tone[c.status]} dot>{c.status === "live" ? "Live now" : c.status[0].toUpperCase() + c.status.slice(1)}</Badge> },
            { key: "a", header: "", className: "text-right", render: (c) => <div className="flex justify-end gap-1"><Button size="sm" variant="ghost" aria-label="Edit" onClick={() => open(c)}><Pencil className="h-4 w-4" /></Button><Button size="sm" variant="ghost" aria-label="Delete" onClick={() => setDel(c)}><Trash2 className="h-4 w-4 text-rose-600" /></Button></div> },
          ]} />
      )}
      <Modal open={!!editing} onClose={() => setEditing(null)} title={editing?.id ? "Edit live class" : "Schedule live class"} size="lg"
        footer={<><Button variant="outline" onClick={() => setEditing(null)}>Cancel</Button><Button type="submit" form="live-form" loading={saving}>Save</Button></>}>
        <form id="live-form" onSubmit={save} className="space-y-4">
          <Select label="Course" value={form.course_id} onChange={(e) => set("course_id", e.target.value)} required>{courses.data?.map((c) => <option key={c.id} value={c.id}>{c.title}</option>)}</Select>
          <Input label="Title" value={form.title} onChange={(e) => set("title", e.target.value)} required minLength={3} />
          <Textarea label="Description" rows={2} value={form.description} onChange={(e) => set("description", e.target.value)} />
          <div className="grid gap-4 sm:grid-cols-2">
            <Input label="Starts" type="datetime-local" value={form.starts_at} onChange={(e) => set("starts_at", e.target.value)} required />
            <Input label="Ends" type="datetime-local" value={form.ends_at} onChange={(e) => set("ends_at", e.target.value)} required />
          </div>
          <div className="grid gap-4 sm:grid-cols-3">
            <div className="sm:col-span-2"><Input label="Meeting URL" type="url" placeholder="https://zoom.us/j/…" value={form.meeting_url} onChange={(e) => set("meeting_url", e.target.value)} required /></div>
            <Select label="Platform" value={form.platform} onChange={(e) => set("platform", e.target.value)}>{["Zoom", "Google Meet", "Microsoft Teams", "Other"].map((p) => <option key={p}>{p}</option>)}</Select>
          </div>
        </form>
      </Modal>
      <ConfirmationModal open={!!del} danger title="Delete live class?" message={<>Delete <strong>{del?.title}</strong>?</>} confirmLabel="Delete" loading={deleting} onConfirm={remove} onCancel={() => setDel(null)} />
    </div>
  );
}
