-- Make an existing account an admin. Admins can never be created from the website.
-- 1. Sign up on the website with the admin's email and a strong password.
-- 2. In the Supabase dashboard open SQL Editor, paste this, change the email, and run it.
update public.profiles set role = 'admin' where email = lower('karthikkanakala2004@gmail.com') returning id, name, email, role;
