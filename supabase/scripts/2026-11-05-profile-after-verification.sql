-- Run once in Supabase dashboard > SQL Editor on the live project. All-or-nothing: on any error nothing is kept.
-- Safe to run twice. Removes nothing. Existing unverified profiles stay until you delete those users.
begin;

-- Student profiles are created when the email is verified, not at sign-up, so unverified sign-ups stay out of the app.
-- Supabase Auth still has to hold the email and hashed password in auth.users until the link is clicked.
create or replace function private.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.email_confirmed_at is null then return new; end if;
  insert into public.profiles (id, name, email, role)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'name'), ''), split_part(new.email, '@', 1)),
    lower(new.email),
    'student'
  )
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_verified on auth.users;
create trigger on_auth_user_verified after update of email_confirmed_at on auth.users
  for each row when (old.email_confirmed_at is null and new.email_confirmed_at is not null)
  execute function private.handle_new_user();

commit;

-- Unverified people who already have a profile from before this change. You can delete them on the Users page.
select count(*) as old_unverified_profiles
from public.profiles p join auth.users u on u.id = p.id
where u.email_confirmed_at is null;
