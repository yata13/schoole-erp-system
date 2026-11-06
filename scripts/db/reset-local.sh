#!/usr/bin/env bash
# Rebuild a local database from the shim, migrations and seed (no Docker).
#   PGHOST=/var/run/postgresql PGPORT=54322 PGUSER=postgres scripts/db/reset-local.sh [db_name]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DB="${1:-school_erp_dev}"
export PGUSER="${PGUSER:-postgres}"
psql -q -v ON_ERROR_STOP=1 -d postgres -c "drop database if exists ${DB}" -c "create database ${DB}" 2>&1 | grep -v 'does not exist, skipping' || true
psql -q -v ON_ERROR_STOP=1 -d "${DB}" -c "alter database ${DB} set search_path = \"\$user\", public, extensions"
run() { psql -q -X -v ON_ERROR_STOP=1 -d "${DB}" -f "$1" > /dev/null; }
run "${ROOT}/scripts/db/supabase-shim.sql"
for f in "${ROOT}"/supabase/migrations/*.sql; do
  echo "migrate  $(basename "$f")"
  run "$f"
done
echo "seed     seed.sql"
run "${ROOT}/supabase/seed.sql"
