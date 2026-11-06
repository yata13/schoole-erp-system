# School ERP

A multi-school ERP for Ethiopian secondary schools (grades 9–12). It uses React + TypeScript + Vite + Tailwind for the app, with Supabase (Postgres, Auth, Storage, Edge Functions) behind it.
One database serves many schools. Every table has `school_id`, and Row Level Security keeps each school, and each person, to their own data.

- Schema and rules: [`docs/phase-1-tables.md`](docs/phase-1-tables.md)
- Migrations: `supabase/migrations/` (one step per file, run in order)
- Database tests (pgTAP): `supabase/tests/`

## Phase 1 progress

- [x] Database: enums and helpers, tenancy and login token hook, school setup, people, enrollment, audit and soft delete, RLS, storage
- [x] Seed: 1 school, 4 grades, 40 sections, subjects
- [x] Database tests: 169 checks, plus a two-session race check for section capacity
- [ ] Edge Functions: `create-users`, `reset-password`
- [ ] React app: auth, users, setup, students

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

## Hosted project setup

1. Apply the migrations: `npx supabase db push`.
2. Turn on the login token hook. Go to **Authentication → Hooks → Customize Access Token**, then choose `public.custom_access_token_hook`. Without it, tokens carry no `school_id`, and RLS refuses everything.
3. Keep public sign-up off. Logins are made only by the `create-users` Edge Function.
