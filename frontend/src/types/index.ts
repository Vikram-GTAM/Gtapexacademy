export type Role = "student" | "admin";
export type Difficulty = "beginner" | "intermediate" | "advanced";

export interface User { id: string; name: string; email: string; role: Role; is_active: boolean; avatar_url?: string | null }
export interface AuthResponse { access_token: string; token_type: string; user: User }

export interface Page<T> { items: T[]; total: number; page: number; page_size: number; pages: number }

export interface CourseCard {
  id: string; title: string; slug: string; short_description: string; category: string; difficulty: Difficulty;
  price: number; offline_price: number | null; duration_months: number | null; offline_only: boolean; thumbnail_url: string | null; is_published: boolean; lesson_count: number; duration_seconds: number; enrolled_count: number;
}
export interface Resource { id: string; title: string; file_url: string }
export interface Lesson {
  id: string; module_id?: string; title: string; description?: string; video_url?: string | null;
  duration_seconds: number; position: number; is_free_preview: boolean; resources?: Resource[];
}
export interface Module { id: string; course_id?: string; title: string; position: number; lessons: Lesson[] }
export interface CourseDetail extends CourseCard { description: string; features: string[]; modules: Module[]; is_enrolled: boolean }
export interface CourseAdminDetail extends CourseCard { description: string; features: string[]; modules: Module[] }

export interface Progress { total_lessons: number; completed_lessons: number; percentage: number; completed_ids?: string[] }
export interface MyCourse {
  course: CourseCard; progress: Progress; enrolled_at: string; completed_at: string | null; is_completed: boolean;
}
export interface LearningData { course: { id: string; title: string }; modules: Module[]; progress: Progress }

export type LiveStatus = "upcoming" | "live" | "completed";
export interface LiveClass {
  id: string; course_id: string; course_title: string; title: string; description: string; starts_at: string; ends_at: string;
  platform: string; status: LiveStatus; meeting_url: string | null; duration_minutes: number;
}

export interface Submission {
  id: string; assignment_id: string; text_answer: string | null; file_url: string | null; submitted_at: string; is_late: boolean;
  status: "submitted" | "reviewed"; marks: number | null; feedback: string | null; reviewed_at: string | null;
}
export interface Assignment {
  id: string; course_id: string; course_title: string; module_id: string | null; title: string; instructions: string;
  deadline: string; max_marks: number; allow_late: boolean; attachment_url: string | null; is_past_deadline: boolean;
  submission: Submission | null;
}
export interface AdminAssignment {
  id: string; course_id: string; course_title: string; module_id: string | null; title: string; instructions: string;
  deadline: string; max_marks: number; allow_late: boolean; attachment_url: string | null; submission_count: number; pending_count: number;
}
export interface AdminSubmission extends Submission {
  student_id: string; student_name: string; student_email: string; assignment_title: string; course_title: string; max_marks: number;
}

export interface QuizOptionS { id: string; text: string }
export interface QuizQuestionS { id: string; text: string; marks: number; options: QuizOptionS[] }
export interface QuizSummary {
  id: string; course_id: string; course_title: string; title: string; description: string; time_limit_minutes: number;
  show_results: boolean; question_count: number; total_marks: number;
  last_attempt: { id: string; score: number; total_marks: number; submitted_at: string | null } | null;
  questions: QuizQuestionS[] | null;
}
export interface AttemptResult {
  attempt_id: string; score: number; total_marks: number; percentage: number; show_results: boolean;
  results: { question_id: string; selected_option_id: string | null; correct_option_id: string | null; is_correct: boolean }[] | null;
}
export interface QuizAdmin {
  id: string; course_id: string; course_title: string; module_id: string | null; title: string; description: string;
  time_limit_minutes: number; show_results: boolean; is_published: boolean; attempt_count: number;
  questions: { id: string; text: string; marks: number; options: { id: string; text: string; is_correct: boolean }[] }[];
}

export interface Notification { id: string; type: string; title: string; message: string; is_read: boolean; created_at: string }
export interface Certificate { id: string; course_id: string; course_title: string; certificate_code: string; issued_at: string }

export interface DashboardData {
  stats: { enrolled: number; in_progress: number; completed: number; pending_assignments: number };
  courses: MyCourse[]; pending_assignments: Assignment[]; upcoming_live_classes: LiveClass[];
  recent_activity: { type: string; title: string; at: string }[];
}
export interface AdminDashboard {
  stats: {
    total_students: number; total_courses: number; total_enrollments: number; total_revenue: number;
    active_students: number; pending_assignments: number; upcoming_live_classes: number;
  };
  enrollments_series: { date: string; count: number }[];
  revenue_series: { month: string; amount: number }[];
  top_courses: { title: string; enrollments: number }[];
}
export interface AdminStudentRow { id: string; name: string; email: string; is_active: boolean; joined_at: string; enrolled_count: number }
export interface AdminStudentProfile {
  id: string; name: string; email: string; is_active: boolean; joined_at: string;
  courses: { course_id: string; title: string; enrolled_at: string; completed_at: string | null; percentage: number; completed_lessons: number; total_lessons: number; learning_mode?: "online" | "offline" | null }[];
  assignments: { id: string; title: string; status: string; marks: number | null; max_marks: number; submitted_at: string; is_late: boolean }[];
  quizzes: { id: string; title: string; score: number; total_marks: number; submitted_at: string }[];
}
export interface AdminPayment {
  id: string; student_name: string; student_email: string; course_title: string; learning_mode?: "online" | "offline"; amount: number; currency: string;
  status: "created" | "paid" | "failed"; razorpay_order_id: string | null; razorpay_payment_id: string | null; created_at: string;
}
export interface AdminCertificate { id: string; certificate_code: string; student_name: string; student_email: string; course_title: string; issued_at: string }

export interface DemoRequest {
  id: string; name: string; email: string; phone: string; course_interest: string | null;
  preferred_time: string | null; message: string | null; is_contacted: boolean; created_at: string;
}

export interface ContactMessage {
  id: string; name: string; email: string | null; phone: string | null; subject: string; message: string; is_read: boolean; created_at: string;
}
