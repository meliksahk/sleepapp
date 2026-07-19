-- migrate:up

-- audio_assets — SENTEZ OLMAYAN ses kaynakları (kullanıcının/bizim koyduğumuz dosyalar).
--
-- NEDEN AYRI TABLO (soundscapes'e kolon eklemek DEĞİL): soundscape bir TARİFTİR
-- (engine_params → on-device sentez), audio_asset ise bir DOSYADIR. İkisi farklı
-- yaşam döngüsüne sahip: tarif sürümlenir ve motorla birlikte değişir, dosya
-- değişmez (değişirse yeni dosyadır). Aynı dosya birden çok tarifte kullanılabilir.
--
-- ⚠️ `key` URL DEĞİL, DEPOLAMA ANAHTARIDIR (ör. 'demo/pad-fire-demo.wav').
-- Bilinçli: bugün MinIO (:9000), yarın gerçek S3 veya CDN olabilir. URL saklasaydık
-- backend taşındığında tablodaki HER SATIR bozulurdu. URL, istek anında presigned
-- olarak üretilir (s3-asset.signer.ts) — soundscapes.preview_asset_key ile aynı desen.
CREATE TABLE audio_assets (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Depolama anahtarı = idempotency anahtarı. Yükleme script'i ON CONFLICT (key)
  -- ile çalışır: aynı dosya iki kez yüklenince kopya satır oluşmaz, meta güncellenir.
  key              text        NOT NULL UNIQUE,

  title            text        NOT NULL,

  -- Tek değer: bir dosya bir türdedir ('ambient', 'rain', 'piano'...).
  genre            text        NOT NULL,

  -- ÇOK DEĞERLİ: bir ses aynı anda hem 'calm' hem 'focus' olabilir.
  --
  -- text[] SEÇİLDİ, jsonb DEĞİL — gerekçe:
  --  1. Repo deseni: soundscapes.archetype_affinity zaten text[] (aynı şekil,
  --     aynı sorgu: `mood && ARRAY['calm']` örtüşme filtresi).
  --  2. İhtiyaç DÜZ bir dizgi listesi; jsonb'nin sunduğu iç içe yapı/nesne
  --     yeteneğine ihtiyacımız yok ve olsaydı şemasız bir alan olurdu.
  --  3. GIN indeksi ile örtüşme sorgusu doğrudan desteklenir (aşağıda).
  -- jsonb'ye geçiş gerekirse (ör. mood başına ağırlık) ayrı bir migration işidir.
  mood             text[]      NOT NULL DEFAULT '{}',

  duration_seconds integer     NOT NULL DEFAULT 0,

  -- LİSANS ZORUNLU (CLAUDE.md §6 / mağaza uyumu). Hangi dosyanın hangi hakla
  -- burada olduğunu BİLMİYORSAK mağazaya çıkarken kanıtlayamayız ve tek bir
  -- telifli dosya tüm uygulamayı riske atar. Bu yüzden kural veritabanı
  -- seviyesinde: NOT NULL YETMEZ (boş dizgi de NOT NULL'dır), CHECK ile
  -- boş/whitespace de reddedilir. Uygulama katmanı atlanabilir, DB atlanamaz.
  license          text        NOT NULL,
  -- Nereden geldi: URL, "kendi ürettiğimiz", kişi adı, satın alma no...
  source           text        NOT NULL,

  -- İçerik parmak izi (sha256 hex). Idempotency İÇİN ŞART DEĞİL (o `key` ile
  -- sağlanır) ama yükleme script'i "aynı ad, DEĞİŞMİŞ içerik" durumunu ancak
  -- bununla görebilir → gereksiz yeniden yüklemeyi atlar, gerçek değişikliği yapar.
  checksum         text,
  byte_size        bigint,
  content_type     text,

  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT audio_assets_key_not_blank     CHECK (btrim(key) <> ''),
  CONSTRAINT audio_assets_title_not_blank   CHECK (btrim(title) <> ''),
  CONSTRAINT audio_assets_genre_not_blank   CHECK (btrim(genre) <> ''),
  CONSTRAINT audio_assets_license_not_blank CHECK (btrim(license) <> ''),
  CONSTRAINT audio_assets_source_not_blank  CHECK (btrim(source) <> ''),
  CONSTRAINT audio_assets_duration_positive CHECK (duration_seconds >= 0)
);

CREATE INDEX idx_audio_assets_genre ON audio_assets (genre);
-- GIN: `mood && ARRAY['calm','focus']` örtüşme filtresi için (liste ucu).
CREATE INDEX idx_audio_assets_mood ON audio_assets USING gin (mood);

-- migrate:down

DROP TABLE IF EXISTS audio_assets;
