-- Removes the cohort system from the live database and puts every changed function back as it was.
-- Run once in Supabase dashboard > SQL Editor. All-or-nothing: on any error nothing is kept.
-- Permanently deletes any cohorts and any session recording links. Students, enrollments, payments and demo requests stay.
begin;

-- Functions added by the cohort change, and those whose arguments it altered.
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname || '.' || p.proname in (
    'private.date_field',
    'private.url_field',
    'private.cohort_or_404',
    'private.cohort_public',
    'private.visible_live',
    'private.live_audience',
    'private.student_live_out',
    'private.cohort_admin_out',
    'private.apply_cohort_fields',
    'public.admin_cohorts',
    'public.admin_create_cohort',
    'public.admin_update_cohort',
    'public.admin_delete_cohort',
    'public.admin_cohort_students',
    'public.admin_add_offline_student',
    'public.admin_remove_offline_student',
    'private.check_cohort',
    'private.demo_out',
    'private.enroll_user',
    'public.book_demo',
    'public.payment_prepare',
    'public.payment_record_order'
    )
  loop
    execute format('drop function %s', f.sig);
  end loop;
end $$;

-- The functions as they were before.
create or replace function private.enroll_user(p_user public.profiles, p_course public.courses) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if private.is_enrolled(p_user.id, p_course.id) then return; end if;
  insert into public.enrollments (user_id, course_id) values (p_user.id, p_course.id);
  perform private.notify(p_user.id, 'enrollment', 'Enrolled in ' || p_course.title, 'You can start learning right away.');
  perform private.notify_admins('enrollment', 'New enrollment', p_user.name || ' enrolled in ' || p_course.title);
end $$;

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

create or replace function public.payment_record_order(p_user_id uuid, p_course_id uuid, p_amount numeric, p_order_id text)
returns void language sql security definer set search_path = '' as $$
  insert into public.payments (user_id, course_id, amount, currency, status, razorpay_order_id)
  values (p_user_id, p_course_id, p_amount, 'INR', 'created', p_order_id)
$$;

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

-- The added columns, the cohorts table and its types.
alter table public.demo_requests drop column cohort_id;
alter table public.payments drop column cohort_id;
alter table public.live_classes drop column cohort_id;
alter table public.live_classes drop column recording_url;
alter table public.enrollments drop column cohort_id;
alter table public.enrollments drop column learning_mode;
drop table public.cohorts;
drop type public.learning_mode;
drop type public.cohort_status;

-- ================================================================ permissions (same rules as the storage_and_grants migration)
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'private')
  loop
    execute format('revoke all on function %s from public, anon, authenticated', f.sig);
  end loop;
  for f in
    select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname not like 'payment\_%'
  loop
    execute format('grant execute on function %s to authenticated', f.sig);
  end loop;
end $$;

grant execute on function public.list_courses(text, text, text, text, boolean, int, int) to anon;
grant execute on function public.course_categories() to anon;
grant execute on function public.get_course(uuid) to anon;
grant execute on function public.book_demo(text, text, text, text, text, text) to anon;
grant execute on function public.send_contact_message(text, text, text, text, text) to anon;

grant execute on function public.payment_prepare(uuid, uuid) to service_role;
grant execute on function public.payment_record_order(uuid, uuid, numeric, text) to service_role;
grant execute on function public.payment_mark_paid(text, text, text, uuid) to service_role;
grant execute on function public.payment_mark_failed(text, uuid) to service_role;

commit;
