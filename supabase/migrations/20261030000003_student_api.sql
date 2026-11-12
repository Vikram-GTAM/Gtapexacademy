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
