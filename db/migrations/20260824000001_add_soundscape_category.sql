-- migrate:up
-- Kategori: gürültü / doğa / rahatlatıcı — hazır seslerin ayrı kulvarlarda listelenmesi için.
-- Noise-benzeri doğa sentezleri (rain/waves/fire) kategorik olarak "doğa"da kalır;
-- saf modal sentezler (ceramic/chimes) "rahatlatıcı"da. Gürültüler saf noise katmanlarıdır.
ALTER TABLE soundscapes ADD COLUMN category text NOT NULL DEFAULT 'nature'
  CONSTRAINT soundscapes_category_allowed CHECK (category IN ('noise','nature','relaxing'));

-- Mevcut 12 kayıt backfill: baskın katman tipine göre.
UPDATE soundscapes SET category = 'noise' WHERE slug IN ('delta-drift','cabin-fan');
UPDATE soundscapes SET category = 'relaxing' WHERE slug IN ('deep-hum','soft-beat','cathedral-hum','rain-chapel','night-bell','midnight-garden','ocean-dream');
-- kalanlar (deep-ocean-hush, rainfall-window, first-light, night-train, hearth-and-static) DEFAULT 'nature' olarak kalır.

CREATE INDEX idx_soundscapes_category ON soundscapes (category);

-- migrate:down
DROP INDEX IF EXISTS idx_soundscapes_category;
ALTER TABLE soundscapes DROP COLUMN IF EXISTS category;
