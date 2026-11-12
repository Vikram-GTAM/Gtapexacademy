import { GraduationCap, MonitorPlay, ShieldCheck } from "lucide-react";
import type { ReactNode } from "react";
import { Link } from "react-router-dom";
import { EMAIL, PHONE, PHONE_LINK } from "../../utils/contactInfo";

function TermsCard({ icon, title, intro, terms }: { icon: ReactNode; title: string; intro: string; terms: string[] }) {
  return (
    <section className="glass rounded-2xl p-6 sm:p-8">
      <div className="flex items-center gap-3">
        <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-brand-100 text-brand-600">{icon}</span>
        <h2 className="text-xl font-bold text-slate-900">{title}</h2>
      </div>
      <p className="mt-4 text-slate-600">{intro}</p>
      <ul className="mt-4 list-disc space-y-2 pl-5 text-slate-600">
        {terms.map((t) => <li key={t}>{t}</li>)}
      </ul>
    </section>
  );
}

export default function RefundPolicy() {
  return (
    <div className="relative overflow-hidden">
      <div className="grid-bg pointer-events-none absolute inset-0 opacity-70" />
      <div className="relative mx-auto max-w-3xl space-y-6 px-4 py-16 sm:px-6 lg:px-8">
        <header className="mb-10">
          <h1 className="text-4xl font-extrabold tracking-tight text-slate-900 sm:text-5xl">Refund terms</h1>
          <p className="mt-4 text-lg text-slate-500">When you can get your money back, and how to ask for it.</p>
          <p className="mt-2 text-sm text-slate-500">Last updated: 4 November 2026</p>
        </header>

        <TermsCard icon={<MonitorPlay className="h-6 w-6" />} title="Online courses" intro="You can get a full refund if both of these are true:"
          terms={["You ask within 7 days of paying.", "You have completed less than 25% of the course's lessons."]} />

        <TermsCard icon={<GraduationCap className="h-6 w-6" />} title="Offline courses and programmes"
          intro="These terms cover all classroom courses, including the 100% Placement Programme and the Entrepreneurship Programme. Your refund depends on when you ask:"
          terms={["Before your first class: full refund.", "Within 7 days of your first class: 50% of the fee you paid.", "After that: no refund.", "100% Placement Programme: not being placed in a job is not a reason for a refund."]} />

        <TermsCard icon={<ShieldCheck className="h-6 w-6" />} title="Always refunded in full" intro="You get all your money back, at any time, if:"
          terms={["You were charged twice for the same course.", "You paid but never received access to the course.", "GTapex Academy cancels your course before it starts."]} />

        <section className="glass rounded-2xl p-6 sm:p-8">
          <h2 className="text-xl font-bold text-slate-900">How to ask for a refund</h2>
          <p className="mt-4 text-slate-600">
            Email <a href={`mailto:${EMAIL}`} className="break-all font-medium text-brand-600 hover:underline">{EMAIL}</a> or call <a href={`tel:${PHONE_LINK}`} className="font-medium text-brand-600 hover:underline">{PHONE}</a> with your name, your course and your payment reference.
          </p>
          <p className="mt-3 text-slate-600">We reply within 3 working days. Once approved, the refund goes back to your original payment method within 7 to 10 working days.</p>
          <p className="mt-3 text-slate-600">Any questions? <Link to="/contact" className="font-medium text-brand-600 hover:underline">Contact us</Link>.</p>
        </section>
      </div>
    </div>
  );
}
