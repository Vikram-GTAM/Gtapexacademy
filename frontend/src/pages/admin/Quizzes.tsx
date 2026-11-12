import { BarChart3, HelpCircle, Pencil, Plus, Trash2, X } from "lucide-react";
import { useState, type FormEvent } from "react";
import { Badge, Button, Checkbox, ConfirmationModal, EmptyState, ErrorState, Input, Modal, PageHeader, Select, Table, Textarea } from "../../components/ui";
import { useToast } from "../../context/ToastContext";
import { useAsync } from "../../hooks/useAsync";
import { adminApi } from "../../services";
import { getErrorMessage } from "../../services/api";
import type { QuizAdmin } from "../../types";
import { formatDateTime } from "../../utils/format";

interface QForm { text: string; marks: string; options: { text: string; is_correct: boolean }[] }
interface Form { course_id: string; title: string; description: string; time_limit_minutes: string; show_results: boolean; is_published: boolean; questions: QForm[] }
const newQ = (): QForm => ({ text: "", marks: "1", options: [{ text: "", is_correct: true }, { text: "", is_correct: false }, { text: "", is_correct: false }, { text: "", is_correct: false }] });

export default function AdminQuizzes() {
  const toast = useToast();
  const list = useAsync(adminApi.quizzes);
  const courses = useAsync(() => adminApi.courses());
  const [editing, setEditing] = useState<{ id: string | null } | null>(null);
  const [form, setForm] = useState<Form>({ course_id: "", title: "", description: "", time_limit_minutes: "0", show_results: true, is_published: true, questions: [newQ()] });
  const [saving, setSaving] = useState(false);
  const [del, setDel] = useState<QuizAdmin | null>(null);
  const [deleting, setDeleting] = useState(false);
  const [attemptsFor, setAttemptsFor] = useState<QuizAdmin | null>(null);
  const attempts = useAsync(() => (attemptsFor ? adminApi.quizAttempts(attemptsFor.id) : Promise.resolve([])), [attemptsFor?.id]);

  function open(q?: QuizAdmin) {
    setForm(q ? { course_id: q.course_id, title: q.title, description: q.description, time_limit_minutes: String(q.time_limit_minutes), show_results: q.show_results, is_published: q.is_published,
      questions: q.questions.map((x) => ({ text: x.text, marks: String(x.marks), options: x.options.map((o) => ({ text: o.text, is_correct: o.is_correct })) })) }
      : { course_id: courses.data?.[0]?.id ?? "", title: "", description: "", time_limit_minutes: "0", show_results: true, is_published: true, questions: [newQ()] });
    setEditing({ id: q?.id ?? null });
  }
  const set = <K extends keyof Form>(k: K, v: Form[K]) => setForm((f) => ({ ...f, [k]: v }));
  const setQ = (i: number, fn: (q: QForm) => QForm) => setForm((f) => ({ ...f, questions: f.questions.map((q, j) => (j === i ? fn(q) : q)) }));

  async function save(e: FormEvent) {
    e.preventDefault();
    if (!form.course_id) { toast.error("Choose a course"); return; }
    const questions = [];
    for (let i = 0; i < form.questions.length; i++) {
      const q = form.questions[i];
      const opts = q.options.filter((o) => o.text.trim());
      if (!q.text.trim()) { toast.error(`Question ${i + 1} needs text`); return; }
      if (opts.length < 2) { toast.error(`Question ${i + 1} needs at least 2 options`); return; }
      if (opts.filter((o) => o.is_correct).length !== 1) { toast.error(`Question ${i + 1} must have exactly one correct option`); return; }
      const marks = Number(q.marks);
      if (!Number.isInteger(marks) || marks < 1) { toast.error(`Question ${i + 1}: marks must be a whole number ≥ 1`); return; }
      questions.push({ text: q.text.trim(), marks, options: opts.map((o) => ({ text: o.text.trim(), is_correct: o.is_correct })) });
    }
    const body = { course_id: form.course_id, title: form.title.trim(), description: form.description, time_limit_minutes: Math.max(0, Math.floor(Number(form.time_limit_minutes) || 0)), show_results: form.show_results, is_published: form.is_published, questions };
    setSaving(true);
    try {
      if (editing?.id) await adminApi.updateQuiz(editing.id, body); else await adminApi.createQuiz(body);
      toast.success(editing?.id ? "Quiz updated" : "Quiz created"); setEditing(null); list.reload();
    } catch (e2) { toast.error(getErrorMessage(e2)); } finally { setSaving(false); }
  }
  async function remove() {
    if (!del) return; setDeleting(true);
    try { await adminApi.deleteQuiz(del.id); toast.success("Quiz deleted"); setDel(null); list.reload(); }
    catch (e) { toast.error(getErrorMessage(e)); } finally { setDeleting(false); }
  }

  return (
    <div>
      <PageHeader title="Quizzes" subtitle="Multiple-choice quizzes with optional timers." actions={<Button icon={<Plus className="h-4 w-4" />} onClick={() => open()}>New quiz</Button>} />
      {list.error ? <ErrorState message={list.error} onRetry={list.reloadWithSpinner} /> : (
        <Table<QuizAdmin> loading={list.loading} rows={list.data ?? []} rowKey={(q) => q.id}
          empty={<EmptyState icon={<HelpCircle className="h-7 w-7" />} title="No quizzes" message="Create a quiz for one of your courses." />}
          columns={[
            { key: "t", header: "Quiz", render: (q) => <div><p className="font-semibold text-slate-900">{q.title}</p><p className="text-xs text-slate-500">{q.course_title}</p></div> },
            { key: "q", header: "Questions", render: (q) => q.questions.length, hideOnMobile: true },
            { key: "tm", header: "Time", render: (q) => (q.time_limit_minutes ? `${q.time_limit_minutes} min` : "None"), hideOnMobile: true },
            { key: "s", header: "Status", render: (q) => <Badge tone={q.is_published ? "green" : "slate"} dot>{q.is_published ? "Published" : "Draft"}</Badge> },
            { key: "at", header: "Attempts", render: (q) => q.attempt_count, hideOnMobile: true },
            { key: "a", header: "", className: "text-right", render: (q) => <div className="flex justify-end gap-1"><Button size="sm" variant="ghost" aria-label="View attempts" onClick={() => setAttemptsFor(q)}><BarChart3 className="h-4 w-4" /></Button><Button size="sm" variant="ghost" aria-label="Edit" onClick={() => open(q)}><Pencil className="h-4 w-4" /></Button><Button size="sm" variant="ghost" aria-label="Delete" onClick={() => setDel(q)}><Trash2 className="h-4 w-4 text-rose-600" /></Button></div> },
          ]} />
      )}

      <Modal open={!!editing} onClose={() => setEditing(null)} title={editing?.id ? "Edit quiz" : "New quiz"} size="xl"
        footer={<><Button variant="outline" onClick={() => setEditing(null)}>Cancel</Button><Button type="submit" form="quiz-form" loading={saving}>Save quiz</Button></>}>
        <form id="quiz-form" onSubmit={save} className="space-y-4">
          <Select label="Course" value={form.course_id} onChange={(e) => set("course_id", e.target.value)} required>{courses.data?.map((c) => <option key={c.id} value={c.id}>{c.title}</option>)}</Select>
          <Input label="Title" value={form.title} onChange={(e) => set("title", e.target.value)} required minLength={3} />
          <Textarea label="Description" rows={2} value={form.description} onChange={(e) => set("description", e.target.value)} />
          <div className="grid gap-4 sm:grid-cols-3">
            <Input label="Time limit (min)" type="number" min={0} max={600} hint="0 = no limit" value={form.time_limit_minutes} onChange={(e) => set("time_limit_minutes", e.target.value)} />
            <div className="pt-6"><Checkbox label="Show answers after submit" checked={form.show_results} onChange={(v) => set("show_results", v)} /></div>
            <div className="pt-6"><Checkbox label="Published" checked={form.is_published} onChange={(v) => set("is_published", v)} /></div>
          </div>
          <div className="space-y-4">
            {form.questions.map((q, i) => (
              <div key={i} className="rounded-xl border border-slate-200 p-4">
                <div className="mb-3 flex items-center justify-between"><p className="text-sm font-bold text-slate-900">Question {i + 1}</p>
                  <Button size="sm" variant="ghost" aria-label={`Remove question ${i + 1}`} disabled={form.questions.length === 1} onClick={() => setForm((f) => ({ ...f, questions: f.questions.filter((_, j) => j !== i) }))}><Trash2 className="h-4 w-4 text-rose-600" /></Button></div>
                <div className="grid gap-3 sm:grid-cols-4"><div className="sm:col-span-3"><Textarea label="Question" rows={2} value={q.text} onChange={(e) => setQ(i, (x) => ({ ...x, text: e.target.value }))} /></div><Input label="Marks" type="number" min={1} value={q.marks} onChange={(e) => setQ(i, (x) => ({ ...x, marks: e.target.value }))} /></div>
                <fieldset className="mt-3"><legend className="mb-1 text-xs font-semibold uppercase tracking-wide text-slate-500">Options — select the correct one</legend>
                  <div className="space-y-2">
                    {q.options.map((o, oi) => (
                      <div key={oi} className="flex items-center gap-2">
                        <input type="radio" name={`correct-${i}`} checked={o.is_correct} onChange={() => setQ(i, (x) => ({ ...x, options: x.options.map((p, k) => ({ ...p, is_correct: k === oi })) }))} aria-label={`Mark option ${oi + 1} correct`} className="h-4 w-4 accent-brand-600" />
                        <input value={o.text} onChange={(e) => setQ(i, (x) => ({ ...x, options: x.options.map((p, k) => (k === oi ? { ...p, text: e.target.value } : p)) }))} placeholder={`Option ${oi + 1}`} aria-label={`Option ${oi + 1} text`} className="h-10 flex-1 rounded-xl border border-slate-300 px-3 text-sm focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-100" />
                        <button type="button" aria-label={`Remove option ${oi + 1}`} disabled={q.options.length <= 2} onClick={() => setQ(i, (x) => { const opts = x.options.filter((_, k) => k !== oi); if (!opts.some((p) => p.is_correct)) opts[0].is_correct = true; return { ...x, options: opts }; })} className="rounded-lg p-2 text-slate-400 hover:bg-white/10 disabled:opacity-30"><X className="h-4 w-4" /></button>
                      </div>
                    ))}
                  </div>
                  {q.options.length < 8 && <Button size="sm" variant="ghost" className="mt-2" icon={<Plus className="h-4 w-4" />} onClick={() => setQ(i, (x) => ({ ...x, options: [...x.options, { text: "", is_correct: false }] }))}>Add option</Button>}
                </fieldset>
              </div>
            ))}
            <Button variant="outline" icon={<Plus className="h-4 w-4" />} onClick={() => setForm((f) => ({ ...f, questions: [...f.questions, newQ()] }))}>Add question</Button>
          </div>
        </form>
      </Modal>

      <Modal open={!!attemptsFor} onClose={() => setAttemptsFor(null)} title={`Attempts · ${attemptsFor?.title ?? ""}`} size="lg">
        {attempts.loading ? <p className="text-sm text-slate-500">Loading…</p> : (attempts.data ?? []).length === 0 ? <p className="text-sm text-slate-500">No attempts yet.</p> : (
          <ul className="divide-y divide-slate-100">{attempts.data!.map((a) => <li key={a.id} className="flex items-center justify-between py-2 text-sm"><span><span className="font-medium text-slate-900">{a.student_name}</span> <span className="text-slate-500">· {formatDateTime(a.submitted_at)}</span></span><Badge tone="brand">{a.score}/{a.total_marks}</Badge></li>)}</ul>
        )}
      </Modal>
      <ConfirmationModal open={!!del} danger title="Delete quiz?" message={<>Delete <strong>{del?.title}</strong> and all {del?.attempt_count} attempt(s)?</>} confirmLabel="Delete" loading={deleting} onConfirm={remove} onCancel={() => setDel(null)} />
    </div>
  );
}
