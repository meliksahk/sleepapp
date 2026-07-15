-- migrate:up

-- Soundscape örnek/önizleme sesi için MinIO nesne anahtarı (opsiyonel). Dosya
-- 'soundscape-assets' bucket'ında; API presigned URL üretir, dosyayı proxy'lemez.
ALTER TABLE soundscapes ADD COLUMN preview_asset_key text;

-- migrate:down

ALTER TABLE soundscapes DROP COLUMN IF EXISTS preview_asset_key;
