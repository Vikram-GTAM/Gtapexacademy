import { CalendarCheck } from "lucide-react";
import { Badge, Button, EmptyState, ErrorState, PageHeader, Table } from "../../components/ui";
import { useToast } from "../../context/ToastContext";
import { useAsync } from "../../hooks/useAsync";
import { adminApi } from "../../services";
import { getErrorMessage } from "../../services/api";
import type { DemoRequest } from "../../types";
import { formatDateTime } from "../../utils/format";

export default function AdminDemoRequests() {
  const toast = useToast();
  const { data, loading, error, reload, reloadWithSpinner } = useAsync(() => adminApi.demoRequests());
  const toggle = async (id: string) => {
    try { await adminApi.toggleDemoContacted(id); reload(); } catch (e) { toast.error(getErrorMessage(e)); }
  };
  const pending = (data ?? []).filter((r) => !r.is_contacted).length;
  return (
    <div>
      <PageHeader title="Demo requests" subtitle={data ? `${pending} awaiting contact · ${data.length} total` : "People who booked a free demo"} />
      {error ? <ErrorState message={error} onRetry={reloadWithSpinner} /> : (
        <Table<DemoRequest> loading={loading} rows={data ?? []} rowKey={(r) => r.id}
          empty={<EmptyState icon={<CalendarCheck className="h-7 w-7" />} title="No demo requests yet" message="Requests from the Book Free Demo form will appear here." />}
          columns={[
            { key: "n", header: "Name", render: (r) => <div><p className="font-semibold text-slate-900">{r.name}</p><p className="text-xs text-slate-500">{r.email}</p></div> },
            { key: "p", header: "Phone", render: (r) => <a href={`tel:${r.phone}`} className="text-brand-600 hover:underline">{r.phone}</a> },
            { key: "c", header: "Interest / time", render: (r) => <div><p>{r.course_interest ?? "—"}</p><p className="text-xs text-slate-500">{r.preferred_time ?? "Any time"}</p></div>, hideOnMobile: true },
            { key: "m", header: "Message", render: (r) => <span className="line-clamp-2 text-slate-500">{r.message ?? "—"}</span>, hideOnMobile: true },
            { key: "d", header: "Requested", render: (r) => formatDateTime(r.created_at), hideOnMobile: true },
            { key: "s", header: "Status", render: (r) => <div className="flex items-center gap-2"><Badge tone={r.is_contacted ? "green" : "amber"} dot>{r.is_contacted ? "Contacted" : "New"}</Badge><Button size="sm" variant="ghost" onClick={() => toggle(r.id)}>{r.is_contacted ? "Undo" : "Mark contacted"}</Button></div> },
          ]} />
      )}
    </div>
  );
}
