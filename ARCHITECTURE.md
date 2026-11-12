> **Historical document.** This describes the old FastAPI backend, which is retired. For how the site works today, see `README.md` and `supabase/README.md`.

# LMS Architecture

## Stack
- **Frontend**: React 18 + Vite + TypeScript, React Router, Tailwind CSS, Axios, Lucide icons
- **Backend**: FastAPI, SQLAlchemy 2.0, PostgreSQL, Pydantic v2, JWT (python-jose), bcrypt, Alembic
- **Storage**: `StorageBackend` interface with `LocalStorage` (dev) and `S3Storage` (prod). Selected by `STORAGE_BACKEND` env var. No binaries in PostgreSQL. Videos are referenced by URL (S3/CDN/YouTube/Vimeo etc.) or uploaded through the storage layer.
- **Payments**: Razorpay (test mode). Order creation and signature verification happen server-side only; the frontend gets only the public key id.

## Roles
Exactly two: `student` and `admin`. Admins are created only by `seed.py` (from `ADMIN_EMAIL` / `ADMIN_PASSWORD` env vars). Public registration always creates a `student`.

## Database (UUID primary keys, created_at / updated_at on all tables)
| Table | Key columns |
|---|---|
| users | id, name, email (unique), password_hash, role, is_active, avatar_url |
| courses | id, title, slug (unique), short_description, description, category, difficulty, price, thumbnail_url, is_published, features (JSON) |
| course_modules | id, course_id FK, title, position |
| lessons | id, module_id FK, title, description, video_url, duration_seconds, position, is_free_preview |
| lesson_resources | id, lesson_id FK, title, file_url |
| enrollments | id, user_id FK, course_id FK, unique(user_id, course_id), enrolled_at, completed_at |
| lesson_progress | id, user_id FK, lesson_id FK, unique(user_id, lesson_id), completed_at |
| live_classes | id, course_id FK, title, description, starts_at, ends_at, meeting_url, platform |
| assignments | id, course_id FK, module_id FK null, title, instructions, deadline, max_marks, allow_late, attachment_url |
| assignment_submissions | id, assignment_id FK, user_id FK, unique(assignment_id, user_id), text_answer, file_url, submitted_at, is_late, status, marks, feedback, reviewed_at |
| quizzes | id, course_id FK, module_id FK null, title, description, time_limit_minutes, show_results, is_published |
| quiz_questions | id, quiz_id FK, text, marks, position |
| quiz_options | id, question_id FK, text, is_correct |
| quiz_attempts | id, quiz_id FK, user_id FK, score, total_marks, started_at, submitted_at |
| quiz_answers | id, attempt_id FK, question_id FK, option_id FK null, is_correct |
| payments | id, user_id FK, course_id FK, amount, currency, status, razorpay_order_id, razorpay_payment_id, razorpay_signature |
| notifications | id, user_id FK, type, title, message, is_read |
| certificates | id, user_id FK, course_id FK, unique(user_id, course_id), certificate_code (unique), issued_at |

Indexes on all foreign keys and frequently filtered columns (email, slug, category, starts_at, deadline).

## API map
- `/api/auth/*` register, login, me, forgot/reset password, profile update
- `/api/courses/*` public catalog, details, enroll, lessons (enrolled only)
- `/api/student/*` my courses, progress, lesson complete, assignments, submissions, certificates, notifications
- `/api/assignments/*`, `/api/quizzes/*`, `/api/live-classes/*` student-facing
- `/api/payments/*` order creation, verification
- `/api/admin/*` everything admin (guarded by `require_admin` dependency on the router)

## Authorization rules
- `get_current_user` validates JWT and that the account is active.
- `require_admin` is applied at router level for all `/api/admin/*`.
- Student resources are always filtered by `current_user.id`; lesson/assignment/quiz access requires enrollment.
