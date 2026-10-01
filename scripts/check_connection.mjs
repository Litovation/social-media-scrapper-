// Reads configuration without printing secrets or modifying the database.
const base = process.env.SUPABASE_URL?.replace(/\/$/, '');
const privileged = Boolean(process.env.SUPABASE_SERVICE_ROLE_KEY);
const key = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_KEY;
if (!base || !key || (!privileged && !process.env.DASHBOARD_TOKEN)) {
  console.error('Supabase connection not configured. Missing project URL, key or dashboard token.');
  process.exit(2);
}
try {
  const headers = {apikey:key, 'Content-Type':'application/json'};
  if (!key.startsWith('sb_')) headers.Authorization = `Bearer ${key}`;
  const response = await fetch(base + '/rest/v1/rpc/' + (privileged ? 'dashboard' : 'signal_dashboard'), {
    method:'POST', headers,
    body:JSON.stringify({p_days:1095, ...(privileged ? {} : {p_token:process.env.DASHBOARD_TOKEN})}), signal:AbortSignal.timeout(30000)
  });
  if (!response.ok) { console.error(`Dashboard RPC unavailable (${response.status}). Check project, schema and server-key permissions.`); process.exit(1); }
  const data = await response.json();
  if (!data?.summary || !Array.isArray(data.accounts)) throw new Error('Unexpected response');
  console.log(JSON.stringify({connected:true,posts:data.summary.posts_all,tagged:data.summary.tagged,lastCollection:data.summary.last_collect,lastLayaRun:data.summary.last_tag},null,2));
} catch { console.error('Could not verify the dashboard connection.'); process.exit(1); }
