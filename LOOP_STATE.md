# LOOP_STATE — NOCTA geliştirme döngüsü defteri

## 🚧 İlerleme: ≈76% — F1–F5 (otonom kapsam)

```
[██████████████████████████████░░░░░░░░░░] 76%
```

| Yüzey       | İlerleme | Ağırlık | Kalan çekirdek işler                                                   |
| ----------- | -------- | ------- | ---------------------------------------------------------------------- |
| Backend/API | ~97%     | 0.30    | F5 sertleşme (Redis), admin API, veri export (D-7), billing (F6)       |
| Mobil       | ~61%     | 0.40    | **ses motoru: native graf + mikser**, mic takibi + alarm, mix-to-video |
| Admin       | ~92%     | 0.15    | auth/RBAC, içerik CMS'i, metrik panoları, kampanya/flag UI             |
| Web         | ~45%     | 0.15    | LCP/CLS (lighthouse-ci), hreflang, programatik long-tail, blog         |

> **Tahmindir** (Dürüstlük Protokolü — kesin ölçüm değil): yüzey-başına kaba tamamlanma
> yüzdelerinin ağırlıklı ortalaması = 0.30·97 + 0.40·61 + 0.15·92 + 0.15·45 ≈ **76%**.
>
> **Düzeltme (#111):** önceki iki değer yanlıştı — tablo mobili %39 yazarken formül 48
> kullanıyordu (tablo güncellenmemiş), ve 48 ile sonuç 51.45'tir, yazılan 53 değil. Bar
> gerçekte olduğundan ~2 puan iyimserdi. İkisi de düzeltildi.
> F6 (ödeme + lansman) insan-kapılı olduğundan otonom kapsamın dışında. Bar her
> iterasyonda LOOP.md "İlerleme göstergesi" kuralına göre yeniden hesaplanır.

---

> İnsanın loop'u denetlediği tek ekran. Her iterasyonda güncellenir (LOOP.md §6).
> Kanıt olmadan ✅ yazılmaz (Dürüstlük Protokolü).

**Aktif faz:** F1 (Temel) — F0 kickoff kapandı.
**Repo:** https://github.com/meliksahk/sleepapp (private)
**Son güncelleme:** 2026-07-16

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

1. **Mobil devam (%61, ağırlık 0.40 — en yüksek):** cihazsız kalan işler: (a) **uyku modu ekranı iskeleti** — zincir hazır ama onu çağıran UI yok; mikrofon yakalama olmadan da "başlat/bitir + süre" akışı kurulabilir (sahte besleme ile testlenir). (b) mix-to-video offline render yolu (renderMix hazır).
   **Zincir durumu:** DSP ✓ #96-98 · tarif ayrıştırıcı ✓ #127 · olay tespiti ✓ #128 · alarm ✓ #129 · oturum taslağı ✓ #130 · API'ye bağlandı + uçtan uca test ✓ #131.
   **Eksik halkalar İNSAN-KAPILI:** mikrofon yakalama (platform izni) ve native ses grafiği (kulaklıkla doğrulama, CLAUDE.md §1.1).
2. **İnsan-kapılı (otonom YAPILAMAZ):** native ses grafiği + gerçek cihaz doğrulaması (CLAUDE.md §1.1 kulaklıkla), mikrofon yakalama (platform izni), olay sınıflandırma eşiklerinin gerçek gece kayıtlarıyla ayarlanması (docs/04 §120 fixture'ları).
3. **A1/A3 artıkları:** D7 + paylaşım oranı hesabı (analitik olaylar var), audit_log, zamanlanmış yayın, sayfalama.
4. **admin A0 artıkları (ertelendi, engelleyici değil):** TOTP 2FA, davet akışı + parola sıfırlama, hesap-başına kilitleme. Rol kapısı ✓ #112, audience ✓ #113, parola girişi ✓ #114, giriş limiti ✓ #115, panel girişi + vitest ✓ #116, yenileme + çıkış ✓ #117, yarış toleransı ✓ #118.
5. ~~`.env.example` oluştur~~ — **bu madde yanlış bir bulguya dayanıyordu** (dosya
   zaten vardı); gerçek sorun bayatlıktı, #132'de düzeltildi + kapı eklendi.
6. **web SEO devam:** CWV lighthouse-ci CI eşiği + hreflang (EN/TR). sitemap/robots/llms.txt ✓ iter #17, OG image ✓ iter #24.
7. **API sertleşme (B4 erken):** content feed cache (Redis 5dk TTL), rate-limit'i Redis storage'a taşı, request boyut limitleri.
8. **notification modülü iskeleti** (docs/02 B3): token kaydı + BullMQ fan-out log-adaptörü (gerçek APNs/FCM → docs/10).

> B1 backend modülleri TAMAM: identity(v1+v2+silme), profile, archetype(+web), flags, content(+MinIO). API 15 endpoint.

## İterasyon geçmişi

### #134 — panel denetim izi: kim ne yaptı (PR #135, merged)

✅ **Yapıldı ve doğrulandı**

- `admin_audit_log` + BEŞ yazma işleminde iz + `GET /v1/admin/audit` + panoda
  "Son etkinlik" CANLI. İçerik yayınlanıyor/geri çekiliyor/tarifi değişiyordu ama
  **kimin yaptığının izi YOKTU** — ve bu sonradan eklenemez, GEÇMİŞ GERİ GELMEZ.
- **Migration** (additive, PR+CI üzerinden): down/up TERSİNİRLİĞİ doğrulandı,
  `db/schema.sql` + `prisma db pull` senkron. CI sıfırdan temiz DB'ye uyguladı ✓.
- **GERÇEK SUNUCUDA:** create → publish(**409, iz YOK**) → recipe → publish(200) →
  iz: publish / recipe {layers:1} / create {title}. Kanıt silindi.
- API **380 test** (370→380), admin **78 test** (76→78), turbo 19/19.

📌 **Varsayımlar / kararlar**

- **FK ON DELETE SET NULL, CASCADE DEĞİL** + `actor_email` DONDURULUR: hesap silinince
  geçmiş eylemleri kaybolmamalı — denetim izinin bütün anlamı bu (e2e doğruladı).
- **İz YALNIZCA BAŞARIDA:** reddedilen denemeyi "yayınladı" diye yazmak izi
  YALANDAN BETER yapardı. Yetkisiz işlem de yazılmaz.
- **`record()` ASLA ATMAZ** ama SESSİZ de kalmaz (logger.error) — iz yazılamadı diye
  editörün işi başarısız olmamalı; boş catch de yasak.
- **Detaylarda NE değişti, DEĞERLER değil** (`{changed:['title']}` — başlık izde yok).
- Eylemler sabit birlik tipi (yazım hatası izi sessizce kaybederdi). Pano 20 kayıt:
  akış özeti, arşiv değil.
- #126'da SAHTE diye kaldırdığım "Son etkinlik" tablosu geri geldi — gerçek veriyle.

🔥 **Riskler / açıklar**

- Tam denetim geçmişi (filtreli/sayfalı uç) yok — pano yalnızca son 20.
- D7 retention (kohort, A3) ve deneme→ücretli (F6) hâlâ yok; panoda açıkça yazılı.

❌ **Yapılmadı**

- D7 retention, zamanlanmış yayın, içerik sayfalama, TOTP 2FA, davet akışı.

### #133 — paylaşım hunisi: viral kancanın sağlığı (PR #134, merged)

✅ **Yapıldı ve doğrulandı**

- `GET /v1/admin/overview` paylaşım hunisini döndürüyor; panoda "Kart paylaşım
  oranı" CANLI. CLAUDE.md §1.1 "viral kancalar ÇEKİRDEK özellik" diyor ama ölçülmüyordu
  (olaylar #90'dan beri toplanıyordu, hesap yoktu).
- **GERÇEK SUNUCUDA:** olay yokken `{completed:0, shared:0, rate:null}` → 3 kullanıcı
  (biri **5 KEZ** paylaştı) → `{completed:3, shared:1, rate:0.333}`. Kanıt silindi.
- API **370 test** (360→370), admin **76 test** (71→76), turbo 19/19.

📌 **Varsayımlar / kararlar**

- **BENZERSİZ KULLANICI, olay DEĞİL:** tek kullanıcı 5 kez paylaşırsa huni "%500"
  gösterirdi. Soru "kaç KİŞİ paylaştı?"dır. Canlı doğrulandı.
- **`rate` null olabilir, 0 DEĞİL:** kimse test yapmadıysa oran TANIMSIZDIR; "%0"
  demek "kimse paylaşmıyor" demektir ve insan ona bakıp "kanca çalışmıyor" der.
  Sıfıra bölme dalı **e2e'de test EDİLEMEZ** (paylaşılan DB'de completed asla 0
  olmaz) → birim testte sabitlendi.
- **Oran DOMAIN'de, SQL'de değil:** sıfıra bölme bir ÜRÜN kararı.
- Ham sayılar da dönüyor (1/1 de "%100" görünür → panel "1/1 kişi" yazıyor).
- Sayım DB'de (groupBy user_id); oran yuvarlanmaz (sunum panelin işi).

🔥 **Riskler / açıklar**

- D7 retention kohort analizi ister (A3); deneme→ücretli billing'e bağlı (F6);
  son etkinlik için audit_log gerekli — üçü de panoda AÇIKÇA yazılı.

❌ **Yapılmadı**

- D7 retention, audit_log, zamanlanmış yayın, sayfalama, TOTP 2FA, davet akışı.

### #132 — `.env.example` bayatlığı + sürüklenme kapısı (PR #133, merged)

> **Bar değişmedi (%73):** bu bir hata düzeltmesi + kapı, yeni ürün yeteneği değil.

✅ **Yapıldı ve doğrulandı**

- **🔴 KENDİ YANLIŞ BULGUMU DÜZELTTİM:** #115'te "`.env.example` depoda YOK" yazmıştım
  ve **üç raporda tekrarladım — YANLIŞTI**. Dosya var ve commit'li; aramam hatalıydı.
- **Gerçek sorun ÖLÇÜLDÜ:** dosya BAYATTI — şemadaki **23 değişkenin 11'i eksikti**
  (MAGIC_LINK__, WEB_BASE_URL, APP_DEEPLINK_SCHEME, MAX_REQUEST_BODY_BYTES,
  THROTTLE__, ADMIN_LOGIN_LIMIT, REFRESH_REUSE_GRACE_MS, MINIO_REGION,
  MINIO_BUCKET_SOUNDSCAPES). Yani son ~10 iterasyonda eklediğim her env eksikti.
- **Kanıt (önce kırmızı):** kapı yazıldı → exit=1, 11 eksiği tam isabetle listeledi.
  Dosya düzeltildi → ✓ 23 senkron. Kapı yorumlanmış satırı da yakalıyor
  (`# ADMIN_LOGIN_LIMIT=5` belgelemez, kandırır → exit=1).
- `pnpm check:env-example` CI'a bağlandı. turbo 19/19.

📌 **Varsayımlar / kararlar**

- **ÜRETMEK YERİNE KAPI:** `.env.example` yalnızca API'yi değil admin/web
  değişkenlerini ve "neden böyle" yorumlarını da taşıyor; şemadan üretmek o bilgiyi
  silerdi. Kapı, insanın yazdığı dosyanın şemayla ÇELİŞMEDİĞİNİ garanti eder.
- Ayrıştırma tam TS parser DEĞİL (şema düz nesne literali ve öyle kalmalı); şekil
  değişirse kapı **ÇÖKER** — sessizce boş küme dönüp işlevsiz kalmaz.

🔥 **Riskler / açıklar**

- **Ders:** bir bulguyu doğrulamadan deftere yazdım ve üç kez tekrarladım. "Aramam
  bir şey bulamadı" ≠ "yok".
- **Bu iterasyonda mobil ekranı YAPMADIM, bilerek:** uyku modu ekranı mikrofon
  yakalama olmadan "dinliyorum" der ama hep 0 olay kaydeder — sahte özellik olurdu.
  Mobilin kalan çekirdek işi insan-kapılı (mikrofon izni, kulaklıkla ses doğrulaması);
  LOOP.md "bir yüzey blokeyse diğerine geç" diyor.

❌ **Yapılmadı**

- Uyku modu ekranı (mikrofon gelmeden dürüst değil), mikrofon yakalama, native ses
  grafiği, mix-to-video.

### #131 — tek serileştirme kaynağı + uçtan uca zincir testi (PR #132, merged)

✅ **Yapıldı ve doğrulandı**

- `recordSession` artık `SleepSessionDraft` alıyor; gövdeyi taslak üretiyor.
- **Uçtan uca test:** sentetik mikrofon PCM → dB zarfı → olay tespiti → taslak →
  HTTP gövdesi. Parçalar tek tek testliydi ama **birleşince hiç koşmamıştı**.
- flutter analyze temiz; **238 test** (235→238). turbo 19/19.

🔥 **Riskler / açıklar — KENDİ HATALARIM**

- **🔴 BİR İTERASYON ÖNCE ÜRETTİĞİM HATA:** #130'da `toJson()` eklerken
  `recordSession`'ın AYNI dört alanı zaten serileştirdiğini kontrol etmedim → iki
  doğruluk kaynağı. **Her PR'da uyardığım hatanın ta kendisi.** Somut riski: UTC
  kuralı (CLAUDE.md §4) yalnızca birinde düzeltilseydi "gece" gruplaması (06:00)
  SESSİZCE kayardı. Tek kaynağa indirildi.
- **İkinci bulgu:** `recordSession`'ın `lib/` içinde HİÇ ÇAĞIRANI YOKTU — #128-#130
  zinciri API katmanıyla hiç buluşmamıştı.
- **Testin yakaladığı üçüncü hatam:** sahte API yanıtımda alanlar eksikti ("Null is
  not int"). Sahte yanıt gerçeğe uymazsa test gerçeği değil kurgumu doğrular.
- Mikrofon YAKALAMA yok → zincir sentetik beslemeyle koşuyor. Uyku modu ekranı yok.

❌ **Yapılmadı**

- Mikrofon yakalama (platform, insan-kapılı), uyku modu ekranı, native ses grafiği
  (insan-kapılı), mix-to-video.

### #130 — uyku oturumu birleştirici + olay sınıflandırma (PR #131, merged)

✅ **Yapıldı ve doğrulandı**

- Dedektör olayları + oturum zamanı → API'nin beklediği `RecordSleepSessionDto`
  taslağı. #128 olayları buluyordu ama API'nin istediği iki sayıya çevrilemiyordu.
- flutter analyze temiz; **235 test** (222→235, +13). turbo 19/19.

📌 **Varsayımlar / kararlar**

- **AYRIM DOĞRULANMADI ve SAKLANMIYOR:** süre-tabanlı (kısa=hareket, uzun=ses)
  docs/04 §85'in "basit sınıflandırma"sının en savunulabilir hâli — ama bir ÖLÇÜM
  DEĞİL, VARSAYIM. Testler DAVRANIŞI sabitliyor, DOĞRULUĞU değil (dosyada+testte yazılı).
- **UTC + ISO 8601 zorunlu** (CLAUDE.md §4): yerel saatle göndermek sunucudaki "gece"
  gruplamasını (06:00 sınırı) SESSİZCE kaydırırdı → kullanıcı gecesini yanlış günde
  görürdü. Testle sabit.
- **HAM VERİ SIZMAZ:** gövdede yalnızca 4 alan (2 zaman + 2 sayı); zarf/dB/olay
  detayı gitmez — CLAUDE.md §6'nın somut hâli, testle sabit.
- Eşik ayarlanabilir: fixture'lar gelince değişecek TEK şey o olsun.

🔥 **Riskler / açıklar**

- **📌 D-10 AÇILDI:** rapor "12 hareket" derken aslında "12 kısa akustik olay" diyor;
  kullanıcı "12 kez döndüm" diye okur. Sağlık iddiası değil ama **YANLIŞ KESİNLİK**.
  **Önerim:** etiketleri ölçtüğümüz şeye eşitle ("Kısa hareketlenmeler"/"Yüksek anlar")
  — yalnızca i18n metni değişir. Karar gelene kadar mevcut etiketler duruyor
  (bilinçli borç; gece raporu henüz gerçek veriyle beslenmiyor).
- Mikrofon yakalama, uyku modu ekranı, oturumu API'ye GÖNDERME yok.

❌ **Yapılmadı**

- Mikrofon yakalama (platform), uyku modu ekranı, oturum gönderme, native ses grafiği
  (insan-kapılı), mix-to-video.

### #129 — akıllı alarm penceresi + aktivite köprüsü (PR #130, merged)

✅ **Yapıldı ve doğrulandı**

- `SmartAlarm` (docs/04 §86) + `hasRecentActivity` köprüsü (dedektörün ÇERÇEVE
  birimini alarmın DUVAR SAATİne çevirir). Mobilde alarm adına hiç kod yoktu.
- docs/04 §120 zaten "alarm penceresi mantığı unit+integration testli" diyor →
  cihazsız yapılabilir kısım tam da bu.
- flutter analyze temiz; **222 test** (200→222, +22). turbo 19/19.

📌 **Varsayımlar / kararlar**

- **EN KRİTİK — SON TARİH PAZARLIKSIZ:** hafif uyku sinyali HİÇ görülmese de pencere
  sonunda çalar. "Akıllı" kısım bir OPTİMİZASYON; alarm bir SÖZ. Sinyal beklerken
  sessiz kalmak = kullanıcının işe geç kalması. Testlerin ağırlığı orada (son tarih
  geçtiyse de çalar — tick kaçarsa kaybolmasın; sıfır pencere kilitlenmez).
- **SAF MANTIK, YAN ETKİSİZ:** bildirim/ses/zamanlayıcı yok — alarmın doğruluğu
  saniyesi saniyesine test edilebilmeli.
- BİR KEZ çalar (yoksa her tick'te bildirim). Pencere öncesi aktivite olsa bile çalmaz.
- Köprü AYRI dosyada: dedektör çerçeveyle, alarm saatle çalışır; çeviriyi birine
  gömmek onu diğerinin zaman kavramına bağlardı.
- Süregelen olay sayılır (horlama hâlâ sürüyorsa "şu an ses var").

🔥 **Riskler / açıklar**

- **SEZGİSEL (dürüstlük):** "son N dk akustik aktivite = hafif uyku" varsayımı
  polisomnografiyle DOĞRULANMADI. İddia "hareketlendiğinde uyandırırız" ile sınırlı
  kalmalı — "REM'i biliriz" DEĞİL (CLAUDE.md §1.1 ürün metnine de bakar).
- Bildirim, "sunrise" ses rampası, zamanlayıcı, uyku modu ekranı YOK (platform işi).
- iOS kısıtı duruyor: uyku modu = şarjda + uygulama açık (docs/04 §86 ürün kararı).

❌ **Yapılmadı**

- Bildirim/zamanlayıcı, uyku modu ekranı, olay sınıflandırma, mikrofon yakalama,
  native ses grafiği (insan-kapılı), mix-to-video.

### #128 — on-device dB zarfı + akustik olay tespiti (PR #129, merged)

✅ **Yapıldı ve doğrulandı**

- **🔴 GERÇEK BOŞLUK:** API `movementEvents`/`soundEvents` bekliyor (#44) ve CLAUDE.md
  §6 "yalnızca türetilmiş metrikler" diyor — ama **mobilde takip adına HİÇBİR ŞEY
  yoktu**. `core/sleep_tracking/`: dB zarfı + uyarlanabilir tabanlı olay tespiti.
- **UYDURULMADI:** docs/04 §85 birebir tarif ediyor ("dB zarfı + basit olay
  sınıflandırması; ham ses diske bile yazılmaz"); §120 çıkış kriteri zaten SİMÜLE
  beslemeyle testi şart koşuyor → cihazsız yapılabilir kısım tam da bu.
- flutter analyze temiz; **200 test** (182→200, +18). turbo 19/19.

📌 **Varsayımlar / kararlar**

- **ASIL KARAR — UYARLANABİLİR TABAN:** sabit eşik gerçek gecede çöker. Fan açılınca
  taban -55→-35 çıkar ve sabit eşik YÜZLERCE olay üretir → rapor "312 hareket" der,
  kullanıcı uygulamayı siler. Test: 1000 çerçevelik fan → **≤1 olay**.
- **TESTİN YAKALADIĞI KENDİ TASARIM KUSURUM:** tabanı olay boyunca dondurdum (uzun
  horlama bölünmesin diye) ama SONSUZA KADAR dondurunca fan bitmeyen tek olay oldu ve
  taban hiç uyum sağlamadı. Ayrım eksikti: **kısa aşım OLAY, sürekli aşım SEVİYE
  KAYMASI** → `maxEventFrames` eklendi, taban yeni seviyeye sıçratılıyor.
- dB (ham genlik değil): işitme logaritmik. Mutlak dB SPL YOK: cihaz hassasiyeti değişir.
- Sessizlik -inf değil sonlu taban (-inf aritmetiği zehirlerdi). Refrakter: tek dönme
  3-4 kez sayılmasın. `finish()`: gecenin son sesi kaybolmasın.
- **Birim ÇERÇEVE, saniye değil** — varsayılanlar ~50ms/çerçeve varsayar, dosyada yazılı.
- **GİZLİLİK:** çıktı yalnızca SAYI; zarftan konuşma yeniden kurulamaz.

🔥 **Riskler / açıklar**

- **SINIFLANDIRMA YOK** (hareket/horlama/gürültü): mikrofonla ayırmak süre/periyodiklik
  analizi ister ve GERÇEK VERİYLE doğrulanmalı. Uydurmak = sayıyı yanlış etiketleyip
  güvenilir gibi sunmak. **API'nin `movementEvents`/`soundEvents` alanları bu yüzden
  HÂLÂ doldurulamıyor.**
- **EŞİKLER AYARLANMADI:** makul başlangıç değerleri; docs/04 §120 fixture'ları yok.
- Mikrofon YAKALAMA yok (platform işi), uyku modu ekranı yok, alarm yok.

❌ **Yapılmadı**

- Olay sınıflandırma, mikrofon yakalama, uyku modu ekranı, akıllı alarm, native ses
  grafiği (insan-kapılı), mix-to-video.

### #127 — mobil `engine_params` → MixSpec ayrıştırıcısı (PR #128, merged)

✅ **Yapıldı ve doğrulandı**

- **🔴 GERÇEK BOŞLUK KAPANDI:** sunucuda tarif zinciri kuruldu (#123–#125) ama **mobil
  `engineParams`'ı TAMAMEN DÜŞÜRÜYORDU** ("motor gelince eklenecek" yorumu). Admin'de
  yazılan tarif istemcinin modeline hiç ulaşmıyordu. Artık ulaşıyor + doğrulanıyor.
- flutter analyze temiz; **182 test** (159→182, +23). turbo 19/19.

📌 **Varsayımlar / kararlar**

- **NEDEN NATIVE MOTOR DEĞİL (dürüstlük):** defterde sıradaki iş oydu; ama CLAUDE.md
  §1.1 "ses değişiklikleri GERÇEK CİHAZDA KULAKLIKLA doğrulanır" diyor. **Duyamadığım
  ses kodunu ship etmek** hem o ilkeyi hem Dürüstlük Protokolü'nü ihlal ederdi.
  Motorun ihtiyaç duyacağı, CİHAZSIZ doğrulanabilir halkayı yaptım.
- **ÇÖKME YOK, zarifçe null** (docs/04 §79 açıkça istiyor): uygulama mağazada yıllarca
  yaşar, bir gün v2 tarif görebilir → atmak kütüphaneyi çökertirdi.
- **TOLERANS YOK:** kısmen geçerli tarif sessizce YANLIŞ ses üretir — duyulmayan hata,
  duyulan hatadan beterdir. Bilinmeyen kaynak türü "yaklaşık"la değiştirilmez.
- **Bozuk tarif KAYDI DÜŞÜRMEZ** (yalnızca mixSpec null) — yoksa kütüphane sessizce boşalırdı.
- `gain` `num` kabul: JSON'da 1 ile 1.0 aynı; `is double` yazsam gain:1 sessizce reddedilirdi.

🔥 **Riskler / açıklar**

- **`mixSpec`'in RUNTIME TÜKETİCİSİ YOK — ses hâlâ ÇALMIYOR.** Değeri: sözleşme
  istemcide doğrulanıyor, parser cihazsız test edilebiliyor. Motor geldiğinde tüketecek.
- `isPlayable` alanı eklemiştim, kullanan olmadığı için KALDIRDIM (spekülatif API).
- **Native graf İNSAN-KAPILI:** gerçek cihaz + kulaklık ister. Otonom yapılamaz.

❌ **Yapılmadı**

- Native ses grafiği (AVAudioEngine/Oboe) + `AudioEngineFacade`, mic takibi + alarm,
  mix-to-video. D7/paylaşım oranı, audit_log, zamanlanmış yayın, sayfalama.

### #126 — canlı pano: gerçek rakamlar, dürüst boşluklar (PR #127, merged)

✅ **Yapıldı ve doğrulandı**

- `GET /v1/admin/overview` + panelin ANA EKRANI canlı rakam gösteriyor
  (yayında/taslak/planlı + bekleme listesi). Dört sahte "—" gitti.
- **GERÇEK SUNUCUDA:** API `{"soundscapes":{"draft":1,"scheduled":0,"published":1},
"waitlist":1}` · panel 200 ve görünür metinde "Yayında 1", "Taslak 1",
  "Bekleme listesi 1", "2 kayıt · 0 planlı"; **sahte tablo yok** (`<table>` yok).
- API **360 test** (352→360), admin 71 test, turbo 19/19.

📌 **Varsayımlar / kararlar**

- **DÜRÜSTLÜK ASIL KARAR:** yalnızca bugün DOĞRU hesaplanabilenler eklendi. D7
  retention (kohort analizi) ve deneme→ücretli (billing yok) için **sahte sayı
  üretmedim** — yanlış metrik, olmayan metrikten kötüdür; insan ona güvenip karar
  verir. Panelde ne olmadığı ve NEDEN olmadığı yazıyor. **Test sabitliyor:** yanıtta
  `d7Retention`/`trialConversion` YOK, anahtar kümesi tam olarak {soundscapes, waitlist}.
- **"Son etkinlik" tablosu KALDIRILDI:** `audit_log` yok → hiç dolmayacak boş bir söz.
- **Sayım COUNT/groupBy ile, listeyi çekerek DEĞİL** — pano her açılışta katalogu
  belleğe alsaydı sessizce O(n) olurdu (#101'in hata sınıfı).
- groupBy eksik durumları 0 ile doldurulur (yoksa panelde "undefined").
- Pano kaynağı İKİ modülün PUBLIC use case'ini birleştiriyor (content + waitlist).

🔥 **Riskler / açıklar**

- **Kendi varsayımım yanlıştı:** `POST /v1/waitlist` 201 değil **202** dönüyormuş;
  testi gerçeğe uydurdum.
- D7/paylaşım oranı (A3), deneme→ücretli (F6), audit_log yok — panelde açıkça yazılı.
- Zamanlanmış yayın, sayfalama yok; `layer_defs` **D-9**; i18n **D-8** bekliyor.

❌ **Yapılmadı**

- D7/paylaşım oranı hesabı, audit_log, zamanlanmış yayın, sayfalama, TOTP 2FA,
  davet akışı, `.env.example`.

### #125 — başlık/affinity düzenleme (PR #126, merged)

✅ **Yapıldı ve doğrulandı**

- `PATCH /v1/admin/soundscapes/:slug` (kısmi) + panelde "Bilgiler" formu.
  **A1'in son büyük eksiği kapandı** — tarif düzenlenebiliyordu ama başlık düzeltilemiyordu.
- **GERÇEK SUNUCUDA:** yayındaki kaydın başlığı düzeltildi → DB'de
  `{"en":"Doğru Yazım","tr":"Türkçe Başlık"}` — **TR KORUNDU**; affinity güncellendi;
  slug enjeksiyonu 400. Kanıt verisi silindi.
- API **352 test** (340→352), admin **71 test** (66→71), turbo 19/19.

📌 **Varsayımlar / kararlar**

- **SLUG DEĞİŞTİRİLEMEZ, panelde alanı bile YOK:** derin linkte yaşar ve paylaşılan
  kartlarda dolaşır → değiştirmek dışarıdaki linkleri sessizce kırardı. Düzenlenebilir
  göstermek, tutulamayacak söz vermek olurdu. Yeniden adlandırma → yönlendirme tablosu (ayrı iş).
- **EN düzenlemesi DİĞER DİLLERİ SİLMEZ:** `title_i18n` çok dilli; komple yazmak TR'yi
  sessizce uçururdu. Mevcut nesne okunup üzerine yazılıyor.
- **KISMİ:** verilmeyen alana dokunulmaz; `affinity: []` ise TEMİZLEME (ikisi karışmıyor).
- **Cache düşürülür:** feed hem `titleI18n` hem `archetypeAffinity` taşır (affinity
  SIRALAMAYI bile değiştirir) — ısıtılmış-cache testiyle sabit.
- `status` gövdeden enjekte edilemez (yayınlama kapısı delinmesin).

🔥 **Riskler / açıklar**

- Zamanlanmış yayın yok (`scheduled` + `publish_at` şemada var, akış yok).
- Dashboard hâlâ yer tutucu; sayfalama yok.
- `layer_defs` kullanılmıyor — **D-9 bekliyor**; i18n yok — **D-8 bekliyor**.

❌ **Yapılmadı**

- Zamanlanmış yayın, dashboard canlı veri, sayfalama, TOTP 2FA, davet akışı,
  `.env.example`.

### #124 — panelde ses tarifi editörü + admin detay ucu (PR #125, merged)

✅ **Yapıldı ve doğrulandı**

- `/content/[slug]` düzenleme ekranı: katman editörü (id/tür/kazanç, 1–8).
  **A1 zinciri panelden tamamlandı: taslak oluştur → tarif yaz → yayınla.**
- `GET /v1/admin/soundscapes/:slug` (özet + düzenlenecek ham tarif).
- **GERÇEK SUNUCUDA:** editor girişi → `/content/form-rcp` 200; sayfada "Form Recipe",
  "Ses tarifi", `value="base"`, tür "brown", kazanç 0.70, "Tarifi kaydet" + "Katman
  ekle" render oldu. Kanıt verisi silindi.
- API **340 test** (334→340), admin **66 test** (55→66), turbo 19/19.

📌 **Varsayımlar / kararlar**

- **Ham tarif DOĞRULANMADAN dönüyor:** DB'de eski/elle girilmiş bozuk kayıt olabilir,
  **editör görmeden düzeltemez**. Sıkı kapı YAZMA yolunda (#123).
- **`toFormLayers` DOĞRULAMAZ, KURTARIR:** bilinmeyen tür → varsayılan, aralık dışı
  gain → kırpılır; katman KAYBOLMAZ.
- **"Ham JSON" sekmesi YOK** (docs/03 "advanced" öneriyor): form yeterliyken ham JSON,
  bozuk tarif üretmenin en kolay yolu olurdu. Sözleşme büyürse yeniden değerlendir.
- Katmanlar JSON alanıyla gönderiliyor (düz FormData alanları ad çakışması üretirdi).
- Kaydetme HEM detay HEM listeyi tazeler (tarif varlığı yayınlama düğmesini etkiler).

🔥 **Riskler / açıklar**

- **DÜRÜSTLÜK:** form GÖNDERİMİ gerçek tarayıcıyla koşulmadı (Next-Action protokolü
  curl'le zahmetli). Action birim testlerle, API yolu + render canlı doğrulandı.
- Başlık/affinity düzenleme YOK (yalnızca tarif).
- `layer_defs` kullanılmıyor — **D-9 kararı bekliyor**; (2) çıkarsa #122'nin kapısı
  yanlış kolona bakıyor demektir.
- Zamanlanmış yayın, dashboard canlı veri, sayfalama yok; i18n yok (**D-8**).

❌ **Yapılmadı**

- Başlık/affinity düzenleme, zamanlanmış yayın, dashboard canlı veri, sayfalama,
  TOTP 2FA, davet akışı, `.env.example`.

### #123 — ses tarifi ucu (şema doğrulamalı) (PR #124, merged)

✅ **Yapıldı ve doğrulandı**

- `PUT /v1/admin/soundscapes/:slug/recipe` — sözleşme:
  `{ schemaVersion: 1, layers: [{id, type: white|pink|brown, gain: 0–1}] }`.
- **#122'nin kapısı artık açılabiliyor:** o güne dek içerik ancak DB'ye elle müdahaleyle
  yayınlanabiliyordu. Kapı vardı, anahtar yoktu.
- **GERÇEK SUNUCUDA:** oluştur 201 → tarifsiz publish **409** → bozuk tarif **400** →
  geçerli tarif 200 → publish 200 → feed'de `engineParams` görünüyor. Kanıt verisi silindi.
- API **334 test** (318→334, +16): 8 bozuk girdi × "DB'ye giremez" + kapı açılır +
  feed'e ulaşır + **ısıtılmış cache ile anında güncellenir**. turbo 19/19.

📌 **Varsayımlar / kararlar**

- **Sözleşme UYDURULMADI:** mobil motorun `MixSpec`'iyle birebir + mevcut
  `parseMixerState` kurallarıyla aynı. Katman doğrulama TEK yerde (`parseLayers`).
- **`schemaVersion` zorunlu** (docs/04 §79 istiyor); **bilinmeyen sürüm REDDEDİLİR** —
  anlamadığımız veriyi istemciye aktarmak hatayı telefona ertelemek olurdu.
- DTO kasıtlı SIĞ, asıl sözleşme domain'de (iki kopya olsaydı biri eskirdi).
- Doğrulanmış hâl yazılır, ham girdi değil → fazladan alanlar elenir.
- **Cache düşürülür** — #122'nin dersi uygulandı, ısıtılmış-cache testiyle sabit.

🔥 **Riskler / açıklar**

- **📌 D-9 SORULDU:** tarifin tamamını `engine_params`'a koydum; şemadaki `layer_defs`
  kolonunun rolü belgelerde NET DEĞİL ve **kullanılmıyor**. Uydurup şemayı kilitlemedim.
  **Seçenek (2) çıkarsa #122'nin yayınlama kapısı yanlış kolona bakıyor demektir.**
- **Panel formu YOK** — bu PR API tarafı; editör hâlâ curl'süz tarif yazamıyor.
- Düzenleme (başlık/affinity), zamanlanmış yayın, dashboard canlı veri, sayfalama yok.
- i18n yok (**D-8 kararı bekliyor**).

❌ **Yapılmadı**

- Panel tarif formu, düzenleme, zamanlanmış yayın, dashboard canlı veri, sayfalama,
  TOTP 2FA, davet akışı, `.env.example`.

### #122 — yayınlama/geri çekme + 🔴 bayat feed cache hatası (PR #123, merged)

✅ **Yapıldı ve doğrulandı**

- `POST .../publish` + `/unpublish` + panelde satır başına Yayınla/Geri çek düğmesi.
- **🔴 CANLI ÖLÇÜMÜN BULDUĞU GERÇEK HATA (asıl değer):** uçları yazdım, gerçek sunucuda
  denedim → **geri çekilen içerik feed'de KALDI**. Feed archetype başına 5dk cache'leniyor
  ve durum değişimi cache'i temizlemiyordu → **"yanlış içerik canlıda" senaryosunda geri
  çekme 5 DAKİKA işe yaramıyordu**; üstelik kendi yorumumda "geri çekmek daima anında"
  yazıyordu. **Testlerim göremiyordu çünkü hiçbiri cache'i ÖNCE ISITMIYORDU** — oysa
  gerçek senaryo tam da bu.
- **Kanıt (önce kırmızı):** ısıtmalı iki test → "Tests: 2 failed, 10 passed". Cache
  temizleme eklendi → 12/12. Canlıda da doğrulandı (ısıtılmış cache + geri çek → anında).
- **Yayınlama kapısı:** BOŞ ses tarifi yayınlanamaz (409) — feed `engineParams`'ı
  uygulamaya taşır, boş tarif = görünen ama SES ÇIKARMAYAN kayıt.
- API **318 test** (306→318), admin **55 test** (48→55), turbo 19/19.

📌 **Varsayımlar / kararlar**

- Yayından kaldırmada kapı YOK: geri çekmek daima güvenli; boş tarifli kayıt bile
  çekilebilir (acil çekme koşula takılmamalı — testle sabit).
- `Cache.delByPrefix` eklendi: feed ~9 anahtara yayılır; tek tek `del` archetype listesini
  cache tüketicisine bildirmek olurdu. Redis (B4) SCAN+DEL ile karşılar.
- Geçersizleştirme KABA (tüm varyantlar): ince ayar yanlış yapılırsa SESSİZ bayat içerik;
  içerik değişimi seyrek, feed ucuz.
- `EmptyRecipeError` → 409 (400 değil): istek doğru, engel kaynağın MEVCUT DURUMU.

🔥 **Riskler / açıklar**

- **Ders (dördüncü kez):** cache/eşzamanlılık hataları yalnızca GERÇEK koşuşturmada
  görünüyor. Bu iterasyonda testlerim yeşilken sistem bozuktu — canlı deneme kurtardı.
- **Ses tarifi editörü YOK** → pratikte yayınlanabilir içerik ancak DB/seed ile üretiliyor.
  Bu, kapının doğal ve dürüst sonucu; asıl editör deneyimi (mikser/katmanlar) ayrı iş.
- `scheduled` durumu + `publish_at` kullanılmıyor (şema var, akış yok).
- Dashboard yer tutucu; sayfalama yok; i18n yok (**D-8 kararı bekliyor**).

❌ **Yapılmadı**

- Ses tarifi editörü, düzenleme (başlık/affinity), zamanlanmış yayın, dashboard canlı
  veri, sayfalama, TOTP 2FA, davet akışı, `.env.example`.

### #121 — panelde taslak oluşturma formu (PR #122, merged)

✅ **Yapıldı ve doğrulandı**

- `/content`'te "Yeni taslak" formu (Server Action); yalnızca owner/editor'e gösterilir.
- **GERÇEK SUNUCUDA:** editor `/content` → form GÖRÜNÜYOR · analyst → form GİZLİ ·
  editor oturumuyla kayıt oluşturuldu → panelin görünür gövdesinde "Form Proof",
  "form-proof-1", "Taslak". Kanıt verisi silindi.
- admin **48 test** (30→48). turbo 19/19.

📌 **Varsayımlar / kararlar**

- **Server Action, route handler DEĞİL:** token httpOnly çerezde → çağrı zaten sunucudan
  gitmek zorunda (#116); ayrı proxy uç gereksiz katman olurdu.
- **`revalidatePath('/content')`:** liste sunucuda render ediliyor; tazelenmezse editör
  kaydettiğini GÖREMEZDİ (testle sabit).
- **Doğrulama TEKRAR EDİLMEDİ:** slug/çakışma/rol sunucunun işi (#120). Panelde tekrar
  etmek iki doğruluk kaynağı yaratır, biri sessizce eskir.
- **`createErrorMessage` ayırt edici:** "bir şeyler ters gitti" slug'ı dolu editörü
  çaresiz bırakırdı. 409/400/403 ayrı.
- Formun rol-kapısı yalnızca UX; gerçek kapı sunucuda (§3.3). Sızsa bile 403 gelir ve
  form mesajı gösterir (testle sabit).
- `apiPost` hata FIRLATMAZ, ayrık sonuç döner: yazma hataları OLAĞAN sonuçlardır.

🔥 **Riskler / açıklar**

- **DÜRÜSTLÜK:** Server Action'ın KENDİSİ gerçek tarayıcı gönderimiyle koşulmadı
  (Next-Action protokolü curl'le zahmetli). Action birim testlerle (fetch mock'lu),
  beslediği API yolu + sayfa render'ı canlı doğrulandı.
- **Kendi hatam:** commit mesajında test sayısını 30→44 yazdım, gerçek 30→48.
  PR gövdesi düzeltildi + PR'a düzeltme yorumu eklendi.
- Ses tarifi editörü YOK: taslak boş `engine_params` ile doğuyor — asıl editör
  deneyimi (mikser/katmanlar) hâlâ uzak.
- Sayfalama yok; i18n yok (**D-8 kararı bekliyor**).

❌ **Yapılmadı**

- Yayınlama (draft→published), düzenleme, ses tarifi editörü, dashboard canlı veri,
  sayfalama, TOTP 2FA, davet akışı, `.env.example`.

### #120 — taslak oluşturma + rol daraltması (PR #121, merged)

✅ **Yapıldı ve doğrulandı**

- `POST /v1/admin/soundscapes` — taslak oluşturur. **Yazma yalnızca owner+editor**;
  analyst/support okur ama yazamaz (CLAUDE.md §3.3 "analyst salt okunur" ilk kez zorlandı).
- **GERÇEK SUNUCUDA:** editor → 201 `{"status":"draft"}` · analyst → **403** ·
  analyst GET → 200. Kanıt verisi silindi.
- API **306 test** (295→306), turbo 19/19. Kontrat → `gen:api-types`.

📌 **Varsayımlar / kararlar**

- **Durum daima 'draft':** yayınlamak AYRI ve bilinçli adım. Tek çağrıda "oluştur ve
  yayınla" olsaydı yanlış kayıt kullanıcılara yazım hatası kadar kolay ulaşırdı.
- **`created_by` TOKEN'dan, gövdeden DEĞİL** — istemcinin "ben şuyum" demesine güvenmek
  denetim izini işe yaramaz kılardı (test gerçek userId ile doğruluyor).
- **Slug çakışması DB'nin UNIQUE kısıtına bırakıldı:** "önce sor sonra yaz" yarışta iki
  kaydı da geçirirdi. P2002 → 409.
- Slug NORMALİZE (trim+küçült) ama boşluk/alt-çizgi/eğik çizgi RED: slug derin linkte yaşar.
- `whitelist` sayesinde gövdeden `status` enjekte EDİLEMEZ (testle sabit).

🔥 **Riskler / açıklar**

- **Kendi hatam #1:** ilk denetim-izi iddiam TAUTOLOJİYDİ (`created_by`'ı kendisiyle
  karşılaştırıyordu) — hiçbir şey kanıtlamıyordu. Düzeltildi.
- **Kendi hatam #2:** iki testim ÇELİŞİYORDU (biri büyük harf normalize, diğeri red
  bekliyordu). Normalizasyon doğru karar; test düzeltildi.
- **Panel formu YOK** — bu PR yalnızca API. Panelden oluşturma sıradaki iş.
- Düzenleme/yayınlama yok; ses tarifi düzenleme yok (taslak boş `engine_params` ile doğar).
- Sayfalama yok; i18n yok (**D-8 kararı bekliyor**).

❌ **Yapılmadı**

- Panel oluşturma formu, PATCH/publish, ses tarifi editörü, dashboard canlı veri,
  sayfalama, TOTP 2FA, davet akışı, `.env.example`.

### #119 — içerik listesi: panel taslakları görüyor (A1 başladı) (PR #120, merged)

✅ **Yapıldı ve doğrulandı**

- `GET /v1/admin/soundscapes` (taslak/planlı/yayınlanmış hepsi) + panelde `/content`
  listesi + sunucu tarafı API istemcisi (httpOnly çerezden token okur).
- **7 iterasyonluk auth/güvenlik serisi bitti; ASIL ÜRÜN İŞİ başladı.**
- **GERÇEK SUNUCUDA:** taslak+yayın seed → panel `/content` 200; görünür gövdede
  "CMS Proof Draft" + "CMS Proof Published", "Taslak"/"Yayında", "deep-ocean".
  **10 `<td>` = 2 satır × 5 kolon** (boş durum DEĞİL, gerçek tablo). Kanıt verisi silindi.
- API **295 test** (289→295), admin **30 test** (27→30), turbo 19/19.

📌 **Varsayımlar / kararlar**

- **Boundary lint iki kez dayattı, ikisi de haklıydı:** (1) `admin/domain` content'in
  module-api'sini import edemez → `CatalogStatus` admin'in KENDİ sözleşmesi (eşleme
  module-def'te açık; content iç tipini değiştirirse orada derleme hatası verir, admin
  sessizce kırılmaz). (2) `shared/api` `features/auth`'u import edemez → çerez sabitleri
  `shared/auth/`e taşındı; zaten oraya aitti (4 yer kullanıyor, tek dilime ait değil).
- `SoundscapeSummary` AYRI okuma modeli: `status` uygulama entity'sinde yok + ağır
  `engineParams`/`layerDefs` listede taşınmamalı (testle sabit).
- Ayrı use case, feed'e bayrak DEĞİL: feed "yayınlanmış+affinity" bir ÜRÜN kararı.
- Cache YOK: editör az önce kaydettiğini görmeli. 401'de sunucu istemcisi YENİLEMEZ
  (Server Component çerez yazamaz — yenileme middleware'in işi).

🔥 **Riskler / açıklar**

- **Salt okunur:** yazma (CRUD) yok. Rol daraltması da CRUD ile gelecek (şu an analyst
  dahil her panel rolü GÖREBİLİYOR — okuma için doğru).
- **Sayfalama yok:** liste tüm kayıtları döner. İçerik büyürse gerekir.
- Dashboard hâlâ yer tutucu; i18n yok (**D-8 kararı bekliyor**).

❌ **Yapılmadı**

- Soundscape CRUD, dashboard canlı veri, sayfalama, TOTP 2FA, davet akışı,
  hesap-başına kilitleme, `.env.example`.

### #118 — refresh yarış toleransı: meşru sekmeler artık atılmıyor (PR #119, merged)

✅ **Yapıldı ve doğrulandı**

- Rotasyondan sonraki kısa pencerede (`REFRESH_REUSE_GRACE_MS`, varsayılan 10sn) aynı
  token "çalıntı" değil **yarış** sayılır → aile düşmez. #117'de işaretlediğim risk kapandı.
- **GERÇEK EŞZAMANLILIK TESTİNİN BULDUĞU KENDİ HATAM (asıl değer):** grace'i ekledim,
  gerçek iki paralel istekle ölçtüm → **hâlâ A=200, B=401**. Sebep: rotasyonda ÖNCE
  `markRevoked` SONRA `mint` yapılıyordu; arada ailede **bir an aktif token kalmıyor**,
  o boşluğa düşen sekme "aile ölü" görüp yarışı reuse sanıyor ve aileyi düşürüyordu →
  **grace tamamen işlevsizdi**. Sıralı birim testler bunu GÖREMİYORDU. Sıra düzeltildi
  (önce bas, sonra iptal et) → **5/5 turda iki sekme de sağ kaldı**. Karar artık çağrı
  sırasına bakan bir testle sabit.
- **Çıkışı bozmadığı ölçüldü:** çıkış 204 → hemen sonra refresh **401**. (Naif grace,
  çıkıştan sonraki 10sn'de yeni oturum basıp çıkışı sessizce etkisiz kılardı; bu yüzden
  grace yalnızca **aile canlıyken** uygulanıyor — yeni port `hasActiveInFamily`.)
- **Donmuş saatli testin bulduğu 2. hata:** `<=` tek başına yazılınca `grace=0` (KATI)
  modunda bile fark=0 → tolerans uygulanıyordu. `reuseGraceMs > 0 &&` eklendi.
- API **289 test** (283→289). turbo 19/19.

📌 **Varsayımlar / kararlar**

- **Bedeli açıkça:** token'ı çalan biri meşru rotasyondan sonraki 10sn içinde kullanırsa
  yakalanmaz; pencere dışında hâlâ yakalanır. Endüstride yerleşik takas (Auth0 "reuse
  interval"). **`REFRESH_REUSE_GRACE_MS=0` ile kapatılabilir** — bilinçli.
- Middleware'in "yalnızca gezintide yenile" kısıtı DURUYOR: derinlemesine savunma +
  prefetch/RSC'de gereksiz token üretmemek.
- `problem-details` e2e katı moda sabitlendi (o dosya filtreyi test eder).

🔥 **Riskler / açıklar**

- **Ders (üçüncü kez):** eşzamanlılık hatası yalnızca GERÇEK eşzamanlı istekle görünür.
  Birim testler yeşilken sistem bozuktu.
- Middleware hâlâ token DOĞRULAMAZ — gerçek kapı sunucuda.
- Dashboard hâlâ yer tutucu; i18n yok (**D-8 kararı bekliyor**).

❌ **Yapılmadı**

- TOTP 2FA, davet akışı, hesap-başına kilitleme, `.env.example`, A1 içerik CMS'i.

### #117 — sessiz oturum yenileme + GERÇEK çıkış (PR #118, merged)

✅ **Yapıldı ve doğrulandı**

- Middleware oturumu **sessizce yeniliyor** — panel 15dk'da bir login'e atmıyor.
- **`POST /v1/auth/logout` EKLENDİ** (hiç yoktu) — çıkış artık sunucudaki oturumu
  gerçekten iptal ediyor. + çıkış butonu.
- **GERÇEK SUNUCUDA** (`ACCESS_TOKEN_TTL=20s` ile, 15dk beklemeden): giriş 200 →
  access geçerliyken sayfa 200 → **22sn sonra (access ÖLDÜ) sayfa hâlâ 200** = sessiz
  yenileme → refresh token çerezde **rotasyona uğradı** → çıkış 200 → **eski refresh
  token API'de 401** = sunucu oturumu gerçekten iptal → panel 307. Kanıt hesabı silindi.
- API **283 test** (277→283), admin **27 test** (23→27), turbo 19/19.

📌 **Varsayımlar / kararlar**

- **YARIŞ KORUMASI (asıl karar):** refresh rotasyonlu + reuse-detection'lı → aynı
  token'la iki EŞZAMANLI yenileme TÜM AİLEYİ düşürür. Bu yüzden yenileme yalnızca
  **sayfa gezintisinde** (`sec-fetch-mode: navigate`); prefetch/RSC paralel akar.
- **Testin yakaladığı KENDİ HATAM:** yorumuma "API ulaşılamıyorsa çerezleri silme"
  yazmıştım ama kod hem reddi hem kesintiyi tek `null` ile dönüp ikisinde de siliyordu.
  Artık ayrık tip: `rejected` → temizle, `unreachable` → DOKUNMA.
- Çıkış **AİLEYİ** düşürür (tek token değil) ve **idempotent+sessiz** (bilinmeyen
  token'da da 204 — yanıt "bu token gerçek miydi?" kâhini olmamalı).
- **Boundary lint yine yakaladı:** AppShell (shared) LogoutButton'ı (features) import
  edemez → `actions` SLOT'u; bileşeni app katmanı geçiriyor. Kural gevşetilmedi.

🔥 **Riskler / açıklar**

- **İKİ SEKME YARIŞI (çözülmedi):** iki sekme aynı anda gezinirse eşzamanlı yenileme
  hâlâ mümkün → aile düşer → sert çıkış. Gerçek çözüm API'de kısa **grace window**
  veya tek-uçuş kilidi. **Sıradaki adaylardan.**
- Middleware hâlâ token DOĞRULAMAZ (yalnızca çerez varlığı) — gerçek kapı sunucuda.
- Dashboard hâlâ yer tutucu (canlı veri yok).
- i18n yok (hard-coded TR) — **D-8 kararı bekliyor**.

❌ **Yapılmadı**

- TOTP 2FA, davet akışı, hesap-başına kilitleme, iki-sekme yarışı, `.env.example`,
  dashboard'un canlı veriye bağlanması.

### #116 — panel girişi (httpOnly çerez) + kapı + admin'e vitest (PR #117, merged)

✅ **Yapıldı ve doğrulandı**

- **Panele giriş yapılabiliyor:** giriş sayfası + `/api/session` vekili + middleware
  kapısı. #112→#116 zinciri: API hazırdı, panel ilk kez bağlandı.
- **🆕 BULGU KAPANDI: admin'de HİÇ test yoktu** — `test` script'i bile yoktu, turbo'nun
  "18/18"i admin için hiçbir şey koşmuyordu. Artık **19 task** ve **23 admin testi** (0→23).
- **GERÇEK SUNUCUDA doğrulandı** (API :3099 + panel :3002): çerezsiz `/` → 307
  `/login?next=%2F` · giriş → 200 + `HttpOnly; SameSite=lax`, token'da `"aud":"admin"` ·
  çerezle `/` → 200 · **giriş gövdesi `{"ok":true}` — token SIZMIYOR** · yanlış parola
  401 · arka arkaya denemeler 429. Kanıt hesabı silindi (kalan 0).
- turbo 19/19.

📌 **Varsayımlar / kararlar**

- **httpOnly çerez, localStorage DEĞİL:** XSS admin anahtarını okuyamasın. Bedeli:
  tarayıcı API'ye doğrudan gitmez, panelin route handler'ından geçer — bilerek ödendi.
- **Açık yönlendirme koruması** (`safeNextPath`): `//` ve `/\` de reddedilir (ikisi de
  `/` ile başlar ama tarayıcı DIŞ adres olarak çözer).
- **429 → 401'e çevrilmez:** birleştirmek kullanıcıyı "parolam yanlış" sanıp denemeye
  devam ettirir, limit hiç açılmaz.
- `secure` yalnızca production: lokalde http'de secure çerez yazılmaz, giriş sessizce
  çalışmaz görünürdü.

🔥 **Riskler / açıklar**

- **Middleware YETKİ KONTROLÜ DEĞİL:** yalnızca çerezin VARLIĞINA bakar, token'ı
  doğrulamaz. Gerçek kapı sunucuda (#112/#113). Geçersiz çerezli kullanıcı sayfayı
  GÖRÜR ama veri çekemez. Bu bilinçli — CLAUDE.md §3.3 gereği sunucu kapısı ÖNCE yazıldı.
- **Access token yenileme YOK:** 15dk sonra sayfalar 401 alır → yeniden giriş. Refresh
  çerezi duruyor ama kullanılmıyor. **Sıradaki iş.**
- **Çıkış UI'ı yok** (`DELETE /api/session` var+test edildi, butonu yok) ve çıkış
  sunucudaki oturumu iptal ETMEZ (refresh token API'de geçerli kalır).
- i18n yok (hard-coded TR) — **D-8 kararı bekliyor**.

❌ **Yapılmadı**

- TOTP 2FA, davet akışı, hesap-başına kilitleme, token yenileme, çıkış butonu,
  `.env.example`, dashboard'un canlı veriye bağlanması.

### #115 — admin girişine kaba kuvvet limiti (PR #116, merged)

✅ **Yapıldı ve doğrulandı**

- `POST /v1/auth/admin/login` → **5 deneme/dk** (`ADMIN_LOGIN_LIMIT`, varsayılan 5).
- **ÖLÇÜLDÜ:** global limit route başına **60/dk** → tek IP'den **günde 86.400**
  parola denemesi. #114'te işaretlediğim risk gerçekti.
- **Kanıt (önce kırmızı):** `expected 429, got 401` — 6. deneme de geçiyordu.
  Limit eklendi → yeşil. Tek IP'li kaba kuvvet **12× yavaşladı**.
- API **277 test** (276→277). turbo 18/18. Kontrat → `gen:api-types`.

📌 **Varsayımlar / kararlar**

- **Boundary lint iş başında:** limiti env'e bağlarken `loadEnv()`'i controller'a
  import ettim → lint reddetti (presentation ↛ shared/config). **Kuralı gevşetmedim,
  deseni düzelttim:** `Resolvable` ile istek anında `process.env`; değer env.ts
  şemasında olduğu için açılışta zod DOĞRULAR, bozuksa güvenli varsayılana (5) düşer.
- Giriş e2e'si limiti yükseltir (o dosya kimlik doğrulamayı test eder); limitin
  kendisi kendi e2e'sinde sabitlenir → kapsam dışı kalmıyor.

🔥 **Riskler / açıklar**

- **Limit IP BAŞINA** — botnet/proxy ile dağıtan saldırgan yine deneyebilir. Asıl
  çözüm HESAP başına kilitleme; yeni DB alanı ister (migration) → ayrı iş.
- **🆕 BULGU: admin'de HİÇ test yok** — `apps/admin/package.json`'da `test` script'i
  bile yok, yani turbo'nun "18/18 başarılı"sı admin için **hiçbir şey koşmuyor**.
  Panel kodu yazmadan önce vitest kurulmalı.
- **🆕 BULGU: `.env.example` depoda YOK** — CLAUDE.md §6 "örnekleri `.env.example`"
  diyor; hiç oluşturulmamış. Yeni geliştirici hangi env'lerin gerektiğini bilemez.
  > **⛔ BU BULGU YANLIŞTI (#132'de düzeltildi).** Dosya VAR ve commit'li; aramam
  > hatalıydı ve bunu üç raporda tekrarladım. Gerçek sorun bayatlıktı: 23 env
  > değişkeninin 11'i eksikti. #132'de dosya güncellendi + `check:env-example`
  > kapısı eklendi.
- **🆕 BULGU: admin'de i18n altyapısı yok** ve mevcut metinler hard-coded Türkçe.
  Mobilde bu borcu #109-111'de kapattım; admin'de aynısı duruyor. Ama admin İÇ
  yüzeydir (personel) — EN/TR gerekli mi? Ürün kararı → D-8 olarak sorulmalı.

❌ **Yapılmadı**

- TOTP 2FA, davet akışı, hesap-başına kilitleme, panel login sayfası + middleware.

### #114 — admin parola girişi (argon2id) + ilk admin script'i (PR #115, merged)

✅ **Yapıldı ve doğrulandı**

- `POST /v1/auth/admin/login` + argon2id (`Argon2idPasswordHasher`) +
  `pnpm --filter @nocta/api admin:create`. #112→#113→#114 zinciri kapandı: admin
  token'ı artık DB kurcalamadan, gerçek girişle alınıyor.
- **GERÇEK SUNUCUDA uçtan uca doğrulandı** (curl, :3099): script hesap kurdu →
  giriş 200+token → `/v1/admin/me` 200 `{"roles":["editor"]}` → yanlış parola 401 →
  olmayan hesap AYNI 401 gövdesi → **mobil cihaz token'ı `/admin/me`'de 403**.
  Kanıt hesabı sonra silindi (doğrulandı: kalan 0).
- **Kullanıcı sayımı savunması ÖLÇÜLDÜ:** yanlış parola 13.6ms / olmayan hesap
  14.3ms (sahte doğrulama atlansaydı ~0ms). **Sabit-zaman iddia etmiyorum.**
- API **276 test** (267→276). turbo 18/18. Kontrat → `gen:api-types`.

📌 **Varsayımlar / kararlar**

- **Bağımlılık ölçüldü** (LOOP.md >1MB kuralı): `@node-rs/argon2` 37K + makinede TEK
  platform binary (win 469K / linux 632K) ≈ **506K**, MIT, node-gyp yok.
  Elenenler: `argon2` 1.03MB+node-gyp, `hash-wasm` 1.8MB.
- Parola hash'i domain `User`'a KOYULMADI (User me/refresh/guard'da dolaşır) → ayrı
  `AdminCredentials`. `PasswordHasher` ≠ `TokenHasher` (ayrı port, ayrı gerekçe).
- İlk admin ENDPOINT değil SCRIPT: "ilk admini yaratan" uç kimliksiz erişilebilir olurdu.
- argon2 params OWASP 2024 asgarisi (19MiB/2/1) — artırmak bir KAPASİTE kararıdır.

🔥 **Riskler / açıklar**

- **TOTP 2FA YOK** (CLAUDE.md §3.3 istiyor) — A0 hâlâ bitmedi.
- **Davet akışı yok**: hesap ve parola sıfırlama yalnızca script'le.
- **Giriş ucuna özel sıkı rate-limit yok** — global throttler (route başına) geçerli;
  kaba kuvvet için yetersiz olabilir. Ayrı iş.
- Script parolayı argümandan alır → shell geçmişine düşer (bilinçli takas, belgelendi).
- **Ders:** script'i çalıştırmasam iki hata sessiz kalırdı — pnpm `--`'ı argüman
  olarak geçiriyordu ve script `.env` yüklemiyordu. "Yazdım" ≠ "çalışıyor".

❌ **Yapılmadı**

- TOTP 2FA, davet akışı, panel Next.js middleware, giriş rate-limit'i, audit log.

### #113 — JWT audience ayrımı zorlanıyor (PR #114, merged)

✅ **Yapıldı ve doğrulandı**

- **🔴 KAPATILAN AÇIK (kendi #112'mdeki kapıyı delen yol):** `AccessTokenClaims.aud`
  "mobil/admin token'ı karışmasını önler" diye belgelenmişti ama **ölü koddu** —
  `SessionMinter` her zaman `aud: 'app'` basıyor, `verify` ikisini de kabul ediyor,
  **hiçbir tüketici kontrol etmiyordu**. Etki: cihazda saklanan uzun ömürlü mobil
  token, admin rolü taşıyorsa **panel anahtarı** oluyordu.
- **Kanıt:** #112'nin kendi testleri ANONİM kullanıcıya rol verip 200 alıyordu.
  aud zorlaması eklenince kırmızıya döndüler (`expected 200, got 403` ×4) → yani
  **testlerim var olmaması gereken bir durumu doğru sanıyordu.** Testler gerçek
  admin hesabı (`kind='admin'`) kuracak şekilde düzeltildi.
- `aud` artık `audienceForKind(user.kind)` ile TÜREYİYOR — çağıranın seçimine
  bırakılmadı. Cihaz akışı daima 'anonymous' üretir → mobil token asla 'admin' olamaz.
- API **267 test** (265→267). turbo 18/18. **Migration gerekmedi** (kind zaten elde).

📌 **Varsayımlar**

- `@Roles` yalnızca `AdminRole` alır (tip zorlar) → böyle işaretli her handler tanım
  gereği panel handler'ıdır ve `aud:'admin'` ister. Ayrı bir `@Audience` decorator'ı
  eklemedim (bu ölçekte bürokrasi).
- Admin hesabının cihaz akışıyla oluşmayacağını varsaydım (kind='admin' yalnızca
  davet/seed ile gelir) — davet akışı henüz yok, bu varsayım A0 kalanında sabitlenmeli.

🔥 **Riskler / açıklar**

- **Ders:** #112'yi "kapı kapandı" diye raporladım; kapı kapandı ama duvarda pencere
  vardı. Bir güvenlik iddiasını, onu delen yolu aramadan tamam saymamalıyım.
- Admin hesabı oluşturma hâlâ YOK: rol+kind yalnızca DB'den elle veriliyor.
- Rol/tür değişimi refresh'te yürürlüğe girer → access token ömrü (kısa) boyunca eski
  yetki geçerli.

❌ **Yapılmadı**

- Admin parola girişi (argon2id, `password_hash` kolonu var ama kullanılmıyor) —
  **sıradaki iş**. Sonra TOTP 2FA, davet akışı, panel middleware.

### #112 — admin rol kapısı sunucuda zorlanıyor + admin modülü A0 (PR #113, merged)

✅ **Yapıldı ve doğrulandı**

- **`@Roles(...)` + `RolesGuard`** (identity modülünde — auth kodu yalnızca orada,
  CLAUDE.md §6) ve ilk tüketicisi `admin` modülü: **`GET /v1/admin/me`**.
- **🔴 KAPATILAN AÇIK:** roller JWT'ye basılıyor, request'e ekleniyor ve
  `/v1/auth/me`'de dönüyordu ama **hiçbir yerde kontrol edilmiyordu** — depoda tek
  bir `RolesGuard`/`@Roles`/`hasRole` yoktu. CLAUDE.md §3.3 "her mutation
  server-side rol kontrolünden geçer" diyordu; **rol modeli vardı, zorlaması yoktu**.
- **Kanıt (önce kırmızı):** guard çıkarılıp koşuldu → `expected 403 "Forbidden",
got 200 "OK"` ×3, "Tests: 3 failed, 4 passed". Guard eklendi → 7/7.
- API **265 test** (253→265, +12): e2e 7 + RolesGuard unit 5. turbo 18/18.
- Kontrat değişti → `pnpm gen:api-types` koşuldu, üretilen tipler commit'te.

📌 **Varsayımlar / kararlar**

- `@Roles` **sınıf düzeyinde**: yeni admin ucunda rol koymayı unutmak "herkese açık
  admin ucu" demek olurdu → varsayılan kapalı.
- `@Roles()` boşsa **reddedilir** (herkesi almak değil, programlama hatası);
  `req.user` yoksa reddedilir → guard sırası yanlış kurulursa açık bırakmaz.
- `/admin/me` yalnızca TANINAN rolleri döner → DB'ye elle yazılmış çöp rol adı
  panelin yetki mantığına sızmaz.
- Test sırasında öğrenildi ve sabitlendi: `/v1/auth/refresh` **200** döner (201 değil),
  ve refresh token **rotasyonlu** — eski token tüketilir.

🔥 **Riskler / açıklar**

- **Admin hesabı oluşturma YOK:** davet akışı, argon2id parola, TOTP 2FA henüz yok.
  Şu an admin rolü yalnızca **DB'den elle** verilebiliyor. A0 bitmedi.
- Panel tarafı (Next.js middleware) hâlâ yok — bu PR yalnızca sunucu kapısı.
- Rol değişimi **refresh'te** yürürlüğe girer: rol geri alınan bir kullanıcı, elindeki
  access token'ın ömrü boyunca (kısa) admin kalır. Kabul edilebilir ama bilinsin.

❌ **Yapılmadı**

- Admin davet/parola/2FA, panel middleware, audit log. Sıradaki adaylar.

### #111 — i18n migrasyonu bitti + kural CI'da zorlanıyor (PR #112, merged)

✅ **Yapıldı ve doğrulandı**

- Kalan 6 ekranın tüm kullanıcı metni `app_en.arb`'ye taşındı (57 anahtar):
  archetype test/detay/geçmiş, soundscape kütüphane/detay, uyku geçmişi.
  → `flutter analyze` temiz, `flutter test` **159/159** (sayı değişmedi = saf refactor).
- **`pnpm check:i18n` kapısı** (`tooling/check-hardcoded-strings.mjs`) CI'a eklendi.
  Kapının gerçekten yakaladığı kanıtlandı: sahte `Text('Cures insomnia fast')`
  enjekte → exit=1 (health-claims kapısı da yakaladı) → geri alındı.
- `sleep_history`'deki `'${nights} nights'` İngilizce çoğul mantığı koda gömülüydü
  (TR'de yanlış olurdu) → ICU plural'a çevrildi.
- `pnpm turbo run lint typecheck test build size`: 18/18.

📌 **Varsayımlar**

- Kapı bilinçli DAR: yalnızca `Text('...')` ve `label: '...'`. Yanlış pozitif üreten
  kapı, kapatılan kapıdır. Yeni metin taşıyıcı (`tooltip:`, `hintText:`) çıkarsa eklenir.

🔥 **Riskler / açıklar**

- **Kendi hatam:** `dart format --line-length 100` çalıştırdım; depo ne 100 ne de 80
  ile format-clean, sonuç 65 ilgisiz dosyada gürültü oldu. Amaçlamadığım dosyaları
  geri aldım (PR 15 dosyaya indi) ama **depoda format kapısı yok** — bu er ya da geç
  yine olur. Ayrı iş: `dart format --set-exit-if-changed` kapısı + tek seferlik
  formatlama commit'i.
- `app_tr.arb` hâlâ yok: altyapı hazır, TR çeviri içerik kararı bekliyor (kod değişmez).
- Kapı `.arb` içeriğini değil yalnızca Dart literal'lerini tarar; arb'ye yanlış dilde
  metin girmesini engellemez.

❌ **Yapılmadı**

- `flutter gen-l10n && git diff --exit-code` drift guard (üretilen dosya elle
  düzenlenirse fark edilmez). Ayrı iş.

- **#110 (l10n: home + settings — 🔑 çoğul mantığı düzeltildi):** #109'un devamı; en büyük iki ekran daha arb'ye (~20 metin), **kalan 7 ekran**. **Bu sadece metin taşıma DEĞİL:** İngilizce çoğul mantığı **koda gömülüydü** ve çeviride ÇALIŞMAZDI — `'$revoked other device${revoked==1?'':'s'} signed out'`, `current==1?'night streak':'nights streak'`, `'$count soundscape${...}'`. Türkçe böyle çoğullanmaz; metni arb'ye taşımak **tek başına yetmezdi**, koddaki "-s ekle" mantığı yanlış kalırdı. Hepsi **ICU plural**'a çevrildi → çoğul kuralı artık dilin kendi dosyasında, TR arb gelince kod değişmeyecek. arb **12→34 anahtar** (ICU plural + placeholder). Stale "M1'de taşınacak" notları silindi. settings'te iki async metodda l10n await'ten ÖNCE yakalanıyor (#109'daki analyzer dersi). `'NOCTA'` bilinçli çevrilmiyor (marka). **DAVRANIŞ DEĞİŞMEDİ:** testler değişmeden geçti, yalnızca delegate eklendi; analyze temiz, 159 test, health scan ✓ (240 dosya), turbo 18/18. Bar mobil 47→48% (toplam ≈53%). PR #111.
- **#109 (mobil i18n altyapısı + ilk ekran — 🔴 DÜRÜST İTİRAF):** CLAUDE.md §4 "tüm kullanıcı metinleri **baştan itibaren** arb'de … hard-code string PR'da **reddedilir**" diyor. Gerçek: mobilde l10n altyapısı **HİÇ YOKTU**, ~63 metin hard-coded, 9 dosyada "M1'de taşınacak" notu. **Son ~20 iterasyonda BEN DE bu borcu büyüttüm** (aynı notu düşerek) — #90/#91/#107/#108 ile aynı sınıf ama farkı: **ihlale ben de katıldım**. ~63 metin/10 ekran → iş **hiç olmayacağı kadar ucuz şu an**. Tek PR 400 satırı aşardı → **bölündü**: bu PR altyapı + en büyük ekran (night_report, 11 metin), diff 348 satır; kalan 9 ekran (~50 metin) sonraki turlarda. `flutter_localizations`+`intl`+`generate:true`, `l10n.yaml` (kaynak EN), `app_en.arb` (12 açıklamalı anahtar; **TR arb eklenince KOD DEĞİŞMEZ**), MaterialApp delegate'leri. **gen-l10n kaynak ağacına üretiyor → CI'da ayrı üretim adımı gerekmiyor** (doğrulandı). **DAVRANIŞ DEĞİŞMEDİ:** testler tek satır değişmeden geçti (EN değerleri birebir aynı), teste yalnızca delegate eklendi; 159 test yeşil, analyze temiz, turbo 18/18. **Analyzer gerçek hata yakaladı:** `AppL10n.of(context)` await'ten SONRA kullanılıyordu (`use_build_context_synchronously`) → messenger gibi await'ten ÖNCE yakalanıyor. **🟡 KENDİ KAPIMIN KÖR NOKTASI:** metni .arb'ye taşıyınca #108'deki tarayıcı onu **görmüyordu** (.arb kapsam dışı) — metni tam da kapının kör noktasına taşıyordum; .arb kapsama eklendi + sahte iddiayla doğrulandı (240 dosya). Bar mobil 46→47% (toplam ≈52%). PR #110. **Takip:** 9 ekran + sonunda "hard-coded string yok" kapısı; üretilen dosya commit ediliyor → `gen-l10n && git diff --exit-code` drift guard'ı.
- **#108 (depo geneli sağlık iddiası taraması — CI kapısı):** CLAUDE.md §1.1 bunu **uyum kuralı** olarak koyuyor (FTC/App Store/reklam kurulu, "metin üreten her PR'da kontrol edilir") ama tarama yalnızca web'in birkaç testindeydi; **mobil metinler, API açıklamaları, admin ve llms.txt HİÇ taranmıyordu** → en yüksek yasal riskli kural en zayıf zorlanıyordu (#90/#91/#107 ile aynı sınıf). **Önce ölçtüm:** gerçek ihlal YOK (4 isabetin hepsi kuralı belgeleyen yorumlar) → kapı güvenli. **Kelime listesi uydurulmadı:** CLAUDE.md örnekleri + mevcut web testlerinin kümesinin birleşimi. **Kapsam:** yorum satırları atlanır (kullanıcıya gösterilmez + kuralı belgeleyen yorumlar yanlış pozitif olurdu), test dosyaları atlanır (yasak kelimeleri bilerek içerirler). **🟡 BULGU:** tarayıcı `llms.txt`'te 3 satır yakaladı ama bunlar iddia DEĞİL, **iddianın REDDİ** ("not a medical product", "does not diagnose, treat, or cure anything") — kapıyı geçirmek için feragati silmek **aktif zarar** olurdu; **incelenmiş istisna listesi** eklendi, **TAM SATIR** eşleşmesiyle → metin değişirse kapı yeniden düşer, insan yeniden inceler. **Doğrulama iki yönlü:** temizde 237 dosya ✓ exit 0; mobile'a sahte iddia ("cures insomnia … clinically proven") enjekte edilince yakalayıp exit 1. `tooling/check-health-claims.mjs` + root `check:health-claims` + CI adımı. turbo 18/18, API 253. Bar backend 78→79% (toplam ≈52%). PR #109.
- **#107 (🔴 coverage eşiği tanımlıydı ama HİÇ ZORLANMIYORDU):** CLAUDE.md §5 "%80 satır kapsamı CI eşiği" diyor; `coverageThreshold` jest config'inde **tanımlıydı** ama `test` script'i `--coverage` içermiyordu ve CI'da coverage adımı yoktu → **jest eşiği yalnızca coverage toplanırken değerlendirir, yani kapı hiç çalışmıyordu**. #90 (olay sözlüğü) / #91 (CWV bütçesi) ile aynı sınıf: belgelenmiş, uygulanmamış. **#91'in dersiyle önce ÖLÇTÜM:** satır **%97.56**, statement %97.02, fonksiyon %98.07, branch %87.71 → hepsi %80'in epey üstünde; CWV'nin aksine kapıyı açmak **güvenli**, kimseyi kırmıyor. **Kapının kırmızı olabildiği de kanıtlandı:** eşik geçici 99.9 → `Jest: coverage threshold for lines (99.9%) not met: 97.56%`. `--coverage` yalnızca CI'a değil **`test` script'ine** eklendi (kapı lokalde de aynı çalışsın, CI'da sürpriz olmasın); maliyet ~%15, turbo cache tekrarları atlıyor. turbo 18/18, API 253 test. Bar değişmedi (≈51% — kapı açma, yeni yetenek değil). PR #108. **Dürüstçe eksik:** eşik **global** (`src/**`), CLAUDE.md "domain+application katmanlarında" diyor → global %97 teorik olarak zayıf bir katmanı gizleyebilir; katman-başına eşik + branch eşiği (%87.71) ayrı iyileştirme — bu PR mevcut eşiği uygular, yeni eşik icat etmez.
- **#106 (🔴 GÜVENLİK/SIZINTI: idempotency cache kullanıcılar arası yanıt sızdırıyordu):** `IdempotencyInterceptor` cache anahtarı yalnızca `url:key` idi — **çağıran kimliği yoktu**. Aynı `Idempotency-Key`'i kullanan iki kullanıcıdan **ikincisi BİRİNCİNİN yanıtını** alıyordu (başkasının userId'si + skorları) ve **kendi işlemi hiç yapılmıyordu** (handler atlanıyor). Anahtarlar gizli değil; naif istemci (sayaç/timestamp/"retry-1") çakışmayı olası kılar. CLAUDE.md §6 "her şey çağıranın kimliğiyle kapsamlanır" burada uygulanmamıştı. **SIZINTI KANITLANDI:** eski kodla B'nin yanıtı A'nın userId'sini taşıdı (Expected b957cc78=B, Received 18990b11=A) — teorik değil. Düzeltme: anahtar çağıran-kapsamlı → kimlik varsa `u:{userId}`, yoksa `ip:{ip}`. **IP fallback neden:** public uçlar (`/v1/archetype/web`, `/v1/waitlist`) da retry güvenliğinden yararlanıyor; IP mükemmel değil (NAT) ama "herkes tek havuz"dan kat kat iyi. `req.user` **yapısal** okundu — identity'den tip import shared→modül sınırını ihlal ederdi. API **253 test** (251→253): sızıntı regresyonu (her kullanıcı KENDİ yanıtını alır + B'nin işlemi gerçekten yapılır), aynı kullanıcı+aynı anahtar → hâlâ cache hit, mevcut public test değişmeden geçer. turbo 18/18. Bar backend 77→78% (toplam ≈51%). PR #107. **Örüntü:** son üç turda üç sessiz kusur (#101 stats penceresi, #105 bağlanmamış rate-limit guard'ı, #106 bu) — hepsi "kod okununca doğru görünen ama yanlış çalışan" sınıfından.
- **#105 (🔴 GÜVENLİK: rate-limit çoğu uçta ZORLANMIYORDU):** `ThrottlerModule` kayıtlıydı ama **guard kayıtlı değildi** — NestJS'te modül tek başına hiçbir şey zorlamaz, `APP_GUARD` gerekir. Rate-limit yalnızca `@UseGuards(ThrottlerGuard)` yazan **iki** public controller'da (web-archetype, waitlist) çalışıyordu; **`/v1/auth/*` dahil TÜM uçlar korumasızdı**: `/v1/auth/device` → **sınırsız anonim hesap açma** (DB şişirme), `/v1/auth/email/request` → magic-link spam'i (gerçek SMTP'de e-posta bombası), refresh + tüm authed uçlar limitsiz. Üstelik app.module'deki yorum "In-memory IP rate-limit" diyerek **korunuyor izlenimi** veriyordu. **Açık KANITLANDI:** eski kodla `/health` "expected 429, got 200", `/v1/auth/device` "expected 429, got **201 Created**". Düzeltme: `APP_GUARD`+`ThrottlerGuard` global; limitler env'e (`THROTTLE_LIMIT`/`THROTTLE_TTL_MS`, `forRootAsync` → fabrika her app kurulumunda çalışır) çünkü e2e'ler tek IP'den yüzlerce istek atıyor; jest-setup testte limiti yükseltir, **throttling kendi e2e'sinde limiti ezerek test edilir** (kapsam dışı değil). API **251 test** (249→251), turbo 18/18, mevcut e2e'ler 429 yemedi. Bar backend 76→77% (toplam ≈51%). PR #106. **Kendi hatam:** ilk testimin varsayımı yanlıştı ("IP başına tek havuz") — throttler sayacı **rota başına**; kod doğruydu, test hatalıydı, düzeltildi. **Kapsam dışı (bilinçli):** uç-başına daha sıkı limitler (`@Throttle` statik → testleri kırardı, env'e bağlanması ayrı iş); şu an hepsi tek varsayılanda (60/dk) — korumasızdan çok iyi ama ideal değil. Redis storage hâlâ B4.
- **#104 (mobil kimlik geçmişi ekranı):** #103'teki `GET /v1/archetype/results` ucunun mobil karşılığı (#78→#79 deseni). "Overthinker → Deep Ocean" anlatısı görünür; en yenide **"Current"** rozeti. `listResults` + `archetypeHistoryProvider` + `ArchetypeHistoryScreen` + `/identity/history`. **home'da bağlantı YALNIZCA birden fazla sonuç varsa** (tek sonuçta "geçmiş" anlamsız); yükleme/hata → gizli. İsim içerikten, yoksa slug fallback. Tarih: ISO'nun gün kısmı — **`intl` bağımlılığı EKLENMEDİ** (maliyet disiplini). **⚠️ Rota sırası:** `/identity/history`, `/identity/:slug`'dan ÖNCE tanımlandı; aksi halde "history" slug sanılıp "Unknown identity" gösterirdi. `flutter test` 159 yeşil (153→159, +6): geçmiş+isim çözümü+Current rozeti, slug fallback, boş, hata; home'da bağlantı görünür/gizli. Salt mobil, contract değişmedi. İlerleme barı mobil 45→46% (toplam ≈51%). PR #105. **Not:** 1.5 saatlik kullanıcı duraklamasından sonraki ilk iterasyon.
- **#103 (archetype sonuç geçmişi + 📋 D-7 export planı):** `GET /v1/archetype/results` — sonuç geçmişi (yeniden eskiye). **Boşluk:** testi tekrar etmek yeni kayıt üretiyor ve kayıtlar saklanıyordu, ama yalnızca EN SON sonuç erişilebiliyordu; geçmiş kullanıcının kendi verisi olmasına rağmen hiçbir yerden görünmüyordu. Kimlik zamanla değişir ("Deep Ocean→Dawn Chaser") — ürünün çekirdek anlatısı. **Sınır YOK (bilinçli):** kırpmak #101/#102'deki sessiz hatalarla aynı sınıf olurdu; hacim küçük (test başına tek kayıt). port `listByUserId` + `ListResultsUseCase` + endpoint (mevcut DTO yeniden kullanıldı) + openapi/shared-types regen. API **249 test** (247→249): tekrar test→2 kayıt/en yeni önce, `/result` hâlâ en sonu döner, **izolasyon** (B, A'nın geçmişini görmez). turbo 18/18. Bar backend 75→76% (toplam ≈50%). PR #104. **📋 KAPSAM KARARI:** bu tura **GDPR export** ile başladım; veri envanterini çıkarınca tam export'un **6 modülü** kapsadığını (identity/profile/archetype/sleep/notification/analytics), **modül döngüsü** nedeniyle yeni bir `account` modülü gerektirdiğini (sleep→profile, herkes→identity) ve analytics olaylarının **sayfalama** isteyeceğini gördüm → tek PR'a sığmaz. **Yarım export'u "verileriniz" diye sunmak yanıltıcı olacağı için ship ETMEDİM**; bunun yerine export'un da gerekeceği ilk tam parçayı gönderdim ve **tüm bulguları DECISIONS_NEEDED · D-7'ye yazdım** (döngü kısıtı, kırpma yasağı, sır sızdırmama, kapsam seçenekleri) → sonraki iterasyon sıfırdan araştırmayacak.
- **#102 (🔴 streak sessizce 400 geceyle sınırlıydı):** #101'in yan bulgusu kapatıldı. `listNightDates` `take:400` ile sınırlıydı; `computeStreak` ise hem `totalNights` hem `longest` için tarihlerin TAMAMINA ihtiyaç duyuyor → **400+ gecesi olan kullanıcıda ikisi de SESSİZCE yanlış** (≈13 ay, yani ikinci yılındaki kullanıcı). #101'le aynı sınıf: hata/uyarı yok, sadece yanlış rakam. **Yine önce bug'ı üreten test yazıldı, eski kodla KIRMIZI kanıtlandı: Expected 450, Received 400.** Sınır kaldırıldı + gerekçe koda yazıldı; maliyet küçük (yalnızca distinct tarih kolonu, gece başına tek satır, 10 yıl ≈3.6k). API **247 test** (246→247): e2e 450 ardışık gece → totalNights=450/longest=450 (eskiden 400/400); toplu insert (450 HTTP yerine — okuma yolu testi); e2e'ye PrismaClient + `tokenAndUser`. turbo 18/18. Bar değişmedi (≈50% — hata düzeltmesi). PR #103. **Durum:** bilinen sessiz kırpma sınırları KAPANDI (stats 100 oturum #101, streak 400 gece #102). `ListSleepSessionsUseCase`'deki 100 limiti **bilinçli** kalıyor — o listeleme/sayfalama limiti, istatistik değil.
- **#101 (🔴 GERÇEK VERİ HATASI: uyku istatistikleri sessizce son 100 oturumu sayıyordu):** `GetSleepStatsUseCase` WINDOW=100 ile son 100 oturumu çekip özetliyordu; **100+ oturumu olan kullanıcıda `nights` ve ortalama SESSİZCE kısmi** veriyi yansıtıyordu — üstelik mobil bunu genel istatistik gibi gösteriyor ("N nights · avg"). ~3 aydan uzun kullanan herkes yanlış sayı görürdü: hata/uyarı/log yok, sadece yanlış rakam. **CLAUDE.md §5 gereği önce bug'ı üreten test yazıldı ve eski kodla KIRMIZI olduğu kanıtlandı: Expected 120, Received 100.** Düzeltme: pencere kaldırıldı, toplam DB'de hesaplanıyor (SQL agregasyonu → bellek de yemiyor). `SleepAggregate`+`statsFromAggregate` (eski `aggregateStats` yerine), port `aggregateFor`, repo Prisma aggregate(count+sum)+groupBy(night_date) (COUNT(DISTINCT) Prisma'da yok). API **246 test** (244→246): e2e 120 gece → nights=120/total=7200 (eskiden 100/6000); ortalamanın **oturum başına** olduğu açıkça sabitlendi. turbo 18/18. Contract değişmedi → regen yok. Bar değişmedi (≈50% — hata düzeltmesi, yeni yetenek değil). PR #102. **⚠️ YAN BULGU (düzeltilmedi):** `listNightDates` içinde `take: 400` → **streak 400 geceyle sınırlı**; aynı sınıftan sessiz sınır ama 400 gece >1 yıl olduğu için aciliyeti düşük — sıradaki adaylardan.
- **#100 (mobil mixerState tipleme + içerik→motor bağlantısı; 🔴 #98 iddiamın düzeltmesi):** #99'da sunucu tipledi; mobil hâlâ **`dynamic`** taşıyordu — **CLAUDE.md §4 ihlali** ("dynamic yasak") ve analyzer yakalamıyordu (strict-casts açık bildirimi kapsamaz). `lib`'deki TEK dynamic buydu → artık sıfır. `MixerLayerState`/`MixerState`+`tryParse` (**savunmacı**: sunucu doğruluyor ama istemci eski/yeni olabilir; geçersizse kısmi değil null) + `toMixSpec()` → **içerik→motor zinciri kapandı**, sunucu preset'i gerçekten render ediliyor. `avoid_dynamic_calls` lint eklendi (kuralın uygulanabilir kısmı; açık bildirim hâlâ lint'lenemiyor — dürüstçe not). `flutter test` 153 yeşil (135→153, +18), turbo 18/18, API 244. **🔴 BULGU — #98'deki kendi iddiamı düzeltir:** test 1sn render'da DC=0.0086 verip kırmızı oldu; eşiği gevşetmek yerine ölçtüm → aynı mix: 1sn=0.0086, 2sn=0.0030, 5sn=0.00002, 10sn=0.00019. **"DC" pencere ortalamasıdır ve kısa pencerede gürültülüdür**; #98'de raporladığım dc=0.00002 **evrensel garanti DEĞİL**, 5sn'ye özgü şanslı örnek. Kısa pencerede DC eşiği regresyon bekçisi olarak ANLAMSIZ (ham sinyalinki bazen daha küçük). **Kod değişmedi — filtre doğru, ölçüm iddiam fazlaydı**; uçtan uca testten DC iddiası kaldırıldı, uyarı `dc_blocker.dart`'a yazıldı. İlerleme barı mobil 43→45% (toplam ≈50%). PR #101.
- **#99 (🔴 preset mixer_state sözleşmesi — tipli + doğrulanır):** `presets.mixer_state` şimdiye dek **serbest jsonb** idi (domain/DTO tipi: `unknown`) → editör herhangi bir JSON koyabilir, hata ancak **kullanıcının telefonunda çalma anında** patlardı. Mevcut seed `{rain:0.7}` sadece kazanç taşıyordu, **ses tipi yoktu** → motor render EDEMEZDİ. Motoru #94–#98'de yazdığım için gereksinimi biliyorum: katman={id,type,gain}; şema mobil `MixSpec` ile birebir hizalı tanımlandı ve **okuma yolunda doğrulanıyor** → bozuk preset istemciye HİÇ ulaşmıyor. **Tolerans yok:** tek katman bozuksa tüm state reddedilir (kısmi mix yok); NaN/Infinity elenir, id benzersiz, max 8 katman (CPU/headroom). **Sessiz düşürme yok:** `Logger.error` + beklenen şema loglanır (CLAUDE.md §0); soundscape yine 200 döner, yalnızca o preset elenir. `Preset.mixerState` artık `MixerState` (unknown DEĞİL); `MixerStateDto`/`MixerLayerDto`; openapi+shared-types regen; e2e seed yeni şemaya taşındı. API **244 test** (222→244, +22): 20 red vakası + sınır değerler + **e2e sözleşme kapısı** (DB'ye bozuk preset yazıldı → istemciye ulaşmadı, 200 korundu). turbo 18/18. İlerleme barı backend 73→75% (toplam ≈49%, bar 20 blok). PR #100. **Not:** yazma yolu (admin CMS) yok; CMS gelince aynı `parseMixerState` girişte de kullanılmalı.
- **#98 (🔊 offline mix renderer — DSP zinciri birleşti):** kaynaklar → `Mixer` → `DcBlocker`; `MixSpec`/`MixLayer` deklaratif tanım + `renderMix()`. **Spekülatif değil:** hem native grafın eşleşmesi gereken **referans** implementasyon, hem **mix-to-video (viral kanca #3)** için gereken offline üretim. **🔑 Katman dekorelasyonu:** tüm katmanlar aynı seed'i kullansaydı aynı gürültüyü üretir → iki pembe katman birebir aynı olur, toplama sesi zenginleştirmek yerine sadece yükseltirdi. Katman başına asal çarpanla seed; **ölçüldü: aynı tip farklı indekste %0.0 aynı örnek** (tam bağımsız), testle sabit. Ölçümler (uyku mix'i pembe0.5+kahve0.4, 5sn@48k, seed42): rms=0.1274, mad=0.0457, **dc=0.00002** (ham pembenin -0.036'sı zincirde temizlendi → #95→#96 zinciri uçtan uca doğru), **clipped=0**. `flutter test` 135 yeşil (126→135, +9). İlerleme barı mobil 41→43% (toplam ≈48%). PR #99. **Not:** katman hâlâ ses ÇALMIYOR (offline render); native graf + `AudioEngineFacade` (gerçek zamanlı çalma, kesinti/odak) sırada; kulakla doğrulama docs/10.
- **#97 (🔊 katman mikseri — kazanç rampası / anti-tık):** Ses zincirinin sıradaki halkası. **Asıl mesele zipper noise:** sürgü çekilince kazancı sıçratmak tam ölçekli süreksizlik = duyulur tık (CLAUDE.md "ucuz duyulan hiçbir şey ship edilmez"). Kazançlar hedefe 20 ms doğrusal yürür, durum `mixInto` çağrıları arasında sürer. **Ölçümle kanıtlandı:** rampalı maxDelta=**0.00104** (tam 1/960) vs rampasız sıçrama **1.00000** → ~960×; test ikisini yan yana koyuyor ("rampanın önlediği şey"). **Headroom:** toplam 1'i aşarsa son çare clamp + `clippedSamples` **raporu** (sessizce bozmaz; 1.0+1.0 → 4800/4800 kırpıldı, sayıldı). `flutter test` 126 yeşil (116→126, +10): toplama, rampa deltası/hedefe ulaşma, immediate karşılaştırması, yeni katman sessizden girer, clamp+rapor, **streaming denkliği** (128'lik parçalı == tek seferde), [0,1] clamp, reset. İlerleme barı mobil 39→41% (toplam ≈47%, bar 19 blok). PR #98. **Not:** DC blocker + mikser henüz üretim zincirine BAĞLI DEĞİL; katman hâlâ ses ÇALMIYOR — native graf + `AudioEngineFacade` sırada.
- **#96 (🔊 DC engelleyici — #95 bulgusu KAPANDI):** #95'te bulup "sıradaki iş" diye yazdığım açık kapatıldı: pembe gürültünün artık DC'si kaynağında temizleniyor. **Kritik tasarım:** durumlu tek-kutuplu yüksek geçiren (`y[n]=x[n]-x[n-1]+R·y[n-1]`, R=0.9995) — **"buffer ortalamasını çıkar" DEĞİL**, çünkü native graf sesi 128–1024'lük callback'lerle parça parça işler; ortalama çıkarma tüm buffer'ı görmeyi gerektirir. **Testle kanıtlandı:** parçalı (128'lik) işleme = tek seferde işleme **birebir aynı** → native'e birebir taşınabilir. Ölçümler: pink dc -0.03568→**0.00060** (60×); white rms 0.5763→0.5764 (sinyal bozulmuyor); sabit 1.0 girişi→0.00000; kesim **3.82 Hz** @48k (bas duyulur kalır). `flutter test` 116 yeşil (110→116, +6), analyze temiz. İlerleme barı mobil 38→39% (toplam ≈46%). PR #97. **Not:** filtre henüz üretim yoluna bağlı değil — mikser/graf gelince zincire girecek; katman hâlâ ses ÇALMIYOR.
- **#95 (🔊 pembe gürültü — Voss-McCartney + DC bulgusu):** #94'te sıraya bırakılan pembe gürültü (1/f, uyku sesinin klasiği). 16 beyaz üreteç farklı oktavlarda yenilenir (satır k, 2^k örnekte bir) → oktav başına eşit enerji. Golden değerler yine **ÖLÇÜLEREK**: pink rms=0.2279, mad=0.0950, peak=1.0000. **Asıl özellik testle sabit:** spektral eğim white(0.6652) > pink(0.0950) > brown(0.0433) → pembe tam ortada. `flutter test` 110 yeşil (104→110), analyze temiz. PR #96. **🟡 BULGU (gizlenmedi):** pembede artık **DC=-0.036** (white/brown ≈0.000). Hata DEĞİL — en yavaş satır 32768 örnekte bir yenilenir, sonlu pencerede 1/f'in düşük-frekans enerjisi sabit kayma gibi görünür. **Neden "düzeltilmedi":** buffer ortalamasını çıkarınca DC ~0 olur ve testler tertemiz geçerdi, ama bu numara yalnızca offline buffer'da çalışır — **streaming native grafta (AVAudioEngine/Oboe) aynı DC geri gelir**; yani sorunu çözmez, saklardı ve native'de sürpriz olurdu. Ham bırakıldı; **çalma yolunda DC engelleyici (high-pass) GEREKİR** — kodda + testte + burada yazılı. **SIRADAKİ İŞ:** DC blocker/high-pass biquad + golden testi.
- **#94 (🔊 ses motoru DSP çekirdeği — ilk taş):** Projenin **en büyük boşluğuna** başlandı. `core/audio_engine/dsp/noise.dart` — saf Dart, platformdan bağımsız: deterministik LCG (`Random` değil — golden testler tekrarlanabilir olmalı), `whiteNoise`, `brownNoise` (beyazın **sızıntılı integrali**; sızıntı DC drift'ini engeller, tepe 1'e normalize → kırpma yok) + istatistik yardımcıları `rms`/`dcOffset`/`meanAbsDelta` (FFT'siz spektral eğim vekili). **docs/04 §80 birebir uygulandı**: 5 sn buffer'ın istatistik snapshot'ı, örnek eşitliği DEĞİL (platform toleransı). Beklenen değerler implementasyondan **ÖLÇÜLEREK** alındı (uydurulmadı): white rms=0.5763 (teori 1/√3=0.5774 ✓), dc=0.0002; brown rms=0.2517, dc=0.0007, peak=1.0000, pürüzsüzlük beyazın ~15 katı düşük. `flutter analyze` temiz, `flutter test` 104 yeşil (91→104, +13): determinizm, golden snapshot'lar, sınırlılık, boş/tek-örnek. İlerleme barı mobil 35→37% (toplam ≈46%). PR #95. **DÜRÜSTLÜK:** bu katman **HENÜZ SES ÇALMAZ** — native graf (AVAudioEngine/Oboe) + `AudioEngineFacade` ayrı; bu dosya onların doğruluk ölçütü. Pink (Voss) bilinçli olarak sıraya bırakıldı (PR küçük kalsın).
- **#93 (report_shared olayı — sözlük + emisyon atomik):** #92'de bilinçli bırakılan uç kapatıldı. Olay sözlüğe (API) ve mobile (emisyon) **aynı PR'da** girdi — `docs/analytics-events.md`'deki sıra kuralı gereği ("önce sözlük, sonra gönderim"); ayrı gitseydi #90'daki kapı batch'i 400'lerdi. Viral huninin ikinci ayağı artık ölçülebilir: archetype (`archetype_completed`→`share_tapped`) + gece raporu (`report_shared`). **props YOK (bilinçli):** tek anlamlı aday gece tarihiydi → PII'ye yakın (CLAUDE.md §6) + huni için gereksiz; gerekçe dokümanda. `flutter analyze` temiz, mobil 91 yeşil, turbo 18/18, API 222. Testler: sözlük bilir; mobil paylaşımda olay izlenir, **kart 404'te olay YOK** (yalnızca gerçekten paylaşılınca sayılır). İlerleme barı değişmedi (≈45% — küçük ölçüm dilimi). PR #94.
- **#92 (mobil Gece Raporu ekranı + paylaşım — viral kanca #2):** CLAUDE.md'nin üç çekirdek viral kancasından biri (archetype kartı / **gece raporu** / mix-to-video) mobilde **hiç yüzeyi yoktu**: `nightReport()` controller'da atıl, `/v1/sharing/report` ucu (backend'de hazır) hiç tüketilmiyordu. Artık geçmişten geceye tıklayınca `/report/:night` açılıyor (süre, calm, oturum/hareket/ses) + "Share this night". Paylaşım metni **sunucudan** gelir (kart metni tek kaynak, istemcide kopya yok); `Sharer` portu ile test edilebilir. `NightReportShare` modeli + `reportShare` (404→null) + `nightReportProvider` (family) + route + geçmiş kartları tıklanabilir. **Sağlık iddiası:** calm skoru açık uyarıyla ("not a health score") sunuldu ve **testle sabitlendi**. `flutter analyze` temiz, `flutter test` 91 yeşil (85→91): gösterim, sağlık-uyarısı, boş, hata, paylaşım (sunucu metni, RecordingSharer), kart 404→paylaşım yok. Salt mobil, contract değişmedi. İlerleme barı mobil 33→35% (toplam ≈45%). PR #93. **Kapsam dışı (açıkça):** `report_shared` analitik olayı EKLENMEDİ — sözlükte yok, #90'daki kapı 400'lerdi; sözlük(API)+emisyon(mobil) birlikte ayrı PR'da gitmeli. Görsel paylaşım kartı (görüntü üretimi) + mix-to-video açık.
- **#91 (web JS bütçe kapısı + 🔴 bütçe çatışması bulgusu):** CLAUDE.md §3.4 JS<90KB kapısı **hiç kurulmamıştı**; kurmak için ölçünce **bütçenin ZATEN İHLAL EDİLDİĞİ** ortaya çıktı: ana sayfa First Load JS **103 kB** (kendi gzip metriğimizle 107 kB) = React 19 (54.2 kB) + Next 15 App Router (46 kB) + **uygulama kodu ~1 kB**. Bağımlılıklar yalnızca next/react/react-dom → kırpılacak şey yok, **90KB bu mimariyle ULAŞILAMAZ**. **Davranış:** CLAUDE.md sormadan değiştirilmedi; bütçe sessizce gerçeğe uydurulmadı. Onun yerine `check-bundle-size.mjs` + `size` turbo görevi + CI → **regresyon bekçisi** (115 kB gzip, kodda/dokümanda "hedef değil" diye etiketli). Karar insana: **DECISIONS_NEEDED.md · D-6** (bütçeyi gerçeğe çek / Astro'ya taşı / LCP-CLS üzerinden tanımla). Kapı **iki yönde doğrulandı**: eşik 115→geçer (107.0 kB, exit 0), eşik 50→exit 1. turbo 18/18 (17→18, yeni size görevi). İlerleme barı web 44→45% (toplam ≈44%). PR #92. **AÇIK:** LCP/CLS (lighthouse-ci) YAPILMADI — Chrome'lu CI job'u gerektirir, D-6'da not.
- **#90 (analitik olay sözlüğü zorlaması):** docs/01 §7'nin **belgelenmiş ama uygulanmamış** gereksinimi kapatıldı — "sözlükte olmayan event gönderilemez". Olay adı şimdiye dek YALNIZCA regex ile doğrulanıyordu (herhangi bir `[a-z0-9_.]` adı kabul). Artık `KNOWN_EVENT_NAMES` (domain, tek kaynak) + eşlenik `docs/analytics-events.md` (docs/01'in adıyla istediği dosya: sözlük tablosu, ad kuralları, **PII yasağı**, "önce sözlük sonra gönderim" sırası). `unknown_event` hata kodu; biçim kontrolünden sonra sözlük kapısı. Sözlük yalnızca **gerçekten yayılan** olayları içerir (`archetype_completed`, `share_tapped`) — spekülatif olay eklenmedi. API 222 test (217→222): sözlük bilinir/bilinmez, biçim-geçerli-ama-tanımsız, set tutarlılığı, batch tümden red; e2e unknown_event 400 + satır yazılmaz. turbo 17/17. Mobilin iki olayı da sözlükte → kırılma yok. İlerleme barı backend 72→73% (toplam ≈44%, bar 18 blok). PR #91. **Tercih (dürüstçe):** tek tanımsız olay tüm batch'i düşürür (kısmi kabul yok); istemci sözlükten önce olay eklerse o batch kaybolur — bilinçli, dokümanda yazılı.
- **#89 (mobil detayda "sana uygun sesler"):** Archetype detay ekranına o kimliğe affinity'si olan soundscape listesi (tıklayınca `/library/:slug`). #87'nin kapsam-dışı detay→içerik bağı tamamlandı; test→kimlik→içerik döngüsünün son halkası. `soundscapesForArchetypeProvider` (family: `feed(archetype)` + affinity filtresi) + `_SoundsSection` — **ikincil bölüm**: boş/yükleme/hata → gizli, detay bloklanmaz. `flutter analyze` temiz, `flutter test` 85 yeşil (82→85): liste gösterilir, boşsa gizli, hata detayı bloklamaz. İlerleme barı mobil 32→33% (toplam ≈43%). PR #90. **Not:** `soundscapeFeedProvider` zaten parametresiz → #88 ile sunucuda otomatik kişiselleşiyor, ek temizlik gerekmedi (planlanan "provider temizliği" no-op çıktı).
- **#88 (API kişiselleştirilmiş içerik feed'i):** `GET /v1/content/feed` archetype paramı yoksa kullanıcının KENDİ en son sonucuna göre sıralanır (yoksa 'all'); açık `?archetype=` önceliklidir. Ürün döngüsü: test→içerik, sunucu tarafında. `UserArchetypeReader` portu + module-def adaptörü (archetype public `GetLatestResultUseCase`; content archetype tablosuna dokunmaz — boundary lint yeşil). `GetFeedUseCase.execute(userId, explicitArchetype?)`. openapi+shared-types regen. API 217 test (213→217): reader'a düşme, explicit override, sonuç yok→all, e2e paramsız 200. turbo 17/17. İlerleme barı backend 71→72% (toplam ≈43%). PR #89. Not: cache kullanıcıya özel değil (archetype başına) → PII sızmaz; mobil feed provider'ının parametreyi bırakması ayrı.
- **#87 (mobil archetype detay ekranı):** Home kimlik kartı tıklanabilir → `/identity/:slug` detay ekranı (isim + tagline + özet, `archetypeContentProvider`'dan). #86'nın kapsam-dışı tıklaması tamamlandı. `content.when` dayanıklı: bilinen slug→içerik, bilinmeyen→"Unknown identity", hata→retry. Yeni route + `_IdentityCard` GestureDetector. `flutter analyze` temiz, `flutter test` 82 yeşil (79→82). Salt mobil, contract değişmedi. İlerleme barı mobil 31→32% (toplam ≈43%). PR #88. Not: detayda "sana uygun sesler" (affinity→soundscape) linki ayrı.
- **#86 (mobil home uyku kimliği):** Kullanıcı testi yaptıysa home'da uyku kimliği kartı (isim + tagline, `archetypeContentProvider`'dan çözülür; içerik yoksa slug fallback) + CTA "Find your sleep identity"→"Retake the test". Gerçek ürün döngüsü: `GET /v1/archetype/result` + `latestResult()` ilk kez UI'da tüketiliyor. Yeni `latestArchetypeResultProvider`, `_IdentityCard` (yükleme/hata/yok → gizli). `flutter analyze` temiz, `flutter test` 79 yeşil (76→79): kimlik kartı+Retake; sonuç yok→gizli+Find; slug fallback. Salt mobil, contract değişmedi. İlerleme barı mobil 30→31% (toplam ≈42%, bar 17 blok). PR #87. Not: kimlik kartına tıklama→detay ayrı.
- **#85 (web site geneli footer):** Ortak `SiteFooter` (root layout) — her SSG sayfasına iç bağlantı (Sleep identities / Take the test / FAQ) → SEO iç-link sinyali + keşfedilebilirlik. Semantik `<footer>` + erişilebilir `<nav aria-label="Footer">`, "relaxation & sleep ritual" dili. web 27 test (24→27: href'ler, aria-label, sağlık taraması). turbo 17/17, build tüm sayfalarda footer. İlerleme barı web 43→44% (toplam ≈41%). PR #86.
- **#84 (mobil soundscape affinity etiketi):** Kütüphane kartında `archetypeAffinity` okunur etiketle gösterilir ("For Deep Ocean · Delta Drifter") — archetype↔ses bağı (çekirdek ürün döngüsü), modeldeki alan ilk kez UI'da. `Soundscape.affinityLabel({max=2})` + `_humanizeSlug`. Kartta affinity varsa caption altyazı (yoksa gizli). `flutter analyze` temiz, `flutter test` 76 yeşil (75→76): affinityLabel ilk-2/boş + kartta var/yok. Salt mobil, contract değişmedi. İlerleme barı mobil 29→30% (toplam ≈41%). PR #85. Not: tam archetype adları (ör. "3AM Overthinker") için içerik eşlemesi ayrı.
- **#83 (API güvenlik başlıkları — B4 sertleşme):** Zero-dependency `SecurityHeadersMiddleware` (helmet YOK) — tüm rotalara, guard'lardan önce: `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: no-referrer`, `Cross-Origin-Resource-Policy: same-origin`. main.ts'te `X-Powered-By` kapatıldı (framework parmak izi). 213 test (211→213): e2e başarılı+401 yanıtta başlıklar. turbo 17/17. Contract değişmedi. **CI:** düzeltilmiş bekleme kalıbıyla (≥2 check VAR + hepsi pass) yeşil doğrulandı, sonra merge. İlerleme barı backend 70→71% (toplam ≈41%). PR #84. Not: X-Powered-By kapatma main.ts bootstrap'ında → e2e (createNestApplication) kapsamı dışında (dürüstçe). CSP/HSTS → VPS/deploy fazı.
- **#82 (mobil home streak kişisel rekor):** Streak kartı iyileştirmesi — (1) hiç kayıt yokken (totalNights=0) kart gizli (yeni kullanıcıya "0 nights streak" yerine), (2) `longest > current` ise "Best N" kişisel rekor satırı (streak/alışkanlık döngüsü). Seri kopmuş ama geçmiş varsa 0 + Best (yeniden başlamaya teşvik). `_StreakCard(current, longest)`. `flutter analyze` temiz, `flutter test` 75 yeşil (73→75): Best görünür/gizli, totalNights=0 gizli, kopmuş seri+best. İlerleme barı mobil 28→29% (toplam ≈41%). PR #83. **⚠️ SÜREÇ HATASI (dürüstçe):** merge, PR CI _pending_ iken gerçekleşti — bekleme döngüsü `gh pr checks` boş liste döndürünce (checks henüz kaydolmamış) pending=0 sanıp erken "ALL DONE" verdi. Zarar yok: merge sonrası main push CI'ı **success** doğrulandı (`gh run watch --exit-status` EXIT=0). Düzeltme: bundan sonra bekleme döngüsü "en az 1 check VAR ve hepsi pass" koşulu arayacak (boş liste ≠ yeşil).
- **#81 (web breadcrumb yayılımı):** Genel `buildBreadcrumbTrail(crumbs)` builder'ı (kök-göreli path); archetype breadcrumb'ı buna delege eder (çıktı bit-bit aynı, regresyon yok). `/faq` (Home→FAQ) ve `/archetypes` (Home→Sleep identities) sayfalarına `BreadcrumbList` eklendi — arama zenginleştirme + iç bağlantı sinyali (docs/05 §3.1). web 24 test (23→24: trail sıralı pozisyon + kök-göreli item; archetype breadcrumb delegasyonla korunur). turbo 17/17, build'de iki sayfa da static ○. İlerleme barı web 42→43% (toplam ≈40%). PR #82.
- **#80 (web SSS + FAQPage yapısal veri):** `/faq` statik SSG sayfası + `FAQPage` JSON-LD (GEO/AI-özet + arama zenginleştirme, docs/05 §4). `buildFaqJsonLd` (schema.ts tek util) + `FAQ_ITEMS` content (6 soru-cevap: ne olduğu, sleep identity, ücretsiz tier, offline ses motoru, gizlilik/ham-mikrofon-yüklenmez, paylaşım kartı). Semantik `dl/dt/dd`. `getSiteRoutes`'a `/faq` (sitemap otomatik). **Sağlık iddiası:** "relaxation & sleep ritual" dili; iki katmanlı tarama (schema banned-words blob'una FAQ + FAQ içeriğine ayrı regex). web 23 test (19→23), turbo 17/17, build'de `/faq` static ○ 164B. İlerleme barı web 40→42% (toplam ≈40%). PR #81. Not: hreflang hâlâ TR içerik gerektiriyor (ertelendi).
- **#79 (mobil haftalık trend mini-grafiği):** #78 (`GET /v1/sleep/trend`) ucunu tüketen saf Flutter bar grafiği — geçmiş ekranında istatistik başlığı ile liste arasında son 7 gecenin süresi. Harici grafik kütüphanesi YOK (maliyet disiplini): `Row`+`Container` yükseklikleri, çubuk ∝ süre, veri-yok gece ince taban (inkFaint), veri olan gece accentAurora. `WeeklyTrend`/`TrendNight` model + `SleepController.weeklyTrend` + `sleepTrendProvider`. `WeeklyTrendChart` widget. Ekranda `trend.maybeWhen` — nightsWithData=0/yükleme/hata → gizli (dayanıklı). `flutter analyze` temiz, `flutter test` 73 yeşil (71→73): veri olan trend→7 çubuk; veri yok→gizli (mevcut testlere default trend override). Salt mobil (contract değişmedi). İlerleme barı mobil 26→28% → toplam %40. PR #80. Not: eksen etiketleri / dokunma-detay / calmScore serisi ayrı.
- **#78 (haftalık uyku trendi ucu):** `GET /v1/sleep/trend` — son 7 gecenin gece-başına toplam süresi (grafik/haftalık özet için), oturumu olmayan gece 0, aynı gece toplanır. Yanıt: `nights` (eskiden yeniye, 7) + `averageDurationMinutes` (yalnızca veri olan geceler) + `nightsWithData`. Saf domain `trend.ts` (`weeklyTrend(sessions, today, days=7)` — deterministik, today parametreli, UTC takvim aritmetiği DST-güvenli). `GetWeeklyTrendUseCase` streak deseni (tz+clock ile "bugün", `[today-6..today]` `listByNightRange`'den — yeni repo metodu YOK). Controller açık DTO map (readonly→mutable), openapi+shared-types regen. 211 test yeşil (204→211: 5 unit + 2 e2e). turbo 17/17 (boundary yeşil). **Ek:** e2e'de 06:00 gece sınırı oturumu bugün/dün kovasına kaydırabildiği için kova-sabitleme yerine sınır-bağımsız (max night ≥180dk) doğrulama. Not: mobil grafik UI ayrı; calmScore trendi / aylık pencere ayrı. PR #78.
- **#77 (mobil bildirim toggle):** #75 (profil bayrağı) + #76 (gönderim enforcement) zincirinin mobil UI karşılığı — özellik artık uçtan uca çalışır. Yeni `profile` feature'ı: `Profile` modeli + `ProfileController` (`get`/`setNotificationsEnabled`, AuthController.authorizedRequest ile sarılı, sleep→profile deseni) + providers. `NoctaApiClient.patchAuthed` eklendi. Ayarlar ekranına `SwitchListTile` (profileProvider.maybeWhen — yükleme/hata → gizli dayanıklı); değişince PATCH beklenir + provider invalidate, hata → switch eski değerinde kalır + snackbar. `flutter analyze` temiz, `flutter test` 71 yeşil (69→71): tek MockClient hem auth hem apiClient'a bağlı, `/v1/profile` GET/PATCH yönlendirilir (toggle açık yansıtır; kapatınca PATCH + invalidate sonrası switch kapanır). Not: gerçek push teslimi (APNs/FCM) hâlâ docs/10; bu yalnızca tercih yüzeyi. PR #77.
- **#76 (bildirim opt-out enforcement):** #75'te eklenen `notifications_enabled` bayrağı artık gönderimde uygulanıyor (önceki iterasyonun açık bıraktığı boşluk kapatıldı). `SendNotificationUseCase` başında opt-out kısa-devresi: kullanıcı bildirimleri kapattıysa cihaz SORGULANMADAN `{sent:0,failed:0}` döner. Tercih, notification domain'ine eklenen `NotificationPreferenceReader` portu + module-def adaptörüyle (profil public `GetProfileUseCase`) okunur — notification `profiles` tablosuna DOKUNMAZ (sleep→profile timezone deseninin aynısı, modül sınırı korunur). 204 test yeşil (202→204): unit (opt-out'ta cihaz sorgusu bile yok, sender çağrılmaz) + e2e (cihaz kayıtlıyken profil kapalı → sent:0). turbo 17/17 (boundary yeşil). Contract değişmedi → shared-types regen gerekmedi. Not: gerçek APNs/FCM + BullMQ async teslim hâlâ docs/10; mobil ayar toggle'ı ayrı. PR #76.
- **#75 (profile bildirim tercihi):** `profiles.notifications_enabled` (boolean, default true) — push bildirim opt-out (docs/06). migration + prisma pull; domain Profile/defaultProfile/ProfileUpdate + repo upsert/toProfile; `UpdateProfileDto` (@IsBoolean opsiyonel) + response DTO + controller pass-through. 202 test yeşil (200→202): e2e (varsayılan true, PATCH false kalıcı, boolean-değil→400). turbo 17/17 (boundary yeşil). Not: bildirim gönderimi bu bayrağı henüz kontrol ETMİYOR (SendNotification'a gating ekleme ayrı iterasyon); mobil ayar toggle'ı ayrı.
- **#74 (mobile share_tapped analytics — viral huni):** #70 (archetype_completed) üstüne ikinci olay noktası. Archetype sonucu başarıyla paylaşılınca `share_tapped` (props: archetype slug) izlenir → viral huni ölçümü (tamamlama → paylaşım dönüşümü). Analitik bloklamaz. 69 Flutter testi yeşil (share testi zenginleştirildi): paylaşımda hem `archetype_completed` hem `share_tapped` kaydı (containsAll). `flutter analyze` temiz. Not: diğer olay noktaları (sleep_recorded, retake) + huni analizi admin panosunda (A3) ayrı.
- **#73 (mobile sleep stats başlığı):** #72 ucunu geçmiş ekranında gösterir. `SleepController.stats()` + `SleepStats` modeli + `sleepStatsProvider`. Uyku geçmişi ekranına başlık: "N nights · avg 7h 30m" (veri gelince, nights:0/yükleme/hata → gizli, dayanıklı). Paylaşılan `formatMinutes` helper'ı (SleepSession.durationText + stats başlığı ortak). 69 Flutter testi yeşil (67→69): controller stats parse + ekran başlığı gösterir. `flutter analyze` temiz. **Ek düzeltme:** geçmiş testlerinin `_pump`'ına default stats override (default apiClientProvider→FlavorConfig okuyordu). Not: haftalık trend grafiği + ortalama calmScore ayrı.
- **#72 (API sleep istatistikleri):** `GET /v1/sleep/stats` (auth) → uyku içgörüleri: `{nights (benzersiz gece), totalDurationMinutes, averageDurationMinutes}`. Saf `aggregateStats` (deterministik, oturum yoksa hepsi 0, gece Set ile tekilleştirilir, ortalama yuvarlanır) + son 100 oturum penceresi. 200 API testi yeşil (195→200): domain (boş→0, benzersiz gece + toplam/ortalama, yuvarlama) + e2e (2 gece→nights:2 total:660 avg:330, kayıtsız→0). turbo 17/17 (boundary yeşil). Not: haftalık/aylık trend + mobil stats ekranı ayrı; ortalama calmScore (rapor-bazlı) ayrı.
- **#71 (mobile analytics otomatik flush — lifecycle):** olaylar tamponlanıyor ama gönderilmiyordu → uçtan uca tamamlandı. `AnalyticsFlusher` (WidgetsBindingObserver) — uygulama arka plana geçince (paused/detached) tamponu flush eder (fire-and-forget, bloklamaz). NoctaApp'in oturum-sonrası kökü `_AppRoot` (ConsumerStatefulWidget) observer'ı kaydeder/kaldırır. 67 Flutter testi yeşil (65→67): paused/detached→flush, resumed/inactive/hidden→flush yok. `flutter analyze` temiz. Analytics artık işlevsel: olay(#70)→tampon(#51)→lifecycle flush(#71)→backend(#50). Not: periyodik flush (interval) + tampon kalıcılığı (uygulama çökerse) ayrı.
- **#70 (mobile analytics gerçek olay noktası):** #51 analytics client'ı tüketilmiyordu → ilk gerçek olay bağlandı. `Analytics` arayüzü çıkarıldı (`ProductAnalytics implements Analytics`), provider `analyticsProvider` (tip `Analytics`, test'te spy override). Archetype sonuç görüntülenince `archetype_completed` (props: archetype slug) izlenir — viral kanca ölçümü (backend #50'ye batch gider). 65 Flutter testi yeşil (64→65): sonuçta olay + props kanıtı (RecordingAnalytics). `flutter analyze` temiz. **Ek düzeltme:** ekran testlerinin `_pump`'ına analytics override eklendi (default apiClientProvider→FlavorConfig'i okuyordu, testte bootstrap yok). Not: otomatik flush (app lifecycle) + diğer olay noktaları (sleep_recorded, share_tapped) ayrı iterasyon.
- **#69 (shared-types sözleşme senkronu — bakım borcu):** Defalarca "shared-types regen ertelendi" diye not düşülmüştü; `gen:api-types` çalıştırıldı → OpenAPI (`apps/api/openapi.json`) + üretilen TS istemci (`packages/shared-types/src/generated/api.ts`) tüm yeni uçlarla senkronlandı: auth/sessions(+revoke-others), archetype/content, sharing/report, sleep/{sessions,report,streak}, analytics/events vb. (+1636/-132 satır). turbo 17/17 (üretilen tipler temiz typecheck/build). 195 test korundu. Not: henüz TS TÜKETİCİ yok (admin/web ileride import edecek) — bu saf sözleşme hijyeni; Dart client hâlâ Java-bloke (B-3).
- **#68 (API test bildirimi ucu):** `POST /v1/notifications/test` (auth) → mevcut fan-out use case'i (#35) kullanıcının KENDİ cihazlarına test push gönderir (`{sent, failed}`, userId scope). Fan-out çekirdeği artık uçtan uca tetiklenebilir (log-adaptörü ile). `TestNotificationDto` (title 1-80, body 1-240 validasyon). 195 test yeşil (191→195): e2e (401 auth-yok, cihazsız sent:0, **2 cihaz→sent:2**, boş başlık 400). turbo 17/17 (boundary yeşil). Not: gerçek APNs/FCM gönderimi + asenkron BullMQ teslim docs/10'da; mobil "test push" ayar butonu ayrı.
- **#67 (mobile settings — aktif cihaz sayısı):** #66 ucunu tüketir. `AuthController.listSessions()` + `SessionInfo` modeli + `activeSessionsProvider`. Settings ekranı "Active devices: N" gösterir (veri gelince; yükleme/hata → gizli, dayanıklı). Revoke sonrası liste `ref.invalidate` ile güncellenir. 64 Flutter testi yeşil (62→64): controller listSessions parse + ekran cihaz sayısı gösterir. `flutter analyze` temiz. Identity oturum yönetimi tam: revoke(#64)+list(#66)+mobil UI(#65,#67). Not: cihaz başına detay/tekil iptal UI ayrı.
- **#66 (identity — aktif oturum listeleme):** `GET /v1/auth/sessions` (auth) → kullanıcının aktif oturumları (family başına: familyId + createdAt + expiresAt). **Token/hash HİÇ dışa verilmez** (yalnızca meta). #64 revoke + #65 mobil UI'nin tamamlayıcısı ("cihazları yönet"). `listActiveByUser` repo (in-memory + Prisma: user + revoked_at null + expires_at>now, createdAt desc). 191 test yeşil (186→191): use case unit (yalnızca aktif, iptal/süre-dolmuş/başka-kullanıcı hariç + token sızmaz + sıralama + boş) + e2e (401 auth-yok, kayıt sonrası ≥1 oturum, refresh token sızmaz). turbo 17/17 (boundary yeşil). Not: "current" işareti yok (access token family taşımaz — güvenli, GET'te refresh token istenmez); mobil cihaz listesi UI ayrı.
- **#65 (mobile "diğer cihazlardan çık" akışı):** #64 backend'ini tüketir. `AuthController.revokeOtherSessions()` — refresh token'ı `authorizedRequest` closure'ında GÜNCEL okur (401 refresh rotasyonundan sonra eski token gönderilmez, ince hata önlendi). `SettingsScreen` — "Log out other devices" butonu → çağırır → "N other device(s) signed out" SnackBar (hata→uyarı). `/settings` route + home "Settings" (ghost) butonu. 62 Flutter testi yeşil (59→62): controller revoke (güncel refresh token + revoked sayısı) + ekran akışı (çoğul/tekil SnackBar). `flutter analyze` temiz. Not: oturum listeleme UI (aktif cihazlar) backend listeleme ucu gelince.
- **#64 (identity — diğer cihazlardan çık):** hesap güvenliği (docs/06). `POST /v1/auth/sessions/revoke-others` (auth) — kullanıcı mevcut refresh token'ını sunar; o family HARİÇ TÜM aktif oturumları iptal eder (`{revoked: N}`). **Güvenlik:** token geçersiz/iptal/süresi-dolmuş ya da BAŞKA kullanıcıya aitse → 401 (access-token sahibi refresh token'ın sahibi olmalı, izolasyon). `revokeAllExceptFamily` repo (in-memory + Prisma, userId+family!=keep+aktif). Auth kodu tek yerde (identity, CLAUDE.md §6). 186 test yeşil (179→186): use case unit (çok-family iptal + u2 izole + geçersiz/başka-kullanıcı/iptal/süre-dolmuş → hata) + e2e (401 auth-yok, revoked:0 tek-oturum, geçersiz token 401). turbo 17/17 (boundary yeşil). Not: oturum LİSTELEME ucu + mobil "log out everywhere" UI ayrı.
- **#63 (web archetype iç bağlantı):** SEO internal linking (docs/05). Her `/a/{slug}` landing sayfasının altına "Other sleep identities" — diğer 3 archetype'a `<Link>` (kendisi hariç, `<nav aria-label>`). Arama motorlarına küme sinyali + kullanıcı gezinme. 19 web testi yeşil (18→19): diğerlerine link verir + doğru href, kendi sayfasına link VERMEZ. turbo 17/17. Not: statik bileşen; content tek kaynak (content/archetypes.ts).
- **#62 (mobile archetype sonuç zenginleştirme):** #61 content ucunu tüketir (backend→UI). `ArchetypeController.fetchContent()` (`GET /v1/archetype/content`) + `ArchetypeInfo` modeli + `archetypeContentProvider` (slug→info haritası). Sonuç ekranı artık isim + **tagline + özet** gösterir (içerik geldiyse; yoksa yalnızca title-case ad — dayanıklı `maybeWhen`). 59 Flutter testi yeşil (58→59): controller fetchContent parse + ekran tagline gösterir (tam akış). `flutter analyze` temiz. Not: içerik yüklenemezse sessizce ad'a düşer (sonuç kritik yolda değil).
- **#61 (API archetype tanıtım içeriği):** `GET /v1/archetype/content` (**PUBLIC**, auth yok) → 4 archetype'ın isim/tagline/özet'i. Sonuç ucu yalnızca slug+skor dönüyordu; mobil sonuç ekranı + paylaşım kartı için isim/açıklama tek kaynağı. `ARCHETYPE_INFO` domain sabiti (sağlık-iddiası-uyumlu) + `getArchetypeInfo`/`hasAllArchetypeInfo`. Ayrı guard'sız `ArchetypeContentController` (route çakışması yok: content vs questions/answers/result). 179 test yeşil (175→179): domain (tüm slug tanımlı, getInfo, **yasak kelime**) + e2e (public 200 auth-yok, 4 içerik). turbo 17/17 (boundary yeşil). **DÜRÜSTLÜK:** web SSG kendi kopyasını tutuyor (content/archetypes.ts) — çift kaynak; ileride shared paket/CMS ile birleşir (defterde). shared-types regen ertelendi (TS tüketici yok).
- **#60 (mobile uyku geçmişi ekranı):** #47 veri katmanı üstüne. `SleepHistoryScreen` (ConsumerWidget) — `recentSleepSessionsProvider` (FutureProvider→recentSessions) izler: oturumlar gece tarihi + süre ("7h 42m") ile listelenir; boş/yükleme/hata(retry). `SleepSession.durationText` getter (dakika→"7h 42m"). `/sleep` route + home "Sleep history" (ghost) butonu. 58 Flutter testi yeşil (54→58): durationText biçim, liste (gece+süre), boş→empty, hata→retry. `flutter analyze` temiz. Mobil sleep yüzeyi: veri katmanı(#47)+streak(#48)+geçmiş(#60). Not: gece-aralığı takvim filtresi (#59 API) + oturum detayı/rapor ekranı ayrı; kayıt akışı (mikrofon/alarm) on-device motor ile.
- **#59 (API sleep gece-aralığı filtresi):** `GET /v1/sleep/sessions?from=YYYY-MM-DD&to=YYYY-MM-DD` — gece aralığı sorgusu (geçmiş/takvim görünümü). `from`+`to` birlikte + geçerli format + `from<=to` olmalı; aksi 400 invalid_range. Yalnızca biri → recent'e düşmez, 400. Aralık yoksa mevcut recent(limit) davranışı korunur. `listByNightRange` repo (userId-scoped, night_date gte/lte). `ListSleepSessionsUseCase` opts (limit|from+to). 175 test yeşil (170→175): use case routing (aralık vs recent, clamp, yalnız-from) + e2e (aralık filtresi yalnızca içi, geçersiz param 400). turbo 17/17 (boundary yeşil). Not: sayfalama (cursor) + mobil geçmiş ekranı ayrı.
- **#58 (web archetype dizin sayfası):** SEO iç bağlantı (docs/05). `/archetypes` SSG sayfası — 4 archetype'ı name+tagline ile listeler, her biri `/a/{slug}`'a link + teste CTA. `ItemList` JSON-LD (sıralı liste, arama zenginleştirme). routes/sitemap'e `/archetypes` (3 sabit + N). 18 web testi yeşil (17→18): ItemList builder + routes (dizin dahil, sayı tutarlı) + yasak kelime. **Kanıt:** üretilen HTML'de ItemList JSON-LD + 4 archetype adı; build 17 sayfa. turbo 17/17. Not: programatik long-tail sayfalar + blog (docs/05) ayrı; hreflang TR içeriği gelince.
- **#57 (mobile home haftalık yayın kartı):** docs/01 "haftalık soundscape içerikleri" (retention). `weeklyReleaseProvider` (FutureProvider→weekly). Home'a `_WeeklyCard` — yayın varsa "This week" + notes (yoksa "N soundscapes this week"), kütüphaneye tıklanabilir. **Dayanıklı:** yükleme/hata/null → gizli (maybeWhen orElse), home BLOKLANMAZ. 54 Flutter testi yeşil (52→54): kart notes gösterir, null→gizli home render. `flutter analyze` temiz. Mevcut streak/NoctaApp testleri korundu (weekly session-yok→hata→gizli). Not: haftalık yayın oluşturma admin CMS'te (A1); kart→ilk soundscape derin link ayrı.
- **#56 (mobile soundscape detay ekranı):** #55 kütüphane üstüne. `SoundscapeDetailScreen(slug)` — `soundscapeDetailProvider` (family) izler: başlık + preset sayısı ("1 preset"/"N presets") + "Preview available" (previewUrl varsa). Yok/404→null → "not found", hata→retry. `/library/:slug` route; kütüphane item'ları artık tıklanabilir (`context.push('/library/{slug}')`). 52 Flutter testi yeşil (48→52): detay (başlık+preset+preview), previewUrl yok→gösterge yok, 404→not found, hata→retry. `flutter analyze` temiz. Not: preview OYNATMA (on-device ses motoru/mikser) ayrı; başlık 'en' (l10n M1).
- **#55 (mobile soundscape kütüphane ekranı):** #54 veri katmanı üstüne. `SoundscapeLibraryScreen` (ConsumerWidget) — `soundscapeFeedProvider` (FutureProvider→feed) izler: liste (NCard başlıklar), boş durum, yükleme spinner, hata retry. `/library` route + home "Browse soundscapes" (ghost) butonu `context.push`. 48 Flutter testi yeşil (45→48): feed listelenir, boş→empty state, hata→retry. `flutter analyze` temiz. Not: soundscape detay/mikser ekranı + previewUrl oynatma (on-device ses motoru) ayrı; başlık 'en' sabit (l10n M1).
- **#54 (mobile content veri katmanı):** content API'sini tüketen `ContentController` (docs/04): `feed({archetype})` (affinity sıralı liste), `soundscape(slug)` (detay+preset+previewUrl, 404→null), `weekly()` (haftalık yayın, 404→null). Tümü `authorizedRequest` (401 refresh). Interim modeller: `Soundscape` (+`title(locale)` fallback en→slug), `Preset`, `SoundscapeDetail`, `WeeklyRelease`. 45 Flutter testi yeşil (41→45): feed (archetype query + title fallback), feed archetype-yok query eklenmez, detay 200/404, weekly 200/404. `flutter analyze` temiz. Not: soundscape kütüphanesi/mikser UI + on-device ses motoru (engineParams/layerDefs) ayrı; presigned previewUrl oynatma ayrı.
- **#53 (mobile flags client):** #52 üstüne. `FeatureFlagsController` — `GET /v1/flags` context'iyle (platform + appVersion query) değerlendirilmiş haritayı çeker (`authorizedRequest` → 401 refresh). `isEnabled(key)` bilinmeyen/çekilmemiş anahtarda güvenli **false** varsayılan. Provider platform'u `dart:io Platform` (ios/android/flutter) + `kAppVersion` ile geçer. 41 Flutter testi yeşil (38→41): çekmeden false, refresh (context query gönderir + parse), 500→hata (flag'ler varsayılan kalır). `flutter analyze` temiz. Not: flag'e göre UI gating (gerçek özellik kapıları) + açılışta otomatik refresh ayrı iterasyon.
- **#52 (flags segment hedefleme):** docs/03 A4 (kısmi). `evaluateFlag`'e segment kapıları: `platforms` allowlist + `minAppVersion` (semver `compareVersions`). İstemci context'i `GET /v1/flags?platform=ios&appVersion=1.5.0` query ile geçer. **FAIL-CLOSED:** kural platform/sürüm istiyor ama context yoksa flag KAPALI (güvenli varsayılan). `parseRules` yeni alanları güvenli okur. Geriye dönük uyumlu (ctx opsiyonel, kural yoksa eski davranış). 170 test yeşil (159→170): segment (eşleşen/eşleşmeyen/context-yok), compareVersions (küçük/eşit/büyük/farklı-uzunluk), segment+rollout birlikte, parseRules, e2e (query ile ios/android + sürüm kapıları). turbo 17/17 (boundary yeşil). Not: archetype segmenti + tam kural motoru (AND/OR) + flag YAZMA (admin) sonraki A4 parçaları.
- **#51 (mobile analytics client):** `ProductAnalytics` — olayları tamponlar, batch olarak `/v1/analytics/events`'e gönderir (`authorizedRequest` → 401 refresh). `track(name, props?)` + `flush()` (202→temizle, aksi→tampon korunur/tekrar denenir; analitik uygulamayı bloklamaz). Tampon sınırı 100 (en eski düşer). PII gönderilmez. Clock enjekte (occurredAt deterministik). 38 Flutter testi yeşil (34→38): track+flush (Bearer+gövde+occurredAt+temizlenir), boş→çağrı yok, 500→tampon korunur, tampon cap. `flutter analyze` temiz. Not: otomatik flush zamanlaması (app lifecycle/interval) + gerçek olay noktalarına bağlama (archetype tamamlandı vb.) ayrı iterasyon.
- **#50 (analytics-ingest modülü):** docs/02 analytics-ingest. `POST /v1/analytics/events` (auth, 202) → ürün olay batch'ini yutar: `{events: [{name, occurredAt, props?}]}`. Ad doğrulama `^[a-z0-9_.]{1,64}$` (ör. archetype_completed), batch 1-100 (DoS sınırı), tipli hata (empty_batch/batch_too_large/invalid_event_name → 400). `analytics_events` migration (FK cascade, name+time & user index) + prisma pull. **PII taşımaz** — yalnızca olay adı+zaman+serbest props (body-size #29 ile sınırlı). 159 test yeşil (149→159): domain (ad validasyonu, batch cap, boş) + e2e (202+DB kalıcılık, boş/geçersiz ad 400, 401). turbo 17/17 (boundary yeşil). Admin metrik panoları (D7 retention/funnel) bunu tüketecek (A3). Not: sunucu-tarafı olay üretimi (outbox) + retention sorguları ayrı.
- **#49 (sharing gece raporu kartı):** viral kanca #2 paylaşımı. `GET /v1/sharing/report?night=YYYY-MM-DD` (auth) → gece raporundan paylaşım kartı: `{nightDate, title "My night: 7h 42m", subtitle "Calm 85/100 · NOCTA sleep ritual", durationText, calmScore, webUrl (indirme CTA), deepLink nocta://report/{night}}`. Saf `buildNightReportShare`+`formatDuration`. **ÜÇÜNCÜ cross-module:** sharing, sleep'in public `GetNightReportUseCase`'ini module-def adapter ile okur (sleep barrel + exports). Rapor yoksa 404 no_report, geçersiz night 400. **Sağlık iddiası yok** (süre + göreli calm, DTO/kart metninde). 149 test yeşil (141→149): domain (formatDuration saat/dk, kart alanları, yasak kelime) + e2e (uyku kaydından sonra kart 7h 30m, 404, 400). turbo 17/17 (boundary yeşil). Not: kart GÖRSELİ (OG/canvas render) ve mix-to-video ayrı; kişisel rapor web sayfası yok (deep-link app-only).
- **#48 (mobile home streak kartı):** #47 veri katmanı üstüne. `streakProvider` (FutureProvider → sleep streak). Home artık `ConsumerWidget`: streak verisi gelince "N nights streak" kartı gösterir; **yükleme/hata → gizli (SizedBox.shrink), home BLOKLANMAZ** (maybeWhen orElse). 34 Flutter testi yeşil (31→34): streak kartı görünür, tekil "night streak", **hata home'u bloklamaz** (kart gizli, NOCTA yine render). `flutter analyze` temiz. Not: tam uyku ekranı (oturum listesi + rapor + kayıt akışı) ayrı; mikrofon takibi on-device DSP ayrı.
- **#47 (mobile sleep veri katmanı):** sleep API'sini tüketen `SleepController` (docs/04): `recordSession` (POST, türetilmiş metrikler — ham ses ASLA), `recentSessions` (liste), `nightReport(night)` (200/404→null), `streak`. Tümü `AuthController.authorizedRequest` ile 401→refresh+retry. Interim modeller (SleepSession/NightReport/StreakStats). 31 Flutter testi yeşil (27→31): kayıt (Bearer+gövde+parse), liste, rapor 200/404, streak. `flutter analyze` temiz. Not: uyku/streak UI ekranları + mikrofon takibi (on-device DSP) ayrı iterasyonlar; üretilen Dart client (B-3) gelince modeller swap.
- **#46 (streak/habit hesabı):** `GET /v1/sleep/streak` (auth) → `{current, longest, totalNights}`. Saf `computeStreak(nightDates, today)`: benzersiz gece tarihlerinden ardışık seriler (epoch gün farkı=1). "Bugün" kullanıcı timezone'una göre `nightDateOf(now, tz)` ile; seri son gece bugün VEYA dün ise canlı (bugün henüz uyunmadıysa kopmaz), yoksa current=0. `Clock` portu enjekte (test deterministik; module gerçek `() => new Date()`). `listNightDates` repo (distinct night, userId-scoped, son 400). 141 test yeşil (132→141): computeStreak unit (canlı/kopmuş/boşluklu longest>current/tekrar tekilleştirme/ay-sınırı) + e2e (kayıtsız 0, bu-geceki oturumdan sonra current≥1). turbo 17/17. Not: streak koruma (freeze) / rozet ayrı; UI ayrı iterasyon.
- **#45 (gece raporu):** `GET /v1/sleep/report?night=YYYY-MM-DD` (auth) → o gecenin oturumlarını tek rapora indirger: sessionCount, totalDurationMinutes, movement/soundEvents toplamı, `calmScore` (0-100 göreli dinginlik — **SAĞLIK ÖLÇÜSÜ DEĞİL**, "relaxation & sleep ritual" çerçevesi, DTO'da açıkça belirtildi). Saf `buildNightReport`+`calmScore` (deterministik). `findByNight` repo metodu (userId+night scoped). Oturumsuz gece→404 no_report, geçersiz night→400 invalid_night. 132 test yeşil (124→132): report domain (toplama, calmScore sınır/clamp, boş→null) + e2e (rapor özeti, 404, 400). turbo 17/17 (boundary yeşil). Not: paylaşılabilir kart görseli/OG + streak ayrı; calmScore formülü ürün ayarı (saat başına rahatsızlık).
- **#44 (sleep modülü — uyku oturumu kaydı):** docs/02 B. `POST /v1/sleep/sessions` (auth) → türetilmiş metriklerle kayıt: süre started/ended'den SUNUCUDA hesaplanır, gece etiketi `nightDateOf` (#43) + kullanıcı timezone ile write-time türetilir. `GET /v1/sleep/sessions?limit=` (en yeni, userId-scoped). `sleep_sessions` migration (FK cascade, user+night index) + prisma pull. **İKİNCİ cross-module:** sleep, profile'ın public `GetProfileUseCase`'inden timezone okur (module-def adapter; profiles tablosuna dokunmaz). profile barrel + `exports:[GetProfileUseCase]`. **KVKK/§6:** ham mikrofon verisi HİÇ uğramaz — yalnızca türetilmiş sayılar (hareket/ses olay sayısı). 124 test yeşil (117→124): domain (süre/aralık) + e2e (kayıt+gece etiketi Istanbul tz, invalid_range 400, negatif olay 400, liste izolasyon "B, A'yı göremez"). turbo 17/17 (boundary yeşil). Not: akıllı alarm + rapor üretimi + streak ayrı iterasyonlar.
- **#43 ("gece" gruplama saf fonksiyonu):** CLAUDE.md §4 — uyku oturumlarının "gece" tanımı TEK paylaşılan fonksiyonda: `nightDateOf(instant, timezone)` → `YYYY-MM-DD` gece etiketi. Kural: yerel saat < 06:00 ise önceki takvim gününün gecesi (akşam→sabah sarkan uyku aynı gece), 06:00+ o gün. Intl ile yerel Y/M/D/H, takvim aritmetiği UTC epoch üzerinde (DST-güvenli, duvar-saati kaydırılmaz). `shared/time/` (sleep/sharing/analytics ortak kullanır). 117 test yeşil (109→117, +8): akşam/gece-yarısı/sınır(05:59 vs 06:00)/farklı-tz/ay-sınırı/yıl-sınırı/UTC. turbo 17/17. Not: sleep modülü gelince oturum gruplaması bu fonksiyonu çağıracak (henüz tüketici yok — §4'ün zorunlu kıldığı ön koşul).
- **#42 (profile timezone/locale doğrulama):** `locale`/`timezone` alanları zaten vardı ama yalnızca `IsString`+`MaxLength` ile — geçersiz saat dilimi kabul ediliyordu. Custom validator'lar eklendi: `IsIanaTimeZone` (Intl ile geçerli IANA tz doğrular) + `IsBcp47Locale` (Intl.getCanonicalLocales ile dil etiketi). "Gece" gruplaması (kullanıcı yerel günü, 06:00 sınırı — CLAUDE.md §4, sleep modülü ön koşulu) geçerli tz'ye bağlı olduğundan veri bütünlüğü. **Boundary:** validator'lar profile presentation'a konuldu (presentation→shared YASAK olduğu doğrulandı; module-local YAGNI çözüm, config gevşetilmedi). 109 test yeşil (102→109): validator unit (geçerli/bozuk tz+locale) + e2e (geçersiz tz/locale 400, geçerli tr kalıcı). turbo 17/17 (boundary yeşil).
- **#41 (web `/a/{slug}` paylaşım butonu):** viral kanca (docs/05). Client `ShareButton` — Web Share API varsa OS paylaşım sayfası, yoksa link'i panoya kopyalar (masaüstü fallback, "Link copied"). `ArchetypeContent`'e teste-CTA yanına yerleştirildi (`My sleep identity is {name}` + `{SITE_URL}/a/{slug}`). 17 web testi yeşil (15→17): Web Share yolu (title+url ile navigator.share) + clipboard fallback (writeText + "Link copied"). turbo 17/17. Not: `navigator.share` iptal/başarısızlıkta panoya düşer; boş catch yok (`.then(ok,fail)` deseni).
- **#40 (mobile archetype — mevcut sonuç + retake):** açılışta `latestResult` kontrolü: kayıtlı sonuç varsa doğrudan gösterilir (dönen kullanıcı sihirbazı atlar), yoksa soru sihirbazı yüklenir. Sonuç ekranına "Retake test" butonu (ghost) → sonucu temizle + soruları yeniden yükle. 27 Flutter testi yeşil (25→27): kayıtlı sonuç→sihirbaz atlanır, retake→sihirbaza döner. `flutter analyze` temiz. Not: sunucu her yeni testte sonucu üzerine yazar (archetype_results latest); geçmiş sonuç saklama/karşılaştırma kapsam dışı.
- **#39 (mobile paylaşım — sonuç ekranı share):** #38 API + #37 UI üstüne. `ArchetypeController.fetchShare()` (`GET /v1/sharing/archetype`, 404→null). `Sharer` portu + `ClipboardSharer` (interim: link'i panoya kopyalar, bağımlılıksız). Sonuç ekranına "Share my identity" butonu → share kartını çek → sharer.share → "Link copied" SnackBar. 25 Flutter testi yeşil (23→25): controller fetchShare 200/404, ekran paylaş akışı (recording sharer web URL alır + SnackBar). `flutter analyze` temiz. **DÜRÜSTLÜK:** native OS paylaşım sayfası (share_plus) ERTELENDİ — interim panoya kopyalama; `Sharer` portu sayesinde tak-çıkar. OG görsel/mix-to-video export ayrı.
- **#38 (API sharing modülü — archetype paylaşım kartı):** viral kanca (docs/02 sharing). `GET /v1/sharing/archetype` (auth) → kullanıcının archetype sonucundan paylaşım kartı: `{archetypeSlug, title, description, webUrl, deepLink}` (web `/a/{slug}` + `nocta://a/{slug}`); sonuç yoksa 404. Saf domain `buildArchetypeShare` + `slugToDisplayName`. **İLK cross-module entegrasyon:** sharing kendi `ArchetypeResultReader` portunu tanımlar, module-def seviyesinde archetype'ın public `GetLatestResultUseCase`'ine adapte eder (boundary: application→module-api yasak, module-def→module-api serbest — archetype tablosuna DOKUNMAZ). archetype `index.ts` barrel + `exports:[GetLatestResultUseCase]`. `WEB_BASE_URL`/`APP_DEEPLINK_SCHEME` env. 102 test yeşil (95→102): domain (URL/başlık/slash-temizleme/yasak-kelime) + e2e (401/sonuçsuz 404/test sonrası kart, gerçek DB cross-module). turbo 17/17 (boundary lint yeşil). Not: shared-types regen ertelendi (henüz TS tüketici yok); OG görsel/mix-to-video paylaşımı ayrı.
- **#37 (mobile archetype test UI):** #36 veri katmanı üstüne ekran (docs/04 M1, viral kanca #1). `ArchetypeTestScreen` (ConsumerStatefulWidget): soruları yükle→her soruya bir seçenek (seçili=primary, diğeri=ghost)→gönder→sonuç kartı (slug→görünen ad). Yükleme spinner / hata retry durumları. `/archetype` route + home "Find your sleep identity" butonu `context.push` ile bağlandı. 23 Flutter testi yeşil (22→23): widget testi soru yükleme + **gating** (cevapsız submit→sonuç yok) + seç→gönder→sonuç ("Deep Ocean") tam akış. `flutter analyze` temiz. Not: l10n yok (M0 hard-coded deseni), sonuç paylaşım kartı (mix-to-video/OG) ayrı iterasyon.
- **#36 (mobile archetype test veri katmanı):** archetype akışı (docs/04 M1): soru çek→cevapla→sonuç. `NoctaApiClient.getAuthed/postAuthed` (Bearer'lı ham yanıt). `ArchetypeController` (fetchQuestions/submitAnswers/latestResult) — tümü `AuthController.authorizedRequest` ile sarılı → **401'de otomatik refresh+retry**. Interim modeller (ArchetypeQuestions/Question/Option/Result). 22 Flutter testi yeşil (18→22): Bearer header + parse, cevap gövdesi + sonuç (201), latestResult 200/404→null, **401→refresh→retry entegrasyon**. `flutter analyze` temiz. Not: UI ekranları (soru sihirbazı + sonuç kartı) sonraki iterasyon; üretilen Dart client (B-3) gelince modeller swap.
- **#35 (notification fan-out çekirdeği):** push fan-out (docs/02 B3). `PushSender` portu + `PushMessage`/`PushTarget` + `SendNotificationUseCase` (kullanıcının tüm cihazlarına gönderir, hedef başına İZOLE — biri düşse diğerleri devam, `{sent, failed}` döner) + `LogPushSender` adaptörü (gerçek APNs/FCM yerine loglar, tam token loglamaz — yalnızca son 4 hane). `DeviceTokenRepository.findTokensByUser` (userId scoped) eklendi. Modül `SendNotificationUseCase`'i dışa açar (kampanya/domain-event tetikleyicileri için). 95 test yeşil (91→95): fan-out sayımı, kısmi hata izolasyonu, cihazsız no-op, log-sender no-throw. turbo 17/17. **DÜRÜSTLÜK:** SENKRON gönderir — asenkron güvenilir teslim (BullMQ + Redis worker + outbox) ve gerçek APNs/FCM + tetikleyici uç **docs/10'a ertelendi**.
- **#34 (web structured data genişletme):** SEO/GEO (docs/05 §3.1). Root layout'a site geneli `Organization` + `WebSite` JSON-LD (her sayfada); archetype sayfasına `BreadcrumbList` (Home→archetype) — mevcut Article'a ek. Tümü tek util'den (`schema.ts`), sağlık-iddiası-yok dili. 15 web testi yeşil (11→15): builder şekil + breadcrumb pozisyon + **yasak kelime taraması** (cure/treat/therapy/clinically/medical/disease JSON-LD'de yok). **Kanıt:** üretilen HTML'de archetype = Article+BreadcrumbList+Organization+WebSite, home = Organization+WebSite. turbo 17/17. Not: FAQPage EKLENMEDİ — içerikte gerçek soru/cevap yok, uydurmak düşük kalite/yanıltıcı (dürüstlük); FAQ içeriği yazılınca eklenir.
- **#33 (admin feature-sliced boundary lint):** admin A0 (docs/03 §3.3). Feature-sliced katmanlar kuruldu: `AppShell`→`shared/ui/`, dashboard→`features/dashboard/DashboardPage`, `app/page.tsx` ince kompozisyon. `eslint-plugin-boundaries` + TS resolver ile sınırlar zorlanıyor: app→features→entities→shared (üst→alt izinli, ters YASAK). **Kanıtlandı:** shared→features ihlali YAKALANIYOR (`No rule allowing this dependency ... type 'shared' ... Dependency 'features'`), temiz kod geçiyor. turbo 14/14 (typecheck/lint/build) + 91 test korundu. Not: `entities/` katmanı config'de tanımlı ama henüz dosyasız (A1 içerik CMS'inde dolacak). Admin auth guard/RBAC (API admin uçları gerektirir) ayrı iterasyon.
- **#32 (content feed cache — port + in-memory):** `Cache` portu (`get/set/del`, TTL) + `InMemoryCache` (TTL, enjekte edilebilir saat) + global `CacheModule`. `GetFeedUseCase` archetype başına 5dk cache'ler (`content:feed:{archetype|all}`; feed global içerik, presigned URL yok → TTL güvenli, userId scoping gerekmez). 91 test yeşil (84→91): cache unit (set/get/TTL-expiry/del), feed-cache unit (aynı archetype→repo tek kez, farklı archetype→ayrı anahtar, TTL geçince yeniden sorgu). turbo 17/17. **DÜRÜSTLÜK NOTU:** Bu Redis DEĞİL — in-memory (tek instance), idempotency interceptor'la aynı desen. **Redis adaptörü B4'te** bu port'un arkasına takılacak (ioredis + CI service gerektirir; ayrı iterasyon). Cache invalidation (admin içerik yayınında `del`) admin CMS gelince (A1).
- **#31 (mobile refresh-token interceptor):** 401'de otomatik token yenileme (docs/04 M0). `NoctaApiClient.refresh()` (`POST /v1/auth/refresh` → yeni Session; reuse/geçersiz → ApiException). `AuthController.authorizedRequest(send)`: access token ile gönderir, 401'de bir kez refresh dener + yeni token'ları saklar + isteği tekrarlar; refresh de başarısızsa signOut + hata iletir. 18 Flutter testi yeşil (13→18): client refresh 200/401, authorizedRequest 401→refresh→retry (token'lar kalıcı) / reuse→signOut / 200→refresh yok. `flutter analyze` temiz. Not: interim http seam; generated client + Dio interceptor'a geçince değişir. Eşzamanlı 401 tek-uçuş (single-flight) dedup ileride.
- **#30 (mobile açılış oturum wiring):** `ensureSession` artık açılışa bağlı (docs/04 M0). `DeviceIdentity` (get-or-create, `Random.secure` ile 32-hex anonim id, kalıcı — uuid bağımlılığı YOK, PII değil) + `KeyValueStore` soyutlaması (in-memory/secure). `sessionBootstrapProvider` (FutureProvider): device-id çözer → `ensureSession`. `NoctaApp` artık `ConsumerWidget` gate: yükleme→spinner, hata→retry, veri→router. 13 Flutter testi yeşil (4→13): device_identity unit (üret/kalıcı/seed), gate widget (splash→home, restore→register yok). `flutter analyze` temiz. Not: l10n yok (M0 hard-coded desen sürüyor) → splash metinsiz tutuldu; gerçek secure storage cihazda doğrulanır.
- **#29 (request boyut limiti):** DoS sertleşme (docs/02, "Sıradaki iş" #4). `MAX_REQUEST_BODY_BYTES` env (64kb default); main.ts `bodyParser: false` + elle limitli `json`/`urlencoded`. `ProblemDetailsFilter` genişletildi: http-errors tarzı hatalar (body-parser'ın `PayloadTooLargeError`'ı — HttpException DEĞİL) `statusCode`/`expose` üzerinden doğru statüye eşlenir. 84 test yeşil (e2e: 1kb limitle >1kb gövde → 413 problem+json, limit altı normal). Body-parser hatasının global filtreye ULAŞTIĞI ampirik doğrulandı. Not: rate-limit Redis'e taşıma + feed cache hâlâ B4'te.
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
- **#28 (correlation-id + access log):** `RequestIdMiddleware` — her isteğe `x-request-id` (verilirse echo, yoksa üretir) + prod'da erişim logu (method/url/status/ms). **Middleware olarak** (guard'lardan önce) → 401/403 dahil TÜM yanıtlarda header (interceptor guard'dan sonra çalıştığı için yetersizdi — düzeltildi). Sentry bu id'yi tag olarak kullanacak. 82 test yeşil (üretim/echo/401'de header). Test'te log susturulur.
- **#27 (Idempotency-Key desteği):** global `IdempotencyInterceptor` — `Idempotency-Key` header'lı POST'lar cache'lenir (5dk TTL); aynı anahtar tekrar gelirse handler ATLANIR, ilk yanıt döner (yeni işlem yok). Mobil offline kuyruğunun retry güvenliği (docs/02 §4). 79 test yeşil (e2e: aynı anahtar→aynı slug + tek DB satırı; anahtarsız→yeni slug). Not: in-memory (tek instance); dağıtık Redis cache B4.
- **#26 (mobile session kalıcılığı):** `SessionStore` soyutlaması (`InMemorySessionStore` test + `SecureSessionStore` flutter_secure_storage prod). AuthController `restore`/`ensureSession` (kayıtlı oturum varsa yeniden kaydolmaz) + `signOut` temizler. 8 test yeşil (kayıt→store'a yazılır; ikinci açılış restore, API çağrısı yok). Not: secure storage cihazda doğrulanır (platform channel; test soyutlama üzerinden).
- **#25 (content weekly release):** `GET /v1/content/weekly` (kimlik doğrulamalı) → en güncel haftalık soundscape yayını (yayınlanmış soundscape'lerle çözülür, yoksa 404). `weekly_releases` tablosu. 78 test yeşil (e2e: 401/en güncel yayın + soundscape çözümü, far-future week_start ile deterministik). Not: haftalık yayın oluşturma admin CMS'te (A1).
- **#24 (web OG image):** `next/og` `ImageResponse` ile site OG (`/opengraph-image`) + per-archetype OG (`/a/{slug}/opengraph-image`, 4 archetype) — token renkleri, viral paylaşım kartı hedefi (docs/05 §3.1). `generateStaticParams` ile build'de static üretim (16 sayfa). Not: görsel doğrulama BUILD ile (render başarılı); vitest testi yok (ImageResponse build-time route). turbo 17/17.
- **#23 (RFC 7807 problem+json):** global `ProblemDetailsFilter` — tüm API hatalarını `application/problem+json` (type/title/status/detail/code) formatına çevirir (docs/02 §4). Controller'ların domain hata `code`'u korunur (istemci dallanması). Beklenmeyen hata teknik detayı loglanır, istemciye sızmaz. 76 test yeşil (e2e: 401 problem+json, 400 validasyon detail, refresh reuse → code passthrough). main.ts'e global filter.
- **#22 (notification token kaydı):** `POST /v1/notifications/token` (kimlik doğrulamalı) → push cihaz token kaydı (idempotent upsert, cihaz hesap değiştirince yeniden atama). `device_tokens` tablosu. 73 test yeşil (e2e: 401/kayıt 204+kalıcı/idempotent tek satır/yeniden atama/geçersiz platform 400). Not: BullMQ fan-out worker (Redis) + gerçek APNs/FCM gönderimi docs/10'a ertelendi.
- **#21 (readiness health check):** `GET /v1/health/ready` — Prisma ile DB erişilebilirliğini kontrol eder (`SELECT 1`), DB down → 503 degraded. VPS deploy/rollout sağlık kontrolü (docs/02). Bare `/health` liveness olarak statik/prefix'siz kalır. 69 test yeşil (e2e: liveness prefix'siz 200, readiness DB up 200). Staging compose healthcheck bu uca bağlanacak.
- **#20 (mobile auth controller):** api client'ı app mimarisine bağlayan glue (docs/04 M0). `AuthController` (session tutar, `registerAnonymously` → platform=flutter, `isAuthenticated`, `signOut`) + Riverpod `apiClientProvider` (baseUrl flavor'dan, onDispose close) + `authControllerProvider`. 7 test yeşil (MockClient: kayıt→oturum kurulur, signOut sıfırlar). Controller deseni kalıcı (generated client gelince yalnızca client swap).
- **#19 (mobile api client):** `core/api` — ince interim `NoctaApiClient` (`package:http`) + `Session`/`ApiException` modelleri; `registerDevice` (POST /v1/auth/device). `MockClient` ile test edildi (ağ yok): 201→Session parse + doğru uç + gövde, 201-dışı→ApiException. flutter analyze temiz + 6 test yeşil. Not: generated Dart client (Java) gelince değişir (B-3); auth interceptor + offline kuyruk üstüne eklenecek.
- **#18 (mobile design_system):** M0 ilerledi (mobile en geride kalmıştı). `NButton` (variant, dokunma hedefi ≥44px) + `NCard` (bg/raised + iç kenarlık) — üretilen Dart token'ları kullanır. design_system barrel; home_screen bunları tüketiyor. `flutter analyze` temiz + 4 widget testi yeşil (tıklama iletimi, 44px hedef, child render). API client'a bağlı değil (Java bloke → B-3).
- **#17 (web SEO temeli):** otomatik `sitemap.xml` + `robots.txt` (Next metadata route'ları, rota listesi tek kaynaktan — archetype sayfaları büyüdükçe otomatik) + `llms.txt` (AI-dostu site özeti, GEO — docs/05 §4; sağlık-iddiası-yok dili). 11 web testi yeşil (route listesi doğrulaması). `/r/` (gece raporları) noindex. turbo 17/17.
- **#16 (packages/ui genişleme):** `Input` (erişilebilir label/aria-invalid), `DataTable` (generic, boşta EmptyState, özel hücre render), `ConfirmDialog` (tehlikeli işlem onayı, docs/03 §1.3). 10 ui testi yeşil (input/tablo/dialog etkileşimleri). admin dashboard'da DataTable kullanılıyor. turbo 17/17.
- **#15 (packages/ui + admin dashboard):** paylaşılan React primitive kiti (docs/03 §1.1 Seviye 1) — `Button` (variant'lar), `StatCard`, `EmptyState`; token'lı, iş mantığı/API yok. Web'deki gibi vitest kuruldu (5 test: tıklama/disabled/variant/render). admin bunları tüketen AppShell (sidebar+topbar) + dashboard sayfasında kullanıyor (transpilePackages + tailwind content genişletildi). turbo 17 task yeşil (ui test dahil). Not: shadcn tabanına geçiş + DataTable sonraki iterasyonda.
- **#14 (archetype landing sayfaları):** `/a/{slug}` 4 SSG sayfa (deep-ocean/overthinker/delta-drifter/dawn-chaser) — SEO/GEO içerik (alıntılanabilir summary + paragraflar + "sana uygun sesler" + teste CTA) + schema.org JSON-LD (tek util). `generateStaticParams` ile static üretim; bilinmeyen slug → 404. 9 web testi yeşil — **sağlık iddiası taraması** dahil (cure/treat/therapy yasak kelime kontrolü). turbo 14/14.
- **#13 (web W0 frontend):** ilk frontend feature. `/test` sayfası — public API'yi tüketen `ArchetypeTest` client bileşeni (soruları çek → cevapla → `POST /v1/archetype/web` → sonuç + `/a/{slug}` linki) + home'da `WaitlistForm`. Web'e **vitest + testing-library** kuruldu (fetch mock'lu component testleri — CI'da API/DB gerekmez). 4 web testi + api 67 = turbo 14 task yeşil; `next build` static (home 1kB JS). **Ek düzeltme:** api jest `testTimeout` 30s — turbo eşzamanlı yükte e2e beforeAll flake'ini giderdi.
- **#12 (W0 API yüzeyi):** web viral testinin backend'i. Public `GET /v1/archetype/web/questions` (auth yok — tek kaynak matris, web render eder) + **waitlist** modülü `POST /v1/waitlist` (public, IP rate-limit'li, idempotent e-posta). `waitlist` tablosu. 67 test yeşil (e2e: public questions, waitlist katıl/idempotent/geçersiz-email 400). Not: web FRONTEND sayfaları (test altyapısı gerektirir) sıradaki iterasyonda.
- **#11 (identity v2 — magic link):** e-posta ile hesaba yükseltme. `POST /v1/auth/email/request` (kimlik doğrulamalı, magic link üret + log-mailer) + `POST /v1/auth/email/verify` (public, token → anonim→registered yükseltme, email_verified_at). `one_time_tokens.email` kolonu; OTT/Mailer portları; dev'de ham token dönüyor (prod'da gizli, IS_PRODUCTION DI token'ı — presentation→shared boundary'sini korur). 63 test yeşil (in-memory unit + e2e: request/verify/kullanılmış-token 401/geçersiz-email 400/e-posta çakışması 409). Not: **gerçek SMTP (Brevo/Resend) ertelendi** → DECISIONS_NEEDED D-5; argon2id yalnızca şifre-tabanlı auth eklenirse gerekir (magic link passwordless).
