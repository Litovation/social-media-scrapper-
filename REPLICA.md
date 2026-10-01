# Agency Signal

A replica of the supplied Agency Signal dashboard, connected to Supabase and real Laya inference.

Supabase project: `iqfigajknhhikuluvzth`

Repository: https://github.com/Litovation/social-media-scrapper-

## Current operation

The Supabase schema, collector Edge Function and database schedules are deployed. The local dashboard reads live posts through a separate token-protected RPC bridge. GitHub Actions has the three protected credentials required by the Laya tagging workflow. Collection has produced real posts and Laya has written real classifications.

The supplied collectors cover X, Instagram, Bluesky, Mastodon, YouTube and Contra. Source availability varies, and each account's errors appear in Accounts and Setup & health. A configured collector does not guarantee every account is reachable.

## Open the dashboard

Requires Node 22+. Run `npm start`, or double-click START.cmd. Open http://127.0.0.1:4173. The dashboard server listens on this computer only.

The ignored local .env is configured on the original computer. Credentials are not included in this repository or the ZIP. On another computer, copy .env.example to .env and configure SUPABASE_URL, SUPABASE_KEY and DASHBOARD_TOKEN. The dashboard does not need a service-role key. Run `npm run check:connection` to verify the connection without printing secrets.

## Laya

worker/laya_worker.py uses Laya's real Router, not simulated classifications. It labels purpose, hook, subject, CTA, specificity, relevance and generic AI wording; it also classifies discovered profiles.

The GitHub Actions workflow runs every 3 hours and can be started manually under Actions > Laya tagging > Run workflow. Its repository secrets are SUPABASE_URL, SUPABASE_KEY and LAYA_WORKER_TOKEN. CPU inference downloads the model on first use.

To run locally, install `python -m pip install -r worker/requirements.txt`, configure the ignored .env, then run `python worker/run_laya.py`.

## Database jobs

- Open-platform collection: every 10 minutes
- X / Instagram / Contra queue processing: every minute
- Engagement scoring: twice an hour
- Patterns, hot topics and candidate promotion: hourly
- Retention cleanup: daily

## Recreate in a new project

Inspect the target database first: the schema uses public tables such as accounts and posts. Run `python scripts/prepare_connection.py --project-ref YOUR_PROJECT_REF` to generate the target-specific installation SQL. Apply supabase/prepared/install.sql, deploy the collect Edge Function with its own secret authentication, then activate supabase/prepared/activate-schedules.sql. Do not reapply setup blindly to an existing application.

## Browser companion

The extension source is included for X, Instagram and Contra browsing capture, but it is not installed automatically. Automatic collection works independently of it. The extension needs its own setup, a local Laya serving endpoint, and your worker token if you enable syncing.

The original Claude-only connector was replaced with a local Supabase bridge. Snapshots are stored on the current device. No secret values are shipped in the public source.
