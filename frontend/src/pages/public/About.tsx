import { ArrowRight, Award, BookOpenCheck, Bot, Briefcase, Target, Users, Video } from "lucide-react";
import { Link } from "react-router-dom";
import { LinkButton } from "../../components/ui";

const pillars = [
  { icon: <Target className="h-6 w-6" />, title: "Practical, campaign-first", text: "Every module ends with real work — audits, campaign plans and reports — not just theory." },
  { icon: <Video className="h-6 w-6" />, title: "Live + recorded", text: "Learn on your own schedule with recorded lessons, and join live clinics to get answers in real time." },
  { icon: <Bot className="h-6 w-6" />, title: "Built for the AI era", text: "We teach how to use AI tools for research, content and analytics alongside the fundamentals." },
  { icon: <Award className="h-6 w-6" />, title: "Certified progress", text: "Quizzes and assignments are graded, and you earn a shareable certificate when you complete a course." },
];
const steps = [
  { n: "01", title: "Learn", text: "Work through structured modules of recorded video lessons and downloadable resources." },
  { n: "02", title: "Practise", text: "Complete assignments and quizzes, and get marks with written feedback from instructors." },
  { n: "03", title: "Get certified", text: "Finish the course to unlock your certificate and build a portfolio of real campaign work." },
  { n: "04", title: "Get placed", text: "Use our placement support — resume, mock interviews and referrals — to start your career." },
];

export default function About() {
  return (
    <div>
      <section className="relative overflow-hidden">
        <div className="grid-bg pointer-events-none absolute inset-0 opacity-70" />
        <div className="relative mx-auto max-w-7xl px-4 py-16 sm:px-6 sm:py-24 lg:px-8">
          <div className="max-w-3xl animate-fadeUp">
            <span className="inline-flex items-center gap-2 rounded-full border border-brand-500/40 bg-brand-50 px-3.5 py-1.5 text-sm font-medium text-brand-600"><Users className="h-4 w-4" />About GTapex Academy</span>
            <h1 className="mt-6 text-4xl font-extrabold leading-tight tracking-tight text-white sm:text-5xl">We teach digital marketing the way it is <span className="text-neon-gradient">actually practised</span></h1>
            <p className="mt-5 max-w-2xl text-lg text-slate-500">GTapex Academy is the training arm of GTapex Marketing, a digital marketing and growth agency. Our courses are designed by people who run campaigns for a living, so you learn the skills agencies and brands are hiring for.</p>
            <div className="mt-8 flex flex-wrap gap-3">
              <LinkButton to="/courses" size="lg">Explore courses<ArrowRight className="h-4 w-4" /></LinkButton>
              <LinkButton to="/book-demo" variant="outline" size="lg">Book a free demo</LinkButton>
            </div>
          </div>
        </div>
      </section>

      <section className="mx-auto max-w-7xl px-4 py-12 sm:px-6 lg:px-8">
        <div className="grid gap-6 lg:grid-cols-2">
          <div className="glass rounded-2xl p-6 sm:p-8"><h2 className="flex items-center gap-2 text-xl font-bold text-white"><Target className="h-5 w-5 text-brand-500" />Our mission</h2><p className="mt-3 leading-relaxed text-slate-500">To make job-ready digital marketing education accessible — combining expert-led teaching with hands-on practice, so every learner finishes with skills they can use on day one.</p></div>
          <div className="glass rounded-2xl p-6 sm:p-8"><h2 className="flex items-center gap-2 text-xl font-bold text-white"><BookOpenCheck className="h-5 w-5 text-brand-500" />What we cover</h2><p className="mt-3 leading-relaxed text-slate-500">SEO, paid advertising, social media marketing, content, email and AI-powered analytics — taught through structured courses with assignments, quizzes and certificates.</p></div>
        </div>
      </section>

      <section className="mx-auto max-w-7xl px-4 py-12 sm:px-6 lg:px-8">
        <h2 className="text-3xl font-extrabold tracking-tight text-white">Why learners choose us</h2>
        <div className="mt-8 grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
          {pillars.map((p) => <div key={p.title} className="glass glass-hover rounded-2xl p-6"><span className="flex h-12 w-12 items-center justify-center rounded-xl bg-brand-50 text-brand-600">{p.icon}</span><h3 className="mt-4 text-lg font-bold text-white">{p.title}</h3><p className="mt-2 text-sm leading-relaxed text-slate-500">{p.text}</p></div>)}
        </div>
      </section>

      <section className="mx-auto max-w-7xl px-4 py-12 sm:px-6 lg:px-8">
        <h2 className="text-3xl font-extrabold tracking-tight text-white">How it works</h2>
        <div className="mt-8 grid gap-5 sm:grid-cols-2 lg:grid-cols-4">
          {steps.map((s) => <div key={s.n} className="glass rounded-2xl p-6"><p className="text-3xl font-extrabold text-brand-500">{s.n}</p><h3 className="mt-3 text-lg font-bold text-white">{s.title}</h3><p className="mt-2 text-sm leading-relaxed text-slate-500">{s.text}</p></div>)}
        </div>
      </section>

      <section className="mx-auto max-w-7xl px-4 pb-8 pt-12 sm:px-6 lg:px-8">
        <div className="glass flex flex-col items-start justify-between gap-5 rounded-2xl p-8 sm:flex-row sm:items-center">
          <div><h2 className="flex items-center gap-2 text-2xl font-bold text-white"><Briefcase className="h-6 w-6 text-brand-500" />Ready to start your marketing career?</h2><p className="mt-1 text-slate-500">See what we offer for <Link to="/placements" className="text-brand-600 hover:underline">placements</Link>, or talk to us first.</p></div>
          <LinkButton to="/book-demo" size="lg">Book Free Demo</LinkButton>
        </div>
      </section>
    </div>
  );
}
