-- Run once in Supabase dashboard > SQL Editor on the live project. All-or-nothing: on any error nothing is kept.
-- Permanently deletes every old course except Marketing Analytics and AI driven marketing,
-- along with their lessons, quizzes, assignments, live classes and enrollments.
begin;

-- Stop, keeping everything, if anyone has paid for one of these courses.
do $$
begin
  if exists (select 1 from public.payments where status = 'paid' and course_id in (
    '4c4abdb5-f903-40f7-b4f5-cdf3aac728c7', '71c75253-c3ff-4e5a-813f-8f8d6f5adce6',
    '7b13b51a-96c0-41b0-af91-f81cec4591a8', 'f42beb1a-1954-4957-9711-0b1adbf584af')) then
    raise exception 'One of these courses has paid purchases, so nothing was deleted.';
  end if;
end $$;

-- Remove old courses: Google Ads & PPC Mastery, Content Marketing & Copywriting,
-- Social Media Marketing Strategy, SEO Fundamentals: Rank on Google.
delete from public.courses where id in (
  '4c4abdb5-f903-40f7-b4f5-cdf3aac728c7', '71c75253-c3ff-4e5a-813f-8f8d6f5adce6',
  '7b13b51a-96c0-41b0-af91-f81cec4591a8', 'f42beb1a-1954-4957-9711-0b1adbf584af');

commit;
