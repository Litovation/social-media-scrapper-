"""Prepare a target-specific SQL installation; does not access or change a database."""
import argparse
import re
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--project-ref', required=True)
args = parser.parse_args()
if not re.fullmatch(r'[a-z0-9]{20}', args.project_ref):
    parser.error('Expected the 20-character Supabase project reference.')
root = Path(__file__).resolve().parents[1]
files = sorted((root / 'supabase/sql').glob('*.sql'))
chunks = []
for p in files:
    sql = p.read_text(encoding='utf-8')
    sql = re.sub(r'https://[a-z0-9]{20}\.supabase\.co', f'https://{args.project_ref}.supabase.co', sql)
    # Install schedules only after all function replacements have been applied.
    if p.name == '07_schedules_and_dashboard.sql':
        sql, schedules = sql.split('-- Schedules', 1)
    chunks.append(f'-- Source: {p.name}\n{sql}')
chunks.append('''-- Explicit server-only RPC privileges.
grant usage on schema public to service_role;
grant execute on all functions in schema public to service_role;
''')
out = root / 'supabase/prepared'
out.mkdir(exist_ok=True)
(out / 'install.sql').write_text('\n\n'.join(chunks), encoding='utf-8')
(out / 'activate-schedules.sql').write_text('-- Activate after deploying and testing the collect function.\n' + schedules, encoding='utf-8')
print(f'Prepared {len(files)} migrations for the selected project. No database was changed.')
