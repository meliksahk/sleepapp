-- migrate:up

-- account_deletions — hesap silme SAYACI. Satır başına TEK bilgi: ne zaman.
--
-- NEDEN AYRI TABLO: `users.deleteById` HARD delete (FK ON DELETE CASCADE); satır
-- gidince sayılacak hiçbir şey kalmıyor. Panel "kaskad gerçekten çalışıyor mu"
-- sorusuna bakabilmeli — ama bunun için kullanıcıyı SAKLAMAK gerekmiyor.
--
-- ⚠️ KULLANICI KİMLİĞİ BİLEREK YOK. user_id tutsaydık:
--   (a) silinen kullanıcının izi kalırdı — "sil" dediğinde silinmiş olmaz (KVKK/GDPR),
--   (b) FK cascade bu satırı da silerdi, yani sayaç hep 0 dönerdi.
-- Bu tablo bir OLAY sayacıdır, bir kayıt defteri değil.
CREATE TABLE account_deletions (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deleted_at timestamptz NOT NULL DEFAULT now()
);

-- Panel "son 30 gün" sorar; tarama değil aralık taraması olsun.
CREATE INDEX account_deletions_deleted_at_idx ON account_deletions (deleted_at DESC);

-- migrate:down

DROP TABLE account_deletions;
