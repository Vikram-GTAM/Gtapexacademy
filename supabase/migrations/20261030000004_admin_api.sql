-- GTapex Academy on Supabase: admin API (port of /api/admin/*). Every function starts with private.require_admin().
-- Create/update functions take a JSON object of fields; on update only the keys present are changed
-- (the FastAPI model_dump(exclude_unset=True) behaviour).

-- ================================================================ helpers
create or replace function private.admin_course_detail(c public.courses) returns jsonb
language sql stable security definer set search_path = '' as $$
  select private.course_card(c) || jsonb_build_object('description', c.description, 'features', c.features,
                                                      'modules', private.modules_json(c.id, true))
$$;

create or replace function private.course_or_404(p_course_id uuid) returns public.courses
language plpgsql stable security definer set search_path = '' as $$
declare c public.courses;
begin
  select * into c from public.courses where id = p_course_id;
  if not found then perform private.not_found('Course'); end if;
  return c;
end $$;

create or replace function private.module_or_404(p_module_id uuid) returns public.course_modules
language plpgsql stable security definer set search_path = '' as $$
declare m public.course_modules;
begin
  select * into m from public.course_modules where id = p_module_id;
  if not found then perform private.not_found('Module'); end if;
  return m;
end $$;

create or replace function private.check_module(p_course_id uuid, p_module_id uuid) returns void
language plpgsql stable security definer set search_path = '' as $$
begin
  if p_module_id is not null and not exists (select 1 from public.course_modules where id = p_module_id and course_id = p_course_id) then
    perform private.err('invalid_module', 'Module does not belong to this course');
  end if;
end $$;

create or replace function private.enrolled_ids(p_course_id uuid) returns uuid[]
language sql stable security definer set search_path = '' as $$
  select coalesce(array_agg(user_id), '{}') from public.enrollments where course_id = p_course_id
$$;

create or replace function private.ts_field(p_value jsonb, p_label text) returns timestamptz
language plpgsql stable set search_path = '' as $$
begin
  if p_value is null or jsonb_typeof(p_value) = 'null' then perform private.err('validation_error', p_label || ' is required'); end if;
  -- Times without a zone are treated as UTC, like services.courses.ensure_utc.
  return case when (p_value #>> '{}') ~ '(Z|[+-]\d\d:?\d\d)$' then (p_value #>> '{}')::timestamptz
              else ((p_value #>> '{}')::timestamp at time zone 'UTC') end;
exception when invalid_datetime_format or datetime_field_overflow then
  perform private.err('validation_error', p_label || ' is not a valid date and time');
  return null;
end $$;

create or replace function private.int_field(p_value jsonb, p_label text, p_min int, p_max int) returns int
language plpgsql immutable set search_path = '' as $$
declare v numeric;
begin
  begin
    v := (p_value #>> '{}')::numeric;
  exception when others then
    perform private.err('validation_error', p_label || ' must be a whole number');
  end;
  if v is null or v <> trunc(v) then perform private.err('validation_error', p_label || ' must be a whole number'); end if;
  if v < p_min or v > p_max then perform private.err('validation_error', p_label || ' must be between ' || p_min || ' and ' || p_max); end if;
  return v::int;
end $$;

-- ================================================================ dashboard
-- GET /api/admin/dashboard
create or replace function public.admin_dashboard() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_start date := (now() at time zone 'UTC')::date - 13;
begin
  perform private.require_admin();
  return jsonb_build_object(
    'stats', jsonb_build_object(
      'total_students', (select count(*) from public.profiles where role = 'student'),
      'total_courses', (select count(*) from public.courses),
      'total_enrollments', (select count(*) from public.enrollments),
      'total_revenue', (select coalesce(sum(amount), 0)::float8 from public.payments where status = 'paid'),
      'active_students', (select count(distinct user_id) from public.lesson_progress where completed_at >= now() - interval '30 days'),
      'pending_assignments', (select count(*) from public.assignment_submissions where status = 'submitted'),
      'upcoming_live_classes', (select count(*) from public.live_classes where starts_at >= now())),
    'enrollments_series', (
      select jsonb_agg(jsonb_build_object('date', d::date, 'count',
               (select count(*) from public.enrollments e where (e.created_at at time zone 'UTC')::date = d::date)) order by d)
      from generate_series(v_start, v_start + 13, interval '1 day') d),
    'revenue_series', coalesce((
      select jsonb_agg(jsonb_build_object('month', m, 'amount', amt) order by m) from (
        select m, amt from (
          select to_char(created_at at time zone 'UTC', 'YYYY-MM') m, sum(amount)::float8 amt
          from public.payments where status = 'paid' group by 1
        ) x order by m desc limit 6) y), '[]'::jsonb),
    'top_courses', coalesce((
      select jsonb_agg(jsonb_build_object('title', title, 'enrollments', n) order by n desc) from (
        select c.title, count(e.id) n from public.courses c join public.enrollments e on e.course_id = c.id
        group by c.id, c.title order by n desc limit 5) t), '[]'::jsonb));
end $$;

-- ================================================================ courses
-- GET /api/admin/courses
create or replace function public.admin_courses(p_search text default null) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  return coalesce((select jsonb_agg(private.course_card(c) order by c.created_at desc) from public.courses c
                   where nullif(trim(p_search), '') is null or c.title ilike '%' || trim(p_search) || '%'), '[]'::jsonb);
end $$;

-- GET /api/admin/courses/{id}
create or replace function public.admin_course(p_course_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  return private.admin_course_detail(private.course_or_404(p_course_id));
end $$;

-- Validates and writes the editable course fields present in p_data onto c.
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
  if p_data ? 'thumbnail_url' then c.thumbnail_url := nullif(trim(coalesce(p_data ->> 'thumbnail_url', '')), ''); end if;
  if p_data ? 'features' and jsonb_typeof(p_data -> 'features') <> 'null' then
    if jsonb_typeof(p_data -> 'features') <> 'array' then perform private.err('validation_error', 'Features must be a list'); end if;
    c.features := p_data -> 'features';
  end if;
  if p_data ? 'is_published' and jsonb_typeof(p_data -> 'is_published') <> 'null' then c.is_published := (p_data ->> 'is_published')::boolean; end if;
  return c;
end $$;

-- POST /api/admin/courses
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
  insert into public.courses (id, title, slug, short_description, description, category, difficulty, price, thumbnail_url, is_published, features)
  values (c.id, c.title, c.slug, c.short_description, c.description, c.category, c.difficulty, c.price, c.thumbnail_url, c.is_published, c.features)
  returning * into c;
  return private.admin_course_detail(c);
end $$;

-- PUT /api/admin/courses/{id}
create or replace function public.admin_update_course(p_course_id uuid, p_data jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c public.courses;
begin
  perform private.require_admin();
  c := private.apply_course_fields(private.course_or_404(p_course_id), p_data);
  if p_data ? 'title' then c.slug := private.unique_slug(c.title, c.id); end if;
  update public.courses set title = c.title, slug = c.slug, short_description = c.short_description, description = c.description,
    category = c.category, difficulty = c.difficulty, price = c.price, thumbnail_url = c.thumbnail_url,
    is_published = c.is_published, features = c.features
  where id = c.id returning * into c;
  return private.admin_course_detail(c);
end $$;

-- DELETE /api/admin/courses/{id}
create or replace function public.admin_delete_course(p_course_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c public.courses;
begin
  perform private.require_admin();
  c := private.course_or_404(p_course_id);
  if exists (select 1 from public.payments where course_id = c.id and status = 'paid') then
    perform private.err('course_has_payments', 'This course has paid purchases. Unpublish it instead of deleting.');
  end if;
  delete from public.courses where id = c.id;
  return jsonb_build_object('message', 'Course deleted');
end $$;

-- ================================================================ modules
create or replace function private.module_out(m public.course_modules) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('id', m.id, 'course_id', m.course_id, 'title', m.title, 'position', m.position,
    'lessons', coalesce((select jsonb_agg(private.lesson_out(l) order by l.position, l.created_at) from public.lessons l where l.module_id = m.id), '[]'::jsonb))
$$;

create or replace function public.admin_create_module(p_course_id uuid, p_title text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c public.courses; m public.course_modules;
begin
  perform private.require_admin();
  c := private.course_or_404(p_course_id);
  insert into public.course_modules (course_id, title, position)
  values (c.id, private.text_field(p_title, 'Title', 1, 200),
          coalesce((select max(position) from public.course_modules where course_id = c.id), 0) + 1)
  returning * into m;
  return private.module_out(m);
end $$;

create or replace function public.admin_update_module(p_module_id uuid, p_title text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare m public.course_modules;
begin
  perform private.require_admin();
  perform private.module_or_404(p_module_id);
  update public.course_modules set title = private.text_field(p_title, 'Title', 1, 200) where id = p_module_id returning * into m;
  return private.module_out(m);
end $$;

create or replace function public.admin_delete_module(p_module_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin();
  perform private.module_or_404(p_module_id);
  delete from public.course_modules where id = p_module_id;
  return jsonb_build_object('message', 'Module deleted');
end $$;

create or replace function public.admin_reorder_modules(p_course_id uuid, p_ids uuid[]) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin();
  perform private.course_or_404(p_course_id);
  if coalesce(cardinality(p_ids), 0) <> (select count(distinct x) from unnest(p_ids) x)
     or (select coalesce(array_agg(id order by id), '{}') from public.course_modules where course_id = p_course_id)
        <> (select coalesce(array_agg(x order by x), '{}') from unnest(p_ids) x) then
    perform private.err('invalid_order', 'The list must contain every module of this course exactly once');
  end if;
  update public.course_modules m set position = o.ord - 1 from unnest(p_ids) with ordinality o(id, ord) where m.id = o.id;
  return jsonb_build_object('message', 'Modules reordered');
end $$;

-- ================================================================ lessons
create or replace function public.admin_create_lesson(p_module_id uuid, p_data jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare m public.course_modules; c public.courses; l public.lessons; r jsonb;
begin
  perform private.require_admin();
  m := private.module_or_404(p_module_id);
  select * into c from public.courses where id = m.course_id;
  insert into public.lessons (module_id, title, description, video_url, duration_seconds, is_free_preview, position)
  values (m.id, private.text_field(p_data ->> 'title', 'Title', 1, 200), coalesce(p_data ->> 'description', ''),
          nullif(trim(coalesce(p_data ->> 'video_url', '')), ''),
          case when p_data ? 'duration_seconds' and jsonb_typeof(p_data -> 'duration_seconds') <> 'null'
               then private.int_field(p_data -> 'duration_seconds', 'Duration', 0, 2147483647) else 0 end,
          coalesce((p_data ->> 'is_free_preview')::boolean, false),
          coalesce((select max(position) from public.lessons where module_id = m.id), 0) + 1)
  returning * into l;
  for r in select * from jsonb_array_elements(coalesce(p_data -> 'resources', '[]'::jsonb)) loop
    insert into public.lesson_resources (lesson_id, title, file_url)
    values (l.id, private.text_field(r ->> 'title', 'Resource title', 1, 200), private.text_field(r ->> 'file_url', 'Resource file', 1, 600));
  end loop;
  if c.is_published then
    perform private.notify_many(private.enrolled_ids(c.id), 'new_content', 'New lesson in ' || c.title, l.title);
  end if;
  return private.lesson_out(l);
end $$;

create or replace function public.admin_update_lesson(p_lesson_id uuid, p_data jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare l public.lessons; cur public.course_modules; target public.course_modules;
begin
  perform private.require_admin();
  select * into l from public.lessons where id = p_lesson_id;
  if not found then perform private.not_found('Lesson'); end if;
  if p_data ? 'module_id' and jsonb_typeof(p_data -> 'module_id') <> 'null' and (p_data ->> 'module_id')::uuid <> l.module_id then
    target := private.module_or_404((p_data ->> 'module_id')::uuid);
    select * into cur from public.course_modules where id = l.module_id;
    if target.course_id <> cur.course_id then
      perform private.err('invalid_module', 'Lessons can only be moved within the same course');
    end if;
    l.module_id := target.id;
    l.position := coalesce((select max(position) from public.lessons where module_id = target.id), 0) + 1;
  end if;
  if p_data ? 'title' and jsonb_typeof(p_data -> 'title') <> 'null' then l.title := private.text_field(p_data ->> 'title', 'Title', 1, 200); end if;
  if p_data ? 'description' and jsonb_typeof(p_data -> 'description') <> 'null' then l.description := p_data ->> 'description'; end if;
  if p_data ? 'video_url' then l.video_url := nullif(trim(coalesce(p_data ->> 'video_url', '')), ''); end if;
  if p_data ? 'duration_seconds' and jsonb_typeof(p_data -> 'duration_seconds') <> 'null' then
    l.duration_seconds := private.int_field(p_data -> 'duration_seconds', 'Duration', 0, 2147483647);
  end if;
  if p_data ? 'is_free_preview' and jsonb_typeof(p_data -> 'is_free_preview') <> 'null' then l.is_free_preview := (p_data ->> 'is_free_preview')::boolean; end if;
  update public.lessons set module_id = l.module_id, position = l.position, title = l.title, description = l.description,
    video_url = l.video_url, duration_seconds = l.duration_seconds, is_free_preview = l.is_free_preview
  where id = l.id returning * into l;
  return private.lesson_out(l);
end $$;

create or replace function public.admin_delete_lesson(p_lesson_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin();
  delete from public.lessons where id = p_lesson_id;
  if not found then perform private.not_found('Lesson'); end if;
  return jsonb_build_object('message', 'Lesson deleted');
end $$;

create or replace function public.admin_reorder_lessons(p_module_id uuid, p_ids uuid[]) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin();
  perform private.module_or_404(p_module_id);
  if coalesce(cardinality(p_ids), 0) <> (select count(distinct x) from unnest(p_ids) x)
     or (select coalesce(array_agg(id order by id), '{}') from public.lessons where module_id = p_module_id)
        <> (select coalesce(array_agg(x order by x), '{}') from unnest(p_ids) x) then
    perform private.err('invalid_order', 'The list must contain every lesson of this module exactly once');
  end if;
  update public.lessons l set position = o.ord - 1 from unnest(p_ids) with ordinality o(id, ord) where l.id = o.id;
  return jsonb_build_object('message', 'Lessons reordered');
end $$;

create or replace function public.admin_add_resource(p_lesson_id uuid, p_title text, p_file_url text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r public.lesson_resources;
begin
  perform private.require_admin();
  if not exists (select 1 from public.lessons where id = p_lesson_id) then perform private.not_found('Lesson'); end if;
  insert into public.lesson_resources (lesson_id, title, file_url)
  values (p_lesson_id, private.text_field(p_title, 'Title', 1, 200), private.text_field(p_file_url, 'File', 1, 600))
  returning * into r;
  return jsonb_build_object('id', r.id, 'title', r.title, 'file_url', r.file_url);
end $$;

create or replace function public.admin_delete_resource(p_resource_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin();
  delete from public.lesson_resources where id = p_resource_id;
  if not found then perform private.not_found('Resource'); end if;
  return jsonb_build_object('message', 'Resource deleted');
end $$;

-- ================================================================ live classes
create or replace function public.admin_live_classes(p_course_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  return coalesce((select jsonb_agg(private.live_out(lc, true) order by lc.starts_at desc) from public.live_classes lc
                   where p_course_id is null or lc.course_id = p_course_id), '[]'::jsonb);
end $$;

create or replace function public.admin_create_live(p_data jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c public.courses; lc public.live_classes; v_start timestamptz; v_end timestamptz;
begin
  perform private.require_admin();
  c := private.course_or_404((p_data ->> 'course_id')::uuid);
  v_start := private.ts_field(p_data -> 'starts_at', 'Start time');
  v_end := private.ts_field(p_data -> 'ends_at', 'End time');
  if v_end <= v_start then perform private.err('invalid_time', 'End time must be after start time'); end if;
  insert into public.live_classes (course_id, title, description, starts_at, ends_at, meeting_url, platform)
  values (c.id, private.text_field(p_data ->> 'title', 'Title', 3, 200), coalesce(p_data ->> 'description', ''), v_start, v_end,
          private.text_field(p_data ->> 'meeting_url', 'Meeting link', 5, 600),
          coalesce(private.text_field(p_data ->> 'platform', 'Platform', 0, 60, false), 'Zoom'))
  returning * into lc;
  perform private.notify_many(private.enrolled_ids(c.id), 'live_class', 'New live class: ' || lc.title,
                              c.title || ' — ' || private.fmt_ts(v_start) || ' UTC');
  return private.live_out(lc, true);
end $$;

create or replace function public.admin_update_live(p_live_id uuid, p_data jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare lc public.live_classes;
begin
  perform private.require_admin();
  select * into lc from public.live_classes where id = p_live_id;
  if not found then perform private.not_found('Live class'); end if;
  if p_data ? 'course_id' and jsonb_typeof(p_data -> 'course_id') <> 'null' then
    lc.course_id := (private.course_or_404((p_data ->> 'course_id')::uuid)).id;
  end if;
  if p_data ? 'title' and jsonb_typeof(p_data -> 'title') <> 'null' then lc.title := private.text_field(p_data ->> 'title', 'Title', 3, 200); end if;
  if p_data ? 'description' and jsonb_typeof(p_data -> 'description') <> 'null' then lc.description := p_data ->> 'description'; end if;
  if p_data ? 'starts_at' and jsonb_typeof(p_data -> 'starts_at') <> 'null' then lc.starts_at := private.ts_field(p_data -> 'starts_at', 'Start time'); end if;
  if p_data ? 'ends_at' and jsonb_typeof(p_data -> 'ends_at') <> 'null' then lc.ends_at := private.ts_field(p_data -> 'ends_at', 'End time'); end if;
  if p_data ? 'meeting_url' and jsonb_typeof(p_data -> 'meeting_url') <> 'null' then lc.meeting_url := private.text_field(p_data ->> 'meeting_url', 'Meeting link', 5, 600); end if;
  if p_data ? 'platform' and jsonb_typeof(p_data -> 'platform') <> 'null' then lc.platform := coalesce(private.text_field(p_data ->> 'platform', 'Platform', 0, 60, false), 'Zoom'); end if;
  if lc.ends_at <= lc.starts_at then perform private.err('invalid_time', 'End time must be after start time'); end if;
  update public.live_classes set course_id = lc.course_id, title = lc.title, description = lc.description, starts_at = lc.starts_at,
    ends_at = lc.ends_at, meeting_url = lc.meeting_url, platform = lc.platform
  where id = lc.id returning * into lc;
  return private.live_out(lc, true);
end $$;

create or replace function public.admin_delete_live(p_live_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin();
  delete from public.live_classes where id = p_live_id;
  if not found then perform private.not_found('Live class'); end if;
  return jsonb_build_object('message', 'Live class deleted');
end $$;

-- ================================================================ assignments and grading
create or replace function private.admin_assignment_out(a public.assignments) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', a.id, 'course_id', a.course_id, 'course_title', (select title from public.courses where id = a.course_id),
    'module_id', a.module_id, 'title', a.title, 'instructions', a.instructions, 'deadline', a.deadline, 'max_marks', a.max_marks,
    'allow_late', a.allow_late, 'attachment_url', a.attachment_url,
    'submission_count', (select count(*) from public.assignment_submissions where assignment_id = a.id),
    'pending_count', (select count(*) from public.assignment_submissions where assignment_id = a.id and status = 'submitted'))
$$;

create or replace function public.admin_assignments(p_course_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  return coalesce((select jsonb_agg(private.admin_assignment_out(a) order by a.deadline desc) from public.assignments a
                   where p_course_id is null or a.course_id = p_course_id), '[]'::jsonb);
end $$;

create or replace function private.assignment_or_404(p_id uuid) returns public.assignments
language plpgsql stable security definer set search_path = '' as $$
declare a public.assignments;
begin
  select * into a from public.assignments where id = p_id;
  if not found then perform private.not_found('Assignment'); end if;
  return a;
end $$;

create or replace function public.admin_get_assignment(p_assignment_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  return private.admin_assignment_out(private.assignment_or_404(p_assignment_id));
end $$;

create or replace function public.admin_create_assignment(p_data jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c public.courses; a public.assignments; v_module uuid := nullif(p_data ->> 'module_id', '')::uuid;
begin
  perform private.require_admin();
  c := private.course_or_404((p_data ->> 'course_id')::uuid);
  perform private.check_module(c.id, v_module);
  insert into public.assignments (course_id, module_id, title, instructions, deadline, max_marks, allow_late, attachment_url)
  values (c.id, v_module, private.text_field(p_data ->> 'title', 'Title', 3, 200), coalesce(p_data ->> 'instructions', ''),
          private.ts_field(p_data -> 'deadline', 'Deadline'),
          case when p_data ? 'max_marks' and jsonb_typeof(p_data -> 'max_marks') <> 'null' then private.int_field(p_data -> 'max_marks', 'Max marks', 1, 1000) else 100 end,
          coalesce((p_data ->> 'allow_late')::boolean, false), nullif(trim(coalesce(p_data ->> 'attachment_url', '')), ''))
  returning * into a;
  perform private.notify_many(private.enrolled_ids(c.id), 'new_content', 'New assignment: ' || a.title,
                              c.title || ' — due ' || private.fmt_ts(a.deadline) || ' UTC');
  return private.admin_assignment_out(a);
end $$;

create or replace function public.admin_update_assignment(p_assignment_id uuid, p_data jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare a public.assignments;
begin
  perform private.require_admin();
  a := private.assignment_or_404(p_assignment_id);
  if p_data ? 'module_id' then
    a.module_id := nullif(p_data ->> 'module_id', '')::uuid;
    perform private.check_module(a.course_id, a.module_id);
  end if;
  if p_data ? 'title' and jsonb_typeof(p_data -> 'title') <> 'null' then a.title := private.text_field(p_data ->> 'title', 'Title', 3, 200); end if;
  if p_data ? 'instructions' and jsonb_typeof(p_data -> 'instructions') <> 'null' then a.instructions := p_data ->> 'instructions'; end if;
  if p_data ? 'deadline' and jsonb_typeof(p_data -> 'deadline') <> 'null' then a.deadline := private.ts_field(p_data -> 'deadline', 'Deadline'); end if;
  if p_data ? 'max_marks' and jsonb_typeof(p_data -> 'max_marks') <> 'null' then a.max_marks := private.int_field(p_data -> 'max_marks', 'Max marks', 1, 1000); end if;
  if p_data ? 'allow_late' and jsonb_typeof(p_data -> 'allow_late') <> 'null' then a.allow_late := (p_data ->> 'allow_late')::boolean; end if;
  if p_data ? 'attachment_url' then a.attachment_url := nullif(trim(coalesce(p_data ->> 'attachment_url', '')), ''); end if;
  update public.assignments set module_id = a.module_id, title = a.title, instructions = a.instructions, deadline = a.deadline,
    max_marks = a.max_marks, allow_late = a.allow_late, attachment_url = a.attachment_url
  where id = a.id returning * into a;
  return private.admin_assignment_out(a);
end $$;

create or replace function public.admin_delete_assignment(p_assignment_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin();
  perform private.assignment_or_404(p_assignment_id);
  delete from public.assignments where id = p_assignment_id;
  return jsonb_build_object('message', 'Assignment deleted');
end $$;

create or replace function private.admin_submission_out(s public.assignment_submissions) returns jsonb
language sql stable security definer set search_path = '' as $$
  select private.submission_out(s) || jsonb_build_object(
    'student_id', s.user_id, 'student_name', u.name, 'student_email', u.email,
    'assignment_title', a.title, 'course_title', c.title, 'max_marks', a.max_marks)
  from public.profiles u, public.assignments a, public.courses c
  where u.id = s.user_id and a.id = s.assignment_id and c.id = a.course_id
$$;

create or replace function public.admin_submissions(
  p_assignment_id uuid default null, p_course_id uuid default null, p_status text default null, p_search text default null,
  p_page int default 1, p_page_size int default 20
) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_page int := greatest(coalesce(p_page, 1), 1);
  v_size int := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_like text := '%' || trim(coalesce(p_search, '')) || '%';
  v_total bigint; v_items jsonb;
begin
  perform private.require_admin();
  if p_status is not null and p_status not in ('submitted', 'reviewed') then
    perform private.err('validation_error', 'status must be submitted or reviewed');
  end if;
  with hits as (
    select s.* from public.assignment_submissions s
    join public.profiles u on u.id = s.user_id
    join public.assignments a on a.id = s.assignment_id
    where (p_assignment_id is null or s.assignment_id = p_assignment_id)
      and (p_course_id is null or a.course_id = p_course_id)
      and (p_status is null or s.status = p_status::public.submission_status)
      and (nullif(trim(p_search), '') is null or u.name ilike v_like or u.email ilike v_like)
  )
  select (select count(*) from hits),
         coalesce((select jsonb_agg(private.admin_submission_out(h) order by h.submitted_at desc)
                   from (select * from hits order by submitted_at desc offset (v_page - 1) * v_size limit v_size) h), '[]'::jsonb)
  into v_total, v_items;
  return jsonb_build_object('items', v_items) || private.page_meta(v_total, v_page, v_size);
end $$;

create or replace function private.submission_or_404(p_id uuid) returns public.assignment_submissions
language plpgsql stable security definer set search_path = '' as $$
declare s public.assignment_submissions;
begin
  select * into s from public.assignment_submissions where id = p_id;
  if not found then perform private.not_found('Submission'); end if;
  return s;
end $$;

create or replace function public.admin_get_submission(p_submission_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  return private.admin_submission_out(private.submission_or_404(p_submission_id));
end $$;

create or replace function public.admin_grade_submission(p_submission_id uuid, p_marks numeric, p_feedback text default '') returns jsonb
language plpgsql security definer set search_path = '' as $$
declare s public.assignment_submissions; a public.assignments;
begin
  perform private.require_admin();
  s := private.submission_or_404(p_submission_id);
  select * into a from public.assignments where id = s.assignment_id;
  if p_marks is null or p_marks < 0 then perform private.err('validation_error', 'Marks must be 0 or more'); end if;
  if p_marks > a.max_marks then perform private.err('marks_exceed_max', 'Marks cannot exceed the maximum of ' || a.max_marks); end if;
  update public.assignment_submissions set marks = p_marks, feedback = nullif(trim(coalesce(p_feedback, '')), ''),
    status = 'reviewed', reviewed_at = now()
  where id = s.id returning * into s;
  perform private.notify(s.user_id, 'assignment_graded', 'Assignment graded: ' || a.title,
                         'You scored ' || trim_scale(p_marks)::text || '/' || a.max_marks || '.');
  return private.admin_submission_out(s);
end $$;

create or replace function public.admin_mark_reviewed(p_submission_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare s public.assignment_submissions;
begin
  perform private.require_admin();
  s := private.submission_or_404(p_submission_id);
  update public.assignment_submissions set status = 'reviewed', reviewed_at = now() where id = s.id returning * into s;
  return private.admin_submission_out(s);
end $$;

-- ================================================================ quizzes
create or replace function private.quiz_admin_out(q public.quizzes) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', q.id, 'course_id', q.course_id, 'course_title', (select title from public.courses where id = q.course_id),
    'module_id', q.module_id, 'title', q.title, 'description', q.description, 'time_limit_minutes', q.time_limit_minutes,
    'show_results', q.show_results, 'is_published', q.is_published,
    'questions', coalesce((select jsonb_agg(jsonb_build_object('id', qq.id, 'text', qq.text, 'marks', qq.marks,
                   'options', coalesce((select jsonb_agg(jsonb_build_object('id', o.id, 'text', o.text, 'is_correct', o.is_correct) order by o.created_at, o.id)
                                        from public.quiz_options o where o.question_id = qq.id), '[]'::jsonb))
                 order by qq.position, qq.created_at) from public.quiz_questions qq where qq.quiz_id = q.id), '[]'::jsonb),
    'attempt_count', (select count(*) from public.quiz_attempts where quiz_id = q.id and submitted_at is not null))
$$;

-- Validates the question list (QuestionIn rules) and inserts it. Options keep their given order.
create or replace function private.build_questions(p_quiz_id uuid, p_questions jsonb) returns void
language plpgsql security definer set search_path = '' as $$
declare qj jsonb; oj jsonb; i int := 0; v_q uuid; v_n int; v_correct int; v_ts timestamptz := clock_timestamp();
begin
  if p_questions is null or jsonb_typeof(p_questions) = 'null' then return; end if;
  if jsonb_typeof(p_questions) <> 'array' then perform private.err('validation_error', 'Questions must be a list'); end if;
  for qj in select * from jsonb_array_elements(p_questions) loop
    i := i + 1;
    v_n := jsonb_array_length(coalesce(qj -> 'options', '[]'::jsonb));
    if v_n < 2 or v_n > 8 then perform private.err('validation_error', 'Question ' || i || ': add between 2 and 8 options'); end if;
    select count(*) into v_correct from jsonb_array_elements(qj -> 'options') o where coalesce((o ->> 'is_correct')::boolean, false);
    if v_correct <> 1 then perform private.err('validation_error', 'Question ' || i || ': each question must have exactly one correct option'); end if;
    insert into public.quiz_questions (quiz_id, text, marks, position)
    values (p_quiz_id, private.text_field(qj ->> 'text', 'Question ' || i, 1, 100000),
            case when qj ? 'marks' and jsonb_typeof(qj -> 'marks') <> 'null' then private.int_field(qj -> 'marks', 'Question ' || i || ' marks', 1, 100) else 1 end,
            i - 1)
    returning id into v_q;
    -- created_at steps forward per option so they read back in the order they were entered
    for oj in select * from jsonb_array_elements(qj -> 'options') loop
      v_ts := v_ts + interval '1 microsecond';
      insert into public.quiz_options (question_id, text, is_correct, created_at)
      values (v_q, private.text_field(oj ->> 'text', 'Question ' || i || ' option', 1, 500), coalesce((oj ->> 'is_correct')::boolean, false), v_ts);
    end loop;
  end loop;
end $$;

create or replace function public.admin_quizzes(p_course_id uuid default null) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  return coalesce((select jsonb_agg(private.quiz_admin_out(q) order by q.created_at desc) from public.quizzes q
                   where p_course_id is null or q.course_id = p_course_id), '[]'::jsonb);
end $$;

create or replace function private.quiz_or_404(p_id uuid) returns public.quizzes
language plpgsql stable security definer set search_path = '' as $$
declare q public.quizzes;
begin
  select * into q from public.quizzes where id = p_id;
  if not found then perform private.not_found('Quiz'); end if;
  return q;
end $$;

create or replace function public.admin_quiz(p_quiz_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  return private.quiz_admin_out(private.quiz_or_404(p_quiz_id));
end $$;

create or replace function public.admin_create_quiz(p_data jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare c public.courses; q public.quizzes; v_module uuid := nullif(p_data ->> 'module_id', '')::uuid;
begin
  perform private.require_admin();
  c := private.course_or_404((p_data ->> 'course_id')::uuid);
  perform private.check_module(c.id, v_module);
  insert into public.quizzes (course_id, module_id, title, description, time_limit_minutes, show_results, is_published)
  values (c.id, v_module, private.text_field(p_data ->> 'title', 'Title', 3, 200), coalesce(p_data ->> 'description', ''),
          case when p_data ? 'time_limit_minutes' and jsonb_typeof(p_data -> 'time_limit_minutes') <> 'null'
               then private.int_field(p_data -> 'time_limit_minutes', 'Time limit', 0, 600) else 0 end,
          coalesce((p_data ->> 'show_results')::boolean, true), coalesce((p_data ->> 'is_published')::boolean, true))
  returning * into q;
  perform private.build_questions(q.id, coalesce(p_data -> 'questions', '[]'::jsonb));
  if q.is_published then
    perform private.notify_many(private.enrolled_ids(c.id), 'quiz', 'New quiz available: ' || q.title, c.title);
  end if;
  return private.quiz_admin_out(q);
end $$;

create or replace function public.admin_update_quiz(p_quiz_id uuid, p_data jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare q public.quizzes;
begin
  perform private.require_admin();
  q := private.quiz_or_404(p_quiz_id);
  if p_data ? 'module_id' then
    q.module_id := nullif(p_data ->> 'module_id', '')::uuid;
    perform private.check_module(q.course_id, q.module_id);
  end if;
  if p_data ? 'title' and jsonb_typeof(p_data -> 'title') <> 'null' then q.title := private.text_field(p_data ->> 'title', 'Title', 3, 200); end if;
  if p_data ? 'description' and jsonb_typeof(p_data -> 'description') <> 'null' then q.description := p_data ->> 'description'; end if;
  if p_data ? 'time_limit_minutes' and jsonb_typeof(p_data -> 'time_limit_minutes') <> 'null' then
    q.time_limit_minutes := private.int_field(p_data -> 'time_limit_minutes', 'Time limit', 0, 600);
  end if;
  if p_data ? 'show_results' and jsonb_typeof(p_data -> 'show_results') <> 'null' then q.show_results := (p_data ->> 'show_results')::boolean; end if;
  if p_data ? 'is_published' and jsonb_typeof(p_data -> 'is_published') <> 'null' then q.is_published := (p_data ->> 'is_published')::boolean; end if;
  update public.quizzes set module_id = q.module_id, title = q.title, description = q.description,
    time_limit_minutes = q.time_limit_minutes, show_results = q.show_results, is_published = q.is_published
  where id = q.id returning * into q;
  if p_data ? 'questions' and jsonb_typeof(p_data -> 'questions') <> 'null' then
    -- Replace the question set. Past attempts keep their stored scores.
    delete from public.quiz_questions where quiz_id = q.id;
    perform private.build_questions(q.id, p_data -> 'questions');
  end if;
  return private.quiz_admin_out(q);
end $$;

create or replace function public.admin_delete_quiz(p_quiz_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin();
  perform private.quiz_or_404(p_quiz_id);
  delete from public.quizzes where id = p_quiz_id;
  return jsonb_build_object('message', 'Quiz deleted');
end $$;

create or replace function public.admin_quiz_attempts(p_quiz_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  perform private.quiz_or_404(p_quiz_id);
  return coalesce((select jsonb_agg(jsonb_build_object('id', a.id, 'student_id', a.user_id, 'student_name', u.name, 'student_email', u.email,
                     'score', a.score, 'total_marks', a.total_marks, 'submitted_at', a.submitted_at) order by a.submitted_at desc)
                   from public.quiz_attempts a join public.profiles u on u.id = a.user_id
                   where a.quiz_id = p_quiz_id and a.submitted_at is not null), '[]'::jsonb);
end $$;

-- ================================================================ students
create or replace function public.admin_students(p_search text default null, p_status text default null, p_page int default 1, p_page_size int default 20)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_page int := greatest(coalesce(p_page, 1), 1);
  v_size int := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_like text := '%' || trim(coalesce(p_search, '')) || '%';
  v_total bigint; v_items jsonb;
begin
  perform private.require_admin();
  if p_status is not null and p_status not in ('active', 'disabled') then
    perform private.err('validation_error', 'status must be active or disabled');
  end if;
  with hits as (
    select * from public.profiles u
    where u.role = 'student'
      and (nullif(trim(p_search), '') is null or u.name ilike v_like or u.email ilike v_like)
      and (p_status is null or u.is_active = (p_status = 'active'))
  )
  select (select count(*) from hits),
         coalesce((select jsonb_agg(jsonb_build_object('id', h.id, 'name', h.name, 'email', h.email, 'is_active', h.is_active,
                     'joined_at', h.created_at, 'enrolled_count', (select count(*) from public.enrollments e where e.user_id = h.id))
                     order by h.created_at desc)
                   from (select * from hits order by created_at desc offset (v_page - 1) * v_size limit v_size) h), '[]'::jsonb)
  into v_total, v_items;
  return jsonb_build_object('items', v_items) || private.page_meta(v_total, v_page, v_size);
end $$;

create or replace function private.student_or_404(p_id uuid) returns public.profiles
language plpgsql stable security definer set search_path = '' as $$
declare u public.profiles;
begin
  select * into u from public.profiles where id = p_id and role = 'student';
  if not found then perform private.not_found('Student'); end if;
  return u;
end $$;

create or replace function public.admin_student(p_student_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare u public.profiles;
begin
  perform private.require_admin();
  u := private.student_or_404(p_student_id);
  return jsonb_build_object(
    'id', u.id, 'name', u.name, 'email', u.email, 'is_active', u.is_active, 'joined_at', u.created_at,
    'courses', coalesce((select jsonb_agg(jsonb_build_object('course_id', e.course_id, 'title', c.title, 'enrolled_at', e.created_at,
                 'completed_at', e.completed_at, 'percentage', p -> 'percentage', 'completed_lessons', p -> 'completed_lessons',
                 'total_lessons', p -> 'total_lessons') order by e.created_at desc)
               from public.enrollments e join public.courses c on c.id = e.course_id
               cross join lateral (select private.progress_for(u.id, e.course_id) p) pr
               where e.user_id = u.id), '[]'::jsonb),
    'assignments', coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'title', a.title, 'status', s.status, 'marks', s.marks::float8,
                 'max_marks', a.max_marks, 'submitted_at', s.submitted_at, 'is_late', s.is_late) order by s.submitted_at desc)
               from public.assignment_submissions s join public.assignments a on a.id = s.assignment_id where s.user_id = u.id), '[]'::jsonb),
    'quizzes', coalesce((select jsonb_agg(jsonb_build_object('id', qa.id, 'title', q.title, 'score', qa.score, 'total_marks', qa.total_marks,
                 'submitted_at', qa.submitted_at) order by qa.submitted_at desc)
               from public.quiz_attempts qa join public.quizzes q on q.id = qa.quiz_id
               where qa.user_id = u.id and qa.submitted_at is not null), '[]'::jsonb));
end $$;

create or replace function public.admin_set_student_status(p_student_id uuid, p_is_active boolean) returns jsonb
language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_admin();
  perform private.student_or_404(p_student_id);
  update public.profiles set is_active = coalesce(p_is_active, true) where id = p_student_id;
  return jsonb_build_object('message', case when p_is_active then 'Account enabled' else 'Account disabled' end);
end $$;

-- ================================================================ payments, certificates, broadcast, settings
create or replace function public.admin_payments(p_status text default null, p_search text default null, p_page int default 1, p_page_size int default 20)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_page int := greatest(coalesce(p_page, 1), 1);
  v_size int := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_like text := '%' || trim(coalesce(p_search, '')) || '%';
  v_total bigint; v_items jsonb;
begin
  perform private.require_admin();
  if p_status is not null and p_status not in ('created', 'paid', 'failed') then
    perform private.err('validation_error', 'status must be created, paid or failed');
  end if;
  with hits as (
    select p.*, u.name as student_name, u.email as student_email, c.title as course_title
    from public.payments p join public.profiles u on u.id = p.user_id join public.courses c on c.id = p.course_id
    where (p_status is null or p.status = p_status::public.payment_status)
      and (nullif(trim(p_search), '') is null or u.name ilike v_like or u.email ilike v_like or c.title ilike v_like)
  )
  select (select count(*) from hits),
         coalesce((select jsonb_agg(jsonb_build_object('id', h.id, 'student_name', h.student_name, 'student_email', h.student_email,
                     'course_title', h.course_title, 'amount', h.amount::float8, 'currency', h.currency, 'status', h.status,
                     'razorpay_order_id', h.razorpay_order_id, 'razorpay_payment_id', h.razorpay_payment_id, 'created_at', h.created_at)
                     order by h.created_at desc)
                   from (select * from hits order by created_at desc offset (v_page - 1) * v_size limit v_size) h), '[]'::jsonb)
  into v_total, v_items;
  return jsonb_build_object('items', v_items) || private.page_meta(v_total, v_page, v_size)
    || jsonb_build_object('summary', jsonb_build_object(
         'revenue', (select coalesce(sum(amount), 0)::float8 from public.payments where status = 'paid'),
         'paid_count', (select count(*) from public.payments where status = 'paid')));
end $$;

create or replace function public.admin_certificates() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  return coalesce((select jsonb_agg(jsonb_build_object('id', ce.id, 'certificate_code', ce.certificate_code, 'student_name', u.name,
                     'student_email', u.email, 'course_title', c.title, 'issued_at', ce.issued_at) order by ce.issued_at desc)
                   from public.certificates ce join public.profiles u on u.id = ce.user_id join public.courses c on c.id = ce.course_id), '[]'::jsonb);
end $$;

create or replace function public.admin_broadcast(p_title text, p_message text default '', p_course_id uuid default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_ids uuid[];
begin
  perform private.require_admin();
  if p_course_id is not null then
    perform private.course_or_404(p_course_id);
    v_ids := private.enrolled_ids(p_course_id);
  else
    select coalesce(array_agg(id), '{}') into v_ids from public.profiles where role = 'student' and is_active;
  end if;
  if cardinality(v_ids) = 0 then perform private.err('no_recipients', 'There are no students to notify'); end if;
  perform private.notify_many(v_ids, 'announcement', private.text_field(p_title, 'Title', 3, 200),
                              coalesce(private.text_field(p_message, 'Message', 0, 2000, false), ''));
  return jsonb_build_object('message', 'Notification sent to ' || cardinality(v_ids) || ' student(s)');
end $$;

-- GET /api/admin/settings (the payment part comes from the payments Edge Function)
create or replace function public.admin_settings() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  return (select jsonb_build_object('platform_name', platform_name, 'storage_backend', 'supabase', 'max_upload_mb', max_upload_mb)
          from public.platform_settings);
end $$;

-- ================================================================ leads
create or replace function public.admin_demo_requests() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  return coalesce((select jsonb_agg(to_jsonb(d) - 'updated_at' order by d.created_at desc) from public.demo_requests d), '[]'::jsonb);
end $$;

create or replace function public.admin_toggle_demo_contacted(p_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare d public.demo_requests;
begin
  perform private.require_admin();
  update public.demo_requests set is_contacted = not is_contacted where id = p_id returning * into d;
  if not found then perform private.not_found('Demo request'); end if;
  return to_jsonb(d) - 'updated_at';
end $$;

create or replace function public.admin_contact_messages() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
begin
  perform private.require_admin();
  return coalesce((select jsonb_agg(to_jsonb(m) - 'updated_at' order by m.created_at desc) from public.contact_messages m), '[]'::jsonb);
end $$;

create or replace function public.admin_toggle_contact_read(p_id uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare m public.contact_messages;
begin
  perform private.require_admin();
  update public.contact_messages set is_read = not is_read where id = p_id returning * into m;
  if not found then perform private.not_found('Message'); end if;
  return to_jsonb(m) - 'updated_at';
end $$;
