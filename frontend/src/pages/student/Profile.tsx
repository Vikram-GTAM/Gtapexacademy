import { useState, type FormEvent } from "react";
import { Button, Card, Input, PageHeader } from "../../components/ui";
import { useAuth } from "../../context/AuthContext";
import { useToast } from "../../context/ToastContext";
import { authApi } from "../../services";
import { getErrorMessage } from "../../services/api";
import { initials } from "../../utils/format";

export default function Profile() {
  const { user, setUser } = useAuth();
  const toast = useToast();
  const [name, setName] = useState(user?.name ?? "");
  const [savingName, setSavingName] = useState(false);
  const [pw, setPw] = useState({ current: "", next: "", confirm: "" });
  const [pwErr, setPwErr] = useState<string | null>(null);
  const [savingPw, setSavingPw] = useState(false);
  if (!user) return null;

  async function saveName(e: FormEvent) {
    e.preventDefault();
    if (name.trim().length < 2) { toast.error("Name must be at least 2 characters"); return; }
    setSavingName(true);
    try { setUser(await authApi.updateMe({ name: name.trim() })); toast.success("Profile updated"); }
    catch (err) { toast.error(getErrorMessage(err)); } finally { setSavingName(false); }
  }
  async function savePw(e: FormEvent) {
    e.preventDefault(); setPwErr(null);
    if (pw.next.length < 8 || !/[A-Za-z]/.test(pw.next) || !/\d/.test(pw.next)) { setPwErr("New password needs 8+ characters with letters and numbers."); return; }
    if (pw.next !== pw.confirm) { setPwErr("Passwords don't match."); return; }
    setSavingPw(true);
    try { await authApi.updateMe({ current_password: pw.current, new_password: pw.next }); toast.success("Password changed"); setPw({ current: "", next: "", confirm: "" }); }
    catch (err) { setPwErr(getErrorMessage(err)); } finally { setSavingPw(false); }
  }

  return (
    <div className="mx-auto max-w-2xl">
      <PageHeader title="Profile" subtitle="Manage your account details." />
      <Card className="mb-6">
        <div className="mb-5 flex items-center gap-4">
          <div className="flex h-16 w-16 items-center justify-center rounded-full bg-neon text-xl font-bold text-brand-ink">{initials(user.name)}</div>
          <div><p className="font-bold text-slate-900">{user.name}</p><p className="text-sm text-slate-500">{user.email}</p></div>
        </div>
        <form onSubmit={saveName} className="space-y-4">
          <Input label="Full name" value={name} onChange={(e) => setName(e.target.value)} required />
          <Input label="Email" value={user.email} disabled hint="Email can't be changed." />
          <Button type="submit" loading={savingName}>Save changes</Button>
        </form>
      </Card>
      <Card>
        <h2 className="mb-4 text-lg font-bold text-slate-900">Change password</h2>
        <form onSubmit={savePw} className="space-y-4">
          <Input label="Current password" type="password" autoComplete="current-password" value={pw.current} onChange={(e) => setPw({ ...pw, current: e.target.value })} required />
          <Input label="New password" type="password" autoComplete="new-password" value={pw.next} onChange={(e) => setPw({ ...pw, next: e.target.value })} required />
          <Input label="Confirm new password" type="password" autoComplete="new-password" value={pw.confirm} onChange={(e) => setPw({ ...pw, confirm: e.target.value })} required />
          {pwErr && <p role="alert" className="text-sm text-rose-600">{pwErr}</p>}
          <Button type="submit" loading={savingPw}>Update password</Button>
        </form>
      </Card>
    </div>
  );
}
