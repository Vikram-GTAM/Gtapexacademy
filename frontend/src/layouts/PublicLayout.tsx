import { CalendarCheck, ChevronDown, LogOut, LayoutDashboard, Menu, X } from "lucide-react";
import { Suspense, useState } from "react";
import { Link, NavLink, Outlet, useLocation, useNavigate } from "react-router-dom";
import { Logo } from "../components/Brand";
import { homeFor } from "../components/ProtectedRoute";
import { Dropdown, LinkButton, PageLoader } from "../components/ui";
import { NavDropdown } from "../components/NavDropdown";
import { NotificationBell } from "../components/NotificationBell";
import { ThemeToggle } from "../components/ThemeToggle";
import { useAuth } from "../context/AuthContext";
import { useAsync } from "../hooks/useAsync";
import { courseApi } from "../services";
import { cx, initials } from "../utils/format";

const links = [{ to: "/about", label: "About" }, { to: "/placements", label: "Placements" }, { to: "/contact", label: "Contact" }];

export function PublicNavbar() {
  const { user, logout } = useAuth();
  const [open, setOpen] = useState(false);
  const nav = useNavigate();
  const [coursesOpen, setCoursesOpen] = useState(false);
  const { pathname } = useLocation();
  const cats = useAsync(() => courseApi.categories());
  const catItems = (cats.data ?? []).map((c) => ({ to: `/courses?category=${encodeURIComponent(c.name)}`, label: c.name, hint: String(c.count) }));
  const linkCls = ({ isActive }: { isActive: boolean }) => cx("rounded-lg px-3 py-2 text-sm font-medium transition", isActive ? "text-brand-600" : "text-slate-600 hover:text-slate-900");
  return (
    <header className="sticky top-0 z-40 border-b border-slate-200/70 bg-base/80 backdrop-blur-lg">
      <div className="mx-auto flex h-16 max-w-7xl items-center justify-between px-4 sm:px-6 lg:px-8">
        <div className="flex items-center gap-8">
          <Logo />
          <nav className="hidden items-center gap-1 md:flex" aria-label="Main"><NavDropdown label="Courses" to="/courses" items={catItems} active={pathname.startsWith("/courses")} />{links.map((l) => <NavLink key={l.to} to={l.to} className={linkCls}>{l.label}</NavLink>)}</nav>
        </div>
        <div className="flex items-center gap-2">
          <ThemeToggle />
          <LinkButton to="/book-demo" variant={user ? "outline" : "primary"} className="hidden sm:inline-flex"><CalendarCheck className="h-4 w-4" />Book Free Demo</LinkButton>
          {user ? (
            <>
              {user.role === "student" && <NotificationBell allPath="/app/notifications" />}
              <Dropdown label="Account menu" trigger={<span className="flex h-9 w-9 items-center justify-center rounded-full bg-neon text-sm font-bold text-brand-ink">{initials(user.name)}</span>}
                header={<><p className="truncate text-sm font-semibold text-slate-900">{user.name}</p><p className="truncate text-xs text-slate-500">{user.email}</p></>}
                items={[
                  { label: user.role === "admin" ? "Admin dashboard" : "My dashboard", icon: <LayoutDashboard className="h-4 w-4" />, onClick: () => nav(homeFor(user.role)) },
                  { label: "Log out", icon: <LogOut className="h-4 w-4" />, danger: true, onClick: () => { logout(); nav("/"); } },
                ]} />
            </>
          ) : (
            <div className="hidden items-center gap-2 sm:flex">
              <LinkButton to="/login" variant="outline">Log in</LinkButton>
            </div>
          )}
          <button className="rounded-lg p-2 text-slate-600 hover:bg-white/10 md:hidden" onClick={() => setOpen((o) => !o)} aria-label="Toggle menu" aria-expanded={open}>{open ? <X className="h-5 w-5" /> : <Menu className="h-5 w-5" />}</button>
        </div>
      </div>
      {open && (
        <div className="animate-fadeUp border-t border-slate-100 bg-panel px-4 py-3 md:hidden">
          <button type="button" onClick={() => setCoursesOpen((o) => !o)} aria-expanded={coursesOpen} className="flex w-full items-center justify-between rounded-lg px-3 py-2.5 text-sm font-medium text-slate-700">Courses<ChevronDown className={cx("h-4 w-4 transition-transform", coursesOpen && "rotate-180")} /></button>
          {coursesOpen && <div className="mb-1 ml-3 border-l border-slate-200 pl-2">
            <Link to="/courses" onClick={() => setOpen(false)} className="block rounded-lg px-3 py-2 text-sm font-semibold text-brand-600">All courses</Link>
            {catItems.map((c) => <Link key={c.to} to={c.to} onClick={() => setOpen(false)} className="block rounded-lg px-3 py-2 text-sm text-slate-600">{c.label}</Link>)}
          </div>}
          {links.map((l) => <NavLink key={l.to} to={l.to} onClick={() => setOpen(false)} className={({ isActive }) => cx("block rounded-lg px-3 py-2.5 text-sm font-medium", isActive ? "bg-brand-100 text-brand-600" : "text-slate-700")}>{l.label}</NavLink>)}
          <div className="mt-3 grid gap-2"><LinkButton to="/book-demo" onClick={() => setOpen(false)}><CalendarCheck className="h-4 w-4" />Book Free Demo</LinkButton>{!user && <LinkButton to="/login" variant="outline" onClick={() => setOpen(false)}>Log in</LinkButton>}</div>
        </div>
      )}
    </header>
  );
}

export function Footer() {
  return (
    <footer className="mt-20 border-t border-slate-200 bg-panel text-slate-500">
      <div className="mx-auto grid max-w-7xl gap-10 px-4 py-14 sm:px-6 md:grid-cols-4 lg:px-8">
        <div className="md:col-span-2">
          <Logo />
          <p className="mt-4 max-w-sm text-sm leading-relaxed text-slate-400">Master SEO, paid ads, social media, content and AI-powered analytics through recorded lessons, live classes, assignments and quizzes — and earn certificates you can share.</p>
        </div>
        <div><h2 className="mb-3 text-sm font-semibold text-white">Platform</h2><ul className="space-y-2 text-sm"><li><Link className="hover:text-white" to="/courses">All courses</Link></li><li><Link className="hover:text-white" to="/about">About</Link></li><li><Link className="hover:text-white" to="/placements">Placements</Link></li><li><Link className="hover:text-white" to="/book-demo">Book a free demo</Link></li><li><Link className="hover:text-white" to="/contact">Contact us</Link></li><li><Link className="hover:text-white" to="/refund-policy">Refund terms</Link></li><li><Link className="hover:text-white" to="/register">Create account</Link></li><li><Link className="hover:text-white" to="/login">Log in</Link></li></ul></div>
        <div><h2 className="mb-3 text-sm font-semibold text-white">Learn</h2><ul className="space-y-2 text-sm"><li>Recorded classes</li><li>Live campaign clinics</li><li>Assignments & quizzes</li><li>Certificates</li></ul></div>
      </div>
      <div className="border-t border-slate-200 py-5 text-center text-xs text-slate-500">© {new Date().getFullYear()} GTapex Academy. All rights reserved.</div>
    </footer>
  );
}

export function PublicLayout() {
  const { pathname } = useLocation();
  return (
    <div className="flex min-h-screen flex-col">
      <PublicNavbar />
      <main className="flex-1" key={pathname}><Suspense fallback={<PageLoader />}><Outlet /></Suspense></main>
      <Footer />
    </div>
  );
}
