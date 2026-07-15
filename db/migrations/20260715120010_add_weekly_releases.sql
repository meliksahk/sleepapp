-- migrate:up

-- Haftalık soundscape yayınları (docs/02 §3). Admin CMS zamanlar; uygulama okur.
CREATE TABLE weekly_releases (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  week_start     date        NOT NULL UNIQUE,
  soundscape_ids uuid[]      NOT NULL DEFAULT '{}',
  notes          text,
  created_at     timestamptz NOT NULL DEFAULT now()
);

-- migrate:down

DROP TABLE IF EXISTS weekly_releases;
