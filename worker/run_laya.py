"""Run the Laya worker using the ignored local .env connection file."""
import os
from pathlib import Path
from laya_worker import main

root = Path(__file__).resolve().parents[1]
path = root / '.env'
allowed = {'SUPABASE_URL', 'SUPABASE_KEY', 'LAYA_WORKER_TOKEN'}
if path.exists():
    for line in path.read_text(encoding='utf-8-sig').splitlines():
        if '=' in line and not line.lstrip().startswith('#'):
            name, value = line.split('=', 1)
            if name.strip() in allowed:
                os.environ.setdefault(name.strip(), value.strip())
raise SystemExit(main())
