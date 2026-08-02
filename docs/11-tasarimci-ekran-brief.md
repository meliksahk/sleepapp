# 11 — Tasarımcı Brief'i: Ürün Kapsamı ve Ekran Envanteri

> **Kime:** dışarıdan gelen tasarımcıya. **Ne için:** uygulamanın neye hizmet ettiğini ve hangi ekranların tasarlanması gerektiğini tek dosyada vermek.
>
> **Bununla birlikte oku:** [`06-design-master-prompt.md`](06-design-master-prompt.md) — renk/tipografi/spacing/motion token'ları ve marka tonu ORADA tanımlı. Bu dosya "ne çizilecek", 06 "hangi dille çizilecek". Token'lar tek kaynaktır: yeni hex/yeni ölçek uydurulmaz, ihtiyaç varsa **öneri olarak bildirilir**.
>
> **Durum etiketleri:** `KODDA VAR` = ekran çalışıyor, tasarım cilası bekliyor · `İSKELET` = ekran var ama içerik/tasarım yok denecek kadar az · `YOK` = hiç yok, sıfırdan tasarlanacak.

---

## 1. Uygulama ne için tasarlanıyor

**Tek cümle:** "Gecenin bir kimliği var."

Bu bir **uyku ritüeli** uygulaması. Kullanıcı akşam uygulamayı açar, kendine ait bir ses ortamı kurar, uykuya dalar; sabah gecesinin bir özetini alır ve bunu paylaşabilir. Üç şey aynı anda yapılıyor:

1. **Kimlik** — kısa bir test kullanıcıya bir "uyku arketipi" verir (`deep-ocean`, `overthinker`, `delta-drifter`, `dawn-chaser`). Arketip kişiselleştirmenin ve paylaşımın omurgası: her arketibin kendi gradyanı/deseni var.
2. **Ses** — sesler kayıt değil, **telefonda anlık üretiliyor** (sentez). Bu yüzden hiç döngüye girmez, internet gerektirmez ve kullanıcı katmanları (dalga / yağmur / ateş / gürültü / pad) tek tek karıştırabilir. Kullanıcı kendi telefonundan da ses ekleyebilir.
3. **Gece** — telefon şarjda ve ekran kapalıyken mikrofonla hareket/ses **olayları** sayılır (ham ses hiçbir yere yazılmaz, buluta hiç gitmez), sabah "gece raporu" üretilir; akıllı alarm hafif uyku anında çalar.

### Ürünü tanımlayan dört kısıt (tasarımı doğrudan bağlar)

| Kısıt                               | Tasarıma yansıması                                                                                                                                                                           |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Sağlık iddiası yok**              | "tedavi", "terapi", "klinik olarak kanıtlanmış", "doktor onaylı" hiçbir yerde geçmez. Sahte EEG dalgası, nabız grafiği, beyaz önlük estetiği yok. Konum: **rahatlama ve ritüel**, tıp değil. |
| **Gece kullanılıyor**               | Uygulama **yalnızca koyu tema**. Açık tema mobilde YOK. Gece ekranlarında hiçbir öge parlak değil; "saat 3'te yarı uykulu göz kısarak kullanabilir mi?" testi geçmeli.                       |
| **Paylaşılabilirlik büyüme motoru** | Kimlik kartı, gece raporu ve mix-to-video **süs değil çekirdek özellik**. "Paylaşmak reklam yapmak gibi değil, hava atmak gibi" hissettirmeli.                                               |
| **Çevrimdışı çalışır**              | Ağ hatası hiçbir çekirdek akışı öldürmemeli. Boş/hatalı ağ durumu ekranın tamamını değil, yalnız ilgili bölümü etkiler.                                                                      |

### Tasarımda **istenmeyenler**

Lotus çiçeği, meditasyon silüeti, zen taşı, ay-yıldız klişesi, çocuksu illüstrasyon, "wellness guru" tonu, hastane/klinik dili, sert drop shadow, canlı/parlak jel butonlar, zıplayan animasyon.

**İstenen his:** planetaryum, derin su, gece göğü, rezonans. Sakin, mahrem, sessizce premium, biraz gizemli.

---

## 2. Kullanıcı yolculuğu — gecenin üç zamanı

```
AKŞAM                     GECE                        SABAH
─────                     ────                        ─────
Ana ekran                 Uyku modu ekranı            Alarm çalıyor  ← YOK
  → ritüeli başlat          (tek küre, saat,           ↓
  → mikser                  ekran neredeyse kara)     Gece raporu
  → ses kütüphanesi        akıllı alarm penceresi       → makbuz kartı
streak / seri şeridi       mikrofon açık göstergesi     → paylaş
                                                       streak güncellenir
```

İlk açılışta bunun öncesinde bir kere: **karşılama → arketip testi → kimlik kartı → paylaş**.

---

## 3. Ekran envanteri

### 3.1 Kimlik / ilk açılış

| #   | Ekran                              | Ne işe yarar                                                                                          | Durum       |
| --- | ---------------------------------- | ----------------------------------------------------------------------------------------------------- | ----------- |
| 1   | **Karşılama / onboarding**         | 2–3 kart: ne olduğu, mikrofonun neden istendiği, ritüel vaadi.                                        | `KODDA VAR` |
| 2   | **Arketip testi**                  | ~60 sn, soru soru ilerleyen test. Uygulamanın ilk izlenimi — en yüksek cilalanma önceliği.            | `KODDA VAR` |
| 3   | **Arketip sonucu / kimlik detayı** | Arketibin adı, gradyanı, kısa karakter metni, "kartı paylaş" CTA'sı, "mikserimi bu kimliğe göre kur". | `KODDA VAR` |
| 4   | **Kimlik geçmişi**                 | Kullanıcı testi tekrar çözerse zaman içindeki kimlik değişimi.                                        | `KODDA VAR` |

**Test ekranı için özel istek:** soru geçişleri "sınav" gibi değil "kendini tanıma" gibi hissettirmeli. İlerleme göstergesi bunaltmamalı. Cevap seçenekleri tek elle, başparmakla erişilebilir alanda. Soru sayısı sabit değil — 6 ila 12 arası bir aralığa uyacak esnek düzen gerekiyor.

### 3.2 Ana ekran ve keşif

| #   | Ekran                                    | Ne işe yarar                                                                                                | Durum                               |
| --- | ---------------------------------------- | ----------------------------------------------------------------------------------------------------------- | ----------------------------------- |
| 5   | **Ana ekran**                            | "Bu gece" bloğu (ritüeli başlat / mikseri aç), seri (streak) şeridi, keşif kısayolları. Tek birincil eylem. | `KODDA VAR`                         |
| 6   | **Ses kütüphanesi (soundscape listesi)** | Hazır ses tarifleri listesi; arketipe göre önerilenler.                                                     | `İSKELET` — ciddi tasarım gerekiyor |
| 7   | **Soundscape detayı**                    | Tek bir tarifin tanıtımı, ön izleme, "mikserde aç".                                                         | `KODDA VAR`                         |

**Kütüphane için özel istek:** burası şu an neredeyse boş bir liste. Kart sistemi, kategori/filtre mantığı, "haftanın içeriği" vurgusu ve **boş hâli** (hiç içerik yokken ne görünür) sıfırdan tasarlanmalı.

### 3.3 Mikser — uygulamanın kalbi

| #   | Ekran                                 | Ne işe yarar                                                                                                                                  | Durum       |
| --- | ------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| 8   | **Mikser**                            | Katman kartları, katman başına ses seviyesi, çalma kontrolü, uyku zamanlayıcı, kaydet, video dışa aktar. En karmaşık ekran (~1100 satır kod). | `KODDA VAR` |
| 9   | **"Ses ekle" sayfası (bottom sheet)** | İki kaynak: hazır katalog + **telefondan dosya seçme**. Yerel kütüphane listesi, kullanılan disk alanı, tek tek silme.                        | `KODDA VAR` |
| 10  | **Mix kaydetme / preset yönetimi**    | Kullanıcının kendi mixini adlandırıp saklaması, listeleyip silmesi.                                                                           | `YOK`       |
| 11  | **Katman detayı** (opsiyonel öneri)   | Bir katmanın ince ayarı (filtre, karakter). Şu an her şey tek ekranda.                                                                        | `YOK`       |

**Mikser için özel istek — en zor tasarım problemi bu:**

- Aynı anda **5'e kadar katman**; her katman kartı en az 44px dokunma hedefi, tek elle ve **göz kapalıya yakın** kullanılabilir olmalı.
- Ses seviyesi görsel olarak **parlaklık/parıltı** ile eşleşiyor (yüksek katman daha çok "yanıyor").
- Katman kaynakları farklı karakterde: `pad` (tonal), `waves`, `rain`, `fire`, `white/pink/brown` gürültü. Her birinin tanınabilir bir görsel imzası olmalı — ikon yeterli değilse jenerik doku.
- Kullanıcının kendi eklediği ses **farklı bir sınıf**: sürgüyle katmanlarına ayrılamaz, "opak" bir blok. Bu fark görsel olarak dürüstçe anlatılmalı, gizlenmemeli.
- Sesle tepki veren görselleştirme **akışkan** olmalı (perlin gürültüsü, dalga şeridi) — dikenli EQ çubuğu değil.

### 3.4 Gece

| #   | Ekran                       | Ne işe yarar                                                                                                                          | Durum                   |
| --- | --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- | ----------------------- |
| 12  | **Uyku modu**               | Gecenin ekranı: nefes alan küre, saat, alarm saati, "mikrofon açık" göstergesi, bitir. Ekran kapanmadan önceki ve açıldığındaki hâli. | `KODDA VAR`             |
| 13  | **Mikrofon izin gerekçesi** | Sistem izin kutusundan ÖNCE gösterilen dürüst açıklama: ham ses kaydedilmiyor, buluta gitmiyor. Ayrıca **izin reddedildi** hâli.      | `YOK` — tasarlanmalı    |
| 14  | **Akıllı alarm kurulumu**   | Alarm saati + pencere (ör. 06:30–07:00 arası hafif uykuda uyandır). Şu an sistemin standart saat seçicisi kullanılıyor.               | `YOK` (sistem diyaloğu) |
| 15  | **Alarm çalıyor ekranı**    | Kullanıcının uygulamayı gördüğü ilk sabah anı: gün doğumu rampası, ertele/kapat.                                                      | `YOK` — tasarlanmalı    |

**Uyku modu için özel istek:** hiçbir öge %40 parlaklığın üzerinde olmamalı. Tek bir yavaş nefes döngüsü (6–8 sn) dışında hareket yok. Kullanıcı gece uyanıp telefona baktığında gözünü acıtmamalı; saat okunabilir ama parlak olmamalı. "Mikrofon açık" göstergesi **gizlenmez** — kural gereği kullanıcı bunu görür.

### 3.5 Sabah — büyüme motoru

| #   | Ekran                        | Ne işe yarar                                                                               | Durum       |
| --- | ---------------------------- | ------------------------------------------------------------------------------------------ | ----------- |
| 16  | **Gece raporu**              | "Gece makbuzu": süre, olay zaman çizelgesi, seri durumu, arketibe göre tek cümlelik yorum. | `KODDA VAR` |
| 17  | **Uyku geçmişi**             | Geçmiş geceler listesi, eğilim.                                                            | `KODDA VAR` |
| 18  | **Seri / alışkanlık ekranı** | Şu an ana ekranda tek şerit. Ayrı bir "ritüelim" ekranı ürün olarak isteniyor.             | `YOK`       |

### 3.6 Hesap, ödeme, sistem

| #   | Ekran                               | Ne işe yarar                                                                                                                                              | Durum                       |
| --- | ----------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------- |
| 19  | **Ayarlar**                         | Üyelik, bildirimler, dil (EN/TR), imza sesi, aktif cihazlar / diğer oturumları kapat.                                                                     | `KODDA VAR`                 |
| 20  | **Paywall**                         | Premium anlatımı. **Gerçek satın alma henüz yok**, CTA "çok yakında" diyor; tasarım gerçek akışa hazır olmalı (fiyat kartları, 7 gün deneme, geri yükle). | `İSKELET` (85 satır)        |
| 21  | **Hesap silme akışı**               | App Store zorunluluğu: hesabı ve tüm veriyi silme, geri dönüşsüz olduğunu anlatan onay.                                                                   | `YOK` — eksik, tasarlanmalı |
| 22  | **Bildirim / hatırlatıcı ayarları** | "Her akşam 23:00'te ritüeli hatırlat" gibi. Şu an yalnız aç/kapa var.                                                                                     | `YOK`                       |
| 23  | **Share Studio (mix-to-video)**     | Mixi 9:16 videoya çevirme: süre seçimi, ön izleme, ilerleme, sonuç. Kod tarafı var, **kendi ekranı yok**.                                                 | `YOK` — tasarlanmalı        |

---

## 4. Paylaşım varlıkları (ekran değil, ürünün reklamı)

Bu üçü uygulamanın dışında, başkasının telefonunda görünecek. **En yüksek estetik çıta bunlarda.**

1. **Kimlik kartı** — 1080×1920 (story) + 1:1 kare. Arketip gradyanı, büyük arketip adı, arketibe özgü takımyıldız benzeri jeneratif desen, köşede küçük logo. Dört arketibin dördü de ayrı ayrı tasarlanmalı.
2. **Gece makbuzu (rapor kartı)** — premium bir bilet/makbuz estetiği: istatistik satırları, gecenin sparkline'ı, tek sıcak cümle, tırtıklı kenar metaforu. Ekran görüntüsü alınmak için tasarlanmış olmalı.
3. **Mix-to-video karesi** — 9:16 döngü video: sesin akışkan görselleştirmesi + arketip teması + filigran. Filigran varsayılan olarak KALIR (büyüme motoru); tasarımı utandırıcı değil, imza gibi olmalı.

Ek olarak istenen, ekran olmayan işler: **uygulama ikonu**, **açılış (splash) ekranı**, **mağaza ekran görüntüsü şablonları** (App Store + Play, EN ve TR), arketip illüstrasyon sistemi.

---

## 5. Her veri ekranı için zorunlu durumlar

Tek "mutlu hâl" teslimi kabul edilmiyor. Veri gösteren her ekran için dört hâl isteniyor:

- **Yükleniyor** — spinner değil, iskelet (skeleton) tercih edilir.
- **Boş** — ilk kullanıcı hiç veri görmez. Boş hâl bir **yönlendirme** olmalı, özür değil. (Ör. hiç gece yoksa: "İlk geceni kaydet.")
- **Hata / çevrimdışı** — ağ yokken ekranın **tamamı** ölmemeli; yalnız ağa bağlı bölüm bir satırla kendini bildirir.
- **İzin reddedildi** — mikrofonla ilgili her yerde.

---

## 6. Pazarlıksız teknik/erişilebilirlik sınırları

- **Yalnız koyu tema** (mobil). Açık tema yalnızca web sitesi ve yönetim paneli için.
- **Kontrast en az AA.** Koyu zemin üzerindeki mor/şeftali vurguların kontrastı ölçülerek verilmeli.
- **Dokunma hedefi ≥ 44px.** Gece ekranlarında daha da büyük.
- **Renk tek başına durum anlatmaz** — ikon veya etiketle eşlenir.
- **Hareket azaltma** ayarına saygı: animasyon kapanabilir olmalı, kapandığında ekran ölü görünmemeli.
- **İki dil: EN (birincil) + TR.** Türkçe metinler İngilizceden ortalama %20–30 uzun; butonlar ve etiketler taşmadan uzayabilmeli. Metin resmin içine gömülmez.
- **Ekran boyutları:** iPhone SE (küçük) alt sınır, katlanabilir/tablet hedef değil.

---

## 7. Öncelik sırası (tasarımcıya iş sırası önerisi)

1. **Mikser** (8, 9) — çekirdek değer, en karmaşık, şu an en çok kod en az tasarım.
2. **Paylaşım varlıkları** (§4) — büyüme buradan geliyor.
3. **Uyku modu + alarm çalıyor + izin gerekçesi** (12, 13, 15) — ürünün "gece" vaadi.
4. **Ses kütüphanesi** (6) — şu an iskelet, doldurulmalı.
5. **Arketip testi + sonuç** (2, 3) — ilk izlenim.
6. **Paywall, hesap silme, ayarlar** (19, 20, 21) — lansman zorunlulukları.
7. **Share Studio, seri ekranı, preset yönetimi** (23, 18, 10) — yeni yüzeyler.

---

## 8. Teslim beklentisi

- Figma dosyası, ekran başına: mutlu hâl + §5'teki durumlar.
- Kullanılan token'lar isimleriyle belirtilmiş (`accent/aurora` gibi), yeni renk uydurulmamış; sistemde olmayan bir şey gerektiyse **öneri olarak işaretlenmiş**.
- Paylaşım varlıkları gerçek ölçüde (1080×1920, 1:1, 9:16) dışa aktarılabilir hâlde.
- Animasyon niyetleri kısa notla (süre, eğri) — video prototip şart değil.
