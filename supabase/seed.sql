-- Starter course content exported from the original FastAPI database on 2026-10-30.
-- Courses, modules, lessons, resources, assignments, quizzes and live classes only: no users, progress or payments.
-- Load it once into a new project (SQL editor, or `supabase db reset` locally). Edit or delete anything from the admin panel.
-- Deadlines and live-class times are written relative to now() so the demo ones are upcoming when loaded.

insert into public.courses (id, title, slug, short_description, description, category, difficulty, price, thumbnail_url, is_published, features, created_at) values
  ('4c4abdb5-f903-40f7-b4f5-cdf3aac728c7', 'Google Ads & PPC Mastery', 'google-ads-ppc-mastery', 'Plan, launch and optimise paid campaigns across Search, Display and YouTube.', 'Build profitable pay-per-click campaigns from scratch: structure accounts, write high-CTR ads, set smart bidding and scale what works while cutting wasted spend.', 'Paid Advertising', 'intermediate', 1499.00, NULL, true, '["Live campaign walkthroughs", "Budget planning templates", "Live doubt-clearing classes", "Certificate of completion"]'::jsonb, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('5d08e624-49b2-460f-8464-fe4cf0dbedef', 'AI & Analytics for Marketers', 'ai-analytics-for-marketers', 'Use GA4, dashboards and AI tools to make faster, smarter marketing decisions.', 'Set up GA4 properly, build reporting dashboards, and apply AI for research, content, segmentation and campaign optimisation without losing brand quality.', 'AI & Analytics', 'advanced', 2999.00, NULL, true, '["GA4 and dashboard templates", "Capstone growth project", "Live classes", "Certificate of completion"]'::jsonb, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('71c75253-c3ff-4e5a-813f-8f8d6f5adce6', 'Content Marketing & Copywriting', 'content-marketing-copywriting', 'Write content that attracts, persuades and converts.', 'Learn the content funnel, storytelling and conversion copywriting frameworks, then build a repeatable editorial workflow for blogs, landing pages and email.', 'Content Marketing', 'beginner', 0.00, NULL, true, '["Copywriting critiques", "Portfolio project", "Certificate of completion"]'::jsonb, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('7b13b51a-96c0-41b0-af91-f81cec4591a8', 'Social Media Marketing Strategy', 'social-media-marketing-strategy', 'Grow an engaged audience on Instagram, LinkedIn, YouTube and more.', 'Create a platform-by-platform strategy, plan a content calendar, run paid social, and measure what actually moves followers, leads and sales.', 'Social Media', 'beginner', 999.00, NULL, true, '["Content calendar templates", "Quizzes after every module", "Certificate of completion"]'::jsonb, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('f42beb1a-1954-4957-9711-0b1adbf584af', 'SEO Fundamentals: Rank on Google', 'seo-fundamentals-rank-on-google', 'Learn keyword research, on-page SEO and link building that drives organic traffic.', 'A practical, hands-on introduction to search engine optimisation. You will research keywords, optimise pages, fix technical issues and build authority, then track the results in Search Console.', 'SEO', 'beginner', 0.00, NULL, true, '["Lifetime access", "Real website audit project", "Assignments with feedback", "Certificate of completion"]'::jsonb, '2026-10-08T20:23:42.510433+05:30'::timestamptz)
on conflict (id) do nothing;

insert into public.course_modules (id, course_id, title, position, created_at) values
  ('022f04d3-dde0-473f-b588-34d5d1670c49', 'f42beb1a-1954-4957-9711-0b1adbf584af', 'How Search Works', 0, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('3d340bcf-88d3-4f1d-98ed-84b7fd2f1beb', '5d08e624-49b2-460f-8464-fe4cf0dbedef', 'Measurement Foundations', 0, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('3d7ecf6f-e1d3-4aa2-8f81-fed80cafba9c', '4c4abdb5-f903-40f7-b4f5-cdf3aac728c7', 'PPC Foundations', 0, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('453a0ce1-9c37-4682-878e-17f16cd075f4', 'f42beb1a-1954-4957-9711-0b1adbf584af', 'On-Page & Technical SEO', 1, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('65a0d8b6-b973-4c62-b947-d2d04f243194', '7b13b51a-96c0-41b0-af91-f81cec4591a8', 'Strategy & Content', 0, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('6b4c15c8-65f1-420f-838a-76e449392b7f', '71c75253-c3ff-4e5a-813f-8f8d6f5adce6', 'Content Foundations', 0, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('95b442e5-3da4-45fe-8a0b-6391cd28c70d', '4c4abdb5-f903-40f7-b4f5-cdf3aac728c7', 'Optimise & Scale', 1, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('9e9fa8b8-83b0-4933-9555-25916337adfb', '7b13b51a-96c0-41b0-af91-f81cec4591a8', 'Growth & Measurement', 1, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('c57e7473-dde0-4d44-a86f-5b3879c695d6', '71c75253-c3ff-4e5a-813f-8f8d6f5adce6', 'Copy That Converts', 1, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('ea244c12-bd75-4484-83b2-713dc6cdf8ea', '5d08e624-49b2-460f-8464-fe4cf0dbedef', 'AI-Powered Marketing', 1, '2026-10-08T20:23:42.510433+05:30'::timestamptz)
on conflict (id) do nothing;

insert into public.lessons (id, module_id, title, description, video_url, duration_seconds, position, is_free_preview, created_at) values
  ('0402b898-f05e-4585-baff-eb7ab295becc', '3d7ecf6f-e1d3-4aa2-8f81-fed80cafba9c', 'Campaign and ad group structure', 'In this lesson of ''Google Ads & PPC Mastery'' we cover: campaign and ad group structure.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4', 960, 1, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('0485e742-a91a-46b7-8b22-c2d11b29f556', '65a0d8b6-b973-4c62-b947-d2d04f243194', 'Choosing platforms and audiences', 'In this lesson of ''Social Media Marketing Strategy'' we cover: choosing platforms and audiences.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4', 600, 0, true, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('06085d86-ae4a-46c5-b06f-6cbd374786f3', '9e9fa8b8-83b0-4933-9555-25916337adfb', 'Analytics and reporting', 'In this lesson of ''Social Media Marketing Strategy'' we cover: analytics and reporting.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4', 900, 2, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('079f6aa9-6795-4412-b318-291c93f1d8de', '9e9fa8b8-83b0-4933-9555-25916337adfb', 'Short-form video that performs', 'In this lesson of ''Social Media Marketing Strategy'' we cover: short-form video that performs.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4', 840, 0, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('0a576b8d-c7d0-4721-a95a-b3e730025114', '453a0ce1-9c37-4682-878e-17f16cd075f4', 'Title tags, headings and snippets', 'In this lesson of ''SEO Fundamentals: Rank on Google'' we cover: title tags, headings and snippets.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4', 900, 0, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('376cb28b-7bef-4287-9d8e-95c8076a176a', '3d7ecf6f-e1d3-4aa2-8f81-fed80cafba9c', 'How the ad auction works', 'In this lesson of ''Google Ads & PPC Mastery'' we cover: how the ad auction works.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4', 780, 0, true, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('38280c41-bfc7-4cf1-bc56-c94e9c67b6ac', '6b4c15c8-65f1-420f-838a-76e449392b7f', 'Headlines and hooks', 'In this lesson of ''Content Marketing & Copywriting'' we cover: headlines and hooks.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4', 660, 1, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('4b332db8-5b1e-41ca-86fb-6554a5e50417', '022f04d3-dde0-473f-b588-34d5d1670c49', 'Welcome & the SEO landscape', 'In this lesson of ''SEO Fundamentals: Rank on Google'' we cover: welcome & the seo landscape.', '/uploads/videos/f373594dc7714b8f95bb077f1fa03894.mp4', 420, 0, true, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('4e9ad395-d829-47c3-8696-ec4d4d618312', '3d340bcf-88d3-4f1d-98ed-84b7fd2f1beb', 'GA4 setup and events', 'In this lesson of ''AI & Analytics for Marketers'' we cover: ga4 setup and events.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4', 780, 0, true, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('59b2e9c0-3d0a-49c2-9789-4798a4136a62', '9e9fa8b8-83b0-4933-9555-25916337adfb', 'Paid social basics', 'In this lesson of ''Social Media Marketing Strategy'' we cover: paid social basics.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4', 720, 1, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('5ca04976-2e27-45af-838b-cfee48701eca', '3d340bcf-88d3-4f1d-98ed-84b7fd2f1beb', 'Attribution and funnels', 'In this lesson of ''AI & Analytics for Marketers'' we cover: attribution and funnels.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4', 960, 1, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('6c7b1950-776e-46d7-81e7-dd2a15e3c346', '95b442e5-3da4-45fe-8a0b-6391cd28c70d', 'Scaling and A/B testing', 'In this lesson of ''Google Ads & PPC Mastery'' we cover: scaling and a/b testing.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4', 540, 2, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('6e218ba0-c119-48fe-9c4a-ebf05b3a66e4', 'c57e7473-dde0-4d44-a86f-5b3879c695d6', 'Email and CTA copy', 'In this lesson of ''Content Marketing & Copywriting'' we cover: email and cta copy.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4', 600, 1, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('72c17680-f9e2-403e-998b-1c1cfb2d96f7', 'ea244c12-bd75-4484-83b2-713dc6cdf8ea', 'Automation and campaign optimisation', 'In this lesson of ''AI & Analytics for Marketers'' we cover: automation and campaign optimisation.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4', 840, 1, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('74176fd7-57ac-4ceb-a757-cf1af7b74d3b', '3d7ecf6f-e1d3-4aa2-8f81-fed80cafba9c', 'Writing ads that get clicks', 'In this lesson of ''Google Ads & PPC Mastery'' we cover: writing ads that get clicks.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4', 840, 2, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('7ac946cd-ada2-480b-b4ef-403fae43e170', '95b442e5-3da4-45fe-8a0b-6391cd28c70d', 'Bidding strategies and budgets', 'In this lesson of ''Google Ads & PPC Mastery'' we cover: bidding strategies and budgets.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4', 600, 0, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('7fe4f9d2-6f3d-4fe6-b2be-731ede7408b1', '453a0ce1-9c37-4682-878e-17f16cd075f4', 'Link building and authority', 'In this lesson of ''SEO Fundamentals: Rank on Google'' we cover: link building and authority.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4', 660, 2, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('8acd2f9d-eaaa-42cf-809b-6338fff6d4bb', '6b4c15c8-65f1-420f-838a-76e449392b7f', 'Know your audience and funnel', 'In this lesson of ''Content Marketing & Copywriting'' we cover: know your audience and funnel.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4', 540, 0, true, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('8f2aa866-f00a-415e-8d40-bc61be6e60f1', '95b442e5-3da4-45fe-8a0b-6391cd28c70d', 'Conversion tracking and ROAS', 'In this lesson of ''Google Ads & PPC Mastery'' we cover: conversion tracking and roas.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4', 900, 1, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('ad1aa932-703a-433f-98a8-0984065a1376', '453a0ce1-9c37-4682-878e-17f16cd075f4', 'Site speed and Core Web Vitals', 'In this lesson of ''SEO Fundamentals: Rank on Google'' we cover: site speed and core web vitals.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4', 720, 1, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('bb57b7a6-d5fb-4076-a630-5dce754fa395', '022f04d3-dde0-473f-b588-34d5d1670c49', 'Search intent and content mapping', 'In this lesson of ''SEO Fundamentals: Rank on Google'' we cover: search intent and content mapping.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4', 840, 2, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('bc02ca8a-8272-4bee-9b92-24851276cd5e', 'c57e7473-dde0-4d44-a86f-5b3879c695d6', 'Landing page copywriting', 'In this lesson of ''Content Marketing & Copywriting'' we cover: landing page copywriting.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4', 720, 0, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('c1592d3d-d13e-4781-b37d-e5145ffe772d', '65a0d8b6-b973-4c62-b947-d2d04f243194', 'Content pillars and calendars', 'In this lesson of ''Social Media Marketing Strategy'' we cover: content pillars and calendars.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4', 480, 1, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('ce63a1b6-05d5-44f8-8dea-1b7b25e9fab9', 'ea244c12-bd75-4484-83b2-713dc6cdf8ea', 'AI for research and content', 'In this lesson of ''AI & Analytics for Marketers'' we cover: ai for research and content.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4', 1020, 0, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('ee89ce29-223a-4137-ba61-fed0f60da964', '022f04d3-dde0-473f-b588-34d5d1670c49', 'Keyword research that converts', 'In this lesson of ''SEO Fundamentals: Rank on Google'' we cover: keyword research that converts.', 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4', 780, 1, false, '2026-10-08T20:23:42.510433+05:30'::timestamptz)
on conflict (id) do nothing;

insert into public.lesson_resources (id, lesson_id, title, file_url, created_at) values
  ('0b4075a5-17ef-4e03-bd8f-91fed7300268', '74176fd7-57ac-4ceb-a757-cf1af7b74d3b', 'Writing ads that get clicks - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('17b2af74-2f70-4668-adca-354451e3dc1a', 'c1592d3d-d13e-4781-b37d-e5145ffe772d', 'Content pillars and calendars - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('1c799c3a-c7dc-40b5-aad0-b5c58810de86', '6e218ba0-c119-48fe-9c4a-ebf05b3a66e4', 'Email and CTA copy - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('1d79e35c-d21a-4917-9a9e-233213b8d15b', 'bb57b7a6-d5fb-4076-a630-5dce754fa395', 'Search intent and content mapping - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('2759f4a5-be0c-435c-98a6-489e169a1b68', '376cb28b-7bef-4287-9d8e-95c8076a176a', 'How the ad auction works - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('31e9e1d8-85e7-4357-b22d-9b508284a7fa', '0a576b8d-c7d0-4721-a95a-b3e730025114', 'Title tags, headings and snippets - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('3cba3da2-722c-426a-9d61-cf61223a8246', '72c17680-f9e2-403e-998b-1c1cfb2d96f7', 'Automation and campaign optimisation - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('66e2583d-9e1b-4062-a0bc-7c4879d66561', '7fe4f9d2-6f3d-4fe6-b2be-731ede7408b1', 'Link building and authority - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('6e5f55f6-79a9-4ddc-9b16-107bce9fca05', '06085d86-ae4a-46c5-b06f-6cbd374786f3', 'Analytics and reporting - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('75e3f417-a74e-4e9d-a799-f141b00f2543', '8f2aa866-f00a-415e-8d40-bc61be6e60f1', 'Conversion tracking and ROAS - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('854c5b9f-0b0f-4a56-b149-28fa2f4fab98', 'ee89ce29-223a-4137-ba61-fed0f60da964', 'Keyword research that converts - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('8c3e049a-220d-4203-8017-dc8c65204a83', 'bc02ca8a-8272-4bee-9b92-24851276cd5e', 'Landing page copywriting - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('914cb5af-2983-48e0-9680-1128516452d5', '8acd2f9d-eaaa-42cf-809b-6338fff6d4bb', 'Know your audience and funnel - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('92218416-d197-4e7e-9abe-e8bb95e91151', '079f6aa9-6795-4412-b318-291c93f1d8de', 'Short-form video that performs - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('a3cae815-2d6e-419d-850e-9ef6e1cb00b3', '0402b898-f05e-4585-baff-eb7ab295becc', 'Campaign and ad group structure - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('aa792415-59cf-40d5-88b7-97ed00b9a801', '5ca04976-2e27-45af-838b-cfee48701eca', 'Attribution and funnels - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('b0d14ca6-22bf-4a44-bdfb-9b7c750cfc39', '4b332db8-5b1e-41ca-86fb-6554a5e50417', 'Welcome & the SEO landscape - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('b294a68d-c8f4-4e4b-a118-008ee5ac41c5', '59b2e9c0-3d0a-49c2-9789-4798a4136a62', 'Paid social basics - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('c09b3fe5-a7cd-4734-99dc-86de7f271c93', '6c7b1950-776e-46d7-81e7-dd2a15e3c346', 'Scaling and A/B testing - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('c2a22c2d-aeba-4939-8de8-c3051b96039d', '0485e742-a91a-46b7-8b22-c2d11b29f556', 'Choosing platforms and audiences - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('cd871eee-3591-404a-b8f3-3732799e9a43', '4e9ad395-d829-47c3-8696-ec4d4d618312', 'GA4 setup and events - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('ce4f8004-7405-4e0e-b219-0aa571654492', '38280c41-bfc7-4cf1-bc56-c94e9c67b6ac', 'Headlines and hooks - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('d8d0ba72-7977-46ec-ab24-3015bc68f5f6', 'ce63a1b6-05d5-44f8-8dea-1b7b25e9fab9', 'AI for research and content - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('d8fb5962-daa8-4ff0-9aab-269c6e2c2bc6', 'ad1aa932-703a-433f-98a8-0984065a1376', 'Site speed and Core Web Vitals - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('ee0511b8-3912-471f-a360-e6cbea85a7da', '7ac946cd-ada2-480b-b4ef-403fae43e170', 'Bidding strategies and budgets - slides', 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', '2026-10-08T20:23:42.510433+05:30'::timestamptz)
on conflict (id) do nothing;

insert into public.assignments (id, course_id, module_id, title, instructions, deadline, max_marks, allow_late, attachment_url, created_at) values
  ('0ae535f1-695a-40e4-b792-ce02083067bd', '71c75253-c3ff-4e5a-813f-8f8d6f5adce6', '6b4c15c8-65f1-420f-838a-76e449392b7f', 'Assignment 1: Content Foundations practice', 'Complete the exercises described in the lesson, then upload your solution file or paste your answer below. Explain your approach briefly.', now() + interval '604800 seconds', 100, false, NULL, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('7d31a64b-faf8-42c9-b903-c5363c093903', '5d08e624-49b2-460f-8464-fe4cf0dbedef', '3d340bcf-88d3-4f1d-98ed-84b7fd2f1beb', 'Assignment 1: Measurement Foundations practice', 'Complete the exercises described in the lesson, then upload your solution file or paste your answer below. Explain your approach briefly.', now() + interval '604800 seconds', 100, false, NULL, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('bd3e659c-b82d-4fb3-82fe-cf4a49ede8e5', '4c4abdb5-f903-40f7-b4f5-cdf3aac728c7', '3d7ecf6f-e1d3-4aa2-8f81-fed80cafba9c', 'Assignment 1: PPC Foundations practice', 'Complete the exercises described in the lesson, then upload your solution file or paste your answer below. Explain your approach briefly.', now() + interval '604800 seconds', 100, false, NULL, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('cb4dc4cc-49c2-4f51-8602-dfd0299d4663', '7b13b51a-96c0-41b0-af91-f81cec4591a8', '65a0d8b6-b973-4c62-b947-d2d04f243194', 'Assignment 1: Strategy & Content practice', 'Complete the exercises described in the lesson, then upload your solution file or paste your answer below. Explain your approach briefly.', now() + interval '604800 seconds', 100, false, NULL, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('fca96abe-60fd-44b1-bb0d-f60bd9f6f6c2', 'f42beb1a-1954-4957-9711-0b1adbf584af', '022f04d3-dde0-473f-b588-34d5d1670c49', 'Assignment 1: How Search Works practice', 'Complete the exercises described in the lesson, then upload your solution file or paste your answer below. Explain your approach briefly.', now() + interval '604800 seconds', 100, false, NULL, '2026-10-08T20:23:42.510433+05:30'::timestamptz)
on conflict (id) do nothing;

insert into public.quizzes (id, course_id, module_id, title, description, time_limit_minutes, show_results, is_published, created_at) values
  ('749e2c39-32f8-4af6-8971-97f868ea2e57', '4c4abdb5-f903-40f7-b4f5-cdf3aac728c7', NULL, 'PPC Foundations Quiz', 'Check your understanding. You can retake this quiz.', 10, true, true, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('8e2267a0-3853-4e4d-bb25-a4313eefa102', 'f42beb1a-1954-4957-9711-0b1adbf584af', NULL, 'How Search Works Quiz', 'Check your understanding. You can retake this quiz.', 10, true, true, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('f1f34541-89ac-49fd-8db9-dbc9e8c685aa', '7b13b51a-96c0-41b0-af91-f81cec4591a8', NULL, 'Strategy & Content Quiz', 'Check your understanding. You can retake this quiz.', 10, true, true, '2026-10-08T20:23:42.510433+05:30'::timestamptz)
on conflict (id) do nothing;

insert into public.quiz_questions (id, quiz_id, text, marks, position, created_at) values
  ('1e09df86-1b0c-40a7-a15d-43bcc94b28cc', '8e2267a0-3853-4e4d-bb25-a4313eefa102', 'Which element is the most important on-page signal for a page''s topic?', 1, 1, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('3726bbd7-8878-4720-9082-d4e1fce75776', '749e2c39-32f8-4af6-8971-97f868ea2e57', 'Which keyword match type is the most restrictive?', 1, 2, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('374425c9-fe86-4da2-a968-659b4fe4df1c', '749e2c39-32f8-4af6-8971-97f868ea2e57', 'What does ROAS measure?', 1, 1, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('418156f2-ddf7-4e15-95b4-9e45578a3bbc', 'f1f34541-89ac-49fd-8db9-dbc9e8c685aa', 'What is a content pillar?', 1, 0, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('47dd2ca6-e3b9-42b8-a3fa-751961aa9468', '749e2c39-32f8-4af6-8971-97f868ea2e57', 'In Google Ads, CTR is calculated as...', 1, 0, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('6b15e1a1-7f00-400d-8697-868969ca5c8e', 'f1f34541-89ac-49fd-8db9-dbc9e8c685aa', 'Engagement rate is best described as...', 1, 1, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('8b7e251a-2880-40e2-aa5f-561aacccaf95', '8e2267a0-3853-4e4d-bb25-a4313eefa102', 'Which tool shows how your site appears in Google search?', 1, 3, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('a9df37fa-2a05-4670-bd48-55dd94aadca6', 'f1f34541-89ac-49fd-8db9-dbc9e8c685aa', 'Which platform is typically strongest for B2B lead generation?', 1, 2, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('d28dcd10-210b-4c22-8fbc-c83a7afb13d4', '8e2267a0-3853-4e4d-bb25-a4313eefa102', 'What does SERP stand for?', 1, 0, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('e28091bb-e7a2-4b69-bb1a-1cd741321458', '8e2267a0-3853-4e4d-bb25-a4313eefa102', 'Search intent that signals readiness to buy is called...', 1, 2, '2026-10-08T20:23:42.510433+05:30'::timestamptz)
on conflict (id) do nothing;

insert into public.quiz_options (id, question_id, text, is_correct, created_at) values
  ('0165a230-5e26-4713-ae73-18c40710857c', 'e28091bb-e7a2-4b69-bb1a-1cd741321458', 'Transactional', true, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('0256f71a-b68d-4daa-b6df-051243aab2a8', '3726bbd7-8878-4720-9082-d4e1fce75776', 'Modified', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('06d60a45-5f7d-450a-9a6f-788d60639657', 'a9df37fa-2a05-4670-bd48-55dd94aadca6', 'Pinterest', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('10f38e5c-7597-4927-98e6-c5f44d740e86', '1e09df86-1b0c-40a7-a15d-43bcc94b28cc', 'Footer text', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('13157f5e-e3a0-4228-9d98-61613c5ae429', 'd28dcd10-210b-4c22-8fbc-c83a7afb13d4', 'Search Engine Results Page', true, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('141d4246-08f4-4aaf-898d-dd2c7756a1dd', '374425c9-fe86-4da2-a968-659b4fe4df1c', 'Rate of ad skips', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('1f7ede9a-d281-487d-8ea3-052346223487', 'a9df37fa-2a05-4670-bd48-55dd94aadca6', 'Twitch', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('2019f7bb-0fb4-495b-b143-b112369b70e6', '6b15e1a1-7f00-400d-8697-868969ca5c8e', 'Posting frequency', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('2bc23de8-33fd-4782-8528-35703b2c053c', '418156f2-ddf7-4e15-95b4-9e45578a3bbc', 'A recurring theme your content covers', true, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('34c5ac30-33df-42f6-a488-a98dbfcc7327', '8b7e251a-2880-40e2-aa5f-561aacccaf95', 'Google Keep', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('3bc6df10-d7e0-4a6a-bb65-550b62c27539', '47dd2ca6-e3b9-42b8-a3fa-751961aa9468', 'Impressions ÷ Clicks', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('447aeb40-feb7-40af-8e5b-aaa6a85142ea', 'e28091bb-e7a2-4b69-bb1a-1cd741321458', 'Local', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('450f2fd5-b964-4dfb-a433-cfe3877a5c0d', '6b15e1a1-7f00-400d-8697-868969ca5c8e', 'Interactions relative to audience or reach', true, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('4c0a7316-2255-425d-89f7-33e1fbdacf51', '8b7e251a-2880-40e2-aa5f-561aacccaf95', 'Google Search Console', true, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('4e7eb5a6-5d7d-46e8-8e6b-4ee84a48b365', 'd28dcd10-210b-4c22-8fbc-c83a7afb13d4', 'Site Entry Redirect Protocol', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('53c95a82-8314-45da-bb61-64fb7c0ced07', 'e28091bb-e7a2-4b69-bb1a-1cd741321458', 'Informational', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('58c948a2-97b6-48dd-ac8b-de8730dc59db', '3726bbd7-8878-4720-9082-d4e1fce75776', 'Phrase', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('5d52f8c2-dc1a-4d9f-969f-3cf653eb6e5c', '1e09df86-1b0c-40a7-a15d-43bcc94b28cc', 'Cookie banner', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('6257b99d-adfa-4eb8-b708-ffbc10f884ad', 'd28dcd10-210b-4c22-8fbc-c83a7afb13d4', 'Search Engine Ranking Policy', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('62e0dd3d-4275-4ccf-8799-fe762c2da859', '3726bbd7-8878-4720-9082-d4e1fce75776', 'Broad', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('6ae3f515-4924-4ee6-97b8-bc52b7aa7da0', 'a9df37fa-2a05-4670-bd48-55dd94aadca6', 'LinkedIn', true, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('6c7297bb-cbf0-451d-8d74-a7bd9e9774a8', '1e09df86-1b0c-40a7-a15d-43bcc94b28cc', 'Favicon', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('72a57524-2217-487c-8ed0-e6aad5c3056c', '47dd2ca6-e3b9-42b8-a3fa-751961aa9468', 'Clicks ÷ Impressions', true, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('7eda1764-8e1b-4cb9-bd07-7e0753470805', 'e28091bb-e7a2-4b69-bb1a-1cd741321458', 'Navigational', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('83cbffe0-9cf9-4947-92fe-e457c75d6405', 'd28dcd10-210b-4c22-8fbc-c83a7afb13d4', 'Secure Email Response Page', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('88dc8383-d4d3-4e5f-bd49-fc0dd0123ed4', '8b7e251a-2880-40e2-aa5f-561aacccaf95', 'Google Calendar', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('8ae2ce2a-05b7-4511-ac93-9c9094e172cd', '374425c9-fe86-4da2-a968-659b4fe4df1c', 'Reach of ad sets', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('93b04479-a38d-46c6-9acc-f59cf6996546', '374425c9-fe86-4da2-a968-659b4fe4df1c', 'Rank of ad score', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('93c63ed4-127b-41a4-9670-67915278fab9', '47dd2ca6-e3b9-42b8-a3fa-751961aa9468', 'Cost ÷ Clicks', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('9f998902-43b0-4213-9b0f-b2b6919a8165', '374425c9-fe86-4da2-a968-659b4fe4df1c', 'Revenue per ad spend', true, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('a1386b08-f59c-4cf2-8acd-30d8b2aee1a9', '418156f2-ddf7-4e15-95b4-9e45578a3bbc', 'A follower milestone', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('a3b4bd1a-ae15-4c6f-a02f-be5870ca918c', '6b15e1a1-7f00-400d-8697-868969ca5c8e', 'Ad spend per day', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('b2c6d0c8-503a-4738-a8c6-7b2642745d0b', '47dd2ca6-e3b9-42b8-a3fa-751961aa9468', 'Conversions ÷ Clicks', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('b59f00c9-d172-4403-bf89-677c72ecb8c3', 'a9df37fa-2a05-4670-bd48-55dd94aadca6', 'Snapchat', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('c3e15989-feb7-4cb7-bc59-84b20b6f6d2d', '3726bbd7-8878-4720-9082-d4e1fce75776', 'Exact', true, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('c5aa1da2-0e81-4a00-aa04-8e4f35ee79ef', '418156f2-ddf7-4e15-95b4-9e45578a3bbc', 'A hashtag limit', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('cafb3b08-54d8-45c8-85cb-4693bf51ceec', '6b15e1a1-7f00-400d-8697-868969ca5c8e', 'Total followers', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('cb275bee-7afa-479f-b6d9-bfc4992fe350', '1e09df86-1b0c-40a7-a15d-43bcc94b28cc', 'Title tag', true, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('df745796-b71a-4b2a-865e-cc8558a104a3', '418156f2-ddf7-4e15-95b4-9e45578a3bbc', 'A paid ad format', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('e3a69216-31a7-4d1a-b7c5-6561c087940c', '8b7e251a-2880-40e2-aa5f-561aacccaf95', 'Google Sheets', false, '2026-10-08T20:23:42.510433+05:30'::timestamptz)
on conflict (id) do nothing;

insert into public.live_classes (id, course_id, title, description, starts_at, ends_at, meeting_url, platform, created_at) values
  ('24b844f7-c61f-49ac-91d6-11deaa31607f', '4c4abdb5-f903-40f7-b4f5-cdf3aac728c7', 'Google Ads account teardown', 'Real account review: wasted spend, quality score and bidding fixes.', now() + interval '259200 seconds', now() + interval '264600 seconds', 'https://zoom.us/j/9876543210', 'Zoom', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('5fdbf6ce-2429-4e64-ab0b-33ba19057244', 'f42beb1a-1954-4957-9711-0b1adbf584af', 'Technical SEO audit clinic', 'Live audit of a student site: crawl errors, speed and indexing.', now() + interval '93600 seconds', now() + interval '97200 seconds', 'https://zoom.us/j/1234567890', 'Zoom', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('6251fa8d-4ce1-4fe0-8b2d-4ba6aac34390', '7b13b51a-96c0-41b0-af91-f81cec4591a8', 'Instagram Reels growth clinic', 'Hooks, retention and posting cadence with worked examples.', now() + interval '-172799 seconds', now() + interval '-169199 seconds', 'https://zoom.us/j/1112223334', 'Zoom', '2026-10-08T20:23:42.510433+05:30'::timestamptz),
  ('8c22504e-f914-482c-9cba-d48a5afbe9bf', 'f42beb1a-1954-4957-9711-0b1adbf584af', 'Live Q&A: Keyword research workshop', 'Bring your niche and we''ll build a keyword map together.', now() + interval '-599 seconds', now() + interval '3000 seconds', 'https://meet.google.com/lookup/lms-demo-live', 'Google Meet', '2026-10-08T20:23:42.510433+05:30'::timestamptz)
on conflict (id) do nothing;

-- First course: new name and online/offline prices; shown first in the catalog.
update public.courses set title = 'Marketing Analytics and AI driven marketing', slug = 'marketing-analytics-and-ai-driven-marketing',
  price = 4999, offline_price = 14999, created_at = now()
where id = '5d08e624-49b2-460f-8464-fe4cf0dbedef';

-- Remove old courses: Google Ads & PPC Mastery, Content Marketing & Copywriting,
-- Social Media Marketing Strategy, SEO Fundamentals: Rank on Google.
delete from public.courses where id in (
  '4c4abdb5-f903-40f7-b4f5-cdf3aac728c7', '71c75253-c3ff-4e5a-813f-8f8d6f5adce6',
  '7b13b51a-96c0-41b0-af91-f81cec4591a8', 'f42beb1a-1954-4957-9711-0b1adbf584af');

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

-- Course lineup: every course runs 4 months, except the two programmes below.
update public.courses set duration_months = 4;
update public.courses set price = 9999 where slug in ('graphic-designer', 'video-editing');

-- The combo and Entrepreneurship go after the existing courses. The Placement Programme goes second, right after
-- Marketing Analytics, so it appears in the home page rows (which show the first 4).
insert into public.courses (title, slug, short_description, description, category, difficulty, price, offline_price, duration_months, offline_only, features, is_published, created_at) values
  ('Video Editing + Graphic Designer Combo', 'video-editing-graphic-designer-combo',
   'Learn video editing and graphic design together.',
   'Learn video editing and graphic design together in one course.',
   'Video & Graphic Design', 'beginner', 17999, 34999, 4, false,
   '["Video Editing", "Graphic Designer"]'::jsonb, true,
   (select min(created_at) from public.courses) - interval '1 minute'),
  ('100% Placement Programme', '100-placement-programme',
   'Every GTapex course, taught in the classroom over 8 months.',
   'Every GTapex course, taught in the classroom over 8 months.',
   'Placement Programme', 'beginner', 59999, 59999, 8, true,
   '["Marketing Analytics and AI driven marketing", "Website & Landing Marketing", "Social Media & Content Marketing", "SEO & AI Search Optimization", "Digital Marketing Professional", "Graphic Designer", "Video Editing"]'::jsonb, true,
   (select created_at from public.courses where slug = 'marketing-analytics-and-ai-driven-marketing') - interval '30 seconds'),
  ('Entrepreneurship Programme', 'entrepreneurship-programme',
   'A classroom programme for people building their own business.',
   'A classroom programme for people building their own business.',
   'Entrepreneurship', 'beginner', 40000, 40000, 6, true,
   '[]'::jsonb, true,
   (select min(created_at) from public.courses) - interval '2 minutes');

-- One category for video and design: Graphic Designer, Video Editing and the combo.
update public.courses set category = 'Video Editing & Graphic Designing'
where slug in ('graphic-designer', 'video-editing', 'video-editing-graphic-designer-combo');

-- Course pictures: files are in frontend/public/course-thumbnails.
update public.courses set thumbnail_url = '/course-thumbnails/marketing-analytics-and-ai-driven-marketing.webp' where slug = 'marketing-analytics-and-ai-driven-marketing';
update public.courses set thumbnail_url = '/course-thumbnails/100-placement-programme.webp' where slug = '100-placement-programme';
update public.courses set thumbnail_url = '/course-thumbnails/website-landing-marketing.webp' where slug = 'website-landing-marketing';
update public.courses set thumbnail_url = '/course-thumbnails/social-media-content-marketing.webp' where slug = 'social-media-content-marketing';
update public.courses set thumbnail_url = '/course-thumbnails/seo-ai-search-optimization.webp' where slug = 'seo-ai-search-optimization';
update public.courses set thumbnail_url = '/course-thumbnails/digital-marketing-professional.webp' where slug = 'digital-marketing-professional';
update public.courses set thumbnail_url = '/course-thumbnails/graphic-designer.webp' where slug = 'graphic-designer';
update public.courses set thumbnail_url = '/course-thumbnails/video-editing.webp' where slug = 'video-editing';
update public.courses set thumbnail_url = '/course-thumbnails/video-editing-graphic-designer-combo.webp' where slug = 'video-editing-graphic-designer-combo';
update public.courses set thumbnail_url = '/course-thumbnails/entrepreneurship-programme.webp' where slug = 'entrepreneurship-programme';
