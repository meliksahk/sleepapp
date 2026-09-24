-- migrate:up

-- Hatırlatıcı ve sessiz saatler (F3 · bildirim ayarları ekranı).
--
-- NEDEN PROFİLE: kullanıcı başına TEK bir tercih; ayrı tabloya çıkarmak 1:1 bir
-- join'i bedavaya satın almak olurdu. `notifications_enabled` zaten burada.
--
-- ⚠️ SAAT, KULLANICININ YEREL SAATİ (0–23) — UTC DEĞİL. Bilinçli: "23:00'te
-- hatırlat" cümlesi kullanıcının duvar saatine aittir; UTC'de saklasaydık
-- kullanıcı seyahat edince ya da yaz saati değişince hatırlatıcı kayardı.
-- Gönderim anında `timezone` (aynı satırda) ile UTC'ye çevrilir.
ALTER TABLE profiles
  ADD COLUMN reminder_hour      smallint,
  ADD COLUMN quiet_hours_start  smallint,
  ADD COLUMN quiet_hours_end    smallint;

-- Saat aralığı DB'de de zorlanır: uygulama katmanı atlanabilir, tablo atlanamaz.
ALTER TABLE profiles
  ADD CONSTRAINT profiles_reminder_hour_range
    CHECK (reminder_hour IS NULL OR (reminder_hour BETWEEN 0 AND 23)),
  ADD CONSTRAINT profiles_quiet_start_range
    CHECK (quiet_hours_start IS NULL OR (quiet_hours_start BETWEEN 0 AND 23)),
  ADD CONSTRAINT profiles_quiet_end_range
    CHECK (quiet_hours_end IS NULL OR (quiet_hours_end BETWEEN 0 AND 23));

-- migrate:down

ALTER TABLE profiles
  DROP CONSTRAINT profiles_reminder_hour_range,
  DROP CONSTRAINT profiles_quiet_start_range,
  DROP CONSTRAINT profiles_quiet_end_range,
  DROP COLUMN reminder_hour,
  DROP COLUMN quiet_hours_start,
  DROP COLUMN quiet_hours_end;
