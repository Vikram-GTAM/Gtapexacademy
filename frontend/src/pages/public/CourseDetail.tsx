import { ArrowRight, BookOpen, CalendarDays, CheckCircle2, ChevronDown, Clock, GraduationCap, Lock, MonitorPlay, PlayCircle, ShieldCheck, Users } from "lucide-react";
import { useState, type ReactNode } from "react";
import { Link, useLocation, useNavigate, useParams } from "react-router-dom";
import { CourseVisual } from "../../components/CourseVisual";
import { Badge, Button, Card, ErrorState, LinkButton, Skeleton } from "../../components/ui";
import { useAuth } from "../../context/AuthContext";
import { useToast } from "../../context/ToastContext";
import { useAsync } from "../../hooks/useAsync";
import { paymentApi, courseApi } from "../../services";
import { assetUrl, getErrorCode, getErrorMessage } from "../../services/api";
import type { Module } from "../../types";
import { cx, formatClock, formatDuration, formatPrice } from "../../utils/format";
import { courseMeta, usePageMeta } from "../../utils/seo";

declare global { interface Window { Razorpay?: new (opts: Record<string, unknown>) => { open: () => void; on: (e: string, cb: (r: unknown) => void) => void } } }

function loadRazorpay(): Promise<boolean> {
  return new Promise((resolve) => {
    if (window.Razorpay) return resolve(true);
    const s = document.createElement("script");
    s.src = "https://checkout.razorpay.com/v1/checkout.js";
    s.onload = () => resolve(true); s.onerror = () => resolve(false);
    document.body.appendChild(s);
  });
}
type LearningMode = "online" | "offline";
const plural = (n: number, word: string) => `${n} ${word}${n === 1 ? "" : "s"}`;

function PriceCard({ icon, label, price, benefits, action }: { icon: ReactNode; label: string; price: string; benefits: string[]; action: ReactNode }) {
  return (
    <Card padded={false} className="glass-hover flex h-full flex-col p-6 hover:-translate-y-1 sm:p-8">
      <div className="flex items-center gap-3">
        <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-brand-100 text-brand-600">{icon}</span>
        <h3 className="text-lg font-bold text-slate-900">{label}</h3>
      </div>
      <p className="mt-6 break-words font-display text-4xl font-extrabold tracking-tight text-slate-900 sm:text-5xl">{price}</p>
      <ul className="mb-8 mt-6 flex-1 space-y-3 border-t border-slate-100 pt-6">
        {benefits.map((b) => <li key={b} className="flex items-start gap-2.5 text-slate-700"><CheckCircle2 className="mt-0.5 h-5 w-5 shrink-0 text-brand-500" />{b}</li>)}
      </ul>
      {action}
    </Card>
  );
}

function ModuleAccordion({ module: m, index, isOpen, unlocked, onToggle }: { module: Module; index: number; isOpen: boolean; unlocked: boolean; onToggle: () => void }) {
  const seconds = m.lessons.reduce((sum, l) => sum + l.duration_seconds, 0);
  const panelId = `module-panel-${m.id}`;
  return (
    <Card padded={false} className={cx("overflow-hidden transition-colors duration-200", isOpen && "border-brand-500/40")}>
      <button onClick={onToggle} aria-expanded={isOpen} aria-controls={panelId} className="flex w-full items-center gap-3 p-4 text-left transition-colors hover:bg-white/5 sm:gap-4 sm:p-5">
        <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-brand-100 font-display font-bold text-brand-600">{index + 1}</span>
        <span className="min-w-0 flex-1">
          <span className="block break-words font-semibold text-slate-900 sm:text-lg">{m.title}</span>
          <span className="mt-1 flex flex-wrap items-center gap-x-4 gap-y-1 text-sm text-slate-500">
            <span className="flex items-center gap-1.5"><BookOpen className="h-4 w-4" />{plural(m.lessons.length, "lesson")}</span>
            {seconds > 0 && <span className="flex items-center gap-1.5"><Clock className="h-4 w-4" />{formatDuration(seconds)}</span>}
          </span>
        </span>
        <ChevronDown className={cx("h-5 w-5 shrink-0 text-slate-500 transition-transform duration-300", isOpen && "rotate-180")} />
      </button>
      {/* Animating rows from 0fr to 1fr slides the panel open at its natural height. */}
      <div id={panelId} className={cx("grid transition-[grid-template-rows,visibility] duration-300 ease-out", isOpen ? "visible grid-rows-[1fr]" : "invisible grid-rows-[0fr]")}>
        <div className="min-h-0 overflow-hidden">
          <ul className="border-t border-slate-100 bg-sunken px-4 py-1 sm:px-5">
            {m.lessons.map((l) => (
              <li key={l.id} className="flex items-center gap-3 border-t border-slate-100 py-3 text-sm first:border-0">
                {unlocked || l.is_free_preview ? <PlayCircle className="h-4 w-4 shrink-0 text-brand-500" /> : <Lock className="h-4 w-4 shrink-0 text-slate-400" />}
                <span className="min-w-0 flex-1 break-words text-slate-700">{l.title}</span>
                {l.is_free_preview && <Badge tone="green" className="shrink-0">Preview</Badge>}
                {l.duration_seconds > 0 && <span className="shrink-0 text-xs tabular-nums text-slate-500">{formatClock(l.duration_seconds)}</span>}
              </li>
            ))}
          </ul>
        </div>
      </div>
    </Card>
  );
}

export default function CourseDetail() {
  const { id = "" } = useParams();
  const { user } = useAuth();
  const toast = useToast();
  const nav = useNavigate();
  const loc = useLocation();
  const { data: c, loading, error, reload } = useAsync(() => courseApi.get(id), [id, user?.id]);
  const [busy, setBusy] = useState<LearningMode | null>(null);
  const [open, setOpen] = useState<Record<string, boolean>>({});
  usePageMeta(c ? courseMeta(c) : null);

  if (loading) return <div className="mx-auto max-w-7xl px-4 py-10"><Skeleton className="mb-6 h-64 w-full" /><Skeleton className="h-8 w-1/2" /></div>;
  if (error || !c) return <div className="mx-auto max-w-3xl px-4 py-16"><ErrorState message={error ?? "Course not found"} onRetry={reload} /><div className="mt-4 text-center"><Link to="/courses" className="text-sm font-semibold text-brand-600 hover:underline">← Back to all courses</Link></div></div>;

  const isAdmin = user?.role === "admin";
  const goLearn = () => nav(`/app/learn/${c.id}`);

  async function buy(mode: LearningMode) {
    if (!c) return;
    if (!user) return nav("/login", { state: { from: loc.pathname } });
    setBusy(mode);
    try {
      if (mode === "online" && c.price === 0) {
        await courseApi.enroll(c.id);
        toast.success("You're enrolled! Let's start learning.");
        goLearn();
      } else await pay(mode);
    } catch (e) {
      if (getErrorCode(e) === "already_enrolled") { reload(); toast.info("You're already enrolled in this course."); }
      else toast.error(getErrorMessage(e));
    } finally { setBusy(null); }
  }

  async function pay(mode: LearningMode) {
    if (!c) return;
    const cfg = await paymentApi.config();
    if (!cfg.configured) { toast.error("Online payments aren't set up yet. Please contact the administrator."); return; }
    if (!(await loadRazorpay()) || !window.Razorpay) { toast.error("Couldn't load the payment window. Check your connection and try again."); return; }
    const order = await paymentApi.createOrder(c.id, mode);
    await new Promise<void>((resolve) => {
      const rz = new window.Razorpay!({
        key: order.key_id, amount: order.amount, currency: order.currency, order_id: order.order_id, name: "GTapex Academy", description: order.course_title,
        prefill: { name: user?.name, email: user?.email }, theme: { color: "#00A83F" },
        handler: async (resp: { razorpay_order_id: string; razorpay_payment_id: string; razorpay_signature: string }) => {
          try { await paymentApi.verify(resp); toast.success("Payment successful! You're enrolled."); goLearn(); }
          catch (e) { toast.error(getErrorMessage(e, "Payment verification failed")); }
          resolve();
        },
        modal: { ondismiss: () => resolve() },
      });
      rz.on("payment.failed", () => { paymentApi.failed(order.order_id).catch(() => undefined); toast.error("Payment failed. You have not been charged."); });
      rz.open();
    });
  }

  const action = (mode: LearningMode) => isAdmin ? <p className="rounded-xl bg-slate-100 p-3 text-center text-sm text-slate-600">You're viewing as an admin.</p>
    : c.is_enrolled ? <Button size="lg" className="w-full" onClick={goLearn} icon={<PlayCircle className="h-5 w-5" />}>Continue learning</Button>
    : <Button size="lg" className="w-full" onClick={() => buy(mode)} loading={busy === mode} disabled={busy !== null}>{mode === "online" && c.price === 0 ? "Enroll for free" : "Buy now"}{busy !== mode && <ArrowRight className="h-5 w-5" />}</Button>;

  return (
    <div>
      <div className="relative overflow-hidden border-b border-slate-200 bg-panel/60"><div className="grid-bg pointer-events-none absolute inset-0 opacity-70" /><div className="pointer-events-none absolute -right-20 -top-20 h-80 w-80 rounded-full bg-brand-500/15 blur-3xl" />
        <div className="relative mx-auto grid max-w-7xl gap-8 px-4 py-12 sm:px-6 lg:grid-cols-3 lg:px-8">
          <div className="lg:col-span-2">
            <nav className="mb-4 text-sm text-slate-500"><Link to="/courses" className="hover:text-white">Courses</Link> / <span>{c.category}</span></nav>
            <div className="mb-3 flex flex-wrap items-center gap-2"><Badge tone="slate">{c.category}</Badge></div>
            <h1 className="text-3xl font-extrabold leading-tight text-white sm:text-4xl">{c.title}</h1>
            <p className="mt-4 max-w-2xl text-lg text-slate-500">{c.short_description}</p>
            <div className="mt-6 flex flex-wrap gap-x-6 gap-y-2 text-sm text-slate-600">
              {c.duration_months && <span className="flex items-center gap-2"><CalendarDays className="h-4 w-4" />{plural(c.duration_months, "month")}</span>}
              {c.offline_only ? <span className="flex items-center gap-2"><GraduationCap className="h-4 w-4" />Classroom only</span> : <>
                {c.duration_seconds > 0 && <span className="flex items-center gap-2"><Clock className="h-4 w-4" />{formatDuration(c.duration_seconds)} of content</span>}
                {c.lesson_count > 0 && <span className="flex items-center gap-2"><BookOpen className="h-4 w-4" />{plural(c.lesson_count, "lesson")}</span>}
              </>}
              {c.enrolled_count > 0 && <span className="flex items-center gap-2"><Users className="h-4 w-4" />{c.enrolled_count} enrolled</span>}
            </div>
          </div>
        </div>
      </div>

      <section aria-labelledby="pricing-heading" className="mx-auto max-w-7xl px-4 pt-10 sm:px-6 lg:px-8">
        <h2 id="pricing-heading" className="mb-5 text-2xl font-bold text-slate-900">{c.offline_only ? "Join in the classroom" : "Choose how you learn"}</h2>
        <div className={cx("grid gap-6", c.offline_only ? "max-w-xl" : "sm:grid-cols-2")}>
          {!c.offline_only && <PriceCard icon={<MonitorPlay className="h-6 w-6" />} label="Online" price={formatPrice(c.price)} benefits={["Recorded lessons", "Live classes"]} action={action("online")} />}
          <PriceCard icon={<GraduationCap className="h-6 w-6" />} label="Offline" price={c.offline_price == null ? "Contact us" : formatPrice(c.offline_price)} benefits={["Classroom learning", "In-person trainer support", "Placement assistance"]}
            action={c.offline_price == null
              ? !isAdmin && <LinkButton to="/contact" variant="outline" size="lg" className="w-full">Contact us</LinkButton>
              : (isAdmin || c.is_enrolled) && !c.offline_only ? null : action("offline")} />
        </div>
        <p className="mt-4 text-sm text-slate-500">Before you pay, read our <Link to="/refund-policy" className="font-medium text-brand-600 hover:underline">refund terms</Link>.</p>
      </section>

      <div className="mx-auto grid max-w-7xl gap-8 px-4 py-10 sm:px-6 lg:grid-cols-3 lg:px-8">
        <div className="space-y-8 lg:col-span-2">
          <Card><h2 className="mb-3 text-xl font-bold text-slate-900">About this course</h2><p className="whitespace-pre-line leading-relaxed text-slate-600">{c.description || "No description provided yet."}</p></Card>
          {c.features.length > 0 && (
            <Card><h2 className="mb-4 text-xl font-bold text-slate-900">What's included</h2>
              <ul className="grid gap-3 sm:grid-cols-2">{c.features.map((f) => <li key={f} className="flex items-start gap-2.5 text-sm text-slate-700"><CheckCircle2 className="mt-0.5 h-5 w-5 shrink-0 text-brand-500" />{f}</li>)}</ul></Card>
          )}
          <section aria-labelledby="curriculum-heading">
            <div className="mb-4 flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1">
              <h2 id="curriculum-heading" className="text-2xl font-bold text-slate-900">Curriculum</h2>
              {c.modules.length > 0 && <p className="text-sm text-slate-500">{plural(c.modules.length, "module")} · {plural(c.lesson_count, "lesson")}{c.duration_seconds > 0 && ` · ${formatDuration(c.duration_seconds)}`}</p>}
            </div>
            {c.modules.length === 0 ? <Card><p className="text-sm text-slate-500">The curriculum will be published soon.</p></Card> : (
              <div className="space-y-3">
                {c.modules.map((m, mi) => {
                  const isOpen = open[m.id] ?? mi === 0;
                  return <ModuleAccordion key={m.id} module={m} index={mi} isOpen={isOpen} unlocked={c.is_enrolled} onToggle={() => setOpen((o) => ({ ...o, [m.id]: !isOpen }))} />;
                })}
              </div>
            )}
          </section>
        </div>

        <aside className="order-first lg:order-none">
          <Card padded={false} className="sticky top-24 overflow-hidden">
            <div className="p-2"><CourseVisual category={c.category} src={assetUrl(c.thumbnail_url)} alt={c.title} className="aspect-[5/3] w-full" /></div>
            <div className="p-5 pt-3">
              <ul className="space-y-2.5 text-sm text-slate-600">
                {c.duration_months && <li className="flex items-center gap-2.5"><CalendarDays className="h-4 w-4 text-slate-400" />{plural(c.duration_months, "month")} long</li>}
                {c.offline_only ? <li className="flex items-center gap-2.5"><GraduationCap className="h-4 w-4 text-slate-400" />Classroom only</li> : <>
                  {c.duration_seconds > 0 && <li className="flex items-center gap-2.5"><Clock className="h-4 w-4 text-slate-400" />{formatDuration(c.duration_seconds)} on-demand video</li>}
                  {c.lesson_count > 0 && <li className="flex items-center gap-2.5"><BookOpen className="h-4 w-4 text-slate-400" />{plural(c.lesson_count, "lesson")} across {plural(c.modules.length, "module")}</li>}
                </>}
                <li className="flex items-center gap-2.5"><ShieldCheck className="h-4 w-4 text-slate-400" />Certificate on completion</li>
              </ul>
            </div>
          </Card>
        </aside>
      </div>
    </div>
  );
}
