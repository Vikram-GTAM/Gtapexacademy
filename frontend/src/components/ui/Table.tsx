import { ChevronLeft, ChevronRight } from "lucide-react";
import type { ReactNode } from "react";
import { cx } from "../../utils/format";
import { Skeleton } from "./Misc";

export interface Column<T> { key: string; header: string; render: (row: T) => ReactNode; className?: string; hideOnMobile?: boolean }

export function Table<T>({ columns, rows, rowKey, loading, empty, onRowClick }: {
  columns: Column<T>[]; rows: T[]; rowKey: (r: T) => string; loading?: boolean; empty?: ReactNode; onRowClick?: (r: T) => void;
}) {
  return (
    <div className="glass overflow-hidden rounded-2xl">
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-slate-100 text-sm">
          <thead className="bg-sunken">
            <tr>{columns.map((c) => <th key={c.key} scope="col" className={cx("whitespace-nowrap px-4 py-3 text-left text-xs font-semibold uppercase tracking-wide text-slate-500", c.hideOnMobile && "hidden md:table-cell", c.className)}>{c.header}</th>)}</tr>
          </thead>
          <tbody className="divide-y divide-slate-100">
            {loading
              ? Array.from({ length: 5 }).map((_, i) => (
                  <tr key={i}>{columns.map((c) => <td key={c.key} className={cx("px-4 py-4", c.hideOnMobile && "hidden md:table-cell")}><Skeleton className="h-4 w-full max-w-[160px]" /></td>)}</tr>
                ))
              : rows.map((r) => (
                  <tr key={rowKey(r)} onClick={onRowClick ? () => onRowClick(r) : undefined} className={cx("transition-colors hover:bg-white/5", onRowClick && "cursor-pointer")}>
                    {columns.map((c) => <td key={c.key} className={cx("px-4 py-3.5 align-middle text-slate-700", c.hideOnMobile && "hidden md:table-cell", c.className)}>{c.render(r)}</td>)}
                  </tr>
                ))}
          </tbody>
        </table>
      </div>
      {!loading && rows.length === 0 && <div className="p-8 text-center text-sm text-slate-500">{empty ?? "Nothing to show yet."}</div>}
    </div>
  );
}

export function Pagination({ page, pages, onChange }: { page: number; pages: number; onChange: (p: number) => void }) {
  if (pages <= 1) return null;
  const nums: (number | "…")[] = [];
  for (let p = 1; p <= pages; p++) if (p === 1 || p === pages || Math.abs(p - page) <= 1) nums.push(p); else if (nums[nums.length - 1] !== "…") nums.push("…");
  const btn = "flex h-9 min-w-9 items-center justify-center rounded-lg px-2 text-sm font-medium transition";
  return (
    <nav className="mt-5 flex items-center justify-center gap-1" aria-label="Pagination">
      <button className={cx(btn, "text-slate-600 hover:bg-white/10 disabled:opacity-40")} disabled={page <= 1} onClick={() => onChange(page - 1)} aria-label="Previous page"><ChevronLeft className="h-4 w-4" /></button>
      {nums.map((n, i) => n === "…" ? <span key={`e${i}`} className="px-1 text-slate-400">…</span> :
        <button key={n} onClick={() => onChange(n)} aria-current={n === page ? "page" : undefined} className={cx(btn, n === page ? "bg-neon text-brand-ink" : "text-slate-600 hover:bg-white/10")}>{n}</button>)}
      <button className={cx(btn, "text-slate-600 hover:bg-white/10 disabled:opacity-40")} disabled={page >= pages} onClick={() => onChange(page + 1)} aria-label="Next page"><ChevronRight className="h-4 w-4" /></button>
    </nav>
  );
}
