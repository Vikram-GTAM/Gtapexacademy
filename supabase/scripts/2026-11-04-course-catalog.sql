-- Run once in Supabase dashboard > SQL Editor on the live project. All-or-nothing: on any error nothing is kept.
-- Adds six courses with online (price) and offline (offline_price) prices. They have no lessons yet.
begin;

-- Course catalog: Marketing Analytics stays first, then the new courses in this order.
update public.courses set created_at = now() where id = '5d08e624-49b2-460f-8464-fe4cf0dbedef';

insert into public.courses (title, slug, short_description, description, category, difficulty, price, offline_price, is_published, created_at) values
  ('Website & Landing Marketing', 'website-landing-marketing',
   'Plan websites and landing pages that turn visitors into customers.',
   'Plan websites and landing pages that turn visitors into customers.',
   'Website Marketing', 'beginner', 4999, 14999, true, now() - interval '1 minute'),
  ('Social Media & Content Marketing', 'social-media-content-marketing',
   'Grow an audience on social media with content that connects.',
   'Grow an audience on social media with content that connects.',
   'Social Media', 'beginner', 4999, 14999, true, now() - interval '2 minutes'),
  ('SEO & AI Search Optimization', 'seo-ai-search-optimization',
   'Get found on Google and in AI search results.',
   'Get found on Google and in AI search results.',
   'SEO', 'beginner', 4999, 14999, true, now() - interval '3 minutes'),
  ('Digital Marketing Professional', 'digital-marketing-professional',
   'Build skills across the main digital marketing channels.',
   'Build skills across the main digital marketing channels.',
   'Digital Marketing', 'beginner', 9999, 39999, true, now() - interval '4 minutes'),
  ('Graphic Designer', 'graphic-designer',
   'Learn to create clear, professional graphics for brands and marketing.',
   'Learn to create clear, professional graphics for brands and marketing.',
   'Graphic Design', 'beginner', 4999, 19999, true, now() - interval '5 minutes'),
  ('Video Editing', 'video-editing',
   'Learn to edit engaging videos for social media and marketing.',
   'Learn to edit engaging videos for social media and marketing.',
   'Video Editing', 'beginner', 4999, 19999, true, now() - interval '6 minutes');

commit;
