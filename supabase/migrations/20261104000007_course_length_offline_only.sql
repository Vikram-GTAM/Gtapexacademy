-- Course length, and courses sold only in the classroom.
-- duration_months: how long the course runs; null = not shown.
-- offline_only: no online purchase. `price` then mirrors offline_price, so these courses are never treated as free.

alter table public.courses add column duration_months smallint check (duration_months between 1 and 60);
alter table public.courses add column offline_only boolean not null default false;
alter table public.courses add constraint courses_offline_only_priced
  check (not offline_only or (offline_price > 0 and price = offline_price));

create or replace function private.course_card(c public.courses) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', c.id, 'title', c.title, 'slug', c.slug, 'short_description', c.short_description, 'category', c.category,
    'difficulty', c.difficulty, 'price', c.price::float8, 'offline_price', c.offline_price::float8, 'duration_months', c.duration_months, 'offline_only', c.offline_only, 'thumbnail_url', c.thumbnail_url, 'is_published', c.is_published,
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
  if p_data ? 'duration_months' then  -- null = no length shown
    if jsonb_typeof(p_data -> 'duration_months') = 'null' then
      c.duration_months := null;
    elsif jsonb_typeof(p_data -> 'duration_months') <> 'number' or (p_data ->> 'duration_months') !~ '^[0-9]+$'
          or (p_data ->> 'duration_months')::numeric not between 1 and 60 then
      perform private.err('validation_error', 'Duration must be a whole number of months from 1 to 60');
    else
      c.duration_months := (p_data ->> 'duration_months')::smallint;
    end if;
  end if;
  if p_data ? 'offline_only' and jsonb_typeof(p_data -> 'offline_only') <> 'null' then c.offline_only := (p_data ->> 'offline_only')::boolean; end if;
  if p_data ? 'thumbnail_url' then c.thumbnail_url := nullif(trim(coalesce(p_data ->> 'thumbnail_url', '')), ''); end if;
  if p_data ? 'features' and jsonb_typeof(p_data -> 'features') <> 'null' then
    if jsonb_typeof(p_data -> 'features') <> 'array' then perform private.err('validation_error', 'Features must be a list'); end if;
    c.features := p_data -> 'features';
  end if;
  if p_data ? 'is_published' and jsonb_typeof(p_data -> 'is_published') <> 'null' then c.is_published := (p_data ->> 'is_published')::boolean; end if;
  -- An offline-only course always carries its classroom price in `price` too, so it can never count as free.
  if c.offline_only then
    if coalesce(c.offline_price, 0) <= 0 then perform private.err('validation_error', 'An offline-only course needs an offline price'); end if;
    c.price := c.offline_price;
  end if;
  return c;
end $$;

create or replace function public.admin_create_course(p_data jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c public.courses;
begin
  perform private.require_admin();
  if not (p_data ? 'title') then perform private.err('validation_error', 'Title is required'); end if;
  c.id := gen_random_uuid(); c.short_description := ''; c.description := ''; c.category := 'General'; c.difficulty := 'beginner';
  c.price := 0; c.offline_only := false; c.features := '[]'::jsonb; c.is_published := false;
  c := private.apply_course_fields(c, p_data);
  c.slug := private.unique_slug(c.title);
  insert into public.courses (id, title, slug, short_description, description, category, difficulty, price, offline_price, duration_months, offline_only, thumbnail_url, is_published, features)
  values (c.id, c.title, c.slug, c.short_description, c.description, c.category, c.difficulty, c.price, c.offline_price, c.duration_months, c.offline_only, c.thumbnail_url, c.is_published, c.features)
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
    category = c.category, difficulty = c.difficulty, price = c.price, offline_price = c.offline_price, duration_months = c.duration_months, offline_only = c.offline_only, thumbnail_url = c.thumbnail_url,
    is_published = c.is_published, features = c.features
  where id = c.id returning * into c;
  return private.admin_course_detail(c);
end $$;

-- Offline-only courses cannot be bought online.
create or replace function public.payment_prepare(p_user_id uuid, p_course_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare u public.profiles; c public.courses;
begin
  select * into u from public.profiles where id = p_user_id;
  if not found then perform private.err('invalid_token', 'User no longer exists'); end if;
  if not u.is_active then perform private.err('account_disabled', 'Your account has been disabled. Contact support.'); end if;
  if u.role <> 'student' then perform private.err('forbidden', 'This area is for students only'); end if;
  select * into c from public.courses where id = p_course_id;
  if not found or not c.is_published then perform private.not_found('Course'); end if;
  if private.is_enrolled(u.id, c.id) then perform private.err('already_enrolled', 'You are already enrolled in this course'); end if;
  if c.offline_only then perform private.err('offline_only', 'This programme is only available offline. Book a free demo to join.'); end if;
  if c.price <= 0 then perform private.err('free_course', 'This course is free. Use the enroll button.'); end if;
  return jsonb_build_object('course_id', c.id, 'title', c.title, 'price', c.price::float8);
end $$;
