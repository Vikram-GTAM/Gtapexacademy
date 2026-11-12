import { Bell, CheckCheck } from "lucide-react";
import { Button, Card, EmptyState, ErrorState, PageHeader, Skeleton } from "../../components/ui";
import { useAsync } from "../../hooks/useAsync";
import { notificationApi } from "../../services";
import { cx, timeAgo } from "../../utils/format";

export default function Notifications() {
  const { data, loading, error, reload, reloadWithSpinner } = useAsync(notificationApi.list);
  const items = data?.items ?? [];
  async function readAll() { await notificationApi.readAll(); reload(); window.dispatchEvent(new Event("lms:notifications")); }
  async function readOne(id: string, isRead: boolean) { if (isRead) return; await notificationApi.read(id); reload(); window.dispatchEvent(new Event("lms:notifications")); }
  return (
    <div className="mx-auto max-w-3xl">
      <PageHeader title="Notifications" subtitle={data ? `${data.unread_count} unread` : undefined}
        actions={<Button variant="outline" icon={<CheckCheck className="h-4 w-4" />} onClick={readAll} disabled={!data?.unread_count}>Mark all as read</Button>} />
      {error ? <ErrorState message={error} onRetry={reloadWithSpinner} /> : loading ? (
        <div className="space-y-3">{Array.from({ length: 4 }).map((_, i) => <Skeleton key={i} className="h-20" />)}</div>
      ) : items.length === 0 ? (
        <EmptyState icon={<Bell className="h-7 w-7" />} title="You're all caught up" message="New announcements, deadlines and grades will appear here." />
      ) : (
        <Card padded={false} className="divide-y divide-slate-100">
          {items.map((n) => (
            <button key={n.id} onClick={() => readOne(n.id, n.is_read)} className={cx("flex w-full items-start gap-3 px-5 py-4 text-left hover:bg-white/5", !n.is_read && "bg-brand-50/40")}>
              <span className={cx("mt-2 h-2 w-2 shrink-0 rounded-full", n.is_read ? "bg-transparent" : "bg-neon")} />
              <span className="min-w-0 flex-1"><span className="block font-semibold text-slate-900">{n.title}</span>{n.message && <span className="mt-0.5 block text-sm text-slate-600">{n.message}</span>}<span className="mt-1 block text-xs text-slate-400">{timeAgo(n.created_at)}</span></span>
            </button>
          ))}
        </Card>
      )}
    </div>
  );
}
