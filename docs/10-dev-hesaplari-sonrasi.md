# 10 — Dev Hesapları Bağlandıktan Sonra Yapılacaklar (F6)

> F1–F5 bitip loop hesapları istediğinde bu liste devreye girer. Sıra önemlidir; her blok kendi doğrulama kanıtıyla kapanır. Bu dosya aynı zamanda loop'un F6 iş listesi olarak kullanılır.

## 0. Bağlanacak hesaplar (kullanıcıdan istenecekler)

| Hesap                                | Ne için                                            | Not                                                                                                            |
| ------------------------------------ | -------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Apple Developer Program (99 $/yıl)   | Sertifikalar, TestFlight, IAP, Apple Sign-In, APNs | Tek zorunlu maliyet; şirket mi bireysel mi kararını kullanıcı verir (şirket = App Store'da tüzel isim görünür) |
| App Store Connect erişimi            | Uygulama kaydı, IAP ürünleri, store metadata       | Apple Developer ile birlikte gelir; API anahtarı CI için üretilir                                              |
| Google Play Console (25 $ tek sefer) | Android lansmanı                                   | iOS-öncelikli plan gereği ertelenebilir; FCM push için Firebase projesi yalnızca push amaçlı açılır            |
| Alan adı (yoksa)                     | API/site prod domain'leri + universal links        | Zaten varsa yalnızca DNS kayıtları                                                                             |

Kullanıcıdan istenecek erişim biçimi: App Store Connect API key (CI için), geliştirici hesabına davet (admin değil "App Manager" yeter). Şifre paylaşımı istenmez.

## 1. Kimlik & Altyapı bağlama

- [ ] Bundle ID kaydı + capabilities: Sign in with Apple, Push Notifications, Background Modes (audio), App Groups (widget için).
- [ ] APNs anahtarı üret → API `notification` modülünün log-adaptörü gerçek APNs adaptörüyle değiştirilir; staging'de test cihazına push kanıtı.
- [ ] Apple Sign-In: `identity` modülüne `POST /v1/auth/apple` (identity token doğrulama — JWKS Apple'dan); mobil tarafta buton + hesap birleştirme akışı (anonim → Apple). "A'nın Apple hesabı B'nin anonim hesabını ele geçiremez" testi.
- [ ] Universal links / associated domains: paylaşım linkleri (`/a/`, `/r/`) uygulamayı açar; apple-app-site-association dosyası web'e eklenir.
- [ ] fastlane match/sertifika yönetimi + TestFlight lane'i; CI'dan otomatik internal build kanıtı.

## 2. Billing (backend B5 + mobil M7 birlikte)

- [ ] App Store Connect'te IAP ürünleri: `plus_yearly` (7 gün deneme), `plus_monthly`, `lifetime`. Fiyat kararı → `DECISIONS_NEEDED.md`'den kullanıcı onayıyla.
- [ ] `billing` modülü: StoreKit 2 transaction JWS doğrulama, App Store Server Notifications V2 endpoint'i (imza doğrulama + idempotency), entitlement senkronu.
- [ ] `EntitlementService` stub'ının gerçekle değişimi; feature gating regresyon testleri.
- [ ] Paywall UI (flag'li varyantlar) + restore purchases + "kart bilgisi girmeden dene" konumlandırması.
- [ ] Sandbox test matrisi: satın al / restore / iade / deneme bitişi / abonelik yenileme — beşi de kanıtlı.

## 3. Lansman kontrol listesi (ertelenen gerçek-dünya doğrulamaları)

- [ ] **Gerçek cihaz gece testleri:** 8 saat kesintisiz ses + pil profili (CPU < %4) en az 2 cihazda; 5 gerçek gece kaydından mantıklı rapor. (Bilinçli ertelenmişti — lansmanın ön şartıdır, atlanamaz.)
- [ ] Gerçek cihaz matrisi duman testi: iPhone SE (küçük ekran) + eski Android.
- [ ] Mikrofon izin metni + privacy nutrition labels + hesap silme akışının App Store uyumluluk kontrolü.
- [ ] Store metadata: ekran görüntüleri, önizleme videosu (Share Studio motoruyla üretilebilir), long-tail ASO metinleri (`fastlane/metadata`), sağlık-iddiası taraması.
- [ ] Prod ortamı: DNS, SSL, prod DB migration, yedek tatbikatı, Sentry release, uptime monitörü.
- [ ] TestFlight external beta (küçük grup) → crash-free %99+ hedefi → App Store review başvurusu.

## 4. Lansman sonrası ilk 2 hafta

- [ ] Review'e takılma senaryosu planı (mikrofon gerekçesi en olası soru — cevap şablonu hazır).
- [ ] Push kampanya sistemi ilk gerçek kampanya (paneldeki A4 altyapısıyla).
- [ ] Web sitesine App Store linki + SoftwareApplication schema güncellemesi; GSC'de indexleme kontrolü.
- [ ] Metrik hattı doğrulama: gerçek kullanıcı funnel'ları (test→paylaşım, rapor→paylaşım, deneme→ücretli) panoda akıyor.
