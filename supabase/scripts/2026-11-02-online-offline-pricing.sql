-- Run once in Supabase dashboard > SQL Editor on the live project.
begin;

-- Online and offline pricing: `price` is the online price (what Razorpay charges); `offline_price` is the classroom price.

alter table public.courses add column offline_price numeric(10, 2) check (offline_price is null or offline_price >= 0);

create or replace function private.course_card(c public.courses) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', c.id, 'title', c.title, 'slug', c.slug, 'short_description', c.short_description, 'category', c.category,
    'difficulty', c.difficulty, 'price', c.price::float8, 'offline_price', c.offline_price::float8, 'thumbnail_url', c.thumbnail_url, 'is_published', c.is_published,
    'lesson_count', (select count(*) from public.lessons l join public.course_modules m on m.id = l.module_id where m.course_id = c.id),
    'duration_seconds', (select coalesce(sum(l.duration_seconds), 0) from public.lessons l join public.course_modules m on m.id = l.module_id where m.course_id = c.id),
    'enrolled_count', (select count(*) from public.enrollments e where e.course_id = c.id))
$$;

create or replace function private.apply_course_fields(c public.courses, p_data jsonb) returns public.courses
language plpgsql stable set search_path = '' as $$
begin
  if p_data ? 'title' then c.title := private.text_field(p_data ->> 'title', 'Title', 3, 200); end if;
  if p_data ? 'short_description' then c.short_description := coalesce(private.text_field(p_data ->> 'short_description', 'Short description', 0, 300, false), ''); end if;
  if p_data ? 'description' then c.description := coalesce(p_data ->> 'description', ''); end if;
  if p_data ? 'category' then c.category := coalesce(private.text_field(p_data ->> 'category', 'Category', 0, 80, false), 'General'); end if;
  if p_data ? 'difficulty' and jsonb_typeof(p_data -> 'difficulty') <> 'null' then
    if (p_data ->> 'difficulty') not in ('beginner', 'intermediate', 'advanced') then
      perform private.err('validation_error', 'Difficulty must be beginner, intermediate or advanced');
    end if;
    c.difficulty := (p_data ->> 'difficulty')::public.difficulty;
  end if;
  if p_data ? 'price' and jsonb_typeof(p_data -> 'price') <> 'null' then
    if jsonb_typeof(p_data -> 'price') <> 'number' or (p_data ->> 'price')::numeric < 0 then
      perform private.err('validation_error', 'Price must be 0 or more');
    end if;
    c.price := (p_data ->> 'price')::numeric;
  end if;
  if p_data ? 'offline_price' then  -- null or missing value = no offline option
    if jsonb_typeof(p_data -> 'offline_price') = 'null' then
      c.offline_price := null;
    elsif jsonb_typeof(p_data -> 'offline_price') <> 'number' or (p_data ->> 'offline_price')::numeric < 0 then
      perform private.err('validation_error', 'Offline price must be 0 or more');
    else
      c.offline_price := (p_data ->> 'offline_price')::numeric;
    end if;
  end if;
  if p_data ? 'thumbnail_url' then c.thumbnail_url := nullif(trim(coalesce(p_data ->> 'thumbnail_url', '')), ''); end if;
  if p_data ? 'features' and jsonb_typeof(p_data -> 'features') <> 'null' then
    if jsonb_typeof(p_data -> 'features') <> 'array' then perform private.err('validation_error', 'Features must be a list'); end if;
    c.features := p_data -> 'features';
  end if;
  if p_data ? 'is_published' and jsonb_typeof(p_data -> 'is_published') <> 'null' then c.is_published := (p_data ->> 'is_published')::boolean; end if;
  return c;
end $$;

create or replace function public.admin_create_course(p_data jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c public.courses;
begin
  perform private.require_admin();
  if not (p_data ? 'title') then perform private.err('validation_error', 'Title is required'); end if;
  c.id := gen_random_uuid(); c.short_description := ''; c.description := ''; c.category := 'General'; c.difficulty := 'beginner';
  c.price := 0; c.features := '[]'::jsonb; c.is_published := false;
  c := private.apply_course_fields(c, p_data);
  c.slug := private.unique_slug(c.title);
  insert into public.courses (id, title, slug, short_description, description, category, difficulty, price, offline_price, thumbnail_url, is_published, features)
  values (c.id, c.title, c.slug, c.short_description, c.description, c.category, c.difficulty, c.price, c.offline_price, c.thumbnail_url, c.is_published, c.features)
  returning * into c;
  return private.admin_course_detail(c);
end $$;

create or replace function public.admin_update_course(p_course_id uuid, p_data jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c public.courses;
begin
  perform private.require_admin();
  c := private.apply_course_fields(private.course_or_404(p_course_id), p_data);
  if p_data ? 'title' then c.slug := private.unique_slug(c.title, c.id); end if;
  update public.courses set title = c.title, slug = c.slug, short_description = c.short_description, description = c.description,
    category = c.category, difficulty = c.difficulty, price = c.price, offline_price = c.offline_price, thumbnail_url = c.thumbnail_url,
    is_published = c.is_published, features = c.features
  where id = c.id returning * into c;
  return private.admin_course_detail(c);
end $$;

-- First course: new name and online/offline prices; shown first in the catalog.
update public.courses set title = 'Marketing Analytics and AI driven marketing', slug = 'marketing-analytics-and-ai-driven-marketing',
  price = 4999, offline_price = 14999, created_at = now()
where id = '5d08e624-49b2-460f-8464-fe4cf0dbedef';

commit;
