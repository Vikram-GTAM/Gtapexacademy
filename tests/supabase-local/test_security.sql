-- Attack tests from the code audit. Runs last, after test_api.sql created the helpers and accounts.
\set ON_ERROR_STOP 1
select id as admin_id from auth.users where email = 'admin@gtapex.test' \gset
select id as priya_id from auth.users where email = 'priya@gtapex.test' \gset
select assignment_id from public.assignment_submissions where user_id = :'priya_id' limit 1 \gset
select id as open_assignment from public.assignments where not exists (select 1 from public.assignment_submissions s where s.assignment_id = assignments.id and s.user_id = :'priya_id' and s.status = 'reviewed') and course_id in (select course_id from public.enrollments where user_id = :'priya_id') limit 1 \gset

-- ---------------------------------------------------------------- Harmful links in assignments
select test.login(:'priya_id');
set role authenticated;
select test.expect_error(format($$select public.submit_assignment(%L, null, %L)$$, :'assignment_id', format('javascript:alert(1)//https://x.supabase.co/storage/v1/object/public/submissions/%s/a.pdf', :'priya_id')), 'invalid_file');
select test.expect_error(format($$select public.submit_assignment(%L, null, %L)$$, :'assignment_id', format('https://evil.example/storage/v1/object/public/submissions/%s/a.pdf', :'priya_id')), 'invalid_file');
select test.expect_error(format($$select public.submit_assignment(%L, null, %L)$$, :'assignment_id', format('http://x.supabase.co/storage/v1/object/public/submissions/%s/a.pdf', :'priya_id')), 'invalid_file');
select test.expect_error(format($$select public.submit_assignment(%L, null, %L)$$, :'assignment_id', format('https://x.supabase.co/storage/v1/object/public/submissions/%s/../../a.pdf"><script>', :'priya_id')), 'invalid_file');
select test.expect_error(format($$select public.submit_assignment(%L, null, %L)$$, :'assignment_id', 'https://x.supabase.co/storage/v1/object/public/submissions/00000000-0000-0000-0000-000000000000/a.pdf'), 'invalid_file');

-- ---------------------------------------------------------------- Becoming an admin, or reading other people's data
select test.expect_error($$update public.profiles set role = 'admin'$$, '42501');
select test.expect_error('select * from public.payments', '42501');
select test.expect_error('select * from public.profiles', '42501');
select test.expect_error('select * from public.quiz_options', '42501');
select test.expect_error('select private.auth_user()', '42501');
select test.expect_error('select * from private.rate_limits', '42501');
select test.check((public.update_my_profile('Priya') ->> 'role') = 'student', 'changing your profile keeps you a student');

-- ---------------------------------------------------------------- Getting a course without paying
select test.expect_error($$select public.payment_mark_paid('order', 'pay')$$, '42501');
select test.expect_error(format($$select public.payment_prepare(%L, gen_random_uuid())$$, :'priya_id'), '42501');
select test.expect_error(format($$select public.payment_record_order(%L, gen_random_uuid(), 1, 'o')$$, :'priya_id'), '42501');
reset role;

-- A student tries every admin function: all must refuse before doing anything.
create temp table admin_calls on commit drop as select 1 as x limit 0;
do $$
declare
  f record;
  call_sql text;
  failures text[] := '{}';
  tried int := 0;
  err_hint text;
  err_state text;
begin
  perform set_config('role', 'authenticated', true);
  for f in
    select p.proname, p.oid::regprocedure as sig, p.proargtypes::regtype[] as args, p.pronargs
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'admin\_%'
  loop
    tried := tried + 1;
    select 'select public.' || f.proname || '(' || coalesce(string_agg('null::' || t::text, ','), '') || ')' into call_sql
    from unnest(f.args) t;
    begin
      execute call_sql;
      failures := failures || f.proname::text;
    exception when others then
      get stacked diagnostics err_hint = pg_exception_hint, err_state = returned_sqlstate;
      if coalesce(err_hint, '') <> 'forbidden' then failures := failures || (f.proname::text || ':' || coalesce(err_hint, err_state)); end if;
    end;
  end loop;
  perform set_config('role', 'none', true);
  if array_length(failures, 1) > 0 then raise exception 'admin functions not refusing a student: %', failures; end if;
  if tried < 20 then raise exception 'expected many admin functions, found %', tried; end if;
  raise notice 'student refused by all % admin functions', tried;
end $$;

-- A paid order can't be switched back to failed.
insert into public.payments (user_id, course_id, amount, currency, status, razorpay_order_id, learning_mode)
select :'priya_id', id, price, 'INR', 'paid', 'order_security_test', 'online' from public.courses where price > 0 limit 1;
select public.payment_mark_failed('order_security_test', :'priya_id');
select test.check((select status::text = 'paid' from public.payments where razorpay_order_id = 'order_security_test'), 'a paid order stays paid');
-- Another student's order can't be claimed.
select test.expect_error($$select public.payment_mark_paid('order_security_test', 'pay', 'sig', gen_random_uuid())$$, 'not_found');
delete from public.payments where razorpay_order_id = 'order_security_test';

-- ---------------------------------------------------------------- Lesson videos stay private
select test.check(public.get_course(c.id)::text !~ 'video_url', 'public course page has no lesson video links') from public.courses c join public.course_modules m on m.course_id = c.id limit 1;

-- ---------------------------------------------------------------- Limits on the public forms
select set_config('request.headers', '{"x-forwarded-for": "203.0.113.5, 10.0.0.1"}', false);
set role anon;
do $$
begin
  for i in 1..10 loop perform public.book_demo('Spam', 'spam@example.com', '9000000000'); end loop;
  for i in 1..10 loop perform public.send_contact_message('Spam', 'spam@example.com', 'Hello', 'Hello there'); end loop;
  for i in 1..10 loop perform public.send_chat_enquiry('Spam', '9000000000'); end loop;
end $$;
select test.expect_error($$select public.book_demo('Spam', 'spam@example.com', '9000000000')$$, 'rate_limited');
select test.expect_error($$select public.send_contact_message('Spam', 'spam@example.com', 'Hello', 'Hello there')$$, 'rate_limited');
select test.expect_error($$select public.send_chat_enquiry('Spam', '9000000000')$$, 'rate_limited');
reset role;
select test.check((select count(*) = 10 from public.demo_requests where name = 'Spam'), 'exactly 10 saved, the 11th refused');
select test.check((select count(*) = 3 from private.rate_limits r where length(r.key) = 32 and r.key = md5('demo:203.0.113.5')) is not null, 'only a hash of the address is stored');
select test.check(not exists (select 1 from private.rate_limits where key like '%203.0.113%'), 'the address itself is never stored');
-- A different visitor isn't affected, and Cloudflare's address wins over a forged forwarded header.
select set_config('request.headers', '{"x-forwarded-for": "203.0.113.5", "cf-connecting-ip": "198.51.100.9"}', false);
set role anon;
select public.book_demo('Other', 'other@example.com', '9000000000');
reset role;
select set_config('request.headers', '', false);
select test.check((select count(*) = 1 from public.demo_requests where name = 'Other'), 'other visitors still get through');
-- Old hits expire.
update private.rate_limits set hit_at = now() - interval '2 hours';
select set_config('request.headers', '{"x-forwarded-for": "203.0.113.5"}', false);
set role anon;
select public.book_demo('Later', 'later@example.com', '9000000000');
reset role;
select set_config('request.headers', '', false);
select test.check((select count(*) = 1 from public.demo_requests where name = 'Later'), 'the limit resets after an hour');
delete from public.demo_requests where name in ('Spam', 'Other', 'Later');
delete from public.contact_messages where name = 'Spam';
