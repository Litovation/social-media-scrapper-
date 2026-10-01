# Connection state

Target Supabase project: `iqfigajknhhikuluvzth`

Target repository: https://github.com/Litovation/social-media-scrapper-

The target addresses are configured. Database deployment, collection schedules, dashboard credentials and GitHub Actions secrets are not yet activated or verified.

The database must be inspected before installing the schema, because it uses public tables with general names such as accounts, posts and sources.

The preparation script creates install.sql without starting schedules. After deploying and testing the collect Edge Function, activate-schedules.sql starts the database jobs. The collector validates its database-held secret even though gateway JWT verification is disabled for that one function.

The Laya workflow requires three repository secrets: SUPABASE_URL, SUPABASE_KEY and LAYA_WORKER_TOKEN. The dashboard separately uses the server-only SUPABASE_SERVICE_ROLE_KEY. Keep secret values out of source control and chat.

Collectors supplied here cover X, Instagram, Bluesky, Mastodon, YouTube and Contra. The browser extension also collects visible X, Instagram and Contra posts. Successful access varies by platform; the collector's presence does not mean that live collection has been verified.
