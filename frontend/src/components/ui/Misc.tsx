import { AlertTriangle, Inbox, Loader2 } from "lucide-react";
import type { ReactNode } from "react";
import { cx } from "../../utils/format";
import { Button } from "./Button";

export function Card({ children, className, padded = true }: { children: ReactNode; className?: string; padded?: boolean }) {
  return <div className={cx("glass rounded-2xl", padded && "p-5", className)}>{children}</div>;
}

const tones = {
  slate: "bg-white/10 text-slate-700", brand: "bg-brand-100 text-brand-600", green: "bg-emerald-50 text-emerald-700",
  amber: "bg-amber-50 text-amber-700", red: "bg-rose-50 text-rose-700", blue: "bg-sky-50 text-sky-700",
};
export type Tone = keyof typeof tones;
export function Badge({ children, tone = "slate", dot, className }: { children: ReactNode; tone?: Tone; dot?: boolean; className?: string }) {
  return (
    <span className={cx("inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-xs font-medium", tones[tone], className)}>
      {dot && <span className="h-1.5 w-1.5 rounded-full bg-current" />}{children}
    </span>
  );
}

export function ProgressBar({ value, size = "md", showLabel, className }: { value: number; size?: "sm" | "md"; showLabel?: boolean; className?: string }) {
  const v = Math.max(0, Math.min(100, value));
  return (
    <div className={cx("flex items-center gap-3", className)}>
      <div className={cx("flex-1 overflow-hidden rounded-full bg-slate-100", size === "sm" ? "h-1.5" : "h-2.5")} role="progressbar" aria-valuenow={Math.round(v)} aria-valuemin={0} aria-valuemax={100}>
        <div className={cx("h-full rounded-full transition-all duration-500", v >= 100 ? "bg-emerald-500" : "bg-neon")} style={{ width: `${v}%` }} />
      </div>
      {showLabel && <span className="w-10 text-right text-xs font-semibold text-slate-600">{Math.round(v)}%</span>}
    </div>
  );
}

export function Skeleton({ className }: { className?: string }) {
  return <div className={cx("animate-pulse rounded-lg bg-white/10", className)} aria-hidden="true" />;
}
export function CardSkeleton() {
  return (
    <div className="glass overflow-hidden rounded-2xl">
      <Skeleton className="h-40 rounded-none" />
      <div className="space-y-3 p-4"><Skeleton className="h-4 w-1/3" /><Skeleton className="h-5 w-4/5" /><Skeleton className="h-4 w-full" /><Skeleton className="h-9 w-full" /></div>
    </div>
  );
}

export function Spinner({ className }: { className?: string }) { return <Loader2 className={cx("animate-spin text-brand-600", className ?? "h-6 w-6")} />; }
export function PageLoader() { return <div className="flex min-h-[40vh] items-center justify-center"><Spinner className="h-8 w-8" /></div>; }

export function EmptyState({ icon, title, message, action }: { icon?: ReactNode; title: string; message?: string; action?: ReactNode }) {
  return (
    <div className="flex flex-col items-center justify-center rounded-2xl border border-dashed border-slate-300 bg-white/[0.03] px-6 py-14 text-center">
      <div className="mb-4 flex h-14 w-14 items-center justify-center rounded-2xl border border-slate-200 bg-brand-50 text-brand-600">{icon ?? <Inbox className="h-7 w-7" />}</div>
      <h3 className="text-base font-semibold text-slate-900">{title}</h3>
      {message && <p className="mt-1 max-w-sm text-sm text-slate-500">{message}</p>}
      {action && <div className="mt-5">{action}</div>}
    </div>
  );
}

export function ErrorState({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <div className="flex flex-col items-center justify-center rounded-2xl border border-rose-200 bg-rose-50 px-6 py-12 text-center" role="alert">
      <div className="mb-3 flex h-12 w-12 items-center justify-center rounded-2xl bg-rose-100 text-rose-500"><AlertTriangle className="h-6 w-6" /></div>
      <h3 className="text-base font-semibold text-slate-900">Something went wrong</h3>
      <p className="mt-1 max-w-md text-sm text-slate-600">{message}</p>
      {onRetry && <Button className="mt-5" variant="outline" onClick={onRetry}>Try again</Button>}
    </div>
  );
}

export function PageHeader({ title, subtitle, actions }: { title: string; subtitle?: string; actions?: ReactNode }) {
  return (
    <div className="mb-6 flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
      <div><h1 className="text-2xl font-bold tracking-tight text-slate-900 sm:text-3xl">{title}</h1>{subtitle && <p className="mt-1 text-sm text-slate-500">{subtitle}</p>}</div>
      {actions && <div className="flex flex-wrap gap-2">{actions}</div>}
    </div>
  );
}

export function StatCard({ label, value, icon, tone = "brand" }: { label: string; value: ReactNode; icon: ReactNode; tone?: "brand" | "green" | "amber" | "blue" | "rose" }) {
  const t = { brand: "bg-brand-50 text-brand-600", green: "bg-emerald-50 text-emerald-600", amber: "bg-amber-50 text-amber-600", blue: "bg-sky-50 text-sky-600", rose: "bg-rose-50 text-rose-600" }[tone];
  return (
    <Card className="flex items-center gap-4">
      <div className={cx("flex h-12 w-12 shrink-0 items-center justify-center rounded-xl", t)}>{icon}</div>
      <div className="min-w-0"><p className="truncate text-sm text-slate-500">{label}</p><p className="text-2xl font-bold text-slate-900">{value}</p></div>
    </Card>
  );
}

export function Tabs<T extends string>({ tabs, value, onChange }: { tabs: { id: T; label: string; count?: number }[]; value: T; onChange: (t: T) => void }) {
  return (
    <div className="flex gap-1 overflow-x-auto rounded-xl border border-slate-200 bg-sunken p-1" role="tablist">
      {tabs.map((t) => (
        <button key={t.id} role="tab" aria-selected={value === t.id} onClick={() => onChange(t.id)}
          className={cx("whitespace-nowrap rounded-lg px-3.5 py-1.5 text-sm font-medium transition", value === t.id ? "bg-brand-100 text-brand-600 shadow-[inset_0_0_0_1px_rgba(0,255,91,.35)]" : "text-slate-500 hover:text-slate-800")}>
          {t.label}{t.count !== undefined && <span className="ml-1.5 text-xs text-slate-400">{t.count}</span>}
        </button>
      ))}
    </div>
  );
}
