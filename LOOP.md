# NOCTA Geliştirme Döngüsü — Loop Master Prompt

Sen bu monorepoda otonom geliştirme döngüsü yürütüyorsun. Hedefin: docs/01
§6'daki faz haritasının TAMAMINI (F1→F5 ve dev hesapları bağlandıktan sonra
F6/docs-10) bitirmek. Fazlar arasında DURMA — bir fazın çıkış kriterleri
kanıtlandığında LOOP_STATE.md'ye faz kapanış raporu yaz ve bir sonraki faza
kendiliğinden geç. Her iterasyonda bu dosyayı baştan sona uygula. CLAUDE.md
(özellikle Dürüstlük Protokolü) her zaman geçerlidir; çelişkide CLAUDE.md
kazanır.

## İlerleme göstergesi (her iterasyonda güncelle)

`LOOP_STATE.md`'nin **en üstünde** bir yüzde barı + yüzey tablosu durur. Bu,
insanın "ne kadar bitti?" sorusuna tek bakışta yanıttır. Her iterasyonun sonunda
(§6) yeniden hesapla ve güncelle.

- **Kapsam:** yalnızca otonom fazlar **F1–F5** (docs/01 §6). F6 (ödeme + lansman)
  insan-kapılı olduğu için yüzdeye KATILMAZ; bittiğinde ayrıca not düşülür.
- **Model:** dört yüzeyin kaba tamamlanma yüzdesinin ağırlıklı ortalaması.
  Ağırlıklar (efor tahmini): **Mobil 0.40, Backend 0.30, Admin 0.15, Web 0.15**.
  Toplam = `0.30·backend + 0.40·mobil + 0.15·admin + 0.15·web`.
- **Dürüstlük:** bu bir TAHMİNDİR; "kesin ölçüm" gibi sunma. Bir yüzey yüzdesini
  yalnızca o iterasyonda o yüzeyde somut, test edilmiş bir dilim bittiyse artır
  (birkaç puan). Çekirdek özellik (ör. ses motoru) bitmeden mobil yüzdesini
  şişirme. Bar 40 karakter: dolu = `round(yüzde/100·40)` adet `█`, kalanı `░`.
- **Nerede:** tek kaynak `LOOP_STATE.md` üstüdür (LOOP.md'deki bu bölüm yalnızca
  kuralı tanımlar; buraya sayı yazma).

## Her iterasyonun adımları

1. DURUM OKU: `LOOP_STATE.md`'yi ve aktif fazın dokümanını (`docs/0X-*.md`)
   oku. Yarım kalmış iş varsa önce onu bitir. `BLOCKERS.md`'de çözülebilir
   hale gelmiş bloker varsa önce onu dene.
2. TEK İŞ SEÇ: Aktif fazın sıradaki EN KÜÇÜK anlamlı işini seç (hedef: tek
   PR, <400 satır diff). Faz sırasını atlama; "daha ilginç" işe sıçramak
   yasak. Backend/mobil/panel/web fazları paralel akar — bir yüzey blokeyse
   diğer yüzeyin sıradaki işine geç.
3. UYGULA: Mimari kurallara uygun yaz. Yeni desen icat etmeden önce en
   benzer mevcut kodu oku ve taklit et. Test yazmadan implementation'ı
   bitmiş sayma.
4. DOĞRULA: `pnpm turbo lint test` (+ ilgiliyse `flutter analyze && flutter
test`) koş. Kanıtsız "çalışıyor" yazmak yasak — Dürüstlük Protokolü.
5. TESLİM ET: Yeşilse conventional commit + `feat/loop-<konu>` branch + PR
   aç, CI yeşilse PR'ı merge et (squash). PR açıklamasına DURUM RAPORU
   bloğunu koy.
6. DEFTERİ GÜNCELLE: `LOOP_STATE.md`'ye ekle: iterasyon no, yapılan iş, PR
   linki, DURUM RAPORU, sıradaki iş. Ayrıca en üstteki **İlerleme
   göstergesi**ni (yüzde barı + yüzey tablosu) yeniden hesaplayıp güncelle
   (bkz. "İlerleme göstergesi"). Bu dosya insanın loop'u denetlediği tek
   ekrandır — asla atlama.
7. TEMPO: Devam edecek iş varsa hemen sürdür; CI/dış olay bekleniyorsa
   uyanmayı ona göre zamanla.

## Ertelenmiş işler (SONA bırak — erken yapma)

- **Ödeme/IAP/paywall:** tüm yapı çalışır olmadan yazılmaz. F5 sonuna kadar
  premium gating yalnızca `EntitlementService` stub'ı üzerinden (herkes
  premium). Billing modülü + paywall UI yalnızca F6'da, docs/10 listesiyle.
- **Dev hesabı gerektiren her şey:** Apple Sign-In, APNs/FCM push gönderimi,
  TestFlight, store metadata, sandbox IAP → docs/10. Bu işlere sıra
  geldiğinde kodu hazırlayabilirsin ama hesap bağlantısı gereken adımda
  `DECISIONS_NEEDED.md`'ye "dev hesapları gerekli" yaz ve İNSANDAN İSTE.
- **Gerçek cihaz/gece testleri ve sandbox testleri:** docs/10 lansman
  kontrol listesinde; o güne kadar otomatik testler + simülatör yeterlidir
  ama bunların "doğrulanmadı" statüsünü her raporda dürüstçe taşı.

## F5 tamamlanınca (dev-hesabı kapısı — projenin TEK insan kapısı)

1. LOOP_STATE.md'ye "F1–F5 tamam" kapanış raporu + docs/10 için hazırlık
   listesi yaz (hangi hesaplar, hangi bilgiler gerekiyor — madde madde).
2. Kullanıcıya açıkça bildir: "Dev hesaplarını bağlamamız gerekiyor: [liste]".
3. Hesap bilgileri gelene kadar F6 dışı kalan cila/borç/test-kapsamı işlerini
   sürdür; onlar da bitince loop'u DURDUR ve bekle.
4. Hesaplar bağlanınca docs/10'daki listeyi sırayla uygula ve projeyi
   lansman-hazır durumda kapat.

## Kesin sınırlar (ihlali = loop'u durdur ve insana yaz)

- Production'a migration, deploy, store işlemi, veri silme: yalnızca
  kurulu CI/CD hattı üzerinden; hattı baypas etmek ASLA.
- Ücretli servis ekleme, yeni bağımlılık >1MB veya lisansı belirsiz:
  durdur, `DECISIONS_NEEDED.md`'ye yaz, bağımsız başka işe geç.
- Secrets'ı dosyaya/koda yazmak: ASLA.
- Aynı işte 3 iterasyon üst üste başarısızlık: işi `BLOCKERS.md`'ye
  gerekçesiyle yaz, o işi bırak, bir SONRAKİ bağımsız işe geç. Bağımsız iş
  de kalmadıysa loop'u durdur ve insana özetle.
- Belirsiz ürün kararı (metin tonu, fiyat, tasarım tercihi): en makul
  varsayımla İLERLE, kararı `DECISIONS_NEEDED.md`'ye yaz — insanın cevabı
  gelince güncellemek üzere. Yalnızca geri alınması pahalı kararlarda dur.

## Kalite çıtası (her iterasyonda)

- CLAUDE.md DoD maddeleri + boundary lint'ler yeşil.
- Kişisel-veri endpoint'lerinde "A, B'nin verisini okuyamaz" testi.
- Sağlık iddiası taraması (metin değiştiyse).
- LOOP_STATE.md'de kanıt: test çıktısı özeti / CI linki olmadan ✅ yazılamaz.
