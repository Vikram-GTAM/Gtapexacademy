-- Run once in Supabase dashboard > SQL Editor on the live project. All-or-nothing: on any error nothing is kept.
-- Lets Krish send visitors' enquiries to Admin > Contact messages. Courses and existing messages don't change.
begin;

-- Enquiries from Krish, the chat assistant. They appear in Admin > Contact messages.
-- A visitor may leave only a phone number, so a contact message no longer has to have an email address.
alter table public.contact_messages alter column email drop not null;

create or replace function public.send_chat_enquiry(p_name text, p_contact text, p_interest text default null, p_message text default null)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_contact text := trim(coalesce(p_contact, ''));
  v_is_email boolean := v_contact ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$';
  v_interest text := private.text_field(p_interest, 'Interest', 0, 80, false);
begin
  if not v_is_email and v_contact !~ '^\+?[0-9 -]{7,16}$' then
    perform private.err('validation_error', 'Enter a valid phone number or email address');
  end if;
  insert into public.contact_messages (name, email, phone, subject, message)
  values (
    private.text_field(p_name, 'Name', 2, 120),
    case when v_is_email then private.valid_email(v_contact) end,
    case when not v_is_email then v_contact end,
    'Krish chat: ' || coalesce(v_interest, 'Not sure yet'),
    coalesce(private.text_field(p_message, 'Message', 0, 1000, false), 'No extra details given.'));
  return jsonb_build_object('message', 'Thanks! Our team will reach out within one working day.');
end $$;

revoke all on function public.send_chat_enquiry(text, text, text, text) from public, anon, authenticated;
grant execute on function public.send_chat_enquiry(text, text, text, text) to anon, authenticated;

commit;
