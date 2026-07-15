-- migrate:up

-- Feature flag + remote config (docs/02 §3). rules jsonb: {enabled, rolloutPercentage?, ...}.
-- Yazma admin modülünden (B3); F1'de yalnızca okuma + değerlendirme.
CREATE TABLE feature_flags (
  key         text PRIMARY KEY,
  description text,
  rules       jsonb       NOT NULL DEFAULT '{"enabled": false}'::jsonb,
  updated_by  uuid,
  updated_at  timestamptz NOT NULL DEFAULT now()
);

-- migrate:down

DROP TABLE IF EXISTS feature_flags;
