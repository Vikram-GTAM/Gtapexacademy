# GTapex Academy on Supabase

This folder is the backend: everything the old FastAPI server did, moved into Supabase. That server is retired.
The website (`../frontend`) talks to it directly; there is no server of our own to run.

| Old backend | Now |
|---|---|
| FastAPI endpoints (`/api/...`) | Database functions in `migrations/` that the website calls with `supabase.rpc(...)` |
| JWT login, bcrypt, password-reset tokens | Supabase Auth |
| `require_admin` / `require_student` checks | Same checks at the top of every database function (`private.require_admin()` ...) |
| Razorpay order + signature check | Edge Function `functions/payments` (only place the Razorpay secret lives) |
| (new) | Edge Function `functions/razorpay-webhook`: enrols the student even if they close the tab after paying |
| ReportLab certificate PDF | Drawn in the browser from the certificate record (`frontend/src/services/certificatePdf.ts`) |
| `uploads/` folder or S3 | Supabase Storage buckets `thumbnails`, `course-files`, `submissions` |
| Alembic | `migrations/*.sql` |
| `seed.py` | `seed.sql` (courses only) + `scripts/make-admin.sql` |

## How it is secured

* Every table has row level security on with **no** policies, and the API roles have no table rights. The website
  can never read or change a table directly, so a forgotten rule cannot leak data.
* The only way in is the functions in `public`, each of which checks who is calling, exactly as the FastAPI
  dependencies did. Helpers live in the `private` schema, which the API does not expose.
* Quiz answer keys never leave the database: questions are sent without `is_correct`, and grading runs inside `submit_quiz`.
* Students can only upload into their own folder of the `submissions` bucket. Only admins upload course files.
  Files are reachable by their (random, unguessable) URL, like the old `/uploads` folder; nobody can list a bucket.
* The Razorpay secret and the Supabase service-role key exist only in Edge Function secrets, never in the website.

## Going live, step by step

You need: a Supabase account, Node.js, and the Razorpay test keys. Commands run from the `lms/` folder.

1. **Create the project.** supabase.com → New project. Choose the region closest to your students (Mumbai if
   offered). Save the database password in your password manager.
2. **Link this folder to it.**
   ```
   npx supabase login
   npx supabase link --project-ref <your-project-ref>
   ```
3. **Create the tables and functions.** `npx supabase db push`
4. **Load the starter courses (optional).** Open the Supabase dashboard → SQL Editor, paste `seed.sql`, run it.
5. **Apply the login settings** (password rules, reset email): `npx supabase config push`.
   Then in the dashboard → Authentication → URL Configuration set **Site URL** to your live address
   (e.g. `https://academy.gtapexmarketing.com`) and add `https://<that address>/reset-password` to Redirect URLs.
6. **Payments.**
   ```
   npx supabase secrets set RAZORPAY_KEY_ID=rzp_test_xxx RAZORPAY_KEY_SECRET=xxx RAZORPAY_WEBHOOK_SECRET=<choose one>
   npx supabase functions deploy payments
   npx supabase functions deploy razorpay-webhook
   ```
   In the Razorpay dashboard → Webhooks, add `https://<project-ref>.supabase.co/functions/v1/razorpay-webhook`
   for **payment.captured** and **order.paid**, using the same webhook secret.
7. **The website.** Copy `frontend/.env.example` to `frontend/.env` and fill in the project URL and the
   **anon public** key (Dashboard → Project Settings → API). Then `npm run build` in `frontend/` and upload the
   contents of `frontend/dist/` (including the hidden `.htaccess`) to Hostinger's `public_html`.
8. **Make yourself admin.** Sign up on the website, then run `scripts/make-admin.sql` (with your email) in the SQL Editor.
9. **Test as a student** before telling anyone: sign up with a second email, enrol in a free course, finish a lesson,
   take a quiz, submit an assignment, download a certificate, and buy a paid course with a Razorpay test card.

## Free plan notes

* **Emails:** Supabase's built-in sender only sends a few emails per hour. Before launch, add your own sender
  (Dashboard → Authentication → SMTP, e.g. Brevo or Resend). "Confirm email" is on: students log in after clicking
  the email link, and their profile is created at that moment. Keep it on, or sign-ups skip verification.
* **Pausing:** free projects pause after about a week with no activity. A nightly backup job also keeps it awake.
* **Backups:** none on the free plan. Set up the nightly backup before real students join.
* **File size:** at most 50 MB per file. Host long videos on YouTube (unlisted), Vimeo or Bunny and paste the link.

## Testing the SQL locally

`../tests/supabase-local/` applies these migrations to a throwaway database on a local PostgreSQL, with stand-ins for
Supabase's built-in parts, and runs `test_api.sql`: about 100 checks acting as a visitor, two students, an admin and
the payment service. It never touches a Supabase project.

```
python tests/supabase-local/run.py "postgresql://USER:PASSWORD@localhost:5432/postgres"
```

## WhatsApp alerts for Krish's enquiries

`functions/enquiry-alert` sends a WhatsApp template message for each new enquiry from Krish. Enquiries are saved whether or not the alert works.

1. In Meta's WhatsApp Manager, add a sending number and create a Utility template named `new_enquiry` in English:
   `New enquiry from Krish. Name: {{1}}. Contact: {{2}}. Interested in: {{3}}. Message: {{4}}.`
2. Set the secrets, then deploy:
   `npx supabase secrets set ENQUIRY_ALERT_SECRET=... WHATSAPP_TOKEN=... WHATSAPP_PHONE_NUMBER_ID=... WHATSAPP_ALERT_TO=916301617216`
   `npx supabase functions deploy enquiry-alert`
3. In the Supabase dashboard, open Integrations > Database Webhooks and create one on `public.contact_messages` for Insert events. Choose HTTP Request, method POST, with the function's URL and a header `x-webhook-secret` holding the same secret.
