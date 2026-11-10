#!/usr/bin/env bash
# Regenerate src/lib/database.types.ts from the hosted database.
set -euo pipefail
npx supabase gen types typescript --project-id uuslloclignjvcvtakqn --schema public > src/lib/database.types.ts
