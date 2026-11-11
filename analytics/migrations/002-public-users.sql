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
