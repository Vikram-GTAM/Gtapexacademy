import { CalendarCheck, CheckCircle2, Clock, MessageCircle, Video } from "lucide-react";
import { useState, type FormEvent } from "react";
import { useSearchParams } from "react-router-dom";
import { Button, Input, LinkButton, Select, Textarea } from "../../components/ui";
import { useToast } from "../../context/ToastContext";
import { useAsync } from "../../hooks/useAsync";
import { courseApi, demoApi } from "../../services";
import { getErrorMessage } from "../../services/api";

const slots = ["Morning (9 AM – 12 PM)", "Afternoon (12 PM – 4 PM)", "Evening (4 PM – 8 PM)", "Weekend"];
const perks = [
  { icon: <Video className="h-5 w-5" />, text: "A live walkthrough of the course content and the learning platform" },
  { icon: <MessageCircle className="h-5 w-5" />, text: "Ask our team anything about the syllabus, fees and career outcomes" },
  { icon: <Clock className="h-5 w-5" />, text: "A short session — no payment, no commitment" },
];

export default function BookDemo() {
  const toast = useToast();
  const [params] = useSearchParams();
  const cats = useAsync(() => courseApi.categories());
  const [f, setF] = useState({ name: "", email: "", phone: "", course_interest: params.get("course") ?? "", preferred_time: "", message: "" });
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState<string | null>(null);
  const set = (k: keyof typeof f) => (e: { target: { value: string } }) => setF((p) => ({ ...p, [k]: e.target.value }));

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    const err: Record<string, string> = {};
    if (f.name.trim().length < 2) err.name = "Please enter your name";
    if (!/^\S+@\S+\.\S+$/.test(f.email.trim())) err.email = "Enter a valid email address";
    if (f.phone.replace(/\D/g, "").length < 7) err.phone = "Enter a valid phone number";
    setErrors(err);
    if (Object.keys(err).length) return;
    setBusy(true);
    try {
      const r = await demoApi.book({
        name: f.name.trim(), email: f.email.trim(), phone: f.phone.trim(),
        course_interest: f.course_interest || undefined, preferred_time: f.preferred_time || undefined, message: f.message.trim() || undefined,
      });
      setDone(r.message);
    } catch (ex) {
      toast.error(getErrorMessage(ex));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="relative overflow-hidden">
      <div className="grid-bg pointer-events-none absolute inset-0 opacity-70" />
      <div className="relative mx-auto grid max-w-6xl gap-10 px-4 py-14 sm:px-6 lg:grid-cols-2 lg:px-8 lg:py-20">
        <div className="animate-fadeUp">
          <span className="inline-flex items-center gap-2 rounded-full border border-brand-500/40 bg-brand-50 px-3.5 py-1.5 text-sm font-medium text-brand-600"><CalendarCheck className="h-4 w-4" />Free demo class</span>
          <h1 className="mt-5 text-4xl font-extrabold leading-tight tracking-tight text-white sm:text-5xl">Book your <span className="text-neon-gradient">free demo</span></h1>
          <p className="mt-4 max-w-md text-lg text-slate-500">See how our academy works before you enrol. Tell us a little about yourself and we'll call you to schedule a session.</p>
          <ul className="mt-8 space-y-4">
            {perks.map((p) => <li key={p.text} className="flex items-start gap-3 text-slate-600"><span className="mt-0.5 flex h-9 w-9 shrink-0 items-center justify-center rounded-lg bg-brand-50 text-brand-600">{p.icon}</span><span className="pt-1.5">{p.text}</span></li>)}
          </ul>
        </div>

        <div className="glass animate-fadeUp rounded-2xl p-6 sm:p-8">
          {done ? (
            <div className="py-8 text-center">
              <CheckCircle2 className="mx-auto h-14 w-14 text-brand-500" />
              <h2 className="mt-4 text-2xl font-bold text-white">Request received</h2>
              <p className="mx-auto mt-2 max-w-sm text-slate-500">{done}</p>
              <LinkButton to="/courses" variant="outline" className="mt-6">Browse courses</LinkButton>
            </div>
          ) : (
            <form onSubmit={submit} noValidate className="space-y-4">
              <h2 className="text-xl font-bold text-white">Your details</h2>
              <Input label="Full name" value={f.name} onChange={set("name")} error={errors.name} autoComplete="name" required />
              <div className="grid gap-4 sm:grid-cols-2">
                <Input label="Email" type="email" value={f.email} onChange={set("email")} error={errors.email} autoComplete="email" required />
                <Input label="Phone / WhatsApp" type="tel" value={f.phone} onChange={set("phone")} error={errors.phone} autoComplete="tel" required />
              </div>
              <div className="grid gap-4 sm:grid-cols-2">
                <Select label="Interested in" value={f.course_interest} onChange={set("course_interest")}>
                  <option value="">Not sure yet</option>
                  {(cats.data ?? []).map((c) => <option key={c.name} value={c.name}>{c.name}</option>)}
                </Select>
                <Select label="Preferred time" value={f.preferred_time} onChange={set("preferred_time")}>
                  <option value="">Any time</option>
                  {slots.map((s) => <option key={s} value={s}>{s}</option>)}
                </Select>
              </div>
              <Textarea label="Anything we should know? (optional)" value={f.message} onChange={set("message")} maxLength={1000} />
              <Button type="submit" size="lg" loading={busy} className="w-full">Book my free demo</Button>
              <p className="text-center text-xs text-slate-500">We only use your details to contact you about the demo.</p>
            </form>
          )}
        </div>
      </div>
    </div>
  );
}
