import { ArrowRight, Briefcase, FileText, Handshake, Linkedin, Mic, Presentation, Rocket } from "lucide-react";
import { LinkButton } from "../../components/ui";

const support = [
  { icon: <FileText className="h-6 w-6" />, title: "Resume & portfolio review", text: "Turn your course assignments and campaign work into a resume and portfolio that employers want to see." },
  { icon: <Mic className="h-6 w-6" />, title: "Mock interviews", text: "Practise with realistic interview rounds and get specific feedback before the real thing." },
  { icon: <Linkedin className="h-6 w-6" />, title: "LinkedIn & personal branding", text: "Set up a profile that gets found by recruiters and agencies hiring marketers." },
  { icon: <Handshake className="h-6 w-6" />, title: "Job referrals", text: "Eligible students are introduced to hiring partners and openings as they come up." },
  { icon: <Presentation className="h-6 w-6" />, title: "Live project exposure", text: "Work on real campaign briefs so you can talk about results, not just concepts." },
  { icon: <Rocket className="h-6 w-6" />, title: "Freelance start-up guidance", text: "Prefer to work for yourself? Learn how to find and pitch your first clients." },
];
const roles = ["Digital Marketing Executive", "SEO Executive / Analyst", "Performance Marketer (PPC)", "Social Media Manager", "Content Marketer", "Marketing Analyst", "Email & CRM Marketer", "Freelance Consultant"];
const steps = [
  { n: "1", title: "Complete your course", text: "Finish the lessons, assignments and quizzes and earn your certificate." },
  { n: "2", title: "Build your profile", text: "Polish your resume, portfolio and LinkedIn with our team." },
  { n: "3", title: "Prepare", text: "Take mock interviews and fix the gaps." },
  { n: "4", title: "Get introduced", text: "We share your profile with hiring partners when roles match." },
];

export default function Placements() {
  return (
    <div>
      <section className="relative overflow-hidden">
        <div className="grid-bg pointer-events-none absolute inset-0 opacity-70" />
        <div className="relative mx-auto max-w-7xl px-4 py-16 sm:px-6 sm:py-24 lg:px-8">
          <div className="max-w-3xl animate-fadeUp">
            <span className="inline-flex items-center gap-2 rounded-full border border-brand-500/40 bg-brand-50 px-3.5 py-1.5 text-sm font-medium text-brand-600"><Briefcase className="h-4 w-4" />Placement support</span>
            <h1 className="mt-6 text-4xl font-extrabold leading-tight tracking-tight text-white sm:text-5xl">From certificate to <span className="text-neon-gradient">your first marketing job</span></h1>
            <p className="mt-5 max-w-2xl text-lg text-slate-500">Learning is only half the journey. Our placement team helps you present your skills, prepare for interviews and connect with employers.</p>
            <div className="mt-8 flex flex-wrap gap-3">
              <LinkButton to="/book-demo" size="lg">Book Free Demo<ArrowRight className="h-4 w-4" /></LinkButton>
              <LinkButton to="/courses" variant="outline" size="lg">View courses</LinkButton>
            </div>
          </div>
        </div>
      </section>

      <section className="mx-auto max-w-7xl px-4 py-12 sm:px-6 lg:px-8">
        <h2 className="text-3xl font-extrabold tracking-tight text-white">What placement support includes</h2>
        <div className="mt-8 grid gap-5 sm:grid-cols-2 lg:grid-cols-3">
          {support.map((s) => <div key={s.title} className="glass glass-hover rounded-2xl p-6"><span className="flex h-12 w-12 items-center justify-center rounded-xl bg-brand-50 text-brand-600">{s.icon}</span><h3 className="mt-4 text-lg font-bold text-white">{s.title}</h3><p className="mt-2 text-sm leading-relaxed text-slate-500">{s.text}</p></div>)}
        </div>
      </section>

      <section className="mx-auto max-w-7xl px-4 py-12 sm:px-6 lg:px-8">
        <h2 className="text-3xl font-extrabold tracking-tight text-white">Roles our learners go for</h2>
        <div className="mt-6 flex flex-wrap gap-3">
          {roles.map((r) => <span key={r} className="rounded-full border border-slate-200 bg-brand-50 px-4 py-2 text-sm font-medium text-slate-700">{r}</span>)}
        </div>
      </section>

      <section className="mx-auto max-w-7xl px-4 py-12 sm:px-6 lg:px-8">
        <h2 className="text-3xl font-extrabold tracking-tight text-white">How placement works</h2>
        <div className="mt-8 grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
          {steps.map((s) => <div key={s.n} className="glass rounded-2xl p-6"><span className="flex h-10 w-10 items-center justify-center rounded-full bg-neon font-extrabold text-brand-ink">{s.n}</span><h3 className="mt-4 text-lg font-bold text-white">{s.title}</h3><p className="mt-2 text-sm leading-relaxed text-slate-500">{s.text}</p></div>)}
        </div>
        <p className="mt-6 text-sm text-slate-500">Placement support is guidance and introductions — it does not guarantee a job offer.</p>
      </section>

      <section className="mx-auto max-w-7xl px-4 pb-8 pt-4 sm:px-6 lg:px-8">
        <div className="glass flex flex-col items-start justify-between gap-5 rounded-2xl p-8 sm:flex-row sm:items-center">
          <div><h2 className="text-2xl font-bold text-white">Want to know how it would work for you?</h2><p className="mt-1 text-slate-500">Book a free demo and ask our team about placements.</p></div>
          <LinkButton to="/book-demo" size="lg">Book Free Demo</LinkButton>
        </div>
      </section>
    </div>
  );
}
