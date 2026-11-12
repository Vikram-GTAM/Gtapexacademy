import { Inbox } from "lucide-react";
import { Badge, Button, EmptyState, ErrorState, PageHeader, Table } from "../../components/ui";
import { useToast } from "../../context/ToastContext";
import { useAsync } from "../../hooks/useAsync";
import { adminApi } from "../../services";
import { getErrorMessage } from "../../services/api";
import type { ContactMessage } from "../../types";
import { formatDateTime } from "../../utils/format";

export default function AdminContactMessages() {
  const toast = useToast();
  const { data, loading, error, reload, reloadWithSpinner } = useAsync(() => adminApi.contactMessages());
  const toggle = async (id: string) => {
    try { await adminApi.toggleContactRead(id); reload(); } catch (e) { toast.error(getErrorMessage(e)); }
  };
  const unread = (data ?? []).filter((m) => !m.is_read).length;
  return (
    <div>
      <PageHeader title="Contact messages" subtitle={data ? `${unread} unread · ${data.length} total` : "Messages from the Contact page and Krish"} />
      {error ? <ErrorState message={error} onRetry={reloadWithSpinner} /> : (
        <Table<ContactMessage> loading={loading} rows={data ?? []} rowKey={(m) => m.id}
          empty={<EmptyState icon={<Inbox className="h-7 w-7" />} title="No messages yet" message="Messages from the Contact page and Krish will appear here." />}
          columns={[
            { key: "n", header: "From", render: (m) => <div><p className="font-semibold text-slate-900">{m.name}</p>{m.email && <a href={`mailto:${m.email}`} className="text-xs text-brand-600 hover:underline">{m.email}</a>}{m.phone && <p className="text-xs text-slate-500"><a href={`tel:${m.phone.replace(/[\s-]/g, "")}`} className="hover:underline">{m.phone}</a></p>}</div> },
            { key: "m", header: "Message", render: (m) => <div className="max-w-md"><p className="font-medium text-slate-800">{m.subject}</p><p className="mt-0.5 whitespace-pre-line text-sm text-slate-500">{m.message}</p></div> },
            { key: "d", header: "Received", render: (m) => formatDateTime(m.created_at), hideOnMobile: true },
            { key: "s", header: "Status", render: (m) => <div className="flex items-center gap-2"><Badge tone={m.is_read ? "green" : "amber"} dot>{m.is_read ? "Read" : "New"}</Badge><Button size="sm" variant="ghost" onClick={() => toggle(m.id)}>{m.is_read ? "Mark unread" : "Mark read"}</Button></div> },
          ]} />
      )}
    </div>
  );
}
