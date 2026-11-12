-- A profile appears only once the email is verified. Runs last, after test_api.sql created the helpers.
\set ON_ERROR_STOP 1
reset role;

insert into auth.users (email, raw_user_meta_data, email_confirmed_at) values ('Waiting@Gtapex.test', '{"name":"Waiting Student","role":"admin"}', null);
select id as waiting_id from auth.users where email = 'Waiting@Gtapex.test' \gset
select test.check((select count(*) = 0 from public.profiles where id = :'waiting_id'), 'unverified sign-up: no profile');
select test.check((select count(*) = 1 from auth.users where id = :'waiting_id'), 'unverified sign-up: Supabase still holds the login');

select id as admin_id from auth.users where email = 'admin@gtapex.test' \gset
select test.login(:'admin_id');
set role authenticated;
select test.check((public.admin_students('Waiting Student') ->> 'total')::int = 0 and (public.admin_students('waiting@gtapex.test') ->> 'total')::int = 0, 'unverified sign-up: not in the admin student list');
reset role;

update auth.users set email = 'waiting2@gtapex.test' where id = :'waiting_id';
select test.check((select count(*) = 0 from public.profiles where id = :'waiting_id'), 'changing an unverified email: still no profile');
update auth.users set raw_user_meta_data = raw_user_meta_data || '{"x":1}' where id = :'waiting_id';
select test.check((select count(*) = 0 from public.profiles where id = :'waiting_id'), 'other updates: still no profile');

update auth.users set email_confirmed_at = now() where id = :'waiting_id';
select test.check((select count(*) = 1 from public.profiles where id = :'waiting_id' and name = 'Waiting Student' and email = 'waiting2@gtapex.test' and role = 'student'), 'verifying creates the profile, always as a student');
select test.login(:'admin_id');
set role authenticated;
select test.check((public.admin_students('Waiting Student') ->> 'total')::int = 1, 'verified: appears in the admin student list');
reset role;

update public.profiles set name = 'Renamed' where id = :'waiting_id';
update auth.users set email_confirmed_at = now() where id = :'waiting_id';
select test.check((select count(*) = 1 from public.profiles where id = :'waiting_id' and name = 'Renamed'), 'verified time updated again: profile untouched');

insert into auth.users (email, raw_user_meta_data, email_confirmed_at) values ('direct@gtapex.test', '{"name":"Direct"}', now());
select test.check((select count(*) = 1 from public.profiles p join auth.users u on u.id = p.id where u.email = 'direct@gtapex.test'), 'already verified at creation: profile created');

-- Someone who signed up before this change already has a profile: verifying later must not fail or overwrite it.
insert into auth.users (email, email_confirmed_at) values ('old@gtapex.test', null);
select id as old_id from auth.users where email = 'old@gtapex.test' \gset
insert into public.profiles (id, name, email, role) values (:'old_id', 'Old Name', 'old@gtapex.test', 'student');
update auth.users set email_confirmed_at = now() where id = :'old_id';
select test.check((select count(*) = 1 from public.profiles where id = :'old_id' and name = 'Old Name'), 'older unverified profile: verifying keeps it');

delete from auth.users where email in ('waiting2@gtapex.test', 'direct@gtapex.test', 'old@gtapex.test');
select test.check((select count(*) = 0 from public.profiles where email in ('waiting2@gtapex.test', 'direct@gtapex.test', 'old@gtapex.test')), 'deleting a user removes the profile');
