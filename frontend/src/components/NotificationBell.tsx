import { Bell, CheckCheck, CalendarClock, Award, ClipboardCheck, CreditCard, GraduationCap, Megaphone, FileText, HelpCircle } from "lucide-react";
import { useCallback, useEffect, useRef, useState, type ReactNode } from "react";
import { Link } from "react-router-dom";
import { notificationApi } from "../services";
import type { Notification } from "../types";
import { cx, timeAgo } from "../utils/format";

const icons: Record<string, ReactNode> = {
  enrollment: <GraduationCap className="h-4 w-4" />, live_class: <CalendarClock className="h-4 w-4" />, assignment_deadline: <ClipboardCheck className="h-4 w-4" />,
  assignment_graded: <ClipboardCheck className="h-4 w-4" />, new_content: <FileText className="h-4 w-4" />, quiz: <HelpCircle className="h-4 w-4" />,
  payment: <CreditCard className="h-4 w-4" />, certificate: <Award className="h-4 w-4" />, course_completed: <Award className="h-4 w-4" />,
  announcement: <Megaphone className="h-4 w-4" />, submission: <FileText className="h-4 w-4" />,
};

export function NotificationBell({ allPath }: { allPath?: string }) {
  const [open, setOpen] = useState(false);
  const [items, setItems] = useState<Notification[]>([]);
  const [unread, setUnread] = useState(0);
  const ref = useRef<HTMLDivElement>(null);

  const load = useCallback(() => { notificationApi.list().then((r) => { setItems(r.items.slice(0, 8)); setUnread(r.unread_count); }).catch(() => undefined); }, []);
  useEffect(() => { load(); const t = setInterval(load, 60000); window.addEventListener("lms:notifications", load); return () => { clearInterval(t); window.removeEventListener("lms:notifications", load); }; }, [load]);
  useEffect(() => {
    if (!open) return;
    const click = (e: MouseEvent) => ref.current && !ref.current.contains(e.target as Node) && setOpen(false);
    const key = (e: KeyboardEvent) => e.key === "Escape" && setOpen(false);
    document.addEventListener("mousedown", click); document.addEventListener("keydown", key);
    return () => { document.removeEventListener("mousedown", click); document.removeEventListener("keydown", key); };
  }, [open]);

  const markAll = async () => { await notificationApi.readAll().catch(() => undefined); load(); };
  const markOne = async (n: Notification) => { if (!n.is_read) { await notificationApi.read(n.id).catch(() => undefined); load(); } };

  return (
    <div className="relative" ref={ref}>
      <button onClick={() => { setOpen((o) => !o); if (!open) load(); }} aria-label={`Notifications${unread ? `, ${unread} unread` : ""}`} aria-expanded={open}
        className="relative rounded-xl p-2.5 text-slate-500 transition hover:bg-white/10 hover:text-slate-800">
        <Bell className="h-5 w-5" />
        {unread > 0 && <span className="absolute right-1.5 top-1.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-rose-500 px-1 text-[10px] font-bold text-white">{unread > 9 ? "9+" : unread}</span>}
      </button>
      {open && (
        <div className="fixed inset-x-3 top-16 z-50 animate-pop overflow-hidden rounded-2xl glass shadow-2xl sm:absolute sm:inset-x-auto sm:right-0 sm:top-auto sm:mt-2 sm:w-96">
          <div className="flex items-center justify-between border-b border-slate-100 px-4 py-3">
            <h3 className="text-sm font-semibold text-slate-900">Notifications</h3>
            {unread > 0 && <button onClick={markAll} className="flex items-center gap-1 text-xs font-medium text-brand-600 hover:underline"><CheckCheck className="h-3.5 w-3.5" />Mark all read</button>}
          </div>
          <div className="max-h-96 overflow-y-auto">
            {items.length === 0 ? <p className="px-4 py-10 text-center text-sm text-slate-500">You're all caught up 🎉</p> :
              items.map((n) => (
                <button key={n.id} onClick={() => markOne(n)} className={cx("flex w-full gap-3 border-b border-slate-100 px-4 py-3 text-left transition hover:bg-white/5", !n.is_read && "bg-brand-50/40")}>
                  <span className={cx("mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-lg", n.is_read ? "bg-slate-100 text-slate-500" : "bg-brand-100 text-brand-600")}>{icons[n.type] ?? <Bell className="h-4 w-4" />}</span>
                  <span className="min-w-0 flex-1">
                    <span className="block text-sm font-medium text-slate-800">{n.title}</span>
                    {n.message && <span className="mt-0.5 line-clamp-2 block text-xs text-slate-500">{n.message}</span>}
                    <span className="mt-1 block text-[11px] text-slate-400">{timeAgo(n.created_at)}</span>
                  </span>
                  {!n.is_read && <span className="mt-2 h-2 w-2 shrink-0 rounded-full bg-neon" />}
                </button>
              ))}
          </div>
          {allPath && <Link to={allPath} onClick={() => setOpen(false)} className="block border-t border-slate-100 px-4 py-2.5 text-center text-sm font-medium text-brand-600 hover:bg-white/5">View all notifications</Link>}
        </div>
      )}
    </div>
  );
}
