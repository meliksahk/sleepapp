# 02 — Backend Servis: Mimari ve Faz Planı

## 1. Mimari Karar

**Seçim:** İlk günden **tamamen self-hosted, tamamen bize ait** stack — Hostinger VPS üzerinde Docker ile: **NestJS modüler monolit + Postgres + MinIO (S3 uyumlu depolama) + Redis**. Auth dahil hiçbir katman üçüncü parti BaaS'a bağlı değildir.

**Gerekçe:**

- Sıfır ek sermaye: her şey eldeki VPS'te container — ek aylık maliyet ~0 $; vendor lock-in ve free-tier tuzağı yok; veri egemenliği tam bizde (KVKK açısından da en temiz konum).
- Tek kişi: NestJS = en geniş ekosistem, en kolay işe alım (ileride ekip), decorators ile OpenAPI otomatik.
- Ölçeklenebilirlik: hexagonal modüller → mikroservise kopartılabilir; Postgres → partitioning/replica yolu açık; MinIO → istenirse herhangi bir S3'e taşınır (aynı API).
- Reddedilenler: Supabase/Firebase (dış bağımlılık — kullanıcı kararı: her şey bize ait olacak), saf serverless (lokal geliştirme zorluğu + lock-in), Go (ekosistem/işe alım hızı; performans ihtiyacı bu iş yükünde yok — ağır iş cihazda).
- Dürüst bedel: auth'u kendimiz yazıyoruz — bu güvenlik sorumluluğunu da bize alır. Karşılığı aşağıda ayrı bölüm (§2.1) ve sıkı test zorunluluğudur; kripto asla elle yazılmaz, kanıtlanmış kütüphaneler (argon2, jose) kullanılır.

## 2. Modül Haritası ve Hexagonal İskelet

```
apps/api/src/
├── modules/
│   ├── identity/        # KENDİ auth'umuz: anonim cihaz kaydı, token'lar, hesap silme kaskadı
│   ├── profile/         # kullanıcı profili, tercihler, kronotip
│   ├── archetype/       # test soru matrisi, skorlama, sonuç ataması
│   ├── content/         # soundscape/preset/haftalık yayın metadata'sı
│   ├── sleep/           # uyku oturumu ingest (türetilmiş metrikler), gece raporu üretimi
│   ├── sharing/         # paylaşım kartı meta, derin link, /a/{slug} OG verisi
│   ├── billing/         # IAP doğrulama (EN SON faz — o güne dek EntitlementService stub)
│   ├── notification/    # push token kaydı, kampanya fan-out (BullMQ)
│   ├── flags/           # feature flag + remote config (basit tablo tabanlı)
│   ├── analytics-ingest/# istemci olaylarını PostHog'a proxy'leme/zenginleştirme (opsiyonel)
│   └── admin/           # panel BFF'i: RBAC, toplu işlemler, metrik sorguları
├── shared/
│   ├── kernel/          # Result tipi, domain event base, outbox, guard'lar
│   ├── infra/           # prisma, redis, minio (s3) client, mailer
│   └── config/          # tipli env (zod ile parse, eksikte boot fail)
└── main.ts
```

### 2.1 `identity` — kendi auth sistemimiz (kritik modül)

- **Akış:** uygulama ilk açılışta anonim kayıt olur (`POST /v1/auth/device` → cihaz başına user + token çifti) — onboarding sürtünmesiz başlar. Sonradan e-posta (magic link / şifre) ile hesaba yükseltme; Apple Sign-In dev hesapları bağlanınca eklenir (docs/10).
- **Token modeli:** kısa ömürlü access JWT (15 dk, RS256 — anahtar çifti bizde, JWKS endpoint'i API'de) + opak refresh token (DB'de hash'li, rotation + reuse-detection ile; çalıntı refresh tespitinde tüm oturumlar düşürülür).
- **Şifre/hash:** argon2id; e-posta doğrulama ve magic link token'ları tek kullanımlık + süreli.
- **Admin auth'u da burada:** davetli hesaplar, TOTP 2FA, ayrı audience claim'i (`aud: admin`) — mobil token'la panele girilemez.
- **Sınır:** JWT üretimi/doğrulaması ve her türlü kripto YALNIZCA bu modülde. Diğer modüller `AuthGuard`'dan gelen `userId/roles` context'ini kullanır.
- **Yetkilendirme modeli (RLS'in yerini alan şey):** her repository metodu `userId` scope'u zorunlu alır; scope'suz erişim yalnızca `admin` modülünün açıkça işaretli use case'lerinde. Her kişisel-veri endpoint'ine "A, B'nin verisine erişemez" integration testi zorunlu (CLAUDE.md §6).

Her modülün içi:

```
modules/sleep/
├── domain/          # SleepSession entity, NightReport VO, SleepRepository (port), event'ler
├── application/     # IngestSleepSessionUseCase, GenerateNightReportUseCase, query handler'lar
├── infrastructure/  # PrismaSleepRepository, ReportRendererAdapter
└── presentation/    # SleepController, DTO'lar (class-validator), mapper'lar
```

**Sınır kuralları (eslint-plugin-boundaries ile zorlanır):**

- `domain` → hiçbir şeyi import etmez (saf TS).
- `application` → yalnızca kendi `domain` + `shared/kernel`.
- Modüller arası: yalnızca hedef modülün `application` public API'si (`index.ts` barrel) veya domain event. Prisma modeline modül dışından erişim yasak.
- CQRS-lite: yazma = use case, okuma = ayrı query handler (karmaşık raporlarda raw SQL serbest — okuma tarafı domain'den geçmek zorunda değil).

## 3. Veri Modeli (çekirdek şema)

```sql
-- Kimlik (kendi auth'umuz)
users(id uuid PK, kind enum(anonymous/registered/admin), email UNIQUE NULL,
      email_verified_at, password_hash NULL,
      -- Admin 2FA (RFC 6238). Üçü BİRLİKTE anlamlı:
      --   totp_secret       : base32 anahtar (kurulumda üretilir)
      --   totp_confirmed_at : NULL iken 2FA ZORUNLU DEĞİL — kurulumu yarıda bırakan
      --                       kullanıcının kendini kalıcı kilitlemesini önler
      --   totp_last_counter : son kabul edilen adım; aynı kodun ikinci kez
      --                       kullanılmasını engeller (RFC 6238 §5.2 tekrar saldırısı)
      totp_secret NULL, totp_confirmed_at NULL, totp_last_counter NULL,
      roles text[], created_at, deleted_at)
auth_devices(id, user_id FK, device_fingerprint UNIQUE, platform, created_at)
refresh_tokens(id, user_id FK, token_hash UNIQUE, family_id,   -- rotation + reuse detection
               expires_at, revoked_at NULL, created_at)
one_time_tokens(id, user_id, purpose enum(magic_link/email_verify/password_reset),
                token_hash UNIQUE, expires_at, used_at NULL)

-- Profil
profiles(id uuid PK = users.id, display_name, chronotype, locale,
         timezone, created_at)
archetype_results(id, user_id FK, archetype_slug, answers jsonb,
                  scores jsonb, version int, created_at)

-- İçerik (admin CMS'in yazdığı, uygulamanın okuduğu)
soundscapes(id, slug UNIQUE, title_i18n jsonb, engine_params jsonb,  -- jeneratif motor parametreleri
            layer_defs jsonb, archetype_affinity text[], status enum(draft/scheduled/published),
            publish_at, created_by, version)
presets(id, soundscape_id FK, archetype_slug, mixer_state jsonb)
weekly_releases(id, week_start date UNIQUE, soundscape_ids uuid[], notes)

-- Kullanıcı üretimi
user_mixes(id, user_id, name, mixer_state jsonb, is_shared bool, share_slug UNIQUE NULL)

-- Uyku (yalnızca türetilmiş metrikler; ham ses ASLA gelmez)
sleep_sessions(id, user_id, started_at, ended_at, tz_offset_min,
               metrics jsonb,          -- {duration_min, noise_events, movement_events, ...}
               source enum(mic/manual))
night_reports(id, session_id FK UNIQUE, user_id, report jsonb, share_slug UNIQUE NULL, created_at)

-- Para & motor
entitlements(user_id PK, tier enum(free/plus/lifetime), source, current_period_end, store_payload jsonb)
billing_events(id, store_event_id UNIQUE, type, user_id, payload jsonb, processed_at)  -- idempotency (B5'te)

-- Platform
device_tokens(id, user_id, platform, token UNIQUE, last_seen_at)
feature_flags(key PK, description, rules jsonb, updated_by)
streaks(user_id PK, current int, longest int, last_activity_date date)
outbox(id, aggregate, event_type, payload jsonb, created_at, published_at NULL)
audit_log(id, actor_id, actor_role, action, target, diff jsonb, created_at)  -- admin işlemleri
```

- **Erişim modeli:** DB dış dünyaya kapalı (yalnızca Docker iç ağı); tek kapı API. Kullanıcı verisi repository-katmanı `userId` scoping'i ile korunur; içerik tabloları yalnızca `published` satırlarıyla public uçlardan servis edilir; admin işlemleri rol-guard'lı `admin` modülünden geçer ve audit'lenir.
- **Veri envanteri (KVKK/GDPR):** kişisel veri taşıyan tablolar: users, auth_devices, profiles, archetype_results, user_mixes, sleep_sessions, night_reports, device_tokens, entitlements. Hesap silme: `identity` modülünde tek use case, kaskad + MinIO nesne temizliği. Mikrofon ham verisi hiçbir zaman cihaz dışına çıkmaz.
- **Migration disiplini:** yalnızca `db/migrations` (SQL-first, dbmate) — Prisma `db push`/`migrate` yasak; şema senkronu `prisma db pull` ile. Her migration geri alma (down) bloğu içerir; staging'de koşmadan prod'a gidemez.
- **Depolama:** MinIO bucket'ları: `soundscape-assets` (public-read, immutable, uzun cache — Caddy üzerinden servis), `share-cards` (public-read), `backups` (private). Dosya erişimi presigned URL ile; API dosya proxy'lemez.
- **Depolama bütçesi (96 GB VPS):** ses varlıkları Opus/AAC sıkıştırmalı yüklenir (60 sn loop ≈ 0.7–1.5 MB; WAV/AIFF bucket'a giremez — CI kontrolü); kullanıcı videoları ve ham mikrofon sesi SUNUCUYA HİÇ GELMEZ (cihazda kalır); `share-cards` yeniden üretilebilir cache'tir → 30 gün lifecycle ile otomatik budanır; Docker log rotation (max-size/max-file) + haftalık `docker image prune` cron'u zorunlu; `sleep_sessions` aylık partition + 18 ay sonrası agregat-özete indirgeme politikası. Beklenen ilk yıl toplamı < 40 GB.
- **Trafik/CDN:** alan adı Cloudflare free proxy arkasına alınır; immutable asset'ler edge'de cache'lenir (VPS trafik kotası korunur). Cache-Control header'ları B0'da doğru kurulur.
- **E-posta:** magic-link için SMTP sağlayıcısı şart (self-host mail deliverability nedeniyle yasak): Brevo/Resend free tier; `shared/infra/mailer` adaptör arkasında, sağlayıcı tek satırla değişebilir.

## 4. API Tasarımı

- REST, `/v1` prefix. Kaynak örnekleri: `POST /v1/archetype/answers`, `GET /v1/content/feed`, `POST /v1/sleep/sessions`, `GET /v1/reports/{id}`, `POST /v1/mixes`, `GET /v1/flags`.
- Kimlik: `Authorization: Bearer <access JWT>` — kendi `identity` modülümüzün imzaladığı RS256 token; guard lokal public key ile doğrular. Refresh akışı: `POST /v1/auth/refresh`.
- Idempotency: yazma uçlarında `Idempotency-Key` header desteği (mobil offline kuyruğu retry yapar).
- Rate limit: Redis tabanlı, kullanıcı başına; anonim uçlar (web testi) IP başına.
- Hata sözleşmesi: RFC 7807 problem+json; hata kodları enum olarak `shared-types`'a üretilir.
- OpenAPI çıktısı codegen'in tek kaynağı (bkz. 01 no'lu doküman).

## 5. Fazlar

### Faz B0 — VPS + Çekirdek Stack (Hafta 1–3)

- VPS sertleştirme: ssh key-only, ufw (22/80/443), fail2ban, unattended-upgrades, Docker.
- Compose stack'leri (staging+prod ayrı): Postgres + MinIO + Redis (yalnızca iç ağ) + API + Caddy (otomatik SSL). GitHub Actions → SSH deploy hattı boş commit'le uçtan uca test edilir.
- NestJS iskeleti: shared/kernel (Result, DomainEvent, outbox), tipli config, Sentry, health check, OpenAPI pipeline + codegen CI'ı.
- `identity` v1: anonim cihaz kaydı (`POST /v1/auth/device`), access/refresh token akışı, rotation + reuse-detection.
- dbmate migration akışı + şema v1 (users/auth/profiles/archetype_results/soundscapes/presets) + seed.
- Public uç: web archetype testi için `POST /v1/archetype/web` (anonim skorlama + paylaşım slug'ı, IP rate-limit'li).
- MinIO bucket'ları: `soundscape-assets`, `share-cards`, `backups`; günlük pg_dump + off-site yedek cron'u.
- **Çıkış kriteri:** staging'de /health 200; anonim kayıt→token→yetkili istek zinciri integration testle kanıtlı; web testi ucu çalışıyor; yedek dosyası VPS dışında doğrulandı.

### Faz B1 — Modül Çekirdeği (Hafta 4–7)

- Modüller: `profile`, `archetype` (soru matrisi versiyonlu — sorular DB'de, admin düzenleyebilir), `content` (feed: archetype affinity'ye göre sıralı içerik; asset'ler MinIO presigned URL), `flags`.
- `identity` v2: e-posta ile hesaba yükseltme (magic link), hesap silme kaskadı.
- **Entitlement stub'ı:** `billing` modülü henüz YAZILMAZ; onun yerine tek arayüz `EntitlementService` — geliştirme boyunca herkes premium döner. Gerçek IAP docs/10'da bu arayüzün arkasına takılır.
- **Çıkış kriteri:** mobil tüm işlemleri API'den yapıyor; boundary lint + %80 kapsam eşiği aktif; "A, B'nin verisini okuyamaz" testleri her kişisel-veri ucu için yeşil.

### Faz B2 — Sleep & Report (Hafta 8–11)

- `sleep`: session ingest (idempotent, offline batch destekli), doğrulama (max süre, çakışan oturum reddi).
- Gece raporu üretimi: use case cihazdan gelen metrikleri + archetype'ı birleştirir → `report jsonb` (kartı cihaz çizer; sunucu yalnızca paylaşım sayfası için OG image üretir — satori, on-demand + MinIO cache).
- `sharing`: `share_slug` üretimi, `/a/{slug}` ve `/r/{slug}` için public read endpoint'leri (web app tüketir).
- `streaks` mantığı (yerel gün sınırı kuralı shared fonksiyonda).
- **Çıkış kriteri:** uçtan uca: cihaz oturum yollar → rapor oluşur → web'de paylaşım sayfası açılır.

### Faz B3 — Admin API + Notification Altyapısı (Hafta 12–15)

- `admin` modülü: admin auth (davetli + TOTP), RBAC guard (owner/editor/analyst/support), CMS CRUD'ları (soundscape/preset/weekly_release, taslak→zamanla→yayınla akışı), kullanıcı arama, entitlement override (destek senaryosu), `audit_log` her admin mutasyonunda zorunlu.
- `notification`: token kaydı, BullMQ fan-out worker'ı, sessiz saat kuralı — **gerçek APNs/FCM gönderimi HARİÇ** (dev hesabı ister, docs/10'a). Worker, "gönderici adaptörü" arayüzüne yazar; geliştirmede log adaptörü çalışır.
- Outbox publisher worker'ı çalışır hale gelir (event → PostHog/push tetikleri).
- Metrik sorguları: D1/D7/D30 retention, paylaşım oranları — materialized view'lar + gece refresh cron'u.
- **Çıkış kriteri:** panel tüm operasyonları API üzerinden yapabiliyor; kampanya oluşturma → worker'ın log adaptörüne doğru fan-out'u testle kanıtlı.

### Faz B4 — Sertleşme & Ölçek (Hafta 15–18)

- Rate limit'ler, request boyut limitleri, kritik tablo değişiklik loglaması.
- Okuma yolu cache'i (Redis, content feed 5 dk TTL), CDN/cache header'ları.
- Partitioning: `sleep_sessions` aylık partition (büyüyen tek tablo).
- Yedek geri-dönüş tatbikatı: staging'e dünkü yedekten tam restore.
- SLO'lar: API uptime %99.5, p95 < 200ms; Sentry alert kuralları; k6 yük testi (200 rps feed okuma < p95 150ms).
- İlk kopartma adayı dokümante edilir: `sleep` modülü (en yüksek yazma hacmi).

### Faz B5 — Billing (EN SON — dev hesapları bağlandıktan sonra, docs/10 ile)

- `billing` modülü: In-App Purchase doğrulama. Varsayılan yol **doğrudan Apple** (StoreKit 2 + App Store Server API + Server Notifications V2 — "tamamen bize ait" ilkesine uygun, üçüncü parti yok); istenirse RevenueCat alternatifi tek adaptör değişikliğidir.
- Transaction doğrulama (JWS imza), `billing_events` idempotency, entitlement senkronu, `GET /v1/me/entitlement`; gerçek 7 gün deneme durumu sunucuda.
- `EntitlementService` stub'ı gerçek implementasyonla değiştirilir — uygulama kodunda başka hiçbir şey değişmez (arayüz bunun için vardı).
- **Çıkış kriteri:** sandbox satın alma → bildirim → entitlement → uygulamada premium açılıyor; iade → geri kapanıyor (ikisi de test edildi).

## 6. Test Stratejisi

- Unit: use case'ler (port'lar fake ile) — hedef davranış: skorlama matrisi, streak kuralları, entitlement geçişleri.
- Integration: modül başına, testcontainers Postgres'e karşı repository + controller (supertest).
- Contract: OpenAPI şema snapshot'ı — beklenmeyen breaking change CI'da patlar.
- Yetkilendirme: "kullanıcı A, B'nin verisini okuyamaz/yazamaz" integration testleri her kişisel-veri endpoint'i için zorunlu.
- Auth: token rotation, reuse-detection, süre dolumu, yanlış audience senaryoları ayrı test paketi.
- Billing (B5'te): Apple imzalı örnek JWS fixture'ları ile doğrulama + idempotency testleri.
