# Deploy Agency Signal on Vercel

The dashboard is prepared for Vercel's native Node.js server support. Supabase and the GitHub Laya workflow continue operating independently.

1. Sign in to Vercel and import `Litovation/social-media-scrapper-` from GitHub, using branch `main` and the repository root. Use framework preset **Other** and Node.js **24.x**. The checked-in configuration runs `npm run check` and bundles the dashboard assets.
2. Before adding connection credentials, open the project's **Security > Deployment Protection**, enable **Vercel Authentication**, and choose **All Deployments**. Ensure production, previews and any custom domain are protected. This is the dashboard's hosted login layer; the application itself does not provide a separate login. A server-side token protects Supabase from direct access, but the dashboard API needs the platform login protection too.
3. Configure these server-side environment variables for the protected deployment: `SUPABASE_URL`, `SUPABASE_KEY` (publishable key) and `DASHBOARD_TOKEN`. Use the values from the ignored local `.env`. Do not upload the `.env`, use public frontend variables, or add the worker token or service-role key. No secret values are included in this repository.
4. Redeploy. Test the protected URL while signed in and confirm that the dashboard loads real counts. In a signed-out browser, the dashboard and `/api/rpc/dashboard` must be gated by Vercel Authentication.
5. For a custom domain, add it in Vercel and set `APP_ORIGIN` to its exact HTTPS origin, such as `https://signal.example.com`, then redeploy. The generated production and preview domains are recognized through Vercel's system environment variables.

The app rejects hosts and origins outside its configured deployment URLs. Local `npm start` continues listening only on loopback. The dashboard does not run Laya inference inside a Vercel Function.

Sources: [Native Node.js servers](https://vercel.com/docs/functions/runtimes/node-js#deploy-a-nodejs-server), [Production login protection](https://vercel.com/changelog/protect-production-deployments-for-free-on-every-plan), [System environment variables](https://vercel.com/docs/environment-variables/system-environment-variables).

Status: prepared and locally verified. A successful Vercel deployment and signed-out access test are still required before calling it online.
