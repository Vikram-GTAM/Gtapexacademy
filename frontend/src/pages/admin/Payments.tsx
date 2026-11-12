import { CreditCard, Search } from "lucide-react";
import { useState } from "react";
import { Card, EmptyState, ErrorState, Input, PageHeader, Pagination, Select, Table, Badge } from "../../components/ui";
import { useAsync } from "../../hooks/useAsync";
import { useDebounce } from "../../hooks/useDebounce";
import { adminApi } from "../../services";
import type { AdminPayment } from "../../types";
import { formatDateTime, formatMoney } from "../../utils/format";

const tone = { paid: "green", created: "amber", failed: "red" } as const;
export default function AdminPayments() {
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("");
  const [mode, setMode] = useState("");
  const [page, setPage] = useState(1);
  const q = useDebounce(search, 300);
  const { data, loading, error, reloadWithSpinner } = useAsync(() => adminApi.payments({ page, page_size: 15, search: q || undefined, status: status || undefined, mode: mode || undefined }), [page, q, status, mode]);
  return (
    <div>
      <PageHeader title="Payments" subtitle="Razorpay transactions" />
      {data && <div className="mb-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4"><Card><p className="text-sm text-slate-500">Total revenue</p><p className="text-2xl font-extrabold text-slate-900">{formatMoney(data.summary.revenue)}</p></Card><Card><p className="text-sm text-slate-500">Successful payments</p><p className="text-2xl font-extrabold text-slate-900">{data.summary.paid_count}</p></Card><Card><p className="text-sm text-slate-500">Online buyers</p><p className="text-2xl font-extrabold text-slate-900">{data.summary.online_count ?? 0}</p></Card><Card><p className="text-sm text-slate-500">Offline buyers</p><p className="text-2xl font-extrabold text-slate-900">{data.summary.offline_count ?? 0}</p></Card></div>}
      <div className="mb-4 flex flex-col gap-3 sm:flex-row">
        <div className="flex-1 sm:max-w-sm"><Input aria-label="Search payments" placeholder="Search student, course or order…" icon={<Search className="h-4 w-4" />} value={search} onChange={(e) => { setSearch(e.target.value); setPage(1); }} /></div>
        <div className="sm:w-44"><Select aria-label="Status" value={status} onChange={(e) => { setStatus(e.target.value); setPage(1); }}><option value="">All statuses</option><option value="paid">Paid</option><option value="created">Pending</option><option value="failed">Failed</option></Select></div>
        <div className="sm:w-44"><Select aria-label="Buyer type" value={mode} onChange={(e) => { setMode(e.target.value); setPage(1); }}><option value="">Online and offline</option><option value="online">Online only</option><option value="offline">Offline only</option></Select></div>
      </div>
      {error ? <ErrorState message={error} onRetry={reloadWithSpinner} /> : (
        <>
          <Table<AdminPayment> loading={loading} rows={data?.items ?? []} rowKey={(p) => p.id}
            empty={<EmptyState icon={<CreditCard className="h-7 w-7" />} title="No payments yet" message="Paid enrollments will be listed here." />}
            columns={[
              { key: "s", header: "Student", render: (p) => <div><p className="font-semibold text-slate-900">{p.student_name}</p><p className="text-xs text-slate-500">{p.student_email}</p></div> },
              { key: "c", header: "Course", render: (p) => p.course_title, hideOnMobile: true },
              { key: "m", header: "Type", render: (p) => <Badge tone={p.learning_mode === "offline" ? "green" : "blue"}>{p.learning_mode === "offline" ? "Offline" : "Online"}</Badge> },
              { key: "a", header: "Amount", render: (p) => formatMoney(p.amount) },
              { key: "st", header: "Status", render: (p) => <Badge tone={tone[p.status]} dot>{p.status === "created" ? "Pending" : p.status[0].toUpperCase() + p.status.slice(1)}</Badge> },
              { key: "o", header: "Order / Payment ID", render: (p) => <span className="font-mono text-xs text-slate-500">{p.razorpay_order_id}<br />{p.razorpay_payment_id ?? "—"}</span>, hideOnMobile: true },
              { key: "d", header: "Date", render: (p) => formatDateTime(p.created_at), hideOnMobile: true },
            ]} />
          {data && <div className="mt-4"><Pagination page={data.page} pages={data.pages} onChange={setPage} /></div>}
        </>
      )}
    </div>
  );
}
