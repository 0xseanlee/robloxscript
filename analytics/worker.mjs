const scripts = new Set([
  'loader', 'games/towerofhell.lua', 'games/rt2.lua',
  'games/Demon Soul Simulator.lua', 'universal/all.lua',
  'universal/flyandspeed.lua', 'dev/devtp.lua',
]);
const eventTypes = new Set(['loader_started', 'load_failed', 'unsupported_game', 'script_started']);
const publicHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
  'X-Content-Type-Options': 'nosniff',
};
const json = (body, status = 200) => Response.json(body, {
  status, headers: { ...publicHeaders, 'Cache-Control': 'no-store' },
});
const idPattern = /^[1-9][0-9]{0,19}$/;
const uuidPattern = /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;

function filters(url) {
  const days = url.searchParams.get('days') ?? '30';
  const script = url.searchParams.get('script') ?? '';
  const userId = url.searchParams.get('user_id') ?? '';
  if (!['7', '30', '90', 'all'].includes(days) ||
      (script && (!scripts.has(script) || script === 'loader')) ||
      (userId && !idPattern.test(userId))) throw new Error('invalid_query');
  // 以台灣日曆日計算，包含今天。
  const now = Math.floor(Date.now() / 1000);
  const start = days === 'all' ? 0 : Math.floor((now + 28800) / 86400) * 86400 - 28800 - (Number(days) - 1) * 86400;
  const parts = ["event = 'script_started'", 'created_at >= ?'];
  const params = [start];
  if (script) { parts.push('script = ?'); params.push(script); }
  if (userId) { parts.push('user_id = ?'); params.push(userId); }
  return { where: parts.join(' AND '), params, start, days };
}
function integer(url, key, fallback, max) {
  const value = url.searchParams.get(key);
  if (value === null) return fallback;
  if (!/^[0-9]{1,7}$/.test(value) || Number(value) > max) throw new Error('invalid_query');
  return Number(value);
}
async function rows(env, sql, params = []) {
  return (await env.DB.prepare(sql).bind(...params).all()).results;
}
async function readPublic(url, env) {
  const f = filters(url);
  if (url.pathname === '/api/summary') {
    const [totals, daily] = await Promise.all([
      env.DB.prepare(`SELECT coalesce(sum(executions), 0) AS executions, count(*) AS accounts,
        coalesce(sum(CASE WHEN executions > 1 THEN 1 ELSE 0 END), 0) AS returning_accounts,
        min(first_seen) AS first_seen, max(last_seen) AS last_seen
        FROM (SELECT user_id, count(*) AS executions, min(created_at) AS first_seen,
        max(created_at) AS last_seen FROM public_events WHERE ${f.where} GROUP BY user_id)`)
        .bind(...f.params).first(),
      rows(env, `SELECT date(created_at, 'unixepoch', '+8 hours') AS day,
        count(*) AS executions, count(DISTINCT user_id) AS accounts FROM public_events
        WHERE ${f.where} GROUP BY day ORDER BY day DESC LIMIT 30`, f.params),
    ]);
    return json({ ...totals, daily: daily.reverse(), timezone: 'Asia/Taipei',
      days: f.days, generated_at: Math.floor(Date.now() / 1000), identity: 'roblox_user_id',
      source: 'client_reports', legacy_anonymous_excluded: true });
  }
  if (url.pathname === '/api/users') {
    const offset = integer(url, 'offset', 0, 1000000);
    const limit = Math.max(1, integer(url, 'limit', 50, 100));
    const sort = url.searchParams.get('sort') ?? 'recent';
    if (!['recent', 'executions'].includes(sort)) return json({ error: 'invalid_query' }, 400);
    const order = sort === 'recent' ? 'last_seen DESC, user_id' : 'executions DESC, last_seen DESC, user_id';
    const [users, total] = await Promise.all([
      rows(env, `SELECT user_id, count(*) AS executions, count(DISTINCT script) AS scripts,
        min(created_at) AS first_seen, max(created_at) AS last_seen FROM public_events
        WHERE ${f.where} GROUP BY user_id ORDER BY ${order} LIMIT ? OFFSET ?`, [...f.params, limit, offset]),
      env.DB.prepare(`SELECT count(DISTINCT user_id) AS total FROM public_events WHERE ${f.where}`).bind(...f.params).first(),
    ]);
    return json({ users, total: total.total, offset, limit, has_more: offset + users.length < total.total });
  }
  if (url.pathname === '/api/events') {
    if (!url.searchParams.get('user_id')) return json({ error: 'user_id_required' }, 400);
    const limit = Math.max(1, integer(url, 'limit', 50, 100));
    const cursor = url.searchParams.get('cursor');
    let where = f.where;
    const params = [...f.params];
    if (cursor) {
      const match = /^([0-9]{1,12}):([a-f0-9-]{36})$/i.exec(cursor);
      if (!match || !uuidPattern.test(match[2])) return json({ error: 'invalid_cursor' }, 400);
      where += ' AND (created_at < ? OR (created_at = ? AND event_id < ?))';
      params.push(Number(match[1]), Number(match[1]), match[2]);
    }
    const events = await rows(env, `SELECT event_id, user_id, script, created_at FROM public_events
      WHERE ${where} ORDER BY created_at DESC, event_id DESC LIMIT ?`, [...params, limit + 1]);
    const hasMore = events.length > limit;
    if (hasMore) events.pop();
    const last = events.at(-1);
    return json({ events, next_cursor: hasMore ? `${last.created_at}:${last.event_id}` : null });
  }
  return json({ error: 'not_found' }, 404);
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;
    if (request.method === 'OPTIONS' && (path === '/events' || path === '/public/events' || path.startsWith('/api/'))) {
      return new Response(null, { status: 204, headers: publicHeaders });
    }
    if (request.method === 'GET' && path === '/health') {
      try {
        await env.DB.prepare('SELECT 1 FROM public_events LIMIT 1').first();
        return json({ ok: true, version: 'public-users-v2' });
      } catch { return json({ ok: false, error: 'migration_required' }, 503); }
    }
    if (path.startsWith('/api/')) {
      if (request.method !== 'GET') return json({ error: 'method_not_allowed' }, 405);
      try { return await readPublic(url, env); }
      catch (error) {
        return json({ error: error.message === 'invalid_query' ? 'invalid_query' : 'temporarily_unavailable' },
          error.message === 'invalid_query' ? 400 : 503);
      }
    }
    if (path !== '/events' && path !== '/public/events') return json({ error: 'not_found' }, 404);
    if (request.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
    if (!request.headers.get('content-type')?.toLowerCase().startsWith('application/json')) {
      return json({ error: 'json_required' }, 415);
    }
    const reader = request.body?.getReader();
    if (!reader) return json({ error: 'invalid_body' }, 400);
    let size = 0;
    const chunks = [];
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > 2048) { await reader.cancel(); return json({ error: 'body_too_large' }, 413); }
      chunks.push(value);
    }
    const bytes = new Uint8Array(size);
    let offset = 0;
    for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
    let data;
    try { data = JSON.parse(new TextDecoder().decode(bytes)); }
    catch { return json({ error: 'invalid_json' }, 400); }
    if (!data || typeof data !== 'object' ||
        typeof data.event_id !== 'string' || !uuidPattern.test(data.event_id) ||
        typeof data.user_id !== 'string' || !idPattern.test(data.user_id) ||
        typeof data.place_id !== 'string' || !/^[0-9]{1,20}$/.test(data.place_id) ||
        !scripts.has(data.script) || !eventTypes.has(data.event) ||
        (data.script === 'loader') === (data.event === 'script_started')) {
      return json({ error: 'invalid_event' }, 400);
    }
    try {
      const now = Math.floor(Date.now() / 1000);
      // 原本的 /events 仍保留匿名化；只有獨立前置程式使用公開端點。
      if (path === '/events') {
        const setting = await env.DB.prepare("SELECT value FROM analytics_settings WHERE key = 'user_salt'").first();
        if (!setting) return json({ error: 'not_configured' }, 503);
        const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(setting.value),
          { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
        const signature = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(data.user_id));
        const userKey = Array.from(new Uint8Array(signature), b => b.toString(16).padStart(2, '0')).join('');
        const result = await env.DB.prepare(`INSERT OR IGNORE INTO events
          (event_id, user_key, script, place_id, event, created_at)
          SELECT ?, ?, ?, ?, ?, ?
          WHERE (SELECT count(*) FROM events WHERE user_key = ? AND created_at >= ?) < 30
          AND (SELECT count(*) FROM events WHERE created_at >= ?) < 10000`)
          .bind(data.event_id, userKey, data.script, data.place_id, data.event, now,
            userKey, now - 60, Math.floor(now / 86400) * 86400).run();
        return json({ ok: true, recorded: result.meta.changes > 0 });
      }
      const result = await env.DB.prepare(`INSERT OR IGNORE INTO public_events
        (event_id, user_id, script, place_id, event, created_at)
        SELECT ?, ?, ?, ?, ?, ?
        WHERE (SELECT count(*) FROM public_events WHERE user_id = ? AND created_at >= ?) < 30
        AND (SELECT count(*) FROM public_events WHERE created_at >= ?) < 10000`)
        .bind(data.event_id, data.user_id, data.script, data.place_id, data.event, now,
          data.user_id, now - 60, Math.floor(now / 86400) * 86400).run();
      return json({ ok: true, recorded: result.meta.changes > 0 });
    } catch {
      return json({ error: 'temporarily_unavailable' }, 503);
    }
  },
};
