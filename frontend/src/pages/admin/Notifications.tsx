import { Megaphone, Send } from "lucide-react";
import { useState, type FormEvent } from "react";
import { Button, Card, Input, PageHeader, Select, Textarea } from "../../components/ui";
import { useToast } from "../../context/ToastContext";
import { useAsync } from "../../hooks/useAsync";
import { adminApi } from "../../services";
import { getErrorMessage } from "../../services/api";

export default function AdminNotifications() {
  const toast = useToast();
  const courses = useAsync(() => adminApi.courses());
  const [title, setTitle] = useState("");
  const [message, setMessage] = useState("");
  const [courseId, setCourseId] = useState("");
  const [busy, setBusy] = useState(false);
  async function send(e: FormEvent) {
    e.preventDefault();
    if (!title.trim()) { toast.error("Add a title"); return; }
    setBusy(true);
    try {
      const r = await adminApi.broadcast({ title: title.trim(), message: message.trim(), course_id: courseId || null });
      toast.success(r.message); setTitle(""); setMessage("");
    } catch (e2) { toast.error(getErrorMessage(e2)); } finally { setBusy(false); }
  }
  return (
    <div className="mx-auto max-w-2xl">
      <PageHeader title="Notifications" subtitle="Send an announcement to students. It appears in their notification bell." />
      <Card>
        <div className="mb-4 flex items-center gap-2 text-brand-700"><Megaphone className="h-5 w-5" /><h2 className="font-bold">New announcement</h2></div>
        <form onSubmit={send} className="space-y-4">
          <Select label="Audience" value={courseId} onChange={(e) => setCourseId(e.target.value)}><option value="">All students</option>{courses.data?.map((c) => <option key={c.id} value={c.id}>Enrolled in: {c.title}</option>)}</Select>
          <Input label="Title" maxLength={200} value={title} onChange={(e) => setTitle(e.target.value)} required />
          <Textarea label="Message" rows={4} value={message} onChange={(e) => setMessage(e.target.value)} />
          <Button type="submit" loading={busy} icon={<Send className="h-4 w-4" />}>Send announcement</Button>
        </form>
      </Card>
    </div>
  );
}
