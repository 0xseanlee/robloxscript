const scripts = new Set([
  'loader', 'games/towerofhell.lua', 'games/rt2.lua',
  'games/Demon Soul Simulator.lua', 'universal/all.lua',
  'universal/flyandspeed.lua', 'dev/devtp.lua',
]);
const eventTypes = new Set(['loader_started', 'load_failed', 'unsupported_game', 'script_started']);
const json = (body, status = 200) => Response.json(body, {
  status, headers: { 'Cache-Control': 'no-store' },
});

export default {
  async fetch(request, env) {
    const path = new URL(request.url).pathname;
    if (request.method === 'GET' && path === '/health') {
      try {
        const ready = await env.DB.prepare("SELECT 1 FROM analytics_settings WHERE key = 'user_salt'").first();
        return json({ ok: Boolean(ready) }, ready ? 200 : 503);
      } catch { return json({ ok: false }, 503); }
    }
    if (path !== '/events') return json({ error: 'not_found' }, 404);
    if (request.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);
    if (!request.headers.get('content-type')?.toLowerCase().startsWith('application/json')) {
      return json({ error: 'json_required' }, 415);
    }
    // Bound the body before JSON parsing, including chunked requests.
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
        !/^[a-f0-9-]{36}$/i.test(data.event_id ?? '') ||
        typeof data.user_id !== 'string' || !/^[1-9][0-9]{0,19}$/.test(data.user_id) ||
        typeof data.place_id !== 'string' || !/^[0-9]{1,20}$/.test(data.place_id) ||
        !scripts.has(data.script) || !eventTypes.has(data.event) ||
        (data.script === 'loader') === (data.event === 'script_started')) {
      return json({ error: 'invalid_event' }, 400);
    }
    try {
      const setting = await env.DB.prepare("SELECT value FROM analytics_settings WHERE key = 'user_salt'").first();
      if (!setting) return json({ error: 'not_configured' }, 503);
      const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(setting.value),
        { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
      const signature = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(data.user_id));
      const userKey = Array.from(new Uint8Array(signature), b => b.toString(16).padStart(2, '0')).join('');
      const now = Math.floor(Date.now() / 1000);
      // Atomic conditional insert: cap per-user traffic and total daily writes.
      // Public clients can be spoofed; these limits bound storage, not identity.
      const result = await env.DB.prepare(`INSERT OR IGNORE INTO events
        (event_id, user_key, script, place_id, event, created_at)
        SELECT ?, ?, ?, ?, ?, ?
        WHERE (SELECT count(*) FROM events WHERE user_key = ? AND created_at >= ?) < 30
        AND (SELECT count(*) FROM events WHERE created_at >= ?) < 10000`)
        .bind(data.event_id, userKey, data.script, data.place_id, data.event, now,
          userKey, now - 60, Math.floor(now / 86400) * 86400).run();
      return json({ ok: true, recorded: result.meta.changes > 0 });
    } catch {
      // Do not log request bodies, raw UserIds, or database errors.
      return json({ error: 'temporarily_unavailable' }, 503);
    }
  },
};
