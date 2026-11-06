#!/usr/bin/env bash
# Rebuild a throwaway database from the migrations and run the pgTAP tests,
# without Docker. Needs psql, pg_prove and the pgTAP extension.
#
#   PGHOST=/var/run/postgresql PGPORT=54322 PGUSER=postgres scripts/db/test-local.sh
#
# With Docker you can use the Supabase CLI instead:
#   npx supabase start && npx supabase test db
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DB="${TEST_DB:-school_erp_test}"
export PGUSER="${PGUSER:-postgres}"

"${ROOT}/scripts/db/reset-local.sh" "${DB}"

psql -q -v ON_ERROR_STOP=1 -d "${DB}" -c "create extension if not exists pgtap with schema extensions" > /dev/null
pg_prove -d "${DB}" --ext .sql -r "${ROOT}/supabase/tests"
