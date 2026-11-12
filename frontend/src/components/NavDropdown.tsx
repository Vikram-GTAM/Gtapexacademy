import { ChevronDown } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { Link, useLocation } from "react-router-dom";
import { cx } from "../utils/format";

export interface NavDropdownItem { to: string; label: string; hint?: string }

/** Header nav item with a ▾ menu. Opens on hover (desktop) and on click/tap; closes on Escape, outside click and navigation. */
export function NavDropdown({ label, to, items, active }: { label: string; to: string; items: NavDropdownItem[]; active: boolean }) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  const { pathname, search } = useLocation();
  useEffect(() => setOpen(false), [pathname, search]);
  useEffect(() => {
    if (!open) return;
    const click = (e: MouseEvent) => ref.current && !ref.current.contains(e.target as Node) && setOpen(false);
    const key = (e: KeyboardEvent) => e.key === "Escape" && setOpen(false);
    document.addEventListener("mousedown", click);
    document.addEventListener("keydown", key);
    return () => { document.removeEventListener("mousedown", click); document.removeEventListener("keydown", key); };
  }, [open]);
  return (
    <div ref={ref} className="relative" onMouseEnter={() => setOpen(true)} onMouseLeave={() => setOpen(false)}>
      <button type="button" onClick={() => setOpen((o) => !o)} aria-haspopup="menu" aria-expanded={open}
        className={cx("flex items-center gap-1 rounded-lg px-3 py-2 text-sm font-medium transition", active || open ? "text-brand-600" : "text-slate-600 hover:text-slate-900")}>
        {label}<ChevronDown className={cx("h-4 w-4 transition-transform", open && "rotate-180")} />
      </button>
      {open && (
        <div className="absolute left-0 top-full z-50 w-64 pt-2">
          <div role="menu" className="glass animate-pop overflow-hidden rounded-xl py-1 shadow-xl">
            <Link role="menuitem" to={to} className="block border-b border-slate-100 px-4 py-2.5 text-sm font-semibold text-brand-600 hover:bg-white/5">All courses →</Link>
            {items.length === 0 && <p className="px-4 py-2.5 text-sm text-slate-500">No categories yet</p>}
            {items.map((i) => (
              <Link key={i.to} role="menuitem" to={i.to} className="flex items-center justify-between gap-3 px-4 py-2.5 text-sm text-slate-700 hover:bg-white/5 hover:text-white">
                <span className="truncate">{i.label}</span>{i.hint && <span className="text-xs text-slate-500">{i.hint}</span>}
              </Link>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
