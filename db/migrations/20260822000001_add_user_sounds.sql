-- migrate:up

-- user_sounds — TOPLULUK SESLERİ: kullanıcıların kendi yüklediği dosyalar.
--
-- NEDEN AYRI TABLO (audio_assets'e kolon eklemek DEĞİL): iki tablonun yaşam
-- döngüsü farklıdır. `audio_assets` KATALOGTUR (sahibi yok, herkes aynı listeyi
-- görür, lisans zorunludur). `user_sounds` SAHİPLİDİR: satırın bir kullanıcısı
-- vardır, moderasyon durum makinesinden geçer ve ONAYLANMADAN katalogda
-- görünmez. Onaylanmış satırlar katalog okumasında BİRLEŞİR
-- (PrismaAudioAssetRepository.list) — ama verinin TEK kaynağı burası kalır;
-- onayı "audio_assets'e kopyalamak" iki doğruluk kaynağı yaratirdi.
--
-- DURUM MAKİNESİ:
--   pending  → yükleme slotu açıldı / dosya bekleniyor veya moderasyonda
--   approved → moderatör onayladı → katalogda görünür
--   rejected → reddedildi (+ reason); tekrar pending'e ALINAMAZ — yeniden
--              paylaşım yeni bir yükleme olur (denetim izi temiz kalır)
--
-- `storage_key` biçimi: 'user/{userId}/{soundId}' — kullanıcının kimliği
-- anahtarın İÇİNDE olduğundan bucket policy ileride satır-başı izole edilebilir.
CREATE TABLE user_sounds (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  -- Kullanıcının VERDİĞİ başlık; serbest metin ama boş/whitespace yasak (DB
  -- seviyesinde: uygulama atlanabilir, CHECK atlanamaz).
  title       text        NOT NULL,

  storage_key text        NOT NULL UNIQUE,
  byte_size   bigint,
  duration_seconds integer NOT NULL DEFAULT 0 CHECK (duration_seconds >= 0),

  status      text        NOT NULL DEFAULT 'pending'
              CONSTRAINT user_sounds_status_allowed
              CHECK (status IN ('pending', 'approved', 'rejected')),

  rejection_reason text,
  moderated_at     timestamptz,

  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),

  -- Red kararı gerekçesiz olamaz: kullanıcıya SÖYLENEMEYEN bir red, sessiz
  -- sansürdür. approved/rejected geçişlerinde uygulama katmanı da zorlar.
  CONSTRAINT user_sounds_rejection_needs_reason
    CHECK (status <> 'rejected' OR btrim(rejection_reason) <> '')
);

CREATE INDEX idx_user_sounds_user   ON user_sounds (user_id, created_at DESC);
CREATE INDEX idx_user_sounds_status ON user_sounds (status, created_at DESC);

-- migrate:down

DROP TABLE IF EXISTS user_sounds;
