# 07 — Bu Projeyi Geliştirmek İçin Claude Skills & Connectors

> Amaç: Claude (Cowork/Claude Code) ile bu monorepoyu geliştirirken kurulması gereken bağlantılar (connector/MCP) ve yazılması gereken özel skill'ler. "Kurulu mu?" sütunu bu oturumdaki duruma göre işaretlendi; kendi ortamında doğrula.

## 1. Connectors / MCP Sunucuları

### Zorunlu (F0–F1'den itibaren)

| Connector        | Ne için                                                                | Not                                                                                                    |
| ---------------- | ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| **GitHub**       | PR/issue/CI yönetimi, kod inceleme akışı                               | `gh` CLI cloud oturumlarda zaten var; desktop'ta connector kur                                         |
| **Postgres MCP** | Staging DB'ye salt-okunur sorgular, şema inceleme, migration doğrulama | Resmî Postgres MCP server; YALNIZCA staging'e, read-only kullanıcıyla bağla (prod bağlantısı verilmez) |
| **Sentry**       | Hata triyajı, release health, "bu crash'in kökü ne" analizi            | Bu oturumda zaten bağlı; dört projeyi (mobile/api/admin/web) ayrı ayrı tanımla                         |

### Kuvvetle önerilen (F2+)

| Connector                         | Ne için                                                                                                    |
| --------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| **PostHog MCP**                   | Funnel/retention sorgularını Claude'a sordurma ("D7 bu hafta neden düştü")                                 |
| **Linear veya GitHub Projects**   | Faz planındaki işlerin takibi; ekip gelince zorunlu olur                                                   |
| **Figma**                         | Design token/mockup senkronu (Claude Design çıktıları Figma'ya taşınırsa)                                  |
| **Slack**                         | Ekip kurulunca: CI/Sentry alert kanalları, release duyuruları                                              |
| **App Store Connect API** (F6'da) | Abonelik/satış metrikleri için custom skill — billing doğrudan Apple ile olduğundan RevenueCat'e gerek yok |
| **Google Search Console**         | Resmî connector yok; API anahtarıyla custom skill üzerinden SEO raporu çekme                               |

### Bilinçli olarak kurulmayan

- App Store Connect MCP: mağaza işlemleri fastlane ile CI'dan yapılır; canlı mağaza erişimini agent'a vermek risk/fayda dengesinde gereksiz.

## 2. Yazılacak Özel Skill'ler (`.claude/skills/` altında)

Skill = tekrar eden işin standart tarifi. Bu projede şunlar yazılmalı (öncelik sırasıyla):

1. **`new-feature-mobile`** — Flutter'da feature açma tarifi: klasör iskeleti (domain/data/presentation), Riverpod controller şablonu, test dosyaları, boundary lint kontrol listesi. _Faz M1 öncesi yazılır; mimarinin sürdürülmesini garanti eden en önemli skill budur._
2. **`new-module-api`** — NestJS'te hexagonal modül açma tarifi: port/adapter iskeleti, OpenAPI decorator standartları, integration test şablonu, boundary kuralları.
3. **`release-checklist`** — Mobil release tarifi: sürüm artırma, changelog, fastlane lane'leri, TestFlight dağıtımı, gerçek cihaz duman testi listesi, store metni sağlık-iddiası taraması, DURUM RAPORU zorunluluğu.
4. **`db-migration`** — Migration tarifi: SQL-first (dbmate) kural, down bloğu zorunluluğu, `prisma db pull` senkronu, yetkilendirme testi zorunluluğu, staging→prod sırası, yedek-önce kuralı.
5. **`content-page`** — `/sounds/*` programatik sayfa üretim tarifi: frontmatter şeması, 300+ kelime özgünlük kuralı, schema.org blokları, iç link kuralları, yasak kelime listesi (tedavi iddiaları).
6. **`geo-audit`** — Aylık GEO ölçüm tarifi: 20 soruluk test seti, motor başına alıntılanma tablosu, `llms.txt` güncelleme kontrolü.
7. **`analytics-event`** — Yeni analytics olayı ekleme tarifi: olay sözlüğü güncelleme, tipli event sınıfı (Dart+TS), PostHog doğrulama adımı.
8. **`revenue-report`** (F6'da) — App Store Connect API'sinden MRR/deneme dönüşümü çekip haftalık özet üreten skill.
9. **`sound-design-review`** — Ses varlığı/preset PR'ları için kontrol listesi: LUFS hedefleri, loop noktası kliksizliği, 8 saat pil profili gerekliliği, golden audio testi güncelleme.

Her skill, kök `CLAUDE.md`'nin Dürüstlük Protokolü'ne ve DURUM RAPORU formatına atıf yapar; skill içindeki adımlar atlanırsa raporda "❌ Yapılmadı" satırına yazılır.

## 3. Hazır Skill'lerden Kullanılacaklar (Cowork'te mevcut)

- **dataviz** — admin panel grafik tasarımlarında ve yıllık Sleep Identity Report görsellerinde.
- **docx / pptx / pdf** — yatırımcı olmasa da: App Store review notları, basın kiti, veri hikâyesi PDF'leri.
- **skill-creator** — yukarıdaki özel skill'leri yazarken kullan (eval'li skill üretimi).
- **deep-research** — rakip takibi (Anima fiyat/feature değişimleri), ASO kelime araştırması, GEO taktik güncellemeleri için üç ayda bir.

## 4. CI/Otomasyon Tarafında Claude Kullanımı (ekip hazırlığı)

- PR review: GitHub Actions'ta claude-code review adımı — kontrol odağı: boundary ihlali, `userId` scoping'siz repository metodu, `identity` dışında JWT/kripto kodu, hard-coded string/hex, sağlık iddiası kelime taraması, test eksiği. İnsan onayının yerine geçmez, önüne geçer.
- Haftalık scheduled task (Cowork): Sentry + PostHog + GSC'den haftalık sağlık raporu derleyip özetleyen görev.
- Kural: Agent'ların prod'a yazma yetkisi YOK — deploy her zaman CI pipeline'ından, migration her zaman insan onaylı PR'dan.
