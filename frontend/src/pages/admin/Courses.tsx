import { BookOpen, Eye, EyeOff, Layers, Pencil, Plus, Search, Trash2 } from "lucide-react";
import { useState, type FormEvent } from "react";
import { useNavigate } from "react-router-dom";
import { Badge, Button, Checkbox, ConfirmationModal, EmptyState, ErrorState, FileUploader, Input, Modal, PageHeader, Table, Textarea } from "../../components/ui";
import { useToast } from "../../context/ToastContext";
import { useAsync } from "../../hooks/useAsync";
import { useDebounce } from "../../hooks/useDebounce";
import { adminApi } from "../../services";
import { getErrorMessage } from "../../services/api";
import type { CourseCard } from "../../types";
import { formatDuration, formatPrice } from "../../utils/format";

interface Form { title: string; short_description: string; description: string; category: string; price: string; offline_price: string; duration_months: string; offline_only: boolean; thumbnail_url: string | null; features: string; is_published: boolean }
const empty: Form = { title: "", short_description: "", description: "", category: "General", price: "0", offline_price: "", duration_months: "", offline_only: false, thumbnail_url: null, features: "", is_published: false };

export default function AdminCourses() {
  const toast = useToast();
  const nav = useNavigate();
  const [search, setSearch] = useState("");
  const q = useDebounce(search, 300);
  const { data, loading, error, reload, reloadWithSpinner } = useAsync(() => adminApi.courses(q || undefined), [q]);
  const [editing, setEditing] = useState<{ id: string | null } | null>(null);
  const [form, setForm] = useState<Form>(empty);
  const [errs, setErrs] = useState<Record<string, string>>({});
  const [saving, setSaving] = useState(false);
  const [del, setDel] = useState<CourseCard | null>(null);
  const [deleting, setDeleting] = useState(false);

  async function openEdit(c: CourseCard | null) {
    setErrs({});
    if (!c) { setForm(empty); setEditing({ id: null }); return; }
    try {
      const full = await adminApi.course(c.id);
      setForm({ title: full.title, short_description: full.short_description, description: full.description, category: full.category, price: String(full.price), offline_price: full.offline_price == null ? "" : String(full.offline_price), duration_months: full.duration_months == null ? "" : String(full.duration_months), offline_only: full.offline_only, thumbnail_url: full.thumbnail_url, features: full.features.join("\n"), is_published: full.is_published });
      setEditing({ id: c.id });
    } catch (e) { toast.error(getErrorMessage(e)); }
  }

  async function save(e: FormEvent) {
    e.preventDefault();
    const er: Record<string, string> = {};
    if (form.title.trim().length < 3) er.title = "Title must be at least 3 characters";
    const price = Number(form.price);
    if (!form.offline_only && (Number.isNaN(price) || price < 0)) er.price = "Enter a valid price (0 for free)";
    const offline = form.offline_price.trim() === "" ? null : Number(form.offline_price);
    if (offline !== null && (Number.isNaN(offline) || offline < 0)) er.offline_price = "Enter a valid price";
    if (form.offline_only && !offline) er.offline_price = "An offline-only course needs an offline price";
    const months = form.duration_months.trim() === "" ? null : Number(form.duration_months);
    if (months !== null && (!Number.isInteger(months) || months < 1 || months > 60)) er.duration_months = "Enter whole months from 1 to 60";
    setErrs(er);
    if (Object.keys(er).length) return;
    const body = { ...form, title: form.title.trim(), price, offline_price: offline, duration_months: months, features: form.features.split("\n").map((f) => f.trim()).filter(Boolean) };
    setSaving(true);
    try {
      if (editing?.id) await adminApi.updateCourse(editing.id, body); else await adminApi.createCourse(body);
      toast.success(editing?.id ? "Course updated" : "Course created");
      setEditing(null); reload();
    } catch (e2) { toast.error(getErrorMessage(e2)); } finally { setSaving(false); }
  }

  async function togglePublish(c: CourseCard) {
    try { await adminApi.updateCourse(c.id, { is_published: !c.is_published }); toast.success(c.is_published ? "Course unpublished" : "Course published"); reload(); }
    catch (e) { toast.error(getErrorMessage(e)); }
  }
  async function remove() {
    if (!del) return;
    setDeleting(true);
    try { await adminApi.deleteCourse(del.id); toast.success("Course deleted"); setDel(null); reload(); }
    catch (e) { toast.error(getErrorMessage(e)); } finally { setDeleting(false); }
  }
  const set = <K extends keyof Form>(k: K, v: Form[K]) => setForm((f) => ({ ...f, [k]: v }));

  return (
    <div>
      <PageHeader title="Courses" subtitle="Create and manage your course catalog." actions={<Button icon={<Plus className="h-4 w-4" />} onClick={() => openEdit(null)}>New course</Button>} />
      <div className="mb-4 max-w-sm"><Input aria-label="Search courses" placeholder="Search courses…" icon={<Search className="h-4 w-4" />} value={search} onChange={(e) => setSearch(e.target.value)} /></div>
      {error ? <ErrorState message={error} onRetry={reloadWithSpinner} /> : (
        <Table<CourseCard> loading={loading} rows={data ?? []} rowKey={(c) => c.id}
          empty={<EmptyState icon={<BookOpen className="h-7 w-7" />} title="No courses found" message="Create your first course to get started." action={<Button onClick={() => openEdit(null)}>New course</Button>} />}
          columns={[
            { key: "t", header: "Course", render: (c) => <div><p className="font-semibold text-slate-900">{c.title}</p><p className="text-xs text-slate-500">{c.category}</p></div> },
            { key: "s", header: "Status", render: (c) => <Badge tone={c.is_published ? "green" : "slate"} dot>{c.is_published ? "Published" : "Draft"}</Badge> },
            { key: "p", header: "Online", render: (c) => (c.offline_only ? "—" : formatPrice(c.price)), hideOnMobile: true },
            { key: "o", header: "Offline", render: (c) => (c.offline_price == null ? "—" : formatPrice(c.offline_price)), hideOnMobile: true },
            { key: "d", header: "Length", render: (c) => (c.duration_months ? `${c.duration_months} mo` : "—"), hideOnMobile: true },
            { key: "l", header: "Lessons", render: (c) => `${c.lesson_count} · ${formatDuration(c.duration_seconds)}`, hideOnMobile: true },
            { key: "e", header: "Students", render: (c) => c.enrolled_count, hideOnMobile: true },
            { key: "a", header: "", className: "text-right", render: (c) => (
              <div className="flex justify-end gap-1">
                <Button size="sm" variant="ghost" aria-label="Manage content" title="Modules & lessons" onClick={() => nav(`/admin/content?course=${c.id}`)}><Layers className="h-4 w-4" /></Button>
                <Button size="sm" variant="ghost" aria-label={c.is_published ? "Unpublish" : "Publish"} title={c.is_published ? "Unpublish" : "Publish"} onClick={() => togglePublish(c)}>{c.is_published ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}</Button>
                <Button size="sm" variant="ghost" aria-label="Edit" onClick={() => openEdit(c)}><Pencil className="h-4 w-4" /></Button>
                <Button size="sm" variant="ghost" aria-label="Delete" onClick={() => setDel(c)}><Trash2 className="h-4 w-4 text-rose-600" /></Button>
              </div>) },
          ]} />
      )}

      <Modal open={!!editing} onClose={() => setEditing(null)} title={editing?.id ? "Edit course" : "New course"} size="lg"
        footer={<><Button variant="outline" onClick={() => setEditing(null)}>Cancel</Button><Button type="submit" form="course-form" loading={saving}>{editing?.id ? "Save changes" : "Create course"}</Button></>}>
        <form id="course-form" onSubmit={save} className="space-y-4">
          <Input label="Title" value={form.title} error={errs.title} onChange={(e) => set("title", e.target.value)} required />
          <Input label="Short description" maxLength={300} value={form.short_description} onChange={(e) => set("short_description", e.target.value)} />
          <Textarea label="Full description" rows={4} value={form.description} onChange={(e) => set("description", e.target.value)} />
          <div className="grid gap-4 sm:grid-cols-2">
            <Input label="Category" value={form.category} onChange={(e) => set("category", e.target.value)} />
            {!form.offline_only && <Input label="Online price (₹)" type="number" min={0} step="1" value={form.price} error={errs.price} hint="0 = free" onChange={(e) => set("price", e.target.value)} />}
            <Input label="Offline price (₹)" type="number" min={0} step="1" value={form.offline_price} error={errs.offline_price} hint={form.offline_only ? undefined : "Leave empty to show “Contact us”"} onChange={(e) => set("offline_price", e.target.value)} />
            <Input label="Length (months)" type="number" min={1} max={60} step="1" value={form.duration_months} error={errs.duration_months} hint="Leave empty to hide" onChange={(e) => set("duration_months", e.target.value)} />
          </div>
          <Checkbox label="Offline only" hint="Only the offline price is shown and sold." checked={form.offline_only} onChange={(v) => set("offline_only", v)} />
          <Textarea label="What students will learn" rows={3} hint="One item per line" value={form.features} onChange={(e) => set("features", e.target.value)} />
          <FileUploader label="Thumbnail" image accept="image/png,image/jpeg,image/webp" maxMB={5} value={form.thumbnail_url} onChange={(u) => set("thumbnail_url", u)} onUpload={async (f) => (await adminApi.upload("thumbnail", f)).url} />
          <Checkbox label="Published" hint="Visible in the public catalog" checked={form.is_published} onChange={(v) => set("is_published", v)} />
        </form>
      </Modal>
      <ConfirmationModal open={!!del} danger title="Delete course?" message={<>This permanently deletes <strong>{del?.title}</strong> along with its lessons, enrollments and progress.</>} confirmLabel="Delete" loading={deleting} onConfirm={remove} onCancel={() => setDel(null)} />
    </div>
  );
}
