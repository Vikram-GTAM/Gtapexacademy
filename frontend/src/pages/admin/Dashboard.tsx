import { BookOpen, ClipboardCheck, CreditCard, GraduationCap, UserCheck, Users, Video } from "lucide-react";
import { Area, AreaChart, Bar, BarChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from "recharts";
import { Card, ErrorState, PageHeader, Skeleton, StatCard } from "../../components/ui";
import { useAsync } from "../../hooks/useAsync";
import { adminApi } from "../../services";
import { formatMoney } from "../../utils/format";

const tip = { contentStyle: { background: "var(--tooltip-bg)", border: "1px solid var(--card-hover-border)", borderRadius: 12, color: "var(--tooltip-fg)", fontSize: 12 }, labelStyle: { color: "var(--chart-axis)" }, itemStyle: { color: "var(--chart-1)" } };

export default function AdminDashboard() {
  const { data, loading, error, reloadWithSpinner } = useAsync(adminApi.dashboard);
  if (error) return <ErrorState message={error} onRetry={reloadWithSpinner} />;
  const s = data?.stats;
  return (
    <div>
      <PageHeader title="Dashboard" subtitle="Platform overview" />
      {loading || !s || !data ? (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">{Array.from({ length: 8 }).map((_, i) => <Skeleton key={i} className="h-24" />)}</div>
      ) : (
        <>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <StatCard label="Students" value={s.total_students} icon={<Users className="h-5 w-5" />} />
            <StatCard label="Courses" value={s.total_courses} icon={<BookOpen className="h-5 w-5" />} tone="blue" />
            <StatCard label="Enrollments" value={s.total_enrollments} icon={<GraduationCap className="h-5 w-5" />} tone="green" />
            <StatCard label="Revenue" value={formatMoney(s.total_revenue)} icon={<CreditCard className="h-5 w-5" />} tone="amber" />
            <StatCard label="Active students" value={s.active_students} icon={<UserCheck className="h-5 w-5" />} tone="green" />
            <StatCard label="Pending reviews" value={s.pending_assignments} icon={<ClipboardCheck className="h-5 w-5" />} tone="rose" />
            <StatCard label="Upcoming classes" value={s.upcoming_live_classes} icon={<Video className="h-5 w-5" />} tone="blue" />
          </div>
          <div className="mt-6 grid gap-6 lg:grid-cols-2">
            <Card>
              <h2 className="mb-4 font-bold text-slate-900">Enrollments · last 30 days</h2>
              <div className="h-64" role="img" aria-label="Enrollments over the last 30 days">
                <ResponsiveContainer width="100%" height="100%">
                  <AreaChart data={data.enrollments_series}>
                    <defs><linearGradient id="enr" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stopColor="var(--chart-1)" stopOpacity={0.35} /><stop offset="100%" stopColor="var(--chart-1)" stopOpacity={0} /></linearGradient></defs>
                    <CartesianGrid strokeDasharray="3 3" stroke="var(--c-brand-100)" vertical={false} />
                    <XAxis dataKey="date" tick={{ fontSize: 11, fill: "var(--chart-axis)" }} tickFormatter={(v: string) => v.slice(5)} interval="preserveStartEnd" />
                    <YAxis allowDecimals={false} tick={{ fontSize: 11, fill: "var(--chart-axis)" }} width={28} />
                    <Tooltip {...tip} />
                    <Area type="monotone" dataKey="count" name="Enrollments" stroke="var(--chart-1)" strokeWidth={2} fill="url(#enr)" />
                  </AreaChart>
                </ResponsiveContainer>
              </div>
            </Card>
            <Card>
              <h2 className="mb-4 font-bold text-slate-900">Revenue by month</h2>
              {data.revenue_series.every((r) => r.amount === 0) ? <p className="flex h-64 items-center justify-center text-sm text-slate-500">No paid enrollments yet.</p> : <div className="h-64" role="img" aria-label="Revenue by month">
                <ResponsiveContainer width="100%" height="100%">
                  <BarChart data={data.revenue_series}>
                    <CartesianGrid strokeDasharray="3 3" stroke="var(--c-brand-100)" vertical={false} />
                    <XAxis dataKey="month" tick={{ fontSize: 11, fill: "var(--chart-axis)" }} />
                    <YAxis tick={{ fontSize: 11, fill: "var(--chart-axis)" }} width={44} />
                    <Tooltip {...tip} cursor={{ fill: "rgba(0,255,91,0.08)" }} formatter={(v: number) => formatMoney(v)} />
                    <Bar dataKey="amount" name="Revenue" fill="var(--chart-1)" radius={[6, 6, 0, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              </div>}
            </Card>
            <Card className="lg:col-span-2">
              <h2 className="mb-4 font-bold text-slate-900">Top courses by enrollment</h2>
              {data.top_courses.length === 0 ? <p className="text-sm text-slate-500">No enrollments yet.</p> : (
                <div className="h-64" role="img" aria-label="Top courses by enrollment">
                  <ResponsiveContainer width="100%" height="100%">
                    <BarChart data={data.top_courses} layout="vertical" margin={{ left: 8 }}>
                      <CartesianGrid strokeDasharray="3 3" stroke="var(--c-brand-100)" horizontal={false} />
                      <XAxis type="number" allowDecimals={false} tick={{ fontSize: 11, fill: "var(--chart-axis)" }} />
                      <YAxis type="category" dataKey="title" width={170} tick={{ fontSize: 11, fill: "var(--chart-axis)" }} />
                      <Tooltip {...tip} cursor={{ fill: "rgba(0,255,91,0.08)" }} />
                      <Bar dataKey="enrollments" name="Enrollments" fill="var(--chart-2)" radius={[0, 6, 6, 0]} />
                    </BarChart>
                  </ResponsiveContainer>
                </div>
              )}
            </Card>
          </div>
        </>
      )}
    </div>
  );
}
