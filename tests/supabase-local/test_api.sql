-- End-to-end checks of the Supabase API, run by tests/local/run.py on a throwaway database.
-- Each block impersonates a visitor, a student, an admin or the payments service and asserts what they can and
-- cannot do. Any failed check stops the run with an error.
\set ON_ERROR_STOP 1

-- ---------------------------------------------------------------- test helpers (test database only)
create schema test;
grant usage on schema test to anon, authenticated, service_role;

create function test.check(p_ok boolean, p_label text) returns void language plpgsql as $$
begin
  if p_ok is distinct from true then raise exception 'CHECK FAILED: %', p_label; end if;
end $$;

-- Runs p_sql and requires it to fail with the given app error code (hint), SQLSTATE or message fragment.
create function test.expect_error(p_sql text, p_expected text) returns void language plpgsql as $$
declare v_hint text; v_state text; v_msg text;
begin
  begin
    execute p_sql;
  exception when others then
    get stacked diagnostics v_hint = pg_exception_hint, v_state = returned_sqlstate, v_msg = message_text;
    if p_expected in (coalesce(v_hint, ''), v_state) or v_msg ilike '%' || p_expected || '%' then return; end if;
    raise exception 'EXPECTED % FROM [%] BUT GOT % / % / %', p_expected, p_sql, v_hint, v_state, v_msg;
  end;
  raise exception 'EXPECTED % FROM [%] BUT IT SUCCEEDED', p_expected, p_sql;
end $$;

create function test.login(p_uid uuid) returns void language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, false)
$$;
create function test.logout() returns void language sql as $$ select set_config('request.jwt.claims', '', false) $$;
grant execute on all functions in schema test to anon, authenticated, service_role;

-- ---------------------------------------------------------------- people (sign-up trigger creates profiles)
insert into auth.users (email, raw_user_meta_data) values
  ('admin@gtapex.test', '{"name": "Asha Admin"}'),
  ('priya@gtapex.test', '{"name": "Priya", "role": "admin"}'),   -- trying to sign up as admin must NOT work
  ('rahul@gtapex.test', '{}');
update public.profiles set role = 'admin' where email = 'admin@gtapex.test';
select id as admin_id from auth.users where email = 'admin@gtapex.test' \gset
select id as priya_id from auth.users where email = 'priya@gtapex.test' \gset
select id as rahul_id from auth.users where email = 'rahul@gtapex.test' \gset

select test.check((select role from public.profiles where id = :'priya_id') = 'student', 'sign-up metadata cannot make an admin');
select test.check((select name from public.profiles where id = :'rahul_id') = 'rahul', 'name falls back to the email prefix');

-- ---------------------------------------------------------------- admin builds content
select test.login(:'admin_id');
set role authenticated;

select test.check((public.get_me() ->> 'role') = 'admin', 'admin sees own admin profile');
select (public.admin_create_course('{"title": "Google Ads & PPC Mastery", "price": 1499, "category": "Paid Advertising", "difficulty": "intermediate", "is_published": true, "features": ["Live classes"]}')) ->> 'id' as paid_course \gset
select (public.admin_create_course('{"title": "SEO Fundamentals", "price": 0, "category": "SEO", "is_published": true}')) ->> 'id' as free_course \gset
select (public.admin_create_course('{"title": "Draft course", "price": 0}')) ->> 'id' as draft_course \gset
select test.check((public.admin_course(:'free_course') ->> 'slug') = 'seo-fundamentals', 'slug generated');
select test.check((public.admin_create_course('{"title": "SEO Fundamentals"}') ->> 'slug') = 'seo-fundamentals-2', 'duplicate titles get unique slugs');
select test.expect_error($$select public.admin_create_course('{"title": "ab"}')$$, 'validation_error');
select test.expect_error($$select public.admin_create_course('{"title": "Valid title", "price": -5}')$$, 'validation_error');

-- online and offline prices
select test.check((public.admin_update_course(:'paid_course', '{"offline_price": 14999}') ->> 'offline_price')::numeric = 14999, 'offline price saved');
select test.check((public.admin_course(:'paid_course') ->> 'price')::numeric = 1499, 'online price unchanged by offline price');
select test.expect_error(format($$select public.admin_update_course(%L, '{"offline_price": -1}')$$, :'paid_course'), 'validation_error');
select test.check((public.admin_course(:'free_course') -> 'offline_price') = 'null'::jsonb, 'offline price optional');

select (public.admin_create_module(:'paid_course', 'PPC Foundations')) ->> 'id' as paid_mod \gset
select (public.admin_create_module(:'free_course', 'How Search Works')) ->> 'id' as free_mod \gset
select (public.admin_create_module(:'free_course', 'Extra module')) ->> 'id' as free_mod2 \gset
select (public.admin_create_lesson(:'paid_mod', '{"title": "Ad auction", "video_url": "https://video.test/paid.mp4", "duration_seconds": 600}')) ->> 'id' as paid_lesson \gset
select (public.admin_create_lesson(:'free_mod', '{"title": "Welcome", "video_url": "https://video.test/free.mp4", "duration_seconds": 300, "resources": [{"title": "Slides", "file_url": "https://files.test/slides.pdf"}]}')) ->> 'id' as free_lesson \gset
select (public.admin_create_lesson(:'free_mod2', '{"title": "Bonus"}')) ->> 'id' as bonus_lesson \gset
select test.check((public.admin_update_lesson(:'bonus_lesson', format('{"module_id": "%s"}', :'free_mod')::jsonb) ->> 'module_id') = :'free_mod', 'lesson moved within the course');
select test.expect_error(format($$select public.admin_update_lesson(%L, '{"module_id": "%s"}')$$, :'bonus_lesson', :'paid_mod'), 'invalid_module');
select public.admin_delete_lesson(:'bonus_lesson');
select public.admin_delete_module(:'free_mod2');
select test.expect_error(format($$select public.admin_reorder_modules(%L, array[%L]::uuid[])$$, :'paid_course', :'free_mod'), 'invalid_order');
select public.admin_reorder_modules(:'paid_course', array[:'paid_mod']::uuid[]);
select test.check((public.admin_course(:'free_course') ->> 'lesson_count')::int = 1, 'free course has one lesson');

select (public.admin_create_quiz(format('{"course_id": "%s", "title": "SEO basics quiz", "questions": [
  {"text": "What does SEO stand for?", "marks": 2, "options": [{"text": "Search Engine Optimisation", "is_correct": true}, {"text": "Social Engine Outreach"}]},
  {"text": "Is keyword research useful?", "options": [{"text": "No"}, {"text": "Yes", "is_correct": true}]}]}', :'free_course')::jsonb)) ->> 'id' as quiz_id \gset
select test.expect_error(format($$select public.admin_create_quiz('{"course_id": "%s", "title": "Bad quiz", "questions": [{"text": "Q", "options": [{"text": "A", "is_correct": true}, {"text": "B", "is_correct": true}]}]}')$$, :'free_course'), 'exactly one correct');
select test.check((public.admin_quiz(:'quiz_id') -> 'questions' -> 0 -> 'options' -> 0 ->> 'text') = 'Search Engine Optimisation', 'options keep their order');

select (public.admin_create_assignment(format('{"course_id": "%s", "title": "Audit a website", "deadline": "%s", "max_marks": 10}', :'free_course', (now() + interval '3 days')::text)::jsonb)) ->> 'id' as assignment_id \gset
select (public.admin_create_assignment(format('{"course_id": "%s", "title": "Closed task", "deadline": "2020-01-01T10:00:00"}', :'free_course')::jsonb)) ->> 'id' as closed_assignment \gset
select test.check((public.admin_get_assignment(:'closed_assignment') ->> 'deadline')::timestamptz = '2020-01-01T10:00:00Z', 'zone-less deadline stored as UTC');
select (public.admin_create_live(format('{"course_id": "%s", "title": "Keyword workshop", "starts_at": "%s", "ends_at": "%s", "meeting_url": "https://meet.google.com/abc-defg-hij", "platform": "Google Meet"}',
         :'free_course', (now() + interval '2 days')::text, (now() + interval '2 days 1 hour')::text)::jsonb)) ->> 'id' as live_id \gset
select test.expect_error(format($$select public.admin_create_live('{"course_id": "%s", "title": "Backwards", "starts_at": "2030-01-01T10:00:00Z", "ends_at": "2030-01-01T09:00:00Z", "meeting_url": "https://meet.test/x"}')$$, :'free_course'), 'invalid_time');
select test.check((public.admin_dashboard() -> 'stats' ->> 'total_courses')::int = 4, 'dashboard counts courses');

-- ---------------------------------------------------------------- the API roles cannot touch tables directly
select test.expect_error('select * from public.quiz_options', '42501');
select test.expect_error('select * from public.profiles', '42501');
select test.expect_error($$update public.profiles set role = 'admin'$$, '42501');
select test.expect_error('select private.auth_user()', '42501');
reset role;

-- ---------------------------------------------------------------- a visitor (not signed in)
select test.logout();
set role anon;
select test.check((public.list_courses() ->> 'total')::int = 2, 'visitors see the 2 published courses only');
select test.check((public.list_courses(p_sort => 'price_desc') -> 'items' -> 0 ->> 'title') = 'Google Ads & PPC Mastery', 'sort by price');
select test.check((public.list_courses(p_search => 'seo') ->> 'total')::int = 1, 'search');
select test.check((public.list_courses(p_free_only => true) -> 'items' -> 0 ->> 'title') = 'SEO Fundamentals', 'free filter');
select test.check(jsonb_array_length(public.course_categories()) = 2, 'categories');
select test.check(not (public.get_course(:'free_course') -> 'modules' -> 0 -> 'lessons' -> 0 ? 'video_url'), 'catalog hides video links');
select test.check((public.get_course(:'free_course') ->> 'is_enrolled')::boolean = false, 'visitor not enrolled');
select test.check((public.get_course(:'paid_course') ->> 'offline_price')::numeric = 14999, 'visitors see the offline price');
select test.expect_error(format('select public.get_course(%L)', :'draft_course'), 'not_found');
select test.expect_error('select public.get_me()', '42501');
select test.expect_error(format('select public.course_lessons(%L)', :'free_course'), '42501');
select test.expect_error('select * from public.courses', '42501');
select public.book_demo('Kiran', 'kiran@example.com', '9876543210', 'SEO', 'Saturday');
select public.send_contact_message('Meera', 'meera@example.com', 'Weekend batch?', 'Is there a weekend batch for SEO?');
select test.expect_error($$select public.book_demo('K', 'kiran@example.com', '9876543210')$$, 'validation_error');
select test.expect_error($$select public.send_contact_message('Meera', 'not-an-email', 'Hello', 'Hello there')$$, 'validation_error');
reset role;

-- ---------------------------------------------------------------- student Priya
select test.login(:'priya_id');
set role authenticated;
select test.check((public.get_me() ->> 'name') = 'Priya', 'student profile');
select test.check((public.update_my_profile(p_name => '  Priya Sharma ') ->> 'name') = 'Priya Sharma', 'profile name updated');
select test.expect_error('select public.admin_dashboard()', 'forbidden');
select test.expect_error(format($$select public.admin_update_course(%L, '{"price": 0}')$$, :'paid_course'), 'forbidden');
select test.expect_error(format('select public.course_lessons(%L)', :'paid_course'), 'forbidden');
select test.expect_error(format('select public.enroll_free_course(%L)', :'paid_course'), 'payment_required');
select public.enroll_free_course(:'free_course');
select test.expect_error(format('select public.enroll_free_course(%L)', :'free_course'), 'already_enrolled');
select test.check((public.get_course(:'free_course') ->> 'is_enrolled')::boolean, 'now enrolled');
select test.check((public.course_lessons(:'free_course') -> 'modules' -> 0 -> 'lessons' -> 0 ->> 'video_url') = 'https://video.test/free.mp4', 'enrolled student gets the video');
select test.expect_error(format('select public.complete_lesson(%L)', :'paid_lesson'), 'forbidden');
select test.expect_error(format('select public.generate_certificate(%L)', :'free_course'), 'course_incomplete');
select test.check((public.complete_lesson(:'free_lesson') ->> 'percentage')::numeric = 100, 'lesson completed');
select test.check((public.complete_lesson(:'free_lesson') ->> 'completed_lessons')::int = 1, 'completing twice is harmless');
select test.check((public.my_courses() -> 0 ->> 'is_completed')::boolean, 'course marked complete');
select (public.generate_certificate(:'free_course')) ->> 'id' as cert_id \gset
select test.check((public.generate_certificate(:'free_course') ->> 'id') = :'cert_id', 'certificate issued once');
select test.check((public.certificate_details(:'cert_id') ->> 'student_name') = 'Priya Sharma', 'certificate details');
select test.check((public.certificate_details(:'cert_id') ->> 'platform_name') = 'GTapex Academy', 'platform name on certificate');
select test.check((public.uncomplete_lesson(:'free_lesson') ->> 'completed_lessons')::int = 0, 'lesson un-completed');
select test.check((public.complete_lesson(:'free_lesson') ->> 'completed_lessons')::int = 1, 'lesson re-completed');

-- quiz: questions come without the answer key; grading happens server-side
select test.check(not (public.get_quiz(:'quiz_id') -> 'questions' -> 0 -> 'options' -> 0 ? 'is_correct'), 'quiz options never include is_correct');
select (public.start_quiz(:'quiz_id')) ->> 'attempt_id' as attempt_id \gset
reset role;
-- look up question/option ids as the table owner (the student cannot read these tables)
select q.id as q1, o.id as q1_right from public.quiz_questions q join public.quiz_options o on o.question_id = q.id
  where q.text like 'What does SEO%' and o.is_correct \gset
select q.id as q2, o.id as q2_wrong from public.quiz_questions q join public.quiz_options o on o.question_id = q.id
  where q.text like 'Is keyword%' and not o.is_correct \gset
set role authenticated;
select test.check((public.submit_quiz(:'quiz_id', jsonb_build_array(
    jsonb_build_object('question_id', :'q1', 'option_id', :'q1_right'),
    jsonb_build_object('question_id', :'q2', 'option_id', :'q2_wrong')), :'attempt_id') ->> 'score')::int = 2, 'quiz graded: 2 of 3 marks');
select test.expect_error(format($$select public.submit_quiz(%L, '[]', %L)$$, :'quiz_id', :'attempt_id'), 'already_submitted');
select test.check((public.my_quizzes() -> 0 -> 'last_attempt' ->> 'score')::int = 2, 'last attempt shown');

-- assignments
select test.expect_error(format($$select public.submit_assignment(%L, null, null)$$, :'assignment_id'), 'empty_submission');
select test.expect_error(format($$select public.submit_assignment(%L, 'done')$$, :'closed_assignment'), 'deadline_passed');
select test.expect_error(format($$select public.submit_assignment(%L, null, 'https://x.supabase.co/storage/v1/object/public/submissions/%s/a.pdf')$$, :'assignment_id', :'rahul_id'), 'invalid_file');
select test.check((public.submit_assignment(:'assignment_id', 'My audit', format('https://x.supabase.co/storage/v1/object/public/submissions/%s/a.pdf', :'priya_id')) -> 'submission' ->> 'status') = 'submitted', 'assignment submitted');
select test.check((public.submit_assignment(:'assignment_id', 'My audit v2') -> 'submission' ->> 'file_url') like '%/a.pdf', 'resubmitting text keeps the file');
select test.check(jsonb_array_length(public.my_assignments()) = 2, 'my assignments');
select test.check((public.student_dashboard() -> 'stats' ->> 'completed')::int = 1, 'dashboard stats');
select test.check(jsonb_array_length(public.student_course_content(:'free_course') -> 'quizzes') = 1, 'course content');
select test.check((public.list_live_classes() -> 0 ->> 'meeting_url') is null, 'meeting link hidden until 15 minutes before');
select test.check((public.list_notifications() ->> 'unread_count')::int >= 3, 'notifications arrive');
select public.read_all_notifications();
select test.check((public.list_notifications() ->> 'unread_count')::int = 0, 'mark all read');
reset role;

-- ---------------------------------------------------------------- storage rules
select test.login(:'priya_id');
set role authenticated;
insert into storage.objects (bucket_id, name) values ('submissions', :'priya_id' || '/report.pdf');
select test.expect_error(format($$insert into storage.objects (bucket_id, name) values ('submissions', '%s/report.pdf')$$, :'rahul_id'), '42501');
select test.expect_error($$insert into storage.objects (bucket_id, name) values ('thumbnails', 'x.png')$$, '42501');
reset role;
select test.login(:'admin_id');
set role authenticated;
insert into storage.objects (bucket_id, name) values ('thumbnails', 'course.png');
reset role;

-- ---------------------------------------------------------------- student Rahul: cannot see Priya's things; buys a course
select test.login(:'rahul_id');
set role authenticated;
select test.expect_error(format('select public.certificate_details(%L)', :'cert_id'), 'not_found');
select test.expect_error(format('select public.my_assignment(%L)', :'assignment_id'), 'forbidden');
select test.expect_error(format('select public.get_quiz(%L)', :'quiz_id'), 'forbidden');
select test.expect_error(format('select public.payment_mark_paid(%L, %L)', 'order_x', 'pay_x'), '42501');
reset role;

set role service_role;
select test.check((public.payment_prepare(:'rahul_id', :'paid_course') ->> 'price')::numeric = 1499, 'payment prepared');
select test.expect_error(format('select public.payment_prepare(%L, %L)', :'rahul_id', :'free_course'), 'free_course');
select test.expect_error(format('select public.payment_prepare(%L, %L)', :'admin_id', :'paid_course'), 'forbidden');
select public.payment_record_order(:'rahul_id', :'paid_course', 1499, 'order_TEST1');
select test.expect_error(format('select public.payment_mark_paid(%L, %L, %L, %L)', 'order_TEST1', 'pay_1', 'sig', :'priya_id'), 'not_found');
select test.check((public.payment_mark_paid('order_TEST1', 'pay_1', 'sig', :'rahul_id') ->> 'status') = 'paid', 'payment verified');
select test.check((public.payment_mark_paid('order_TEST1', 'pay_1') ->> 'status') = 'paid', 'webhook after verify is harmless');
select test.expect_error(format('select public.payment_prepare(%L, %L)', :'rahul_id', :'paid_course'), 'already_enrolled');
reset role;

select test.login(:'rahul_id');
set role authenticated;
select test.check((public.course_lessons(:'paid_course') -> 'course' ->> 'id') = :'paid_course', 'paid course unlocked after payment');
select test.check((public.my_payments() -> 0 ->> 'status') = 'paid', 'my payments');
select test.check((select count(*) from jsonb_array_elements(public.list_notifications() -> 'items') n where n ->> 'title' = 'Payment successful') = 1, 'payment notification once');
reset role;

-- ---------------------------------------------------------------- admin reviews and manages
select test.login(:'admin_id');
set role authenticated;
select (public.admin_submissions() -> 'items' -> 0 ->> 'id') as submission_id \gset
select test.expect_error(format('select public.admin_grade_submission(%L, 11)', :'submission_id'), 'marks_exceed_max');
select test.check((public.admin_grade_submission(:'submission_id', 8.5, 'Good work') ->> 'status') = 'reviewed', 'graded');
select test.check((public.admin_submissions(p_status => 'reviewed', p_search => 'priya') ->> 'total')::int = 1, 'submission filters');
select test.check((public.admin_payments() -> 'summary' ->> 'revenue')::numeric = 1499, 'revenue summary');
select test.check((public.admin_dashboard() -> 'stats' ->> 'total_revenue')::numeric = 1499, 'dashboard revenue');
select test.check(jsonb_array_length(public.admin_dashboard() -> 'enrollments_series') = 14, '14-day series');
select test.expect_error(format('select public.admin_delete_course(%L)', :'paid_course'), 'course_has_payments');
select test.check((public.admin_students(p_search => 'rahul') -> 'items' -> 0 ->> 'enrolled_count')::int = 1, 'student list');
select test.check(jsonb_array_length(public.admin_student(:'priya_id') -> 'quizzes') = 1, 'student detail');
select test.check(jsonb_array_length(public.admin_certificates()) = 1, 'certificates list');
select test.check(jsonb_array_length(public.admin_quiz_attempts(:'quiz_id')) = 1, 'quiz attempts');
select test.check((public.admin_broadcast('Holiday notice', 'No class on Monday') ->> 'message') = 'Notification sent to 2 student(s)', 'broadcast');
select test.check(jsonb_array_length(public.admin_demo_requests()) = 1 and jsonb_array_length(public.admin_contact_messages()) = 1, 'leads visible');
select (public.admin_demo_requests() -> 0 ->> 'id') as demo_id \gset
select test.check((public.admin_toggle_demo_contacted(:'demo_id') ->> 'is_contacted')::boolean, 'demo marked contacted');
select test.check((public.admin_update_course(:'free_course', '{"title": "SEO Fundamentals 2026"}') ->> 'slug') = 'seo-fundamentals-2026', 'slug follows title');
select test.check(jsonb_array_length(public.admin_update_quiz(:'quiz_id', format('{"questions": [{"text": "New Q", "options": [{"text": "A", "is_correct": true}, {"text": "B"}]}]}')::jsonb) -> 'questions') = 1, 'quiz questions replaced');
select test.check((public.admin_settings() ->> 'platform_name') = 'GTapex Academy', 'settings');
select public.admin_set_student_status(:'rahul_id', false);
reset role;

select test.login(:'rahul_id');
set role authenticated;
select test.expect_error('select public.get_me()', 'account_disabled');
select test.expect_error(format('select public.course_lessons(%L)', :'paid_course'), 'account_disabled');
reset role;

select test.login(:'priya_id');
set role authenticated;
select test.expect_error(format($$select public.submit_assignment(%L, 'changed')$$, :'assignment_id'), 'already_reviewed');
select test.check((select count(*) from jsonb_array_elements(public.list_notifications() -> 'items') n where n ->> 'title' like 'Assignment graded%' and n ->> 'message' = 'You scored 8.5/10.') = 1, 'grade notification');
reset role;

select test.logout();
\echo 'API tests passed'
