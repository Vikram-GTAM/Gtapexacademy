import { lazy, Suspense } from "react";
import { BrowserRouter, Route, Routes, useLocation } from "react-router-dom";
import { ErrorBoundary } from "./components/ErrorBoundary";
import { RouteMeta } from "./components/RouteMeta";
import { ScrollToTop } from "./components/ScrollToTop";
import { GuestRoute, ProtectedRoute } from "./components/ProtectedRoute";
import { PageLoader } from "./components/ui";
import { AuthProvider } from "./context/AuthContext";
import { ToastProvider } from "./context/ToastContext";
import { AdminLayout } from "./layouts/AdminLayout";
import { PublicLayout } from "./layouts/PublicLayout";
import { StudentLayout } from "./layouts/StudentLayout";
import Home from "./pages/public/Home";

const l = <T extends { default: React.ComponentType }>(f: () => Promise<T>) => lazy(f);
// Public. Home loads with the first page; the rest load when visited.
const Krish = lazy(() => import("./components/Krish").then((m) => ({ default: m.Krish })));
const CourseDetail = l(() => import("./pages/public/CourseDetail"));
const About = l(() => import("./pages/public/About"));
const BookDemo = l(() => import("./pages/public/BookDemo"));
const Contact = l(() => import("./pages/public/Contact"));
const Courses = l(() => import("./pages/public/Courses"));
const NotFound = l(() => import("./pages/public/NotFound"));
const Placements = l(() => import("./pages/public/Placements"));
const RefundPolicy = l(() => import("./pages/public/RefundPolicy"));
const Login = lazy(() => import("./pages/public/AuthPages").then((m) => ({ default: m.Login })));
const Register = lazy(() => import("./pages/public/AuthPages").then((m) => ({ default: m.Register })));
const ForgotPassword = lazy(() => import("./pages/public/AuthPages").then((m) => ({ default: m.ForgotPassword })));
const ResetPassword = lazy(() => import("./pages/public/AuthPages").then((m) => ({ default: m.ResetPassword })));
// Student
const Dashboard = l(() => import("./pages/student/Dashboard"));
const MyCourses = l(() => import("./pages/student/MyCourses"));
const Learn = l(() => import("./pages/student/Learn"));
const Assignments = l(() => import("./pages/student/Assignments"));
const AssignmentDetail = l(() => import("./pages/student/AssignmentDetail"));
const Quizzes = l(() => import("./pages/student/Quizzes"));
const QuizTake = l(() => import("./pages/student/QuizTake"));
const LiveClasses = l(() => import("./pages/student/LiveClasses"));
const Certificates = l(() => import("./pages/student/Certificates"));
const Notifications = l(() => import("./pages/student/Notifications"));
const Profile = l(() => import("./pages/student/Profile"));
// Admin
const AdminDashboard = l(() => import("./pages/admin/Dashboard"));
const AdminCourses = l(() => import("./pages/admin/Courses"));
const AdminContent = l(() => import("./pages/admin/Content"));
const AdminLive = l(() => import("./pages/admin/Live"));
const AdminAssignments = l(() => import("./pages/admin/Assignments"));
const AdminSubmissions = l(() => import("./pages/admin/Submissions"));
const AdminQuizzes = l(() => import("./pages/admin/Quizzes"));
const AdminStudents = l(() => import("./pages/admin/Students"));
const AdminStudentDetail = l(() => import("./pages/admin/StudentDetail"));
const AdminContactMessages = l(() => import("./pages/admin/ContactMessages"));
const AdminDemoRequests = l(() => import("./pages/admin/DemoRequests"));
const AdminPayments = l(() => import("./pages/admin/Payments"));
const AdminCertificates = l(() => import("./pages/admin/Certificates"));
const AdminNotifications = l(() => import("./pages/admin/Notifications"));
const AdminSettings = l(() => import("./pages/admin/Settings"));

function SafeRoutes({ children }: { children: React.ReactNode }) {
  const { pathname } = useLocation();
  return <ErrorBoundary resetKey={pathname}>{children}</ErrorBoundary>;
}

export default function App() {
  return (
    <BrowserRouter>
      <ToastProvider>
        <AuthProvider>
          <RouteMeta />
          <ScrollToTop />
          <SafeRoutes>
          <Suspense fallback={<PageLoader />}>
            <Routes>
              <Route element={<PublicLayout />}>
                <Route index element={<Home />} />
                <Route path="courses" element={<Courses />} />
                <Route path="about" element={<About />} />
                <Route path="placements" element={<Placements />} />
                <Route path="book-demo" element={<BookDemo />} />
                <Route path="contact" element={<Contact />} />
                <Route path="refund-policy" element={<RefundPolicy />} />
                <Route path="courses/:id" element={<CourseDetail />} />
                <Route element={<GuestRoute />}>
                  <Route path="login" element={<Login />} />
                  <Route path="register" element={<Register />} />
                  <Route path="forgot-password" element={<ForgotPassword />} />
                </Route>
                <Route path="reset-password" element={<ResetPassword />} />
              </Route>

              <Route element={<ProtectedRoute role="student" />}>
                <Route path="app/learn/:courseId" element={<Learn />} />
                <Route path="app" element={<StudentLayout />}>
                  <Route index element={<Dashboard />} />
                  <Route path="courses" element={<MyCourses />} />
                  <Route path="assignments" element={<Assignments />} />
                  <Route path="assignments/:id" element={<AssignmentDetail />} />
                  <Route path="quizzes" element={<Quizzes />} />
                  <Route path="quizzes/:id" element={<QuizTake />} />
                  <Route path="live" element={<LiveClasses />} />
                  <Route path="certificates" element={<Certificates />} />
                  <Route path="notifications" element={<Notifications />} />
                  <Route path="profile" element={<Profile />} />
                  <Route path="*" element={<NotFound />} />
                </Route>
              </Route>

              <Route element={<ProtectedRoute role="admin" />}>
                <Route path="admin" element={<AdminLayout />}>
                  <Route index element={<AdminDashboard />} />
                  <Route path="courses" element={<AdminCourses />} />
                  <Route path="content" element={<AdminContent />} />
                  <Route path="live" element={<AdminLive />} />
                  <Route path="assignments" element={<AdminAssignments />} />
                  <Route path="submissions" element={<AdminSubmissions />} />
                  <Route path="quizzes" element={<AdminQuizzes />} />
                  <Route path="students" element={<AdminStudents />} />
                  <Route path="students/:id" element={<AdminStudentDetail />} />
                  <Route path="demo-requests" element={<AdminDemoRequests />} />
                  <Route path="contact-messages" element={<AdminContactMessages />} />
                  <Route path="payments" element={<AdminPayments />} />
                  <Route path="certificates" element={<AdminCertificates />} />
                  <Route path="notifications" element={<AdminNotifications />} />
                  <Route path="settings" element={<AdminSettings />} />
                  <Route path="*" element={<NotFound />} />
                </Route>
              </Route>

              <Route path="*" element={<NotFound />} />
            </Routes>
          </Suspense>
          </SafeRoutes>
          <ErrorBoundary resetKey="krish"><Suspense fallback={null}><Krish /></Suspense></ErrorBoundary>
        </AuthProvider>
      </ToastProvider>
    </BrowserRouter>
  );
}
