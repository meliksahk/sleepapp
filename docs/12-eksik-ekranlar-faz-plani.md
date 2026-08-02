# 12 — Eksik Ekranlar: Faz Planı (mobil + servis + admin)

> **Bağlam:** [`11-tasarimci-ekran-brief.md`](11-tasarimci-ekran-brief.md) 24 ekranlık envanteri
> çıkardı; [`06`](06-design-master-prompt.md)'daki Elegy sistemi **var olan 15 ekranın
> tamamına** uygulandı (PR #219). Geriye tasarımda olan ama uygulamada **hiç bulunmayan
> 8 ekran** kaldı. Bu dosya onları fazlara böler ve her fazın **servis (apps/api)** ile
> **yönetim paneli (apps/admin)** ayağını da yazar.
>
> **Kural:** bir faz, üç ayağı da (mobil + API + admin) bitmeden "tamam" sayılmaz.
> Ekranı yazıp arkasındaki ucu bırakmak, bu repoda daha önce yaşandı: uyku takibi
> mantığı #128–#132'de yazıldı ve kullanıcı ona 90 gün ulaşamadı.

---

## 0. Servis ve panel envanteri (ÖLÇÜLDÜ, tahmin değil)

Aşağıdakiler `apps/api/src/modules/*/presentation/*.controller.ts` ve
`apps/admin/src/app` taranarak çıkarıldı.

### Zaten HAZIR olan uçlar (mobil hiç çağırmıyor)

| Uç                                         | Modül    | Durum                                                                |
| ------------------------------------------ | -------- | -------------------------------------------------------------------- |
| `DELETE /v1/auth/me`                       | identity | **Hazır** — kaskad silme, 204, scope = token sub                     |
| `GET /v1/me/export`                        | privacy  | **Hazır** — tüm kişisel veri JSON, `Content-Disposition: attachment` |
| `GET /v1/sleep/streak` · `stats` · `trend` | sleep    | Hazır (geçmiş ekranı kullanıyor)                                     |
| `PATCH /v1/profile`                        | profile  | Hazır — ama yalnız `notificationsEnabled` (tek boole)                |

> **Bulgu:** hesap silme ve veri indirme **sunucuda çalışıyor, uygulamada düğmesi yok.**
> App Store'un hesap silme zorunluluğu bir API eksiği değil, bir EKRAN eksiği.

### EKSİK olan servis işleri

| İhtiyaç                                                 | Neden gerekli                                               | Faz |
| ------------------------------------------------------- | ----------------------------------------------------------- | --- |
| `profile`'a `reminderHour`, `quietHoursStart/End`       | Bildirim ayarları ekranı tek boole'dan fazlasını gösteriyor | F3  |
| `mixes` modülü: `GET/POST/DELETE /v1/mixes` + migration | Kullanıcının kendi mixini kaydetmesi (preset ekranı)        | F4  |
| `content.feed`'e kategori/etiket alanı                  | Kütüphane filtreleri (tasarımda 4 filtre çipi var)          | F6  |

### EKSİK olan panel işleri

| İhtiyaç                                          | Neden gerekli                                                  | Faz       |
| ------------------------------------------------ | -------------------------------------------------------------- | --------- |
| ~~Gizlilik görünürlüğü: silinen hesap sayacı~~   | Silme kaskadının çalıştığını operasyonel olarak görmek         | **F1 ✅** |
| Kampanya hedeflemesine "hatırlatıcı saati" alanı | Bildirim tercihleri sunucuya taşınınca kampanya onu kullanmalı | F3        |
| İçerik CMS'ine kategori/etiket editörü           | Kütüphane filtreleri içeriğe bağlı                             | F6        |

Panelin **content / users / flags / campaigns / security / dashboard** dilimleri zaten var;
yukarıdakiler o dilimlerin içine eklenir, yeni bölüm açılmaz.

---

## F1 — Gizlilik ve hesap _(lansman blokeri)_ · ✅ **ÜÇ AYAK DA BİTTİ**

> **Durum (2 Ağu 2026):**
>
> - **Mobil:** `/settings/delete-account` rotası + ayarlarda "Gizlilik" bölümü,
>   `AuthController.deleteAccount()` / `exportData()`, 3 test.
> - **Servis:** `account_deletions` tablosu (migration) + `AccountDeletionLog`
>   portu + `CountAccountDeletionsUseCase` (identity'nin public servisi) +
>   `DeleteAccountUseCase` artık silme BAŞARILI olunca sayaç yazıyor, 2 test.
> - **Admin:** panoda "Silinen hesap · son 30 gün" kartı.
>
> **Tasarım kararı — audit'e YAZILMADI:** panel denetim izi (`admin_audit_log`)
> bir ADMIN eylemi kaydıdır; satırları `actor_email` ile ve `users`'a FK ile
> bağlıdır. Hesap silme bir KULLANICI eylemi ve kaskad o satırı da silerdi —
> yani sayaç hep 0 dönerdi. Onun yerine kimlik taşımayan bir olay sayacı
> tablosu açıldı: "sil" dediğinde gerçekten siliniyor, geriye yalnız bir
> zaman damgası kalıyor.

**Neden ilk:** App Store, hesap oluşturan her uygulamada **uygulama içinden hesap silmeyi**
şart koşuyor. Bu olmadan gönderim reddedilir — yani F1 bitmeden lansman yok.
Üstelik iki ucun ikisi de hazır: iş, ekran + istemci çağrısı.

| Ayak  | İş                                                                                                                                                                |
| ----- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Mobil | Ayarlar → "Gizlilik" bölümü · **Hesabımı sil** ekranı (geri alınamaz onayı, ne silineceğinin listesi, onay kutusu) · **Verilerimi indir** (paylaş sayfasına JSON) |
| API   | Ek iş yok. `DELETE /v1/auth/me` + `GET /v1/me/export` kullanılacak                                                                                                |
| Admin | Panoda **"Silinen hesap · son 30 gün"** kartı — `deletedAccounts30d` alanı `GET /v1/admin/overview` yanıtına eklendi.                                             |

**Çıkış kriteri (karşılandı):** onay kutusu işaretlenmeden buton pasif ve istek GİTMİYOR ·
silme sonrası oturum düşüyor · sunucu reddederse oturum DURUYOR · silme patlarsa sayaç
yazılmıyor · panoda sayaç kartı var.

⚠️ **Migration henüz koşulmadı** (`pnpm db:migrate` bir Postgres ister; bu makinede
ayakta değil). Deploy sırasında koşacak — koşmadan `GET /v1/admin/overview` 500 döner.

---

## F2 — Gece kontrolü · ✅ **ÜÇ EKRAN DA BİTTİ**

> **Durum (2 Ağu 2026):**
>
> - ✅ **Mikrofon izin gerekçesi** — `/sleep-mode/microphone`, sistem kutusundan
>   ÖNCE gösterilir, BİR KEZ (`MicRationaleFlag`, secure storage). Reddedilmiş
>   izinle geri gelinirse "ne kaybettiğini" söyleyen blok açılır. 5 test.
> - ✅ **Akıllı alarm kurulumu** — `/sleep-mode/alarm`, saat + **pencere
>   genişliği** (10–60 dk) birlikte. `SleepModeController.alarmWindow` artık
>   değiştirilebilir ve değişiklik ZATEN KURULU alarma da uygulanıyor. 4 test.
> - ✅ **Alarm çalıyor tam ekran** — çalarken ekranın TAMAMI devralınıyor;
>   "geceyi bitir"/"başlat" düğmeleri ekranda kalmıyor (yarı uykuluya üç düğme
>   sunmak yanlış düğmeye basmanın davetiydi; biri geceyi bitiriyor). Test
>   `sleep-toggle`ın YOK olduğunu sabitliyor. "Sustur" geceyi bitirmez —
>   tasarımdaki "kapat ve raporu aç" akışı davranışı değiştirirdi, görsel bir
>   karar uğruna değiştirmedik.
> - ⬜ **Gün doğumu rampası anahtarı** — tasarımda var, motorda karşılığı yok
>   (`SunriseAlarmSound` her zaman açık). Çalışmayan anahtar ÇİZİLMEDİ: olmayan
>   bir özelliği varmış gibi göstermek olurdu.

**Neden ikinci:** mikrofon izni reddedilirse gece raporu hiç üretilmiyor — ürünün ikinci
viral kancası sessizce ölüyor. Sistemin izin kutusunu gerekçesiz göstermek red oranını
yükseltir.

| Ayak  | İş                                                                                                                                                                                                                                              |
| ----- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Mobil | **Mikrofon izin gerekçesi** (sistem kutusundan ÖNCE) + **izin reddedildi** hali · **Akıllı alarm kurulumu** (saat + pencere genişliği + gün doğumu rampası; şu an sistemin saat seçicisi) · **Alarm çalıyor** tam ekran (şu an satır içi panel) |
| API   | Yok — alarm tamamen istemcide (docs/04 §1.3)                                                                                                                                                                                                    |
| Admin | Yok                                                                                                                                                                                                                                             |

**Çıkış kriteri:** izin reddedildiğinde ritüel yine çalışıyor ve kullanıcı bunu ekranda
okuyor; alarm penceresi mobil testte kuruluyor; alarm ekranı `alarmRinging` durumunda
tam ekranı devralıyor.

---

## F3 — Alışkanlık ve bildirim

| Ayak  | İş                                                                                                                                                       |
| ----- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Mobil | **Ritüelim / seri** ekranı (büyük seri sayısı, ay ızgarası, 3 istatistik) · **Bildirim ayarları** (hatırlatıcı saati, sessiz saatler, tür bazlı aç/kapa) |
| API   | `profile`'a `reminderHour` + `quietHoursStart/End`; migration; `notification` modülünde zamanlamanın bu alanları okuması                                 |
| Admin | Kampanya hedeflemesinde "hatırlatıcı saati" filtresi                                                                                                     |

**Çıkış kriteri:** kullanıcı hatırlatıcı saatini değiştirince sunucuda kalıcı ve
bildirim o saate göre planlanıyor (integration test).

---

## F4 — Mikser derinliği

| Ayak  | İş                                                                                                           |
| ----- | ------------------------------------------------------------------------------------------------------------ |
| Mobil | **Mix kaydetme / preset yönetimi** (adlandır, listele, sil) · **Katman detayı** (karakter/filtre ince ayarı) |
| API   | **Yeni `mixes` modülü**: `GET/POST/DELETE /v1/mixes`, kullanıcıya scope'lu repository, SQL migration         |
| Admin | Yok (kullanıcı verisi, panelde gösterilmez)                                                                  |

**Çıkış kriteri:** kaydedilen mix uygulama kapanıp açılınca ve **başka cihazda** geliyor;
"kullanıcı A, B'nin mixini okuyamaz" integration testi yeşil (CLAUDE.md §6).

---

## F5 — Share Studio (mix-to-video ekranı)

**Not:** dışa aktarma **kodu zaten var** (`MixVideoExporter`, `mix_video_frame.dart`) ve
mikserdeki butondan çalışıyor; eksik olan **kendi ekranı** — süre seçimi, ön izleme,
ilerleme, sonuç ve paylaş.

| Ayak  | İş                                                                                     |
| ----- | -------------------------------------------------------------------------------------- |
| Mobil | Share Studio ekranı + rota; süre seçenekleri (30 sn / 1 dk / 10 dk), boyut preset'leri |
| API   | Yok                                                                                    |
| Admin | Yok                                                                                    |

---

## F6 — Kütüphane derinliği

**Not:** kütüphane ekranı VAR ama tasarımdaki filtre çipleri, "haftanın tarifi" vurgusu ve
iskelet/çevrimdışı halleri yok.

| Ayak  | İş                                                                    |
| ----- | --------------------------------------------------------------------- |
| Mobil | Filtre çipleri, haftanın tarifi hero'su, iskelet + çevrimdışı halleri |
| API   | `content.feed` yanıtına kategori/etiket alanı                         |
| Admin | İçerik CMS'inde kategori/etiket editörü                               |

---

## Sıra gerekçesi (tek cümlede)

F1 lansmanı açar · F2 ikinci viral kancayı kurtarır · F3 geri dönüşü (retention) kurar ·
F4 çekirdek değeri derinleştirir · F5 üçüncü viral kancayı tamamlar · F6 içerik yüzeyini
doldurur.
