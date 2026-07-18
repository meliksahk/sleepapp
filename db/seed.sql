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

-- ============================================================================
-- SOUNDSCAPE'LER
-- ============================================================================
-- Bir soundscape ses DOSYASI DEĞİL, ses TARİFİDİR. Sunucu MP3 stream etmez;
-- `engine_params` bir reçetedir ve sesi telefon kendi üretir (docs/04 §78).
-- Tarif sözleşmesi (apps/api .../content/domain/engine-params.ts):
--   { "schemaVersion": 1, "layers": [ { "id": ..., "type": ..., "gain": ... } ] }
-- Motor ŞU AN yalnızca üç jeneratif kaynak tanıyor: white / pink / brown.
-- Bunun dışında bir "type" yazmak, tarifi okuma yolunda geçersiz kılar ve
-- soundscape istemciye HİÇ ulaşmaz (parseLayers → null → içerik elenir).
-- Kurallar: 1..8 katman, katman id'leri benzersiz, gain ∈ [0,1].
--
-- Katman sayısı ve gain dengesi tarifin karakteridir:
--   tek katman + yüksek gain  → düz, değişmeyen bir zemin
--   çok katman + düşük gain'ler → daha dokulu, katmanlı bir doku
-- Aşağıdaki altı tarif bilerek birbirinden ayrışır (1, 2, 2, 2, 3, 4 katman).
--
-- Sabit UUID'ler: haftalık yayın bu id'lere referans verdiği için seed'in her
-- çalışmasında aynı kalmalılar (idempotentlik ON CONFLICT (slug) ile sağlanır).
--
-- NOT (şema): `layer_defs` NOT NULL ama okuma yolunda hiçbir kod onu kullanmıyor
-- (bkz. engine-params.ts'teki D-9 notu) → '[]'::jsonb yazıyoruz.
-- `preview_asset_key` NULL: önizleme MinIO nesnesi yok, ses zaten cihazda üretiliyor.
-- `created_by` NULL: admin hesabı ayrı script ile kuruluyor, seed ona bağımlı olmamalı.

INSERT INTO soundscapes (
  id, slug, title_i18n, engine_params, layer_defs,
  archetype_affinity, status, publish_at, preview_asset_key, created_by
)
VALUES
  -- Deep Ocean Hush — "Deep Ocean" için: derin, kalın, neredeyse hareketsiz bir zemin.
  -- Brown gürültü baskın (düşük frekans ağırlıklı); üstüne çok kısık bir pink katman
  -- tarifin tamamen boğuk kalmamasını sağlıyor.
  (
    'a0000000-0000-4000-8000-000000000001',
    'deep-ocean-hush',
    '{"en": "Deep Ocean Hush", "tr": "Derin Okyanus Sessizliği"}'::jsonb,
    '{"schemaVersion": 1, "layers": [
        {"id": "swell",     "type": "brown", "gain": 0.75},
        {"id": "surface",   "type": "pink",  "gain": 0.18}
     ]}'::jsonb,
    '[]'::jsonb,
    '{deep-ocean}',
    'published', now(), NULL, NULL
  ),

  -- Rainfall Window — "3AM Overthinker" için: zihindeki gevezeliği örtecek kadar
  -- dokulu bir doku. Üç katman; pink gövde, white "damla" parlaklığı, brown gövde.
  -- Maskeleme burada asıl amaç, o yüzden en kalabalık ikinci tarif.
  (
    'a0000000-0000-4000-8000-000000000002',
    'rainfall-window',
    '{"en": "Rainfall Window", "tr": "Yağmurlu Pencere"}'::jsonb,
    '{"schemaVersion": 1, "layers": [
        {"id": "canopy",   "type": "pink",  "gain": 0.55},
        {"id": "droplets", "type": "white", "gain": 0.28},
        {"id": "gutter",   "type": "brown", "gain": 0.12}
     ]}'::jsonb,
    '[]'::jsonb,
    '{overthinker,delta-drifter}',
    'published', now(), NULL, NULL
  ),

  -- Delta Drift — "Delta Drifter" için: tek katman, hiç olay yok. Uzun gecede
  -- dikkat çeken hiçbir değişiklik olmasın diye bilerek en sade tarif.
  (
    'a0000000-0000-4000-8000-000000000003',
    'delta-drift',
    '{"en": "Delta Drift", "tr": "Delta Sürüklenişi"}'::jsonb,
    '{"schemaVersion": 1, "layers": [
        {"id": "drift", "type": "brown", "gain": 0.62}
     ]}'::jsonb,
    '[]'::jsonb,
    '{delta-drifter}',
    'published', now(), NULL, NULL
  ),

  -- First Light — "Dawn Chaser" için: akşam yatışma ritüeli. Toplam kazanç bilerek
  -- düşük; erken kalkan biri için zemin ince olmalı, ağır bir duvar değil.
  (
    'a0000000-0000-4000-8000-000000000004',
    'first-light',
    '{"en": "First Light", "tr": "İlk Işık"}'::jsonb,
    '{"schemaVersion": 1, "layers": [
        {"id": "haze",   "type": "pink",  "gain": 0.40},
        {"id": "breeze", "type": "white", "gain": 0.15}
     ]}'::jsonb,
    '[]'::jsonb,
    '{dawn-chaser}',
    'published', now(), NULL, NULL
  ),

  -- Night Train — en katmanlı tarif (4). Hem "Delta Drifter"ın uzun gecesine hem
  -- "Overthinker"ın maskeleme ihtiyacına hitap ediyor: kalın brown gövde + iki
  -- kısık pink + çok kısık white. Katman sayısının tarifi nasıl değiştirdiğini
  -- göstermek için lokal referans örnek budur.
  (
    'a0000000-0000-4000-8000-000000000005',
    'night-train',
    '{"en": "Night Train", "tr": "Gece Treni"}'::jsonb,
    '{"schemaVersion": 1, "layers": [
        {"id": "rail-rumble",  "type": "brown", "gain": 0.66},
        {"id": "carriage-hum", "type": "pink",  "gain": 0.30},
        {"id": "track-hiss",   "type": "white", "gain": 0.14},
        {"id": "distant-wind", "type": "pink",  "gain": 0.09}
     ]}'::jsonb,
    '[]'::jsonb,
    '{delta-drifter,overthinker}',
    'published', now(), NULL, NULL
  ),

  -- Cabin Fan — white baskın tek gerçek tarif. Yukarıdakilerin hepsi brown/pink
  -- ağırlıklıydı; bu, spektrumun diğer ucunu lokalde görünür kılıyor.
  (
    'a0000000-0000-4000-8000-000000000006',
    'cabin-fan',
    '{"en": "Cabin Fan", "tr": "Oda Vantilatörü"}'::jsonb,
    '{"schemaVersion": 1, "layers": [
        {"id": "blade-wash", "type": "white", "gain": 0.58},
        {"id": "motor-body", "type": "brown", "gain": 0.22}
     ]}'::jsonb,
    '[]'::jsonb,
    '{overthinker,deep-ocean}',
    'published', now(), NULL, NULL
  ),
  -- ==========================================================================
  -- Hearth & Static — TAM DEMO: müzik + gürültü + efekt bir arada.
  --
  -- NEDEN BU KAYIT VAR: yukarıdaki altı tarif #210'da yazıldı, meditatif
  -- kaynaklar (#213) HENÜZ YOKKEN. Sonuç: motor pad/fire/rain/waves biliyor
  -- ama HİÇBİR tarif onları kullanmıyordu; kullanıcı mikseri açınca yalnızca
  -- gürültü görüyordu ve ürün "yarım yamalak" hissettiriyordu. Bu kayıt
  -- kombinasyonun çalıştığını GÖSTEREN referans tariftir.
  --
  -- Katmanlar (üçü üç farklı sınıftan):
  --   pad   = melodik/tonal gövde ("müzik") — 30 sn döngüye faz-kilitli
  --   white = maskeleyici gürültü yatağı
  --   fire  = çıtırtı transient'leri (efekt)
  -- Toplam kazanç 0.34+0.30+0.26 = 0.90 < 1.0 → kırpma payı korunuyor.
  (
    'a0000000-0000-4000-8000-000000000007',
    'hearth-and-static',
    '{"en": "Hearth & Static", "tr": "Ocak ve Parazit"}'::jsonb,
    '{"schemaVersion": 1, "layers": [
        {"id": "music",  "type": "pad",   "gain": 0.34},
        {"id": "static", "type": "white", "gain": 0.30},
        {"id": "hearth", "type": "fire",  "gain": 0.26}
     ]}'::jsonb,
    '[]'::jsonb,
    '{overthinker,delta-drifter}',
    'published', now(), NULL, NULL
  )
ON CONFLICT (slug) DO NOTHING;

-- ============================================================================
-- PRESET'LER — archetype başına mikser başlangıç noktası
-- ============================================================================
-- Preset, aynı tarifin farklı bir dengeyle açılmasıdır: kullanıcı "Night Train"i
-- açtığında Overthinker ise maskeleyen katmanlar daha yüksek, Delta Drifter ise
-- gövde daha yüksek başlar. Şema mixer_state = {layers:[...]}, engine_params ile
-- aynı katman sözleşmesi (mixer-state.ts).
-- presets'te UNIQUE kısıt YOK → idempotentlik WHERE NOT EXISTS ile sağlanıyor.

INSERT INTO presets (soundscape_id, archetype_slug, mixer_state)
SELECT v.soundscape_id, v.archetype_slug, v.mixer_state
FROM (
  VALUES
    ('a0000000-0000-4000-8000-000000000005'::uuid, 'overthinker',
     '{"layers": [
        {"id": "rail-rumble",  "type": "brown", "gain": 0.45},
        {"id": "carriage-hum", "type": "pink",  "gain": 0.45},
        {"id": "track-hiss",   "type": "white", "gain": 0.30},
        {"id": "distant-wind", "type": "pink",  "gain": 0.12}
      ]}'::jsonb),
    ('a0000000-0000-4000-8000-000000000005'::uuid, 'delta-drifter',
     '{"layers": [
        {"id": "rail-rumble",  "type": "brown", "gain": 0.78},
        {"id": "carriage-hum", "type": "pink",  "gain": 0.20},
        {"id": "track-hiss",   "type": "white", "gain": 0.06},
        {"id": "distant-wind", "type": "pink",  "gain": 0.05}
      ]}'::jsonb),
    ('a0000000-0000-4000-8000-000000000002'::uuid, 'overthinker',
     '{"layers": [
        {"id": "canopy",   "type": "pink",  "gain": 0.50},
        {"id": "droplets", "type": "white", "gain": 0.40},
        {"id": "gutter",   "type": "brown", "gain": 0.10}
      ]}'::jsonb),
    ('a0000000-0000-4000-8000-000000000001'::uuid, 'deep-ocean',
     '{"layers": [
        {"id": "swell",   "type": "brown", "gain": 0.85},
        {"id": "surface", "type": "pink",  "gain": 0.10}
      ]}'::jsonb),
    ('a0000000-0000-4000-8000-000000000004'::uuid, 'dawn-chaser',
     '{"layers": [
        {"id": "haze",   "type": "pink",  "gain": 0.34},
        {"id": "breeze", "type": "white", "gain": 0.20}
      ]}'::jsonb)
) AS v (soundscape_id, archetype_slug, mixer_state)
WHERE NOT EXISTS (
  SELECT 1 FROM presets p
  WHERE p.soundscape_id = v.soundscape_id
    AND p.archetype_slug = v.archetype_slug
);

-- ============================================================================
-- HAFTALIK YAYIN
-- ============================================================================
-- /v1/content/weekly, yayın YOKSA 404 döner (content.controller.ts). Lokalde o
-- ekranın boş kalmaması için içinde bulunulan haftaya bir yayın koyuyoruz.
-- week_start'ı sabit yazmak yerine date_trunc kullanıyoruz: seed haftalar sonra
-- çalıştırıldığında da "bu hafta" kalsın, elle güncelleme gerekmesin.
-- (Postgres'te date_trunc('week', ...) haftayı PAZARTESİ'den başlatır.)
-- API en büyük week_start'ı seçer ve dizideki id'lerden yalnızca 'published'
-- olanları döndürür.

INSERT INTO weekly_releases (week_start, soundscape_ids, notes)
VALUES (
  date_trunc('week', now())::date,
  ARRAY[
    'a0000000-0000-4000-8000-000000000005'::uuid,  -- Night Train
    'a0000000-0000-4000-8000-000000000002'::uuid,  -- Rainfall Window
    'a0000000-0000-4000-8000-000000000004'::uuid   -- First Light
  ],
  'Lokal geliştirme yayını: katmanlı, maskeleyen ve ince — üç farklı tarif karakteri.'
)
ON CONFLICT (week_start) DO NOTHING;
