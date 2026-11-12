import { Search, Users } from "lucide-react";
import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Badge, EmptyState, ErrorState, Input, PageHeader, Pagination, Select, Table } from "../../components/ui";
import { useAsync } from "../../hooks/useAsync";
import { useDebounce } from "../../hooks/useDebounce";
import { adminApi } from "../../services";
import type { AdminStudentRow } from "../../types";
import { formatDate } from "../../utils/format";

export default function AdminStudents() {
  const nav = useNavigate();
  const [search, setSearch] = useState("");
  const [status, setStatus] = useState("");
  const [page, setPage] = useState(1);
  const q = useDebounce(search, 300);
  const { data, loading, error, reloadWithSpinner } = useAsync(() => adminApi.students({ page, page_size: 15, search: q || undefined, status: status || undefined }), [page, q, status]);
  return (
    <div>
      <PageHeader title="Students" subtitle={data ? `${data.total} registered` : undefined} />
      <div className="mb-4 flex flex-col gap-3 sm:flex-row">
        <div className="flex-1 sm:max-w-sm"><Input aria-label="Search students" placeholder="Search by name or email…" icon={<Search className="h-4 w-4" />} value={search} onChange={(e) => { setSearch(e.target.value); setPage(1); }} /></div>
        <div className="sm:w-44"><Select aria-label="Status" value={status} onChange={(e) => { setStatus(e.target.value); setPage(1); }}><option value="">All</option><option value="active">Active</option><option value="disabled">Disabled</option></Select></div>
      </div>
      {error ? <ErrorState message={error} onRetry={reloadWithSpinner} /> : (
        <>
          <Table<AdminStudentRow> loading={loading} rows={data?.items ?? []} rowKey={(s) => s.id} onRowClick={(s) => nav(`/admin/students/${s.id}`)}
            empty={<EmptyState icon={<Users className="h-7 w-7" />} title="No students found" message="Students appear here after they register." />}
            columns={[
              { key: "n", header: "Student", render: (s) => <div><p className="font-semibold text-slate-900">{s.name}</p><p className="text-xs text-slate-500">{s.email}</p></div> },
              { key: "e", header: "Courses", render: (s) => s.enrolled_count, hideOnMobile: true },
              { key: "j", header: "Joined", render: (s) => formatDate(s.joined_at), hideOnMobile: true },
              { key: "s", header: "Status", render: (s) => <Badge tone={s.is_active ? "green" : "red"} dot>{s.is_active ? "Active" : "Disabled"}</Badge> },
            ]} />
          {data && <div className="mt-4"><Pagination page={data.page} pages={data.pages} onChange={setPage} /></div>}
        </>
      )}
    </div>
  );
}
