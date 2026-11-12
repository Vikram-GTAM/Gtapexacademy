import { Globe, LogOut, Menu, User, X } from "lucide-react";
import { Suspense, useEffect, useState, type ReactNode } from "react";
import { NavLink, Outlet, useLocation, useNavigate } from "react-router-dom";
import { Logo } from "../components/Brand";
import { NotificationBell } from "../components/NotificationBell";
import { ThemeToggle } from "../components/ThemeToggle";
import { Badge, Dropdown, PageLoader } from "../components/ui";
import { useAuth } from "../context/AuthContext";
import { cx, initials } from "../utils/format";

export interface NavItem { to: string; label: string; icon: ReactNode; end?: boolean }

function SidebarContent({ items, onNavigate, badge, logoTo }: { items: NavItem[]; onNavigate?: () => void; badge?: string; logoTo: string }) {
  return (
    <div className="flex h-full flex-col">
      <div className="flex h-16 shrink-0 items-center gap-2 border-b border-slate-100 px-4">
        <Logo to={logoTo} compact={!!badge} />{badge && <Badge tone="brand" className="shrink-0">{badge}</Badge>}
      </div>
      <nav className="flex-1 space-y-1 overflow-y-auto p-3" aria-label="Sidebar">
        {items.map((i) => (
          <NavLink key={i.to} to={i.to} end={i.end} onClick={onNavigate}
            className={({ isActive }) => cx("flex items-center gap-3 rounded-xl px-3 py-2.5 text-sm font-medium transition", isActive ? "bg-brand-100 text-brand-600 shadow-[inset_0_0_0_1px_rgba(0,255,91,.3),0_0_18px_rgba(0,255,91,.12)]" : "text-slate-600 hover:bg-white/5 hover:text-slate-900")}>
            <span className="h-5 w-5 shrink-0 [&>svg]:h-5 [&>svg]:w-5">{i.icon}</span>{i.label}
          </NavLink>
        ))}
      </nav>
    </div>
  );
}

export function AppShell({ items, badge, notificationsPath }: { items: NavItem[]; badge?: string; notificationsPath?: string }) {
  const [open, setOpen] = useState(false);
  const { user, logout } = useAuth();
  const nav = useNavigate();
  const { pathname } = useLocation();
  useEffect(() => setOpen(false), [pathname]);
  const home = items[0]?.to ?? "/";
  return (
    <div className="min-h-screen">
      <aside className="fixed inset-y-0 left-0 z-30 hidden w-64 border-r border-slate-200 bg-panel/90 backdrop-blur-xl lg:block"><SidebarContent items={items} badge={badge} logoTo={home} /></aside>
      {open && (
        <div className="fixed inset-0 z-50 lg:hidden" role="dialog" aria-modal="true" aria-label="Navigation menu">
          <div className="absolute inset-0 bg-black/70 backdrop-blur-sm" onClick={() => setOpen(false)} />
          <div className="absolute inset-y-0 left-0 w-72 max-w-[85vw] animate-slideInLeft border-r border-slate-200 bg-panel shadow-2xl">
            <button onClick={() => setOpen(false)} aria-label="Close menu" className="absolute right-3 top-4 rounded-lg p-1.5 text-slate-400 hover:bg-white/10"><X className="h-5 w-5" /></button>
            <SidebarContent items={items} badge={badge} logoTo={home} onNavigate={() => setOpen(false)} />
          </div>
        </div>
      )}
      <div className="lg:pl-64">
        <header className="sticky top-0 z-20 flex h-16 items-center justify-between border-b border-slate-200 bg-base/80 px-4 backdrop-blur-lg sm:px-6">
          <button className="rounded-lg p-2 text-slate-600 hover:bg-white/10 lg:hidden" onClick={() => setOpen(true)} aria-label="Open menu"><Menu className="h-5 w-5" /></button>
          <div className="hidden lg:block" />
          <div className="flex items-center gap-1.5">
            <ThemeToggle />
            <NotificationBell allPath={notificationsPath} />
            {user && (
              <Dropdown label="Account menu" trigger={<span className="flex items-center gap-2.5 rounded-xl py-1 pl-1 pr-2 hover:bg-white/10"><span className="flex h-8 w-8 items-center justify-center rounded-full bg-neon text-xs font-bold text-brand-ink">{initials(user.name)}</span><span className="hidden text-sm font-medium text-slate-700 sm:block">{user.name.split(" ")[0]}</span></span>}
                header={<><p className="truncate text-sm font-semibold text-slate-900">{user.name}</p><p className="truncate text-xs text-slate-500">{user.email}</p></>}
                items={[
                  ...(user.role === "student" ? [{ label: "Profile", icon: <User className="h-4 w-4" />, onClick: () => nav("/app/profile") }] : []),
                  { label: "Browse public site", icon: <Globe className="h-4 w-4" />, onClick: () => nav("/") },
                  { label: "Log out", icon: <LogOut className="h-4 w-4" />, danger: true, onClick: () => { logout(); nav("/login"); } },
                ]} />
            )}
          </div>
        </header>
        <main className="mx-auto max-w-7xl animate-fadeUp px-4 py-6 sm:px-6 lg:px-8" key={pathname}><Suspense fallback={<PageLoader />}><Outlet /></Suspense></main>
      </div>
    </div>
  );
}
