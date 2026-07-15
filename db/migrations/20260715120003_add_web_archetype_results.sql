-- migrate:up

-- Anonim web archetype testi sonuçları (docs/05 W0 viral araç). Kullanıcı YOK (PII yok);
-- paylaşım slug'ı ile /a/{...} sayfası + OG verisi servis edilir.
CREATE TABLE web_archetype_results (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  share_slug     text        NOT NULL UNIQUE,
  archetype_slug text        NOT NULL,
  scores         jsonb       NOT NULL,
  version        int         NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now()
);

-- migrate:down

DROP TABLE IF EXISTS web_archetype_results;
