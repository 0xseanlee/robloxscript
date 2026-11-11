CREATE TABLE IF NOT EXISTS analytics_settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);
INSERT OR IGNORE INTO analytics_settings VALUES ('user_salt', lower(hex(randomblob(32))));
CREATE TABLE IF NOT EXISTS events (
  event_id TEXT PRIMARY KEY,
  user_key TEXT NOT NULL,
  script TEXT NOT NULL,
  place_id TEXT NOT NULL,
  event TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS events_time ON events(created_at);
CREATE INDEX IF NOT EXISTS events_user_time ON events(user_key, created_at);
CREATE VIEW IF NOT EXISTS daily_usage AS
SELECT date(created_at, 'unixepoch', '+8 hours') AS day, count(*) AS executions,
  count(DISTINCT user_key) AS users FROM events WHERE event = 'script_started' GROUP BY day;
CREATE VIEW IF NOT EXISTS script_usage AS
SELECT script, count(*) AS executions, count(DISTINCT user_key) AS users,
  datetime(max(created_at), 'unixepoch', '+8 hours') AS last_used
FROM events WHERE event = 'script_started' GROUP BY script;
CREATE VIEW IF NOT EXISTS user_usage AS
SELECT user_key, script, count(*) AS executions,
  datetime(max(created_at), 'unixepoch', '+8 hours') AS last_used
FROM events WHERE event = 'script_started' GROUP BY user_key, script;
-- 僅公開本次更新後收到的紀錄；不連結、還原或公開舊匿名資料。
CREATE TABLE IF NOT EXISTS public_events (
  event_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  script TEXT NOT NULL,
  place_id TEXT NOT NULL,
  event TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS public_events_time ON public_events(created_at DESC, event_id DESC);
CREATE INDEX IF NOT EXISTS public_events_user_time ON public_events(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS public_events_script_time ON public_events(script, created_at DESC);
