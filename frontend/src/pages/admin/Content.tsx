import { ArrowDown, ArrowUp, FileText, Layers, Pencil, Plus, Trash2, Video } from "lucide-react";
import { useState, type FormEvent } from "react";
import { useSearchParams } from "react-router-dom";
import { Badge, Button, Card, Checkbox, ConfirmationModal, EmptyState, ErrorState, FileUploader, Input, Modal, PageHeader, PageLoader, Select, Textarea } from "../../components/ui";
import { useToast } from "../../context/ToastContext";
import { useAsync } from "../../hooks/useAsync";
import { adminApi } from "../../services";
import { getErrorMessage, isUploadedVideo } from "../../services/api";
import type { Lesson, Module, Resource } from "../../types";
import { formatDuration } from "../../utils/format";

interface LForm { title: string; description: string; video_url: string | null; video_source: "upload" | "url"; minutes: string; is_free_preview: boolean }
const emptyL: LForm = { title: "", description: "", video_url: null, video_source: "upload", minutes: "0", is_free_preview: false };

export default function AdminContent() {
  const toast = useToast();
  const [params, setParams] = useSearchParams();
  const courses = useAsync(() => adminApi.courses());
  const courseId = params.get("course") ?? courses.data?.[0]?.id ?? "";
  const detail = useAsync(() => (courseId ? adminApi.course(courseId) : Promise.resolve(null)), [courseId]);

  const [modModal, setModModal] = useState<{ id: string | null; title: string } | null>(null);
  const [lesModal, setLesModal] = useState<{ moduleId: string; id: string | null; resources: Resource[] } | null>(null);
  const [lForm, setLForm] = useState<LForm>(emptyL);
  const [resTitle, setResTitle] = useState("");
  const [saving, setSaving] = useState(false);
  const [del, setDel] = useState<{ kind: "module" | "lesson"; id: string; label: string } | null>(null);
  const [deleting, setDeleting] = useState(false);

  const mods: Module[] = detail.data?.modules ?? [];
  const guard = async (fn: () => Promise<unknown>, ok?: string) => {
    try { await fn(); if (ok) toast.success(ok); detail.reload(); return true; } catch (e) { toast.error(getErrorMessage(e)); return false; }
  };

  async function saveModule(e: FormEvent) {
    e.preventDefault();
    if (!modModal || !modModal.title.trim()) return;
    setSaving(true);
    const ok = await guard(() => (modModal.id ? adminApi.updateModule(modModal.id, modModal.title.trim()) : adminApi.createModule(courseId, modModal.title.trim())), modModal.id ? "Module renamed" : "Module added");
    setSaving(false); if (ok) setModModal(null);
  }
  function move<T extends { id: string }>(list: T[], i: number, dir: -1 | 1) {
    const j = i + dir; if (j < 0 || j >= list.length) return null;
    const ids = list.map((x) => x.id); [ids[i], ids[j]] = [ids[j], ids[i]]; return ids;
  }
  function openLesson(moduleId: string, l?: Lesson) {
    setResTitle("");
    const videoUrl = l?.video_url ?? null;
    setLForm(l ? { title: l.title, description: l.description ?? "", video_url: videoUrl, video_source: isUploadedVideo(videoUrl) ? "upload" : "url", minutes: String(Math.round(l.duration_seconds / 60)), is_free_preview: l.is_free_preview } : emptyL);
    setLesModal({ moduleId, id: l?.id ?? null, resources: l?.resources ?? [] });
  }
  async function saveLesson(e: FormEvent) {
    e.preventDefault();
    if (!lesModal) return;
    if (!lForm.title.trim()) { toast.error("Lesson title is required"); return; }
    const body = { title: lForm.title.trim(), description: lForm.description, video_url: lForm.video_url || null, duration_seconds: Math.max(0, Math.round(Number(lForm.minutes) || 0) * 60), is_free_preview: lForm.is_free_preview };
    setSaving(true);
    const ok = await guard(() => (lesModal.id ? adminApi.updateLesson(lesModal.id, body) : adminApi.createLesson(lesModal.moduleId, body)), lesModal.id ? "Lesson updated" : "Lesson added");
    setSaving(false); if (ok) setLesModal(null);
  }
  async function addResource(file: string) {
    if (!lesModal?.id) return;
    const title = resTitle.trim() || "Resource";
    const ok = await guard(() => adminApi.addResource(lesModal.id!, { title, file_url: file }), "Resource added");
    if (ok) { setResTitle(""); const fresh = await adminApi.course(courseId); const l = fresh.modules.flatMap((m) => m.lessons).find((x) => x.id === lesModal.id); setLesModal((m) => m && { ...m, resources: l?.resources ?? [] }); }
  }
  async function removeResource(id: string) {
    const ok = await guard(() => adminApi.deleteResource(id), "Resource removed");
    if (ok) setLesModal((m) => m && { ...m, resources: m.resources.filter((r) => r.id !== id) });
  }
  async function confirmDelete() {
    if (!del) return;
    setDeleting(true);
    await guard(() => (del.kind === "module" ? adminApi.deleteModule(del.id) : adminApi.deleteLesson(del.id)), `${del.kind === "module" ? "Module" : "Lesson"} deleted`);
    setDeleting(false); setDel(null);
  }

  if (courses.loading) return <PageLoader />;
  if (courses.error) return <ErrorState message={courses.error} onRetry={courses.reloadWithSpinner} />;
  if (!courses.data?.length) return <EmptyState icon={<Layers className="h-7 w-7" />} title="No courses yet" message="Create a course first, then add modules and lessons." />;

  return (
    <div>
      <PageHeader title="Modules & Lessons" subtitle="Build your course curriculum." actions={<Button icon={<Plus className="h-4 w-4" />} onClick={() => setModModal({ id: null, title: "" })} disabled={!courseId}>Add module</Button>} />
      <div className="mb-6 max-w-md"><Select label="Course" value={courseId} onChange={(e) => setParams({ course: e.target.value })}>{courses.data.map((c) => <option key={c.id} value={c.id}>{c.title}</option>)}</Select></div>
      {detail.error ? <ErrorState message={detail.error} onRetry={detail.reloadWithSpinner} /> : detail.loading ? <PageLoader /> : mods.length === 0 ? (
        <EmptyState icon={<Layers className="h-7 w-7" />} title="No modules yet" message="Add a module, then fill it with lessons." action={<Button onClick={() => setModModal({ id: null, title: "" })}>Add module</Button>} />
      ) : (
        <div className="space-y-4">
          {mods.map((m, mi) => (
            <Card key={m.id} padded={false}>
              <div className="flex items-center gap-2 border-b border-slate-100 px-4 py-3">
                <h2 className="flex-1 font-bold text-slate-900">Module {mi + 1}: {m.title}</h2>
                <Button size="sm" variant="ghost" aria-label="Move module up" disabled={mi === 0} onClick={() => { const ids = move(mods, mi, -1); ids && guard(() => adminApi.reorderModules(courseId, ids)); }}><ArrowUp className="h-4 w-4" /></Button>
                <Button size="sm" variant="ghost" aria-label="Move module down" disabled={mi === mods.length - 1} onClick={() => { const ids = move(mods, mi, 1); ids && guard(() => adminApi.reorderModules(courseId, ids)); }}><ArrowDown className="h-4 w-4" /></Button>
                <Button size="sm" variant="ghost" aria-label="Rename module" onClick={() => setModModal({ id: m.id, title: m.title })}><Pencil className="h-4 w-4" /></Button>
                <Button size="sm" variant="ghost" aria-label="Delete module" onClick={() => setDel({ kind: "module", id: m.id, label: m.title })}><Trash2 className="h-4 w-4 text-rose-600" /></Button>
              </div>
              <ul className="divide-y divide-slate-100">
                {m.lessons.length === 0 && <li className="px-4 py-4 text-sm text-slate-500">No lessons in this module.</li>}
                {m.lessons.map((l, li) => (
                  <li key={l.id} className="flex items-center gap-3 px-4 py-3">
                    <Video className="h-4 w-4 shrink-0 text-slate-400" />
                    <div className="min-w-0 flex-1">
                      <p className="truncate text-sm font-medium text-slate-900">{l.title}</p>
                      <p className="text-xs text-slate-500">{formatDuration(l.duration_seconds)}{l.resources && l.resources.length > 0 && ` · ${l.resources.length} resource(s)`}</p>
                    </div>
                    {l.is_free_preview && <Badge tone="green">Free preview</Badge>}
                    {!l.video_url && <Badge tone="amber">No video</Badge>}
                    <Button size="sm" variant="ghost" aria-label="Move lesson up" disabled={li === 0} onClick={() => { const ids = move(m.lessons, li, -1); ids && guard(() => adminApi.reorderLessons(m.id, ids)); }}><ArrowUp className="h-4 w-4" /></Button>
                    <Button size="sm" variant="ghost" aria-label="Move lesson down" disabled={li === m.lessons.length - 1} onClick={() => { const ids = move(m.lessons, li, 1); ids && guard(() => adminApi.reorderLessons(m.id, ids)); }}><ArrowDown className="h-4 w-4" /></Button>
                    <Button size="sm" variant="ghost" aria-label="Edit lesson" onClick={() => openLesson(m.id, l)}><Pencil className="h-4 w-4" /></Button>
                    <Button size="sm" variant="ghost" aria-label="Delete lesson" onClick={() => setDel({ kind: "lesson", id: l.id, label: l.title })}><Trash2 className="h-4 w-4 text-rose-600" /></Button>
                  </li>
                ))}
              </ul>
              <div className="border-t border-slate-100 px-4 py-2"><Button size="sm" variant="ghost" icon={<Plus className="h-4 w-4" />} onClick={() => openLesson(m.id)}>Add lesson</Button></div>
            </Card>
          ))}
        </div>
      )}

      <Modal open={!!modModal} onClose={() => setModModal(null)} title={modModal?.id ? "Rename module" : "New module"} size="sm"
        footer={<><Button variant="outline" onClick={() => setModModal(null)}>Cancel</Button><Button type="submit" form="mod-form" loading={saving}>Save</Button></>}>
        <form id="mod-form" onSubmit={saveModule}><Input label="Module title" autoFocus value={modModal?.title ?? ""} onChange={(e) => setModModal((m) => m && { ...m, title: e.target.value })} required /></form>
      </Modal>

      <Modal open={!!lesModal} onClose={() => setLesModal(null)} title={lesModal?.id ? "Edit lesson" : "New lesson"} size="lg"
        footer={<><Button variant="outline" onClick={() => setLesModal(null)}>Cancel</Button><Button type="submit" form="les-form" loading={saving}>{lesModal?.id ? "Save changes" : "Add lesson"}</Button></>}>
        <form id="les-form" onSubmit={saveLesson} className="space-y-4">
          <Input label="Lesson title" value={lForm.title} onChange={(e) => setLForm({ ...lForm, title: e.target.value })} required />
          <Textarea label="Description" rows={3} value={lForm.description} onChange={(e) => setLForm({ ...lForm, description: e.target.value })} />
          <Select label="Video source" value={lForm.video_source} onChange={(e) => setLForm({ ...lForm, video_source: e.target.value as LForm["video_source"], video_url: null })}>
            <option value="upload">Upload a video file</option>
            <option value="url">Use a video URL</option>
          </Select>
          {lForm.video_source === "url" ? (
            <Input label="Video URL" type="url" placeholder="https://… (MP4, YouTube or Vimeo link)" value={lForm.video_url ?? ""} onChange={(e) => setLForm({ ...lForm, video_url: e.target.value || null })} hint="Paste a direct video, YouTube, or Vimeo link." />
          ) : (
            <FileUploader label="Upload video" accept="video/mp4,video/webm,video/quicktime" maxMB={500} onUpload={async (f) => { const u = (await adminApi.upload("video", f)).url; setLForm((x) => ({ ...x, video_url: u })); return u; }} value={isUploadedVideo(lForm.video_url) ? lForm.video_url : null} onChange={(u) => u === null && setLForm((x) => ({ ...x, video_url: null }))} />
          )}
          <Input label="Duration (minutes)" type="number" min={0} value={lForm.minutes} onChange={(e) => setLForm({ ...lForm, minutes: e.target.value })} />
          <Checkbox label="Free preview" hint="Anyone can watch this lesson without enrolling" checked={lForm.is_free_preview} onChange={(v) => setLForm({ ...lForm, is_free_preview: v })} />
        </form>
        <div className="mt-6 border-t border-slate-100 pt-4">
          <h3 className="mb-2 flex items-center gap-2 text-sm font-semibold text-slate-900"><FileText className="h-4 w-4" />Resources (PDFs, files)</h3>
          {!lesModal?.id ? <p className="text-sm text-slate-500">Save the lesson first, then attach resources.</p> : (
            <>
              <ul className="mb-3 space-y-1">
                {lesModal.resources.map((r) => <li key={r.id} className="flex items-center justify-between rounded-lg bg-slate-50 px-3 py-2 text-sm"><span className="truncate">{r.title}</span><Button size="sm" variant="ghost" aria-label={`Remove ${r.title}`} onClick={() => removeResource(r.id)}><Trash2 className="h-4 w-4 text-rose-600" /></Button></li>)}
                {lesModal.resources.length === 0 && <li className="text-sm text-slate-500">No resources attached.</li>}
              </ul>
              <Input label="Resource title" value={resTitle} onChange={(e) => setResTitle(e.target.value)} placeholder="e.g. Lecture slides" />
              <div className="mt-2"><FileUploader label="Upload file" accept=".pdf,.doc,.docx,.ppt,.pptx,.zip,.txt,.png,.jpg" maxMB={50} onUpload={async (f) => { const u = (await adminApi.upload("resource", f)).url; await addResource(u); return u; }} /></div>
            </>
          )}
        </div>
      </Modal>
      <ConfirmationModal open={!!del} danger title={`Delete ${del?.kind}?`} message={<>Delete <strong>{del?.label}</strong>? {del?.kind === "module" ? "All lessons inside it are removed too." : "Student progress for this lesson is removed."}</>} confirmLabel="Delete" loading={deleting} onConfirm={confirmDelete} onCancel={() => setDel(null)} />
    </div>
  );
}
