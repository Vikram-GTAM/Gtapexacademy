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
