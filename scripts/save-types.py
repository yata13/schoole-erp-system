"""Save the output of the Supabase MCP generate_typescript_types tool as src/lib/database.types.ts.
Usage: python3 -I scripts/save-types.py <saved tool output file>"""
import json, sys
raw = open(sys.argv[1]).read()
data = json.loads(raw)
if isinstance(data, list):
    data = json.loads(data[0]['text'])
open('src/lib/database.types.ts', 'w').write(
    '// Generated from the live database. Do not edit; regenerate with scripts/gen-types.sh.\n' + data['types'])
print('saved', len(data['types']), 'chars')
