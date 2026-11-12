-- GTapex Academy: complete database setup. Paste into Supabase dashboard > SQL Editor and run ONCE on a new project.
-- Generated from supabase/migrations/*.sql and supabase/seed.sql. All-or-nothing: on any error nothing is kept.
begin;

-- ======== 20261030000001_schema.sql ========
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


-- ======== 20261030000002_security.sql ========
-- GTapex Academy on Supabase: lock-down and shared helpers.
--
-- Security model ("gatekeeper inside the database"):
--   * Every table has row level security ON and NO policies, and anon/authenticated have no table grants.
--     The website can never read or write a table directly, so a forgotten rule cannot leak data.
--   * The website calls the public.* functions in the API migrations. Each one checks who is calling
--     (private.auth_user / require_admin / require_student) exactly like the FastAPI dependencies did.
--   * Helpers live in the private schema, which the API does not expose.

do $$
declare t record;
begin
  for t in select tablename from pg_tables where schemaname = 'public'
  loop
    execute format('alter table public.%I enable row level security', t.tablename);
    execute format('revoke all on table public.%I from anon, authenticated', t.tablename);
  end loop;
end $$;

-- Tables created later by the postgres role must not be granted to the API roles either.
alter default privileges in schema public revoke all on tables from anon, authenticated;
alter default privileges in schema public revoke all on sequences from anon, authenticated;
-- Functions are granted explicitly at the end of the API migrations.
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;

revoke all on schema private from public, anon, authenticated;

-- ---------------------------------------------------------------- errors
-- Raises an error the frontend understands: message = text to show, hint = machine code
-- (the same codes the FastAPI backend returned, e.g. already_enrolled, payment_required).
create or replace function private.err(p_code text, p_message text) returns void
language plpgsql set search_path = '' as $$
begin
  raise exception using errcode = 'P0001', message = p_message, hint = p_code;
end $$;

create or replace function private.not_found(p_what text) returns void
language sql set search_path = '' as $$ select private.err('not_found', p_what || ' not found') $$;

-- ---------------------------------------------------------------- who is calling
-- Equivalent of deps.get_current_user: signed in, profile exists, account enabled.
create or replace function private.auth_user() returns public.profiles
language plpgsql stable security definer set search_path = '' as $$
declare p public.profiles;
begin
  if auth.uid() is null then
    perform private.err('unauthorized', 'Authentication required');
  end if;
  select * into p from public.profiles where id = auth.uid();
  if not found then
    perform private.err('invalid_token', 'User no longer exists');
  end if;
  if not p.is_active then
    perform private.err('account_disabled', 'Your account has been disabled. Contact support.');
  end if;
  return p;
end $$;

-- deps.get_optional_user: the signed-in, enabled user, or null for visitors.
create or replace function private.optional_user() returns public.profiles
language plpgsql stable security definer set search_path = '' as $$
declare p public.profiles;
begin
  if auth.uid() is null then return null; end if;
  select * into p from public.profiles where id = auth.uid() and is_active;
  return p;
end $$;

create or replace function private.require_admin() returns public.profiles
language plpgsql stable security definer set search_path = '' as $$
declare p public.profiles := private.auth_user();
begin
  if p.role <> 'admin' then perform private.err('forbidden', 'Admin access required'); end if;
  return p;
end $$;

create or replace function private.require_student() returns public.profiles
language plpgsql stable security definer set search_path = '' as $$
declare p public.profiles := private.auth_user();
begin
  if p.role <> 'student' then perform private.err('forbidden', 'This area is for students only'); end if;
  return p;
end $$;

-- Used by storage policies (they run as the signed-in user).
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin' and is_active)
$$;

-- ---------------------------------------------------------------- validation helpers
-- Trimmed text with length limits, mirroring the pydantic Field(min_length, max_length) rules.
create or replace function private.text_field(p_value text, p_label text, p_min int, p_max int, p_required boolean default true)
returns text language plpgsql immutable set search_path = '' as $$
declare v text := nullif(trim(coalesce(p_value, '')), '');
begin
  if v is null then
    if p_required and p_min > 0 then perform private.err('validation_error', p_label || ' is required'); end if;
    return null;
  end if;
  if length(v) < p_min then perform private.err('validation_error', p_label || ' must be at least ' || p_min || ' characters'); end if;
  if length(v) > p_max then perform private.err('validation_error', p_label || ' must be at most ' || p_max || ' characters'); end if;
  return v;
end $$;

create or replace function private.valid_email(p_value text) returns text
language plpgsql immutable set search_path = '' as $$
declare v text := lower(trim(coalesce(p_value, '')));
begin
  if v !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' or length(v) > 255 then
    perform private.err('validation_error', 'Enter a valid email address');
  end if;
  return v;
end $$;

-- "30 Oct 2026, 14:05" in UTC, as the FastAPI notifications formatted dates.
create or replace function private.fmt_ts(p_ts timestamptz) returns text
language sql immutable set search_path = '' as $$ select to_char(p_ts at time zone 'UTC', 'DD Mon YYYY, HH24:MI') $$;

-- Rupees with thousands separators: 1,499.00
create or replace function private.fmt_money(p_amount numeric) returns text
language sql immutable set search_path = '' as $$ select trim(to_char(p_amount, 'FM9,999,999,990.00')) $$;

-- Offset/limit for page + page_size query params (pages are 1-based, sizes clamped like the FastAPI Query rules).
create or replace function private.page_meta(p_total bigint, p_page int, p_page_size int) returns jsonb
language sql immutable set search_path = '' as $$
  select jsonb_build_object('total', p_total, 'page', p_page, 'page_size', p_page_size,
    'pages', case when p_total > 0 then ceil(p_total::numeric / p_page_size)::int else 0 end)
$$;

-- ---------------------------------------------------------------- notifications
create or replace function private.notify(p_user_id uuid, p_type text, p_title text, p_message text default '')
returns void language sql security definer set search_path = '' as $$
  insert into public.notifications (user_id, type, title, message) values (p_user_id, p_type, left(p_title, 200), coalesce(p_message, ''))
$$;

create or replace function private.notify_many(p_user_ids uuid[], p_type text, p_title text, p_message text default '')
returns void language sql security definer set search_path = '' as $$
  insert into public.notifications (user_id, type, title, message)
  select u, p_type, left(p_title, 200), coalesce(p_message, '') from unnest(p_user_ids) u
$$;

create or replace function private.notify_admins(p_type text, p_title text, p_message text default '')
returns void language sql security definer set search_path = '' as $$
  insert into public.notifications (user_id, type, title, message)
  select id, p_type, left(p_title, 200), coalesce(p_message, '') from public.profiles where role = 'admin'
$$;

-- Lazily create live-class and deadline reminders for a student (deduplicated), like services.notifications.sync_reminders.
create or replace function private.sync_reminders(p_user_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.notifications (user_id, type, title, message)
  select p_user_id, 'live_class', left('Live class soon: ' || lc.title, 200),
         'Starts ' || private.fmt_ts(lc.starts_at) || ' UTC on ' || lc.platform || '.'
  from public.live_classes lc
  join public.enrollments e on e.course_id = lc.course_id and e.user_id = p_user_id
  where lc.starts_at > now() and lc.starts_at <= now() + interval '24 hours'
    and not exists (select 1 from public.notifications n where n.user_id = p_user_id and n.type = 'live_class'
      and n.title = left('Live class soon: ' || lc.title, 200)
      and n.message = 'Starts ' || private.fmt_ts(lc.starts_at) || ' UTC on ' || lc.platform || '.');

  insert into public.notifications (user_id, type, title, message)
  select p_user_id, 'assignment_deadline', left('Assignment due soon: ' || a.title, 200),
         'Deadline ' || private.fmt_ts(a.deadline) || ' UTC.'
  from public.assignments a
  join public.enrollments e on e.course_id = a.course_id and e.user_id = p_user_id
  where a.deadline > now() and a.deadline <= now() + interval '48 hours'
    and not exists (select 1 from public.assignment_submissions s where s.assignment_id = a.id and s.user_id = p_user_id)
    and not exists (select 1 from public.notifications n where n.user_id = p_user_id and n.type = 'assignment_deadline'
      and n.title = left('Assignment due soon: ' || a.title, 200) and n.message = 'Deadline ' || private.fmt_ts(a.deadline) || ' UTC.');
end $$;

-- ---------------------------------------------------------------- courses
create or replace function private.slugify(p_text text) returns text
language sql immutable set search_path = '' as $$
  select coalesce(nullif(trim(both '-' from regexp_replace(lower(p_text), '[^a-z0-9]+', '-', 'g')), ''), 'course')
$$;

create or replace function private.unique_slug(p_title text, p_exclude uuid default null) returns text
language plpgsql security definer set search_path = '' as $$
declare base text := private.slugify(p_title); s text := base; n int := 2;
begin
  while exists (select 1 from public.courses where slug = s and (p_exclude is null or id <> p_exclude)) loop
    s := base || '-' || n; n := n + 1;
  end loop;
  return s;
end $$;

create or replace function private.is_enrolled(p_user_id uuid, p_course_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select p_user_id is not null and exists (select 1 from public.enrollments where user_id = p_user_id and course_id = p_course_id)
$$;

-- services.courses.require_access: admins see everything; students need an enrollment.
create or replace function private.require_access(p_user public.profiles, p_course_id uuid) returns void
language plpgsql stable security definer set search_path = '' as $$
begin
  if p_user.role = 'admin' then return; end if;
  if not private.is_enrolled(p_user.id, p_course_id) then
    perform private.err('forbidden', 'You must be enrolled in this course to access this content');
  end if;
end $$;

-- CourseCard
create or replace function private.course_card(c public.courses) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', c.id, 'title', c.title, 'slug', c.slug, 'short_description', c.short_description, 'category', c.category,
    'difficulty', c.difficulty, 'price', c.price::float8, 'thumbnail_url', c.thumbnail_url, 'is_published', c.is_published,
    'lesson_count', (select count(*) from public.lessons l join public.course_modules m on m.id = l.module_id where m.course_id = c.id),
    'duration_seconds', (select coalesce(sum(l.duration_seconds), 0) from public.lessons l join public.course_modules m on m.id = l.module_id where m.course_id = c.id),
    'enrolled_count', (select count(*) from public.enrollments e where e.course_id = c.id))
$$;

-- LessonOut (full lesson, with video and resources)
create or replace function private.lesson_out(l public.lessons) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', l.id, 'module_id', l.module_id, 'title', l.title, 'description', l.description, 'video_url', l.video_url,
    'duration_seconds', l.duration_seconds, 'position', l.position, 'is_free_preview', l.is_free_preview,
    'resources', coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'title', r.title, 'file_url', r.file_url) order by r.created_at)
                           from public.lesson_resources r where r.lesson_id = l.id), '[]'::jsonb))
$$;

-- ModuleOut (p_full) or ModulePublic (catalog: no video URLs or resources)
create or replace function private.modules_json(p_course_id uuid, p_full boolean) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(
    case when p_full then jsonb_build_object('id', m.id, 'course_id', m.course_id, 'title', m.title, 'position', m.position,
           'lessons', coalesce((select jsonb_agg(private.lesson_out(l) order by l.position, l.created_at) from public.lessons l where l.module_id = m.id), '[]'::jsonb))
         else jsonb_build_object('id', m.id, 'title', m.title, 'position', m.position,
           'lessons', coalesce((select jsonb_agg(jsonb_build_object('id', l.id, 'title', l.title, 'duration_seconds', l.duration_seconds,
                                 'position', l.position, 'is_free_preview', l.is_free_preview) order by l.position, l.created_at)
                               from public.lessons l where l.module_id = m.id), '[]'::jsonb))
    end order by m.position, m.created_at), '[]'::jsonb)
  from public.course_modules m where m.course_id = p_course_id
$$;

-- services.courses.progress_for
create or replace function private.progress_for(p_user_id uuid, p_course_id uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  with ls as (
    select l.id from public.lessons l join public.course_modules m on m.id = l.module_id where m.course_id = p_course_id
  ), done as (
    select lp.lesson_id from public.lesson_progress lp where lp.user_id = p_user_id and lp.lesson_id in (select id from ls)
  )
  select jsonb_build_object(
    'total_lessons', (select count(*) from ls),
    'completed_lessons', (select count(*) from done),
    'percentage', case when (select count(*) from ls) > 0
                    then round((select count(*) from done)::numeric / (select count(*) from ls) * 100, 1)::float8 else 0 end,
    'completed_ids', coalesce((select jsonb_agg(lesson_id) from done), '[]'::jsonb))
$$;

-- LiveClassOut. Students get the meeting link only from 15 minutes before start until the class ends.
create or replace function private.live_out(lc public.live_classes, p_is_admin boolean) returns jsonb
language sql stable security definer set search_path = '' as $$
  with s as (
    select case when now() < lc.starts_at then 'upcoming' when now() <= lc.ends_at then 'live' else 'completed' end as status
  )
  select jsonb_build_object(
    'id', lc.id, 'course_id', lc.course_id,
    'course_title', coalesce((select title from public.courses where id = lc.course_id), ''),
    'title', lc.title, 'description', lc.description, 'starts_at', lc.starts_at, 'ends_at', lc.ends_at,
    'platform', lc.platform, 'status', s.status,
    'meeting_url', case when p_is_admin or (extract(epoch from lc.starts_at - now()) <= 15 * 60 and s.status <> 'completed')
                        then lc.meeting_url end,
    'duration_minutes', floor(extract(epoch from lc.ends_at - lc.starts_at) / 60)::int)
  from s
$$;

-- Adds an enrollment and the two notifications (services.courses.enroll_user). Idempotent.
create or replace function private.enroll_user(p_user public.profiles, p_course public.courses) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if private.is_enrolled(p_user.id, p_course.id) then return; end if;
  insert into public.enrollments (user_id, course_id) values (p_user.id, p_course.id);
  perform private.notify(p_user.id, 'enrollment', 'Enrolled in ' || p_course.title, 'You can start learning right away.');
  perform private.notify_admins('enrollment', 'New enrollment', p_user.name || ' enrolled in ' || p_course.title);
end $$;

-- ---------------------------------------------------------------- assignments
create or replace function private.submission_out(s public.assignment_submissions) returns jsonb
language sql stable set search_path = '' as $$
  select jsonb_build_object(
    'id', s.id, 'assignment_id', s.assignment_id, 'text_answer', s.text_answer, 'file_url', s.file_url,
    'submitted_at', s.submitted_at, 'is_late', s.is_late, 'status', s.status, 'marks', s.marks::float8,
    'feedback', s.feedback, 'reviewed_at', s.reviewed_at)
$$;

-- AssignmentOut for one student
create or replace function private.assignment_out(a public.assignments, p_user_id uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', a.id, 'course_id', a.course_id, 'course_title', coalesce((select title from public.courses where id = a.course_id), ''),
    'module_id', a.module_id, 'title', a.title, 'instructions', a.instructions, 'deadline', a.deadline,
    'max_marks', a.max_marks, 'allow_late', a.allow_late, 'attachment_url', a.attachment_url,
    'is_past_deadline', now() > a.deadline,
    'submission', (select private.submission_out(s) from public.assignment_submissions s where s.assignment_id = a.id and s.user_id = p_user_id))
$$;

-- ---------------------------------------------------------------- certificates
create or replace function private.new_certificate_code() returns text
language sql volatile set search_path = '' as $$ select 'CERT-' || upper(encode(extensions.gen_random_bytes(5), 'hex')) $$;


-- ======== 20261030000003_student_api.sql ========
-- GTapex Academy on Supabase: API for visitors and students.
-- Each function is the port of one FastAPI endpoint (named in its comment) and returns the same JSON shape,
-- so the React pages keep working unchanged. The website calls them with supabase.rpc('<name>', {...}).

-- ================================================================ account  (/api/auth)
-- GET /api/auth/me
create or replace function public.get_me() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare p public.profiles := private.auth_user();
begin
  return jsonb_build_object('id', p.id, 'name', p.name, 'email', p.email, 'role', p.role, 'is_active', p.is_active, 'avatar_url', p.avatar_url);
end $$;

-- PUT /api/auth/me (name and avatar; password changes go through Supabase Auth on the website)
create or replace function public.update_my_profile(p_name text default null, p_avatar_url text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p public.profiles := private.auth_user();
begin
  if p_name is not null then
    update public.profiles set name = private.text_field(p_name, 'Name', 2, 120) where id = p.id;
  end if;
  if p_avatar_url is not null then
    update public.profiles set avatar_url = nullif(trim(p_avatar_url), '') where id = p.id;
  end if;
  return public.get_me();
end $$;

-- ================================================================ catalog  (/api/courses)
-- GET /api/courses
create or replace function public.list_courses(
  p_search text default null, p_category text default null, p_difficulty text default null, p_sort text default 'newest',
  p_free_only boolean default false, p_page int default 1, p_page_size int default 12
) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_page int := greatest(coalesce(p_page, 1), 1);
  v_size int := least(greatest(coalesce(p_page_size, 12), 1), 60);
  v_like text := '%' || trim(coalesce(p_search, '')) || '%';
  v_total bigint;
  v_items jsonb;
begin
  if coalesce(p_sort, 'newest') not in ('newest', 'popular', 'price_asc', 'price_desc', 'title') then
    perform private.err('validation_error', 'sort must be one of: newest, popular, price_asc, price_desc, title');
  end if;
  if p_difficulty is not null and p_difficulty not in ('beginner', 'intermediate', 'advanced') then
    perform private.err('validation_error', 'difficulty must be beginner, intermediate or advanced');
  end if;

  with hits as (
    select c.id, (select count(*) from public.enrollments e where e.course_id = c.id) as n, c.price, c.title, c.created_at
    from public.courses c
    where c.is_published
      and (nullif(trim(p_search), '') is null or c.title ilike v_like or c.short_description ilike v_like or c.category ilike v_like)
      and (p_category is null or c.category = p_category)
      and (p_difficulty is null or c.difficulty = p_difficulty::public.difficulty)
      and (not coalesce(p_free_only, false) or c.price = 0)
  ), ranked as (
    select id, row_number() over (order by
      case when p_sort = 'popular' then n end desc nulls last,
      case when p_sort = 'price_asc' then price end asc,
      case when p_sort = 'price_desc' then price end desc,
      case when p_sort = 'title' then title end asc,
      created_at desc) as ord
    from hits
  )
  select (select count(*) from hits),
         coalesce((select jsonb_agg(private.course_card(c) order by r.ord)
                   from (select * from ranked order by ord offset (v_page - 1) * v_size limit v_size) r
                   join public.courses c on c.id = r.id), '[]'::jsonb)
  into v_total, v_items;

  return jsonb_build_object('items', v_items) || private.page_meta(v_total, v_page, v_size);
end $$;

-- GET /api/courses/categories
create or replace function public.course_categories() returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(jsonb_build_object('name', category, 'count', n) order by category), '[]'::jsonb)
  from (select category, count(*) n from public.courses where is_published group by category) t
$$;

-- GET /api/courses/{id}
create or replace function public.get_course(p_course_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare u public.profiles := private.optional_user(); c public.courses;
begin
  select * into c from public.courses where id = p_course_id;
  if not found or (not c.is_published and coalesce(u.role::text, '') <> 'admin') then perform private.not_found('Course'); end if;
  return private.course_card(c) || jsonb_build_object(
    'description', c.description, 'features', c.features,
    'modules', private.modules_json(c.id, false),
    'is_enrolled', private.is_enrolled(u.id, c.id));
end $$;

-- POST /api/courses/{id}/enroll (free courses only; paid courses go through the payments Edge Function)
create or replace function public.enroll_free_course(p_course_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare u public.profiles := private.auth_user(); c public.courses;
begin
  if u.role <> 'student' then perform private.err('forbidden', 'Only students can enroll in courses'); end if;
  select * into c from public.courses where id = p_course_id;
  if not found or not c.is_published then perform private.not_found('Course'); end if;
  if private.is_enrolled(u.id, c.id) then perform private.err('already_enrolled', 'You are already enrolled in this course'); end if;
  if c.price > 0 then perform private.err('payment_required', 'This is a paid course. Complete the payment to enroll.'); end if;
  perform private.enroll_user(u, c);
  return jsonb_build_object('message', 'Enrolled successfully');
end $$;

-- GET /api/courses/{id}/lessons (the course player)
create or replace function public.course_lessons(p_course_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare u public.profiles := private.auth_user(); c public.courses;
begin
  select * into c from public.courses where id = p_course_id;
  if not found then perform private.not_found('Course'); end if;
  perform private.require_access(u, c.id);
  return jsonb_build_object(
    'course', jsonb_build_object('id', c.id, 'title', c.title),
    'modules', private.modules_json(c.id, true),
    'progress', private.progress_for(u.id, c.id));
end $$;

-- ================================================================ leads  (/api/demo-requests, /api/contact)
create or replace function public.book_demo(
  p_name text, p_email text, p_phone text, p_course_interest text default null, p_preferred_time text default null, p_message text default null
) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.demo_requests (name, email, phone, course_interest, preferred_time, message)
  values (private.text_field(p_name, 'Name', 2, 120), private.valid_email(p_email), private.text_field(p_phone, 'Phone', 7, 32),
          private.text_field(p_course_interest, 'Course interest', 0, 200, false),
          private.text_field(p_preferred_time, 'Preferred time', 0, 80, false),
          private.text_field(p_message, 'Message', 0, 1000, false));
  return jsonb_build_object('message', 'Thanks! Our team will contact you shortly to confirm your free demo.');
end $$;

create or replace function public.send_contact_message(
  p_name text, p_email text, p_subject text, p_message text, p_phone text default null
) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.contact_messages (name, email, phone, subject, message)
  values (private.text_field(p_name, 'Name', 2, 120), private.valid_email(p_email), private.text_field(p_phone, 'Phone', 0, 32, false),
          private.text_field(p_subject, 'Subject', 2, 200), private.text_field(p_message, 'Message', 5, 3000));
  return jsonb_build_object('message', 'Thanks for reaching out! We''ll get back to you within one working day.');
end $$;

-- ================================================================ student area  (/api/student)
create or replace function private.my_course_rows(p_user_id uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select coalesce(jsonb_agg(row order by enrolled_at desc), '[]'::jsonb) from (
    select jsonb_build_object(
      'course', private.course_card(c),
      'progress', p - 'completed_ids',
      'enrolled_at', e.created_at,
      'completed_at', e.completed_at,
      'is_completed', (p ->> 'total_lessons')::int > 0 and (p ->> 'percentage')::numeric >= 100) as row,
      e.created_at as enrolled_at
    from public.enrollments e
    join public.courses c on c.id = e.course_id
    cross join lateral (select private.progress_for(p_user_id, e.course_id) as p) pr
    where e.user_id = p_user_id
  ) t
$$;

-- GET /api/student/courses
create or replace function public.my_courses() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare u public.profiles := private.require_student();
begin
  return private.my_course_rows(u.id);
end $$;

-- GET /api/student/dashboard
create or replace function public.student_dashboard() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  u public.profiles := private.require_student();
  v_courses jsonb := private.my_course_rows(u.id);
  v_pending jsonb;
  v_upcoming jsonb;
  v_activity jsonb;
begin
  select coalesce(jsonb_agg(private.assignment_out(a, u.id) order by a.deadline), '[]'::jsonb) into v_pending
  from public.assignments a
  where a.course_id in (select course_id from public.enrollments where user_id = u.id)
    and not exists (select 1 from public.assignment_submissions s where s.assignment_id = a.id and s.user_id = u.id)
    and (a.deadline > now() or a.allow_late);

  select coalesce(jsonb_agg(private.live_out(lc, false) order by lc.starts_at), '[]'::jsonb) into v_upcoming
  from (select * from public.live_classes
        where course_id in (select course_id from public.enrollments where user_id = u.id) and ends_at >= now()
        order by starts_at limit 5) lc;

  select coalesce(jsonb_agg(jsonb_build_object('type', type, 'title', title, 'at', at) order by at desc), '[]'::jsonb) into v_activity
  from (
    select * from (
      (select 'lesson' as type, 'Completed lesson: ' || l.title as title, lp.completed_at as at
       from public.lesson_progress lp join public.lessons l on l.id = lp.lesson_id
       where lp.user_id = u.id order by lp.completed_at desc limit 6)
      union all
      (select 'assignment', 'Submitted assignment: ' || a.title, s.submitted_at
       from public.assignment_submissions s join public.assignments a on a.id = s.assignment_id
       where s.user_id = u.id order by s.submitted_at desc limit 4)
    ) x order by at desc limit 8
  ) t;

  return jsonb_build_object(
    'stats', jsonb_build_object(
      'enrolled', jsonb_array_length(v_courses),
      'in_progress', (select count(*) from jsonb_array_elements(v_courses) c
                      where not (c ->> 'is_completed')::boolean and (c -> 'progress' ->> 'completed_lessons')::int > 0),
      'completed', (select count(*) from jsonb_array_elements(v_courses) c where (c ->> 'is_completed')::boolean),
      'pending_assignments', jsonb_array_length(v_pending)),
    'courses', v_courses,
    'pending_assignments', coalesce((select jsonb_agg(x) from (select x from jsonb_array_elements(v_pending) x limit 6) t), '[]'::jsonb),
    'upcoming_live_classes', v_upcoming,
    'recent_activity', v_activity);
end $$;

-- POST /api/student/lessons/{id}/complete
create or replace function public.complete_lesson(p_lesson_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare u public.profiles := private.require_student(); v_course public.courses; p jsonb;
begin
  select c.* into v_course from public.lessons l join public.course_modules m on m.id = l.module_id
    join public.courses c on c.id = m.course_id where l.id = p_lesson_id;
  if not found then perform private.not_found('Lesson'); end if;
  if not private.is_enrolled(u.id, v_course.id) then perform private.err('forbidden', 'You must be enrolled in this course'); end if;

  insert into public.lesson_progress (user_id, lesson_id, completed_at) values (u.id, p_lesson_id, now())
  on conflict (user_id, lesson_id) do nothing;

  p := private.progress_for(u.id, v_course.id);
  if (p ->> 'total_lessons')::int > 0 and (p ->> 'percentage')::numeric >= 100 then
    update public.enrollments set completed_at = now()
    where user_id = u.id and course_id = v_course.id and completed_at is null;
    if found then
      perform private.notify(u.id, 'course_completed', 'Course completed: ' || v_course.title,
                             'Congratulations! Your certificate is ready to download.');
    end if;
  end if;
  return p;
end $$;

-- DELETE /api/student/lessons/{id}/complete
create or replace function public.uncomplete_lesson(p_lesson_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare u public.profiles := private.require_student(); v_course_id uuid;
begin
  select m.course_id into v_course_id from public.lessons l join public.course_modules m on m.id = l.module_id where l.id = p_lesson_id;
  if not found then perform private.not_found('Lesson'); end if;
  if not private.is_enrolled(u.id, v_course_id) then perform private.err('forbidden', 'You must be enrolled in this course'); end if;
  delete from public.lesson_progress where user_id = u.id and lesson_id = p_lesson_id;
  update public.enrollments set completed_at = null where user_id = u.id and course_id = v_course_id;
  return private.progress_for(u.id, v_course_id);
end $$;

-- GET /api/student/courses/{id}/progress
create or replace function public.course_progress(p_course_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare u public.profiles := private.require_student();
begin
  if not private.is_enrolled(u.id, p_course_id) then perform private.err('forbidden', 'You must be enrolled in this course'); end if;
  return private.progress_for(u.id, p_course_id);
end $$;

-- GET /api/student/courses/{id}/content (assignments, live classes and quizzes for the course player)
create or replace function public.student_course_content(p_course_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare u public.profiles := private.require_student();
begin
  if not private.is_enrolled(u.id, p_course_id) then perform private.err('forbidden', 'You must be enrolled in this course'); end if;
  return jsonb_build_object(
    'assignments', coalesce((select jsonb_agg(private.assignment_out(a, u.id) order by a.deadline) from public.assignments a where a.course_id = p_course_id), '[]'::jsonb),
    'live_classes', coalesce((select jsonb_agg(private.live_out(lc, false) order by lc.starts_at) from public.live_classes lc where lc.course_id = p_course_id), '[]'::jsonb),
    'quizzes', coalesce((select jsonb_agg(jsonb_build_object('id', q.id, 'title', q.title, 'time_limit_minutes', q.time_limit_minutes) order by q.created_at)
                         from public.quizzes q where q.course_id = p_course_id and q.is_published), '[]'::jsonb));
end $$;

-- GET /api/student/assignments
create or replace function public.my_assignments() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare u public.profiles := private.require_student();
begin
  return coalesce((select jsonb_agg(private.assignment_out(a, u.id) order by a.deadline) from public.assignments a
                   where a.course_id in (select course_id from public.enrollments where user_id = u.id)), '[]'::jsonb);
end $$;

create or replace function private.my_assignment(p_user public.profiles, p_assignment_id uuid) returns public.assignments
language plpgsql stable security definer set search_path = '' as $$
declare a public.assignments;
begin
  select * into a from public.assignments where id = p_assignment_id;
  if not found then perform private.not_found('Assignment'); end if;
  if not private.is_enrolled(p_user.id, a.course_id) then perform private.err('forbidden', 'You must be enrolled in this course'); end if;
  return a;
end $$;

-- GET /api/student/assignments/{id}
create or replace function public.my_assignment(p_assignment_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare u public.profiles := private.require_student();
begin
  return private.assignment_out(private.my_assignment(u, p_assignment_id), u.id);
end $$;

-- POST /api/student/assignments/{id}/submit
-- The website uploads the file to the 'submissions' storage bucket first (into the student's own folder)
-- and passes its public URL here.
create or replace function public.submit_assignment(p_assignment_id uuid, p_text_answer text default null, p_file_url text default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  u public.profiles := private.require_student();
  a public.assignments := private.my_assignment(u, p_assignment_id);
  s public.assignment_submissions;
  v_late boolean := now() > a.deadline;
  v_text text := nullif(trim(coalesce(p_text_answer, '')), '');
  v_file text := nullif(trim(coalesce(p_file_url, '')), '');
begin
  if v_late and not a.allow_late then perform private.err('deadline_passed', 'The deadline for this assignment has passed'); end if;
  if v_file is not null and position('/storage/v1/object/public/submissions/' || u.id::text || '/' in v_file) = 0 then
    perform private.err('invalid_file', 'Upload the file again and resubmit');
  end if;
  select * into s from public.assignment_submissions where assignment_id = a.id and user_id = u.id;
  if v_text is null and v_file is null and (s.id is null or s.file_url is null) then
    perform private.err('empty_submission', 'Add a text answer or upload a file');
  end if;
  if s.status = 'reviewed' then
    perform private.err('already_reviewed', 'This submission has already been graded and can''t be changed');
  end if;

  insert into public.assignment_submissions (assignment_id, user_id, text_answer, file_url, submitted_at, is_late, status)
  values (a.id, u.id, v_text, v_file, now(), v_late, 'submitted')
  on conflict (assignment_id, user_id) do update set
    text_answer = excluded.text_answer,
    file_url = coalesce(excluded.file_url, public.assignment_submissions.file_url),
    submitted_at = excluded.submitted_at, is_late = excluded.is_late, status = 'submitted';

  perform private.notify_admins('submission', 'New assignment submission', u.name || ' submitted ''' || a.title || '''');
  return private.assignment_out(a, u.id);
end $$;

-- ================================================================ certificates
create or replace function private.certificate_out(c public.certificates) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', c.id, 'course_id', c.course_id, 'course_title', (select title from public.courses where id = c.course_id),
                            'certificate_code', c.certificate_code, 'issued_at', c.issued_at)
$$;

-- GET /api/student/certificates
create or replace function public.my_certificates() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare u public.profiles := private.require_student();
begin
  return coalesce((select jsonb_agg(private.certificate_out(c) order by c.issued_at desc) from public.certificates c where c.user_id = u.id), '[]'::jsonb);
end $$;

-- POST /api/student/courses/{id}/certificate
create or replace function public.generate_certificate(p_course_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare u public.profiles := private.require_student(); c public.courses; cert public.certificates; p jsonb;
begin
  select * into c from public.courses where id = p_course_id;
  if not found then perform private.not_found('Course'); end if;
  if not private.is_enrolled(u.id, c.id) then perform private.err('forbidden', 'You must be enrolled in this course'); end if;
  p := private.progress_for(u.id, c.id);
  if (p ->> 'total_lessons')::int = 0 or (p ->> 'percentage')::numeric < 100 then
    perform private.err('course_incomplete', 'Complete all lessons to unlock your certificate');
  end if;
  select * into cert from public.certificates where user_id = u.id and course_id = c.id;
  if not found then
    insert into public.certificates (user_id, course_id, certificate_code, issued_at)
    values (u.id, c.id, private.new_certificate_code(), now()) returning * into cert;
    perform private.notify(u.id, 'certificate', 'Certificate issued', 'Your certificate for ' || c.title || ' is ready.');
  end if;
  return private.certificate_out(cert);
end $$;

-- GET /api/student/certificates/{id}/download: the website draws the PDF from these details.
create or replace function public.certificate_details(p_certificate_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare u public.profiles := private.require_student(); cert public.certificates;
begin
  select * into cert from public.certificates where id = p_certificate_id and user_id = u.id;
  if not found then perform private.not_found('Certificate'); end if;
  return jsonb_build_object(
    'certificate_code', cert.certificate_code, 'issued_at', cert.issued_at, 'student_name', u.name,
    'course_title', (select title from public.courses where id = cert.course_id),
    'platform_name', (select platform_name from public.platform_settings));
end $$;

-- ================================================================ quizzes  (/api/quizzes)
create or replace function private.quiz_for(p_user public.profiles, p_quiz_id uuid) returns public.quizzes
language plpgsql stable security definer set search_path = '' as $$
declare q public.quizzes;
begin
  select * into q from public.quizzes where id = p_quiz_id;
  if not found then perform private.not_found('Quiz'); end if;
  if p_user.role = 'student' then
    if not q.is_published then perform private.not_found('Quiz'); end if;
    if not private.is_enrolled(p_user.id, q.course_id) then
      perform private.err('forbidden', 'You must be enrolled in this course to take this quiz');
    end if;
  end if;
  return q;
end $$;

-- QuizStudentOut. Options never include is_correct.
create or replace function private.quiz_student_out(q public.quizzes, p_user_id uuid, p_with_questions boolean) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', q.id, 'course_id', q.course_id, 'course_title', coalesce((select title from public.courses where id = q.course_id), ''),
    'title', q.title, 'description', q.description, 'time_limit_minutes', q.time_limit_minutes, 'show_results', q.show_results,
    'question_count', (select count(*) from public.quiz_questions where quiz_id = q.id),
    'total_marks', (select coalesce(sum(marks), 0) from public.quiz_questions where quiz_id = q.id),
    'last_attempt', (select jsonb_build_object('id', a.id, 'score', a.score, 'total_marks', a.total_marks, 'submitted_at', a.submitted_at)
                     from public.quiz_attempts a where a.quiz_id = q.id and a.user_id = p_user_id and a.submitted_at is not null
                     order by a.submitted_at desc limit 1),
    'questions', case when p_with_questions then coalesce((
      select jsonb_agg(jsonb_build_object('id', qq.id, 'text', qq.text, 'marks', qq.marks,
               'options', coalesce((select jsonb_agg(jsonb_build_object('id', o.id, 'text', o.text) order by o.created_at, o.id)
                                    from public.quiz_options o where o.question_id = qq.id), '[]'::jsonb))
             order by qq.position, qq.created_at)
      from public.quiz_questions qq where qq.quiz_id = q.id), '[]'::jsonb) end)
$$;

-- GET /api/quizzes
create or replace function public.my_quizzes() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare u public.profiles := private.require_student();
begin
  return coalesce((select jsonb_agg(private.quiz_student_out(q, u.id, false) order by q.created_at desc) from public.quizzes q
                   where q.is_published and q.course_id in (select course_id from public.enrollments where user_id = u.id)), '[]'::jsonb);
end $$;

-- GET /api/quizzes/{id} (questions WITHOUT correct answers)
create or replace function public.get_quiz(p_quiz_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare u public.profiles := private.auth_user();
begin
  return private.quiz_student_out(private.quiz_for(u, p_quiz_id), u.id, true);
end $$;

-- POST /api/quizzes/{id}/start
create or replace function public.start_quiz(p_quiz_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare u public.profiles := private.require_student(); q public.quizzes := private.quiz_for(u, p_quiz_id); a public.quiz_attempts;
begin
  if not exists (select 1 from public.quiz_questions where quiz_id = q.id) then
    perform private.err('empty_quiz', 'This quiz has no questions yet');
  end if;
  insert into public.quiz_attempts (quiz_id, user_id, started_at) values (q.id, u.id, now()) returning * into a;
  return jsonb_build_object('attempt_id', a.id, 'started_at', a.started_at, 'time_limit_minutes', q.time_limit_minutes);
end $$;

-- POST /api/quizzes/{id}/attempt. Grading happens here, with the answer key the student can never read.
-- p_answers: [{"question_id": "...", "option_id": "..." | null}, ...]
create or replace function public.submit_quiz(p_quiz_id uuid, p_answers jsonb, p_attempt_id uuid default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  u public.profiles := private.require_student();
  q public.quizzes := private.quiz_for(u, p_quiz_id);
  a public.quiz_attempts;
  v_grace interval := interval '60 seconds';
  v_score int := 0; v_total int := 0; v_results jsonb := '[]'::jsonb;
  qq record; v_selected uuid; v_correct uuid; v_ok boolean;
begin
  if not exists (select 1 from public.quiz_questions where quiz_id = q.id) then
    perform private.err('empty_quiz', 'This quiz has no questions yet');
  end if;
  if p_attempt_id is not null then
    select * into a from public.quiz_attempts where id = p_attempt_id;
    if not found or a.user_id <> u.id or a.quiz_id <> q.id then perform private.not_found('Attempt'); end if;
    if a.submitted_at is not null then perform private.err('already_submitted', 'This attempt was already submitted'); end if;
    if q.time_limit_minutes > 0 and now() > a.started_at + make_interval(mins => q.time_limit_minutes) + v_grace then
      -- The expired attempt stays unsubmitted (submitted_at null), which every listing already ignores.
      perform private.err('time_expired', 'Time limit exceeded. Please start a new attempt.');
    end if;
  else
    if q.time_limit_minutes > 0 then
      perform private.err('attempt_required', 'Start the quiz first so the timer can be tracked');
    end if;
    insert into public.quiz_attempts (quiz_id, user_id, started_at) values (q.id, u.id, now()) returning * into a;
  end if;

  for qq in select * from public.quiz_questions where quiz_id = q.id order by position, created_at loop
    v_total := v_total + qq.marks;
    select (x ->> 'option_id')::uuid into v_selected
      from jsonb_array_elements(coalesce(p_answers, '[]'::jsonb)) x
      where (x ->> 'question_id')::uuid = qq.id limit 1;
    if v_selected is not null and not exists (select 1 from public.quiz_options where id = v_selected and question_id = qq.id) then
      v_selected := null;  -- an option from another question counts as unanswered
    end if;
    select id into v_correct from public.quiz_options where question_id = qq.id and is_correct limit 1;
    v_ok := v_selected is not null and v_selected = v_correct;
    if v_ok then v_score := v_score + qq.marks; end if;
    insert into public.quiz_answers (attempt_id, question_id, option_id, is_correct) values (a.id, qq.id, v_selected, v_ok);
    v_results := v_results || jsonb_build_object('question_id', qq.id, 'selected_option_id', v_selected,
                                                 'correct_option_id', v_correct, 'is_correct', v_ok);
    v_selected := null; v_correct := null;
  end loop;

  update public.quiz_attempts set score = v_score, total_marks = v_total, submitted_at = now() where id = a.id;
  return jsonb_build_object(
    'attempt_id', a.id, 'score', v_score, 'total_marks', v_total,
    'percentage', case when v_total > 0 then round(v_score::numeric / v_total * 100, 1)::float8 else 0 end,
    'show_results', q.show_results,
    'results', case when q.show_results then v_results end);
end $$;

-- ================================================================ live classes  (/api/live-classes)
create or replace function public.list_live_classes(p_course_id uuid default null, p_include_past boolean default false, p_limit int default 50)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare u public.profiles := private.auth_user(); v_admin boolean := u.role = 'admin';
begin
  return coalesce((
    select jsonb_agg(private.live_out(lc, v_admin) order by lc.starts_at)
    from (select * from public.live_classes lc
          where (v_admin or lc.course_id in (select course_id from public.enrollments where user_id = u.id))
            and (p_course_id is null or lc.course_id = p_course_id)
            and (coalesce(p_include_past, false) or lc.ends_at >= now() - interval '1 hour')
          order by lc.starts_at limit least(greatest(coalesce(p_limit, 50), 1), 200)) lc), '[]'::jsonb);
end $$;

-- ================================================================ notifications  (/api/notifications)
create or replace function public.list_notifications(p_limit int default 30) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare u public.profiles := private.auth_user();
begin
  if u.role = 'student' then perform private.sync_reminders(u.id); end if;
  return jsonb_build_object(
    'items', coalesce((select jsonb_agg(jsonb_build_object('id', n.id, 'type', n.type, 'title', n.title, 'message', n.message,
                                                           'is_read', n.is_read, 'created_at', n.created_at) order by n.created_at desc)
                       from (select * from public.notifications where user_id = u.id order by created_at desc
                             limit least(greatest(coalesce(p_limit, 30), 1), 100)) n), '[]'::jsonb),
    'unread_count', (select count(*) from public.notifications where user_id = u.id and not is_read));
end $$;

create or replace function public.read_all_notifications() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare u public.profiles := private.auth_user();
begin
  update public.notifications set is_read = true where user_id = u.id and not is_read;
  return jsonb_build_object('message', 'All notifications marked as read');
end $$;

create or replace function public.read_notification(p_notification_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare u public.profiles := private.auth_user();
begin
  update public.notifications set is_read = true where id = p_notification_id and user_id = u.id;
  if not found then perform private.not_found('Notification'); end if;
  return jsonb_build_object('message', 'Marked as read');
end $$;

-- ================================================================ payments  (/api/payments)
-- GET /api/payments/my
create or replace function public.my_payments() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare u public.profiles := private.require_student();
begin
  return coalesce((select jsonb_agg(jsonb_build_object('id', p.id, 'course_title', c.title, 'amount', p.amount::float8,
                     'currency', p.currency, 'status', p.status, 'created_at', p.created_at) order by p.created_at desc)
                   from public.payments p join public.courses c on c.id = p.course_id where p.user_id = u.id), '[]'::jsonb);
end $$;

-- POST /api/payments/{order_id}/failed
create or replace function public.mark_payment_failed(p_order_id text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare u public.profiles := private.require_student(); p public.payments;
begin
  select * into p from public.payments where razorpay_order_id = p_order_id and user_id = u.id;
  if not found then perform private.not_found('Payment'); end if;
  if p.status = 'created' then
    update public.payments set status = 'failed' where id = p.id returning * into p;
  end if;
  return jsonb_build_object('status', p.status);
end $$;

-- The steps that need the Razorpay secret run in the 'payments' Edge Function. It calls these with the
-- service role key; they are NOT callable from the website (see grants).

-- Checks before creating a Razorpay order (create-order, first half). Returns the course to charge for.
create or replace function public.payment_prepare(p_user_id uuid, p_course_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare u public.profiles; c public.courses;
begin
  select * into u from public.profiles where id = p_user_id;
  if not found then perform private.err('invalid_token', 'User no longer exists'); end if;
  if not u.is_active then perform private.err('account_disabled', 'Your account has been disabled. Contact support.'); end if;
  if u.role <> 'student' then perform private.err('forbidden', 'This area is for students only'); end if;
  select * into c from public.courses where id = p_course_id;
  if not found or not c.is_published then perform private.not_found('Course'); end if;
  if private.is_enrolled(u.id, c.id) then perform private.err('already_enrolled', 'You are already enrolled in this course'); end if;
  if c.price <= 0 then perform private.err('free_course', 'This course is free. Use the enroll button.'); end if;
  return jsonb_build_object('course_id', c.id, 'title', c.title, 'price', c.price::float8);
end $$;

-- Records the Razorpay order (create-order, second half).
create or replace function public.payment_record_order(p_user_id uuid, p_course_id uuid, p_amount numeric, p_order_id text)
returns void language sql security definer set search_path = '' as $$
  insert into public.payments (user_id, course_id, amount, currency, status, razorpay_order_id)
  values (p_user_id, p_course_id, p_amount, 'INR', 'created', p_order_id)
$$;

-- Marks an order paid and enrolls the student. p_user_id is null when called from the Razorpay webhook.
-- Safe to call twice (verify + webhook): the second call just reports 'paid'.
create or replace function public.payment_mark_paid(p_order_id text, p_payment_id text, p_signature text default null, p_user_id uuid default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare p public.payments; u public.profiles; c public.courses;
begin
  select * into p from public.payments where razorpay_order_id = p_order_id for update;
  if not found or (p_user_id is not null and p.user_id <> p_user_id) then perform private.not_found('Payment'); end if;
  if p.status = 'paid' then return jsonb_build_object('status', 'paid', 'course_id', p.course_id); end if;
  update public.payments set status = 'paid', razorpay_payment_id = p_payment_id,
                             razorpay_signature = coalesce(p_signature, razorpay_signature) where id = p.id;
  select * into u from public.profiles where id = p.user_id;
  select * into c from public.courses where id = p.course_id;
  perform private.enroll_user(u, c);
  perform private.notify(u.id, 'payment', 'Payment successful', '₹' || private.fmt_money(p.amount) || ' paid for ' || c.title || '.');
  perform private.notify_admins('payment', 'New payment received', u.name || ' paid ₹' || private.fmt_money(p.amount) || ' for ' || c.title);
  return jsonb_build_object('status', 'paid', 'course_id', p.course_id);
end $$;

-- Signature check failed in the Edge Function.
create or replace function public.payment_mark_failed(p_order_id text, p_user_id uuid) returns void
language sql security definer set search_path = '' as $$
  update public.payments set status = 'failed' where razorpay_order_id = p_order_id and user_id = p_user_id and status = 'created'
$$;


-- ======== 20261030000004_admin_api.sql ========
-- GTapex Academy on Supabase: admin API (port of /api/admin/*). Every function starts with private.require_admin().
-- Create/update functions take a JSON object of fields; on update only the keys present are changed
-- (the FastAPI model_dump(exclude_unset=True) behaviour).

-- ================================================================ helpers
create or replace function private.admin_course_detail(c public.courses) returns jsonb
language sql stable security definer set search_path = '' as $$
  select private.course_card(c) || jsonb_build_object('description', c.description, 'features', c.features,
                                                      'modules', private.modules_json(c.id, true))
$$;

create or replace function private.course_or_404(p_course_id uuid) returns public.courses
language plpgsql stable security definer set search_path = '' as $$
declare c public.courses;
begin
  select * into c from public.courses where id = p_course_id;
  if not found then perform private.not_found('Course'); end if;
  return c;
end $$;

create or replace function private.module_or_404(p_module_id uuid) returns public.course_modules
language plpgsql stable security definer set search_path = '' as $$
declare m public.course_modules;
begin
  select * into m from public.course_modules where id = p_module_id;
  if not found then perform private.not_found('Module'); end if;
  return m;
end $$;

create or replace function private.check_module(p_course_id uuid, p_module_id uuid) returns void
language plpgsql stable security definer set search_path = '' as $$
begin
  if p_module_id is not null and not exists (select 1 from public.course_modules where id = p_module_id and course_id = p_course_id) then
    perform private.err('invalid_module', 'Module does not belong to this course');
  end if;
end $$;

create or replace function private.enrolled_ids(p_course_id uuid) returns uuid[]
language sql stable security definer set search_path = '' as $$
  select coalesce(array_agg(user_id), '{}') from public.enrollments where course_id = p_course_id
$$;

create or replace function private.ts_field(p_value jsonb, p_label text) returns timestamptz
language plpgsql stable set search_path = '' as $$
begin
  if p_value is null or jsonb_typeof(p_value) = 'null' then perform private.err('validation_error', p_label || ' is required'); end if;
  -- Times without a zone are treated as UTC, like services.courses.ensure_utc.
  return case when (p_value #>> '{}') ~ '(Z|[+-]\d\d:?\d\d)$' then (p_value #>> '{}')::timestamptz
              else ((p_value #>> '{}')::timestamp at time zone 'UTC') end;
exception when invalid_datetime_format or datetime_field_overflow then
  perform private.err('validation_error', p_label || ' is not a valid date and time');
  return null;
end $$;

create or replace function private.int_field(p_value jsonb, p_label text, p_min int, p_max int) returns int
language plpgsql immutable set search_path = '' as $$
declare v numeric;
begin
  begin
    v := (p_value #>> '{}')::numeric;
  exception when others then
    perform private.err('validation_error', p_label || ' must be a whole number');
  end;
  if v is null or v <> trunc(v) then perform private.err('validation_error', p_label || ' must be a whole number'); end if;
  if v < p_min or v > p_max then perform private.err('validation_error', p_label || ' must be between ' || p_min || ' and ' || p_max); end if;
  return v::int;
end $$;

-- ================================================================ dashboard
-- GET /api/admin/dashboard
create or replace function public.admin_dashboard() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_start date := (now() at time zone 'UTC')::date - 13;
begin
  perform private.require_admin();
  return jsonb_build_object(
    'stats', jsonb_build_object(
      'total_students', (select count(*) from public.profiles where role = 'student'),
      'total_courses', (select count(*) from public.courses),
      'total_enrollments', (select count(*) from public.enrollments),
      'total_revenue', (select coalesce(sum(amount), 0)::float8 from public.payments where status = 'paid'),
      'active_students', (select count(distinct user_id) from public.lesson_progress where completed_at >= now() - interval '30 days'),
      'pending_assignments', (select count(*) from public.assignment_submissions where status = 'submitted'),
      'upcoming_live_classes', (select count(*) from public.live_classes where starts_at >= now())),
    'enrollments_series', (
      select jsonb_agg(jsonb_build_object('date', d::date, 'count',
               (select count(*) from public.enrollments e where (e.created_at at time zone 'UTC')::date = d::date)) order by d)
      from generate_series(v_start, v_start + 13, interval '1 day') d),
    'revenue_series', coalesce((
      select jsonb_agg(jsonb_build_object('month', m, 'amount', amt) order by m) from (
        select m, amt from (
          select to_char(created_at at time zone 'UTC', 'YYYY-MM') m, sum(amount)::float8 amt
          from public.payments where status = 'paid' group by 1
        ) x order by m desc limit 6) y), '[]'::jsonb),
    'top_courses', coalesce((
      select jsonb_agg(jsonb_build_object('title', title, 'enrollments', n) order by n desc) from (
        select c.title, count(e.id) n from public.courses c join public.enrollments e on e.course_id = c.id
        group by c.id, c.title order by n desc limit 5) t), '[]'::jsonb));
end $$;

-- ================================================================ courses
-- GET /api/admin/courses
create or replace function public.admin_courses(p_search text default null) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  return coalesce((select jsonb_agg(private.course_card(c) order by c.created_at desc) from public.courses c
                   where nullif(trim(p_search), '') is null or c.title ilike '%' || trim(p_search) || '%'), '[]'::jsonb);
end $$;

-- GET /api/admin/courses/{id}
create or replace function public.admin_course(p_course_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  return private.admin_course_detail(private.course_or_404(p_course_id));
end $$;

-- Validates and writes the editable course fields present in p_data onto c.
create or replace function private.apply_course_fields(c public.courses, p_data jsonb) returns public.courses
language plpgsql stable set search_path = '' as $$
begin
  if p_data ? 'title' then c.title := private.text_field(p_data ->> 'title', 'Title', 3, 200); end if;
  if p_data ? 'short_description' then c.short_description := coalesce(private.text_field(p_data ->> 'short_description', 'Short description', 0, 300, false), ''); end if;
  if p_data ? 'description' then c.description := coalesce(p_data ->> 'description', ''); end if;
  if p_data ? 'category' then c.category := coalesce(private.text_field(p_data ->> 'category', 'Category', 0, 80, false), 'General'); end if;
  if p_data ? 'difficulty' and jsonb_typeof(p_data -> 'difficulty') <> 'null' then
    if (p_data ->> 'difficulty') not in ('beginner', 'intermediate', 'advanced') then
      perform private.err('validation_error', 'Difficulty must be beginner, intermediate or advanced');
    end if;
    c.difficulty := (p_data ->> 'difficulty')::public.difficulty;
  end if;
  if p_data ? 'price' and jsonb_typeof(p_data -> 'price') <> 'null' then
    if jsonb_typeof(p_data -> 'price') <> 'number' or (p_data ->> 'price')::numeric < 0 then
      perform private.err('validation_error', 'Price must be 0 or more');
    end if;
    c.price := (p_data ->> 'price')::numeric;
  end if;
  if p_data ? 'thumbnail_url' then c.thumbnail_url := nullif(trim(coalesce(p_data ->> 'thumbnail_url', '')), ''); end if;
  if p_data ? 'features' and jsonb_typeof(p_data -> 'features') <> 'null' then
    if jsonb_typeof(p_data -> 'features') <> 'array' then perform private.err('validation_error', 'Features must be a list'); end if;
    c.features := p_data -> 'features';
  end if;
  if p_data ? 'is_published' and jsonb_typeof(p_data -> 'is_published') <> 'null' then c.is_published := (p_data ->> 'is_published')::boolean; end if;
  return c;
end $$;

-- POST /api/admin/courses
create or replace function public.admin_create_course(p_data jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c public.courses;
begin
  perform private.require_admin();
  if not (p_data ? 'title') then perform private.err('validation_error', 'Title is required'); end if;
  c.id := gen_random_uuid(); c.short_description := ''; c.description := ''; c.category := 'General'; c.difficulty := 'beginner';
  c.price := 0; c.features := '[]'::jsonb; c.is_published := false;
  c := private.apply_course_fields(c, p_data);
  c.slug := private.unique_slug(c.title);
  insert into public.courses (id, title, slug, short_description, description, category, difficulty, price, thumbnail_url, is_published, features)
  values (c.id, c.title, c.slug, c.short_description, c.description, c.category, c.difficulty, c.price, c.thumbnail_url, c.is_published, c.features)
  returning * into c;
  return private.admin_course_detail(c);
end $$;

-- PUT /api/admin/courses/{id}
create or replace function public.admin_update_course(p_course_id uuid, p_data jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c public.courses;
begin
  perform private.require_admin();
  c := private.apply_course_fields(private.course_or_404(p_course_id), p_data);
  if p_data ? 'title' then c.slug := private.unique_slug(c.title, c.id); end if;
  update public.courses set title = c.title, slug = c.slug, short_description = c.short_description, description = c.description,
    category = c.category, difficulty = c.difficulty, price = c.price, thumbnail_url = c.thumbnail_url,
    is_published = c.is_published, features = c.features
  where id = c.id returning * into c;
  return private.admin_course_detail(c);
end $$;

-- DELETE /api/admin/courses/{id}
create or replace function public.admin_delete_course(p_course_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c public.courses;
begin
  perform private.require_admin();
  c := private.course_or_404(p_course_id);
  if exists (select 1 from public.payments where course_id = c.id and status = 'paid') then
    perform private.err('course_has_payments', 'This course has paid purchases. Unpublish it instead of deleting.');
  end if;
  delete from public.courses where id = c.id;
  return jsonb_build_object('message', 'Course deleted');
end $$;

-- ================================================================ modules
create or replace function private.module_out(m public.course_modules) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', m.id, 'course_id', m.course_id, 'title', m.title, 'position', m.position,
    'lessons', coalesce((select jsonb_agg(private.lesson_out(l) order by l.position, l.created_at) from public.lessons l where l.module_id = m.id), '[]'::jsonb))
$$;

create or replace function public.admin_create_module(p_course_id uuid, p_title text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c public.courses; m public.course_modules;
begin
  perform private.require_admin();
  c := private.course_or_404(p_course_id);
  insert into public.course_modules (course_id, title, position)
  values (c.id, private.text_field(p_title, 'Title', 1, 200),
          coalesce((select max(position) from public.course_modules where course_id = c.id), 0) + 1)
  returning * into m;
  return private.module_out(m);
end $$;

create or replace function public.admin_update_module(p_module_id uuid, p_title text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare m public.course_modules;
begin
  perform private.require_admin();
  perform private.module_or_404(p_module_id);
  update public.course_modules set title = private.text_field(p_title, 'Title', 1, 200) where id = p_module_id returning * into m;
  return private.module_out(m);
end $$;

create or replace function public.admin_delete_module(p_module_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin();
  perform private.module_or_404(p_module_id);
  delete from public.course_modules where id = p_module_id;
  return jsonb_build_object('message', 'Module deleted');
end $$;

create or replace function public.admin_reorder_modules(p_course_id uuid, p_ids uuid[]) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin();
  perform private.course_or_404(p_course_id);
  if coalesce(cardinality(p_ids), 0) <> (select count(distinct x) from unnest(p_ids) x)
     or (select coalesce(array_agg(id order by id), '{}') from public.course_modules where course_id = p_course_id)
        <> (select coalesce(array_agg(x order by x), '{}') from unnest(p_ids) x) then
    perform private.err('invalid_order', 'The list must contain every module of this course exactly once');
  end if;
  update public.course_modules m set position = o.ord - 1 from unnest(p_ids) with ordinality o(id, ord) where m.id = o.id;
  return jsonb_build_object('message', 'Modules reordered');
end $$;

-- ================================================================ lessons
create or replace function public.admin_create_lesson(p_module_id uuid, p_data jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare m public.course_modules; c public.courses; l public.lessons; r jsonb;
begin
  perform private.require_admin();
  m := private.module_or_404(p_module_id);
  select * into c from public.courses where id = m.course_id;
  insert into public.lessons (module_id, title, description, video_url, duration_seconds, is_free_preview, position)
  values (m.id, private.text_field(p_data ->> 'title', 'Title', 1, 200), coalesce(p_data ->> 'description', ''),
          nullif(trim(coalesce(p_data ->> 'video_url', '')), ''),
          case when p_data ? 'duration_seconds' and jsonb_typeof(p_data -> 'duration_seconds') <> 'null'
               then private.int_field(p_data -> 'duration_seconds', 'Duration', 0, 2147483647) else 0 end,
          coalesce((p_data ->> 'is_free_preview')::boolean, false),
          coalesce((select max(position) from public.lessons where module_id = m.id), 0) + 1)
  returning * into l;
  for r in select * from jsonb_array_elements(coalesce(p_data -> 'resources', '[]'::jsonb)) loop
    insert into public.lesson_resources (lesson_id, title, file_url)
    values (l.id, private.text_field(r ->> 'title', 'Resource title', 1, 200), private.text_field(r ->> 'file_url', 'Resource file', 1, 600));
  end loop;
  if c.is_published then
    perform private.notify_many(private.enrolled_ids(c.id), 'new_content', 'New lesson in ' || c.title, l.title);
  end if;
  return private.lesson_out(l);
end $$;

create or replace function public.admin_update_lesson(p_lesson_id uuid, p_data jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare l public.lessons; cur public.course_modules; target public.course_modules;
begin
  perform private.require_admin();
  select * into l from public.lessons where id = p_lesson_id;
  if not found then perform private.not_found('Lesson'); end if;
  if p_data ? 'module_id' and jsonb_typeof(p_data -> 'module_id') <> 'null' and (p_data ->> 'module_id')::uuid <> l.module_id then
    target := private.module_or_404((p_data ->> 'module_id')::uuid);
    select * into cur from public.course_modules where id = l.module_id;
    if target.course_id <> cur.course_id then
      perform private.err('invalid_module', 'Lessons can only be moved within the same course');
    end if;
    l.module_id := target.id;
    l.position := coalesce((select max(position) from public.lessons where module_id = target.id), 0) + 1;
  end if;
  if p_data ? 'title' and jsonb_typeof(p_data -> 'title') <> 'null' then l.title := private.text_field(p_data ->> 'title', 'Title', 1, 200); end if;
  if p_data ? 'description' and jsonb_typeof(p_data -> 'description') <> 'null' then l.description := p_data ->> 'description'; end if;
  if p_data ? 'video_url' then l.video_url := nullif(trim(coalesce(p_data ->> 'video_url', '')), ''); end if;
  if p_data ? 'duration_seconds' and jsonb_typeof(p_data -> 'duration_seconds') <> 'null' then
    l.duration_seconds := private.int_field(p_data -> 'duration_seconds', 'Duration', 0, 2147483647);
  end if;
  if p_data ? 'is_free_preview' and jsonb_typeof(p_data -> 'is_free_preview') <> 'null' then l.is_free_preview := (p_data ->> 'is_free_preview')::boolean; end if;
  update public.lessons set module_id = l.module_id, position = l.position, title = l.title, description = l.description,
    video_url = l.video_url, duration_seconds = l.duration_seconds, is_free_preview = l.is_free_preview
  where id = l.id returning * into l;
  return private.lesson_out(l);
end $$;

create or replace function public.admin_delete_lesson(p_lesson_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin();
  delete from public.lessons where id = p_lesson_id;
  if not found then perform private.not_found('Lesson'); end if;
  return jsonb_build_object('message', 'Lesson deleted');
end $$;

create or replace function public.admin_reorder_lessons(p_module_id uuid, p_ids uuid[]) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin();
  perform private.module_or_404(p_module_id);
  if coalesce(cardinality(p_ids), 0) <> (select count(distinct x) from unnest(p_ids) x)
     or (select coalesce(array_agg(id order by id), '{}') from public.lessons where module_id = p_module_id)
        <> (select coalesce(array_agg(x order by x), '{}') from unnest(p_ids) x) then
    perform private.err('invalid_order', 'The list must contain every lesson of this module exactly once');
  end if;
  update public.lessons l set position = o.ord - 1 from unnest(p_ids) with ordinality o(id, ord) where l.id = o.id;
  return jsonb_build_object('message', 'Lessons reordered');
end $$;

create or replace function public.admin_add_resource(p_lesson_id uuid, p_title text, p_file_url text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r public.lesson_resources;
begin
  perform private.require_admin();
  if not exists (select 1 from public.lessons where id = p_lesson_id) then perform private.not_found('Lesson'); end if;
  insert into public.lesson_resources (lesson_id, title, file_url)
  values (p_lesson_id, private.text_field(p_title, 'Title', 1, 200), private.text_field(p_file_url, 'File', 1, 600))
  returning * into r;
  return jsonb_build_object('id', r.id, 'title', r.title, 'file_url', r.file_url);
end $$;

create or replace function public.admin_delete_resource(p_resource_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin();
  delete from public.lesson_resources where id = p_resource_id;
  if not found then perform private.not_found('Resource'); end if;
  return jsonb_build_object('message', 'Resource deleted');
end $$;

-- ================================================================ live classes
create or replace function public.admin_live_classes(p_course_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  return coalesce((select jsonb_agg(private.live_out(lc, true) order by lc.starts_at desc) from public.live_classes lc
                   where p_course_id is null or lc.course_id = p_course_id), '[]'::jsonb);
end $$;

create or replace function public.admin_create_live(p_data jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c public.courses; lc public.live_classes; v_start timestamptz; v_end timestamptz;
begin
  perform private.require_admin();
  c := private.course_or_404((p_data ->> 'course_id')::uuid);
  v_start := private.ts_field(p_data -> 'starts_at', 'Start time');
  v_end := private.ts_field(p_data -> 'ends_at', 'End time');
  if v_end <= v_start then perform private.err('invalid_time', 'End time must be after start time'); end if;
  insert into public.live_classes (course_id, title, description, starts_at, ends_at, meeting_url, platform)
  values (c.id, private.text_field(p_data ->> 'title', 'Title', 3, 200), coalesce(p_data ->> 'description', ''), v_start, v_end,
          private.text_field(p_data ->> 'meeting_url', 'Meeting link', 5, 600),
          coalesce(private.text_field(p_data ->> 'platform', 'Platform', 0, 60, false), 'Zoom'))
  returning * into lc;
  perform private.notify_many(private.enrolled_ids(c.id), 'live_class', 'New live class: ' || lc.title,
                              c.title || ' — ' || private.fmt_ts(v_start) || ' UTC');
  return private.live_out(lc, true);
end $$;

create or replace function public.admin_update_live(p_live_id uuid, p_data jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare lc public.live_classes;
begin
  perform private.require_admin();
  select * into lc from public.live_classes where id = p_live_id;
  if not found then perform private.not_found('Live class'); end if;
  if p_data ? 'course_id' and jsonb_typeof(p_data -> 'course_id') <> 'null' then
    lc.course_id := (private.course_or_404((p_data ->> 'course_id')::uuid)).id;
  end if;
  if p_data ? 'title' and jsonb_typeof(p_data -> 'title') <> 'null' then lc.title := private.text_field(p_data ->> 'title', 'Title', 3, 200); end if;
  if p_data ? 'description' and jsonb_typeof(p_data -> 'description') <> 'null' then lc.description := p_data ->> 'description'; end if;
  if p_data ? 'starts_at' and jsonb_typeof(p_data -> 'starts_at') <> 'null' then lc.starts_at := private.ts_field(p_data -> 'starts_at', 'Start time'); end if;
  if p_data ? 'ends_at' and jsonb_typeof(p_data -> 'ends_at') <> 'null' then lc.ends_at := private.ts_field(p_data -> 'ends_at', 'End time'); end if;
  if p_data ? 'meeting_url' and jsonb_typeof(p_data -> 'meeting_url') <> 'null' then lc.meeting_url := private.text_field(p_data ->> 'meeting_url', 'Meeting link', 5, 600); end if;
  if p_data ? 'platform' and jsonb_typeof(p_data -> 'platform') <> 'null' then lc.platform := coalesce(private.text_field(p_data ->> 'platform', 'Platform', 0, 60, false), 'Zoom'); end if;
  if lc.ends_at <= lc.starts_at then perform private.err('invalid_time', 'End time must be after start time'); end if;
  update public.live_classes set course_id = lc.course_id, title = lc.title, description = lc.description, starts_at = lc.starts_at,
    ends_at = lc.ends_at, meeting_url = lc.meeting_url, platform = lc.platform
  where id = lc.id returning * into lc;
  return private.live_out(lc, true);
end $$;

create or replace function public.admin_delete_live(p_live_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin();
  delete from public.live_classes where id = p_live_id;
  if not found then perform private.not_found('Live class'); end if;
  return jsonb_build_object('message', 'Live class deleted');
end $$;

-- ================================================================ assignments and grading
create or replace function private.admin_assignment_out(a public.assignments) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', a.id, 'course_id', a.course_id, 'course_title', (select title from public.courses where id = a.course_id),
    'module_id', a.module_id, 'title', a.title, 'instructions', a.instructions, 'deadline', a.deadline, 'max_marks', a.max_marks,
    'allow_late', a.allow_late, 'attachment_url', a.attachment_url,
    'submission_count', (select count(*) from public.assignment_submissions where assignment_id = a.id),
    'pending_count', (select count(*) from public.assignment_submissions where assignment_id = a.id and status = 'submitted'))
$$;

create or replace function public.admin_assignments(p_course_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  return coalesce((select jsonb_agg(private.admin_assignment_out(a) order by a.deadline desc) from public.assignments a
                   where p_course_id is null or a.course_id = p_course_id), '[]'::jsonb);
end $$;

create or replace function private.assignment_or_404(p_id uuid) returns public.assignments
language plpgsql stable security definer set search_path = '' as $$
declare a public.assignments;
begin
  select * into a from public.assignments where id = p_id;
  if not found then perform private.not_found('Assignment'); end if;
  return a;
end $$;

create or replace function public.admin_get_assignment(p_assignment_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  return private.admin_assignment_out(private.assignment_or_404(p_assignment_id));
end $$;

create or replace function public.admin_create_assignment(p_data jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c public.courses; a public.assignments; v_module uuid := nullif(p_data ->> 'module_id', '')::uuid;
begin
  perform private.require_admin();
  c := private.course_or_404((p_data ->> 'course_id')::uuid);
  perform private.check_module(c.id, v_module);
  insert into public.assignments (course_id, module_id, title, instructions, deadline, max_marks, allow_late, attachment_url)
  values (c.id, v_module, private.text_field(p_data ->> 'title', 'Title', 3, 200), coalesce(p_data ->> 'instructions', ''),
          private.ts_field(p_data -> 'deadline', 'Deadline'),
          case when p_data ? 'max_marks' and jsonb_typeof(p_data -> 'max_marks') <> 'null' then private.int_field(p_data -> 'max_marks', 'Max marks', 1, 1000) else 100 end,
          coalesce((p_data ->> 'allow_late')::boolean, false), nullif(trim(coalesce(p_data ->> 'attachment_url', '')), ''))
  returning * into a;
  perform private.notify_many(private.enrolled_ids(c.id), 'new_content', 'New assignment: ' || a.title,
                              c.title || ' — due ' || private.fmt_ts(a.deadline) || ' UTC');
  return private.admin_assignment_out(a);
end $$;

create or replace function public.admin_update_assignment(p_assignment_id uuid, p_data jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare a public.assignments;
begin
  perform private.require_admin();
  a := private.assignment_or_404(p_assignment_id);
  if p_data ? 'module_id' then
    a.module_id := nullif(p_data ->> 'module_id', '')::uuid;
    perform private.check_module(a.course_id, a.module_id);
  end if;
  if p_data ? 'title' and jsonb_typeof(p_data -> 'title') <> 'null' then a.title := private.text_field(p_data ->> 'title', 'Title', 3, 200); end if;
  if p_data ? 'instructions' and jsonb_typeof(p_data -> 'instructions') <> 'null' then a.instructions := p_data ->> 'instructions'; end if;
  if p_data ? 'deadline' and jsonb_typeof(p_data -> 'deadline') <> 'null' then a.deadline := private.ts_field(p_data -> 'deadline', 'Deadline'); end if;
  if p_data ? 'max_marks' and jsonb_typeof(p_data -> 'max_marks') <> 'null' then a.max_marks := private.int_field(p_data -> 'max_marks', 'Max marks', 1, 1000); end if;
  if p_data ? 'allow_late' and jsonb_typeof(p_data -> 'allow_late') <> 'null' then a.allow_late := (p_data ->> 'allow_late')::boolean; end if;
  if p_data ? 'attachment_url' then a.attachment_url := nullif(trim(coalesce(p_data ->> 'attachment_url', '')), ''); end if;
  update public.assignments set module_id = a.module_id, title = a.title, instructions = a.instructions, deadline = a.deadline,
    max_marks = a.max_marks, allow_late = a.allow_late, attachment_url = a.attachment_url
  where id = a.id returning * into a;
  return private.admin_assignment_out(a);
end $$;

create or replace function public.admin_delete_assignment(p_assignment_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin();
  perform private.assignment_or_404(p_assignment_id);
  delete from public.assignments where id = p_assignment_id;
  return jsonb_build_object('message', 'Assignment deleted');
end $$;

create or replace function private.admin_submission_out(s public.assignment_submissions) returns jsonb
language sql stable security definer set search_path = '' as $$
  select private.submission_out(s) || jsonb_build_object(
    'student_id', s.user_id, 'student_name', u.name, 'student_email', u.email,
    'assignment_title', a.title, 'course_title', c.title, 'max_marks', a.max_marks)
  from public.profiles u, public.assignments a, public.courses c
  where u.id = s.user_id and a.id = s.assignment_id and c.id = a.course_id
$$;

create or replace function public.admin_submissions(
  p_assignment_id uuid default null, p_course_id uuid default null, p_status text default null, p_search text default null,
  p_page int default 1, p_page_size int default 20
) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_page int := greatest(coalesce(p_page, 1), 1);
  v_size int := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_like text := '%' || trim(coalesce(p_search, '')) || '%';
  v_total bigint; v_items jsonb;
begin
  perform private.require_admin();
  if p_status is not null and p_status not in ('submitted', 'reviewed') then
    perform private.err('validation_error', 'status must be submitted or reviewed');
  end if;
  with hits as (
    select s.* from public.assignment_submissions s
    join public.profiles u on u.id = s.user_id
    join public.assignments a on a.id = s.assignment_id
    where (p_assignment_id is null or s.assignment_id = p_assignment_id)
      and (p_course_id is null or a.course_id = p_course_id)
      and (p_status is null or s.status = p_status::public.submission_status)
      and (nullif(trim(p_search), '') is null or u.name ilike v_like or u.email ilike v_like)
  )
  select (select count(*) from hits),
         coalesce((select jsonb_agg(private.admin_submission_out(h) order by h.submitted_at desc)
                   from (select * from hits order by submitted_at desc offset (v_page - 1) * v_size limit v_size) h), '[]'::jsonb)
  into v_total, v_items;
  return jsonb_build_object('items', v_items) || private.page_meta(v_total, v_page, v_size);
end $$;

create or replace function private.submission_or_404(p_id uuid) returns public.assignment_submissions
language plpgsql stable security definer set search_path = '' as $$
declare s public.assignment_submissions;
begin
  select * into s from public.assignment_submissions where id = p_id;
  if not found then perform private.not_found('Submission'); end if;
  return s;
end $$;

create or replace function public.admin_get_submission(p_submission_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  return private.admin_submission_out(private.submission_or_404(p_submission_id));
end $$;

create or replace function public.admin_grade_submission(p_submission_id uuid, p_marks numeric, p_feedback text default '') returns jsonb
language plpgsql security definer set search_path = '' as $$
declare s public.assignment_submissions; a public.assignments;
begin
  perform private.require_admin();
  s := private.submission_or_404(p_submission_id);
  select * into a from public.assignments where id = s.assignment_id;
  if p_marks is null or p_marks < 0 then perform private.err('validation_error', 'Marks must be 0 or more'); end if;
  if p_marks > a.max_marks then perform private.err('marks_exceed_max', 'Marks cannot exceed the maximum of ' || a.max_marks); end if;
  update public.assignment_submissions set marks = p_marks, feedback = nullif(trim(coalesce(p_feedback, '')), ''),
    status = 'reviewed', reviewed_at = now()
  where id = s.id returning * into s;
  perform private.notify(s.user_id, 'assignment_graded', 'Assignment graded: ' || a.title,
                         'You scored ' || trim_scale(p_marks)::text || '/' || a.max_marks || '.');
  return private.admin_submission_out(s);
end $$;

create or replace function public.admin_mark_reviewed(p_submission_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare s public.assignment_submissions;
begin
  perform private.require_admin();
  s := private.submission_or_404(p_submission_id);
  update public.assignment_submissions set status = 'reviewed', reviewed_at = now() where id = s.id returning * into s;
  return private.admin_submission_out(s);
end $$;

-- ================================================================ quizzes
create or replace function private.quiz_admin_out(q public.quizzes) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', q.id, 'course_id', q.course_id, 'course_title', (select title from public.courses where id = q.course_id),
    'module_id', q.module_id, 'title', q.title, 'description', q.description, 'time_limit_minutes', q.time_limit_minutes,
    'show_results', q.show_results, 'is_published', q.is_published,
    'questions', coalesce((select jsonb_agg(jsonb_build_object('id', qq.id, 'text', qq.text, 'marks', qq.marks,
                   'options', coalesce((select jsonb_agg(jsonb_build_object('id', o.id, 'text', o.text, 'is_correct', o.is_correct) order by o.created_at, o.id)
                                        from public.quiz_options o where o.question_id = qq.id), '[]'::jsonb))
                 order by qq.position, qq.created_at) from public.quiz_questions qq where qq.quiz_id = q.id), '[]'::jsonb),
    'attempt_count', (select count(*) from public.quiz_attempts where quiz_id = q.id and submitted_at is not null))
$$;

-- Validates the question list (QuestionIn rules) and inserts it. Options keep their given order.
create or replace function private.build_questions(p_quiz_id uuid, p_questions jsonb) returns void
language plpgsql security definer set search_path = '' as $$
declare qj jsonb; oj jsonb; i int := 0; v_q uuid; v_n int; v_correct int; v_ts timestamptz := clock_timestamp();
begin
  if p_questions is null or jsonb_typeof(p_questions) = 'null' then return; end if;
  if jsonb_typeof(p_questions) <> 'array' then perform private.err('validation_error', 'Questions must be a list'); end if;
  for qj in select * from jsonb_array_elements(p_questions) loop
    i := i + 1;
    v_n := jsonb_array_length(coalesce(qj -> 'options', '[]'::jsonb));
    if v_n < 2 or v_n > 8 then perform private.err('validation_error', 'Question ' || i || ': add between 2 and 8 options'); end if;
    select count(*) into v_correct from jsonb_array_elements(qj -> 'options') o where coalesce((o ->> 'is_correct')::boolean, false);
    if v_correct <> 1 then perform private.err('validation_error', 'Question ' || i || ': each question must have exactly one correct option'); end if;
    insert into public.quiz_questions (quiz_id, text, marks, position)
    values (p_quiz_id, private.text_field(qj ->> 'text', 'Question ' || i, 1, 100000),
            case when qj ? 'marks' and jsonb_typeof(qj -> 'marks') <> 'null' then private.int_field(qj -> 'marks', 'Question ' || i || ' marks', 1, 100) else 1 end,
            i - 1)
    returning id into v_q;
    -- created_at steps forward per option so they read back in the order they were entered
    for oj in select * from jsonb_array_elements(qj -> 'options') loop
      v_ts := v_ts + interval '1 microsecond';
      insert into public.quiz_options (question_id, text, is_correct, created_at)
      values (v_q, private.text_field(oj ->> 'text', 'Question ' || i || ' option', 1, 500), coalesce((oj ->> 'is_correct')::boolean, false), v_ts);
    end loop;
  end loop;
end $$;

create or replace function public.admin_quizzes(p_course_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  return coalesce((select jsonb_agg(private.quiz_admin_out(q) order by q.created_at desc) from public.quizzes q
                   where p_course_id is null or q.course_id = p_course_id), '[]'::jsonb);
end $$;

create or replace function private.quiz_or_404(p_id uuid) returns public.quizzes
language plpgsql stable security definer set search_path = '' as $$
declare q public.quizzes;
begin
  select * into q from public.quizzes where id = p_id;
  if not found then perform private.not_found('Quiz'); end if;
  return q;
end $$;

create or replace function public.admin_quiz(p_quiz_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  return private.quiz_admin_out(private.quiz_or_404(p_quiz_id));
end $$;

create or replace function public.admin_create_quiz(p_data jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c public.courses; q public.quizzes; v_module uuid := nullif(p_data ->> 'module_id', '')::uuid;
begin
  perform private.require_admin();
  c := private.course_or_404((p_data ->> 'course_id')::uuid);
  perform private.check_module(c.id, v_module);
  insert into public.quizzes (course_id, module_id, title, description, time_limit_minutes, show_results, is_published)
  values (c.id, v_module, private.text_field(p_data ->> 'title', 'Title', 3, 200), coalesce(p_data ->> 'description', ''),
          case when p_data ? 'time_limit_minutes' and jsonb_typeof(p_data -> 'time_limit_minutes') <> 'null'
               then private.int_field(p_data -> 'time_limit_minutes', 'Time limit', 0, 600) else 0 end,
          coalesce((p_data ->> 'show_results')::boolean, true), coalesce((p_data ->> 'is_published')::boolean, true))
  returning * into q;
  perform private.build_questions(q.id, coalesce(p_data -> 'questions', '[]'::jsonb));
  if q.is_published then
    perform private.notify_many(private.enrolled_ids(c.id), 'quiz', 'New quiz available: ' || q.title, c.title);
  end if;
  return private.quiz_admin_out(q);
end $$;

create or replace function public.admin_update_quiz(p_quiz_id uuid, p_data jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare q public.quizzes;
begin
  perform private.require_admin();
  q := private.quiz_or_404(p_quiz_id);
  if p_data ? 'module_id' then
    q.module_id := nullif(p_data ->> 'module_id', '')::uuid;
    perform private.check_module(q.course_id, q.module_id);
  end if;
  if p_data ? 'title' and jsonb_typeof(p_data -> 'title') <> 'null' then q.title := private.text_field(p_data ->> 'title', 'Title', 3, 200); end if;
  if p_data ? 'description' and jsonb_typeof(p_data -> 'description') <> 'null' then q.description := p_data ->> 'description'; end if;
  if p_data ? 'time_limit_minutes' and jsonb_typeof(p_data -> 'time_limit_minutes') <> 'null' then
    q.time_limit_minutes := private.int_field(p_data -> 'time_limit_minutes', 'Time limit', 0, 600);
  end if;
  if p_data ? 'show_results' and jsonb_typeof(p_data -> 'show_results') <> 'null' then q.show_results := (p_data ->> 'show_results')::boolean; end if;
  if p_data ? 'is_published' and jsonb_typeof(p_data -> 'is_published') <> 'null' then q.is_published := (p_data ->> 'is_published')::boolean; end if;
  update public.quizzes set module_id = q.module_id, title = q.title, description = q.description,
    time_limit_minutes = q.time_limit_minutes, show_results = q.show_results, is_published = q.is_published
  where id = q.id returning * into q;
  if p_data ? 'questions' and jsonb_typeof(p_data -> 'questions') <> 'null' then
    -- Replace the question set. Past attempts keep their stored scores.
    delete from public.quiz_questions where quiz_id = q.id;
    perform private.build_questions(q.id, p_data -> 'questions');
  end if;
  return private.quiz_admin_out(q);
end $$;

create or replace function public.admin_delete_quiz(p_quiz_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin();
  perform private.quiz_or_404(p_quiz_id);
  delete from public.quizzes where id = p_quiz_id;
  return jsonb_build_object('message', 'Quiz deleted');
end $$;

create or replace function public.admin_quiz_attempts(p_quiz_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  perform private.quiz_or_404(p_quiz_id);
  return coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'student_id', a.user_id, 'student_name', u.name, 'student_email', u.email,
                     'score', a.score, 'total_marks', a.total_marks, 'submitted_at', a.submitted_at) order by a.submitted_at desc)
                   from public.quiz_attempts a join public.profiles u on u.id = a.user_id
                   where a.quiz_id = p_quiz_id and a.submitted_at is not null), '[]'::jsonb);
end $$;

-- ================================================================ students
create or replace function public.admin_students(p_search text default null, p_status text default null, p_page int default 1, p_page_size int default 20)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_page int := greatest(coalesce(p_page, 1), 1);
  v_size int := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_like text := '%' || trim(coalesce(p_search, '')) || '%';
  v_total bigint; v_items jsonb;
begin
  perform private.require_admin();
  if p_status is not null and p_status not in ('active', 'disabled') then
    perform private.err('validation_error', 'status must be active or disabled');
  end if;
  with hits as (
    select * from public.profiles u
    where u.role = 'student'
      and (nullif(trim(p_search), '') is null or u.name ilike v_like or u.email ilike v_like)
      and (p_status is null or u.is_active = (p_status = 'active'))
  )
  select (select count(*) from hits),
         coalesce((select jsonb_agg(jsonb_build_object('id', h.id, 'name', h.name, 'email', h.email, 'is_active', h.is_active,
                     'joined_at', h.created_at, 'enrolled_count', (select count(*) from public.enrollments e where e.user_id = h.id))
                     order by h.created_at desc)
                   from (select * from hits order by created_at desc offset (v_page - 1) * v_size limit v_size) h), '[]'::jsonb)
  into v_total, v_items;
  return jsonb_build_object('items', v_items) || private.page_meta(v_total, v_page, v_size);
end $$;

create or replace function private.student_or_404(p_id uuid) returns public.profiles
language plpgsql stable security definer set search_path = '' as $$
declare u public.profiles;
begin
  select * into u from public.profiles where id = p_id and role = 'student';
  if not found then perform private.not_found('Student'); end if;
  return u;
end $$;

create or replace function public.admin_student(p_student_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare u public.profiles;
begin
  perform private.require_admin();
  u := private.student_or_404(p_student_id);
  return jsonb_build_object(
    'id', u.id, 'name', u.name, 'email', u.email, 'is_active', u.is_active, 'joined_at', u.created_at,
    'courses', coalesce((select jsonb_agg(jsonb_build_object('course_id', e.course_id, 'title', c.title, 'enrolled_at', e.created_at,
                 'completed_at', e.completed_at, 'percentage', p -> 'percentage', 'completed_lessons', p -> 'completed_lessons',
                 'total_lessons', p -> 'total_lessons') order by e.created_at desc)
               from public.enrollments e join public.courses c on c.id = e.course_id
               cross join lateral (select private.progress_for(u.id, e.course_id) p) pr
               where e.user_id = u.id), '[]'::jsonb),
    'assignments', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'title', a.title, 'status', s.status, 'marks', s.marks::float8,
                 'max_marks', a.max_marks, 'submitted_at', s.submitted_at, 'is_late', s.is_late) order by s.submitted_at desc)
               from public.assignment_submissions s join public.assignments a on a.id = s.assignment_id where s.user_id = u.id), '[]'::jsonb),
    'quizzes', coalesce((select jsonb_agg(jsonb_build_object('id', qa.id, 'title', q.title, 'score', qa.score, 'total_marks', qa.total_marks,
                 'submitted_at', qa.submitted_at) order by qa.submitted_at desc)
               from public.quiz_attempts qa join public.quizzes q on q.id = qa.quiz_id
               where qa.user_id = u.id and qa.submitted_at is not null), '[]'::jsonb));
end $$;

create or replace function public.admin_set_student_status(p_student_id uuid, p_is_active boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin();
  perform private.student_or_404(p_student_id);
  update public.profiles set is_active = coalesce(p_is_active, true) where id = p_student_id;
  return jsonb_build_object('message', case when p_is_active then 'Account enabled' else 'Account disabled' end);
end $$;

-- ================================================================ payments, certificates, broadcast, settings
create or replace function public.admin_payments(p_status text default null, p_search text default null, p_page int default 1, p_page_size int default 20)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_page int := greatest(coalesce(p_page, 1), 1);
  v_size int := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_like text := '%' || trim(coalesce(p_search, '')) || '%';
  v_total bigint; v_items jsonb;
begin
  perform private.require_admin();
  if p_status is not null and p_status not in ('created', 'paid', 'failed') then
    perform private.err('validation_error', 'status must be created, paid or failed');
  end if;
  with hits as (
    select p.*, u.name as student_name, u.email as student_email, c.title as course_title
    from public.payments p join public.profiles u on u.id = p.user_id join public.courses c on c.id = p.course_id
    where (p_status is null or p.status = p_status::public.payment_status)
      and (nullif(trim(p_search), '') is null or u.name ilike v_like or u.email ilike v_like or c.title ilike v_like)
  )
  select (select count(*) from hits),
         coalesce((select jsonb_agg(jsonb_build_object('id', h.id, 'student_name', h.student_name, 'student_email', h.student_email,
                     'course_title', h.course_title, 'amount', h.amount::float8, 'currency', h.currency, 'status', h.status,
                     'razorpay_order_id', h.razorpay_order_id, 'razorpay_payment_id', h.razorpay_payment_id, 'created_at', h.created_at)
                     order by h.created_at desc)
                   from (select * from hits order by created_at desc offset (v_page - 1) * v_size limit v_size) h), '[]'::jsonb)
  into v_total, v_items;
  return jsonb_build_object('items', v_items) || private.page_meta(v_total, v_page, v_size)
    || jsonb_build_object('summary', jsonb_build_object(
         'revenue', (select coalesce(sum(amount), 0)::float8 from public.payments where status = 'paid'),
         'paid_count', (select count(*) from public.payments where status = 'paid')));
end $$;

create or replace function public.admin_certificates() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  return coalesce((select jsonb_agg(jsonb_build_object('id', ce.id, 'certificate_code', ce.certificate_code, 'student_name', u.name,
                     'student_email', u.email, 'course_title', c.title, 'issued_at', ce.issued_at) order by ce.issued_at desc)
                   from public.certificates ce join public.profiles u on u.id = ce.user_id join public.courses c on c.id = ce.course_id), '[]'::jsonb);
end $$;

create or replace function public.admin_broadcast(p_title text, p_message text default '', p_course_id uuid default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_ids uuid[];
begin
  perform private.require_admin();
  if p_course_id is not null then
    perform private.course_or_404(p_course_id);
    v_ids := private.enrolled_ids(p_course_id);
  else
    select coalesce(array_agg(id), '{}') into v_ids from public.profiles where role = 'student' and is_active;
  end if;
  if cardinality(v_ids) = 0 then perform private.err('no_recipients', 'There are no students to notify'); end if;
  perform private.notify_many(v_ids, 'announcement', private.text_field(p_title, 'Title', 3, 200),
                              coalesce(private.text_field(p_message, 'Message', 0, 2000, false), ''));
  return jsonb_build_object('message', 'Notification sent to ' || cardinality(v_ids) || ' student(s)');
end $$;

-- GET /api/admin/settings (the payment part comes from the payments Edge Function)
create or replace function public.admin_settings() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  return (select jsonb_build_object('platform_name', platform_name, 'storage_backend', 'supabase', 'max_upload_mb', max_upload_mb)
          from public.platform_settings);
end $$;

-- ================================================================ leads
create or replace function public.admin_demo_requests() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  return coalesce((select jsonb_agg(to_jsonb(d) - 'updated_at' order by d.created_at desc) from public.demo_requests d), '[]'::jsonb);
end $$;

create or replace function public.admin_toggle_demo_contacted(p_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare d public.demo_requests;
begin
  perform private.require_admin();
  update public.demo_requests set is_contacted = not is_contacted where id = p_id returning * into d;
  if not found then perform private.not_found('Demo request'); end if;
  return to_jsonb(d) - 'updated_at';
end $$;

create or replace function public.admin_contact_messages() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  return coalesce((select jsonb_agg(to_jsonb(m) - 'updated_at' order by m.created_at desc) from public.contact_messages m), '[]'::jsonb);
end $$;

create or replace function public.admin_toggle_contact_read(p_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare m public.contact_messages;
begin
  perform private.require_admin();
  update public.contact_messages set is_read = not is_read where id = p_id returning * into m;
  if not found then perform private.not_found('Message'); end if;
  return to_jsonb(m) - 'updated_at';
end $$;


-- ======== 20261030000005_storage_and_grants.sql ========
-- GTapex Academy on Supabase: file storage and API permissions.

-- ================================================================ storage buckets
-- Files are public by URL (like the old /uploads folder) but every file name is a random UUID, and nobody can list
-- a bucket's contents. Size limits: Supabase's free plan allows at most 50 MB per file.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('thumbnails', 'thumbnails', true, 5 * 1024 * 1024, array['image/png', 'image/jpeg', 'image/webp', 'image/gif']),
  ('course-files', 'course-files', true, 50 * 1024 * 1024, null),
  ('submissions', 'submissions', true, 25 * 1024 * 1024, null)
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Admins upload thumbnails, lesson videos, resources and assignment attachments.
create policy "admins upload course files" on storage.objects for insert to authenticated
  with check (bucket_id in ('thumbnails', 'course-files') and public.is_admin());
create policy "admins manage course files" on storage.objects for delete to authenticated
  using (bucket_id in ('thumbnails', 'course-files') and public.is_admin());

-- Students upload assignment files into their own folder only: submissions/<their user id>/<random>.<ext>
create policy "students upload own submissions" on storage.objects for insert to authenticated
  with check (bucket_id = 'submissions' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- ================================================================ API permissions
-- Nothing is callable unless listed here. The private schema is never exposed.
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'private')
  loop
    execute format('revoke all on function %s from public, anon, authenticated', f.sig);
  end loop;
end $$;

-- Signed-in users (each function checks student/admin itself).
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname not like 'payment\_%'
  loop
    execute format('grant execute on function %s to authenticated', f.sig);
  end loop;
end $$;

-- Visitors who are not signed in: the catalog and the two lead forms.
grant execute on function public.list_courses(text, text, text, text, boolean, int, int) to anon;
grant execute on function public.course_categories() to anon;
grant execute on function public.get_course(uuid) to anon;
grant execute on function public.book_demo(text, text, text, text, text, text) to anon;
grant execute on function public.send_contact_message(text, text, text, text, text) to anon;

-- The payments Edge Function (service role) only.
grant execute on function public.payment_prepare(uuid, uuid) to service_role;
grant execute on function public.payment_record_order(uuid, uuid, numeric, text) to service_role;
grant execute on function public.payment_mark_paid(text, text, text, uuid) to service_role;
grant execute on function public.payment_mark_failed(text, uuid) to service_role;

-- Functions inside policies and SECURITY DEFINER bodies run as their owner, so the API roles need nothing in private.


-- ======== 20261102000006_offline_price.sql ========
-- Online and offline pricing: `price` is the online price (what Razorpay charges); `offline_price` is the classroom price.

alter table public.courses add column offline_price numeric(10, 2) check (offline_price is null or offline_price >= 0);

create or replace function private.course_card(c public.courses) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', c.id, 'title', c.title, 'slug', c.slug, 'short_description', c.short_description, 'category', c.category,
    'difficulty', c.difficulty, 'price', c.price::float8, 'offline_price', c.offline_price::float8, 'thumbnail_url', c.thumbnail_url, 'is_published', c.is_published,
    'lesson_count', (select count(*) from public.lessons l join public.course_modules m on m.id = l.module_id where m.course_id = c.id),
    'duration_seconds', (select coalesce(sum(l.duration_seconds), 0) from public.lessons l join public.course_modules m on m.id = l.module_id where m.course_id = c.id),
    'enrolled_count', (select count(*) from public.enrollments e where e.course_id = c.id))
$$;

create or replace function private.apply_course_fields(c public.courses, p_data jsonb) returns public.courses
language plpgsql stable set search_path = '' as $$
begin
  if p_data ? 'title' then c.title := private.text_field(p_data ->> 'title', 'Title', 3, 200); end if;
  if p_data ? 'short_description' then c.short_description := coalesce(private.text_field(p_data ->> 'short_description', 'Short description', 0, 300, false), ''); end if;
  if p_data ? 'description' then c.description := coalesce(p_data ->> 'description', ''); end if;
  if p_data ? 'category' then c.category := coalesce(private.text_field(p_data ->> 'category', 'Category', 0, 80, false), 'General'); end if;
  if p_data ? 'difficulty' and jsonb_typeof(p_data -> 'difficulty') <> 'null' then
    if (p_data ->> 'difficulty') not in ('beginner', 'intermediate', 'advanced') then
      perform private.err('validation_error', 'Difficulty must be beginner, intermediate or advanced');
    end if;
    c.difficulty := (p_data ->> 'difficulty')::public.difficulty;
  end if;
  if p_data ? 'price' and jsonb_typeof(p_data -> 'price') <> 'null' then
    if jsonb_typeof(p_data -> 'price') <> 'number' or (p_data ->> 'price')::numeric < 0 then
      perform private.err('validation_error', 'Price must be 0 or more');
    end if;
    c.price := (p_data ->> 'price')::numeric;
  end if;
  if p_data ? 'offline_price' then  -- null or missing value = no offline option
    if jsonb_typeof(p_data -> 'offline_price') = 'null' then
      c.offline_price := null;
    elsif jsonb_typeof(p_data -> 'offline_price') <> 'number' or (p_data ->> 'offline_price')::numeric < 0 then
      perform private.err('validation_error', 'Offline price must be 0 or more');
    else
      c.offline_price := (p_data ->> 'offline_price')::numeric;
    end if;
  end if;
  if p_data ? 'thumbnail_url' then c.thumbnail_url := nullif(trim(coalesce(p_data ->> 'thumbnail_url', '')), ''); end if;
  if p_data ? 'features' and jsonb_typeof(p_data -> 'features') <> 'null' then
    if jsonb_typeof(p_data -> 'features') <> 'array' then perform private.err('validation_error', 'Features must be a list'); end if;
    c.features := p_data -> 'features';
  end if;
  if p_data ? 'is_published' and jsonb_typeof(p_data -> 'is_published') <> 'null' then c.is_published := (p_data ->> 'is_published')::boolean; end if;
  return c;
end $$;

create or replace function public.admin_create_course(p_data jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c public.courses;
begin
  perform private.require_admin();
  if not (p_data ? 'title') then perform private.err('validation_error', 'Title is required'); end if;
  c.id := gen_random_uuid(); c.short_description := ''; c.description := ''; c.category := 'General'; c.difficulty := 'beginner';
  c.price := 0; c.features := '[]'::jsonb; c.is_published := false;
  c := private.apply_course_fields(c, p_data);
  c.slug := private.unique_slug(c.title);
  insert into public.courses (id, title, slug, short_description, description, category, difficulty, price, offline_price, thumbnail_url, is_published, features)
  values (c.id, c.title, c.slug, c.short_description, c.description, c.category, c.difficulty, c.price, c.offline_price, c.thumbnail_url, c.is_published, c.features)
  returning * into c;
  return private.admin_course_detail(c);
end $$;

create or replace function public.admin_update_course(p_course_id uuid, p_data jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c public.courses;
begin
  perform private.require_admin();
  c := private.apply_course_fields(private.course_or_404(p_course_id), p_data);
  if p_data ? 'title' then c.slug := private.unique_slug(c.title, c.id); end if;
  update public.courses set title = c.title, slug = c.slug, short_description = c.short_description, description = c.description,
    category = c.category, difficulty = c.difficulty, price = c.price, offline_price = c.offline_price, thumbnail_url = c.thumbnail_url,
    is_published = c.is_published, features = c.features
  where id = c.id returning * into c;
  return private.admin_course_detail(c);
end $$;


-- ======== 20261104000007_course_length_offline_only.sql ========
-- Course length, and courses sold only in the classroom.
-- duration_months: how long the course runs; null = not shown.
-- offline_only: no online purchase. `price` then mirrors offline_price, so these courses are never treated as free.

alter table public.courses add column duration_months smallint check (duration_months between 1 and 60);
alter table public.courses add column offline_only boolean not null default false;
alter table public.courses add constraint courses_offline_only_priced
  check (not offline_only or (offline_price > 0 and price = offline_price));

create or replace function private.course_card(c public.courses) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', c.id, 'title', c.title, 'slug', c.slug, 'short_description', c.short_description, 'category', c.category,
    'difficulty', c.difficulty, 'price', c.price::float8, 'offline_price', c.offline_price::float8, 'duration_months', c.duration_months, 'offline_only', c.offline_only, 'thumbnail_url', c.thumbnail_url, 'is_published', c.is_published,
    'lesson_count', (select count(*) from public.lessons l join public.course_modules m on m.id = l.module_id where m.course_id = c.id),
    'duration_seconds', (select coalesce(sum(l.duration_seconds), 0) from public.lessons l join public.course_modules m on m.id = l.module_id where m.course_id = c.id),
    'enrolled_count', (select count(*) from public.enrollments e where e.course_id = c.id))
$$;

create or replace function private.apply_course_fields(c public.courses, p_data jsonb) returns public.courses
language plpgsql stable set search_path = '' as $$
begin
  if p_data ? 'title' then c.title := private.text_field(p_data ->> 'title', 'Title', 3, 200); end if;
  if p_data ? 'short_description' then c.short_description := coalesce(private.text_field(p_data ->> 'short_description', 'Short description', 0, 300, false), ''); end if;
  if p_data ? 'description' then c.description := coalesce(p_data ->> 'description', ''); end if;
  if p_data ? 'category' then c.category := coalesce(private.text_field(p_data ->> 'category', 'Category', 0, 80, false), 'General'); end if;
  if p_data ? 'difficulty' and jsonb_typeof(p_data -> 'difficulty') <> 'null' then
    if (p_data ->> 'difficulty') not in ('beginner', 'intermediate', 'advanced') then
      perform private.err('validation_error', 'Difficulty must be beginner, intermediate or advanced');
    end if;
    c.difficulty := (p_data ->> 'difficulty')::public.difficulty;
  end if;
  if p_data ? 'price' and jsonb_typeof(p_data -> 'price') <> 'null' then
    if jsonb_typeof(p_data -> 'price') <> 'number' or (p_data ->> 'price')::numeric < 0 then
      perform private.err('validation_error', 'Price must be 0 or more');
    end if;
    c.price := (p_data ->> 'price')::numeric;
  end if;
  if p_data ? 'offline_price' then  -- null or missing value = no offline option
    if jsonb_typeof(p_data -> 'offline_price') = 'null' then
      c.offline_price := null;
    elsif jsonb_typeof(p_data -> 'offline_price') <> 'number' or (p_data ->> 'offline_price')::numeric < 0 then
      perform private.err('validation_error', 'Offline price must be 0 or more');
    else
      c.offline_price := (p_data ->> 'offline_price')::numeric;
    end if;
  end if;
  if p_data ? 'duration_months' then  -- null = no length shown
    if jsonb_typeof(p_data -> 'duration_months') = 'null' then
      c.duration_months := null;
    elsif jsonb_typeof(p_data -> 'duration_months') <> 'number' or (p_data ->> 'duration_months') !~ '^[0-9]+$'
          or (p_data ->> 'duration_months')::numeric not between 1 and 60 then
      perform private.err('validation_error', 'Duration must be a whole number of months from 1 to 60');
    else
      c.duration_months := (p_data ->> 'duration_months')::smallint;
    end if;
  end if;
  if p_data ? 'offline_only' and jsonb_typeof(p_data -> 'offline_only') <> 'null' then c.offline_only := (p_data ->> 'offline_only')::boolean; end if;
  if p_data ? 'thumbnail_url' then c.thumbnail_url := nullif(trim(coalesce(p_data ->> 'thumbnail_url', '')), ''); end if;
  if p_data ? 'features' and jsonb_typeof(p_data -> 'features') <> 'null' then
    if jsonb_typeof(p_data -> 'features') <> 'array' then perform private.err('validation_error', 'Features must be a list'); end if;
    c.features := p_data -> 'features';
  end if;
  if p_data ? 'is_published' and jsonb_typeof(p_data -> 'is_published') <> 'null' then c.is_published := (p_data ->> 'is_published')::boolean; end if;
  -- An offline-only course always carries its classroom price in `price` too, so it can never count as free.
  if c.offline_only then
    if coalesce(c.offline_price, 0) <= 0 then perform private.err('validation_error', 'An offline-only course needs an offline price'); end if;
    c.price := c.offline_price;
  end if;
  return c;
end $$;

create or replace function public.admin_create_course(p_data jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c public.courses;
begin
  perform private.require_admin();
  if not (p_data ? 'title') then perform private.err('validation_error', 'Title is required'); end if;
  c.id := gen_random_uuid(); c.short_description := ''; c.description := ''; c.category := 'General'; c.difficulty := 'beginner';
  c.price := 0; c.offline_only := false; c.features := '[]'::jsonb; c.is_published := false;
  c := private.apply_course_fields(c, p_data);
  c.slug := private.unique_slug(c.title);
  insert into public.courses (id, title, slug, short_description, description, category, difficulty, price, offline_price, duration_months, offline_only, thumbnail_url, is_published, features)
  values (c.id, c.title, c.slug, c.short_description, c.description, c.category, c.difficulty, c.price, c.offline_price, c.duration_months, c.offline_only, c.thumbnail_url, c.is_published, c.features)
  returning * into c;
  return private.admin_course_detail(c);
end $$;

create or replace function public.admin_update_course(p_course_id uuid, p_data jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c public.courses;
begin
  perform private.require_admin();
  c := private.apply_course_fields(private.course_or_404(p_course_id), p_data);
  if p_data ? 'title' then c.slug := private.unique_slug(c.title, c.id); end if;
  update public.courses set title = c.title, slug = c.slug, short_description = c.short_description, description = c.description,
    category = c.category, difficulty = c.difficulty, price = c.price, offline_price = c.offline_price, duration_months = c.duration_months, offline_only = c.offline_only, thumbnail_url = c.thumbnail_url,
    is_published = c.is_published, features = c.features
  where id = c.id returning * into c;
  return private.admin_course_detail(c);
end $$;

-- Offline-only courses cannot be bought online.
create or replace function public.payment_prepare(p_user_id uuid, p_course_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare u public.profiles; c public.courses;
begin
  select * into u from public.profiles where id = p_user_id;
  if not found then perform private.err('invalid_token', 'User no longer exists'); end if;
  if not u.is_active then perform private.err('account_disabled', 'Your account has been disabled. Contact support.'); end if;
  if u.role <> 'student' then perform private.err('forbidden', 'This area is for students only'); end if;
  select * into c from public.courses where id = p_course_id;
  if not found or not c.is_published then perform private.not_found('Course'); end if;
  if private.is_enrolled(u.id, c.id) then perform private.err('already_enrolled', 'You are already enrolled in this course'); end if;
  if c.offline_only then perform private.err('offline_only', 'This programme is only available offline. Book a free demo to join.'); end if;
  if c.price <= 0 then perform private.err('free_course', 'This course is free. Use the enroll button.'); end if;
  return jsonb_build_object('course_id', c.id, 'title', c.title, 'price', c.price::float8);
end $$;


-- ======== 20261104000008_offline_checkout.sql ========
-- Buying a classroom place online. `learning_mode` on a payment says which price was charged.
-- The amount always comes from the database, never from the browser.

alter table public.payments add column learning_mode text not null default 'online' check (learning_mode in ('online', 'offline'));

drop function public.payment_prepare(uuid, uuid);
drop function public.payment_record_order(uuid, uuid, numeric, text);

create or replace function public.payment_prepare(p_user_id uuid, p_course_id uuid, p_mode text default 'online') returns jsonb
language plpgsql security definer set search_path = '' as $$
declare u public.profiles; c public.courses; v_amount numeric;
begin
  select * into u from public.profiles where id = p_user_id;
  if not found then perform private.err('invalid_token', 'User no longer exists'); end if;
  if not u.is_active then perform private.err('account_disabled', 'Your account has been disabled. Contact support.'); end if;
  if u.role <> 'student' then perform private.err('forbidden', 'This area is for students only'); end if;
  select * into c from public.courses where id = p_course_id;
  if not found or not c.is_published then perform private.not_found('Course'); end if;
  if private.is_enrolled(u.id, c.id) then perform private.err('already_enrolled', 'You are already enrolled in this course'); end if;
  if coalesce(p_mode, '') = 'online' then
    if c.offline_only then perform private.err('offline_only', 'This programme is only available offline.'); end if;
    if c.price <= 0 then perform private.err('free_course', 'This course is free. Use the enroll button.'); end if;
    v_amount := c.price;
  elsif p_mode = 'offline' then
    if coalesce(c.offline_price, 0) <= 0 then perform private.err('offline_unavailable', 'This course cannot be bought for offline learning. Please contact us.'); end if;
    v_amount := c.offline_price;
  else
    perform private.err('validation_error', 'Choose online or offline');
  end if;
  return jsonb_build_object('course_id', c.id, 'title', c.title, 'price', v_amount::float8, 'learning_mode', p_mode);
end $$;

create or replace function public.payment_record_order(p_user_id uuid, p_course_id uuid, p_amount numeric, p_order_id text, p_mode text default 'online')
returns void language sql security definer set search_path = '' as $$
  insert into public.payments (user_id, course_id, amount, currency, status, razorpay_order_id, learning_mode)
  values (p_user_id, p_course_id, p_amount, 'INR', 'created', p_order_id, p_mode)
$$;

revoke all on function public.payment_prepare(uuid, uuid, text) from public, anon, authenticated;
revoke all on function public.payment_record_order(uuid, uuid, numeric, text, text) from public, anon, authenticated;
grant execute on function public.payment_prepare(uuid, uuid, text) to service_role;
grant execute on function public.payment_record_order(uuid, uuid, numeric, text, text) to service_role;

-- The admin payments list shows which price was paid.
create or replace function public.admin_payments(p_status text default null, p_search text default null, p_page int default 1, p_page_size int default 20)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_page int := greatest(coalesce(p_page, 1), 1);
  v_size int := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_like text := '%' || trim(coalesce(p_search, '')) || '%';
  v_total bigint; v_items jsonb;
begin
  perform private.require_admin();
  if p_status is not null and p_status not in ('created', 'paid', 'failed') then
    perform private.err('validation_error', 'status must be created, paid or failed');
  end if;
  with hits as (
    select p.*, u.name as student_name, u.email as student_email, c.title as course_title
    from public.payments p join public.profiles u on u.id = p.user_id join public.courses c on c.id = p.course_id
    where (p_status is null or p.status = p_status::public.payment_status)
      and (nullif(trim(p_search), '') is null or u.name ilike v_like or u.email ilike v_like or c.title ilike v_like)
  )
  select (select count(*) from hits),
         coalesce((select jsonb_agg(jsonb_build_object('id', h.id, 'student_name', h.student_name, 'student_email', h.student_email,
                     'course_title', h.course_title, 'learning_mode', h.learning_mode, 'amount', h.amount::float8, 'currency', h.currency, 'status', h.status,
                     'razorpay_order_id', h.razorpay_order_id, 'razorpay_payment_id', h.razorpay_payment_id, 'created_at', h.created_at)
                     order by h.created_at desc)
                   from (select * from hits order by created_at desc offset (v_page - 1) * v_size limit v_size) h), '[]'::jsonb)
  into v_total, v_items;
  return jsonb_build_object('items', v_items) || private.page_meta(v_total, v_page, v_size)
    || jsonb_build_object('summary', jsonb_build_object(
         'revenue', (select coalesce(sum(amount), 0)::float8 from public.payments where status = 'paid'),
         'paid_count', (select count(*) from public.payments where status = 'paid')));
end $$;


-- ======== 20261104000009_buyer_type.sql ========
-- Spotting online and offline buyers: a filter and counts on the payments list, and the type on each student's courses.

drop function public.admin_payments(text, text, int, int);
create or replace function public.admin_payments(p_status text default null, p_search text default null, p_page int default 1, p_page_size int default 20, p_mode text default null)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_page int := greatest(coalesce(p_page, 1), 1);
  v_size int := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_like text := '%' || trim(coalesce(p_search, '')) || '%';
  v_total bigint; v_items jsonb;
begin
  perform private.require_admin();
  if p_status is not null and p_status not in ('created', 'paid', 'failed') then
    perform private.err('validation_error', 'status must be created, paid or failed');
  end if;
  if p_mode is not null and p_mode not in ('online', 'offline') then
    perform private.err('validation_error', 'type must be online or offline');
  end if;
  with hits as (
    select p.*, u.name as student_name, u.email as student_email, c.title as course_title
    from public.payments p join public.profiles u on u.id = p.user_id join public.courses c on c.id = p.course_id
    where (p_status is null or p.status = p_status::public.payment_status)
      and (p_mode is null or p.learning_mode = p_mode)
      and (nullif(trim(p_search), '') is null or u.name ilike v_like or u.email ilike v_like or c.title ilike v_like)
  )
  select (select count(*) from hits),
         coalesce((select jsonb_agg(jsonb_build_object('id', h.id, 'student_name', h.student_name, 'student_email', h.student_email,
                     'course_title', h.course_title, 'learning_mode', h.learning_mode, 'amount', h.amount::float8, 'currency', h.currency, 'status', h.status,
                     'razorpay_order_id', h.razorpay_order_id, 'razorpay_payment_id', h.razorpay_payment_id, 'created_at', h.created_at)
                     order by h.created_at desc)
                   from (select * from hits order by created_at desc offset (v_page - 1) * v_size limit v_size) h), '[]'::jsonb)
  into v_total, v_items;
  return jsonb_build_object('items', v_items) || private.page_meta(v_total, v_page, v_size)
    || jsonb_build_object('summary', jsonb_build_object(
         'revenue', (select coalesce(sum(amount), 0)::float8 from public.payments where status = 'paid'),
         'paid_count', (select count(*) from public.payments where status = 'paid'),
         'online_count', (select count(*) from public.payments where status = 'paid' and learning_mode = 'online'),
         'offline_count', (select count(*) from public.payments where status = 'paid' and learning_mode = 'offline')));
end $$;

revoke all on function public.admin_payments(text, text, int, int, text) from public, anon, authenticated;
grant execute on function public.admin_payments(text, text, int, int, text) to authenticated;

create or replace function public.admin_student(p_student_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare u public.profiles;
begin
  perform private.require_admin();
  u := private.student_or_404(p_student_id);
  return jsonb_build_object(
    'id', u.id, 'name', u.name, 'email', u.email, 'is_active', u.is_active, 'joined_at', u.created_at,
    'courses', coalesce((select jsonb_agg(jsonb_build_object('course_id', e.course_id, 'title', c.title, 'enrolled_at', e.created_at,
                 'completed_at', e.completed_at, 'percentage', p -> 'percentage', 'completed_lessons', p -> 'completed_lessons',
                 'total_lessons', p -> 'total_lessons',
                 'learning_mode', (select pay.learning_mode from public.payments pay
                                   where pay.user_id = u.id and pay.course_id = e.course_id and pay.status = 'paid'
                                   order by pay.created_at desc limit 1)) order by e.created_at desc)
               from public.enrollments e join public.courses c on c.id = e.course_id
               cross join lateral (select private.progress_for(u.id, e.course_id) p) pr
               where e.user_id = u.id), '[]'::jsonb),
    'assignments', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'title', a.title, 'status', s.status, 'marks', s.marks::float8,
                 'max_marks', a.max_marks, 'submitted_at', s.submitted_at, 'is_late', s.is_late) order by s.submitted_at desc)
               from public.assignment_submissions s join public.assignments a on a.id = s.assignment_id where s.user_id = u.id), '[]'::jsonb),
    'quizzes', coalesce((select jsonb_agg(jsonb_build_object('id', qa.id, 'title', q.title, 'score', qa.score, 'total_marks', qa.total_marks,
                 'submitted_at', qa.submitted_at) order by qa.submitted_at desc)
               from public.quiz_attempts qa join public.quizzes q on q.id = qa.quiz_id
               where qa.user_id = u.id and qa.submitted_at is not null), '[]'::jsonb));
end $$;


-- ======== 20261104000010_chat_enquiries.sql ========
-- Enquiries from Krish, the chat assistant. They appear in Admin > Contact messages.
-- A visitor may leave only a phone number, so a contact message no longer has to have an email address.
alter table public.contact_messages alter column email drop not null;

create or replace function public.send_chat_enquiry(p_name text, p_contact text, p_interest text default null, p_message text default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_contact text := trim(coalesce(p_contact, ''));
  v_is_email boolean := v_contact ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$';
  v_interest text := private.text_field(p_interest, 'Interest', 0, 80, false);
begin
  if not v_is_email and v_contact !~ '^\+?[0-9 -]{7,16}$' then
    perform private.err('validation_error', 'Enter a valid phone number or email address');
  end if;
  insert into public.contact_messages (name, email, phone, subject, message)
  values (
    private.text_field(p_name, 'Name', 2, 120),
    case when v_is_email then private.valid_email(v_contact) end,
    case when not v_is_email then v_contact end,
    'Krish chat: ' || coalesce(v_interest, 'Not sure yet'),
    coalesce(private.text_field(p_message, 'Message', 0, 1000, false), 'No extra details given.'));
  return jsonb_build_object('message', 'Thanks! Our team will reach out within one working day.');
end $$;

revoke all on function public.send_chat_enquiry(text, text, text, text) from public, anon, authenticated;
grant execute on function public.send_chat_enquiry(text, text, text, text) to anon, authenticated;


-- ======== 20261104000011_hardening.sql ========
-- Security and speed fixes from the code audit. Adds and tightens only: no table, column or record is removed.

-- ================================================================ 1. Assignment file links
-- The old check accepted any text containing the expected path, including a javascript: link that would run when an
-- admin opened the submission. The link must now be a real file in this student's own folder.
create or replace function public.submit_assignment(p_assignment_id uuid, p_text_answer text default null, p_file_url text default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  u public.profiles := private.require_student();
  a public.assignments := private.my_assignment(u, p_assignment_id);
  s public.assignment_submissions;
  v_late boolean := now() > a.deadline;
  v_text text := nullif(trim(coalesce(p_text_answer, '')), '');
  v_file text := nullif(trim(coalesce(p_file_url, '')), '');
begin
  if v_late and not a.allow_late then perform private.err('deadline_passed', 'The deadline for this assignment has passed'); end if;
  if v_file is not null and v_file !~ ('^https://[a-z0-9-]+\.supabase\.(co|in)/storage/v1/object/public/submissions/' || u.id::text || '/[A-Za-z0-9._-]+$') then
    perform private.err('invalid_file', 'Upload the file again and resubmit');
  end if;
  select * into s from public.assignment_submissions where assignment_id = a.id and user_id = u.id;
  if v_text is null and v_file is null and (s.id is null or s.file_url is null) then
    perform private.err('empty_submission', 'Add a text answer or upload a file');
  end if;
  if s.status = 'reviewed' then
    perform private.err('already_reviewed', 'This submission has already been graded and can''t be changed');
  end if;

  insert into public.assignment_submissions (assignment_id, user_id, text_answer, file_url, submitted_at, is_late, status)
  values (a.id, u.id, v_text, v_file, now(), v_late, 'submitted')
  on conflict (assignment_id, user_id) do update set
    text_answer = excluded.text_answer,
    file_url = coalesce(excluded.file_url, public.assignment_submissions.file_url),
    submitted_at = excluded.submitted_at, is_late = excluded.is_late, status = 'submitted';

  perform private.notify_admins('submission', 'New assignment submission', u.name || ' submitted ''' || a.title || '''');
  return private.assignment_out(a, u.id);
end $$;

-- ================================================================ 2. Limits on the public forms
-- Anyone can call these three without signing in, so one person could fill the admin inbox, or run up WhatsApp alert
-- costs. Each visitor address gets 10 of each per hour. Only a hash of the address is kept, for one day.
create table if not exists private.rate_limits (
  key text not null,
  hit_at timestamptz not null default now()
);
create index if not exists rate_limits_key_idx on private.rate_limits (key, hit_at);
create index if not exists rate_limits_hit_idx on private.rate_limits (hit_at);
revoke all on private.rate_limits from public, anon, authenticated;

create or replace function private.throttle(p_action text, p_limit int, p_window interval) returns void
language plpgsql set search_path = '' as $$
declare
  v_headers jsonb;
  v_ip text;
  v_key text;
begin
  begin
    v_headers := nullif(current_setting('request.headers', true), '')::jsonb;
  exception when others then
    v_headers := null;
  end;
  v_ip := nullif(trim(coalesce(v_headers ->> 'cf-connecting-ip', split_part(v_headers ->> 'x-forwarded-for', ',', 1))), '');
  if v_ip is null then return; end if;  -- Not a website request (SQL Editor, tests).
  v_key := md5(p_action || ':' || v_ip);
  delete from private.rate_limits where hit_at < now() - interval '1 day';
  if (select count(*) from private.rate_limits where key = v_key and hit_at > now() - p_window) >= p_limit then
    perform private.err('rate_limited', 'Too many requests. Please try again later, or call us.');
  end if;
  insert into private.rate_limits (key) values (v_key);
end $$;
revoke all on function private.throttle(text, int, interval) from public, anon, authenticated;

create or replace function public.book_demo(
  p_name text, p_email text, p_phone text, p_course_interest text default null, p_preferred_time text default null, p_message text default null
) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform private.throttle('demo', 10, interval '1 hour');
  insert into public.demo_requests (name, email, phone, course_interest, preferred_time, message)
  values (private.text_field(p_name, 'Name', 2, 120), private.valid_email(p_email), private.text_field(p_phone, 'Phone', 7, 32),
          private.text_field(p_course_interest, 'Course interest', 0, 200, false),
          private.text_field(p_preferred_time, 'Preferred time', 0, 80, false),
          private.text_field(p_message, 'Message', 0, 1000, false));
  return jsonb_build_object('message', 'Thanks! Our team will contact you shortly to confirm your free demo.');
end $$;

create or replace function public.send_contact_message(
  p_name text, p_email text, p_subject text, p_message text, p_phone text default null
) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform private.throttle('contact', 10, interval '1 hour');
  insert into public.contact_messages (name, email, phone, subject, message)
  values (private.text_field(p_name, 'Name', 2, 120), private.valid_email(p_email), private.text_field(p_phone, 'Phone', 0, 32, false),
          private.text_field(p_subject, 'Subject', 2, 200), private.text_field(p_message, 'Message', 5, 3000));
  return jsonb_build_object('message', 'Thanks for reaching out! We''ll get back to you within one working day.');
end $$;

-- Krish's enquiries. A visitor may leave only a phone number, so a contact message doesn't need an email address.
alter table public.contact_messages alter column email drop not null;

create or replace function public.send_chat_enquiry(p_name text, p_contact text, p_interest text default null, p_message text default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_contact text := trim(coalesce(p_contact, ''));
  v_is_email boolean := v_contact ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$';
  v_interest text := private.text_field(p_interest, 'Interest', 0, 80, false);
begin
  perform private.throttle('chat', 10, interval '1 hour');
  if not v_is_email and v_contact !~ '^\+?[0-9 -]{7,16}$' then
    perform private.err('validation_error', 'Enter a valid phone number or email address');
  end if;
  insert into public.contact_messages (name, email, phone, subject, message)
  values (
    private.text_field(p_name, 'Name', 2, 120),
    case when v_is_email then private.valid_email(v_contact) end,
    case when not v_is_email then v_contact end,
    'Krish chat: ' || coalesce(v_interest, 'Not sure yet'),
    coalesce(private.text_field(p_message, 'Message', 0, 1000, false), 'No extra details given.'));
  return jsonb_build_object('message', 'Thanks! Our team will reach out within one working day.');
end $$;

revoke all on function public.send_chat_enquiry(text, text, text, text) from public, anon, authenticated;
grant execute on function public.send_chat_enquiry(text, text, text, text) to anon, authenticated;

-- ================================================================ 3. Student uploads
-- The browser only offers certain file types, but that check can be bypassed. Storage now enforces the same list, so
-- a student can't upload a web page or script to a public link.
update storage.buckets set allowed_mime_types = array[
  'application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-powerpoint', 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'application/vnd.ms-excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'text/plain', 'application/zip', 'application/x-zip-compressed', 'image/png', 'image/jpeg', 'application/octet-stream'
] where id = 'submissions';

-- ================================================================ 4. Indexes
-- Foreign keys with no index slow down deletes and joins; the others match how the lists are read.
create index if not exists quizzes_module_idx on public.quizzes (module_id);
create index if not exists quiz_answers_question_idx on public.quiz_answers (question_id);
create index if not exists quiz_answers_option_idx on public.quiz_answers (option_id);
create index if not exists notifications_user_created_idx on public.notifications (user_id, created_at desc);
create index if not exists payments_created_idx on public.payments (created_at desc);
create index if not exists contact_messages_created_idx on public.contact_messages (created_at desc);
create index if not exists demo_requests_created_idx on public.demo_requests (created_at desc);


-- ======== 20261105000012_profile_after_verification.sql ========
-- Student profiles are created when the email is verified, not at sign-up, so unverified sign-ups stay out of the app.
-- Supabase Auth still has to hold the email and hashed password in auth.users until the link is clicked.
create or replace function private.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.email_confirmed_at is null then return new; end if;
  insert into public.profiles (id, name, email, role)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'name'), ''), split_part(new.email, '@', 1)),
    lower(new.email),
    'student'
  )
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_verified on auth.users;
create trigger on_auth_user_verified after update of email_confirmed_at on auth.users
  for each row when (old.email_confirmed_at is null and new.email_confirmed_at is not null)
  execute function private.handle_new_user();


-- ======== seed.sql ========
-- Starter course content exported from the original FastAPI database on 2026-10-30.
-- Courses, modules, lessons, resources, assignments, quizzes and live classes only: no users, progress or payments.
-- Load it once into a new project (SQL editor, or `supabase db reset` locally). Edit or delete anything from the admin panel.
-- Deadlines and live-class times are written relative to now() so the demo ones are upcoming when loaded.

insert into public.courses (id, title, slug, short_description, description, category, difficulty, price, thumbnail_url, is_published, features, created_at) values
  ('4c4abdb5-f903-40f7-b4f5-cdf3aac728c7', 'Google Ads & PPC Mastery', 'google-ads-ppc-mastery', 'Plan, launch and optimise paid campaigns across Search, Display and YouTube.', 'Build profitable pay-per-click campaigns from scratch: structure accounts, write high-CTR ads, set smart bidding and scale what works while cutting wasted spend.', 'Paid Advertising', 'intermediate', 1499.00, NULL, true, '["Live campaign walkthroughs", "Budget planning templates", "Live doubt-clearing classes", "Certificate of completion"]'::jsonb, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('5d08e624-49b2-460f-8464-fe4cf0dbedef', 'AI & Analytics for Marketers', 'ai-analytics-for-marketers', 'Use GA4, dashboards and AI tools to make faster, smarter marketing decisions.', 'Set up GA4 properly, build reporting dashboards, and apply AI for research, content, segmentation and campaign optimisation without losing brand quality.', 'AI & Analytics', 'advanced', 2999.00, NULL, true, '["GA4 and dashboard templates", "Capstone growth project", "Live classes", "Certificate of completion"]'::jsonb, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('71c75253-c3ff-4e5a-813f-8f8d6f5adce6', 'Content Marketing & Copywriting', 'content-marketing-copywriting', 'Write content that attracts, persuades and converts.', 'Learn the content funnel, storytelling and conversion copywriting frameworks, then build a repeatable editorial workflow for blogs, landing pages and email.', 'Content Marketing', 'beginner', 0.00, NULL, true, '["Copywriting critiques", "Portfolio project", "Certificate of completion"]'::jsonb, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('7b13b51a-96c0-41b0-af91-f81cec4591a8', 'Social Media Marketing Strategy', 'social-media-marketing-strategy', 'Grow an engaged audience on Instagram, LinkedIn, YouTube and more.', 'Create a platform-by-platform strategy, plan a content calendar, run paid social, and measure what actually moves followers, leads and sales.', 'Social Media', 'beginner', 999.00, NULL, true, '["Content calendar templates", "Quizzes after every module", "Certificate of completion"]'::jsonb, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('f42beb1a-1954-4957-9711-0b1adbf584af', 'SEO Fundamentals: Rank on Google', 'seo-fundamentals-rank-on-google', 'Learn keyword research, on-page SEO and link building that drives organic traffic.', 'A practical, hands-on introduction to search engine optimisation. You will research keywords, optimise pages, fix technical issues and build authority, then track the results in Search Console.', 'SEO', 'beginner', 0.00, NULL, true, '["Lifetime access", "Real website audit project", "Assignments with feedback", "Certificate of completion"]'::jsonb, '2026-10-08T20:23:42.510433+05:30'::timestamptz)
on conflict (id) do nothing;

insert into public.course_modules (id, course_id, title, position, created_at) values
  ('022f04d3-dde0-473f-b588-34d5d1670c49', 'f42beb1a-1954-4957-9711-0b1adbf584af', 'How Search Works', 0, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('3d340bcf-88d3-4f1d-98ed-84b7fd2f1beb', '5d08e624-49b2-460f-8464-fe4cf0dbedef', 'Measurement Foundations', 0, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('3d7ecf6f-e1d3-4aa2-8f81-fed80cafba9c', '4c4abdb5-f903-40f7-b4f5-cdf3aac728c7', 'PPC Foundations', 0, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('453a0ce1-9c37-4682-878e-17f16cd075f4', 'f42beb1a-1954-4957-9711-0b1adbf584af', 'On-Page & Technical SEO', 1, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('65a0d8b6-b973-4c62-b947-d2d04f243194', '7b13b51a-96c0-41b0-af91-f81cec4591a8', 'Strategy & Content', 0, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('6b4c15c8-65f1-420f-838a-76e449392b7f', '71c75253-c3ff-4e5a-813f-8f8d6f5adce6', 'Content Foundations', 0, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('95b442e5-3da4-45fe-8a0b-6391cd28c70d', '4c4abdb5-f903-40f7-b4f5-cdf3aac728c7', 'Optimise & Scale', 1, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('9e9fa8b8-83b0-4933-9555-25916337adfb', '7b13b51a-96c0-41b0-af91-f81cec4591a8', 'Growth & Measurement', 1, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('c57e7473-dde0-4d44-a86f-5b3879c695d6', '71c75253-c3ff-4e5a-813f-8f8d6f5adce6', 'Copy That Converts', 1, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('ea244c12-bd75-4484-83b2-713dc6cdf8ea', '5d08e624-49b2-460f-8464-fe4cf0dbedef', 'AI-Powered Marketing', 1, '2026-10-08T20:23:42.510433+05:30'::timestamptz)
on conflict (id) do nothing;

insert into public.lessons (id, module_id, title, description, video_url, duration_seconds, position, is_free_preview, created_at) values
  ('0402b898-f05e-4585-baff-eb7ab295becc', '3d7ecf6f-e1d3-4aa2-8f81-fed80cafba9c', 'Campaign and ad group structure', 'In this lesson of ''Google Ads & PPC Mastery'' we cover: campaign and ad group structure.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4', 960, 1, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('0485e742-a91a-46b7-8b22-c2d11b29f556', '65a0d8b6-b973-4c62-b947-d2d04f243194', 'Choosing platforms and audiences', 'In this lesson of ''Social Media Marketing Strategy'' we cover: choosing platforms and audiences.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4', 600, 0, true, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('06085d86-ae4a-46c5-b06f-6cbd374786f3', '9e9fa8b8-83b0-4933-9555-25916337adfb', 'Analytics and reporting', 'In this lesson of ''Social Media Marketing Strategy'' we cover: analytics and reporting.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4', 900, 2, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('079f6aa9-6795-4412-b318-291c93f1d8de', '9e9fa8b8-83b0-4933-9555-25916337adfb', 'Short-form video that performs', 'In this lesson of ''Social Media Marketing Strategy'' we cover: short-form video that performs.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4', 840, 0, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('0a576b8d-c7d0-4721-a95a-b3e730025114', '453a0ce1-9c37-4682-878e-17f16cd075f4', 'Title tags, headings and snippets', 'In this lesson of ''SEO Fundamentals: Rank on Google'' we cover: title tags, headings and snippets.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4', 900, 0, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('376cb28b-7bef-4287-9d8e-95c8076a176a', '3d7ecf6f-e1d3-4aa2-8f81-fed80cafba9c', 'How the ad auction works', 'In this lesson of ''Google Ads & PPC Mastery'' we cover: how the ad auction works.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4', 780, 0, true, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('38280c41-bfc7-4cf1-bc56-c94e9c67b6ac', '6b4c15c8-65f1-420f-838a-76e449392b7f', 'Headlines and hooks', 'In this lesson of ''Content Marketing & Copywriting'' we cover: headlines and hooks.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4', 660, 1, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('4b332db8-5b1e-41ca-86fb-6554a5e50417', '022f04d3-dde0-473f-b588-34d5d1670c49', 'Welcome & the SEO landscape', 'In this lesson of ''SEO Fundamentals: Rank on Google'' we cover: welcome & the seo landscape.', '/uploads/videos/f373594dc7714b8f95bb077f1fa03894.mp4', 420, 0, true, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('4e9ad395-d829-47c3-8696-ec4d4d618312', '3d340bcf-88d3-4f1d-98ed-84b7fd2f1beb', 'GA4 setup and events', 'In this lesson of ''AI & Analytics for Marketers'' we cover: ga4 setup and events.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4', 780, 0, true, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('59b2e9c0-3d0a-49c2-9789-4798a4136a62', '9e9fa8b8-83b0-4933-9555-25916337adfb', 'Paid social basics', 'In this lesson of ''Social Media Marketing Strategy'' we cover: paid social basics.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4', 720, 1, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('5ca04976-2e27-45af-838b-cfee48701eca', '3d340bcf-88d3-4f1d-98ed-84b7fd2f1beb', 'Attribution and funnels', 'In this lesson of ''AI & Analytics for Marketers'' we cover: attribution and funnels.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4', 960, 1, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('6c7b1950-776e-46d7-81e7-dd2a15e3c346', '95b442e5-3da4-45fe-8a0b-6391cd28c70d', 'Scaling and A/B testing', 'In this lesson of ''Google Ads & PPC Mastery'' we cover: scaling and a/b testing.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4', 540, 2, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('6e218ba0-c119-48fe-9c4a-ebf05b3a66e4', 'c57e7473-dde0-4d44-a86f-5b3879c695d6', 'Email and CTA copy', 'In this lesson of ''Content Marketing & Copywriting'' we cover: email and cta copy.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4', 600, 1, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('72c17680-f9e2-403e-998b-1c1cfb2d96f7', 'ea244c12-bd75-4484-83b2-713dc6cdf8ea', 'Automation and campaign optimisation', 'In this lesson of ''AI & Analytics for Marketers'' we cover: automation and campaign optimisation.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4', 840, 1, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('74176fd7-57ac-4ceb-a757-cf1af7b74d3b', '3d7ecf6f-e1d3-4aa2-8f81-fed80cafba9c', 'Writing ads that get clicks', 'In this lesson of ''Google Ads & PPC Mastery'' we cover: writing ads that get clicks.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4', 840, 2, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('7ac946cd-ada2-480b-b4ef-403fae43e170', '95b442e5-3da4-45fe-8a0b-6391cd28c70d', 'Bidding strategies and budgets', 'In this lesson of ''Google Ads & PPC Mastery'' we cover: bidding strategies and budgets.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4', 600, 0, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('7fe4f9d2-6f3d-4fe6-b2be-731ede7408b1', '453a0ce1-9c37-4682-878e-17f16cd075f4', 'Link building and authority', 'In this lesson of ''SEO Fundamentals: Rank on Google'' we cover: link building and authority.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4', 660, 2, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('8acd2f9d-eaaa-42cf-809b-6338fff6d4bb', '6b4c15c8-65f1-420f-838a-76e449392b7f', 'Know your audience and funnel', 'In this lesson of ''Content Marketing & Copywriting'' we cover: know your audience and funnel.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4', 540, 0, true, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('8f2aa866-f00a-415e-8d40-bc61be6e60f1', '95b442e5-3da4-45fe-8a0b-6391cd28c70d', 'Conversion tracking and ROAS', 'In this lesson of ''Google Ads & PPC Mastery'' we cover: conversion tracking and roas.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4', 900, 1, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('ad1aa932-703a-433f-98a8-0984065a1376', '453a0ce1-9c37-4682-878e-17f16cd075f4', 'Site speed and Core Web Vitals', 'In this lesson of ''SEO Fundamentals: Rank on Google'' we cover: site speed and core web vitals.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4', 720, 1, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('bb57b7a6-d5fb-4076-a630-5dce754fa395', '022f04d3-dde0-473f-b588-34d5d1670c49', 'Search intent and content mapping', 'In this lesson of ''SEO Fundamentals: Rank on Google'' we cover: search intent and content mapping.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4', 840, 2, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('bc02ca8a-8272-4bee-9b92-24851276cd5e', 'c57e7473-dde0-4d44-a86f-5b3879c695d6', 'Landing page copywriting', 'In this lesson of ''Content Marketing & Copywriting'' we cover: landing page copywriting.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4', 720, 0, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('c1592d3d-d13e-4781-b37d-e5145ffe772d', '65a0d8b6-b973-4c62-b947-d2d04f243194', 'Content pillars and calendars', 'In this lesson of ''Social Media Marketing Strategy'' we cover: content pillars and calendars.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4', 480, 1, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('ce63a1b6-05d5-44f8-8dea-1b7b25e9fab9', 'ea244c12-bd75-4484-83b2-713dc6cdf8ea', 'AI for research and content', 'In this lesson of ''AI & Analytics for Marketers'' we cover: ai for research and content.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4', 1020, 0, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('ee89ce29-223a-4137-ba61-fed0f60da964', '022f04d3-dde0-473f-b588-34d5d1670c49', 'Keyword research that converts', 'In this lesson of ''SEO Fundamentals: Rank on Google'' we cover: keyword research that converts.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4', 780, 1, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz)
on conflict (id) do nothing;

insert into public.lesson_resources (id, lesson_id, title, file_url, created_at) values
  ('0b4075a5-17ef-4e03-bd8f-91fed7300268', '74176fd7-57ac-4ceb-a757-cf1af7b74d3b', 'Writing ads that get clicks - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('17b2af74-2f70-4668-adca-354451e3dc1a', 'c1592d3d-d13e-4781-b37d-e5145ffe772d', 'Content pillars and calendars - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('1c799c3a-c7dc-40b5-aad0-b5c58810de86', '6e218ba0-c119-48fe-9c4a-ebf05b3a66e4', 'Email and CTA copy - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('1d79e35c-d21a-4917-9a9e-233213b8d15b', 'bb57b7a6-d5fb-4076-a630-5dce754fa395', 'Search intent and content mapping - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('2759f4a5-be0c-435c-98a6-489e169a1b68', '376cb28b-7bef-4287-9d8e-95c8076a176a', 'How the ad auction works - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('31e9e1d8-85e7-4357-b22d-9b508284a7fa', '0a576b8d-c7d0-4721-a95a-b3e730025114', 'Title tags, headings and snippets - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('3cba3da2-722c-426a-9d61-cf61223a8246', '72c17680-f9e2-403e-998b-1c1cfb2d96f7', 'Automation and campaign optimisation - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('66e2583d-9e1b-4062-a0bc-7c4879d66561', '7fe4f9d2-6f3d-4fe6-b2be-731ede7408b1', 'Link building and authority - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('6e5f55f6-79a9-4ddc-9b16-107bce9fca05', '06085d86-ae4a-46c5-b06f-6cbd374786f3', 'Analytics and reporting - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('75e3f417-a74e-4e9d-a799-f141b00f2543', '8f2aa866-f00a-415e-8d40-bc61be6e60f1', 'Conversion tracking and ROAS - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('854c5b9f-0b0f-4a56-b149-28fa2f4fab98', 'ee89ce29-223a-4137-ba61-fed0f60da964', 'Keyword research that converts - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('8c3e049a-220d-4203-8017-dc8c65204a83', 'bc02ca8a-8272-4bee-9b92-24851276cd5e', 'Landing page copywriting - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('914cb5af-2983-48e0-9680-1128516452d5', '8acd2f9d-eaaa-42cf-809b-6338fff6d4bb', 'Know your audience and funnel - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('92218416-d197-4e7e-9abe-e8bb95e91151', '079f6aa9-6795-4412-b318-291c93f1d8de', 'Short-form video that performs - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('a3cae815-2d6e-419d-850e-9ef6e1cb00b3', '0402b898-f05e-4585-baff-eb7ab295becc', 'Campaign and ad group structure - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('aa792415-59cf-40d5-88b7-97ed00b9a801', '5ca04976-2e27-45af-838b-cfee48701eca', 'Attribution and funnels - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('b0d14ca6-22bf-4a44-bdfb-9b7c750cfc39', '4b332db8-5b1e-41ca-86fb-6554a5e50417', 'Welcome & the SEO landscape - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('b294a68d-c8f4-4e4b-a118-008ee5ac41c5', '59b2e9c0-3d0a-49c2-9789-4798a4136a62', 'Paid social basics - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('c09b3fe5-a7cd-4734-99dc-86de7f271c93', '6c7b1950-776e-46d7-81e7-dd2a15e3c346', 'Scaling and A/B testing - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('c2a22c2d-aeba-4939-8de8-c3051b96039d', '0485e742-a91a-46b7-8b22-c2d11b29f556', 'Choosing platforms and audiences - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('cd871eee-3591-404a-b8f3-3732799e9a43', '4e9ad395-d829-47c3-8696-ec4d4d618312', 'GA4 setup and events - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('ce4f8004-7405-4e0e-b219-0aa571654492', '38280c41-bfc7-4cf1-bc56-c94e9c67b6ac', 'Headlines and hooks - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('d8d0ba72-7977-46ec-ab24-3015bc68f5f6', 'ce63a1b6-05d5-44f8-8dea-1b7b25e9fab9', 'AI for research and content - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('d8fb5962-daa8-4ff0-9aab-269c6e2c2bc6', 'ad1aa932-703a-433f-98a8-0984065a1376', 'Site speed and Core Web Vitals - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('ee0511b8-3912-471f-a360-e6cbea85a7da', '7ac946cd-ada2-480b-b4ef-403fae43e170', 'Bidding strategies and budgets - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz)
on conflict (id) do nothing;

insert into public.assignments (id, course_id, module_id, title, instructions, deadline, max_marks, allow_late, attachment_url, created_at) values
  ('0ae535f1-695a-40e4-b792-ce02083067bd', '71c75253-c3ff-4e5a-813f-8f8d6f5adce6', '6b4c15c8-65f1-420f-838a-76e449392b7f', 'Assignment 1: Content Foundations practice', 'Complete the exercises described in the lesson, then upload your solution file or paste your answer below. Explain your approach briefly.', now() + interval '604800 seconds', 100, false, NULL, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('7d31a64b-faf8-42c9-b903-c5363c093903', '5d08e624-49b2-460f-8464-fe4cf0dbedef', '3d340bcf-88d3-4f1d-98ed-84b7fd2f1beb', 'Assignment 1: Measurement Foundations practice', 'Complete the exercises described in the lesson, then upload your solution file or paste your answer below. Explain your approach briefly.', now() + interval '604800 seconds', 100, false, NULL, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('bd3e659c-b82d-4fb3-82fe-cf4a49ede8e5', '4c4abdb5-f903-40f7-b4f5-cdf3aac728c7', '3d7ecf6f-e1d3-4aa2-8f81-fed80cafba9c', 'Assignment 1: PPC Foundations practice', 'Complete the exercises described in the lesson, then upload your solution file or paste your answer below. Explain your approach briefly.', now() + interval '604800 seconds', 100, false, NULL, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('cb4dc4cc-49c2-4f51-8602-dfd0299d4663', '7b13b51a-96c0-41b0-af91-f81cec4591a8', '65a0d8b6-b973-4c62-b947-d2d04f243194', 'Assignment 1: Strategy & Content practice', 'Complete the exercises described in the lesson, then upload your solution file or paste your answer below. Explain your approach briefly.', now() + interval '604800 seconds', 100, false, NULL, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('fca96abe-60fd-44b1-bb0d-f60bd9f6f6c2', 'f42beb1a-1954-4957-9711-0b1adbf584af', '022f04d3-dde0-473f-b588-34d5d1670c49', 'Assignment 1: How Search Works practice', 'Complete the exercises described in the lesson, then upload your solution file or paste your answer below. Explain your approach briefly.', now() + interval '604800 seconds', 100, false, NULL, '2026-10-08T20:23:42.510433+05:30'::timestamptz)
on conflict (id) do nothing;

insert into public.quizzes (id, course_id, module_id, title, description, time_limit_minutes, show_results, is_published, created_at) values
  ('749e2c39-32f8-4af6-8971-97f868ea2e57', '4c4abdb5-f903-40f7-b4f5-cdf3aac728c7', NULL, 'PPC Foundations Quiz', 'Check your understanding. You can retake this quiz.', 10, true, true, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('8e2267a0-3853-4e4d-bb25-a4313eefa102', 'f42beb1a-1954-4957-9711-0b1adbf584af', NULL, 'How Search Works Quiz', 'Check your understanding. You can retake this quiz.', 10, true, true, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('f1f34541-89ac-49fd-8db9-dbc9e8c685aa', '7b13b51a-96c0-41b0-af91-f81cec4591a8', NULL, 'Strategy & Content Quiz', 'Check your understanding. You can retake this quiz.', 10, true, true, '2026-10-08T20:23:42.510433+05:30'::timestamptz)
on conflict (id) do nothing;

insert into public.quiz_questions (id, quiz_id, text, marks, position, created_at) values
  ('1e09df86-1b0c-40a7-a15d-43bcc94b28cc', '8e2267a0-3853-4e4d-bb25-a4313eefa102', 'Which element is the most important on-page signal for a page''s topic?', 1, 1, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('3726bbd7-8878-4720-9082-d4e1fce75776', '749e2c39-32f8-4af6-8971-97f868ea2e57', 'Which keyword match type is the most restrictive?', 1, 2, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('374425c9-fe86-4da2-a968-659b4fe4df1c', '749e2c39-32f8-4af6-8971-97f868ea2e57', 'What does ROAS measure?', 1, 1, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('418156f2-ddf7-4e15-95b4-9e45578a3bbc', 'f1f34541-89ac-49fd-8db9-dbc9e8c685aa', 'What is a content pillar?', 1, 0, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('47dd2ca6-e3b9-42b8-a3fa-751961aa9468', '749e2c39-32f8-4af6-8971-97f868ea2e57', 'In Google Ads, CTR is calculated as...', 1, 0, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('6b15e1a1-7f00-400d-8697-868969ca5c8e', 'f1f34541-89ac-49fd-8db9-dbc9e8c685aa', 'Engagement rate is best described as...', 1, 1, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('8b7e251a-2880-40e2-aa5f-561aacccaf95', '8e2267a0-3853-4e4d-bb25-a4313eefa102', 'Which tool shows how your site appears in Google search?', 1, 3, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('a9df37fa-2a05-4670-bd48-55dd94aadca6', 'f1f34541-89ac-49fd-8db9-dbc9e8c685aa', 'Which platform is typically strongest for B2B lead generation?', 1, 2, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('d28dcd10-210b-4c22-8fbc-c83a7afb13d4', '8e2267a0-3853-4e4d-bb25-a4313eefa102', 'What does SERP stand for?', 1, 0, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('e28091bb-e7a2-4b69-bb1a-1cd741321458', '8e2267a0-3853-4e4d-bb25-a4313eefa102', 'Search intent that signals readiness to buy is called...', 1, 2, '2026-10-08T20:23:42.510433+05:30'::timestamptz)
on conflict (id) do nothing;

insert into public.quiz_options (id, question_id, text, is_correct, created_at) values
  ('0165a230-5e26-4713-ae73-18c40710857c', 'e28091bb-e7a2-4b69-bb1a-1cd741321458', 'Transactional', true, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('0256f71a-b68d-4daa-b6df-051243aab2a8', '3726bbd7-8878-4720-9082-d4e1fce75776', 'Modified', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('06d60a45-5f7d-450a-9a6f-788d60639657', 'a9df37fa-2a05-4670-bd48-55dd94aadca6', 'Pinterest', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('10f38e5c-7597-4927-98e6-c5f44d740e86', '1e09df86-1b0c-40a7-a15d-43bcc94b28cc', 'Footer text', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('13157f5e-e3a0-4228-9d98-61613c5ae429', 'd28dcd10-210b-4c22-8fbc-c83a7afb13d4', 'Search Engine Results Page', true, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('141d4246-08f4-4aaf-898d-dd2c7756a1dd', '374425c9-fe86-4da2-a968-659b4fe4df1c', 'Rate of ad skips', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('1f7ede9a-d281-487d-8ea3-052346223487', 'a9df37fa-2a05-4670-bd48-55dd94aadca6', 'Twitch', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('2019f7bb-0fb4-495b-b143-b112369b70e6', '6b15e1a1-7f00-400d-8697-868969ca5c8e', 'Posting frequency', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('2bc23de8-33fd-4782-8528-35703b2c053c', '418156f2-ddf7-4e15-95b4-9e45578a3bbc', 'A recurring theme your content covers', true, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('34c5ac30-33df-42f6-a488-a98dbfcc7327', '8b7e251a-2880-40e2-aa5f-561aacccaf95', 'Google Keep', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('3bc6df10-d7e0-4a6a-bb65-550b62c27539', '47dd2ca6-e3b9-42b8-a3fa-751961aa9468', 'Impressions ÷ Clicks', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('447aeb40-feb7-40af-8e5b-aaa6a85142ea', 'e28091bb-e7a2-4b69-bb1a-1cd741321458', 'Local', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('450f2fd5-b964-4dfb-a433-cfe3877a5c0d', '6b15e1a1-7f00-400d-8697-868969ca5c8e', 'Interactions relative to audience or reach', true, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('4c0a7316-2255-425d-89f7-33e1fbdacf51', '8b7e251a-2880-40e2-aa5f-561aacccaf95', 'Google Search Console', true, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('4e7eb5a6-5d7d-46e8-8e6b-4ee84a48b365', 'd28dcd10-210b-4c22-8fbc-c83a7afb13d4', 'Site Entry Redirect Protocol', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('53c95a82-8314-45da-bb61-64fb7c0ced07', 'e28091bb-e7a2-4b69-bb1a-1cd741321458', 'Informational', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('58c948a2-97b6-48dd-ac8b-de8730dc59db', '3726bbd7-8878-4720-9082-d4e1fce75776', 'Phrase', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('5d52f8c2-dc1a-4d9f-969f-3cf653eb6e5c', '1e09df86-1b0c-40a7-a15d-43bcc94b28cc', 'Cookie banner', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('6257b99d-adfa-4eb8-b708-ffbc10f884ad', 'd28dcd10-210b-4c22-8fbc-c83a7afb13d4', 'Search Engine Ranking Policy', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('62e0dd3d-4275-4ccf-8799-fe762c2da859', '3726bbd7-8878-4720-9082-d4e1fce75776', 'Broad', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('6ae3f515-4924-4ee6-97b8-bc52b7aa7da0', 'a9df37fa-2a05-4670-bd48-55dd94aadca6', 'LinkedIn', true, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('6c7297bb-cbf0-451d-8d74-a7bd9e9774a8', '1e09df86-1b0c-40a7-a15d-43bcc94b28cc', 'Favicon', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('72a57524-2217-487c-8ed0-e6aad5c3056c', '47dd2ca6-e3b9-42b8-a3fa-751961aa9468', 'Clicks ÷ Impressions', true, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('7eda1764-8e1b-4cb9-bd07-7e0753470805', 'e28091bb-e7a2-4b69-bb1a-1cd741321458', 'Navigational', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('83cbffe0-9cf9-4947-92fe-e457c75d6405', 'd28dcd10-210b-4c22-8fbc-c83a7afb13d4', 'Secure Email Response Page', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('88dc8383-d4d3-4e5f-bd49-fc0dd0123ed4', '8b7e251a-2880-40e2-aa5f-561aacccaf95', 'Google Calendar', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('8ae2ce2a-05b7-4511-ac93-9c9094e172cd', '374425c9-fe86-4da2-a968-659b4fe4df1c', 'Reach of ad sets', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('93b04479-a38d-46c6-9acc-f59cf6996546', '374425c9-fe86-4da2-a968-659b4fe4df1c', 'Rank of ad score', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('93c63ed4-127b-41a4-9670-67915278fab9', '47dd2ca6-e3b9-42b8-a3fa-751961aa9468', 'Cost ÷ Clicks', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('9f998902-43b0-4213-9b0f-b2b6919a8165', '374425c9-fe86-4da2-a968-659b4fe4df1c', 'Revenue per ad spend', true, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('a1386b08-f59c-4cf2-8acd-30d8b2aee1a9', '418156f2-ddf7-4e15-95b4-9e45578a3bbc', 'A follower milestone', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('a3b4bd1a-ae15-4c6f-a02f-be5870ca918c', '6b15e1a1-7f00-400d-8697-868969ca5c8e', 'Ad spend per day', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('b2c6d0c8-503a-4738-a8c6-7b2642745d0b', '47dd2ca6-e3b9-42b8-a3fa-751961aa9468', 'Conversions ÷ Clicks', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('b59f00c9-d172-4403-bf89-677c72ecb8c3', 'a9df37fa-2a05-4670-bd48-55dd94aadca6', 'Snapchat', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('c3e15989-feb7-4cb7-bc59-84b20b6f6d2d', '3726bbd7-8878-4720-9082-d4e1fce75776', 'Exact', true, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('c5aa1da2-0e81-4a00-aa04-8e4f35ee79ef', '418156f2-ddf7-4e15-95b4-9e45578a3bbc', 'A hashtag limit', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('cafb3b08-54d8-45c8-85cb-4693bf51ceec', '6b15e1a1-7f00-400d-8697-868969ca5c8e', 'Total followers', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('cb275bee-7afa-479f-b6d9-bfc4992fe350', '1e09df86-1b0c-40a7-a15d-43bcc94b28cc', 'Title tag', true, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('df745796-b71a-4b2a-865e-cc8558a104a3', '418156f2-ddf7-4e15-95b4-9e45578a3bbc', 'A paid ad format', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('e3a69216-31a7-4d1a-b7c5-6561c087940c', '8b7e251a-2880-40e2-aa5f-561aacccaf95', 'Google Sheets', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz)
on conflict (id) do nothing;

insert into public.live_classes (id, course_id, title, description, starts_at, ends_at, meeting_url, platform, created_at) values
  ('24b844f7-c61f-49ac-91d6-11deaa31607f', '4c4abdb5-f903-40f7-b4f5-cdf3aac728c7', 'Google Ads account teardown', 'Real account review: wasted spend, quality score and bidding fixes.', now() + interval '259200 seconds', now() + interval '264600 seconds', 'https://zoom.us/j/9876543210', 'Zoom', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('5fdbf6ce-2429-4e64-ab0b-33ba19057244', 'f42beb1a-1954-4957-9711-0b1adbf584af', 'Technical SEO audit clinic', 'Live audit of a student site: crawl errors, speed and indexing.', now() + interval '93600 seconds', now() + interval '97200 seconds', 'https://zoom.us/j/1234567890', 'Zoom', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('6251fa8d-4ce1-4fe0-8b2d-4ba6aac34390', '7b13b51a-96c0-41b0-af91-f81cec4591a8', 'Instagram Reels growth clinic', 'Hooks, retention and posting cadence with worked examples.', now() + interval '-172799 seconds', now() + interval '-169199 seconds', 'https://zoom.us/j/1112223334', 'Zoom', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('8c22504e-f914-482c-9cba-d48a5afbe9bf', 'f42beb1a-1954-4957-9711-0b1adbf584af', 'Live Q&A: Keyword research workshop', 'Bring your niche and we''ll build a keyword map together.', now() + interval '-599 seconds', now() + interval '3000 seconds', 'https://meet.google.com/lookup/lms-demo-live', 'Google Meet', '2026-10-08T20:23:42.510433+05:30'::timestamptz)
on conflict (id) do nothing;

-- First course: new name and online/offline prices; shown first in the catalog.
update public.courses set title = 'Marketing Analytics and AI driven marketing', slug = 'marketing-analytics-and-ai-driven-marketing',
  price = 4999, offline_price = 14999, created_at = now()
where id = '5d08e624-49b2-460f-8464-fe4cf0dbedef';

-- Remove old courses: Google Ads & PPC Mastery, Content Marketing & Copywriting,
-- Social Media Marketing Strategy, SEO Fundamentals: Rank on Google.
delete from public.courses where id in (
  '4c4abdb5-f903-40f7-b4f5-cdf3aac728c7', '71c75253-c3ff-4e5a-813f-8f8d6f5adce6',
  '7b13b51a-96c0-41b0-af91-f81cec4591a8', 'f42beb1a-1954-4957-9711-0b1adbf584af');

-- Course catalog: Marketing Analytics stays first, then the new courses in this order.
update public.courses set created_at = now() where id = '5d08e624-49b2-460f-8464-fe4cf0dbedef';

insert into public.courses (title, slug, short_description, description, category, difficulty, price, offline_price, is_published, created_at) values
  ('Website & Landing Marketing', 'website-landing-marketing',
   'Plan websites and landing pages that turn visitors into customers.',
   'Plan websites and landing pages that turn visitors into customers.',
   'Website Marketing', 'beginner', 4999, 14999, true, now() - interval '1 minute'),
  ('Social Media & Content Marketing', 'social-media-content-marketing',
   'Grow an audience on social media with content that connects.',
   'Grow an audience on social media with content that connects.',
   'Social Media', 'beginner', 4999, 14999, true, now() - interval '2 minutes'),
  ('SEO & AI Search Optimization', 'seo-ai-search-optimization',
   'Get found on Google and in AI search results.',
   'Get found on Google and in AI search results.',
   'SEO', 'beginner', 4999, 14999, true, now() - interval '3 minutes'),
  ('Digital Marketing Professional', 'digital-marketing-professional',
   'Build skills across the main digital marketing channels.',
   'Build skills across the main digital marketing channels.',
   'Digital Marketing', 'beginner', 9999, 39999, true, now() - interval '4 minutes'),
  ('Graphic Designer', 'graphic-designer',
   'Learn to create clear, professional graphics for brands and marketing.',
   'Learn to create clear, professional graphics for brands and marketing.',
   'Graphic Design', 'beginner', 4999, 19999, true, now() - interval '5 minutes'),
  ('Video Editing', 'video-editing',
   'Learn to edit engaging videos for social media and marketing.',
   'Learn to edit engaging videos for social media and marketing.',
   'Video Editing', 'beginner', 4999, 19999, true, now() - interval '6 minutes');

-- Course lineup: every course runs 4 months, except the two programmes below.
update public.courses set duration_months = 4;
update public.courses set price = 9999 where slug in ('graphic-designer', 'video-editing');

-- The combo and Entrepreneurship go after the existing courses. The Placement Programme goes second, right after
-- Marketing Analytics, so it appears in the home page rows (which show the first 4).
insert into public.courses (title, slug, short_description, description, category, difficulty, price, offline_price, duration_months, offline_only, features, is_published, created_at) values
  ('Video Editing + Graphic Designer Combo', 'video-editing-graphic-designer-combo',
   'Learn video editing and graphic design together.',
   'Learn video editing and graphic design together in one course.',
   'Video & Graphic Design', 'beginner', 17999, 34999, 4, false,
   '["Video Editing", "Graphic Designer"]'::jsonb, true,
   (select min(created_at) from public.courses) - interval '1 minute'),
  ('100% Placement Programme', '100-placement-programme',
   'Every GTapex course, taught in the classroom over 8 months.',
   'Every GTapex course, taught in the classroom over 8 months.',
   'Placement Programme', 'beginner', 59999, 59999, 8, true,
   '["Marketing Analytics and AI driven marketing", "Website & Landing Marketing", "Social Media & Content Marketing", "SEO & AI Search Optimization", "Digital Marketing Professional", "Graphic Designer", "Video Editing"]'::jsonb, true,
   (select created_at from public.courses where slug = 'marketing-analytics-and-ai-driven-marketing') - interval '30 seconds'),
  ('Entrepreneurship Programme', 'entrepreneurship-programme',
   'A classroom programme for people building their own business.',
   'A classroom programme for people building their own business.',
   'Entrepreneurship', 'beginner', 40000, 40000, 6, true,
   '[]'::jsonb, true,
   (select min(created_at) from public.courses) - interval '2 minutes');

-- One category for video and design: Graphic Designer, Video Editing and the combo.
update public.courses set category = 'Video Editing & Graphic Designing'
where slug in ('graphic-designer', 'video-editing', 'video-editing-graphic-designer-combo');

-- Course pictures: files are in frontend/public/course-thumbnails.
update public.courses set thumbnail_url = '/course-thumbnails/marketing-analytics-and-ai-driven-marketing.webp' where slug = 'marketing-analytics-and-ai-driven-marketing';
update public.courses set thumbnail_url = '/course-thumbnails/100-placement-programme.webp' where slug = '100-placement-programme';
update public.courses set thumbnail_url = '/course-thumbnails/website-landing-marketing.webp' where slug = 'website-landing-marketing';
update public.courses set thumbnail_url = '/course-thumbnails/social-media-content-marketing.webp' where slug = 'social-media-content-marketing';
update public.courses set thumbnail_url = '/course-thumbnails/seo-ai-search-optimization.webp' where slug = 'seo-ai-search-optimization';
update public.courses set thumbnail_url = '/course-thumbnails/digital-marketing-professional.webp' where slug = 'digital-marketing-professional';
update public.courses set thumbnail_url = '/course-thumbnails/graphic-designer.webp' where slug = 'graphic-designer';
update public.courses set thumbnail_url = '/course-thumbnails/video-editing.webp' where slug = 'video-editing';
update public.courses set thumbnail_url = '/course-thumbnails/video-editing-graphic-designer-combo.webp' where slug = 'video-editing-graphic-designer-combo';
update public.courses set thumbnail_url = '/course-thumbnails/entrepreneurship-programme.webp' where slug = 'entrepreneurship-programme';

commit;
