// Reads configuration without printing secrets or modifying the database.
const base = process.env.SUPABASE_URL?.replace(/\/$/, '');
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
if (!base || !key) {
  console.error('Supabase connection not configured. Missing project URL or server key.');
  process.exit(2);
}
try {
  const response = await fetch(base + '/rest/v1/rpc/dashboard', {
    method:'POST', headers:{apikey:key, Authorization:`Bearer ${key}`, 'Content-Type':'application/json'},
    body:JSON.stringify({p_days:1095}), signal:AbortSignal.timeout(30000)
  });
  if (!response.ok) { console.error(`Dashboard RPC unavailable (${response.status}). Check project, schema and server-key permissions.`); process.exit(1); }
  const data = await response.json();
  if (!data?.summary || !Array.isArray(data.accounts)) throw new Error('Unexpected response');
  console.log(JSON.stringify({connected:true,posts:data.summary.posts_all,tagged:data.summary.tagged,lastCollection:data.summary.last_collect,lastLayaRun:data.summary.last_tag},null,2));
} catch { console.error('Could not verify the dashboard connection.'); process.exit(1); }
