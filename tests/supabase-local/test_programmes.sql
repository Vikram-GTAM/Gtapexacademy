-- Course length and offline-only courses. Runs after test_api.sql, which creates the helpers and accounts.
\set ON_ERROR_STOP 1
select id as admin_id from auth.users where email = 'admin@gtapex.test' \gset
select id as priya_id from auth.users where email = 'priya@gtapex.test' \gset

select test.login(:'admin_id');
set role authenticated;
select test.expect_error($$select public.admin_create_course('{"title": "No price", "offline_only": true}')$$, 'validation_error');
select test.expect_error($$select public.admin_create_course('{"title": "Zero price", "offline_only": true, "offline_price": 0}')$$, 'validation_error');
select test.expect_error($$select public.admin_create_course('{"title": "Bad length", "duration_months": 0}')$$, 'validation_error');
select test.expect_error($$select public.admin_create_course('{"title": "Bad length", "duration_months": 61}')$$, 'validation_error');
select test.expect_error($$select public.admin_create_course('{"title": "Bad length", "duration_months": 2.5}')$$, 'validation_error');
select test.expect_error($$select public.admin_create_course('{"title": "Bad length", "duration_months": "four"}')$$, 'validation_error');

select (public.admin_create_course('{"title": "Classroom Programme", "offline_only": true, "offline_price": 59999, "price": 1, "duration_months": 8, "is_published": true}')) ->> 'id' as prog \gset
select (public.admin_create_course('{"title": "Hybrid Course", "price": 4999, "offline_price": 14999, "duration_months": 4, "is_published": true}')) ->> 'id' as hybrid \gset
select (public.admin_create_course('{"title": "No Length", "offline_only": true, "offline_price": 40000, "is_published": true}')) ->> 'id' as nolen \gset

select test.check((public.admin_course(:'prog') ->> 'price')::numeric = 59999, 'offline-only price mirrors the classroom price, whatever was sent');
select test.check((public.admin_course(:'prog') ->> 'duration_months')::int = 8, 'length saved');
select test.check((public.admin_course(:'nolen') -> 'duration_months') = 'null'::jsonb, 'length is optional');

-- A publish toggle keeps everything; a new classroom price moves the mirrored price; un-ticking restores a separate online price.
select public.admin_update_course(:'prog', '{"is_published": true}');
select test.check((public.admin_course(:'prog') ->> 'offline_only')::boolean and (public.admin_course(:'prog') ->> 'duration_months')::int = 8, 'partial update keeps the fields');
select public.admin_update_course(:'prog', '{"offline_price": 60000}');
select test.check((public.admin_course(:'prog') ->> 'price')::numeric = 60000, 'price follows the classroom price');
select test.expect_error(format($$select public.admin_update_course(%L, '{"offline_price": null}')$$, :'prog'), 'validation_error');
select public.admin_update_course(:'nolen', '{"offline_only": false, "price": 500}');
select test.check((public.admin_course(:'nolen') ->> 'price')::numeric = 500, 'can become an online course again');
select public.admin_update_course(:'nolen', '{"offline_only": true}');
reset role;

-- Visitors see both fields.
select test.logout();
set role anon;
select test.check((public.get_course(:'prog') ->> 'offline_only')::boolean, 'course page says offline only');
select test.check((public.get_course(:'prog') ->> 'duration_months')::int = 8, 'course page shows the length');
select test.check((public.get_course(:'hybrid') ->> 'offline_only')::boolean = false, 'normal courses are not offline only');
select test.check(not exists (select 1 from jsonb_array_elements(public.list_courses(p_free_only => true, p_page_size => 60) -> 'items') x where (x ->> 'offline_only')::boolean), 'offline-only courses are never listed as free');
reset role;

-- A student cannot get in for free or pay online.
select test.login(:'priya_id');
set role authenticated;
select test.expect_error(format($$select public.enroll_free_course(%L)$$, :'prog'), 'payment_required');
select test.expect_error(format($$select public.enroll_free_course(%L)$$, :'nolen'), 'payment_required');
reset role;
set role service_role;
select test.expect_error(format($$select public.payment_prepare(%L, %L)$$, :'priya_id', :'prog'), 'offline_only');
select test.expect_error(format($$select public.payment_prepare(%L, %L, 'online')$$, :'priya_id', :'prog'), 'offline_only');
select test.check((public.payment_prepare(:'priya_id', :'prog', 'offline') ->> 'price')::numeric = 60000, 'offline-only programme charges its classroom price');
select test.check((public.payment_prepare(:'priya_id', :'hybrid', 'offline') ->> 'price')::numeric = 14999, 'offline card charges the offline price');
select test.check((public.payment_prepare(:'priya_id', :'hybrid', 'online') ->> 'price')::numeric = 4999, 'online card charges the online price');
select test.expect_error(format($$select public.payment_prepare(%L, %L, 'free')$$, :'priya_id', :'hybrid'), 'validation_error');
select test.expect_error(format($$select public.payment_prepare(%L, %L, null)$$, :'priya_id', :'hybrid'), 'validation_error');
select test.check((public.payment_prepare(:'priya_id', :'hybrid') ->> 'price')::numeric = 4999, 'normal courses can still be bought online');
reset role;

-- A course with no offline price cannot be bought for offline learning.
select test.login(:'admin_id');
set role authenticated;
select (public.admin_create_course('{"title": "Online Only", "price": 999, "is_published": true}')) ->> 'id' as online_only \gset
reset role;
set role service_role;
select test.expect_error(format($$select public.payment_prepare(%L, %L, 'offline')$$, :'priya_id', :'online_only'), 'offline_unavailable');
reset role;

-- Visitors and students cannot call the payment steps themselves, so they cannot choose an amount.
set role anon;
select test.expect_error(format($$select public.payment_prepare(%L, %L, 'offline')$$, :'priya_id', :'hybrid'), '42501');
select test.expect_error(format($$select public.payment_record_order(%L, %L, 1, 'order_CHEAP', 'offline')$$, :'priya_id', :'hybrid'), '42501');
reset role;
select test.login(:'priya_id');
set role authenticated;
select test.expect_error(format($$select public.payment_prepare(%L, %L, 'offline')$$, :'priya_id', :'hybrid'), '42501');
select test.expect_error(format($$select public.payment_record_order(%L, %L, 1, 'order_CHEAP', 'offline')$$, :'priya_id', :'hybrid'), '42501');
reset role;

-- A full offline purchase: recorded, paid, enrolled, and visible to the admin as offline.
set role service_role;
select public.payment_record_order(:'priya_id', :'prog', 60000, 'order_OFFLINE1', 'offline');
select public.payment_mark_paid('order_OFFLINE1', 'pay_OFFLINE1', 'sig', :'priya_id');
reset role;
select test.check(private.is_enrolled(:'priya_id', :'prog'), 'offline purchase enrolls the student');
select test.login(:'admin_id');
set role authenticated;
select test.check((select (x ->> 'learning_mode') = 'offline' and (x ->> 'amount')::numeric = 60000
                   from jsonb_array_elements(public.admin_payments(p_search => 'Classroom Programme') -> 'items') x limit 1), 'admin sees the offline payment');
reset role;

-- The admin can pick out each kind of buyer.
select test.login(:'admin_id');
set role authenticated;
select test.check((select count(*) from jsonb_array_elements(public.admin_payments(p_mode => 'offline') -> 'items') x where x ->> 'learning_mode' <> 'offline') = 0, 'offline filter shows only offline');
select test.check(jsonb_array_length(public.admin_payments(p_mode => 'offline') -> 'items') >= 1, 'offline filter finds the purchase');
select test.check((select count(*) from jsonb_array_elements(public.admin_payments(p_mode => 'online') -> 'items') x where x ->> 'learning_mode' <> 'online') = 0, 'online filter shows only online');
select test.check(jsonb_array_length(public.admin_payments(p_mode => 'online') -> 'items') >= 1, 'online filter finds purchases');
select test.check((public.admin_payments() -> 'summary' ->> 'offline_count')::int = 1, 'offline buyers counted');
select test.check((public.admin_payments() -> 'summary' ->> 'online_count')::int = (public.admin_payments() -> 'summary' ->> 'paid_count')::int - 1, 'online buyers counted');
select test.expect_error($$select public.admin_payments(p_mode => 'free')$$, 'validation_error');
select test.check((select x ->> 'learning_mode' from jsonb_array_elements(public.admin_student(:'priya_id') -> 'courses') x where x ->> 'course_id' = :'prog') = 'offline', 'student page shows offline');
reset role;
select test.login(:'priya_id');
set role authenticated;
select test.expect_error($$select public.admin_payments(p_mode => 'offline')$$, 'forbidden');
select test.expect_error(format($$select public.admin_student(%L)$$, :'priya_id'), 'forbidden');
reset role;
select test.logout();
set role anon;
select test.expect_error($$select public.admin_payments(p_mode => 'offline')$$, '42501');
reset role;

-- Even a direct database change cannot leave an offline-only course looking free.
select test.expect_error(format($$update public.courses set price = 0 where id = %L$$, :'prog'), 'courses_offline_only_priced');
select test.logout();
\echo 'Programme tests passed'
