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
