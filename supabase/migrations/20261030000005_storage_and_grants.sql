-- GTapex Academy on Supabase: file storage and API permissions.

-- ================================================================ storage buckets
-- Files are public by URL (like the old /uploads folder) but every file name is a random UUID, and nobody can list
-- a bucket's contents. Size limits: Supabase's free plan allows at most 50 MB per file.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('thumbnails', 'thumbnails', true, 5 * 1024 * 1024, array['image/png', 'image/jpeg', 'image/webp', 'image/gif']),
  ('course-files', 'course-files', true, 50 * 1024 * 1024, null),
  ('submissions', 'submissions', true, 25 * 1024 * 1024, null)
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Admins upload thumbnails, lesson videos, resources and assignment attachments.
create policy "admins upload course files" on storage.objects for insert to authenticated
  with check (bucket_id in ('thumbnails', 'course-files') and public.is_admin());
create policy "admins manage course files" on storage.objects for delete to authenticated
  using (bucket_id in ('thumbnails', 'course-files') and public.is_admin());

-- Students upload assignment files into their own folder only: submissions/<their user id>/<random>.<ext>
create policy "students upload own submissions" on storage.objects for insert to authenticated
  with check (bucket_id = 'submissions' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- ================================================================ API permissions
-- Nothing is callable unless listed here. The private schema is never exposed.
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('public', 'private')
  loop
    execute format('revoke all on function %s from public, anon, authenticated', f.sig);
  end loop;
end $$;

-- Signed-in users (each function checks student/admin itself).
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname not like 'payment\_%'
  loop
    execute format('grant execute on function %s to authenticated', f.sig);
  end loop;
end $$;

-- Visitors who are not signed in: the catalog and the two lead forms.
grant execute on function public.list_courses(text, text, text, text, boolean, int, int) to anon;
grant execute on function public.course_categories() to anon;
grant execute on function public.get_course(uuid) to anon;
grant execute on function public.book_demo(text, text, text, text, text, text) to anon;
grant execute on function public.send_contact_message(text, text, text, text, text) to anon;

-- The payments Edge Function (service role) only.
grant execute on function public.payment_prepare(uuid, uuid) to service_role;
grant execute on function public.payment_record_order(uuid, uuid, numeric, text) to service_role;
grant execute on function public.payment_mark_paid(text, text, text, uuid) to service_role;
grant execute on function public.payment_mark_failed(text, uuid) to service_role;

-- Functions inside policies and SECURITY DEFINER bodies run as their owner, so the API roles need nothing in private.
