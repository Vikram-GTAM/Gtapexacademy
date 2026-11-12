import { ClipboardList } from "lucide-react";
import { useState } from "react";
import { AssignmentRow, assignmentState } from "../../components/Cards";
import { Card, EmptyState, ErrorState, PageHeader, Skeleton, Tabs } from "../../components/ui";
import { useAsync } from "../../hooks/useAsync";
import { studentApi } from "../../services";

type Tab = "all" | "pending" | "submitted" | "graded";
export default function Assignments() {
  const { data, loading, error, reloadWithSpinner } = useAsync(studentApi.assignments);
  const [tab, setTab] = useState<Tab>("all");
  const all = data ?? [];
  const bucket = (a: (typeof all)[number]): Tab => {
    const l = assignmentState(a).label;
    return l === "Graded" ? "graded" : l === "Submitted" ? "submitted" : "pending";
  };
  const list = all.filter((a) => tab === "all" || bucket(a) === tab);
  const count = (t: Tab) => all.filter((a) => bucket(a) === t).length;
  return (
    <div>
      <PageHeader title="Assignments" subtitle="Submit work before the deadline and track your grades." />
      <div className="mb-6">
        <Tabs<Tab> value={tab} onChange={setTab} tabs={[
          { id: "all", label: "All", count: all.length }, { id: "pending", label: "To do", count: count("pending") },
          { id: "submitted", label: "Submitted", count: count("submitted") }, { id: "graded", label: "Graded", count: count("graded") },
        ]} />
      </div>
      {error ? <ErrorState message={error} onRetry={reloadWithSpinner} /> : loading ? (
        <div className="space-y-3">{Array.from({ length: 4 }).map((_, i) => <Skeleton key={i} className="h-20 w-full" />)}</div>
      ) : list.length === 0 ? (
        <EmptyState icon={<ClipboardList className="h-7 w-7" />} title="No assignments here" message="Assignments from your enrolled courses will appear here." />
      ) : (
        <Card padded={false} className="divide-y divide-slate-100">{list.map((a) => <AssignmentRow key={a.id} a={a} />)}</Card>
      )}
    </div>
  );
}
