# GTapex Academy

The learning platform for GTapex Academy: online and classroom marketing courses, with two roles, **student** and **admin**.

**Stack:** React 18, Vite, TypeScript, React Router and Tailwind on the frontend. Supabase provides the database, sign-in, file storage and server functions, so there is no server of our own to run.

See `supabase/README.md` for the database, security rules and how to go live.

## Folders

```
lms/
├── frontend/   the website
├── supabase/   migrations (database and security), Edge Functions, one-off SQL scripts
└── tests/      SQL tests that run on a throwaway local PostgreSQL database
```

The old FastAPI backend was retired and deleted in November 2026. Its code is archived in `../backups/old-backend-2026-11-04.zip`.

## Run the website

```bash
cd frontend
cp .env.example .env     # fill in the public Supabase URL and key
npm install
npm run dev              # http://localhost:5173
```

## Settings

| Where | What | Secret? |
|---|---|---|
| `frontend/.env` | `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, `VITE_SITE_URL` | No, these reach every visitor's browser |
| Supabase secrets | Razorpay keys, WhatsApp alert keys | Yes, set with `npx supabase secrets set` |
| `tests/supabase-local/.env` | Local test database | Yes, local only |

Never put a secret in `frontend/.env`, and never commit a `.env` file.

## Admin accounts

There's no public admin sign-up. Create the user in Supabase under Authentication > Users, then run `supabase/scripts/make-admin.sql` with their email.

## Tests

```bash
cd tests/supabase-local
cp .env.example .env     # local PostgreSQL only
python run.py            # migrations, API tests and attack tests
```

## Deploying

`npm run build` in `frontend/` creates `dist/`, which goes on the web host. Set `VITE_SITE_URL` first so the sitemap is built. `public/.htaccess` handles page addresses, HTTPS and caching on Apache hosting such as Hostinger.
