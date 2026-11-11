import { test } from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';
import worker from './worker.mjs';

function database() {
  const db = new DatabaseSync(':memory:');
  db.exec(readFileSync(new URL('./schema.sql', import.meta.url), 'utf8'));
  const env = { DB: { prepare(sql) {
    let params = [];
    return {
      bind(...values) { params = values; return this; },
      async first() { return db.prepare(sql).get(...params); },
      async all() { return { results: db.prepare(sql).all(...params) }; },
      async run() { return { meta: { changes: db.prepare(sql).run(...params).changes } }; },
    };
  } } };
  return { db, env };
}
const event = (extra = {}) => ({ event_id: crypto.randomUUID(), user_id: '123456789',
  place_id: '1962086868', script: 'games/towerofhell.lua', event: 'script_started', ...extra });
const post = data => new Request('https://example.com/public/events', { method: 'POST',
  headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) });
const get = async (env, path) => {
  const response = await worker.fetch(new Request('https://example.com' + path), env);
  return { status: response.status, headers: response.headers, data: await response.json() };
};

test('same UserId accumulates, different accounts stay separate, duplicate transport is ignored', async () => {
  const { db, env } = database();
  const data = event();
  assert.equal((await (await worker.fetch(post(data), env)).json()).recorded, true);
  assert.equal((await (await worker.fetch(post(data), env)).json()).recorded, false);
  await worker.fetch(post(event({ script: 'games/rt2.lua' })), env);
  await worker.fetch(post(event({ user_id: '999' })), env);
  await worker.fetch(post(event({ script: 'loader', event: 'loader_started' })), env);
  const summary = await get(env, '/api/summary?days=all');
  assert.equal(summary.data.executions, 3);
  assert.equal(summary.data.accounts, 2);
  assert.equal(summary.data.returning_accounts, 1);
  assert.equal(summary.headers.get('Access-Control-Allow-Origin'), '*');
  const users = await get(env, '/api/users?days=all&sort=executions');
  assert.equal(users.data.users[0].user_id, data.user_id);
  assert.equal(users.data.users[0].executions, 2);
  assert.equal(users.data.users[0].scripts, 2);
  const filtered = await get(env, '/api/summary?days=all&script=games%2Frt2.lua');
  assert.equal(filtered.data.executions, 1);
  assert.equal(filtered.data.returning_accounts, 0);
  assert.equal((await get(env, '/health')).data.version, 'public-users-v2');
  assert.equal(db.prepare('SELECT count(*) AS n FROM events').get().n, 0);
  db.close();
});

test('migration preserves old anonymous history without exposing or linking it', async () => {
  const { db, env } = database();
  db.prepare('INSERT INTO events VALUES (?, ?, ?, ?, ?, ?)').run('old', 'old-pseudonym', 'games/rt2.lua', '1', 'script_started', Math.floor(Date.now()/1000));
  const migration = readFileSync(new URL('./migrations/002-public-users.sql', import.meta.url), 'utf8');
  db.exec(migration); db.exec(migration);
  assert.equal((await get(env, '/api/summary?days=all')).data.executions, 0);
  assert.deepEqual((await get(env, '/api/users?days=all')).data.users, []);
  await worker.fetch(post(event()), env);
  assert.equal((await get(env, '/api/summary?days=all')).data.executions, 1);
  assert.equal(db.prepare('SELECT count(*) AS n FROM events').get().n, 1);
  assert.equal(db.prepare('SELECT user_key FROM events').get().user_key, 'old-pseudonym');
  db.close();
});

test('user pagination and event cursor do not lose simultaneous executions', async () => {
  const { db, env } = database();
  const insert = db.prepare('INSERT INTO public_events VALUES (?, ?, ?, ?, ?, ?)');
  const now = Math.floor(Date.now()/1000);
  for (let i = 0; i < 6; i++) insert.run(`00000000-0000-4000-8000-${String(i).padStart(12, '0')}`, i < 4 ? '123' : String(i), 'games/rt2.lua', '1', 'script_started', now);
  const first = (await get(env, '/api/users?days=all&sort=executions&limit=2')).data;
  assert.equal(first.total, 3); assert.equal(first.has_more, true); assert.equal(first.users[0].user_id, '123');
  assert.equal((await get(env, '/api/users?days=all&limit=2&offset=2')).data.users.length, 1);
  const a = (await get(env, '/api/events?days=all&user_id=123&limit=2')).data;
  const b = (await get(env, '/api/events?days=all&user_id=123&limit=2&cursor=' + encodeURIComponent(a.next_cursor))).data;
  assert.equal(a.events.length, 2); assert.equal(b.events.length, 2); assert.equal(b.next_cursor, null);
  assert.equal(new Set([...a.events, ...b.events].map(item => item.event_id)).size, 4);
  assert.deepEqual((await get(env, '/api/users?user_id=99999')).data.users, []);
  db.close();
});

test('Taipei calendar windows, daily grouping and explicit account filtering', async () => {
  const { db, env } = database();
  const realNow = Date.now;
  try {
    Date.now = () => Date.parse('2026-11-11T03:00:00Z');
    const insert = db.prepare('INSERT INTO public_events VALUES (?, ?, ?, ?, ?, ?)');
    const sample = (when, id) => insert.run(crypto.randomUUID(), id, 'games/rt2.lua', '1', 'script_started', Date.parse(when)/1000);
    sample('2026-11-04T15:59:59Z', '1'); // 台灣 11/04，7 天以外。
    sample('2026-11-04T16:00:00Z', '2'); // 台灣 11/05，7 天起點。
    sample('2026-11-10T16:00:00Z', '2'); // 台灣 11/11。
    const summary = (await get(env, '/api/summary?days=7')).data;
    assert.equal(summary.executions, 2); assert.equal(summary.accounts, 1);
    assert.deepEqual(summary.daily.map(item => item.day), ['2026-11-05', '2026-11-11']);
    assert.equal((await get(env, '/api/users?days=all&user_id=1')).data.users[0].executions, 1);
  } finally { Date.now = realNow; db.close(); }
});

test('rejects invalid input, oversized bodies, invalid query and write attempts', async () => {
  const { db, env } = database();
  for (const extra of [{ script: 'unknown' }, { user_id: 'abc' }, { user_id: 123 }, { event: 'unknown' },
    { script: 'loader' }, { event: 'loader_started' }, { place_id: {} }, { event_id: '-'.repeat(36) }]) {
    assert.equal((await worker.fetch(post(event(extra)), env)).status, 400);
  }
  assert.equal((await worker.fetch(post(null), env)).status, 400);
  assert.equal((await worker.fetch(post(event({ padding: 'x'.repeat(2048) })), env)).status, 413);
  for (const query of ['/api/users?sort=bad', '/api/users?offset=-1', '/api/users?limit=999',
    '/api/summary?days=1000', '/api/users?user_id=1%27', '/api/events', '/api/events?user_id=1&cursor=bad']) {
    assert.equal((await get(env, query)).status, 400, query);
  }
  for (const method of ['POST', 'DELETE', 'PUT']) {
    assert.equal((await worker.fetch(new Request('https://example.com/api/users', { method }), env)).status, 405);
  }
  assert.equal((await worker.fetch(new Request('https://example.com/events'), env)).status, 405);
  assert.equal((await worker.fetch(new Request('https://example.com/api/users', { method: 'OPTIONS' }), env)).status, 204);
  assert.equal(db.prepare('SELECT count(*) AS n FROM public_events').get().n, 0);
  db.close();
});

test('bounds public ingestion per account and per day', async () => {
  const { db, env } = database();
  for (let i = 0; i < 30; i++) assert.equal((await (await worker.fetch(post(event()), env)).json()).recorded, true);
  assert.equal((await (await worker.fetch(post(event()), env)).json()).recorded, false);
  const insert = db.prepare('INSERT INTO public_events VALUES (?, ?, ?, ?, ?, ?)');
  const now = Math.floor(Date.now()/1000);
  for (let i = 30; i < 10000; i++) insert.run(`test-${i}`, `user-${i}`, 'loader', '1', 'loader_started', now);
  assert.equal((await (await worker.fetch(post(event({ user_id: '999' })), env)).json()).recorded, false);
  db.close();
});

test('health and API fail visibly before migration', async () => {
  const { db, env } = database();
  db.exec('DROP TABLE public_events');
  assert.equal((await get(env, '/health')).status, 503);
  assert.equal((await get(env, '/api/summary')).status, 503);
  db.close();
});

test('existing clients remain anonymous and never appear in public reporting', async () => {
  const { db, env } = database();
  const data = event();
  const request = new Request('https://example.com/events', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) });
  assert.equal((await (await worker.fetch(request, env)).json()).recorded, true);
  const stored = db.prepare('SELECT * FROM events').get();
  assert.match(stored.user_key, /^[a-f0-9]{64}$/);
  assert.equal('user_id' in stored, false);
  assert.equal((await get(env, '/api/summary?days=all')).data.executions, 0);
  db.close();
});
