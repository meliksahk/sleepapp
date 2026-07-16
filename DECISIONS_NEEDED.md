# DECISIONS_NEEDED — insandan karar bekleyen konular

> Loop öznel/geri-alınması pahalı kararları buraya yazar ve en makul varsayımla
> ilerler (LOOP.md). Cevap gelince ilgili yer güncellenir.

## Açık kararlar

### D-6 · Web JS bütçesi 90KB, mevcut mimariyle ULAŞILAMAZ (yeni bulgu)

- **Durum:** CLAUDE.md §3.4 web bütçesi: **JS < 90KB (ana sayfa)**. Bu kapı hiç kurulmamıştı;
  iter #91'de ölçünce **bütçenin zaten ihlal edildiği** ortaya çıktı.
- **Ölçüm (2026-07-16, `next build`):** ana sayfa First Load JS = **103 kB**
  (kendi gzip metriğimizle ~107 kB). Dağılım:
  - React 19 runtime: **54.2 kB**
  - Next 15 App Router runtime: **46 kB**
  - **Uygulama kodu: ~1 kB** → şişkinlik bizde değil, framework tabanında.
  - `apps/web` bağımlılıkları yalnızca `next`, `react`, `react-dom` (kırpılacak paket yok).
- **Sonuç:** 90KB, Next.js App Router + React ile **erişilemez**; taban zaten 102 kB.
- **Seçenekler:**
  1. **Bütçeyi gerçeğe çek** (ör. <110KB) ve CLAUDE.md §3.4'ü güncelle — Next kalır, en ucuz.
  2. **Tanıtım sitesini hidrasyonsuz mimariye taşı** (Astro / plain SSG): 90KB kolayca tutulur,
     ama `/test` gibi interaktif parçalar yeniden yazılır + `packages/ui` paylaşımı kopar (pahalı).
  3. **Bütçeyi "JS" yerine LCP/CLS üzerinden tanımla** (asıl kullanıcı etkisi orada; 103 kB
     gzip statik sitede LCP'yi zorlamıyor).
- **Varsayım (şimdilik, loop bununla ilerledi):** Seçenek 1'e yakın davranıldı ama **CLAUDE.md
  DEĞİŞTİRİLMEDİ** (kural dosyasını sormadan değiştirmem). Bunun yerine `pnpm --filter @nocta/web size`
  ile **regresyon bekçisi** eklendi (eşik 115 kB gzip, CI'da zorlanır). Bekçi hedef değildir —
  yalnızca sessiz büyümeyi durdurur. Karar gelince eşik/CLAUDE.md birlikte güncellenir.
- **Ayrıca ertelendi:** LCP/CLS ölçümü (lighthouse-ci) — Chrome'lu CI job'u gerektirir, ayrı iterasyon.

### D-1 · Repo görünürlüğü vs. branch protection (öncelikli)

- **Durum:** GitHub free planda private repoda branch protection/ruleset API'si kapalı (BLOCKERS B-4).
- **Seçenekler:**
  1. **Private kal, disiplinle devam** (varsayılan — şu an bu): koruma platformda zorlanmaz, PR akışı elle sürdürülür. Maliyet 0.
  2. **Repoyu public yap:** branch protection ücretsiz açılır; ama kod herkese açık olur (erişim-kontrolü kararı — sormadan yapılmaz).
  3. **GitHub Pro:** ~4$/ay; kickoff "ücretli servis açma" kuralına takılır.
- **Varsayım (şimdilik):** Seçenek 1. Değiştirmek istersen söyle.

### D-2 · Sentry DSN

- **Durum:** API'de Sentry env-opsiyonel bırakıldı (`SENTRY_DSN` boşsa devre dışı). Kod entegrasyonu F1'de eklenecek.
- **Gerekli:** dört proje (mobile/api/admin/web) için Sentry DSN'leri (free tier). Verince `.env`/GitHub Environments'a konur (repoya değil).

### D-3 · VPS kimlik bilgileri (docs/09 Adım 2 & 5)

- **Durum:** "Önce lokal" kararıyla ertelendi.
- **Gerekli (sıra gelince):** Hostinger VPS IP + SSH kullanıcısı (+ staging subdomain, opsiyonel). Koda/repoya ASLA yazılmaz; SSH key-only erişim, ufw, fail2ban, docker, compose stack, GitHub Actions SSH deploy kurulacak.

### D-5 · SMTP sağlayıcı (magic link e-posta gönderimi)

- **Durum:** Magic link e-posta yükseltme kodu tamam; şu an **log-mailer** (linki loglar, gerçek e-posta göndermez). Gerçek gönderim için SMTP sağlayıcı gerekiyor (self-host mail deliverability nedeniyle yasak, docs/02 §3).
- **Gerekli:** Brevo veya Resend free tier API anahtarı → `shared/infra/mailer` adaptörü tek satırla gerçek sağlayıcıya geçer.
- **Varsayım (şimdilik):** log-mailer ile devam; dev/test raw token'ı response'ta döner (prod'da gizli).

### D-4 · Ürün/ton kararları (düşük öncelik, varsayımla ilerleniyor)

- Marka adı **NOCTA** çalışma kod adı (docs/06) — netleşince token/isim tek yerden değişir.
- Archetype slug'ları (deep-ocean/overthinker/delta-drifter/dawn-chaser) taslak.
- Fiyatlandırma/paywall: F6'ya (docs/10) ertelendi.
