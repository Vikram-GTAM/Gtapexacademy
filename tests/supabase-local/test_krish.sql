-- Enquiries from Krish. Runs after test_api.sql, which creates the helpers and accounts.
\set ON_ERROR_STOP 1
select id as admin_id from auth.users where email = 'admin@gtapex.test' \gset
select id as priya_id from auth.users where email = 'priya@gtapex.test' \gset

-- Visitors who are not signed in can send one.
set role anon;
select public.send_chat_enquiry('Asha Rao', '+91 90000 00000', 'SEO', 'I work weekdays');
select public.send_chat_enquiry('Vikram', 'Vikram@Example.com', 'Not sure yet', null);
select public.send_chat_enquiry('Neha', '9000000000');
select test.expect_error($$select public.send_chat_enquiry('A', '9000000000')$$, 'validation_error');
select test.expect_error($$select public.send_chat_enquiry('Asha', 'not a phone')$$, 'validation_error');
select test.expect_error($$select public.send_chat_enquiry('Asha', '123')$$, 'validation_error');
select test.expect_error($$select public.send_chat_enquiry('Asha', '')$$, 'validation_error');
select test.expect_error($$select public.send_chat_enquiry('Asha', '9000000000', repeat('x', 81))$$, 'validation_error');
select test.expect_error($$select public.send_chat_enquiry('Asha', '9000000000', 'SEO', repeat('x', 1001))$$, 'validation_error');
select test.expect_error('select public.admin_contact_messages()', '42501');
select test.expect_error('select * from public.contact_messages', '42501');
reset role;

-- Signed-in students can too.
select test.login(:'priya_id');
set role authenticated;
select public.send_chat_enquiry('Priya', '9111111111', 'Digital Marketing', null);
select test.expect_error('select public.admin_contact_messages()', 'forbidden');
reset role;

-- The admin sees them in Contact messages, with the right details in the right places.
select test.login(:'admin_id');
set role authenticated;
select test.check((select count(*) from jsonb_array_elements(public.admin_contact_messages()) m where m ->> 'subject' like 'Krish chat:%') = 4, 'admin sees all four chat enquiries');
select test.check((select m ->> 'phone' = '+91 90000 00000' and m ->> 'email' is null and m ->> 'subject' = 'Krish chat: SEO' and m ->> 'message' = 'I work weekdays' from jsonb_array_elements(public.admin_contact_messages()) m where m ->> 'name' = 'Asha Rao'), 'phone enquiry saved');
select test.check((select m ->> 'email' = 'vikram@example.com' and m ->> 'phone' is null and m ->> 'message' = 'No extra details given.' from jsonb_array_elements(public.admin_contact_messages()) m where m ->> 'name' = 'Vikram'), 'email enquiry saved');
select test.check((select m ->> 'subject' = 'Krish chat: Not sure yet' from jsonb_array_elements(public.admin_contact_messages()) m where m ->> 'name' = 'Neha'), 'interest defaults to not sure');
select test.check((select m ->> 'is_read' = 'false' from jsonb_array_elements(public.admin_contact_messages()) m where m ->> 'name' = 'Neha'), 'new enquiries are unread');
reset role;

-- The Contact page form still needs an email.
set role anon;
select test.expect_error($$select public.send_contact_message('Meera', '', 'Hello', 'Hello there')$$, 'validation_error');
reset role;
