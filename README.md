# Agency Signal

A replica of the supplied Agency Signal dashboard, connected to Supabase and real Laya inference.

Supabase project: `iqfigajknhhikuluvzth`

Repository: https://github.com/Litovation/social-media-scrapper-

## Current operation

The Supabase schema, collector Edge Function and database schedules are deployed. The local dashboard reads live posts through a separate token-protected RPC bridge. GitHub Actions has the three protected credentials required by the Laya tagging workflow. Collection has produced real posts and Laya has written real classifications.

The supplied collectors cover X, Instagram, Bluesky, Mastodon, YouTube and Contra. Source availability varies, and each account's errors appear in Accounts and Setup & health. A configured collector does not guarantee every account is reachable.

## Open the dashboard

Requires Node 24. Run `npm start`, or double-click START.cmd. Open http://127.0.0.1:4173. The local dashboard server listens on this computer only.

For online hosting, follow [Vercel setup](VERCEL.md). The repository supports Vercel's native Node.js server runtime, exact hosted-domain checks, and HTTPS requests. Enable Vercel Authentication for **All Deployments** before connecting the hosted dashboard to the database. The app has no separate hosted login layer.

The ignored local .env is configured on the original computer. Credentials are not included in this repository or the ZIP. On another computer, copy .env.example to .env and configure SUPABASE_URL, SUPABASE_KEY and DASHBOARD_TOKEN. The dashboard does not need a service-role key. Run `npm run check:connection` to verify the connection without printing secrets.

## Laya

worker/laya_worker.py uses Laya's real Router, not simulated classifications. It labels purpose, hook, subject, CTA, specificity, relevance and generic wording; it also classifies discovered profiles. Generic wording does not establish AI authorship.

## Refined analysis

The dashboard now calculates patterns from a consistent live snapshot of watched accounts in the chosen dates. Each dimension compares against its own known-label cohort. Overview totals include unlabelled posts; the analysis panel explicitly identifies the smaller relevant, scored, refined-label cohort. Platform totals reconcile with overview totals.

The v2 worker re-reads old labels in an engagement-independent order, round-robin across accounts. It keeps the original model answers and records explicit text checks separately. Ambiguous choices abstain. Choice-score thresholds are heuristics: the installed Laya checkpoint warns that some confidence scores are uncalibrated. These scores must not be presented as measured classification accuracy.

CTA presence is separate from CTA effectiveness. The overview compares requests with no request, displays win-rate intervals and platform breakdowns, and checks comparisons within the same account and format. Free-resource requests and paid inquiries are separate action types. Neither option is automatically good or bad; observational evidence does not prove a CTA caused virality.

Recommendations require 30 posts, 3 accounts, 80% refined coverage, sufficient known labels and an uncertainty check. Trait pairs additionally require 5 winners. These are conservative product gates, not proof of causality or correction for all confounding. While backfilling, recommendations remain withheld and Top posts remains an example library.

Export report downloads a standalone HTML snapshot with the exact selected range and matching filename. Open it and use Print / Save as PDF. Counts, cohort definitions, limitations, CTA evidence and source examples are included. Legacy snapshots are excluded and fallback snapshots must match the requested range.

Run `node scripts/test_analysis.mjs` for CTA guidance tests. `python worker/evaluate_laya.py report.json` runs six synthetic regression probes; it is not a representative accuracy benchmark. Visual-media analysis, a larger human-reviewed benchmark and business-outcome tracking still require additional work.

Database advisor warnings about token-authenticated SECURITY DEFINER endpoints are intentional; the private analysis helper and unwrapped dashboard are not executable by public client roles. See [Supabase function-access guidance](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable). Every public worker/dashboard endpoint must retain its token validation.

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
