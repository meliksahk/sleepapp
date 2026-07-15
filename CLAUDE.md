# NOCTA — Sleep Identity Platformu (çalışma kod adı, değiştirilebilir)

Bu dosya, bu monorepoda çalışan her Claude oturumunun ve her geliştiricinin uyması gereken kuralların tek kaynağıdır. Derin mimari detaylar `docs/` altındadır; çelişki durumunda bu dosya kazanır.

---

## 0. MUTLAK KURAL: Dürüstlük Protokolü

Bu projenin bir numaralı kuralı dürüstlüktür. Aşağıdaki maddeler pazarlıksızdır:

1. **Çalışmayan şeye "çalışıyor" deme.** Bir özelliğin çalıştığını söylemeden önce onu gerçekten çalıştır (test, script, curl, tarayıcı). Çalıştıramadıysan "yazdım ama test edemedim" de. Kanıtsız "tamamdır" yasak.
2. **Eksik bıraktığını saklama.** Bir görevi kısmen yaptıysan, atladığın veya basitleştirdiğin her parçayı açıkça listele: "şimdilik mock döndürüyorum", "hata yönetimi eklemedim", "bu edge case'i kapsamadım" gibi.
3. **Varsayımlarını bildir.** Belirsiz bir konuda karar verdiysen ("X kütüphanesinin Y sürümünü varsaydım", "tarih formatını UTC kabul ettim") bunu raporla.
4. **Bilmiyorsan bilmiyorum de.** Bir API'nin güncel davranışından, bir limitin değerinden emin değilsen tahmin üretip kesin gibi sunma. "Dokümana bakmam gerekiyor" veya "emin değilim, doğrulayalım" de.
5. **Riskleri ve açıkları gizleme.** Kodda güvenlik açığı, performans sorunu, veri kaybı riski veya teknik borç görüyorsan — kendi yazdığın kodda bile — kullanıcı sormasa da söyle.
6. **Sessizce kapsam daraltma yapma.** İstenen işi daha kolay bir versiyonuyla değiştirdiysen (ör. gerçek API yerine sahte veri), bunu görünür şekilde belirt.
7. **Hataları üstlen.** Önceki oturumda/committe yanlış yaptıysan, fark ettiğin anda söyle ve düzeltme öner. Hatayı örtmek için kod yamalama yasak.

### Zorunlu Rapor Formatı

Her anlamlı görevin sonunda şu blok üretilir (kısa görevlerde bile en az ilk üç satır). Blok boş geçilemez; her şey mükemmelse "risk yok" yazılır ama blok yazılır:

```
## DURUM RAPORU
✅ Yapıldı ve doğrulandı : <test edilmiş, çalıştığı kanıtlanmış işler>
⚠️ Yapıldı, doğrulanmadı : <yazıldı ama test edilemedi + nedeni>
❌ Yapılmadı / eksik      : <atlanan, ertelenen, kapsam dışı bırakılan işler>
📌 Varsayımlar            : <verilen kararlar ve dayanakları>
🔥 Riskler / açıklar      : <güvenlik, veri, performans, teknik borç>
```

---

## 1. Proje Nedir

Tek kişilik, sıfır sermayeli, viral motorlu bir uyku uygulaması ekosistemi. Dört yüzey:

- **Flutter mobil uygulama** (`apps/mobile`) — Sleep Archetype testi, on-device jeneratif ses motoru + mikser, mikrofonla uyku takibi + akıllı alarm, "Gece Raporu" paylaşım kartı, mix-to-video (9:16, watermark'lı) export, streak/habit döngüsü, haftalık soundscape içerikleri, paywall (cömert free tier + gerçek 7 gün deneme).
- **Backend servis** (`apps/api` — tamamı kendi VPS'imizde: NestJS + Postgres + MinIO + Redis) — kimlik/auth, profil, archetype sonuçları, içerik metadata'sı, uyku oturumları, rapor üretimi, abonelik (IAP doğrulama — en son faz), push, analytics ingest. **Üçüncü parti BaaS (Supabase/Firebase) kullanılmaz; veri ve auth tamamen bize aittir.**
- **Admin panel** (`apps/admin`) — içerik CMS'i (soundscape/preset/haftalık yayın), kullanıcı yönetimi, metrik panoları (D7 retention, kart paylaşım oranı), feature flag, push kampanyaları.
- **Tanıtım sitesi** (`apps/web`) — SEO + GEO odaklı; web tabanlı archetype testi (viral ön-lansman aracı), programatik long-tail sayfalar, blog.

### 1.1 Ürün İlkeleri (koda ve metne yansır)

- **Sağlık iddiası YASAK.** Hiçbir yerde (kod, UI metni, store metni, site, push) "tedavi", "treatment", "cures", "tinnitus tedavisi", "%100 science-backed" tarzı ifade kullanılmaz. Konumlandırma: **"relaxation & sleep ritual"**. Bu bir uyum (FTC/App Store/reklam kurulu) ve itibar kuralıdır; metin üreten her PR'da kontrol edilir.
- **Ses her şeydir.** Ses motoru veya ses varlıklarında "ucuz" duyulan hiçbir şey ship edilmez; ses değişiklikleri gerçek cihazda kulaklıkla doğrulanır.
- **Viral kancalar süs değil çekirdek özelliktir:** archetype kartı, gece raporu, mix-to-video. Bu üçünün paylaşılabilirliğini bozan değişiklik regresyondur.
- **Maliyet disiplini:** aylık işletme maliyetini artıran her karar (yeni servis, CDN, stream) açıkça gerekçelendirilir; varsayılan cevap "on-device / free tier" çözümüdür.

---

## 2. Monorepo Yapısı

```
nocta/
├── CLAUDE.md                  # bu dosya — tek kural kaynağı
├── docs/                      # mimari ve faz dokümanları (01–07)
├── apps/
│   ├── mobile/                # Flutter (feature-first Clean Architecture + Riverpod)
│   ├── api/                   # NestJS modüler monolit (hexagonal modüller)
│   ├── admin/                 # Next.js App Router + shadcn/ui (feature-sliced)
│   └── web/                   # Next.js SSG tanıtım sitesi (SEO/GEO)
├── packages/
│   ├── design-tokens/         # renk/typo/spacing token'ları → TS + Dart'a üretilir
│   ├── shared-types/          # API kontratları: OpenAPI'den üretilen TS tipleri
│   ├── ui/                    # admin+web ortak React bileşen kiti (shadcn üzerine)
│   └── config/                # eslint, tsconfig, prettier, commitlint ortak configleri
├── db/                        # SQL migrations (dbmate), seed scriptleri, yedekleme scriptleri
├── tooling/                   # codegen scriptleri (openapi→ts, tokens→dart/css)
└── .github/workflows/         # CI: path-filtered pipeline'lar (app başına)
```

- **Araçlar:** pnpm workspaces + Turborepo (TS tarafı), Melos (Flutter tarafı için `apps/mobile` içinde paketleme gerekirse).
- **Kural:** `apps/*` birbirini asla import etmez. Paylaşım yalnızca `packages/*` üzerinden.
- **Kural:** API kontratı tek kaynaktan üretilir (`apps/api` OpenAPI çıktısı → `packages/shared-types` + Dart client). Elle tip kopyalamak yasak.
- **Kural:** design token'lar yalnızca `packages/design-tokens`'ta tanımlanır; hex kodu hard-code eden PR reddedilir.

---

## 3. Uygulama Başına Mimari Kuralları

### 3.1 `apps/mobile` — Flutter

- **Mimari:** Feature-first Clean Architecture. Her feature altında üç katman: `presentation/` (widget + Riverpod controller), `domain/` (entity, use case, repository arayüzü — Flutter'dan bağımsız saf Dart), `data/` (DTO, datasource, repository implementasyonu).
- **State management:** Riverpod (codegen'li). BLoC/GetX/Provider karışımı yasak — tek desen.
- **Bağımlılık yönü:** presentation → domain ← data. `domain/` hiçbir Flutter/IO paketi import edemez (lint ile zorlanır: `import_lint` / custom analyzer kuralı).
- **Ses motoru:** `core/audio_engine/` ayrı bir izole modüldür; native tarafla (iOS: AVAudioEngine, Android: Oboe) platform channel/FFI üzerinden konuşur. UI, motora yalnızca domain arayüzü (`AudioEngineFacade`) üzerinden erişir. Detay: `docs/04-flutter-app.md`.
- **Model kuralı:** domain entity'leri `freezed` ile immutable; DTO'lar `json_serializable`; DTO ≠ entity, mapper zorunlu.
- **Navigasyon:** go_router, route'lar tek dosyada tip güvenli tanımlanır.
- **Yerel veri:** drift (yapısal veri: uyku oturumları, mixler) + shared_preferences (basit ayarlar). Uygulama offline-first: ses üretimi ve mikser internetsiz tam çalışır.
- **Test:** her use case'e unit test; kritik akışlara (onboarding testi, paywall, alarm) widget/integration test. Ses motorunun DSP mantığına golden-audio testi (üretilen buffer'ın hash/istatistik doğrulaması).

### 3.2 `apps/api` — NestJS Modüler Monolit

- **Mimari:** Modüler monolit; her modül kendi içinde hexagonal (ports & adapters): `domain/` (entity, domain service, port arayüzleri), `application/` (use case/command/query handler), `infrastructure/` (Prisma repo, harici adapter), `presentation/` (controller, DTO).
- **Modüller:** `identity`, `profile`, `archetype`, `content` (soundscape/preset metadata), `sleep` (oturum + rapor), `sharing` (kart/video meta + derin linkler), `billing` (IAP doğrulama — en son faz, o güne dek `EntitlementService` stub), `notification`, `analytics-ingest`, `admin` (panel API'si), `flags`.
- **Kural:** modüller arası çağrı yalnızca modülün public application servisinden veya domain event üzerinden. Başka modülün repository/Prisma modeline dokunmak yasak (eslint boundary kuralı ile zorlanır). Bu, ileride modülün mikroservise kopartılabilmesinin garantisidir.
- **DB:** Postgres (VPS'te Docker container, yalnızca iç ağa açık — dışarıdan erişim yok). Erişim Prisma ile. Migration'lar SQL-first (`db/migrations`, dbmate) + `prisma db pull` ile şema senkronu. Mobil/panel DB'ye ASLA doğrudan bağlanmaz; tek kapı API'dir. Her sorgu, isteği yapan kullanıcının kimliğiyle kapsamlanır (repository katmanında zorunlu `userId` scoping — scoping'siz repository metodu PR'da reddedilir).
- **API:** REST + OpenAPI (nestjs/swagger'dan otomatik). Sürümleme URL ile: `/v1/...`. Breaking change = yeni sürüm; v(n-1) en az 2 mobil sürüm boyunca yaşar (app store gerçeği: kullanıcılar güncellemez).
- **Async iş:** BullMQ + Redis (VPS'te container). Domain event'ler outbox pattern ile güvenilir yayınlanır.
- **Kural:** controller'da iş mantığı yasak; use case'ler framework'ten bağımsız test edilebilir olmalı.

### 3.3 `apps/admin` — Next.js + shadcn/ui

- **Mimari:** Feature-sliced (katmanlı): `app/` (route'lar, yalnızca kompozisyon) → `features/` (dikey dilimler: content-cms, users, analytics, flags, campaigns) → `entities/` (domain görünümleri: user, soundscape) → `shared/` (ui kit re-export, api client, utils). Üst katman alta bağımlı olabilir, tersi yasak.
- **Atomic design kararı:** Katı atomic (atom/molekül/organizma klasörleri) KULLANILMIYOR — küçük ekipte bürokrasi üretir. Onun yerine iki seviye: `packages/ui` (primitive'ler: Button, Input, DataTable — shadcn tabanlı, token'lı) + feature içi kompozit bileşenler. Gerekçe ve detay: `docs/03-admin-panel.md`.
- **Veri:** TanStack Query + üretilen tip güvenli API client (`packages/shared-types`). Form: react-hook-form + zod (zod şemaları API DTO'larından türetilir).
- **Auth/RBAC:** kendi auth'umuz (API'nin `identity` modülü: davetli admin hesapları, argon2id hash, kısa ömürlü JWT + refresh rotation, TOTP 2FA). Roller: `owner`, `editor` (içerik), `analyst` (salt okunur), `support`. Her sayfa ve her mutation server-side rol kontrolünden geçer — yalnızca UI gizleme yeterli değildir.
- **Grafikler:** Recharts; tüm grafik renkleri token'lardan.

### 3.4 `apps/web` — Tanıtım Sitesi

- **Mimari:** Next.js App Router, tamamen static (SSG) + MDX içerik. İçerik `content/` altında dosya tabanlı; CMS yok (maliyet + basitlik).
- **SEO/GEO zorunlulukları:** her sayfada schema.org JSON-LD, semantik HTML, `llms.txt`, otomatik sitemap, OG image üretimi (satori ile edge'de değil build'de). Core Web Vitals bütçesi: LCP < 2.0s, CLS < 0.05, JS < 90KB (ana sayfa). Bütçe CI'da lighthouse-ci ile zorlanır.
- **Web archetype testi:** uygulamadan önce yayınlanan viral test aracı; sonuç kartı client-side canvas ile üretilir, paylaşım linki `/a/{archetype-slug}` olarak indekslenebilir sayfaya gider.

---

## 4. Kodlama Standartları (tüm repo)

- **Dil:** TS tarafında `strict: true`, `any` yasak (`unknown` + narrowing). Dart tarafında `strict-casts`, `strict-raw-types` açık; `dynamic` yasak.
- **İsimlendirme:** dosyalar kebab-case (TS) / snake_case (Dart); sınıflar PascalCase; DB tabloları snake_case çoğul.
- **Commit:** Conventional Commits (`feat(mobile): ...`, `fix(api): ...`). Scope = app/paket adı. commitlint CI'da zorlar.
- **Branch:** trunk-based. `main` her zaman deploy edilebilir; iş `feat/...`, `fix/...` kısa ömürlü branch'lerde; PR zorunlu (tek kişiyken bile — ileride ekip alışkanlığı şimdiden kurulur).
- **PR kuralları:** küçük PR (<400 satır diff hedef), açıklamada "ne + neden + nasıl test edildi". CI yeşil olmadan merge yok.
- **Hata yönetimi:** boş `catch` yasak. Hatalar tipli (`Result`/exception hiyerarşisi); kullanıcıya gösterilen mesaj ile loglanan teknik detay ayrılır. Tüm yüzeylerde Sentry aktif.
- **i18n:** tüm kullanıcı metinleri baştan itibaren i18n dosyalarında (mobil: `arb`, web/admin: namespace'li JSON). Hard-code string PR'da reddedilir. Başlangıç dilleri: EN (birincil), TR.
- **Zaman:** DB ve API'de her zaman UTC + ISO 8601; kullanıcı saat dilimi yalnızca sunumda. Uyku oturumları "gece" tanımı için kullanıcı yerel gününe göre gruplanır (kural: sabah 06:00 sınırı) — bu mantık tek bir paylaşılan fonksiyonda yaşar.
- **Yorum/doküman:** public API ve karmaşık DSP/algoritma kodu belgelenir; "ne" değil "neden" yazılır.

## 5. Test ve Doğrulama

- **Piramit:** bol unit (domain/use case), orta seviye integration (API modül testleri, repository'ler test DB'sine karşı), az ama kritik E2E (mobil: patrol/integration_test ile onboarding→mix→alarm akışı; admin: Playwright ile CMS yayın akışı).
- **Kapsam eşiği:** domain + application katmanlarında %80 satır kapsamı CI eşiği. UI katmanına sayı zorlanmaz, kritik akış testi zorlanır.
- **Kural:** bug fix'i, önce bug'ı üreten failing test yazılmadan merge edilemez.
- **Doğrulama kanıtı:** Dürüstlük Protokolü gereği "çalışıyor" demek için komut çıktısı/test sonucu/ekran görüntüsü gösterilir.

## 6. Güvenlik ve Uyum

- **Secrets:** repoya asla girmez; `.env` dosyaları gitignore'da, örnekleri `.env.example`. CI secret'ları GitHub Environments'ta.
- **Yetkilendirme:** kişisel veri taşıyan her tabloya erişim testle kanıtlanır: her yeni endpoint'e "kullanıcı A, B'nin verisini okuyamaz/yazamaz" integration testi zorunludur. Auth kodu (token üretimi, hash, refresh) yalnızca `identity` modülünde yaşar; başka yerde kripto/JWT kodu yazmak yasak.
- **Yedekleme:** Postgres günlük `pg_dump` + MinIO verisiyle birlikte off-site (VPS dışına) şifreli yedek; geri dönüş tatbikatı ayda bir. Yedeği olmayan production değişikliği yapılmaz.
- **PII/KVKK/GDPR:** mikrofon verisi ASLA ham yüklenmez — uyku takibi analizi on-device yapılır, sunucuya yalnızca türetilmiş metrikler (süre, hareket/ses olayları sayısı) gider. Hesap silme = tam kaskad silme (App Store zorunluluğu). Veri envanteri `docs/02-backend-servis.md`'de tutulur ve her yeni alanla güncellenir.
- **Ödeme:** ödeme verisi bize hiç uğramaz (In-App Purchase / StoreKit). Webhook/bildirim imza doğrulaması zorunlu. **Sıra kuralı:** ödeme entegrasyonu en son fazdır — tüm yapı çalışır olmadan ve geliştirici hesapları bağlanmadan ödeme kodu yazılmaz (bkz. docs/10). O güne kadar premium gating tek bir `EntitlementService` arayüzünün arkasında durur (geliştirmede herkes premium; arayüz sayesinde IAP sonradan tak-çıkar bağlanır).
- **Çocuk verisi:** 13 yaş altı hedeflenmez; yaş kapısı yok ama içerik/pazarlama çocuklara yönelik olamaz.

## 7. Definition of Done (her görev için)

1. Kod, ilgili mimari kurallara uygun (boundary lint'leri yeşil).
2. Testler yazıldı ve geçiyor; CI yeşil.
3. i18n, erişilebilirlik (touch target ≥44px, kontrast AA) ve dark-mode kontrol edildi.
4. Sağlık iddiası taraması yapıldı (metin değişen PR'larda).
5. Dokümantasyon/`docs/` etkileniyorsa güncellendi.
6. DURUM RAPORU bloğu yazıldı.

## 8. Claude Çalışma Biçimi

- Büyük işte önce kısa plan sun, onay al, sonra uygula. Belirsizlikte varsayım uydurmak yerine sor; sorulamıyorsa varsayımı DURUM RAPORU'na yaz.
- Var olan desenleri taklit et: yeni feature eklerken önce en benzer mevcut feature'ı oku.
- Bağımlılık eklemeden önce gerekçelendir (boyut, bakım, lisans); free-tier maliyet ilkesine uy.
- Migration, silme, store metadata değişikliği gibi geri alınması zor işleri asla sormadan yapma.
- Her uygulamanın kendi `CLAUDE.md`'si (varsa `apps/*/CLAUDE.md`) o dizinde ek kural getirir; kökle çelişirse kök kazanır.

## 9. Komutlar (özet)

```
pnpm i                             # kök bağımlılıklar
pnpm turbo build                   # tüm TS uygulamaları (turbo cache)
pnpm turbo lint typecheck test     # lint + typecheck + test (turbo cache = path-filter)
pnpm --filter @nocta/api dev       # API lokal :3001 (docker compose up -d ile birlikte)
pnpm --filter @nocta/admin dev     # admin panel :3002
pnpm --filter @nocta/web dev       # tanıtım sitesi :3003
docker compose up -d               # lokal Postgres + MinIO + Redis (yalnızca 127.0.0.1)
pnpm db:migrate                    # dbmate migration uygula (DATABASE_URL .env'den)
pnpm db:new <ad>                   # yeni migration dosyası aç
cd apps/mobile && flutter test && flutter run   # flavor: flutter run -t lib/main_dev.dart
pnpm gen:api-types                 # OpenAPI → packages/shared-types (TS). Dart client: openapi-generator (Java)
pnpm gen:tokens                    # design-tokens → CSS vars + Tailwind preset + Dart theme
pnpm --filter @nocta/api keys:gen  # identity RS256 anahtar çifti (stdout → .env, repoya değil)
# Not: Flutter codegen (freezed/json/riverpod build_runner) M0'da eklenecek (melos yok).
```
