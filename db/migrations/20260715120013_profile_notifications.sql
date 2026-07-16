-- migrate:up

-- Push bildirim tercihi (docs/06). Varsayılan açık; kullanıcı kapatabilir.
-- Bildirim gönderimi ileride bu bayrağı kontrol eder (opt-out).
ALTER TABLE profiles ADD COLUMN notifications_enabled boolean NOT NULL DEFAULT true;

-- migrate:down

ALTER TABLE profiles DROP COLUMN notifications_enabled;
