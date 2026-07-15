# LOOP_STATE — NOCTA geliştirme döngüsü defteri

> İnsanın loop'u denetlediği tek ekran. Her iterasyonda güncellenir (LOOP.md §6).
> Kanıt olmadan ✅ yazılmaz (Dürüstlük Protokolü).

**Aktif faz:** F1 (Temel) — F0 kickoff kapandı.
**Repo:** https://github.com/meliksahk/sleepapp (private)
**Son güncelleme:** 2026-07-15

---

## Faz F0 — Kickoff (KAPANDI)

docs/09 kickoff master prompt uygulandı. "Önce lokal" stratejisi (kullanıcı kararı):
VPS sertleştirme + staging deploy, kullanıcı VPS kimlik bilgilerini verince yapılacak.

### Yapıldı ve doğrulandı ✅

- **Monorepo temeli:** pnpm workspaces + Turborepo, `@nocta/config` (eslint9 flat + prettier + tsconfig + commitlint), husky (commit-msg + pre-commit) — `pnpm install` ✓, commitlint valid/invalid ✓, pre-commit prettier gerçek commit'te çalıştı ✓.
- **design-tokens:** tokens.json → Style Dictionary → CSS vars + Tailwind preset + Dart theme. `pnpm gen:tokens` ✓, üç çıktı da üretildi ✓.
- **API (identity v1):** NestJS hexagonal; anonim cihaz kaydı `POST /v1/auth/device`, refresh rotation + reuse-detection (`/v1/auth/refresh`), guard'lı `/v1/auth/me`; jose RS256 + SHA-256 refresh-hash. **13 test yeşil** (unit + docker'sız HTTP e2e), coverage application %98 / domain %100 (≥80 eşik ✓).
- **App iskeletleri:** admin + web (Next15 App Router, TS strict, Tailwind3 + tokens) → build+lint+typecheck ✓; mobile (Flutter, flavor'lar dev/staging/prod, Riverpod + go_router, üretilen Dart token) → `flutter analyze` temiz + widget test ✓.
- **Codegen:** `gen:api-types` uçtan uca (api build → openapi export → openapi-typescript) ✓; `gen:tokens` (CSS+Dart) ✓.
- **CI:** GitHub Actions `ci.yml` (TS turbo job + Flutter job). **Remote'ta yeşil koştu** (run 29423231326): lint/typecheck/test/build + flutter analyze/test hepsi ✓.
- **GitHub:** private `sleepapp` reposu oluşturuldu + push edildi; PR template (zorunlu DURUM RAPORU) + CODEOWNERS.

### Yapıldı, doğrulanmadı ⚠️

- (temiz — F0'ın DB ⚠️ maddesi iter #1'de kapatıldı.)

### Yapılmadı / ertelendi ❌

- **VPS (docs/09 Adım 2) + staging deploy (Adım 5):** kullanıcı kararıyla ertelendi; VPS kimlik bilgileri gelince.
- **Branch protection / CI-zorunlu kilit:** GitHub free planda private repoda API kapalı (bkz. DECISIONS_NEEDED).
- **Dart API client (openapi-generator):** Java yok → ertelendi (bkz. BLOCKERS).
- **argon2id şifre-hash:** identity v1'de şifre yok; F1 e-posta yükseltmede eklenecek (port hazır).
- **Boundary lint (eslint-plugin-boundaries / import_lint):** paket kuruldu ama modül-içi kurallar henüz tanımlanmadı (F1).

---

## Sıradaki iş (F1 — docs/02 B1, docs/03 A0, docs/05 W0)

Öncelik sırası (bir yüzey blokeyse diğerine geç):

1. **admin A0 devam:** auth guard/middleware iskeleti (davetli hesap + rol modeli, docs/03) + `packages/ui`'ye DataTable/Input/ConfirmDialog + feature-sliced boundary lint. packages/ui çekirdeği (Button/StatCard/EmptyState) + AppShell + dashboard ✓ iter #15.
2. **web SEO temeli:** otomatik sitemap + `llms.txt` + OG image üretimi (satori) + CWV lighthouse-ci (docs/05 §3).
3. **admin A0:** `packages/ui` başlangıcı (Button/Input/DataTable/StatCard/EmptyState) + AppShell + auth guard iskeleti (docs/03) + feature-sliced boundary lint.
4. **API sertleşme (B4 erken):** content feed cache (Redis 5dk TTL), rate-limit'i Redis storage'a taşı, request boyut limitleri.
5. **notification modülü iskeleti** (docs/02 B3): token kaydı + BullMQ fan-out log-adaptörü (gerçek APNs/FCM → docs/10).

> B1 backend modülleri TAMAM: identity(v1+v2+silme), profile, archetype(+web), flags, content(+MinIO). API 15 endpoint.

## İterasyon geçmişi

- **#0 (F0 kickoff):** tüm zemin (monorepo, tokens, API+identity, app iskeletleri, codegen, CI). 8 commit, CI yeşil.
- **#1 (DB canlı doğrulama):** Docker stack ayağa kaldırıldı; migration gerçek Postgres'e uygulandı (down/up tersinir + seed doğrulandı); `db/schema.sql` üretildi. B-1 + B-2 çözüldü. PR #1.
- **#2 (Prisma adaptörleri):** identity in-memory → gerçek Postgres (Prisma). `prisma db pull` şema senkronu, PrismaService + Prisma repo'ları, env-based değil doğrudan wiring. Integration testleri (izolasyon dahil) + e2e artık gerçek DB'ye karşı; CI'a Postgres service + dbmate migrate eklendi. 16 test yeşil, curl ile uçtan uca kanıt (register→me→refresh→reuse 401, DB'de satırlar doğru). PR #2.
- **#3 (profile modülü):** ilk F1 feature modülü — `GET`/`PATCH /v1/profile` (kimlik doğrulamalı, kendi profili; upsert; varsayılan projeksiyon). Global PrismaModule refactor, identity public barrel (modüller-arası tek kapı), AuthGuard tüketimi. 21 test yeşil (izolasyon "A, B'yi göremez" dahil); OpenAPI + shared-types senkron. Hexagonal desen sonraki modüller için şablon. PR #3.
- **#4 (boundary lint — api):** eslint-plugin-boundaries + TS resolver ile hexagonal sınırlar zorlanıyor. Kanıtlandı: domain→application, presentation→infrastructure, modüller-arası deep import (barrel dışı) ihlalleri YAKALANIYOR; temiz kod geçiyor. 13/13 turbo yeşil. (Not: import resolver olmadan kural sessiz no-op'tu — düzeltildi ve kasıtlı ihlallerle doğrulandı.) PR #4.
- **#5 (archetype modülü):** viral kanca #1 çekirdeği. Versiyonlu soru matrisi (v1, 6 soru) + deterministik skorlama (saf domain, eşitlikte sıra kuralı). `GET /v1/archetype/questions`, `POST /answers` (skorla+kaydet), `GET /result`. `archetype_results` migration (down + prisma db pull). 31 test yeşil (skorlama unit + e2e: skorlama/kalıcılık/validasyon/izolasyon). Not: sorular F1'de domain sabiti; DB-tabanlı sorular admin CMS (A1). PR #5.
- **#6 (archetype public web ucu):** viral ön-lansman aracı (docs/05 W0). `POST /v1/archetype/web` (anonim, kimlik yok — skorla + paylaşım slug üret), `GET /v1/archetype/web/{slug}` (OG/sayfa verisi). `web_archetype_results` tablosu (PII yok). IP rate-limit @nestjs/throttler (30/60s, yalnızca bu controller) — **ad-hoc doğrulandı: 30×201 sonra 429**. 35 test yeşil. Not: dağıtık/Redis rate-limit B4. PR #6.
- **#7 (flags modülü):** `GET /v1/flags` (kimlik doğrulamalı) → değerlendirilmiş flag haritası. Saf domain `evaluateFlag` (enabled + deterministik rollout kovası) + CryptoBucketHasher (sha256, 0-99). `feature_flags` tablosu (rules jsonb). 43 test yeşil (değerlendirme + kova unit + e2e: 401/enabled/rollout 0/100). Not: flag YAZMA admin modülünde (B3); tam kural motoru (platform/sürüm/archetype segmenti) A4. PR #7.
- **#8 (content modülü):** `GET /v1/content/feed?archetype=` (yayınlanmış soundscape'ler, affinity sıralı — saf `sortByAffinity`) + `GET /v1/content/soundscapes/{slug}` (detay + preset). `soundscapes`+`presets` tabloları (content_status enum). 50 test yeşil (sort unit + e2e: 401/yalnızca-published/affinity sırası/detay/draft 404). Kapsam notu: ses TARİFİ metadata (on-device üretim); MinIO presigned URL (örnek dosyalar) ayrı iterasyona. PR #8.
- **#9 (MinIO presigned URL):** soundscape `preview_asset_key` → detayda presigned `previewUrl` (S3AssetSigner, AWS SDK v3 — üretim OFFLINE, canlı MinIO gerektirmez → CI'da service gerekmiyor). 51 test yeşil (e2e: key varsa imzalı URL X-Amz-Signature içerir, yoksa null). **Ek düzeltme:** `api test` script'i `--runInBand` yapıldı — paralel e2e'nin paylaşılan DB'ye karşı flake'ini giderdi. Not: gerçek dosya erişimi asset'ler yüklenince doğrulanır. PR #9.
- **#10 (hesap silme kaskadı):** `DELETE /v1/auth/me` (kimlik doğrulamalı, yalnızca kendi) → kullanıcı silme, FK ON DELETE CASCADE ile tüm ilişkili veri temizlenir (App Store/GDPR zorunluluğu). 55 test yeşil — e2e kaskadı GERÇEK DB'de kanıtladı: silmeden önce users/devices/refresh/profiles/archetype = 1, sonra hepsi 0. Not: MinIO nesne temizliği kullanıcı üretimi nesneler (share-cards) eklenince use case'e girer; kısa ömürlü access token blacklist edilmez (15 dk, refresh'ler silindi). PR #10.
- **#15 (packages/ui + admin dashboard):** paylaşılan React primitive kiti (docs/03 §1.1 Seviye 1) — `Button` (variant'lar), `StatCard`, `EmptyState`; token'lı, iş mantığı/API yok. Web'deki gibi vitest kuruldu (5 test: tıklama/disabled/variant/render). admin bunları tüketen AppShell (sidebar+topbar) + dashboard sayfasında kullanıyor (transpilePackages + tailwind content genişletildi). turbo 17 task yeşil (ui test dahil). Not: shadcn tabanına geçiş + DataTable sonraki iterasyonda.
- **#14 (archetype landing sayfaları):** `/a/{slug}` 4 SSG sayfa (deep-ocean/overthinker/delta-drifter/dawn-chaser) — SEO/GEO içerik (alıntılanabilir summary + paragraflar + "sana uygun sesler" + teste CTA) + schema.org JSON-LD (tek util). `generateStaticParams` ile static üretim; bilinmeyen slug → 404. 9 web testi yeşil — **sağlık iddiası taraması** dahil (cure/treat/therapy yasak kelime kontrolü). turbo 14/14.
- **#13 (web W0 frontend):** ilk frontend feature. `/test` sayfası — public API'yi tüketen `ArchetypeTest` client bileşeni (soruları çek → cevapla → `POST /v1/archetype/web` → sonuç + `/a/{slug}` linki) + home'da `WaitlistForm`. Web'e **vitest + testing-library** kuruldu (fetch mock'lu component testleri — CI'da API/DB gerekmez). 4 web testi + api 67 = turbo 14 task yeşil; `next build` static (home 1kB JS). **Ek düzeltme:** api jest `testTimeout` 30s — turbo eşzamanlı yükte e2e beforeAll flake'ini giderdi.
- **#12 (W0 API yüzeyi):** web viral testinin backend'i. Public `GET /v1/archetype/web/questions` (auth yok — tek kaynak matris, web render eder) + **waitlist** modülü `POST /v1/waitlist` (public, IP rate-limit'li, idempotent e-posta). `waitlist` tablosu. 67 test yeşil (e2e: public questions, waitlist katıl/idempotent/geçersiz-email 400). Not: web FRONTEND sayfaları (test altyapısı gerektirir) sıradaki iterasyonda.
- **#11 (identity v2 — magic link):** e-posta ile hesaba yükseltme. `POST /v1/auth/email/request` (kimlik doğrulamalı, magic link üret + log-mailer) + `POST /v1/auth/email/verify` (public, token → anonim→registered yükseltme, email_verified_at). `one_time_tokens.email` kolonu; OTT/Mailer portları; dev'de ham token dönüyor (prod'da gizli, IS_PRODUCTION DI token'ı — presentation→shared boundary'sini korur). 63 test yeşil (in-memory unit + e2e: request/verify/kullanılmış-token 401/geçersiz-email 400/e-posta çakışması 409). Not: **gerçek SMTP (Brevo/Resend) ertelendi** → DECISIONS_NEEDED D-5; argon2id yalnızca şifre-tabanlı auth eklenirse gerekir (magic link passwordless).
