-- Spotting online and offline buyers: a filter and counts on the payments list, and the type on each student's courses.

drop function public.admin_payments(text, text, int, int);
create or replace function public.admin_payments(p_status text default null, p_search text default null, p_page int default 1, p_page_size int default 20, p_mode text default null)
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
  if p_mode is not null and p_mode not in ('online', 'offline') then
    perform private.err('validation_error', 'type must be online or offline');
  end if;
  with hits as (
    select p.*, u.name as student_name, u.email as student_email, c.title as course_title
    from public.payments p join public.profiles u on u.id = p.user_id join public.courses c on c.id = p.course_id
    where (p_status is null or p.status = p_status::public.payment_status)
      and (p_mode is null or p.learning_mode = p_mode)
      and (nullif(trim(p_search), '') is null or u.name ilike v_like or u.email ilike v_like or c.title ilike v_like)
  )
  select (select count(*) from hits),
         coalesce((select jsonb_agg(jsonb_build_object('id', h.id, 'student_name', h.student_name, 'student_email', h.student_email,
                     'course_title', h.course_title, 'learning_mode', h.learning_mode, 'amount', h.amount::float8, 'currency', h.currency, 'status', h.status,
                     'razorpay_order_id', h.razorpay_order_id, 'razorpay_payment_id', h.razorpay_payment_id, 'created_at', h.created_at)
                     order by h.created_at desc)
                   from (select * from hits order by created_at desc offset (v_page - 1) * v_size limit v_size) h), '[]'::jsonb)
  into v_total, v_items;
  return jsonb_build_object('items', v_items) || private.page_meta(v_total, v_page, v_size)
    || jsonb_build_object('summary', jsonb_build_object(
         'revenue', (select coalesce(sum(amount), 0)::float8 from public.payments where status = 'paid'),
         'paid_count', (select count(*) from public.payments where status = 'paid'),
         'online_count', (select count(*) from public.payments where status = 'paid' and learning_mode = 'online'),
         'offline_count', (select count(*) from public.payments where status = 'paid' and learning_mode = 'offline')));
end $$;

revoke all on function public.admin_payments(text, text, int, int, text) from public, anon, authenticated;
grant execute on function public.admin_payments(text, text, int, int, text) to authenticated;

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
                 'total_lessons', p -> 'total_lessons',
                 'learning_mode', (select pay.learning_mode from public.payments pay
                                   where pay.user_id = u.id and pay.course_id = e.course_id and pay.status = 'paid'
                                   order by pay.created_at desc limit 1)) order by e.created_at desc)
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
