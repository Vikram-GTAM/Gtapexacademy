import { Video } from "lucide-react";
import { useState } from "react";
import { LiveClassCard } from "../../components/Cards";
import { EmptyState, ErrorState, PageHeader, Skeleton, Tabs } from "../../components/ui";
import { useAsync } from "../../hooks/useAsync";
import { liveApi } from "../../services";

type Tab = "upcoming" | "live" | "completed";
export default function LiveClasses() {
  const { data, loading, error, reloadWithSpinner } = useAsync(() => liveApi.list({ include_past: true }));
  const [tab, setTab] = useState<Tab>("upcoming");
  const all = data ?? [];
  const list = all.filter((c) => c.status === tab);
  const sorted = tab === "completed" ? [...list].reverse() : list;
  return (
    <div>
      <PageHeader title="Live classes" subtitle="The join link unlocks 15 minutes before a class begins." />
      <div className="mb-6"><Tabs<Tab> value={tab} onChange={setTab} tabs={[
        { id: "upcoming", label: "Upcoming", count: all.filter((c) => c.status === "upcoming").length },
        { id: "live", label: "Live now", count: all.filter((c) => c.status === "live").length },
        { id: "completed", label: "Completed", count: all.filter((c) => c.status === "completed").length },
      ]} /></div>
      {error ? <ErrorState message={error} onRetry={reloadWithSpinner} /> : loading ? (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">{Array.from({ length: 3 }).map((_, i) => <Skeleton key={i} className="h-52 w-full" />)}</div>
      ) : sorted.length === 0 ? (
        <EmptyState icon={<Video className="h-7 w-7" />} title={`No ${tab === "live" ? "live" : tab} classes`} message="Classes for your enrolled courses will show up here." />
      ) : (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">{sorted.map((c) => <LiveClassCard key={c.id} lc={c} />)}</div>
      )}
    </div>
  );
}
