import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from "react";
import { AlertCircle, CheckCircle2, Info, X } from "lucide-react";
import { cx } from "../utils/format";

type Kind = "success" | "error" | "info";
interface ToastItem { id: number; kind: Kind; message: string }
interface ToastApi { success: (m: string) => void; error: (m: string) => void; info: (m: string) => void }
const Ctx = createContext<ToastApi | null>(null);
let counter = 0;

export function ToastProvider({ children }: { children: ReactNode }) {
  const [items, setItems] = useState<ToastItem[]>([]);
  const dismiss = useCallback((id: number) => setItems((l) => l.filter((t) => t.id !== id)), []);
  const push = useCallback((kind: Kind, message: string) => {
    const id = ++counter;
    setItems((l) => [...l, { id, kind, message }]);
    setTimeout(() => dismiss(id), kind === "error" ? 6000 : 3500);
  }, [dismiss]);
  const api = useMemo<ToastApi>(() => ({ success: (m) => push("success", m), error: (m) => push("error", m), info: (m) => push("info", m) }), [push]);

  const icon = { success: <CheckCircle2 className="h-5 w-5 text-brand-500" />, error: <AlertCircle className="h-5 w-5 text-rose-500" />, info: <Info className="h-5 w-5 text-brand-500" /> };
  return (
    <Ctx.Provider value={api}>
      {children}
      <div className="pointer-events-none fixed inset-x-0 top-4 z-[100] flex flex-col items-center gap-2 px-4 sm:items-end sm:pr-6" aria-live="polite">
        {items.map((t) => (
          <div key={t.id} role="status" className={cx("pointer-events-auto flex w-full max-w-sm animate-pop items-start gap-3 glass rounded-xl p-3.5 shadow-lg",
            t.kind === "error" ? "!border-rose-400/50" : t.kind === "success" ? "!border-brand-500/60 shadow-glow-sm" : "")}>
            <span className="mt-0.5">{icon[t.kind]}</span>
            <p className="flex-1 text-sm text-slate-700">{t.message}</p>
            <button onClick={() => dismiss(t.id)} aria-label="Dismiss" className="text-slate-400 hover:text-slate-600"><X className="h-4 w-4" /></button>
          </div>
        ))}
      </div>
    </Ctx.Provider>
  );
}
export function useToast() {
  const c = useContext(Ctx);
  if (!c) throw new Error("useToast must be used inside ToastProvider");
  return c;
}
