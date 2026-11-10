# School ERP

A multi-school ERP for Ethiopian schools, KG1 to grade 12. It uses React + TypeScript + Vite + Tailwind for the app, with Supabase (Postgres, Auth, Storage) behind it.
One database serves many schools. Every table has `school_id`, and Row Level Security keeps each school, and each person, to their own data.

- Schema and rules: [`docs/phase-1-tables.md`](docs/phase-1-tables.md), plus migrations `0011`–`0016` for the ERP modules
- Migrations: `supabase/migrations/` (one step per file, run in order)
- Database tests (pgTAP): `supabase/tests/`
- Demo data: `supabase/seed-demo.sql`

## What it does

| Module | Who uses it | What's in it |
|---|---|---|
| Dashboard | Director, super admin, finance, registrar | Students, staff, revenue, expenses, attendance and fines at a glance, with charts |
| Students | Office staff; teachers see their own classes | List with search and filters; profile with results, attendance, fees and fines; add a student |
| Staff | Office staff | Every employee: teachers, office, cleaners, guards, drivers, cooks, nurse; salaries visible only to finance, director and super admin |
| Classes | Staff | KG, primary and secondary; sections A/B, homeroom teacher, seats used (max 30) |
| Attendance | Teachers (their sections), registrar | Mark a whole class per day: present, late, absent, excused |
| Marks | Teachers (their subject only) | Quiz, assignment, test, mid and final exam; class average; totals per subject |
| Teaching roadmap | Teachers; director follows | Week-by-week lesson plan per class and subject; who is behind |
| Finance | Finance, super admin; director reads | Monthly fees, invoices, Telebirr/bank/cash payments (never deleted, only voided), expenses, revenue vs expenses |
| Fines · ቅጣት | Office; teachers for their own students | Late-payment fines, discipline cases, damage, lost items |
| My school | Students and parents | Their own (or their children's) results, attendance, fees and fines |

## Demo (test data only)

**https://sefed-school-erp.netlify.app**: the sign-in page has one-tap buttons for each role:

| Button | School / login | Password |
|---|---|---|
| Admin | AHS / ADMIN | Admin@1234 |
| Director | AHS / DIRECTOR | Demo@1234 |
| Teacher | AHS / T-001 | Demo@1234 |
| Finance | AHS / FINANCE | Demo@1234 |
| Student | AHS / AHS-19-0100 | Demo@1234 |
| Parent | AHS / 0911000001 | Demo@1234 |

The demo school has about 800 students, 51 staff, a term of attendance and marks, and three months of fees and expenses.
**Before real data goes in:** delete the `VITE_DEMO_ACCOUNTS` line in `.env.production`, redeploy, and remove the demo logins.

## Run the database

With Docker and the Supabase CLI:

```bash
npx supabase start
```

```bash
npx supabase test db
```

Without Docker (plain Postgres 15+ with pgTAP and `pg_prove`):

```bash
PGHOST=/var/run/postgresql PGPORT=54322 PGUSER=postgres scripts/db/test-local.sh
```

```bash
PGHOST=/var/run/postgresql PGPORT=54322 PGUSER=postgres scripts/db/section-race-check.sh school_erp_test
```

`scripts/db/supabase-shim.sql` provides the small parts of Supabase (`auth`, `storage` and the API roles) that the migrations need on plain Postgres. It is only for local tests and is never applied to a Supabase project.

Load the demo school into a local database after the migrations:

```bash
psql -d school_erp_dev -f supabase/seed-demo.sql
```

## Live app

**https://sefed-school-erp.netlify.app**: Netlify site `sefed-school-erp` (id `b44970bd-c2e4-4c23-b568-17e9d6a3e9fd`).
Netlify builds it with `npm run build` (see `netlify.toml`). The public Supabase URL and publishable key are in `.env.production`. Preview deploys need Netlify team login; the live site is public and every page sits behind the app's own login.
It was deployed by upload, so a git push does not redeploy it yet. Connect the GitHub repo under the site's **Project configuration → Build & deploy** for deploys on every push.

## Hosted database

| | |
|---|---|
| Project | `school-erp` (ref `uuslloclignjvcvtakqn`), org Sefed studio |
| Region | eu-central-1 (Frankfurt), Postgres 17 |
| API URL | `https://uuslloclignjvcvtakqn.supabase.co` |
| Migrations | `0001`–`0016` applied; migration history uses the same version numbers as the files here |
| Data | demo school `AHS` from `seed-demo.sql` (test only) |

New migrations go out with:

```bash
npx supabase link --project-ref uuslloclignjvcvtakqn
```

```bash
npx supabase db push
```

Dashboard settings that SQL cannot set:

1. Optional speed-up: turn on the login token hook under **Authentication → Hooks → Customize Access Token** and choose `public.custom_access_token_hook`. Then school and roles travel in the token. Without it, the database looks them up instead (migration 0009), with the same rules.
2. Turn public sign-up off under **Authentication → Sign In / Providers → Allow new users to sign up**.

## Not built yet

- Logins for new people from the app (`create-users` and `reset-password` Edge Functions); demo logins are made by `seed-demo.sql`
- Report cards (PDF), result approval, timetable, library, SMS, Amharic interface
