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
-- Motor kaynakları: white / pink / brown / waves / fire / rain / pad / tone.
-- (tone ek katman alanı taşır: "frequencyHz" — mixer-state.ts sözleşmesi.)
-- Tanınmayan bir "type" veya ton'da eksik frekans, tarifi okuma yolunda geçersiz
-- kılar ve soundscape istemciye HİÇ ulaşmaz (parseLayers → null → içerik elenir).
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
  ),

  -- ==========================================================================
  -- Deep Hum — TONE kaynağının referans tarifi.
  --
  -- NEDEN BU KAYIT VAR (#215 dersi): motora yeni bir kaynak eklemek YETMEZ —
  -- onu kullanan İÇERİK yoksa kullanıcı mikserde/kütüphanede onu HİÇ görmez
  -- ve yetenek görünmez kalır. Bu kayıt tone'un çalıştığını GÖSTEREN tariftir.
  --
  -- tone = A2 (110 Hz) saf sinüs, döngü ızgarasına kilitli (30 sn'de tam
  -- 3300 periyot → dikiş yok). Frekans seçimi MÜZİKALDİR: org pedal noktası
  -- bölgesi; sağlık iddiası YOKTUR (CLAUDE.md §1.1). Brown gövde altına
  -- gömülmüş ton "derin uğultu" hissi verir.
  -- Toplam kazanç 0.55+0.18+0.12 = 0.85 < 1.0 → kırpma payı korunuyor.
  (
    'a0000000-0000-4000-8000-000000000008',
    'deep-hum',
    '{"en": "Deep Hum", "tr": "Derin Uğultu"}'::jsonb,
    '{"schemaVersion": 1, "layers": [
        {"id": "body", "type": "brown", "gain": 0.55},
        {"id": "hum",  "type": "tone",  "gain": 0.18, "frequencyHz": 110},
        {"id": "air",  "type": "pink",  "gain": 0.12}
     ]}'::jsonb,
    '[]'::jsonb,
    '{deep-ocean,delta-drifter}',
    'published', now(), NULL, NULL
  ),

  -- Soft Beat — BINAURAL vuru içeren referans tarif.
  --
  -- `beatHz` SÖZLEŞME ÜYESİDİR (mixer-state.ts + mobil engine_params aynı
  -- kurallar: yalnızca tone'da, 0.5–20 Hz, yokluk=mono). API bu tarifi olduğu
  -- gibi taşır; telefon katmanı STEREO çalar (L=200 Hz, R=208 Hz → kulakta
  -- ~8 Hz vuru). Vuru seçimi algısaldır; EEG adı/iddiası YOKTUR (§1.1).
  (
    'a0000000-0000-4000-8000-000000000009',
    'soft-beat',
    '{"en": "Soft Beat", "tr": "Yumuşak Vuru"}'::jsonb,
    '{"schemaVersion": 1, "layers": [
        {"id": "bed",  "type": "brown", "gain": 0.45},
        {"id": "beat", "type": "tone",  "gain": 0.18, "frequencyHz": 200, "beatHz": 8},
        {"id": "air",  "type": "pink",  "gain": 0.10}
     ]}'::jsonb,
    '[]'::jsonb,
    '{overthinker,dawn-chaser}',
    'published', now(), NULL, NULL
  ),

  -- Cathedral Hum — pad + tone: org nefesi gibi, mekânsal derinlik.
  -- Pad melodik gövde sağlar; A2 tonu alt oktavda temel verir. Pink hava.
  (
    'a0000000-0000-4000-8000-00000000000a',
    'cathedral-hum',
    '{"en": "Cathedral Hum", "tr": "Katedral Uğultusu"}'::jsonb,
    '{"schemaVersion": 1, "layers": [
        {"id": "organ", "type": "pad",   "gain": 0.30},
        {"id": "root",  "type": "tone",  "gain": 0.16, "frequencyHz": 110},
        {"id": "air",   "type": "pink",  "gain": 0.10}
     ]}'::jsonb,
    '[]'::jsonb,
    '{deep-ocean,dawn-chaser}',
    'published', now(), NULL, NULL
  ),

  -- Rain Chapel — yağmur + düşük ton: dışarıda yağmur, içeride sıcaklık.
  -- Brown zemin, E2 tonu sıcak bir temel; white damla dokusunu unutturmaz.
  (
    'a0000000-0000-4000-8000-00000000000b',
    'rain-chapel',
    '{"en": "Rain Chapel", "tr": "Yağmur Şapeli"}'::jsonb,
    '{"schemaVersion": 1, "layers": [
        {"id": "shower", "type": "rain", "gain": 0.40},
        {"id": "warm",   "type": "tone", "gain": 0.14, "frequencyHz": 82.4},
        {"id": "ground", "type": "brown","gain": 0.28}
     ]}'::jsonb,
    '[]'::jsonb,
    '{overthinker,delta-drifter}',
    'published', now(), NULL, NULL
  ),

  -- Night Bell — ateş + pad + G2 tonu: gece kampı hissi.
  -- Fire çıtırtısı canlılık verir; pad atmosferik zarf; G2 tonu temel.
  (
    'a0000000-0000-4000-8000-00000000000c',
    'night-bell',
    '{"en": "Night Bell", "tr": "Gece Çanı"}'::jsonb,
    '{"schemaVersion": 1, "layers": [
        {"id": "ember",  "type": "fire", "gain": 0.22},
        {"id": "veil",   "type": "pad",  "gain": 0.24},
        {"id": "bell",   "type": "tone", "gain": 0.14, "frequencyHz": 98},
        {"id": "carpet", "type": "pink", "gain": 0.12}
     ]}'::jsonb,
    '[]'::jsonb,
    '{dawn-chaser,delta-drifter}',
    'published', now(), NULL, NULL
  ),

  -- Midnight Garden — akor + arpej: melodik uyku müziğinin tam örneği.
  -- Chords yavaş harmonik zemin; arpeggi pentatonik gezinti; brown maske.
  (
    'a0000000-0000-4000-8000-00000000000d',
    'midnight-garden',
    '{"en": "Midnight Garden", "tr": "Gece Bahçesi"}'::jsonb,
    '{"schemaVersion": 1, "layers": [
        {"id": "harmony",  "type": "chords",   "gain": 0.22},
        {"id": "melody",   "type": "arpeggio", "gain": 0.14},
        {"id": "blanket",  "type": "brown",    "gain": 0.24}
     ]}'::jsonb,
    '[]'::jsonb,
    '{dawn-chaser,deep-ocean}',
    'published', now(), NULL, NULL
  ),

  -- Ocean Dream — dalga + akor + ton: okyanus üzerinde melodi.
  -- Waves kabarma hissi verir; chords sıcak harmoni; C3 tonu derin temel.
  (
    'a0000000-0000-4000-8000-00000000000e',
    'ocean-dream',
    '{"en": "Ocean Dream", "tr": "Okyanus Rüyası"}'::jsonb,
    '{"schemaVersion": 1, "layers": [
        {"id": "surf",     "type": "waves", "gain": 0.28},
        {"id": "dream",    "type": "chords","gain": 0.20},
        {"id": "deep",     "type": "tone",  "gain": 0.12, "frequencyHz": 130.8}
     ]}'::jsonb,
    '[]'::jsonb,
    '{deep-ocean,delta-drifter}',
    'published', now(), NULL, NULL
  ),

  -- Ceramic Drift — seramik top yuvarlanması: modal rezonans, sürtünme pırıltıları.
  -- Noise'dan tamamen ayrı kategori (relaxing); brown yatağı YOK — saf malzeme sesi.
  (
    'a0000000-0000-4000-8000-00000000000f',
    'ceramic-drift',
    '{"en": "Ceramic Drift", "tr": "Seramik Sürükleniş"}'::jsonb,
    '{"schemaVersion": 1, "layers": [
        {"id": "ceramic", "type": "ceramic", "gain": 0.52},
        {"id": "air",     "type": "pink",    "gain": 0.10}
     ]}'::jsonb,
    '[]'::jsonb,
    '{deep-ocean,delta-drifter}',
    'published', now(), NULL, NULL
  ),

  -- Chime Haven — bambu/metal rüzgar çanı: inharmonik sönümlü vuruşlar, seyrek rüzgâr.
  (
    'a0000000-0000-4000-8000-000000000010',
    'chime-haven',
    '{"en": "Chime Haven", "tr": "Çan Sığınağı"}'::jsonb,
    '{"schemaVersion": 1, "layers": [
        {"id": "chimes", "type": "chimes", "gain": 0.50},
        {"id": "veil",   "type": "pad",    "gain": 0.18}
     ]}'::jsonb,
    '[]'::jsonb,
    '{dawn-chaser,delta-drifter}',
    'published', now(), NULL, NULL
  ),

  -- Ritual: Top & Friction — 10dk ritüel preset’i (amaç cümlesinin sesi).
  -- Topaç vızıltısı (odak) + seramik sürtme (ritmik) + seramik kase (tok temel) + pembe hava.
  -- Yeni malzeme kaynaklarını tek tarife koyan, 10dk fade ile telefonu bırakma ritüelinin
  -- hazır sesi. Toplam 0.96 <1. Kategori relaxing (malzeme).
  (
    'a0000000-0000-4000-8000-000000000011',
    'ritual-top-friction',
    '{"en": "Ritual: Top & Friction", "tr": "Ritüel: Topaç ve Sürtme"}'::jsonb,
    '{"schemaVersion": 1, "layers": [
        {"id": "top",      "type": "topSpin",  "gain": 0.34},
        {"id": "friction", "type": "friction", "gain": 0.32},
        {"id": "ceramic",  "type": "ceramic",  "gain": 0.22},
        {"id": "air",      "type": "pink",     "gain": 0.08}
     ]}'::jsonb,
    '[]'::jsonb,
    '{deep-ocean,delta-drifter,overthinker}',
    'published', now(), NULL, NULL
  ),

  -- Top Spin Solo — saf topaç, tek katman. Fan’cı için değil, odak arayan için.
  (
    'a0000000-0000-4000-8000-000000000012',
    'top-spin-solo',
    '{"en": "Top Spin Solo", "tr": "Topaç Solo"}'::jsonb,
    '{"schemaVersion": 1, "layers": [
        {"id": "top", "type": "topSpin", "gain": 0.58}
     ]}'::jsonb,
    '[]'::jsonb,
    '{deep-ocean,delta-drifter}',
    'published', now(), NULL, NULL
  ),

  -- Friction Solo — iki seramik topun yavaş sürtmesi, tek katman.
  (
    'a0000000-0000-4000-8000-000000000013',
    'friction-solo',
    '{"en": "Friction Solo", "tr": "Sürtme Solo"}'::jsonb,
    '{"schemaVersion": 1, "layers": [
        {"id": "rub", "type": "friction", "gain": 0.60}
     ]}'::jsonb,
    '[]'::jsonb,
    '{deep-ocean,overthinker}',
    'published', now(), NULL, NULL
  ),

  -- Ceramic & Friction — seramik kase + sürtme, çift malzeme, çok dokulu.
  (
    'a0000000-0000-4000-8000-000000000014',
    'ceramic-friction-duo',
    '{"en": "Ceramic & Friction", "tr": "Seramik ve Sürtme"}'::jsonb,
    '{"schemaVersion": 1, "layers": [
        {"id": "bowl", "type": "ceramic",  "gain": 0.42},
        {"id": "rub",  "type": "friction", "gain": 0.38}
     ]}'::jsonb,
    '[]'::jsonb,
    '{deep-ocean,dawn-chaser}',
    'published', now(), NULL, NULL
  ),

  -- Wind Chime Night — rüzgar çanı + yağmur, gece bahçesi hissi.
  (
    'a0000000-0000-4000-8000-000000000015',
    'wind-chime-night',
    '{"en": "Wind Chime Night", "tr": "Rüzgar Çanlı Gece"}'::jsonb,
    '{"schemaVersion": 1, "layers": [
        {"id": "chimes", "type": "chimes", "gain": 0.40},
        {"id": "rain",   "type": "rain",   "gain": 0.35},
        {"id": "pad",    "type": "pad",    "gain": 0.14}
     ]}'::jsonb,
    '[]'::jsonb,
    '{dawn-chaser,deep-ocean}',
    'published', now(), NULL, NULL
  ),

  -- Low Hum Top — topaç üstüne 82Hz ton, derin temel.
  (
    'a0000000-0000-4000-8000-000000000016',
    'low-hum-top',
    '{"en": "Low Hum Top", "tr": "Alçak Uğultu ve Topaç"}'::jsonb,
    '{"schemaVersion": 1, "layers": [
        {"id": "hum", "type": "tone",    "gain": 0.18, "frequencyHz": 82.4},
        {"id": "top", "type": "topSpin", "gain": 0.42},
        {"id": "air", "type": "pink",    "gain": 0.12}
     ]}'::jsonb,
    '[]'::jsonb,
    '{delta-drifter,deep-ocean}',
    'published', now(), NULL, NULL
  ),

  -- Pink Ceramic Mist — pembe sis + seramik, yumuşak malzeme.
  (
    'a0000000-0000-4000-8000-000000000017',
    'pink-ceramic-mist',
    '{"en": "Pink Ceramic Mist", "tr": "Pembe Seramik Sisi"}'::jsonb,
    '{"schemaVersion": 1, "layers": [
        {"id": "pink",    "type": "pink",    "gain": 0.45},
        {"id": "ceramic", "type": "ceramic", "gain": 0.38}
     ]}'::jsonb,
    '[]'::jsonb,
    '{overthinker,dawn-chaser}',
    'published', now(), NULL, NULL
  ),

  -- Brown Friction Ground — kahverengi zemin + sürtme, maskeleyici + dokulu.
  (
    'a0000000-0000-4000-8000-000000000018',
    'brown-friction-ground',
    '{"en": "Brown Friction Ground", "tr": "Kahverengi Sürtme Zemini"}'::jsonb,
    '{"schemaVersion": 1, "layers": [
        {"id": "ground", "type": "brown",    "gain": 0.48},
        {"id": "rub",    "type": "friction", "gain": 0.36}
     ]}'::jsonb,
    '[]'::jsonb,
    '{overthinker,deep-ocean}',
    'published', now(), NULL, NULL
  ),

  -- Arpeggio Garden Top — arpej + topaç, melodik + odak.
  (
    'a0000000-0000-4000-8000-000000000019',
    'arpeggio-garden-top',
    '{"en": "Arpeggio Garden Top", "tr": "Arpej Bahçesi ve Topaç"}'::jsonb,
    '{"schemaVersion": 1, "layers": [
        {"id": "garden", "type": "arpeggio", "gain": 0.28},
        {"id": "top",    "type": "topSpin",  "gain": 0.32},
        {"id": "blanket","type": "brown",    "gain": 0.22}
     ]}'::jsonb,
    '[]'::jsonb,
    '{dawn-chaser,deep-ocean}',
    'published', now(), NULL, NULL
  )
ON CONFLICT (slug) DO NOTHING;

UPDATE soundscapes SET category = 'relaxing' WHERE slug IN ('ceramic-drift','chime-haven','ritual-top-friction','top-spin-solo','friction-solo','ceramic-friction-duo','pink-ceramic-mist') AND category <> 'relaxing';
UPDATE soundscapes SET category = 'nature' WHERE slug IN ('wind-chime-night') AND category <> 'nature';

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
    'a0000000-0000-4000-8000-000000000011'::uuid,  -- Ritual: Top & Friction (yeni amaç)
    'a0000000-0000-4000-8000-000000000005'::uuid,  -- Night Train
    'a0000000-0000-4000-8000-000000000002'::uuid,  -- Rainfall Window
    'a0000000-0000-4000-8000-000000000004'::uuid   -- First Light
  ],
  'Lokal geliştirme yayını: 10dk ritüel + katmanlı, maskeleyen ve ince.'
)
ON CONFLICT (week_start) DO NOTHING;
