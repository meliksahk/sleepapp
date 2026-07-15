-- migrate:up

-- Archetype test sonuçları (docs/02 §3). Kullanıcı başına birden çok sonuç olabilir
-- (yeniden test); en yeni = ORDER BY created_at DESC.
CREATE TABLE archetype_results (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  archetype_slug text        NOT NULL,
  answers        jsonb       NOT NULL,
  scores         jsonb       NOT NULL,
  version        int         NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_archetype_results_user ON archetype_results (user_id, created_at DESC);

-- migrate:down

DROP TABLE IF EXISTS archetype_results;
