-- Run once in Supabase dashboard > SQL Editor on the live project. All-or-nothing: on any error nothing is kept.
-- Lets the Offline price card charge the offline price. No course or price changes.
begin;

-- Buying a classroom place online. `learning_mode` on a payment says which price was charged.
-- The amount always comes from the database, never from the browser.

alter table public.payments add column learning_mode text not null default 'online' check (learning_mode in ('online', 'offline'));

drop function public.payment_prepare(uuid, uuid);
drop function public.payment_record_order(uuid, uuid, numeric, text);

create or replace function public.payment_prepare(p_user_id uuid, p_course_id uuid, p_mode text default 'online') returns jsonb
language plpgsql security definer set search_path = '' as $$
declare u public.profiles; c public.courses; v_amount numeric;
begin
  select * into u from public.profiles where id = p_user_id;
  if not found then perform private.err('invalid_token', 'User no longer exists'); end if;
  if not u.is_active then perform private.err('account_disabled', 'Your account has been disabled. Contact support.'); end if;
  if u.role <> 'student' then perform private.err('forbidden', 'This area is for students only'); end if;
  select * into c from public.courses where id = p_course_id;
  if not found or not c.is_published then perform private.not_found('Course'); end if;
  if private.is_enrolled(u.id, c.id) then perform private.err('already_enrolled', 'You are already enrolled in this course'); end if;
  if coalesce(p_mode, '') = 'online' then
    if c.offline_only then perform private.err('offline_only', 'This programme is only available offline.'); end if;
    if c.price <= 0 then perform private.err('free_course', 'This course is free. Use the enroll button.'); end if;
    v_amount := c.price;
  elsif p_mode = 'offline' then
    if coalesce(c.offline_price, 0) <= 0 then perform private.err('offline_unavailable', 'This course cannot be bought for offline learning. Please contact us.'); end if;
    v_amount := c.offline_price;
  else
    perform private.err('validation_error', 'Choose online or offline');
  end if;
  return jsonb_build_object('course_id', c.id, 'title', c.title, 'price', v_amount::float8, 'learning_mode', p_mode);
end $$;

create or replace function public.payment_record_order(p_user_id uuid, p_course_id uuid, p_amount numeric, p_order_id text, p_mode text default 'online')
returns void language sql security definer set search_path = '' as $$
  insert into public.payments (user_id, course_id, amount, currency, status, razorpay_order_id, learning_mode)
  values (p_user_id, p_course_id, p_amount, 'INR', 'created', p_order_id, p_mode)
$$;

revoke all on function public.payment_prepare(uuid, uuid, text) from public, anon, authenticated;
revoke all on function public.payment_record_order(uuid, uuid, numeric, text, text) from public, anon, authenticated;
grant execute on function public.payment_prepare(uuid, uuid, text) to service_role;
grant execute on function public.payment_record_order(uuid, uuid, numeric, text, text) to service_role;

-- The admin payments list shows which price was paid.
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
                     'course_title', h.course_title, 'learning_mode', h.learning_mode, 'amount', h.amount::float8, 'currency', h.currency, 'status', h.status,
                     'razorpay_order_id', h.razorpay_order_id, 'razorpay_payment_id', h.razorpay_payment_id, 'created_at', h.created_at)
                     order by h.created_at desc)
                   from (select * from hits order by created_at desc offset (v_page - 1) * v_size limit v_size) h), '[]'::jsonb)
  into v_total, v_items;
  return jsonb_build_object('items', v_items) || private.page_meta(v_total, v_page, v_size)
    || jsonb_build_object('summary', jsonb_build_object(
         'revenue', (select coalesce(sum(amount), 0)::float8 from public.payments where status = 'paid'),
         'paid_count', (select count(*) from public.payments where status = 'paid')));
end $$;

commit;
