import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { hostingPolicy } from './hosting.mjs';
const root = dirname(fileURLToPath(import.meta.url));
const port = Number(process.env.PORT || 4173);
const hosting = hostingPolicy(process.env, port);
const privileged = Boolean(process.env.SUPABASE_SERVICE_ROLE_KEY);
const apiKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_KEY;
const configured = Boolean(process.env.SUPABASE_URL && apiKey && (privileged || process.env.DASHBOARD_TOKEN));
const routes = {
  dashboard: a => ({p_days: [30, 90, 1095].includes(a.p_days) ? a.p_days : 1095}),
  add_account: a => {
    if (!['x','instagram','bluesky','mastodon','youtube','contra'].includes(a.p_platform) || !/^[A-Za-z0-9_.@-]{2,80}$/.test(a.p_handle || '')) throw new Error('Invalid account');
    return {p_platform: a.p_platform, p_handle: a.p_handle};
  },
  add_source: a => {
    if (a.p_platform !== 'mastodon' || !/^[a-z0-9_]{2,60}$/.test(a.p_value || '')) throw new Error('Invalid hashtag');
    return {p_platform: a.p_platform, p_value: a.p_value};
  },
  set_account_status: a => {
    if (!Number.isSafeInteger(a.p_id) || a.p_id < 1 || !['watch','ignored'].includes(a.p_status)) throw new Error('Invalid status');
    return {p_id: a.p_id, p_status: a.p_status};
  }
};
export async function handleRequest(req, res) {
  const json = (code, body) => { res.writeHead(code, {'Content-Type':'application/json', 'Cache-Control':'no-store'}); res.end(JSON.stringify(body)); };
  try {
    const policy = hosting.request(req.headers.host, req.headers.origin);
    if (!policy.allowedHost) return json(403, {error:'Host rejected'});
    const path = new URL(req.url, policy.origin).pathname;
    if (path === '/api/status' && req.method === 'GET') return json(200, {configured});
    if (path.startsWith('/api/rpc/') && req.method === 'POST') {
      // Both local and hosted dashboards must use their own exact origin.
      if (!policy.allowedOrigin) return json(403, {error:'Origin rejected'});
      if (req.headers['sec-fetch-site'] === 'cross-site') return json(403, {error:'Origin rejected'});
      if (!configured) return json(503, {error:'Configure the Supabase connection in .env.'});
      const name = path.slice('/api/rpc/'.length);
      if (!Object.hasOwn(routes, name)) return json(404, {error:'Unknown operation'});
      // Vercel API helpers may already have parsed the request body.
      let body = req.body;
      if (body === undefined) {
        body = '';
        for await (const chunk of req) { body += chunk; if (body.length > 8192) return json(413, {error:'Request too large'}); }
      } else if (JSON.stringify(body).length > 8192) return json(413, {error:'Request too large'});
      let args;
      try { args = routes[name](typeof body === 'string' ? JSON.parse(body) : body); } catch { return json(400, {error:'Invalid request'}); }
      const rpcName = privileged ? name : 'signal_' + name;
      const headers = {'Content-Type':'application/json', apikey: apiKey};
      if (!apiKey.startsWith('sb_')) headers.Authorization = `Bearer ${apiKey}`;
      if (!privileged) args.p_token = process.env.DASHBOARD_TOKEN;
      const upstream = await fetch(`${process.env.SUPABASE_URL.replace(/\/$/, '')}/rest/v1/rpc/${rpcName}`, {
        method:'POST', headers,
        body: JSON.stringify(args), signal: AbortSignal.timeout(30000)
      });
      if (!upstream.ok) return json(502, {error:`Supabase returned ${upstream.status}. Check the schema and connection.`});
      const raw = await upstream.text();
      return json(200, raw ? JSON.parse(raw) : null);
    }
    if ((path === '/' || path === '/index.html') && req.method === 'GET') {
      res.writeHead(200, {'Content-Type':'text/html; charset=utf-8', 'Cache-Control':'no-cache'});
      return res.end(await readFile(join(root, 'public/index.html')));
    }
    if (path === '/analysis.js' && req.method === 'GET') {
      res.writeHead(200, {'Content-Type':'text/javascript; charset=utf-8', 'Cache-Control':'no-cache'});
      return res.end(await readFile(join(root, 'public/analysis.js')));
    }
    return json(404, {error:'Not found'});
  } catch { return json(500, {error:'Connection failed. Check server configuration.'}); }
}
