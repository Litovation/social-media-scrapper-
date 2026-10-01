# Agency Signal replica

The dashboard uses the exact HTML, styles, fonts, sections and interactions supplied in agency-media_2.zip. The Claude artifact was inspected and showed an empty, disconnected dashboard. No live posts or performance figures have been invented.

## Open locally

Requires Node 22 or newer. Double-click START.cmd, or run `npm start` in this directory. Open http://127.0.0.1:4173.

## Connect your own database

Copy .env.example to .env. Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY, then restart the server. Run the supplied SQL migrations in numeric order in your own Supabase project first. The dashboard calls only four fixed RPCs; keys stay on the localhost server. Do not expose this privileged local server publicly. Snapshots are stored on this device only.

The original README describes its original deployment; its hardcoded project address is reference material, not your configured database. No original database was accessed or changed.

## Laya

The real Laya Router powers worker/laya_worker.py, which reads posts and profiles and classifies purpose, hook, subject, CTA, specificity, relevance and generic AI wording. The original GitHub Actions workflow is included.

Install `python -m pip install -r worker/requirements.txt`. Set SUPABASE_URL, SUPABASE_KEY and LAYA_WORKER_TOKEN in the environment, then run `python worker/laya_worker.py`. The worker needs the publishable key, not the dashboard service key. For scheduled runs, add these three secrets to your own GitHub repository and enable the included workflow. Installing the dependency does not activate collection or scheduling automatically.

## Included source

- public/index.html and dashboard/agency-signal.html: standalone dashboard
- server.mjs: localhost server and Supabase bridge
- supabase/: original schema, RPCs and collection function
- worker/: real Laya inference worker
- .github/workflows/: original tagging schedule
- extension/: supplied collector extension, not installed automatically

The standalone adaptation replaces Claude-only connector and snapshot APIs with the local server and device snapshots. Database deployment, live collection and the scheduled worker require your own service configuration.
