-- migrate:up

-- admin_audit_log — panelde yapılan HER YAZMA işleminin izi (docs/03).
--
-- NEDEN: içerik yayınlanıyor/geri çekiliyor/tarifi değişiyordu ama KİMİN yaptığının
-- izi yoktu. Yanlış içerik canlıya çıktığında kimse hesap veremez; üstelik bu, sonradan
-- eklenmesi en zor şeylerden biridir çünkü GEÇMİŞ GERİ GELMEZ.
--
-- `users.id`'ye FK var ama ON DELETE **SET NULL**, CASCADE DEĞİL: bir admin hesabı
-- silinince onun geçmişteki eylemleri KAYBOLMAMALI — denetim izinin bütün anlamı
-- budur. Aktörün kim olduğu `actor_email` ile ayrıca DONDURULUR (hesap silinse de
-- "kim yaptı" okunabilsin).
CREATE TABLE admin_audit_log (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id    uuid        REFERENCES users (id) ON DELETE SET NULL,
  -- Silinen hesabın izini korumak için o anki e-posta kopyası (denormalize, bilerek).
  actor_email text        NOT NULL,
  -- Ne yapıldı: 'soundscape.create' | 'soundscape.publish' | ... (kod tarafında sabit).
  action      text        NOT NULL,
  -- Neye yapıldı: soundscape slug'ı gibi insan-okur kimlik.
  target      text        NOT NULL,
  -- Serbest bağlam (ör. eski/yeni durum). PII KONMAZ.
  details     jsonb       NOT NULL DEFAULT '{}',
  created_at  timestamptz NOT NULL DEFAULT now()
);

-- Pano "son etkinlik" akışı: en yeniden eskiye.
CREATE INDEX admin_audit_log_time_idx ON admin_audit_log (created_at DESC);
-- "Bu içeriğe kim ne yaptı?" sorgusu.
CREATE INDEX admin_audit_log_target_idx ON admin_audit_log (target, created_at DESC);

-- migrate:down

DROP TABLE IF EXISTS admin_audit_log;
