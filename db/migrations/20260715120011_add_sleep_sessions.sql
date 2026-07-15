-- migrate:up

-- Uyku oturumları (docs/02 §3). YALNIZCA on-device TÜRETİLMİŞ metrikler; ham
-- mikrofon verisi ASLA yüklenmez (CLAUDE.md §6). night_date = kullanıcı yerel
-- gününe göre gece etiketi (06:00 sınırı, nightDateOf ile write-time hesaplanır).
CREATE TABLE sleep_sessions (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id          uuid        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  started_at       timestamptz NOT NULL,
  ended_at         timestamptz NOT NULL,
  night_date       date        NOT NULL,
  duration_minutes integer     NOT NULL,
  movement_events  integer     NOT NULL DEFAULT 0,
  sound_events     integer     NOT NULL DEFAULT 0,
  created_at       timestamptz NOT NULL DEFAULT now()
);

-- Kullanıcının gecelerini sorgulamak için (rapor/streak).
CREATE INDEX sleep_sessions_user_night_idx ON sleep_sessions (user_id, night_date DESC);

-- migrate:down

DROP TABLE IF EXISTS sleep_sessions;
