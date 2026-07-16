# DECISIONS_NEEDED — insandan karar bekleyen konular

> Loop öznel/geri-alınması pahalı kararları buraya yazar ve en makul varsayımla
> ilerler (LOOP.md). Cevap gelince ilgili yer güncellenir.

## Açık kararlar

### D-7 · Hesap veri dışa aktarma (GDPR taşınabilirlik) — kapsam kararı

- **Durum:** Hesap **silme** kaskadı var (`DELETE /v1/auth/me`, App Store zorunluluğu). **Dışa aktarma yok**
  — GDPR/KVKK taşınabilirlik hakkı karşılanmıyor. #103'te başlandı, kapsam nedeniyle bölündü.
- **Bulgular (araştırıldı, tekrar araştırmaya gerek yok):**
  - Kişisel veri taşıyan modüller: **identity** (users: email/kind/createdAt + auth_devices + refresh_tokens
    - one_time_tokens), **profile**, **archetype** (results — geçmiş ✓ #103'te eklendi), **sleep**
      (sessions), **notification** (device_tokens), **analytics** (events).
  - **Modül döngüsü kısıtı:** `sleep → profile` ve herkes `identity`'yi import ediyor. Export'u profile veya
    identity'ye koymak **döngü** yaratır → kimsenin import etmediği yeni bir **`account` modülü** gerekir.
  - **Hacim sorunu:** `analytics_events` binlerce satır olabilir → tek yanıt yerine **sayfalama/akış** gerekir.
  - **Kırpma yasağı:** #101/#102'de kapatılan sessiz sınırlarla aynı sınıf — export'ta kırpma OLAMAZ.
    Kaynak use case'lerin sınırsız olması şart (`ListSleepSessionsUseCase` 100 ile sınırlı → export için
    ayrı bir "tümü" yolu gerekir).
  - **Sırlar:** `password_hash` ve `totp_secret` export'a **ASLA** girmez.
- **Karar gereken:** hangi kapsam v1 olacak?
  1. **Kullanıcı-anlamlı veri** (hesap + profil + archetype geçmişi + uyku oturumları); analytics telemetrisi
     ve push token'ları hariç, yanıtta gerekçesiyle belirtilir. (Önerilen — çoğu uygulamanın yaptığı.)
  2. **Tam export** (analytics + token'lar dahil) — sayfalama/akış + daha büyük iş.
- **Varsayım (şimdilik):** hiçbir şey ship edilmedi; **yarım bir export'u "verileriniz" diye sunmak
  yanıltıcı olacağı için** bilinçli olarak bekletiliyor. Lansman öncesi kapatılmalı (kullanıcı yok, acil değil).

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

## D-8 · Admin panelinde i18n gerekli mi?

**Bağlam:** CLAUDE.md §4 "tüm kullanıcı metinleri baştan itibaren i18n dosyalarında
(web/admin: namespace'li JSON). Hard-code string PR'da reddedilir." Mobilde bu borcu
#109–#111'de kapattım ve `pnpm check:i18n` kapısıyla zorluyorum.

**Durum:** `apps/admin` içinde i18n altyapısı YOK; mevcut metinler hard-coded Türkçe
("Overview", "İşlem", "Aktör", "Henüz içerik yok"...). Yani kural admin'de ihlal
ediliyor — mobilde olduğu gibi, sessizce büyüyor.

**Soru:** admin İÇ yüzeydir (yalnızca personel: owner/editor/analyst/support). Kural
gerçekten burada da geçerli mi?

1. **Uygula:** admin'e de i18n kur, mevcut metinleri taşı, kapıyı admin'e genişlet.
   Kural tek; istisna açmak kuralı aşındırır. Maliyet: altyapı + refactor + her yeni
   ekranda ek iş.
2. **Muaf tut:** CLAUDE.md §4'e "admin hariç (iç yüzey, tek dil TR)" istisnası yaz.
   Maliyet: ileride admin'e yabancı bir editör/analist katılırsa geri dönüş pahalı.
3. **Ertele:** kuralı koru ama admin i18n'ini F5'e bırak, borcu defterde tut.

**Önerim: (2)** — admin tek kişilik bir ekibin iç aracı; i18n burada gerçek bir
kullanıcı ihtiyacına değil, kuralın harfine hizmet eder. Ama bu CLAUDE.md
değişikliği demektir → tek taraflı yapmadım. **Cevap gelene kadar admin'e yeni
hard-coded metin eklemeye devam edeceğim** (mevcut desen), bunu bilerek.

## D-9 · `soundscapes.layer_defs` kolonunun rolü ne?

**Bağlam:** şemada iki jsonb kolon var: `engine_params` ve `layer_defs` (ilk
migration'dan beri). Belgeler ikisini ayırıyor ama tanımlamıyor:

- docs/02 §84: `engine_params jsonb -- jeneratif motor parametreleri`, `layer_defs jsonb`
- docs/03 §68: "engine_params için şema-doğrulamalı JSON editörü ..., layer tanımları,
  archetype affinity seçici" → ayrı UI kaygıları gibi
- docs/04 §78–79: "engine_params yalnızca _tarif_", "şeması versiyonludur"

**Ne yaptım (#123):** tarifin TAMAMINI `engine_params`'a koydum:
`{ schemaVersion: 1, layers: [{id, type, gain}] }`. Gerekçe: mobil motorun tükettiği
`MixSpec` tam olarak bu (katman = {id,type,gain}); docs/04 "engine_params yalnızca
tarif" diyor; ve #122'de koyduğum yayınlama kapısı zaten `engine_params`'ı kontrol
ediyor. **Sonuç: `layer_defs` şu an KULLANILMIYOR** (boş dizi olarak yazılıyor).

**Soru:** hangisi doğru?

1. **Şimdiki gibi kalsın:** tarif tek kolonda (`engine_params`), `layer_defs` ölü.
   Sonra: `layer_defs` kolonunu migration ile KALDIR (ölü kolon yanıltıcıdır).
2. **Ayır:** `engine_params` = global motor ayarları (örnekleme hızı, master gain,
   schema_version), `layer_defs` = katman listesi. Kolon adları bunu ima ediyor.
   Bu durumda **#122'nin yayınlama kapısı yanlış kolona bakıyor** → `layer_defs`
   boşsa da ses çıkmaz; kapı oraya taşınmalı.
3. **Başka bir şey:** `layer_defs` örnek-tabanlı katmanlar (kuş sesi kaydı gibi,
   docs/04 §78'deki "küçük örnek dosyalar") için ayrılmışsa, jeneratif katmanlar
   `engine_params`'ta kalır ve `layer_defs` ileride doldurulur.

**Önerim: (3) muhtemelen asıl niyet** — docs/04 hem jeneratif hem örnek-tabanlı
kaynaktan söz ediyor. Ama emin değilim ve **uydurup şemayı kilitlemek istemedim**.
Cevap gelene kadar (1) gibi davranıyorum; (2) çıkarsa #122'nin kapısı düzeltilmeli.

## D-10 · Doğrulanmamış "hareket/ses" ayrımı kullanıcıya nasıl sunulmalı?

**Bağlam:** API oturumda iki sayı bekliyor: `movementEvents` ve `soundEvents`
(docs/02 B3, docs/04 §85 "basit olay sınıflandırması"). Gece raporu ekranı bunları
"Movement events" / "Sound events" etiketleriyle GÖSTERİYOR (#109'da i18n'e taşındı).

**Ne yaptım (#130):** ayrımı SÜREYE dayadım — kısa olay (≤20 çerçeve ≈ 1 sn) hareket,
uzun olay ses. Gerekçe: dönmek/hışırdamak kısadır; horlama/köpek/trafik uzun.
docs/04 §85'in kastettiği "basit sınıflandırma"nın en savunulabilir hâli.

**Sorun:** bu bir ÖLÇÜM DEĞİL, VARSAYIM. Gerçek gece kayıtlarıyla (docs/04 §120
fixture'ları — henüz YOK) ayarlanmadı. Yani rapor "12 hareket" derken aslında
"12 kısa akustik olay" diyor. Kullanıcı bunu "12 kez döndüm" diye okur.

**CLAUDE.md §1.1 açısından:** sağlık iddiası değil ama YANLIŞ KESİNLİK. "Relaxation
& sleep ritual" konumlandırmasıyla "kaç kez döndüğünüzü ölçüyoruz" farklı şeyler.

**Seçenekler:**

1. **Etiketleri yumuşat:** "Movement events" → "Quiet stirs" / "Kısa hareketlenmeler",
   "Sound events" → "Louder moments" / "Yüksek anlar". İddia edilen şey ölçtüğümüz
   şeye eşitlenir. Kod değişmez, yalnızca i18n metni.
2. **Tek sayı göster:** rapor "18 gece olayı" der; ayrım fixture'larla doğrulanana
   kadar UI'da gizlenir (API iki alanı almaya devam eder). En dürüst, en az bilgi.
3. **Şimdiki gibi kalsın**, fixture'lar gelince ayarlanır. En riskli: kullanıcı
   sayıya bugünden güvenmeye başlar.

**Önerim: (1)** — bugün ölçebildiğimiz şey tam olarak "kısa/uzun akustik olay";
etiketi ona eşitlemek hem dürüst hem de fixture'lar gelince (2)'ye düşmeden
iyileştirilebilir. Karar gelene kadar mevcut etiketler duruyor — bu bilinçli bir
borçtur, gece raporu ekranı henüz gerçek veriyle beslenmiyor (mikrofon yakalama yok).

---

## D-11 — 2FA sıfırlama: telefonunu kaybeden admin ne yapacak?

**Bağlam:** #135'te admin TOTP 2FA geldi (PR #136). Onaylı 2FA'nın üstüne yazmak
**bilerek** 409 döner: aksi hâlde oturumu ele geçiren saldırgan 2FA'yı kendi
cihazına taşıyabilirdi. Ama bu, madalyonun diğer yüzünü doğuruyor: **telefonunu
kaybeden admin'i şu an yalnızca DB'ye elle müdahale kurtarır.**

Bu tek kişilik bir projede gerçek bir risk: `owner` hesabı tek ve kilitlenirse
panele girilemez.

**Seçenekler:**

1. **Yedek kodlar (backup codes):** kurulumda 8-10 tek kullanımlık kod üretilir,
   kullanıcı saklar. Standart çözüm (GitHub/Google böyle yapar). Maliyeti: bir
   tablo + üretim/harcama akışı + "bir kez gösterilir" ekranı.
2. **`owner` başkasının 2FA'sını sıfırlayabilir:** ekip büyüyünce doğal çözüm, ama
   `owner`ın KENDİ kilidini açmaz — tek kişilik ekipte asıl sorunu çözmez.
3. **Parola + e-posta doğrulamasıyla sıfırlama:** magic-link altyapısı zaten var.
   Ama 2FA'nın koruduğu şeyi (parola sızıntısı) sıfırlama yolu hâline getirir —
   e-postaya erişen saldırgan 2FA'yı atlar. **2FA'yı büyük ölçüde anlamsızlaştırır.**
4. **Hiçbiri — DB erişimi tek kurtarma yolu.** Bugünkü durum. Dürüst ama kırılgan.

**Önerim: (1) + (2).** Yedek kodlar `owner`ın kendini kurtarmasını sağlar; (2) ekip
büyüdüğünde editor/analyst için pratik. (3) reddedilmeli — korumayı kendi eliyle
deler.

**Karar gelene kadar:** 2FA isteğe bağlı ve hiçbir hesapta zorunlu değil; kurulum
ekranı da henüz yok (uçlar var). Yani kimse kilitlenemez — ama 2FA de fiilen
kullanılmıyor. Zorunlu kılmadan ÖNCE bu kararın verilmesi gerekiyor.
