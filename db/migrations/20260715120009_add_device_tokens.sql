-- migrate:up

-- Push cihaz token'ları (docs/02 §3). Gerçek APNs/FCM gönderimi docs/10'a ertelendi;
-- bu tablo token kaydını tutar. token benzersiz (cihaz hesap değiştirirse yeniden atanır).
CREATE TABLE device_tokens (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  platform     text        NOT NULL,
  token        text        NOT NULL UNIQUE,
  last_seen_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_device_tokens_user ON device_tokens (user_id);

-- migrate:down

DROP TABLE IF EXISTS device_tokens;
