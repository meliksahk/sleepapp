-- migrate:up

-- Ön-lansman bekleme listesi (docs/05 W0). Anonim; e-posta benzersiz (idempotent kayıt).
CREATE TABLE waitlist (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email      text        NOT NULL UNIQUE,
  source     text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- migrate:down

DROP TABLE IF EXISTS waitlist;
