-- NOCTA lokal seed — idempotent, YALNIZCA geliştirme. Gerçek kullanıcı/PII içermez.
-- Çalıştır: psql "$DATABASE_URL" -f db/seed.sql  (docker compose ayaktayken)

-- Sabit UUID'li örnek anonim kullanıcı + profil (lokal deneyler için stabil kimlik).
INSERT INTO users (id, kind, roles)
VALUES ('00000000-0000-0000-0000-000000000001', 'anonymous', '{}')
ON CONFLICT (id) DO NOTHING;

INSERT INTO profiles (id, display_name, locale, timezone)
VALUES ('00000000-0000-0000-0000-000000000001', 'Dev Sleeper', 'en', 'UTC')
ON CONFLICT (id) DO NOTHING;

INSERT INTO auth_devices (user_id, device_fingerprint, platform)
VALUES ('00000000-0000-0000-0000-000000000001', 'dev-fingerprint-0001', 'seed')
ON CONFLICT (device_fingerprint) DO NOTHING;
