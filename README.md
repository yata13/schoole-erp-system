# School ERP

A multi-school ERP for Ethiopian secondary schools (grades 9–12). It uses React + TypeScript + Vite + Tailwind for the app, with Supabase (Postgres, Auth, Storage, Edge Functions) behind it.
One database serves many schools. Every table has `school_id`, and Row Level Security keeps each school, and each person, to their own data.

- Schema and rules: [`docs/phase-1-tables.md`](docs/phase-1-tables.md)
- Migrations: `supabase/migrations/` (one step per file, run in order)
- Database tests (pgTAP): `supabase/tests/`

## Phase 1 progress

- [x] Database: enums and helpers, tenancy and login token hook, school setup, people, enrollment, audit and soft delete, RLS, storage
- [x] Seed: 1 school, 4 grades, 40 sections, subjects
- [x] Database tests: 182 checks, plus a two-session race check for section capacity
- [ ] Edge Functions: `create-users`, `reset-password`
- [x] React app shell, live on Netlify: login, school setup (read), student list
- [ ] React app: user management, editing setup, student profile, import, moves

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
| Migrations | `0001`–`0010` applied; migration history uses the same version numbers as the files here |
| Seed | loaded: demo school `AHS` with test admin `ADMIN` / `Admin@1234` (test only) |

New migrations go out with:

```bash
npx supabase link --project-ref uuslloclignjvcvtakqn
```

```bash
npx supabase db push
```

Dashboard settings that SQL cannot set:

1. Optional speed-up: turn on the login token hook under **Authentication → Hooks → Customize Access Token** and choose `public.custom_access_token_hook`. Then school and roles travel in the token. Without it, the database looks them up instead (migration 0009), with the same rules.
2. Turn public sign-up off under **Authentication → Sign In / Providers → Allow new users to sign up**. Logins are made only by the `create-users` Edge Function.
