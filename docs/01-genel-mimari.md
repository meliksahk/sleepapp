# 01 — Genel Mimari ve Monorepo

> Kararlar (kullanıcı onaylı): monorepo; backend = tamamen kendi VPS'imizde self-hosted NestJS + Postgres + MinIO + Redis (BaaS yok); admin = Next.js + shadcn/ui; mobil = Flutter + Riverpod; ödeme (IAP) ve dev-hesabı gerektiren tüm işler en son faz (docs/10).

## 1. Sistem Topolojisi

```
                    ┌─────────────────────────────────────────────┐
                    │                KULLANICILAR                  │
                    └──────┬───────────────┬──────────────┬───────┘
                           │               │              │
                   Flutter App        Tanıtım Sitesi   Admin Panel
                   (iOS öncelikli)    (Next.js SSG)    (Next.js)
                           │               │              │
          on-device katman │               │              │
     ┌─────────────────────┤               │              │
     │ Jeneratif ses motoru│         Vercel/CF Pages   Vercel
     │ Uyku analizi (mic)  │               │              │
     │ Kart/video render   │               └──────┬───────┘
     └─────────────────────┤                      │
                           ▼                      ▼
                ┌──────────────────────────────────────────┐
                │     BACKEND KATMANI (Hostinger VPS)      │
                │  NestJS API + Worker (Docker)            │
                │  Postgres + MinIO (S3) + Redis (Docker,  │
                │  yalnızca iç ağ) + Caddy/Traefik (SSL)   │
                │  Sentry (hata takibi)                    │
                └───────────┬──────────────────────────────┘
                            │ (en son faz, dev hesapları sonrası)
            App Store    ───┤  Server Notifications (IAP)
            APNs/FCM     ───┘  (push)
```

**Temel ilke — maliyet mimarisi:** pahalı her şey cihazda çalışır (ses sentezi, mikrofon analizi, video render, kart render). Sunucu yalnızca _metadata ve koordinasyon_ taşır. Bu, sıfır sermaye kısıtının mimari karşılığıdır: 100 bin kullanıcıda bile sunucu yükü "küçük CRUD API" seviyesinde kalır.

## 2. Neden Monorepo

- API kontratı (OpenAPI → TS tipleri + Dart client) ve design token'lar tek kaynaktan dört yüzeye akar; polyrepo'da bu senkronizasyon tek kişinin en çok zaman yakan işi olurdu.
- Tek CLAUDE.md, tek CI konfig ailesi, tek PR akışı.
- İleride ekip: her `apps/*` dizini CODEOWNERS ile bir ekibe atanabilir; boundary lint'leri sayesinde modül sınırları zaten nettir. Gerekirse bir app tarihçesiyle ayrı repoya `git filter-repo` ile kopartılır — monorepo tek yönlü kapı değildir.

## 3. Paylaşılan Paketler

| Paket           | İçerik                                                                                        | Tüketen            |
| --------------- | --------------------------------------------------------------------------------------------- | ------------------ |
| `design-tokens` | JSON kaynak → Style Dictionary ile CSS variables + Tailwind preset + Dart `ThemeData` üretimi | mobile, admin, web |
| `shared-types`  | OpenAPI'den üretilen TS tipleri + zod şemaları                                                | admin, web         |
| (Dart client)   | Aynı OpenAPI'den `openapi-generator` ile Dart paketi (`apps/mobile/packages/api_client`)      | mobile             |
| `ui`            | shadcn tabanlı React primitive kiti                                                           | admin, web         |
| `config`        | eslint/tsconfig/prettier/commitlint                                                           | tüm TS             |

**Codegen akışı (tek yönlü, elle müdahale yasak):**
`apps/api` decorators → `openapi.json` → CI'da `pnpm gen:api-types` → değişiklik varsa PR'a commit. Token'larda aynı desen: `tokens.json` → `pnpm gen:tokens`.

## 4. Ortamlar ve CI/CD

- Ortamlar: `local` (docker compose: Postgres+MinIO+Redis), `staging` (VPS'te ayrı compose stack + ayrı DB), `production` (aynı VPS, ayrı stack + ayrı domain). Staging'siz production'a hiçbir migration gitmez.
- Barındırma: eldeki **Hostinger VPS** birincil hedef — Docker + Coolify (self-hosted PaaS; git-push deploy, otomatik SSL, tek panel) veya sade docker-compose + GitHub Actions SSH deploy. Statik siteler (web) yine Cloudflare Pages/Vercel free tier'da kalır (global CDN, VPS'i yormaz); API + admin + worker VPS'te.
- GitHub Actions, Turborepo remote cache + path filtering: yalnızca değişen app'in pipeline'ı koşar.
- Pipeline sırası (her app): lint → typecheck → unit → integration → build → (main'de) deploy. Mobil: ek olarak `flutter analyze` + fastlane ile TestFlight lane'i.
- Sürümleme: API `v1` URL sürümü; mobil semver + build number fastlane ile otomatik; web/admin sürekli deploy.

## 5. Ölçeklenme Evrimi (planlı yol, spekülasyon değil)

| Aşama | Tetik                                                          | Değişiklik                                                                                                                                           |
| ----- | -------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| E0    | Başlangıç                                                      | VPS'te tek compose stack: NestJS + Postgres + MinIO + Redis; mobil/web ilk günden API'ye konuşur (BaaS ara katmanı hiç olmaz — geçiş maliyeti sıfır) |
| E1    | Kuyruk gerektiren işler (push fan-out, haftalık içerik yayını) | BullMQ worker container'ı; outbox pattern                                                                                                            |
| E2    | Ekip / yük büyümesi                                            | Modüller zaten hexagonal → en sıcak modül (ör. `sleep`) ayrı servise kopartılır; DB önce şema ayrımı, sonra gerekirse ikinci VPS/managed Postgres    |

Bu tablo "mikroservisle başlamıyoruz ama mikroservise kapı açık" kararının kendisidir. Tek kişiyle mikroservis başlangıcı kabul edilmez (operasyonel yük), düz spagetti monolit de kabul edilmez (ekip gelince kilitlenir); modüler monolit ikisinin kesişimidir.

## 6. Faz Haritası (tüm iş akışlarının üst görünümü)

| Faz             | Süre hedefi              | Mobil                                      | Backend                     | Admin                      | Web                                          |
| --------------- | ------------------------ | ------------------------------------------ | --------------------------- | -------------------------- | -------------------------------------------- |
| F0 Doğrulama    | Hafta 1–2                | —                                          | VPS+Postgres+API çekirdeği  | —                          | Archetype web testi yayında, paylaşım ölçümü |
| F1 Temel        | Hafta 3–5                | Skeleton+auth+design system                | identity(auth)+şema v1      | —                          | Bekleme listesi + SEO temeli                 |
| F2 Çekirdek     | Hafta 5–9                | Test+kimlik kartı, mikser+jeneratif motor  | content/archetype modülleri | CMS v1 (soundscape/preset) | İçerik motoru başlar                         |
| F3 Takip        | Hafta 9–12               | Uyku takibi+alarm+gece raporu              | sleep/report modülleri      | Metrik panosu v1           | Programatik sayfalar                         |
| F4 Viral        | Hafta 12–16              | Mix-to-video, streak, haftalık içerik      | sharing+flags+notification  | Kampanya+flag yönetimi     | GEO derinleşme                               |
| F5 Cila         | Ay 4+                    | A/B altyapısı, erişilebilirlik, performans | analytics+sertleşme         | Kohort analizi             | Blog ölçekleme                               |
| F6 Para+Lansman | Dev hesapları bağlanınca | Paywall+IAP+TestFlight+store               | billing modülü              | Abonelik ekranları         | Lansman sayfası                              |

F6, docs/10'daki "dev hesapları bağlandıktan sonra yapılacaklar" listesinin kendisidir; loop F5 sonuna kadar insan girdisi olmadan akar, F6 için hesapları senden ister.

Detaylı fazlar: backend `02`, admin `03`, mobil `04`, web `05` dokümanlarında.

## 7. Gözlemlenebilirlik

- Sentry: dört yüzeyde de (Flutter, NestJS, iki Next.js) release + source map/symbol upload CI'da.
- Ürün analitiği: PostHog free tier (EU host). Olay sözlüğü tek dosyada (`docs/analytics-events.md` — F2'de oluşturulur); sözlükte olmayan event gönderilemez.
- Uptime: Better Stack free tier ping + status.
- Kuzey yıldızı metrikler: D7 retention, archetype kartı paylaşım oranı, gece raporu görüntülenme→paylaşım dönüşümü, deneme→ücretli dönüşüm.
