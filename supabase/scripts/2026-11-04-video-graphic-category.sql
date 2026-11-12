-- Run once in Supabase dashboard > SQL Editor on the live project. All-or-nothing: on any error nothing is kept.
-- Puts the three video and design courses in one category. No course is deleted.
begin;

-- One category for video and design: Graphic Designer, Video Editing and the combo.
update public.courses set category = 'Video Editing & Graphic Designing'
where slug in ('graphic-designer', 'video-editing', 'video-editing-graphic-designer-combo');

commit;
