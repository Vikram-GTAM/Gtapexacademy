import { useEffect, useRef, useState, type ReactNode } from "react";
import { cx } from "../../utils/format";

export interface DropdownItem { label: string; icon?: ReactNode; onClick: () => void; danger?: boolean; hidden?: boolean }

export function Dropdown({ trigger, items, align = "right", header, label }: { trigger: ReactNode; items: DropdownItem[]; align?: "left" | "right"; header?: ReactNode; label: string }) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (!open) return;
    const click = (e: MouseEvent) => ref.current && !ref.current.contains(e.target as Node) && setOpen(false);
    const key = (e: KeyboardEvent) => e.key === "Escape" && setOpen(false);
    document.addEventListener("mousedown", click);
    document.addEventListener("keydown", key);
    return () => { document.removeEventListener("mousedown", click); document.removeEventListener("keydown", key); };
  }, [open]);
  return (
    <div className="relative" ref={ref}>
      <button onClick={() => setOpen((o) => !o)} aria-haspopup="menu" aria-expanded={open} aria-label={label} className="rounded-xl focus:outline-none focus-visible:ring-2 focus-visible:ring-brand-500">{trigger}</button>
      {open && (
        <div role="menu" className={cx("absolute z-40 mt-2 w-56 animate-pop overflow-hidden glass rounded-xl py-1 shadow-xl", align === "right" ? "right-0" : "left-0")}>
          {header && <div className="border-b border-slate-100 px-3.5 py-2.5">{header}</div>}
          {items.filter((i) => !i.hidden).map((i) => (
            <button key={i.label} role="menuitem" onClick={() => { setOpen(false); i.onClick(); }}
              className={cx("flex w-full items-center gap-2.5 px-3.5 py-2 text-left text-sm hover:bg-white/5", i.danger ? "text-rose-500" : "text-slate-700")}>
              {i.icon}{i.label}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
