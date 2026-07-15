# 03 — Admin Panel: Mimari ve Faz Planı

## 1. Mimari Karar

**Stack:** Next.js (App Router) + TypeScript strict + Tailwind + shadcn/ui + TanStack Query + react-hook-form + zod + Recharts. Deploy: Hostinger VPS'te API ile yan yana (Docker, Coolify/compose) — panel zaten iç araç, CDN gerekmez; erişim VPN/SSO + rol guard'ları arkasında.

### 1.1 "Katmanlı mimari gerekiyor mu, atomic gerekli mi?" — net cevap

**Katmanlı mimari: EVET, ama dikey dilimli haliyle (feature-sliced).** Klasik yatay katmanlama (tüm controller'lar bir klasörde, tüm servisler başka klasörde) admin panelde ekip büyüyünce merge çatışması ve sahiplik belirsizliği üretir. Dikey dilim = her feature kendi katmanlarını taşır; ekip gelince bir kişi `features/content-cms`'i sahiplenir, kimse kimsenin dosyasına dokunmaz.

**Katı Atomic Design: HAYIR.** Atom/molekül/organizma/template/page hiyerarşisi büyük tasarım-sistemi ekipleri için icat edildi; tek kişi + shadcn dünyasında iki soruna yol açar: (1) her bileşende "bu atom mu molekül mü" bürokrasisi, (2) shadcn zaten primitive katmanını veriyor — üstüne ikinci taksonomi gereksiz. Atomic'ten alınan şey ise alınır: **token → primitive → kompozit** üç seviyeli disiplin:

- Seviye 0 — `packages/design-tokens`: renk/typo/spacing (tek kaynak, mobil+web ile ortak).
- Seviye 1 — `packages/ui`: shadcn primitive'leri + DataTable, StatCard, EmptyState, ConfirmDialog gibi genelleştirilmiş bileşenler. **Kural: iş mantığı ve API çağrısı içeremez.**
- Seviye 2 — feature içi kompozitler: `features/content-cms/components/SoundscapeForm.tsx` gibi. **Kural: başka feature'dan import edilemez; iki feature aynı bileşeni isterse bileşen `packages/ui`'ye terfi eder (kopyalanmaz).**

### 1.2 Klasör Yapısı

```
apps/admin/src/
├── app/                      # route'lar: yalnızca kompozisyon + auth/rol guard
│   ├── (auth)/login/
│   └── (panel)/
│       ├── content/          # /content, /content/soundscapes/[id] ...
│       ├── users/
│       ├── analytics/
│       ├── flags/
│       └── campaigns/
├── features/                 # dikey dilimler — asıl kod burada
│   ├── content-cms/
│   │   ├── api/              # bu feature'ın query/mutation hook'ları (TanStack)
│   │   ├── components/
│   │   ├── model/            # zod şemaları, form state mantığı, mapper'lar
│   │   └── index.ts          # public API — dışarıya yalnızca buradan
│   ├── users/  ├── analytics/  ├── flags/  ├── campaigns/  └── auth/
├── entities/                 # feature'lar arası ortak domain görünümleri
│   ├── soundscape/           # tip + küçük görsel temsiller (SoundscapeBadge)
│   ├── user/
│   └── entitlement/
├── shared/
│   ├── api/                  # üretilen client (shared-types) + fetch wrapper + hata çevirisi
│   ├── lib/                  # date/i18n/permission yardımcıları
│   └── config/
└── middleware.ts             # oturum + rol ön kontrolü
```

**Bağımlılık kuralı (eslint-plugin-boundaries):** `app → features → entities → shared`. Yukarı import yasak; feature'dan feature'a import yasak.

### 1.3 Veri ve Güvenlik Desenleri

- Tüm veri erişimi NestJS `admin` modülü üzerinden (panel DB'ye asla doğrudan bağlanmaz; DB zaten yalnızca Docker iç ağında).
- TanStack Query: query key fabrikası feature başına; mutation'larda optimistic update yalnızca düşük riskli alanlarda (isim vb.), yayın/silme gibi işlemler her zaman server onayı bekler + ConfirmDialog.
- RBAC iki katmanlı: middleware route seviyesinde + her mutation API'de tekrar kontrol. UI'da yalnızca gizleme YETERSİZDİR (CLAUDE.md kuralı).
- Her tehlikeli işlem (yayından kaldırma, kullanıcı silme, entitlement override) `audit_log`'a düşer ve panelde "Audit" ekranında görünür.
- Formlar: zod şemaları `shared-types`'taki API DTO şemalarından `extend` edilir — sunucu/istemci doğrulaması asla ayrışamaz.

## 2. Fazlar

### Faz A0 — Temel (Backend B1 ile paralel, Hafta 5–7)

- Next.js iskeleti, boundary lint, `packages/ui` başlangıcı (Button, Input, DataTable, StatCard, ConfirmDialog, AppShell: sidebar+topbar+breadcrumb).
- Auth: kendi `identity` modülümüz (yalnızca davetli hesaplar, TOTP 2FA, `aud: admin` token'ları), middleware guard, rol modeli (owner/editor/analyst/support).
- Hata/boş/yükleme durum standartları: her liste ekranı EmptyState/ErrorState/Skeleton üçlüsünü kullanmak zorunda.
- **Çıkış kriteri:** rol bazlı erişimli boş panel deploy'da; Playwright ile login+guard testi yeşil.

### Faz A1 — İçerik CMS'i (Hafta 7–10) — panelin var olma sebebi

- Soundscape CRUD: i18n başlık alanları, engine_params için şema-doğrulamalı JSON editörü (jsonschema + form hibrit; ham JSON'a "advanced" sekmesinde izin), layer tanımları, archetype affinity seçici.
- **Tarayıcıda önizleme:** engine parametrelerini Web Audio API ile yaklaşık çalan mini player — editör içerik yayınlamadan duyabilmeli (mobil motorla birebir değil, "yaklaşık önizleme" etiketiyle — dürüstlük kuralı UI'a da uygulanır).
- Preset yönetimi (archetype başına default mixer state).
- Yayın akışı: draft → scheduled (publish_at) → published; weekly_releases takvim görünümü.
- **Çıkış kriteri:** editör rolü sıfırdan bir soundscape'i taslak oluşturup zamanlayıp yayınlayabiliyor; E2E testi bu akışı kapsıyor.

### Faz A2 — Kullanıcı Yönetimi + Destek (Hafta 10–12)

- Kullanıcı arama/detay: profil, archetype, entitlement, cihazlar, son oturumlar (kişisel metrik detayında maskeleme — support rolü sleep metriklerini göremez, yalnızca sayı/tarih görür).
- Destek aksiyonları: entitlement override (süreli), hesap silme talebi işleme, push token sıfırlama. Hepsi audit'li + iki adımlı onay.
- **Çıkış kriteri:** örnek destek senaryosu (iade sonrası premium kapanmamış) panelden çözülebiliyor.

### Faz A3 — Analytics Panosu (Hafta 12–15)

- Kuzey yıldızı ekranı: D1/D7/D30 retention eğrileri, kart paylaşım oranı, deneme→ücretli funnel, DAU/WAU.
- İçerik performansı: soundscape başına dinlenme/tamamlanma, archetype dağılımı.
- Kaynak: API'nin materialized view uçları (panelde hesap yapılmaz; sayı tek kaynaktan gelir — PostHog ile çelişen sayı varsa API kazanır ve fark not edilir).
- **Çıkış kriteri:** haftalık büyüme toplantısı (kendinle bile) yalnızca bu ekranla yapılabiliyor.

### Faz A4 — Flags + Kampanyalar (Hafta 15–17)

- Feature flag editörü: kural bazlı (yüzde rollout, platform, sürüm, archetype segmenti), değişiklik audit'li ve anında `flags` API'sine yansır.
- Push kampanyası: segment seç → şablon (i18n) → test cihazına gönder → zamanla; gönderim raporu (delivered/opened).
- **Çıkış kriteri:** bir flag'i %10 rollout'la açıp panelden geri kapatma tatbikatı yapıldı.

### Faz A5 — Operasyonel Olgunluk (Ay 5+)

- Kohort keşfi (basit segment builder), CSV export, haftalık otomatik e-posta özeti.
- İçerik takvimi görünümü + eksik hafta uyarısı ("önümüzdeki 2 hafta için yayın planlanmamış").

## 3. Test Stratejisi

- Unit: model/ katmanındaki mapper ve form mantığı (vitest).
- Component: kritik formlar (SoundscapeForm) testing-library ile.
- E2E (Playwright): login+RBAC, CMS yayın akışı, flag aç/kapa, destek override — her release'te koşan 4 senaryo.
- Görsel regresyon: `packages/ui` bileşenlerine Storybook + Chromatic free tier (veya Playwright screenshot diff).
