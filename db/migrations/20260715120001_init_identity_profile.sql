-- migrate:up

-- Kimlik enum'ları
CREATE TYPE user_kind AS ENUM ('anonymous', 'registered', 'admin');
CREATE TYPE ott_purpose AS ENUM ('magic_link', 'email_verify', 'password_reset');

-- users — kendi auth'umuz (docs/02 §2.1, §3). Kripto/hash yalnızca identity modülünde üretilir.
CREATE TABLE users (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  kind              user_kind   NOT NULL DEFAULT 'anonymous',
  email             text        UNIQUE,
  email_verified_at timestamptz,
  password_hash     text,
  totp_secret       text,
  roles             text[]      NOT NULL DEFAULT '{}',
  created_at        timestamptz NOT NULL DEFAULT now(),
  deleted_at        timestamptz
);

-- auth_devices — cihaz başına anonim kayıt (POST /v1/auth/device)
CREATE TABLE auth_devices (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id            uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  device_fingerprint text        NOT NULL UNIQUE,
  platform           text        NOT NULL,
  created_at         timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_auth_devices_user ON auth_devices (user_id);

-- refresh_tokens — opak, DB'de hash'li; rotation + reuse-detection (family_id ile zincir)
CREATE TABLE refresh_tokens (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  token_hash text        NOT NULL UNIQUE,
  family_id  uuid        NOT NULL,
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_refresh_tokens_user ON refresh_tokens (user_id);
CREATE INDEX idx_refresh_tokens_family ON refresh_tokens (family_id);

-- one_time_tokens — magic link / e-posta doğrulama / şifre sıfırlama (tek kullanımlık + süreli)
CREATE TABLE one_time_tokens (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  purpose    ott_purpose NOT NULL,
  token_hash text        NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  used_at    timestamptz
);
CREATE INDEX idx_ott_user ON one_time_tokens (user_id);

-- profiles — id = users.id (1:1)
CREATE TABLE profiles (
  id           uuid PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
  display_name text,
  chronotype   text,
  locale       text        NOT NULL DEFAULT 'en',
  timezone     text        NOT NULL DEFAULT 'UTC',
  created_at   timestamptz NOT NULL DEFAULT now()
);

-- migrate:down

DROP TABLE IF EXISTS profiles;
DROP TABLE IF EXISTS one_time_tokens;
DROP TABLE IF EXISTS refresh_tokens;
DROP TABLE IF EXISTS auth_devices;
DROP TABLE IF EXISTS users;
DROP TYPE IF EXISTS ott_purpose;
DROP TYPE IF EXISTS user_kind;
