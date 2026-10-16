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
      async run() { return { meta: { changes: db.prepare(sql).run(...params).changes } }; },
    };
  } } };
  return { db, env };
}
const event = (extra = {}) => ({ event_id: crypto.randomUUID(), user_id: '123456789',
  place_id: '1962086868', script: 'games/towerofhell.lua', event: 'script_started', ...extra });
const post = data => new Request('https://example.com/events', { method: 'POST',
  headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) });

test('ingests, deduplicates, pseudonymizes, and groups usage', async () => {
  const { db, env } = database();
  const data = event();
  assert.equal((await (await worker.fetch(post(data), env)).json()).recorded, true);
  assert.equal((await (await worker.fetch(post(data), env)).json()).recorded, false);
  await worker.fetch(post(event({ script: 'games/rt2.lua' })), env);
  await worker.fetch(post(event({ script: 'loader', event: 'loader_started' })), env);
  const stored = db.prepare('SELECT * FROM events LIMIT 1').get();
  assert.match(stored.user_key, /^[a-f0-9]{64}$/);
  assert.notEqual(stored.user_key, data.user_id);
  assert.equal('user_id' in stored, false);
  assert.equal(db.prepare('SELECT executions FROM daily_usage').get().executions, 2);
  assert.equal(db.prepare('SELECT users FROM daily_usage').get().users, 1);
  assert.equal(db.prepare('SELECT count(*) AS n FROM user_usage').get().n, 2);
  assert.equal((await worker.fetch(new Request('https://example.com/events'), env)).status, 405);
  assert.equal((await worker.fetch(new Request('https://example.com/health'), env)).status, 200);
  db.close();
});
test('rejects invalid fields and oversized bodies without writing', async () => {
  const { db, env } = database();
  for (const extra of [{ script: 'unknown' }, { user_id: 'abc' }, { event: 'unknown' },
    { script: 'loader' }, { event: 'loader_started' }, { place_id: {} }]) {
    assert.equal((await worker.fetch(post(event(extra)), env)).status, 400);
  }
  assert.equal((await worker.fetch(post(null), env)).status, 400);
  assert.equal((await worker.fetch(post(event({ padding: 'x'.repeat(2048) })), env)).status, 413);
  assert.equal(db.prepare('SELECT count(*) AS n FROM events').get().n, 0);
  db.close();
});
test('enforces the user and daily caps', async () => {
  const { db, env } = database();
  for (let i = 0; i < 30; i++) {
    assert.equal((await (await worker.fetch(post(event()), env)).json()).recorded, true);
  }
  assert.equal((await (await worker.fetch(post(event()), env)).json()).recorded, false);
  const insert = db.prepare('INSERT INTO events VALUES (?, ?, ?, ?, ?, ?)');
  const now = Math.floor(Date.now()/1000);
  for (let i = 30; i < 10000; i++) insert.run(`test-${i}`, `user-${i}`, 'loader', '1', 'loader_started', now);
  assert.equal((await (await worker.fetch(post(event({ user_id: '999' })), env)).json()).recorded, false);
  db.close();
});
