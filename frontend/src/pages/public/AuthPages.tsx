import { CheckCircle2, Lock, Mail, User as UserIcon } from "lucide-react";
import { useState, type FormEvent, type ReactNode } from "react";
import { Link, useLocation, useNavigate, useSearchParams } from "react-router-dom";
import { Logo } from "../../components/Brand";
import { homeFor } from "../../components/ProtectedRoute";
import { Button, Input } from "../../components/ui";
import { useAuth } from "../../context/AuthContext";
import { useToast } from "../../context/ToastContext";
import { authApi } from "../../services";
import { getErrorCode, getErrorMessage } from "../../services/api";

function AuthShell({ title, subtitle, children, footer }: { title: string; subtitle: string; children: ReactNode; footer: ReactNode }) {
  return (
    <div className="grid min-h-screen lg:grid-cols-2">
      <div className="relative hidden overflow-hidden border-r border-slate-200 bg-panel/70 p-12 lg:flex lg:flex-col lg:justify-between">
        <div className="grid-bg pointer-events-none absolute inset-0 opacity-70" />
        <div className="pointer-events-none absolute -right-20 top-20 h-96 w-96 rounded-full bg-brand-500/20 blur-3xl" />
        <Logo />
        <div className="relative max-w-md">
          <h2 className="text-4xl font-extrabold leading-tight text-white">Learn. Launch. <span className="text-neon-gradient">Grow.</span></h2>
          <p className="mt-4 text-slate-500">Become a job-ready digital marketer with campaign-based learning.</p>
          <ul className="mt-8 space-y-4 text-slate-700">
            {["SEO, paid ads, social and content courses", "Live campaign clinics and recorded lessons", "Assignments with real feedback", "Certificates you can download and share"].map((t) => <li key={t} className="flex items-center gap-3"><CheckCircle2 className="h-5 w-5 text-brand-500" />{t}</li>)}
          </ul>
        </div>
        <p className="relative text-sm text-slate-500">© {new Date().getFullYear()} GTapex Academy</p>
      </div>
      <div className="flex items-center justify-center px-4 py-12 sm:px-8">
        <div className="glass w-full max-w-md animate-fadeUp rounded-3xl p-6 sm:p-8">
          <div className="mb-8 lg:hidden"><Logo /></div>
          <h1 className="text-3xl font-extrabold tracking-tight text-slate-900">{title}</h1>
          <p className="mt-2 text-slate-500">{subtitle}</p>
          <div className="mt-8">{children}</div>
          <div className="mt-6 text-center text-sm text-slate-500">{footer}</div>
        </div>
      </div>
    </div>
  );
}
const emailOk = (v: string) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v);

export function Login() {
  const { login } = useAuth();
  const nav = useNavigate();
  const loc = useLocation();
  const [email, setEmail] = useState(""); const [password, setPassword] = useState("");
  const [err, setErr] = useState<string | null>(null); const [busy, setBusy] = useState(false);
  async function submit(e: FormEvent) {
    e.preventDefault(); setErr(null);
    if (!email.trim() || !password) return setErr("Enter your email and password.");
    setBusy(true);
    try {
      const u = await login(email.trim(), password);
      const from = (loc.state as { from?: string } | null)?.from;
      nav(from && ((u.role === "admin") === from.startsWith("/admin") || !from.startsWith("/app") && !from.startsWith("/admin")) ? from : homeFor(u.role), { replace: true });
    } catch (e2) { setErr(getErrorMessage(e2)); } finally { setBusy(false); }
  }
  return (
    <AuthShell title="Welcome back" subtitle="Log in to continue your marketing journey." footer={<>New here? <Link to="/register" className="font-semibold text-brand-600 hover:underline">Create an account</Link></>}>
      <form onSubmit={submit} className="space-y-5" noValidate>
        {err && <div role="alert" className="rounded-xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{err}</div>}
        <Input label="Email" type="email" autoComplete="email" value={email} onChange={(e) => setEmail(e.target.value)} icon={<Mail className="h-4 w-4" />} placeholder="you@example.com" />
        <Input label="Password" type="password" autoComplete="current-password" value={password} onChange={(e) => setPassword(e.target.value)} icon={<Lock className="h-4 w-4" />} placeholder="Your password" />
        <div className="text-right"><Link to="/forgot-password" className="text-sm font-medium text-brand-600 hover:underline">Forgot password?</Link></div>
        <Button type="submit" size="lg" className="w-full" loading={busy}>Log in</Button>
      </form>
    </AuthShell>
  );
}

export function Register() {
  const { register } = useAuth();
  const nav = useNavigate();
  const toast = useToast();
  const [f, setF] = useState({ name: "", email: "", password: "" });
  const [errs, setErrs] = useState<Record<string, string>>({}); const [err, setErr] = useState<string | null>(null); const [busy, setBusy] = useState(false);
  const [confirmMessage, setConfirmMessage] = useState<string | null>(null);
  async function submit(e: FormEvent) {
    e.preventDefault(); setErr(null);
    const v: Record<string, string> = {};
    if (f.name.trim().length < 2) v.name = "Enter your full name.";
    if (!emailOk(f.email)) v.email = "Enter a valid email address.";
    if (f.password.length < 8 || !/[A-Za-z]/.test(f.password) || !/\d/.test(f.password)) v.password = "Use at least 8 characters with letters and numbers.";
    setErrs(v);
    if (Object.keys(v).length) return;
    setBusy(true);
    try { await register(f.name.trim(), f.email.trim(), f.password); toast.success("Welcome to GTapex Academy!"); nav("/app", { replace: true }); }
    catch (e2) {
      // Account created, waiting on the email link: that message is all there is left to show.
      if (getErrorCode(e2) === "confirm_email") setConfirmMessage(getErrorMessage(e2));
      else setErr(getErrorMessage(e2));
    } finally { setBusy(false); }
  }
  return (
    <AuthShell title="Create your account" subtitle="Start learning in under a minute." footer={<>Already have an account? <Link to="/login" className="font-semibold text-brand-600 hover:underline">Log in</Link></>}>
      {confirmMessage ? (
        <p role="status" className="rounded-xl border border-brand-500/40 bg-brand-50 px-4 py-3 text-center text-sm font-medium text-brand-600">{confirmMessage}</p>
      ) : (
      <form onSubmit={submit} className="space-y-5" noValidate>
        {err && <div role="alert" className="rounded-xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{err}</div>}
        <Input label="Full name" autoComplete="name" value={f.name} onChange={(e) => setF({ ...f, name: e.target.value })} error={errs.name} icon={<UserIcon className="h-4 w-4" />} placeholder="Jane Doe" />
        <Input label="Email" type="email" autoComplete="email" value={f.email} onChange={(e) => setF({ ...f, email: e.target.value })} error={errs.email} icon={<Mail className="h-4 w-4" />} placeholder="you@example.com" />
        <Input label="Password" type="password" autoComplete="new-password" value={f.password} onChange={(e) => setF({ ...f, password: e.target.value })} error={errs.password} hint="At least 8 characters, with letters and numbers." icon={<Lock className="h-4 w-4" />} />
        <Button type="submit" size="lg" className="w-full" loading={busy}>Create account</Button>
      </form>
      )}
    </AuthShell>
  );
}

export function ForgotPassword() {
  const [email, setEmail] = useState(""); const [done, setDone] = useState(false); const [err, setErr] = useState<string | null>(null); const [busy, setBusy] = useState(false);
  async function submit(e: FormEvent) {
    e.preventDefault(); setErr(null);
    if (!emailOk(email)) return setErr("Enter a valid email address.");
    setBusy(true);
    try { await authApi.forgot(email.trim()); setDone(true); } catch (e2) { setErr(getErrorMessage(e2)); } finally { setBusy(false); }
  }
  return (
    <AuthShell title="Reset your password" subtitle="We'll send you a link to choose a new one." footer={<Link to="/login" className="font-semibold text-brand-600 hover:underline">← Back to log in</Link>}>
      {done ? <div className="rounded-xl border border-emerald-200 bg-emerald-50 p-5 text-sm text-emerald-800"><CheckCircle2 className="mb-2 h-6 w-6" />If an account exists for <strong>{email}</strong>, a reset link is on its way. The link is valid for 1 hour.</div> : (
        <form onSubmit={submit} className="space-y-5" noValidate>
          {err && <div role="alert" className="rounded-xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{err}</div>}
          <Input label="Email" type="email" value={email} onChange={(e) => setEmail(e.target.value)} icon={<Mail className="h-4 w-4" />} placeholder="you@example.com" />
          <Button type="submit" size="lg" className="w-full" loading={busy}>Send reset link</Button>
        </form>)}
    </AuthShell>
  );
}

export function ResetPassword() {
  const [params] = useSearchParams(); const token = params.get("token") ?? "";
  const nav = useNavigate(); const toast = useToast();
  const [pw, setPw] = useState(""); const [pw2, setPw2] = useState(""); const [err, setErr] = useState<string | null>(null); const [busy, setBusy] = useState(false);
  async function submit(e: FormEvent) {
    e.preventDefault(); setErr(null);
    if (pw.length < 8 || !/[A-Za-z]/.test(pw) || !/\d/.test(pw)) return setErr("Use at least 8 characters with letters and numbers.");
    if (pw !== pw2) return setErr("Passwords don't match.");
    setBusy(true);
    try { await authApi.reset(token, pw); toast.success("Password updated. Please log in."); nav("/login", { replace: true }); } catch (e2) { setErr(getErrorMessage(e2)); } finally { setBusy(false); }
  }
  return (
    <AuthShell title="Choose a new password" subtitle="Make it something you'll remember." footer={<Link to="/login" className="font-semibold text-brand-600 hover:underline">← Back to log in</Link>}>
      {!token ? <div role="alert" className="rounded-xl border border-rose-200 bg-rose-50 p-4 text-sm text-rose-700">This reset link is missing its token. Please request a new one.</div> : (
        <form onSubmit={submit} className="space-y-5" noValidate>
          {err && <div role="alert" className="rounded-xl border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">{err}</div>}
          <Input label="New password" type="password" autoComplete="new-password" value={pw} onChange={(e) => setPw(e.target.value)} icon={<Lock className="h-4 w-4" />} />
          <Input label="Confirm password" type="password" autoComplete="new-password" value={pw2} onChange={(e) => setPw2(e.target.value)} icon={<Lock className="h-4 w-4" />} />
          <Button type="submit" size="lg" className="w-full" loading={busy}>Update password</Button>
        </form>)}
    </AuthShell>
  );
}
