-- GTapex Academy on Supabase: tables.
-- Ported 1:1 from the FastAPI/SQLAlchemy models (backend/app/models). Users live in auth.users;
-- their app data (name, role, active flag) lives in public.profiles.

create extension if not exists pgcrypto with schema extensions;

create schema if not exists private;  -- internal helpers; never exposed through the API

create type public.user_role as enum ('student', 'admin');
create type public.difficulty as enum ('beginner', 'intermediate', 'advanced');
create type public.submission_status as enum ('submitted', 'reviewed');
create type public.payment_status as enum ('created', 'paid', 'failed');

create or replace function private.touch_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- ---------------------------------------------------------------- people
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name varchar(120) not null,
  email varchar(255) not null,
  role public.user_role not null default 'student',
  is_active boolean not null default true,
  avatar_url varchar(500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index profiles_role_idx on public.profiles (role);
create index profiles_email_idx on public.profiles (lower(email));

-- Single-row platform settings (was env-driven in the FastAPI backend).
create table public.platform_settings (
  id boolean primary key default true check (id),
  platform_name varchar(120) not null default 'GTapex Academy',
  max_upload_mb integer not null default 50,
  updated_at timestamptz not null default now()
);
insert into public.platform_settings (id) values (true);

-- ---------------------------------------------------------------- courses
create table public.courses (
  id uuid primary key default gen_random_uuid(),
  title varchar(200) not null,
  slug varchar(220) not null unique,
  short_description varchar(300) not null default '',
  description text not null default '',
  category varchar(80) not null default 'General',
  difficulty public.difficulty not null default 'beginner',
  price numeric(10, 2) not null default 0 check (price >= 0),
  thumbnail_url varchar(500),
  is_published boolean not null default false,
  features jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index courses_category_idx on public.courses (category);
create index courses_published_idx on public.courses (is_published);

create table public.course_modules (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses (id) on delete cascade,
  title varchar(200) not null,
  position integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index course_modules_course_idx on public.course_modules (course_id);

create table public.lessons (
  id uuid primary key default gen_random_uuid(),
  module_id uuid not null references public.course_modules (id) on delete cascade,
  title varchar(200) not null,
  description text not null default '',
  video_url varchar(600),
  duration_seconds integer not null default 0 check (duration_seconds >= 0),
  position integer not null default 0,
  is_free_preview boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index lessons_module_idx on public.lessons (module_id);

create table public.lesson_resources (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid not null references public.lessons (id) on delete cascade,
  title varchar(200) not null,
  file_url varchar(600) not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index lesson_resources_lesson_idx on public.lesson_resources (lesson_id);

create table public.enrollments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  course_id uuid not null references public.courses (id) on delete cascade,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint uq_enrollment_user_course unique (user_id, course_id)
);
create index enrollments_user_idx on public.enrollments (user_id);
create index enrollments_course_idx on public.enrollments (course_id);

create table public.lesson_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  lesson_id uuid not null references public.lessons (id) on delete cascade,
  completed_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint uq_progress_user_lesson unique (user_id, lesson_id)
);
create index lesson_progress_user_idx on public.lesson_progress (user_id);
create index lesson_progress_lesson_idx on public.lesson_progress (lesson_id);

create table public.live_classes (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses (id) on delete cascade,
  title varchar(200) not null,
  description text not null default '',
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  meeting_url varchar(600) not null,
  platform varchar(60) not null default 'Zoom',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index live_classes_course_idx on public.live_classes (course_id);
create index live_classes_starts_idx on public.live_classes (starts_at);

-- ---------------------------------------------------------------- assessments
create table public.assignments (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses (id) on delete cascade,
  module_id uuid references public.course_modules (id) on delete set null,
  title varchar(200) not null,
  instructions text not null default '',
  deadline timestamptz not null,
  max_marks integer not null default 100,
  allow_late boolean not null default false,
  attachment_url varchar(600),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index assignments_course_idx on public.assignments (course_id);
create index assignments_module_idx on public.assignments (module_id);
create index assignments_deadline_idx on public.assignments (deadline);

create table public.assignment_submissions (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.assignments (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  text_answer text,
  file_url varchar(600),
  submitted_at timestamptz not null,
  is_late boolean not null default false,
  status public.submission_status not null default 'submitted',
  marks numeric(6, 2),
  feedback text,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint uq_submission_assignment_user unique (assignment_id, user_id)
);
create index submissions_assignment_idx on public.assignment_submissions (assignment_id);
create index submissions_user_idx on public.assignment_submissions (user_id);
create index submissions_status_idx on public.assignment_submissions (status);

create table public.quizzes (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses (id) on delete cascade,
  module_id uuid references public.course_modules (id) on delete set null,
  title varchar(200) not null,
  description text not null default '',
  time_limit_minutes integer not null default 0,  -- 0 = no limit
  show_results boolean not null default true,
  is_published boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index quizzes_course_idx on public.quizzes (course_id);

create table public.quiz_questions (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references public.quizzes (id) on delete cascade,
  text text not null,
  marks integer not null default 1,
  position integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index quiz_questions_quiz_idx on public.quiz_questions (quiz_id);

-- is_correct is the quiz answer key: students can never read this table (see security migration).
create table public.quiz_options (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.quiz_questions (id) on delete cascade,
  text varchar(500) not null,
  is_correct boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index quiz_options_question_idx on public.quiz_options (question_id);

create table public.quiz_attempts (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references public.quizzes (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  score integer not null default 0,
  total_marks integer not null default 0,
  started_at timestamptz not null,
  submitted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index quiz_attempts_quiz_idx on public.quiz_attempts (quiz_id);
create index quiz_attempts_user_idx on public.quiz_attempts (user_id);

create table public.quiz_answers (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null references public.quiz_attempts (id) on delete cascade,
  question_id uuid not null references public.quiz_questions (id) on delete cascade,
  option_id uuid references public.quiz_options (id) on delete set null,
  is_correct boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index quiz_answers_attempt_idx on public.quiz_answers (attempt_id);

-- ---------------------------------------------------------------- money, messages, certificates
create table public.payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  course_id uuid not null references public.courses (id) on delete cascade,
  amount numeric(10, 2) not null,
  currency varchar(8) not null default 'INR',
  status public.payment_status not null default 'created',
  razorpay_order_id varchar(120) unique,
  razorpay_payment_id varchar(120),
  razorpay_signature varchar(255),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index payments_user_idx on public.payments (user_id);
create index payments_course_idx on public.payments (course_id);
create index payments_status_idx on public.payments (status);

create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  type varchar(40) not null,
  title varchar(200) not null,
  message text not null default '',
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index notifications_user_idx on public.notifications (user_id);
create index notifications_read_idx on public.notifications (is_read);

create table public.certificates (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  course_id uuid not null references public.courses (id) on delete cascade,
  certificate_code varchar(40) not null unique,
  issued_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint uq_certificate_user_course unique (user_id, course_id)
);
create index certificates_user_idx on public.certificates (user_id);
create index certificates_course_idx on public.certificates (course_id);

create table public.demo_requests (
  id uuid primary key default gen_random_uuid(),
  name varchar(120) not null,
  email varchar(255) not null,
  phone varchar(32) not null,
  course_interest varchar(200),
  preferred_time varchar(80),
  message text,
  is_contacted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index demo_requests_contacted_idx on public.demo_requests (is_contacted);

create table public.contact_messages (
  id uuid primary key default gen_random_uuid(),
  name varchar(120) not null,
  email varchar(255) not null,
  phone varchar(32),
  subject varchar(200) not null,
  message text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index contact_messages_read_idx on public.contact_messages (is_read);

-- updated_at on every table
do $$
declare t text;
begin
  foreach t in array array['profiles', 'courses', 'course_modules', 'lessons', 'lesson_resources', 'enrollments',
    'lesson_progress', 'live_classes', 'assignments', 'assignment_submissions', 'quizzes', 'quiz_questions',
    'quiz_options', 'quiz_attempts', 'quiz_answers', 'payments', 'notifications', 'certificates', 'demo_requests',
    'contact_messages', 'platform_settings']
  loop
    execute format('create trigger touch_updated_at before update on public.%I for each row execute function private.touch_updated_at()', t);
  end loop;
end $$;

-- Every new sign-up gets a profile. The role is ALWAYS student: admins are promoted by scripts/create-admin.mjs only,
-- never from sign-up metadata (which the user controls).
create or replace function private.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, name, email, role)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'name'), ''), split_part(new.email, '@', 1)),
    lower(new.email),
    'student'
  );
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function private.handle_new_user();

-- Keep profiles.email in step when a user changes their login email.
create or replace function private.handle_user_email_change() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.profiles set email = lower(new.email) where id = new.id;
  return new;
end $$;

create trigger on_auth_user_email_changed after update of email on auth.users
  for each row when (old.email is distinct from new.email) execute function private.handle_user_email_change();
