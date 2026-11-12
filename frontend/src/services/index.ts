// Every page gets its data through these functions. They call the Supabase database functions in
// supabase/migrations (supabase.rpc) and return the same shapes the old FastAPI endpoints did.
import { FunctionsHttpError } from "@supabase/supabase-js";
import { supabase } from "../lib/supabase";
import { ApiError, raise } from "./api";
import type {
  AdminAssignment, AdminCertificate, AdminDashboard, AdminPayment, AdminStudentProfile, AdminStudentRow, AdminSubmission,
  Assignment, AttemptResult, AuthResponse, Certificate, CourseAdminDetail, CourseCard, CourseDetail, DashboardData,
  ContactMessage, DemoRequest, LearningData, LiveClass, MyCourse, Notification, Page, Progress, QuizAdmin, QuizSummary, User,
} from "../types";

/** Calls a database function; empty filters ("" / null / undefined) are left out so the function's default applies. */
async function rpc<T>(fn: string, args: Record<string, unknown> = {}): Promise<T> {
  const clean = Object.fromEntries(Object.entries(args).filter(([, v]) => v !== undefined && v !== null && v !== ""));
  const { data, error } = await supabase.rpc(fn, clean);
  if (error) raise(error);
  return data as T;
}

/** Calls the payments Edge Function, which answers errors as { error: { code, message } }. */
async function invokePayments<T>(body: Record<string, unknown>): Promise<T> {
  const { data, error } = await supabase.functions.invoke("payments", { body });
  if (error) {
    if (error instanceof FunctionsHttpError) {
      const b = await error.context.json().catch(() => null) as { error?: { code?: string; message?: string } } | null;
      if (b?.error?.message) raise(new ApiError(b.error.message, b.error.code));
    }
    raise(error);
  }
  return data as T;
}

const session = async () => (await supabase.auth.getSession()).data.session;

// ---------------------------------------------------------------- uploads
const ALLOWED: Record<"image" | "document" | "video", string[]> = {
  image: ["png", "jpg", "jpeg", "webp", "gif"],
  document: ["pdf", "doc", "docx", "ppt", "pptx", "xls", "xlsx", "txt", "zip", "png", "jpg", "jpeg"],
  video: ["mp4", "webm", "mov"],
};
const MAX_MB: Record<string, number> = { thumbnails: 5, "course-files": 50, submissions: 25 };

/** Uploads to Supabase Storage under a random name and returns the public URL. */
async function uploadFile(bucket: string, folder: string, kind: keyof typeof ALLOWED, file: File): Promise<string> {
  const ext = (file.name.split(".").pop() ?? "").toLowerCase();
  if (!ALLOWED[kind].includes(ext)) throw new ApiError(`Invalid file type '.${ext || "unknown"}'. Allowed: ${ALLOWED[kind].map((x) => "." + x).join(", ")}`, "invalid_file_type");
  if (file.size === 0) throw new ApiError("The uploaded file is empty", "empty_file");
  if (file.size > MAX_MB[bucket] * 1024 * 1024) throw new ApiError(`File too large. Maximum size is ${MAX_MB[bucket]} MB`, "file_too_large");
  const path = `${folder}/${crypto.randomUUID().replace(/-/g, "")}.${ext}`;
  const { error } = await supabase.storage.from(bucket).upload(path, file, { contentType: file.type || "application/octet-stream", upsert: false });
  if (error) {
    if (/maximum allowed size|payload too large/i.test(error.message)) throw new ApiError(`File too large. Maximum size is ${MAX_MB[bucket]} MB`, "file_too_large");
    raise(error);
  }
  return supabase.storage.from(bucket).getPublicUrl(path).data.publicUrl;
}

// ---------------------------------------------------------------- auth
async function signedInResponse(): Promise<AuthResponse> {
  let user: User;
  try {
    user = await rpc<User>("get_me");
  } catch (e) {
    await supabase.auth.signOut();
    throw e;
  }
  return { access_token: (await session())?.access_token ?? "", token_type: "bearer", user };
}

export const authApi = {
  register: async (b: { name: string; email: string; password: string }) => {
    const { data, error } = await supabase.auth.signUp({ email: b.email.trim(), password: b.password, options: { data: { name: b.name.trim() } } });
    if (error) {
      if (/already registered|already exists/i.test(error.message)) throw new ApiError("An account with this email already exists", "email_taken");
      raise(error);
    }
    // With "Confirm email" switched on in Supabase, there is no session until the student clicks the link.
    if (!data.session) throw new ApiError("Account created. Check your email for a confirmation link, then log in.", "confirm_email");
    return signedInResponse();
  },
  login: async (b: { email: string; password: string }) => {
    const { error } = await supabase.auth.signInWithPassword({ email: b.email.trim(), password: b.password });
    if (error) {
      if (/invalid login credentials/i.test(error.message)) throw new ApiError("Invalid email or password", "invalid_credentials");
      if (/email not confirmed/i.test(error.message)) throw new ApiError("Please confirm your email first. Check your inbox for the link.", "email_not_confirmed");
      raise(error);
    }
    return signedInResponse();
  },
  me: () => rpc<User>("get_me"),
  updateMe: async (b: { name?: string; current_password?: string; new_password?: string }) => {
    if (b.new_password) {
      const email = (await session())?.user.email;
      // Supabase does not ask for the old password, so check it first by signing in with it.
      const check = email ? await supabase.auth.signInWithPassword({ email, password: b.current_password ?? "" }) : null;
      if (!check || check.error) throw new ApiError("Current password is incorrect", "wrong_password");
      const { error } = await supabase.auth.updateUser({ password: b.new_password });
      if (error) raise(error);
    }
    if (b.name) return rpc<User>("update_my_profile", { p_name: b.name });
    return rpc<User>("get_me");
  },
  forgot: async (email: string) => {
    const { error } = await supabase.auth.resetPasswordForEmail(email.trim(), { redirectTo: `${window.location.origin}/reset-password` });
    if (error) raise(error);
    return { message: "If an account exists for that email, a reset link has been sent." };
  },
  reset: async (token: string, new_password: string) => {
    const { error } = await supabase.auth.verifyOtp({ token_hash: token, type: "recovery" });
    if (error) throw new ApiError("This reset link is invalid or has expired", "invalid_reset_token");
    const upd = await supabase.auth.updateUser({ password: new_password });
    if (upd.error) raise(upd.error);
    await supabase.auth.signOut();
    return { message: "Password updated. You can now sign in." };
  },
};

// ---------------------------------------------------------------- catalog
export interface CourseQuery { search?: string; category?: string; difficulty?: string; sort?: string; free_only?: boolean; page?: number; page_size?: number }
/** Remembers a public result for a minute, so parts of a page asking for the same thing share one request. Failures aren't kept. */
function sharedForAMinute<T>(load: () => Promise<T>): () => Promise<T> {
  let saved: { at: number; result: Promise<T> } | null = null;
  return () => {
    if (saved && Date.now() - saved.at < 60_000) return saved.result;
    const entry = { at: Date.now(), result: load() };
    saved = entry;
    entry.result.catch(() => { if (saved === entry) saved = null; });
    return entry.result;
  };
}

const listCourses = (q: CourseQuery) => rpc<Page<CourseCard>>("list_courses", {
  p_search: q.search, p_category: q.category, p_difficulty: q.difficulty, p_sort: q.sort, p_free_only: q.free_only, p_page: q.page, p_page_size: q.page_size,
});

export const courseApi = {
  /** Every published course, newest first, shared by the home page and Krish. */
  catalog: sharedForAMinute(() => listCourses({ sort: "newest", page_size: 60 })),
  list: listCourses,
  categories: sharedForAMinute(() => rpc<{ name: string; count: number }[]>("course_categories")),
  get: (id: string) => rpc<CourseDetail>("get_course", { p_course_id: id }),
  enroll: (id: string) => rpc<{ message: string }>("enroll_free_course", { p_course_id: id }),
  learning: (id: string) => rpc<LearningData>("course_lessons", { p_course_id: id }),
};

// ---------------------------------------------------------------- student
export const studentApi = {
  dashboard: () => rpc<DashboardData>("student_dashboard"),
  courses: () => rpc<MyCourse[]>("my_courses"),
  complete: (lessonId: string) => rpc<Progress>("complete_lesson", { p_lesson_id: lessonId }),
  uncomplete: (lessonId: string) => rpc<Progress>("uncomplete_lesson", { p_lesson_id: lessonId }),
  courseContent: (courseId: string) =>
    rpc<{ assignments: Assignment[]; live_classes: LiveClass[]; quizzes: { id: string; title: string; time_limit_minutes: number }[] }>(
      "student_course_content", { p_course_id: courseId }),
  assignments: () => rpc<Assignment[]>("my_assignments"),
  assignment: (id: string) => rpc<Assignment>("my_assignment", { p_assignment_id: id }),
  submit: async (id: string, form: FormData) => {
    const file = form.get("file");
    let fileUrl: string | undefined;
    if (file instanceof File && file.name) {
      const uid = (await session())?.user.id;
      if (!uid) raise(new ApiError("Authentication required", "unauthorized"));
      fileUrl = await uploadFile("submissions", uid, "document", file);
    }
    return rpc<Assignment>("submit_assignment", { p_assignment_id: id, p_text_answer: String(form.get("text_answer") ?? ""), p_file_url: fileUrl });
  },
  certificates: () => rpc<Certificate[]>("my_certificates"),
  generateCertificate: (courseId: string) => rpc<Certificate>("generate_certificate", { p_course_id: courseId }),
  downloadCertificate: async (id: string, code: string) => {
    const details = await rpc<import("./certificatePdf").CertificateDetails>("certificate_details", { p_certificate_id: id });
    const { renderCertificatePdf } = await import("./certificatePdf");  // loaded only when someone downloads
    const url = URL.createObjectURL(new Blob([new Uint8Array(await renderCertificatePdf(details))], { type: "application/pdf" }));
    const a = document.createElement("a");
    a.href = url; a.download = `${code}.pdf`; a.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  },
};

export const quizApi = {
  list: () => rpc<QuizSummary[]>("my_quizzes"),
  get: (id: string) => rpc<QuizSummary>("get_quiz", { p_quiz_id: id }),
  start: (id: string) => rpc<{ attempt_id: string; started_at: string; time_limit_minutes: number }>("start_quiz", { p_quiz_id: id }),
  submit: (id: string, body: { attempt_id: string; answers: { question_id: string; option_id: string | null }[] }) =>
    rpc<AttemptResult>("submit_quiz", { p_quiz_id: id, p_answers: body.answers, p_attempt_id: body.attempt_id }),
};

export const liveApi = {
  list: (params?: { include_past?: boolean; course_id?: string }) =>
    rpc<LiveClass[]>("list_live_classes", { p_include_past: params?.include_past, p_course_id: params?.course_id }),
};

export const notificationApi = {
  list: () => rpc<{ items: Notification[]; unread_count: number }>("list_notifications"),
  readAll: () => rpc<{ message: string }>("read_all_notifications"),
  read: (id: string) => rpc<{ message: string }>("read_notification", { p_notification_id: id }),
};

export const paymentApi = {
  config: () => invokePayments<{ configured: boolean; key_id: string; mode: string }>({ action: "config" }),
  createOrder: (course_id: string, learning_mode: "online" | "offline") =>
    invokePayments<{ order_id: string; amount: number; currency: string; key_id: string; course_title: string }>({ action: "create-order", course_id, learning_mode }),
  verify: (b: { razorpay_order_id: string; razorpay_payment_id: string; razorpay_signature: string }) =>
    invokePayments<{ status: string; course_id: string }>({ action: "verify", ...b }),
  failed: (orderId: string) => rpc<{ status: string }>("mark_payment_failed", { p_order_id: orderId }),
};

// ---------------------------------------------------------------- leads
export interface DemoRequestInput { name: string; email: string; phone: string; course_interest?: string; preferred_time?: string; message?: string }
export const demoApi = {
  book: (b: DemoRequestInput) => rpc<{ message: string }>("book_demo", {
    p_name: b.name, p_email: b.email, p_phone: b.phone, p_course_interest: b.course_interest, p_preferred_time: b.preferred_time, p_message: b.message,
  }),
};

export interface ContactInput { name: string; email: string; phone?: string; subject: string; message: string }
export const contactApi = {
  chat: (b: { name: string; contact: string; interest?: string; message?: string }) => rpc<{ message: string }>("send_chat_enquiry", {
    p_name: b.name, p_contact: b.contact, p_interest: b.interest, p_message: b.message,
  }),
  send: (b: ContactInput) => rpc<{ message: string }>("send_contact_message", {
    p_name: b.name, p_email: b.email, p_phone: b.phone, p_subject: b.subject, p_message: b.message,
  }),
};

// ---------------------------------------------------------------- admin
const UPLOAD_KINDS = {
  thumbnail: ["thumbnails", "thumbnails", "image"],
  resource: ["course-files", "resources", "document"],
  attachment: ["course-files", "attachments", "document"],
  video: ["course-files", "videos", "video"],
} as const;

export const adminApi = {
  contactMessages: () => rpc<ContactMessage[]>("admin_contact_messages"),
  toggleContactRead: (id: string) => rpc<ContactMessage>("admin_toggle_contact_read", { p_id: id }),
  demoRequests: () => rpc<DemoRequest[]>("admin_demo_requests"),
  toggleDemoContacted: (id: string) => rpc<DemoRequest>("admin_toggle_demo_contacted", { p_id: id }),
  dashboard: () => rpc<AdminDashboard>("admin_dashboard"),
  upload: async (kind: "thumbnail" | "resource" | "attachment" | "video", file: File) => {
    const [bucket, folder, type] = UPLOAD_KINDS[kind];
    return { url: await uploadFile(bucket, folder, type, file), filename: file.name };
  },
  courses: (search?: string) => rpc<CourseCard[]>("admin_courses", { p_search: search }),
  course: (id: string) => rpc<CourseAdminDetail>("admin_course", { p_course_id: id }),
  createCourse: (b: Record<string, unknown>) => rpc<CourseAdminDetail>("admin_create_course", { p_data: b }),
  updateCourse: (id: string, b: Record<string, unknown>) => rpc<CourseAdminDetail>("admin_update_course", { p_course_id: id, p_data: b }),
  deleteCourse: (id: string) => rpc<{ message: string }>("admin_delete_course", { p_course_id: id }),
  createModule: (courseId: string, title: string) => rpc("admin_create_module", { p_course_id: courseId, p_title: title }),
  updateModule: (id: string, title: string) => rpc("admin_update_module", { p_module_id: id, p_title: title }),
  deleteModule: (id: string) => rpc("admin_delete_module", { p_module_id: id }),
  reorderModules: (courseId: string, ids: string[]) => rpc("admin_reorder_modules", { p_course_id: courseId, p_ids: ids }),
  createLesson: (moduleId: string, b: Record<string, unknown>) => rpc("admin_create_lesson", { p_module_id: moduleId, p_data: b }),
  updateLesson: (id: string, b: Record<string, unknown>) => rpc("admin_update_lesson", { p_lesson_id: id, p_data: b }),
  deleteLesson: (id: string) => rpc("admin_delete_lesson", { p_lesson_id: id }),
  reorderLessons: (moduleId: string, ids: string[]) => rpc("admin_reorder_lessons", { p_module_id: moduleId, p_ids: ids }),
  addResource: (lessonId: string, b: { title: string; file_url: string }) =>
    rpc("admin_add_resource", { p_lesson_id: lessonId, p_title: b.title, p_file_url: b.file_url }),
  deleteResource: (id: string) => rpc("admin_delete_resource", { p_resource_id: id }),

  liveClasses: () => rpc<LiveClass[]>("admin_live_classes"),
  createLive: (b: Record<string, unknown>) => rpc<LiveClass>("admin_create_live", { p_data: b }),
  updateLive: (id: string, b: Record<string, unknown>) => rpc<LiveClass>("admin_update_live", { p_live_id: id, p_data: b }),
  deleteLive: (id: string) => rpc("admin_delete_live", { p_live_id: id }),

  assignments: () => rpc<AdminAssignment[]>("admin_assignments"),
  createAssignment: (b: Record<string, unknown>) => rpc<AdminAssignment>("admin_create_assignment", { p_data: b }),
  updateAssignment: (id: string, b: Record<string, unknown>) => rpc<AdminAssignment>("admin_update_assignment", { p_assignment_id: id, p_data: b }),
  deleteAssignment: (id: string) => rpc("admin_delete_assignment", { p_assignment_id: id }),
  submissions: (p: Record<string, unknown>) => rpc<Page<AdminSubmission>>("admin_submissions", {
    p_assignment_id: p.assignment_id, p_course_id: p.course_id, p_status: p.status, p_search: p.search, p_page: p.page, p_page_size: p.page_size,
  }),
  grade: (id: string, b: { marks: number; feedback: string }) =>
    rpc<AdminSubmission>("admin_grade_submission", { p_submission_id: id, p_marks: b.marks, p_feedback: b.feedback }),
  markReviewed: (id: string) => rpc<AdminSubmission>("admin_mark_reviewed", { p_submission_id: id }),

  quizzes: () => rpc<QuizAdmin[]>("admin_quizzes"),
  quiz: (id: string) => rpc<QuizAdmin>("admin_quiz", { p_quiz_id: id }),
  createQuiz: (b: Record<string, unknown>) => rpc<QuizAdmin>("admin_create_quiz", { p_data: b }),
  updateQuiz: (id: string, b: Record<string, unknown>) => rpc<QuizAdmin>("admin_update_quiz", { p_quiz_id: id, p_data: b }),
  deleteQuiz: (id: string) => rpc("admin_delete_quiz", { p_quiz_id: id }),
  quizAttempts: (id: string) =>
    rpc<{ id: string; student_name: string; student_email: string; score: number; total_marks: number; submitted_at: string }[]>(
      "admin_quiz_attempts", { p_quiz_id: id }),

  students: (p: Record<string, unknown>) => rpc<Page<AdminStudentRow>>("admin_students", {
    p_search: p.search, p_status: p.status, p_page: p.page, p_page_size: p.page_size,
  }),
  student: (id: string) => rpc<AdminStudentProfile>("admin_student", { p_student_id: id }),
  setStudentStatus: (id: string, is_active: boolean) => rpc("admin_set_student_status", { p_student_id: id, p_is_active: is_active }),
  payments: (p: Record<string, unknown>) => rpc<Page<AdminPayment> & { summary: { revenue: number; paid_count: number; online_count?: number; offline_count?: number } }>("admin_payments", {
    p_status: p.status, p_search: p.search, p_page: p.page, p_page_size: p.page_size, p_mode: p.mode,
  }),
  certificates: () => rpc<AdminCertificate[]>("admin_certificates"),
  broadcast: (b: { title: string; message: string; course_id?: string | null }) =>
    rpc<{ message: string }>("admin_broadcast", { p_title: b.title, p_message: b.message, p_course_id: b.course_id }),
  settings: async () => {
    const [s, pay] = await Promise.all([
      rpc<{ platform_name: string; storage_backend: string; max_upload_mb: number }>("admin_settings"),
      paymentApi.config().catch(() => ({ configured: false, key_id: "", mode: "not configured" })),
    ]);
    return { ...s, razorpay_configured: pay.configured, razorpay_mode: pay.mode };
  },
};
