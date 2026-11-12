import { ArrowRight, Award, BarChart3, Bot, CalendarClock, CalendarDays, ClipboardCheck, GraduationCap, Megaphone, PenLine, PlayCircle, Rocket, Search, Target, TrendingUp, Video } from "lucide-react";
import { useState, type FormEvent } from "react";
import { Link, useNavigate } from "react-router-dom";
import { CourseCard } from "../../components/CourseCard";
import { CardSkeleton, ErrorState, LinkButton } from "../../components/ui";
import { useAsync } from "../../hooks/useAsync";
import { courseApi } from "../../services";

const why = [
  { icon: <PlayCircle className="h-6 w-6" />, title: "Recorded classes", text: "Learn at your own pace with structured video lessons you can revisit any time." },
  { icon: <Video className="h-6 w-6" />, title: "Live campaign clinics", text: "Join live sessions to audit real campaigns and get your questions answered." },
  { icon: <ClipboardCheck className="h-6 w-6" />, title: "Assignments & feedback", text: "Submit campaign plans and audits and get marks with written feedback." },
  { icon: <Award className="h-6 w-6" />, title: "Verified certificates", text: "Finish a course and download a certificate with a unique ID." },
];
const steps = [
  { n: "01", title: "Pick a course", text: "Browse by category and preview the full curriculum." },
  { n: "02", title: "Enroll in seconds", text: "Open a course, compare online and offline pricing, and start learning." },
  { n: "03", title: "Learn & practice", text: "Watch lessons, join live classes, take quizzes and submit assignments." },
  { n: "04", title: "Get certified", text: "Complete every lesson to unlock your downloadable certificate." },
];
const outcomes = [
  { icon: <Search className="h-6 w-6" />, title: "Rank on Google", text: "Research keywords, optimise pages and build authority that drives free organic traffic." },
  { icon: <Target className="h-6 w-6" />, title: "Run profitable ads", text: "Launch and scale Google Ads and paid social campaigns with clear ROAS targets." },
  { icon: <Megaphone className="h-6 w-6" />, title: "Grow social audiences", text: "Plan content calendars and short-form video that builds an engaged community." },
  { icon: <PenLine className="h-6 w-6" />, title: "Write copy that converts", text: "Turn visitors into leads with landing pages, emails and CTAs that persuade." },
  { icon: <BarChart3 className="h-6 w-6" />, title: "Measure what matters", text: "Set up GA4, build dashboards and report on growth with confidence." },
  { icon: <Bot className="h-6 w-6" />, title: "Use AI to move faster", text: "Apply AI to research, content and optimisation without losing brand quality." },
];

function Section({ title, subtitle, action, children }: { title: string; subtitle?: string; action?: React.ReactNode; children: React.ReactNode }) {
  return (
    <section className="mx-auto max-w-7xl px-4 pt-16 sm:px-6 lg:px-8">
      <div className="mb-8 flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
        <div><h2 className="text-2xl font-extrabold tracking-tight text-slate-900 sm:text-3xl">{title}<span className="text-brand-500">.</span></h2>{subtitle && <p className="mt-2 max-w-2xl text-slate-500">{subtitle}</p>}</div>{action}
      </div>
      {children}
    </section>
  );
}

/** Courses shown under "Popular right now", in this order. */
const founders = [
  { name: "Krishna", role: "Managing Director & CEO", photo: "/founders/krishna.webp" },
  { name: "Vamsi Girijala", role: "Managing Director & COO", photo: "/founders/vamsi-girijala.webp" },
];

const POPULAR_SLUGS = ["100-placement-programme", "digital-marketing-professional", "entrepreneurship-programme", "video-editing-graphic-designer-combo"];

/** Shows the newest 4 courses, or the given courses in the given order. */
function CourseRow({ slugs }: { slugs?: string[] }) {
  const { data, loading, error, reload } = useAsync(() => courseApi.catalog());
  if (error) return <ErrorState message={error} onRetry={reload} />;
  const items = slugs ? slugs.flatMap((slug) => data?.items.filter((c) => c.slug === slug) ?? []) : data?.items.slice(0, 4) ?? [];
  if (!loading && data && items.length === 0) return <p className="text-slate-500">No courses published yet. Check back soon.</p>;
  return (
    <div className="grid gap-6 sm:grid-cols-2 lg:grid-cols-4">
      {loading || !data ? Array.from({ length: 4 }).map((_, i) => <CardSkeleton key={i} />) : items.map((c) => <CourseCard key={c.id} course={c} />)}
    </div>
  );
}

/** The placement programme, highlighted under the hero. Shows nothing if the programme isn't published. */
function PlacementSpotlight() {
  const { data } = useAsync(() => courseApi.catalog());
  const programme = data?.items.find((c) => c.category === "Placement Programme");
  if (!programme) return null;
  return (
    <section aria-labelledby="placement-heading" className="mx-auto max-w-7xl px-4 pt-10 sm:px-6 lg:px-8">
      <div className="glass relative overflow-hidden rounded-3xl border-brand-500/40 p-6 sm:p-10">
        <div className="grid-bg pointer-events-none absolute inset-0 opacity-50" />
        <div className="pointer-events-none absolute -right-10 -top-10 h-56 w-56 rounded-full bg-brand-500/25 blur-3xl" />
        <div className="relative flex flex-col gap-6 lg:flex-row lg:items-center lg:justify-between">
          <div className="min-w-0">
            <h2 id="placement-heading" className="break-words text-3xl font-extrabold tracking-tight text-slate-900 sm:text-4xl">{programme.title}</h2>
            <p className="mt-3 max-w-2xl text-lg text-slate-500">{programme.short_description}</p>
            <div className="mt-4 flex flex-wrap gap-x-6 gap-y-2 text-sm text-slate-600">
              {programme.duration_months && <span className="flex items-center gap-2"><CalendarDays className="h-4 w-4 text-brand-500" />{programme.duration_months} months</span>}
              {programme.offline_only && <span className="flex items-center gap-2"><GraduationCap className="h-4 w-4 text-brand-500" />Classroom only</span>}
            </div>
          </div>
          <LinkButton to={`/courses/${programme.id}`} size="lg" className="w-full shrink-0 lg:w-auto">View course<ArrowRight className="h-5 w-5" /></LinkButton>
        </div>
      </div>
    </section>
  );
}

export default function Home() {
  const [q, setQ] = useState("");
  const nav = useNavigate();
  const cats = useAsync(() => courseApi.categories());
  const stats = useAsync(() => courseApi.catalog());
  const submit = (e: FormEvent) => { e.preventDefault(); nav(`/courses${q.trim() ? `?search=${encodeURIComponent(q.trim())}` : ""}`); };

  return (
    <div>
      <section className="relative overflow-hidden">
        <div className="grid-bg pointer-events-none absolute inset-0 opacity-70" />
        <div className="pointer-events-none absolute -right-24 -top-24 h-[28rem] w-[28rem] rounded-full bg-brand-500/20 blur-3xl" />
        <div className="pointer-events-none absolute -bottom-32 left-0 h-80 w-80 rounded-full bg-brand-400/10 blur-3xl" />
        <div className="relative mx-auto max-w-7xl px-4 py-20 sm:px-6 sm:py-28 lg:px-8">
          <div className="max-w-3xl animate-fadeUp">
            <span className="inline-flex items-center gap-2 rounded-full border border-brand-500/40 bg-brand-50 px-3.5 py-1.5 text-sm font-medium text-brand-600 backdrop-blur"><Rocket className="h-4 w-4" />The digital marketing academy for the AI era</span>
            <h1 className="mt-6 text-4xl font-extrabold leading-tight tracking-tight text-white sm:text-6xl">Master Marketing with <span className="text-neon-gradient">online &amp; offline</span> classes</h1>
            <p className="mt-5 max-w-2xl text-lg text-slate-500">Placement assistance, online &amp; offline classes, fundamentals of marketing, live case studies, build personal entrepreneurship, certifications.</p>
            <form onSubmit={submit} className="mt-8 flex max-w-xl flex-col gap-3 sm:flex-row" role="search">
              <div className="relative flex-1">
                <Search className="pointer-events-none absolute left-4 top-1/2 h-5 w-5 -translate-y-1/2 text-brand-500" />
                <input value={q} onChange={(e) => setQ(e.target.value)} aria-label="Search courses" placeholder="Try SEO, Social Media, Video Editing…" className="glass h-14 w-full rounded-2xl pl-12 pr-4 text-white placeholder:text-slate-400 focus:border-brand-500 focus:outline-none focus:ring-2 focus:ring-brand-500/30" />
              </div>
              <button className="neon-btn h-14 rounded-2xl px-7 font-bold text-brand-ink transition hover:brightness-110">Search</button>
            </form>
            <div className="mt-10 flex flex-wrap gap-x-10 gap-y-4 text-sm text-slate-500">
              <div><p className="text-3xl font-extrabold text-white">{stats.data?.total ?? "—"}</p>Courses</div>
              <div><p className="text-3xl font-extrabold text-white">{cats.data?.length ?? "—"}</p>Categories</div>
              <div><p className="text-3xl font-extrabold text-neon-gradient">100%</p>Practical</div>
            </div>
          </div>
        </div>
      </section>

      <PlacementSpotlight />

      <Section title="Browse by category" subtitle="Find the right track for your goals.">
        {cats.loading ? <div className="flex gap-3"><div className="h-12 w-40 animate-pulse rounded-xl bg-white/10" /><div className="h-12 w-40 animate-pulse rounded-xl bg-white/10" /></div> : cats.error ? <ErrorState message={cats.error} onRetry={cats.reload} /> :
          <div className="flex flex-wrap gap-3">
            {(cats.data ?? []).map((c) => <Link key={c.name} to={`/courses?category=${encodeURIComponent(c.name)}`} className="flex items-center gap-2 glass glass-hover rounded-xl px-5 py-3 text-sm font-semibold text-slate-700 transition hover:-translate-y-0.5 hover:text-brand-600">{c.name}<span className="rounded-full bg-brand-100 px-2 py-0.5 text-xs text-brand-600">{c.count}</span></Link>)}
            {cats.data?.length === 0 && <p className="text-slate-500">Categories will appear here once courses are published.</p>}
          </div>}
      </Section>

      <Section title="Featured courses" subtitle="Our newest additions, ready to start today." action={<Link to="/courses" className="flex items-center gap-1 text-sm font-semibold text-brand-600 hover:underline">View all <ArrowRight className="h-4 w-4" /></Link>}><CourseRow /></Section>
      <Section title="Popular right now" subtitle="What other learners are enrolling in."><CourseRow slugs={POPULAR_SLUGS} /></Section>

      <Section title="Why choose GTapex Academy" subtitle="Everything you need to learn marketing by doing — in one platform.">
        <div className="grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
          {why.map((w) => <div key={w.title} className="glass glass-hover rounded-2xl p-6"><div className="mb-4 flex h-12 w-12 items-center justify-center rounded-xl border border-brand-500/30 bg-brand-50 text-brand-600">{w.icon}</div><h3 className="font-bold text-slate-900">{w.title}</h3><p className="mt-2 text-sm leading-relaxed text-slate-500">{w.text}</p></div>)}
        </div>
      </Section>

      <Section title="How learning works" subtitle="From first click to certificate in four simple steps.">
        <div className="grid gap-5 md:grid-cols-4">
          {steps.map((s) => <div key={s.n} className="glass relative rounded-2xl p-6"><span className="text-4xl font-black text-brand-500/40">{s.n}</span><h3 className="mt-2 font-bold text-slate-900">{s.title}</h3><p className="mt-2 text-sm text-slate-500">{s.text}</p></div>)}
        </div>
      </Section>

      <Section title="Skills you will build" subtitle="Every course ends with real deliverables you can add to your portfolio.">
        <div className="grid gap-5 md:grid-cols-2 lg:grid-cols-3">
          {outcomes.map((o) => <div key={o.title} className="glass glass-hover flex gap-4 rounded-2xl p-6"><div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-xl border border-brand-500/30 bg-brand-50 text-brand-600">{o.icon}</div><div><h3 className="font-bold text-slate-900">{o.title}</h3><p className="mt-1.5 text-sm leading-relaxed text-slate-500">{o.text}</p></div></div>)}
        </div>
      </Section>

      <section className="mx-auto mt-20 max-w-7xl px-4 sm:px-6 lg:px-8">
        <div className="glass relative overflow-hidden rounded-3xl px-8 py-14 text-center sm:px-16">
          <div className="grid-bg pointer-events-none absolute inset-0 opacity-50" />
          <div className="pointer-events-none absolute -right-10 -top-10 h-56 w-56 rounded-full bg-brand-500/25 blur-3xl" />
          <TrendingUp className="relative mx-auto h-10 w-10 text-brand-500" />
          <h2 className="relative mt-4 text-3xl font-extrabold text-white sm:text-4xl">Ready to grow your marketing career?</h2>
          <p className="relative mx-auto mt-3 max-w-xl text-slate-500">Create a free account and start your first digital marketing course in under a minute.</p>
          <div className="relative mt-8 flex flex-col justify-center gap-3 sm:flex-row">
            <LinkButton to="/register" size="lg">Create free account</LinkButton>
            <LinkButton to="/courses" size="lg" variant="outline"><CalendarClock className="h-5 w-5" />Explore courses</LinkButton>
          </div>
        </div>
      </section>

      <Section title="Meet the founders">
        <ul className="grid grid-cols-2 gap-x-6 gap-y-10 sm:grid-cols-3 lg:grid-cols-5">
          {founders.map((f) => (
            <li key={f.name} className="group">
              <div className="relative aspect-[4/5] overflow-hidden rounded-[20px] border border-white/15 light:border-slate-200">
                <img src={f.photo} alt={`${f.name}, ${f.role}`} width={900} height={1125} loading="lazy" decoding="async" className="absolute inset-0 h-full w-full object-cover object-[50%_22%] transition-transform duration-700 group-hover:scale-[1.04]" />
              </div>
              <p className="mt-4 text-[17px] font-medium leading-6 tracking-[-0.015em] text-slate-900">{f.name}</p>
              <p className="mt-1 text-[11px] font-medium uppercase leading-snug tracking-[0.08em] text-brand-500">{f.role}</p>
            </li>
          ))}
        </ul>
      </Section>
    </div>
  );
}
