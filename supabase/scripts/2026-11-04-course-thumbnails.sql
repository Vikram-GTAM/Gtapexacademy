-- Run once in Supabase dashboard > SQL Editor on the live project. All-or-nothing: on any error nothing is kept.
-- Gives each of the 10 courses its own picture. Only the picture changes.
begin;

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

do $$
begin
  if (select count(*) from public.courses where thumbnail_url = '/course-thumbnails/' || slug || '.webp') <> 10 then
    raise exception 'Expected 10 courses with a picture. Nothing was changed.';
  end if;
end $$;

commit;
