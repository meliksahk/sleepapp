# 05 — Tanıtım Sitesi: SEO + GEO Mimari ve Faz Planı

## 1. Rolü

Site üç iş yapar: (1) ön-lansman viral aracı (web archetype testi), (2) organik edinim motoru (Google SEO + programatik long-tail), (3) **GEO** — ChatGPT/Claude/Perplexity/Google AI Overviews gibi yapay zeka aramalarında alıntılanan kaynak olmak. Uygulama mağaza sayfası değil, kendi başına trafik varlığıdır.

## 2. Mimari

- Next.js App Router, %100 SSG (`output: export` uyumlu tutulur; OG image ve test skorlama gibi dinamik uçlar kendi API'mizin public uçlarına gider) → Cloudflare Pages/Vercel free tier, global CDN.
- İçerik: MDX dosya tabanlı (`content/blog`, `content/sounds`, `content/archetypes`), frontmatter şemasi zod ile CI'da doğrulanır. CMS yok — içerik PR'la girer (Claude ile içerik üretim akışına da en uygun yol).
- `packages/ui` + `design-tokens` kullanır; app ile aynı görsel dil (dönüşüm güveni).
- Sayfa tipleri:
  - `/` ana sayfa, `/download`
  - `/test` — web archetype testi (client-side, skorlama API'nin public `POST /v1/archetype/web` ucu; sonuç: `/a/{archetype}` + kişisel kart)
  - `/a/{archetype}` — 8–12 archetype sayfası (indekslenebilir, zengin içerik: "3AM Overthinker nedir, hangi sesler iyi gelir")
  - `/sounds/{slug}` — programatik ses sayfaları (aşağıda)
  - `/r/{slug}` — paylaşılan gece raporu (noindex, OG'li)
  - `/blog/{slug}`, `/science` (dürüst kanıt sayfası), `/press`, `/privacy`, `/terms`

## 3. SEO Stratejisi

### 3.1 Teknik temel (Faz W0'da bitmek zorunda)

- CWV bütçesi: LCP < 2.0s, CLS < 0.05, INP < 200ms; ana sayfa JS < 90KB. lighthouse-ci CI eşiği.
- Otomatik sitemap + RSS; canonical'lar; `hreflang` (EN birincil, TR ikincil).
- Schema.org JSON-LD: `SoftwareApplication` (+AggregateRating hazır olunca), `FAQPage`, `Article`, `HowTo`, `BreadcrumbList`. Şemalar tek util'den üretilir, elle JSON yazılmaz.
- OG image'ler build'de satori ile sayfa başına otomatik.

### 3.2 İçerik stratejisi — "sleep sounds"u KAZANMAYA ÇALIŞMA

Ana kelimeler (sleep sounds, white noise app) kazanılamaz — Calm/BetterSleep domain otoritesi. Giriş long-tail'den:

- **Programatik ses sayfaları:** `sounds/brown-noise-for-adhd`, `sounds/rain-on-tent`, `sounds/8d-sleep-audio`, `sounds/train-sounds-for-sleeping`... Her sayfa: 30 sn web önizleme (Web Audio, motorun web portu — düşük kalite versiyonu yeter), "bu ses kime iyi gelir", ilgili archetype bağlantısı, app CTA. Şablon + veri dosyası = 50–100 sayfa. **Kalite kuralı: her sayfada en az 300 kelime özgün, insan-değerli metin; şablon-spam Google'da 2024 sonrası ceza sebebi.**
- **Archetype sayfaları:** kimlik testinin paylaşım trafiğini indekslenebilir içeriğe çevirir (paylaşılan kart → siteye gelen arkadaş → testi çözer → döngü).
- **Blog:** haftada 1, tek tema: uyku ritüelleri/ses bilimi; her yazı bir long-tail soruyu hedefler ("why does brown noise help adhd", "how to fall asleep with tinnitus" — _dikkat: tedavi iddiasız, deneyim/ritüel dili_).

### 3.3 Otorite

- Dijital PR: archetype testinin veri hikâyeleri ("test çözenlerin %38'i 3AM Overthinker çıktı") — gazeteci/newsletter'ların alıntılayacağı istatistikler üret. Backlink stratejisinin tamamı budur; link satın alma yok.
- Google Search Console + Bing Webmaster (Bing → ChatGPT arama altyapısı, GEO için kritik) ilk günden kurulur.

## 4. GEO (Generative Engine Optimization) Stratejisi

AI aramalarında alıntılanmanın bilinen mekanikleri üzerine kurulu, ölçüm döngülü plan:

1. **Alıntılanabilir birimler:** her önemli sayfada kısa, kendi başına anlamlı, kaynaklı cevap blokları ("Brown noise, white noise'dan farklı olarak düşük frekanslarda daha fazla enerji taşır...") — AI motorları paragraf-cümle düzeyinde alıntılar; duvar metin alıntılanmaz.
2. **Yapı:** soru başlıklı H2/H3'ler + ilk cümlede doğrudan cevap + ardından detay; her sayfada FAQ bloğu (+`FAQPage` şeması); tanım listeleri, karşılaştırma tabloları (AI'ların en çok çektiği formatlar).
3. **`llms.txt`:** site haritasının AI-dostu özeti; ayrıca temiz semantik HTML (client-side render edilen içerik GEO'da görünmezdir — bizde SSG olduğu için doğal avantaj).
4. **Varlık tutarlılığı:** uygulama adı + kategori tanımı ("X, a sleep ritual app") her yerde aynı formülle geçer; Crunchbase/ProductHunt/App Store/Wikipedia-adjacent kayıtlar tutarlı (AI'lar varlık çözümlemesini bu tutarlılıktan yapar).
5. **İstatistik mıknatısı:** kendi anonim-agregat verinden yıllık "Sleep Identity Report" yayınla — AI cevaplarında "according to..." ile alıntılanan kaynak olmanın en kısa yolu özgün veridir.
6. **Ölçüm:** ChatGPT/Perplexity/Claude'da 20 hedef soruluk test seti ("best brown noise app for adhd" vb.) ayda bir elle koşulur, alıntılanma tablosu tutulur; referrer analitiğinde `chatgpt.com`, `perplexity.ai` segmentleri izlenir.
7. **Dürüstlük sınırı:** GEO taktikleri hızla değişen, kanıtı zayıf bir alan — yukarıdakiler 2025–26 itibarıyla en makul bilinen pratiklerdir, garanti değildir; ölçüm döngüsü bu yüzden planın parçasıdır.

## 5. Fazlar

### Faz W0 — Viral Test + Teknik Temel (Hafta 1–2, HER ŞEYDEN ÖNCE)

- Tek sayfa + `/test` + 8 archetype sonuç sayfası + bekleme listesi (e-posta → API → Postgres).
- Paylaşım kartı (canvas), OG'ler, analytics (paylaşım oranı = ana metrik), CWV bütçesi, GSC+Bing kaydı.
- TikTok/Reels itmesi için UTM'li kısa linkler.
- **Çıkış kriteri:** test yayında; paylaşım oranı ölçülüyor. Karar kapısı: sonuç sayfasından paylaşıma dönüşüm < %8 ise archetype konsepti uygulamaya gömülmeden revize edilir.

### Faz W1 — Lansman Sitesi (Hafta 5–8)

- Ana sayfa (ürün hikâyesi: "Find your sleep identity" karşılığı özgün konumlandırma), `/download`, `/science` (kanıt durumu dürüst anlatım — bu sayfa güven + GEO varlığıdır), privacy/terms (mikrofon politikası açık).
- Blog altyapısı + ilk 4 yazı; `llms.txt`; schema util'leri.
- **Çıkış kriteri:** lighthouse-ci eşikleri yeşil; ilk organik gösterimler GSC'de.

### Faz W2 — Programatik Katman (Hafta 9–14)

- `/sounds/*` şablonu + veri dosyası + web önizleme player'ı; ilk 30 sayfa (öncelik: arama hacmi × rekabet matrisi ile seçilmiş long-tail'ler).
- Archetype sayfalarının zenginleştirilmesi; iç link ağı (sound ↔ archetype ↔ blog).
- **Çıkış kriteri:** 30 sayfa indekslendi; en az 3 sayfa ilk 3 ay içinde ilk 20'de.

### Faz W3 — GEO Derinleşme + Rapor paylaşımları (Hafta 14+)

- `/r/{slug}` gece raporu sayfaları (noindex ama OG mükemmel — sosyal trafik kapısı).
- FAQ blokları sitewide; AI alıntılanma test seti ilk koşum; veri hikâyesi #1 yayını.
- **Çıkış kriteri:** aylık GEO tablosu tutuluyor; en az 1 AI motorunda marka alıntısı gözlendi.

### Faz W4 — Ölçek (Ay 4+)

- Sound sayfaları 100'e; TR yerelleştirme; yıllık Sleep Identity Report; dijital PR döngüsü.

## 6. Test/Kalite

- lighthouse-ci her PR'da; link checker (kırık iç link CI'da fail); frontmatter zod doğrulaması; schema.org validator testi; Playwright ile test akışı + paylaşım kartı smoke.
