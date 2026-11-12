import { Award, Bell, BookOpen, CalendarCheck, CalendarDays, Inbox, ClipboardCheck, ClipboardList, CreditCard, HelpCircle, Layers, LayoutDashboard, Settings, Users } from "lucide-react";
import { AppShell, type NavItem } from "./AppShell";

const items: NavItem[] = [
  { to: "/admin", label: "Dashboard", icon: <LayoutDashboard />, end: true },
  { to: "/admin/courses", label: "Courses", icon: <BookOpen /> },
  { to: "/admin/content", label: "Modules & Lessons", icon: <Layers /> },
  { to: "/admin/live", label: "Live Classes", icon: <CalendarDays /> },
  { to: "/admin/assignments", label: "Assignments", icon: <ClipboardList /> },
  { to: "/admin/submissions", label: "Submissions", icon: <ClipboardCheck /> },
  { to: "/admin/quizzes", label: "Quizzes", icon: <HelpCircle /> },
  { to: "/admin/students", label: "Students", icon: <Users /> },
  { to: "/admin/demo-requests", label: "Demo requests", icon: <CalendarCheck /> },
  { to: "/admin/contact-messages", label: "Contact messages", icon: <Inbox /> },
  { to: "/admin/payments", label: "Payments", icon: <CreditCard /> },
  { to: "/admin/certificates", label: "Certificates", icon: <Award /> },
  { to: "/admin/notifications", label: "Notifications", icon: <Bell /> },
  { to: "/admin/settings", label: "Settings", icon: <Settings /> },
];
export const AdminLayout = () => <AppShell items={items} badge="Admin" />;
