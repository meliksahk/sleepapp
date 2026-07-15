-- migrate:up

CREATE TYPE content_status AS ENUM ('draft', 'scheduled', 'published');

-- soundscapes — admin CMS yazar, uygulama okur (docs/02 §3). Ses TARİFİ (engine_params);
-- MP3 stream yok, üretim on-device (docs/04).
CREATE TABLE soundscapes (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug               text           NOT NULL UNIQUE,
  title_i18n         jsonb          NOT NULL,
  engine_params      jsonb          NOT NULL,
  layer_defs         jsonb          NOT NULL,
  archetype_affinity text[]         NOT NULL DEFAULT '{}',
  status             content_status NOT NULL DEFAULT 'draft',
  publish_at         timestamptz,
  created_by         uuid,
  version            int            NOT NULL DEFAULT 1,
  created_at         timestamptz    NOT NULL DEFAULT now()
);
CREATE INDEX idx_soundscapes_status ON soundscapes (status);

-- presets — archetype başına varsayılan mixer state
CREATE TABLE presets (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  soundscape_id  uuid  NOT NULL REFERENCES soundscapes (id) ON DELETE CASCADE,
  archetype_slug text  NOT NULL,
  mixer_state    jsonb NOT NULL
);
CREATE INDEX idx_presets_soundscape ON presets (soundscape_id);

-- migrate:down

DROP TABLE IF EXISTS presets;
DROP TABLE IF EXISTS soundscapes;
DROP TYPE IF EXISTS content_status;
