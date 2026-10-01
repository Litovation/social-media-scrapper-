# Agency Media — Agency Signal

Finds what design agencies, studios and creative business owners post on social media, and which patterns actually perform. It runs by itself, costs nothing, and shows everything on one dashboard.

## How it works

```
Every minute      X + Instagram      ─┐   (fetched from the database server, gently)
Every 10 minutes  Bluesky, Mastodon,  ├─▶  Supabase: posts, growth snapshots, accounts
                  YouTube, hashtags  ─┘         │
                                                ├─ every 30 min: score each post vs its account's usual
Every 3 hours     Laya (GitHub Actions) ────────┤   (winner = 2× the account's median engagement)
                  reads each post: purpose,     ├─ every hour: winning patterns, trait combos,
                  hook, subject, CTA, slop      │   hot topics, promote newly found accounts
                                                ▼
                                   Agency Signal dashboard (Claude artifact)
```

**It finds accounts by itself.** When it reads an account, it also notes the people that account mentions, quotes or gets suggested alongside, plus authors posting under followed hashtags. Candidates whose bio looks like a designer, studio, agency or business owner get checked once. If they perform and Laya agrees they're relevant, they're promoted to the watchlist, which is capped at 150 accounts per platform. Hashtags that start trending get followed automatically.

**Laya does the reading.** Laya is a free, open-source model that answers typed questions. The questions use the same format as TypeSafe's Jev, so switching to Jev later is a one-line change. Before Laya has run, simple text rules still tag each post's hook, call to action and length, so the dashboard works from day one.

## What's in this repo

| Path | What it is |
|---|---|
| `supabase/sql/` | Database: tables, scoring, pattern engine, X/Instagram fetchers, schedules (run in order) |
| `supabase/functions/collect/` | Edge function that collects Bluesky, Mastodon and YouTube |
| `worker/laya_worker.py` | Laya tagging worker (runs in GitHub Actions or on any computer) |
| `.github/workflows/laya-tagging.yml` | Runs the worker every 3 hours, free |
| `dashboard/agency-signal.html` | Source of the dashboard page |

## Turn on Laya (one-time, about 3 minutes)

1. In Supabase, open **SQL Editor** and run:
   `select value from private.config where key = 'worker_token';`
   Copy the value.
2. In GitHub, open this repo → **Settings → Secrets and variables → Actions → New repository secret**. Add these three:
   - `SUPABASE_URL` = `https://fkmutmzuwexfyqvanmlg.supabase.co`
   - `SUPABASE_KEY` = the project's **publishable** key (Supabase → Project Settings → API Keys)
   - `LAYA_WORKER_TOKEN` = the value from step 1
3. Open **Actions → Laya tagging → Run workflow** once. The first run downloads the model (~2 minutes). After that it runs every 3 hours by itself.

The worker can also run on any laptop:

```bash
pip install laya
export SUPABASE_URL=... SUPABASE_KEY=... LAYA_WORKER_TOKEN=...
python worker/laya_worker.py
```

## Limits to know

- **X** only shares each account's roughly 100 top posts publicly, and they're often older. That's good for evergreen patterns, but it isn't live.
- **Instagram** blocks public data for *business* profiles right now (a bug on Instagram's side). Personal profiles work, and business profiles are retried daily.
- **LinkedIn, Dribbble, Behance, Contra and Threads** block automated access without a login, so they aren't collected.
- These are unofficial public endpoints. The collector runs slowly on purpose, and any source can change without notice.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
