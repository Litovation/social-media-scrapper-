// Trust only this deployment's configured domains, never arbitrary forwarded hosts.
export function hostingPolicy(env = process.env, port = 4173) {
  const hosted = env.VERCEL === '1' || Boolean(env.APP_ORIGIN);
  const origins = new Map();
  const add = value => {
    if (!value) return;
    const url = new URL(value);
    if (url.protocol !== 'https:' || url.username || url.password || url.pathname !== '/' || url.search || url.hash) {
      throw new Error('APP_ORIGIN must be an HTTPS origin without a path.');
    }
    origins.set(url.host, url.origin);
  };
  if (hosted) {
    for (const value of [env.VERCEL_URL, env.VERCEL_PROJECT_PRODUCTION_URL, env.VERCEL_BRANCH_URL]) {
      if (value) add(`https://${value}`);
    }
    add(env.APP_ORIGIN);
  } else {
    origins.set(`127.0.0.1:${port}`, `http://127.0.0.1:${port}`);
    origins.set(`localhost:${port}`, `http://localhost:${port}`);
  }
  return {
    hosted,
    request(host, origin) {
      const expected = origins.get(String(host || '').toLowerCase());
      return {allowedHost: Boolean(expected), allowedOrigin: !origin || origin === expected, origin: expected};
    }
  };
}
