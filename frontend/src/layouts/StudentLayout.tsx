import { Award, BookOpen, CalendarDays, ClipboardList, HelpCircle, LayoutDashboard, User } from "lucide-react";
import { AppShell, type NavItem } from "./AppShell";

const items: NavItem[] = [
  { to: "/app", label: "Dashboard", icon: <LayoutDashboard />, end: true },
  { to: "/app/courses", label: "My Courses", icon: <BookOpen /> },
  { to: "/app/assignments", label: "Assignments", icon: <ClipboardList /> },
  { to: "/app/quizzes", label: "Quizzes", icon: <HelpCircle /> },
  { to: "/app/live", label: "Live Classes", icon: <CalendarDays /> },
  { to: "/app/certificates", label: "Certificates", icon: <Award /> },
  { to: "/app/profile", label: "Profile", icon: <User /> },
];
export const StudentLayout = () => <AppShell items={items} notificationsPath="/app/notifications" />;
