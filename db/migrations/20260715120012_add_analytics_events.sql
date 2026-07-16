-- migrate:up

-- Analitik olayları (docs/02 analytics-ingest). İstemciden gelen türetilmiş
-- ürün olayları (ör. archetype_completed). PII taşımaz — yalnızca olay adı +
-- zaman + serbest props (kişisel veri konmaz; body-size limiti #29 ile sınırlı).
CREATE TABLE analytics_events (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name        text        NOT NULL,
  occurred_at timestamptz NOT NULL,
  props       jsonb       NOT NULL DEFAULT '{}',
  received_at timestamptz NOT NULL DEFAULT now()
);

-- Ada ve zamana göre panolar (retention, funnel).
CREATE INDEX analytics_events_name_time_idx ON analytics_events (name, occurred_at DESC);
CREATE INDEX analytics_events_user_idx ON analytics_events (user_id);

-- migrate:down

DROP TABLE IF EXISTS analytics_events;
