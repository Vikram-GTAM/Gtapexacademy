import { Award, CheckCircle2, ChevronDown, ChevronLeft, ChevronRight, Circle, Download, FileText, HelpCircle, ListVideo, Menu, PlayCircle, X } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { Link, useNavigate, useParams, useSearchParams } from "react-router-dom";
import { Logo } from "../../components/Brand";
import { AssignmentRow, LiveClassCard } from "../../components/Cards";
import { ThemeToggle } from "../../components/ThemeToggle";
import { VideoPlayer } from "../../components/VideoPlayer";
import { Badge, Button, EmptyState, ErrorState, LinkButton, PageLoader, ProgressBar, Tabs } from "../../components/ui";
import { useToast } from "../../context/ToastContext";
import { useAsync } from "../../hooks/useAsync";
import { courseApi, studentApi } from "../../services";
import { assetUrl, getErrorMessage } from "../../services/api";
import type { Lesson } from "../../types";
import { cx, formatClock } from "../../utils/format";

type Tab = "resources" | "assignments" | "quizzes" | "live";

export default function Learn() {
  const { courseId = "" } = useParams();
  const [params, setParams] = useSearchParams();
  const nav = useNavigate();
  const toast = useToast();
  const { data, loading, error, reloadWithSpinner } = useAsync(() => courseApi.learning(courseId), [courseId]);
  const extras = useAsync(() => studentApi.courseContent(courseId), [courseId]);
  const [done, setDone] = useState<Set<string>>(new Set());
  const [tab, setTab] = useState<Tab>("resources");
  const [drawer, setDrawer] = useState(false);
  const [busy, setBusy] = useState(false);
  const [openMods, setOpenMods] = useState<Record<string, boolean>>({});
  const [certBusy, setCertBusy] = useState(false);

  useEffect(() => { if (data) setDone(new Set(data.progress.completed_ids ?? [])); }, [data]);

  const flat = useMemo<Lesson[]>(() => (data ? data.modules.flatMap((m) => m.lessons) : []), [data]);
  const wanted = params.get("lesson");
  const current = useMemo(() => flat.find((l) => l.id === wanted) ?? flat.find((l) => !done.has(l.id)) ?? flat[0], [flat, wanted, done]);
  const idx = current ? flat.findIndex((l) => l.id === current.id) : -1;
  const total = flat.length;
  const pct = total ? Math.round((done.size / total) * 1000) / 10 : 0;
  const complete = total > 0 && done.size >= total;

  const select = (id: string) => { setParams({ lesson: id }, { replace: true }); setDrawer(false); window.scrollTo({ top: 0, behavior: "smooth" }); };

  async function toggle(markDone?: boolean) {
    if (!current) return;
    const want = markDone ?? !done.has(current.id);
    setBusy(true);
    try {
      const p = want ? await studentApi.complete(current.id) : await studentApi.uncomplete(current.id);
      setDone(new Set(p.completed_ids ?? []));
      if (want && p.percentage >= 100) toast.success("🎉 Course completed! Your certificate is ready.");
      else if (want) toast.success("Lesson marked as complete");
    } catch (e) { toast.error(getErrorMessage(e)); } finally { setBusy(false); }
  }
  async function next() { if (current && !done.has(current.id)) await toggle(true); if (idx < total - 1) select(flat[idx + 1].id); }

  async function certificate() {
    setCertBusy(true);
    try { const c = await studentApi.generateCertificate(courseId); await studentApi.downloadCertificate(c.id, c.certificate_code); toast.success("Certificate downloaded"); }
    catch (e) { toast.error(getErrorMessage(e)); } finally { setCertBusy(false); }
  }

  if (loading) return <PageLoader />;
  if (error || !data) return <div className="mx-auto max-w-2xl px-4 py-16"><ErrorState message={error ?? "Couldn't load this course"} onRetry={reloadWithSpinner} /><div className="mt-4 text-center"><Link className="text-sm font-semibold text-brand-600 hover:underline" to="/app/courses">← Back to my courses</Link></div></div>;

  const curriculum = (
    <div className="flex h-full flex-col">
      <div className="border-b border-slate-100 p-4">
        <h2 className="line-clamp-2 text-sm font-bold text-slate-900">{data.course.title}</h2>
        <ProgressBar value={pct} showLabel size="sm" className="mt-3" />
        <p className="mt-1 text-xs text-slate-500">{done.size} of {total} lessons completed</p>
      </div>
      <div className="flex-1 overflow-y-auto">
        {data.modules.map((m, mi) => {
          const open = openMods[m.id] ?? (m.lessons.some((l) => l.id === current?.id) || mi === 0);
          const mdone = m.lessons.filter((l) => done.has(l.id)).length;
          return (
            <div key={m.id} className="border-b border-slate-100">
              <button onClick={() => setOpenMods((o) => ({ ...o, [m.id]: !open }))} aria-expanded={open} className="flex w-full items-center justify-between gap-2 bg-slate-50/70 px-4 py-3 text-left">
                <span><span className="block text-sm font-semibold text-slate-800">{m.title}</span><span className="text-xs text-slate-500">{mdone}/{m.lessons.length} completed</span></span>
                <ChevronDown className={cx("h-4 w-4 text-slate-400 transition", open && "rotate-180")} />
              </button>
              {open && m.lessons.map((l) => (
                <button key={l.id} onClick={() => select(l.id)} aria-current={l.id === current?.id ? "true" : undefined}
                  className={cx("flex w-full items-start gap-3 px-4 py-3 text-left text-sm transition hover:bg-white/5", l.id === current?.id && "bg-brand-50")}>
                  {done.has(l.id) ? <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0 text-emerald-500" /> : l.id === current?.id ? <PlayCircle className="mt-0.5 h-4 w-4 shrink-0 text-brand-600" /> : <Circle className="mt-0.5 h-4 w-4 shrink-0 text-slate-500" />}
                  <span className="min-w-0 flex-1"><span className={cx("block", l.id === current?.id ? "font-semibold text-brand-700" : "text-slate-700")}>{l.title}</span><span className="text-xs text-slate-400">{formatClock(l.duration_seconds)}</span></span>
                </button>
              ))}
            </div>
          );
        })}
      </div>
    </div>
  );

  return (
    <div className="flex h-screen flex-col">
      <header className="flex h-14 shrink-0 items-center justify-between gap-3 border-b border-slate-200 bg-panel/90 px-3 backdrop-blur-xl sm:px-5">
        <div className="flex min-w-0 items-center gap-3">
          <button className="rounded-lg p-2 text-slate-600 hover:bg-white/10 lg:hidden" onClick={() => setDrawer(true)} aria-label="Open curriculum"><Menu className="h-5 w-5" /></button>
          <div className="hidden sm:block"><Logo to="/app" /></div>
          <span className="hidden h-6 w-px bg-slate-200 sm:block" />
          <p className="truncate text-sm font-semibold text-slate-800">{data.course.title}</p>
        </div>
        <div className="flex items-center gap-3">
          <ThemeToggle className="p-2" />
          <div className="hidden w-40 sm:block"><ProgressBar value={pct} showLabel size="sm" /></div>
          <LinkButton to="/app/courses" variant="outline" size="sm"><ChevronLeft className="h-4 w-4" />Exit</LinkButton>
        </div>
      </header>

      <div className="flex min-h-0 flex-1">
        <aside className="hidden w-80 shrink-0 border-r border-slate-200 bg-panel/70 lg:block">{curriculum}</aside>
        {drawer && (
          <div className="fixed inset-0 z-50 lg:hidden" role="dialog" aria-modal="true" aria-label="Course curriculum">
            <div className="absolute inset-0 bg-black/70 backdrop-blur-sm" onClick={() => setDrawer(false)} />
            <div className="absolute inset-y-0 left-0 w-80 max-w-[90vw] animate-slideInLeft border-r border-slate-200 bg-panel shadow-2xl">
              <button onClick={() => setDrawer(false)} className="absolute right-2 top-3 rounded-lg p-1.5 text-slate-400 hover:bg-white/10" aria-label="Close curriculum"><X className="h-5 w-5" /></button>
              {curriculum}
            </div>
          </div>
        )}

        <main className="min-w-0 flex-1 overflow-y-auto">
          <div className="mx-auto max-w-4xl space-y-6 px-4 py-6 sm:px-6">
            {!current ? <EmptyState icon={<ListVideo className="h-7 w-7" />} title="No lessons yet" message="Lessons will appear here as soon as they're published." /> : (
              <>
                <VideoPlayer src={assetUrl(current.video_url)} title={current.title} onEnded={() => !done.has(current.id) && toggle(true)} />
                <div>
                  <div className="flex flex-wrap items-start justify-between gap-3">
                    <div><p className="text-xs font-semibold uppercase tracking-wide text-brand-600">Lesson {idx + 1} of {total}</p><h1 className="mt-1 text-2xl font-extrabold text-slate-900">{current.title}</h1></div>
                    {done.has(current.id) && <Badge tone="green"><CheckCircle2 className="h-3.5 w-3.5" />Completed</Badge>}
                  </div>
                  {current.description && <p className="mt-3 whitespace-pre-line leading-relaxed text-slate-600">{current.description}</p>}
                </div>

                <div className="flex flex-wrap items-center justify-between gap-3 rounded-2xl glass p-3 shadow-card">
                  <Button variant="outline" disabled={idx <= 0} onClick={() => select(flat[idx - 1].id)} icon={<ChevronLeft className="h-4 w-4" />}>Previous</Button>
                  <Button variant={done.has(current.id) ? "outline" : "success"} loading={busy} onClick={() => toggle()} icon={<CheckCircle2 className="h-4 w-4" />}>{done.has(current.id) ? "Mark as incomplete" : "Mark as complete"}</Button>
                  <Button disabled={idx >= total - 1} onClick={next}>Next<ChevronRight className="h-4 w-4" /></Button>
                </div>

                {complete && (
                  <div className="flex flex-col items-start gap-3 rounded-2xl glass border-brand-500/50 p-5 shadow-glow sm:flex-row sm:items-center sm:justify-between">
                    <div className="flex items-center gap-3"><span className="flex h-12 w-12 items-center justify-center rounded-xl bg-brand-100 text-brand-600"><Award className="h-6 w-6" /></span><div><p className="font-bold text-slate-900">You've completed this course!</p><p className="text-sm text-slate-600">Download your certificate of completion.</p></div></div>
                    <Button variant="success" loading={certBusy} onClick={certificate} icon={<Download className="h-4 w-4" />}>Get certificate</Button>
                  </div>
                )}

                <div className="space-y-4">
                  <Tabs<Tab> value={tab} onChange={setTab} tabs={[
                    { id: "resources", label: "Resources", count: current.resources?.length ?? 0 }, { id: "assignments", label: "Assignments", count: extras.data?.assignments.length },
                    { id: "quizzes", label: "Quizzes", count: extras.data?.quizzes.length }, { id: "live", label: "Live classes", count: extras.data?.live_classes.length },
                  ]} />
                  {tab === "resources" && (current.resources?.length ? <ul className="space-y-2">{current.resources.map((r) => (
                    <li key={r.id}><a href={assetUrl(r.file_url)} target="_blank" rel="noopener noreferrer" download className="flex items-center gap-3 rounded-xl glass p-3.5 text-sm font-medium text-slate-700 shadow-sm hover:border-brand-500/60 hover:text-brand-600"><FileText className="h-5 w-5 text-brand-500" /><span className="flex-1">{r.title}</span><Download className="h-4 w-4 text-slate-400" /></a></li>))}</ul>
                    : <p className="rounded-xl border border-dashed border-slate-300 bg-white/[0.03] p-6 text-center text-sm text-slate-500">No downloadable resources for this lesson.</p>)}
                  {tab === "assignments" && (extras.error ? <ErrorState message={extras.error} onRetry={extras.reload} /> : extras.data?.assignments.length ? <div className="space-y-3">{extras.data.assignments.map((a) => <AssignmentRow key={a.id} a={a} />)}</div> : <p className="rounded-xl border border-dashed border-slate-300 bg-white/[0.03] p-6 text-center text-sm text-slate-500">No assignments in this course.</p>)}
                  {tab === "quizzes" && (extras.data?.quizzes.length ? <div className="space-y-3">{extras.data.quizzes.map((q) => (
                    <button key={q.id} onClick={() => nav(`/app/quizzes/${q.id}`)} className="flex w-full items-center gap-3 rounded-2xl glass p-4 text-left shadow-card hover:border-brand-500/60"><span className="flex h-10 w-10 items-center justify-center rounded-xl bg-brand-50 text-brand-600"><HelpCircle className="h-5 w-5" /></span><span className="flex-1"><span className="block font-semibold text-slate-900">{q.title}</span><span className="text-xs text-slate-500">{q.time_limit_minutes ? `${q.time_limit_minutes} min` : "No time limit"}</span></span><ChevronRight className="h-4 w-4 text-slate-400" /></button>))}</div> : <p className="rounded-xl border border-dashed border-slate-300 bg-white/[0.03] p-6 text-center text-sm text-slate-500">No quizzes in this course yet.</p>)}
                  {tab === "live" && (extras.data?.live_classes.length ? <div className="grid gap-4 sm:grid-cols-2">{extras.data.live_classes.map((l) => <LiveClassCard key={l.id} lc={l} compact />)}</div> : <p className="rounded-xl border border-dashed border-slate-300 bg-white/[0.03] p-6 text-center text-sm text-slate-500">No live classes scheduled for this course.</p>)}
                </div>
              </>
            )}
          </div>
        </main>
      </div>
    </div>
  );
}
