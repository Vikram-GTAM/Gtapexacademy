import { CheckCircle2, Clock, Instagram, Linkedin, Mail, MapPin, MessageCircle, Phone, Send, Twitter, Youtube } from "lucide-react";
import { useState, type FormEvent, type ReactNode } from "react";
import { Button, Input, LinkButton, Textarea } from "../../components/ui";
import { useToast } from "../../context/ToastContext";
import { contactApi } from "../../services";
import { getErrorMessage } from "../../services/api";
import { ADDRESS, EMAIL, HOURS, MAP_LINK, PHONE, PHONE_LINK, WHATSAPP_LINK } from "../../utils/contactInfo";

const MAP_EMBED = `https://maps.google.com/maps?q=${encodeURIComponent(ADDRESS)}&z=15&output=embed`;

const socials = [
  { href: "https://www.instagram.com/gt_apexmarketing/", label: "Instagram", icon: <Instagram className="h-5 w-5" /> },
  { href: "https://www.linkedin.com/company/gt-marketing-garage/", label: "LinkedIn", icon: <Linkedin className="h-5 w-5" /> },
  { href: "https://www.youtube.com/@gtapexmarketing", label: "YouTube", icon: <Youtube className="h-5 w-5" /> },
  { href: "https://x.com/gtapexmarketing", label: "X", icon: <Twitter className="h-5 w-5" /> },
];

function InfoCard({ icon, title, children }: { icon: ReactNode; title: string; children: ReactNode }) {
  return (
    <div className="glass glass-hover flex gap-4 rounded-2xl p-5">
      <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-brand-50 text-brand-600">{icon}</span>
      <div className="min-w-0"><p className="text-sm font-semibold text-white">{title}</p><div className="mt-1 text-sm text-slate-500">{children}</div></div>
    </div>
  );
}

export default function Contact() {
  const toast = useToast();
  const [f, setF] = useState({ name: "", email: "", phone: "", subject: "", message: "" });
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState<string | null>(null);
  const set = (k: keyof typeof f) => (e: { target: { value: string } }) => setF((p) => ({ ...p, [k]: e.target.value }));

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    const err: Record<string, string> = {};
    if (f.name.trim().length < 2) err.name = "Please enter your name";
    if (!/^\S+@\S+\.\S+$/.test(f.email.trim())) err.email = "Enter a valid email address";
    if (f.subject.trim().length < 2) err.subject = "Please add a subject";
    if (f.message.trim().length < 5) err.message = "Please write a short message";
    setErrors(err);
    if (Object.keys(err).length) return;
    setBusy(true);
    try {
      const r = await contactApi.send({ name: f.name.trim(), email: f.email.trim(), phone: f.phone.trim() || undefined, subject: f.subject.trim(), message: f.message.trim() });
      setDone(r.message);
    } catch (ex) {
      toast.error(getErrorMessage(ex));
    } finally {
      setBusy(false);
    }
  };

  return (
    <div>
      <section className="relative overflow-hidden">
        <div className="grid-bg pointer-events-none absolute inset-0 opacity-70" />
        <div className="relative mx-auto max-w-7xl px-4 pb-6 pt-14 sm:px-6 sm:pt-20 lg:px-8">
          <div className="max-w-3xl animate-fadeUp">
            <span className="inline-flex items-center gap-2 rounded-full border border-brand-500/40 bg-brand-50 px-3.5 py-1.5 text-sm font-medium text-brand-600"><MessageCircle className="h-4 w-4" />Contact us</span>
            <h1 className="mt-6 text-4xl font-extrabold leading-tight tracking-tight text-white sm:text-5xl">Let's <span className="text-neon-gradient">talk</span></h1>
            <p className="mt-4 max-w-2xl text-lg text-slate-500">Questions about a course, fees, batches or placements? Send us a message, call, or drop by our office — we usually reply within one working day.</p>
          </div>
        </div>
      </section>

      <section className="mx-auto grid max-w-7xl gap-8 px-4 py-10 sm:px-6 lg:grid-cols-5 lg:px-8">
        <div className="space-y-4 lg:col-span-2">
          <InfoCard icon={<Phone className="h-5 w-5" />} title="Call us"><a href={`tel:${PHONE_LINK}`} className="hover:text-brand-600">{PHONE}</a></InfoCard>
          <InfoCard icon={<MessageCircle className="h-5 w-5" />} title="WhatsApp"><a href={WHATSAPP_LINK} target="_blank" rel="noreferrer" className="hover:text-brand-600">Chat with us on WhatsApp</a></InfoCard>
          <InfoCard icon={<Mail className="h-5 w-5" />} title="Email"><a href={`mailto:${EMAIL}`} className="break-all hover:text-brand-600">{EMAIL}</a></InfoCard>
          <InfoCard icon={<MapPin className="h-5 w-5" />} title="Office"><a href={MAP_LINK} target="_blank" rel="noreferrer" className="hover:text-brand-600">{ADDRESS}</a></InfoCard>
          <InfoCard icon={<Clock className="h-5 w-5" />} title="Hours">{HOURS}</InfoCard>
          <div className="glass rounded-2xl p-5">
            <p className="text-sm font-semibold text-white">Follow us</p>
            <div className="mt-3 flex gap-2">
              {socials.map((s) => <a key={s.label} href={s.href} target="_blank" rel="noreferrer" aria-label={s.label} className="flex h-10 w-10 items-center justify-center rounded-xl border border-slate-200 text-slate-600 transition hover:border-brand-500/60 hover:text-brand-600">{s.icon}</a>)}
            </div>
          </div>
        </div>

        <div className="glass rounded-2xl p-6 sm:p-8 lg:col-span-3">
          {done ? (
            <div className="py-10 text-center">
              <CheckCircle2 className="mx-auto h-14 w-14 text-brand-500" />
              <h2 className="mt-4 text-2xl font-bold text-white">Message sent</h2>
              <p className="mx-auto mt-2 max-w-sm text-slate-500">{done}</p>
              <div className="mt-6 flex justify-center gap-3"><LinkButton to="/courses" variant="outline">Browse courses</LinkButton><LinkButton to="/book-demo">Book Free Demo</LinkButton></div>
            </div>
          ) : (
            <form onSubmit={submit} noValidate className="space-y-4">
              <h2 className="text-xl font-bold text-white">Send us a message</h2>
              <div className="grid gap-4 sm:grid-cols-2">
                <Input label="Full name" value={f.name} onChange={set("name")} error={errors.name} autoComplete="name" required />
                <Input label="Email" type="email" value={f.email} onChange={set("email")} error={errors.email} autoComplete="email" required />
              </div>
              <div className="grid gap-4 sm:grid-cols-2">
                <Input label="Phone (optional)" type="tel" value={f.phone} onChange={set("phone")} autoComplete="tel" />
                <Input label="Subject" value={f.subject} onChange={set("subject")} error={errors.subject} placeholder="e.g. Fees for the SEO course" required />
              </div>
              <Textarea label="Message" value={f.message} onChange={set("message")} error={errors.message} maxLength={3000} className="min-h-[160px]" required />
              <Button type="submit" size="lg" loading={busy} icon={<Send className="h-4 w-4" />} className="w-full">Send message</Button>
            </form>
          )}
        </div>
      </section>

      <section className="mx-auto max-w-7xl px-4 pb-8 sm:px-6 lg:px-8">
        <div className="glass overflow-hidden rounded-2xl">
          <iframe title="GTapex office location" src={MAP_EMBED} className="h-80 w-full border-0 grayscale invert-[.92] hue-rotate-180" loading="lazy" referrerPolicy="no-referrer-when-downgrade" />
        </div>
      </section>
    </div>
  );
}
