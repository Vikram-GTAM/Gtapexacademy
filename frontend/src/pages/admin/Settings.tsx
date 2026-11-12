import { CheckCircle2, XCircle } from "lucide-react";
import { Badge, Card, ErrorState, PageHeader, PageLoader } from "../../components/ui";
import { useAsync } from "../../hooks/useAsync";
import { adminApi } from "../../services";

export default function AdminSettings() {
  const { data, loading, error, reloadWithSpinner } = useAsync(adminApi.settings);
  if (loading) return <PageLoader />;
  if (error || !data) return <ErrorState message={error ?? "Could not load settings"} onRetry={reloadWithSpinner} />;
  const rows: [string, React.ReactNode][] = [
    ["Platform name", data.platform_name],
    ["File storage", <Badge key="s" tone="blue">{data.storage_backend}</Badge>],
    ["Max upload size", `${data.max_upload_mb} MB`],
    ["Razorpay", data.razorpay_configured ? <span key="r" className="inline-flex items-center gap-1.5 text-emerald-700"><CheckCircle2 className="h-4 w-4" />Configured ({data.razorpay_mode} mode)</span> : <span key="r" className="inline-flex items-center gap-1.5 text-amber-700"><XCircle className="h-4 w-4" />Not configured</span>],
  ];
  return (
    <div className="mx-auto max-w-2xl">
      <PageHeader title="Settings" subtitle="Platform configuration is managed in Supabase." />
      <Card padded={false}><dl className="divide-y divide-slate-100">{rows.map(([k, v]) => <div key={k} className="flex items-center justify-between gap-4 px-5 py-4"><dt className="text-sm text-slate-500">{k}</dt><dd className="text-sm font-semibold text-slate-900">{v}</dd></div>)}</dl></Card>
      {!data.razorpay_configured && <p className="mt-4 rounded-xl bg-amber-50 p-4 text-sm text-amber-800">Add <code>RAZORPAY_KEY_ID</code> and <code>RAZORPAY_KEY_SECRET</code> (test-mode keys) as Supabase secrets and deploy the payment functions to enable paid course checkout.</p>}
    </div>
  );
}
