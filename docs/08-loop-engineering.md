# 08 — Loop Engineering: Projeyi /loop ile Geliştirme

> "Loop engineering" Anthropic'in kendi kullandığı terim: doğru primitifleri seçip (loop/schedule/goal), net başarı kriterleri ve doğrulama adımları tanımlayarak Claude'un işi sen olmadan da döngüyle ilerletmesini tasarlamak. /loop bir prompt'u tekrar tekrar koşturur: ya sabit aralıkla (`/loop 15m ...`) ya da aralıksız yazarsan **dinamik modda** — Claude bir sonraki uyanmayı işin gerçek temposuna göre kendisi zamanlar.

Master prompt repo kökündeki **`LOOP.md`** dosyasıdır (ayrı dosya olarak hazır). Model: loop **kesintisizdir** — F1'den F5'e fazları kendiliğinden geçer, ödeme/IAP ve dev-hesabı gerektiren her işi sona erteler, F5 bitince **projenin tek insan kapısında** senden dev hesaplarını ister ve bağlandıktan sonra `docs/10` listesini uygulayarak projeyi lansman-hazır kapatır.

## 1. Dürüst çerçeve

**Loop'un iyi yaptığı:** faz planındaki işleri tek tek alıp implement etmek, test koşmak, CI beklemek, kırmızıyı düzeltmek, PR açıp merge etmek, defteri güncelleyip devam etmek.

**Yapısal gerçekler:** (1) doğrulayıcısı olmayan loop hatayı da döngüyle üretir — bu yüzden loop başlamadan CI/lint/test zemini kurulmuş olmalı (docs/09 kickoff bunun için); (2) loop oturum yaşadıkça çalışır; kullanım limitine takılırsa kaldığı yerden devam ettirmek için aynı `/loop` komutunu yeniden verirsin — `LOOP_STATE.md` hafızası olduğu için kayıp olmaz; (3) öznel kararları (fiyat, ton, estetik) `DECISIONS_NEEDED.md`'ye bırakır ve varsayımla ilerler — o dosyayı ara ara okumak senin işin; (4) ertelenen gerçek-dünya doğrulamaları (gece testleri, sandbox) raporlarda "doğrulanmadı" olarak dürüstçe taşınır ve docs/10'da kapatılır.

## 2. Kullanım tarifi

1. Kickoff'u tamamla (docs/09) — zemin: repo, CI, VPS, lokal stack.
2. Loop'u başlat:
   ```
   /loop LOOP.md'yi oku ve tek iterasyon uygula.
   ```
   Aralık verme → dinamik mod. Aktif fazı belirtmene gerek yok; loop fazı `LOOP_STATE.md`'den kendisi bilir.
3. **Senin günlük rutinin (5 dakika):** `LOOP_STATE.md` (ne yapıldı), `BLOCKERS.md` (nerede takıldı), `DECISIONS_NEEDED.md` (senden ne karar bekliyor) — üç dosyayı oku; karar sorularını cevapla (loop bir sonraki iterasyonda alır).
4. Durdurmak istersen: "loop'u durdur" yaz. Devam ettirmek: aynı `/loop` komutu.
5. F5 sonunda loop sana "dev hesapları gerekli: [liste]" diye seslenecek → hesapları bağla → loop docs/10'u uygulayıp projeyi kapatır.

## 3. Loop engineering ilkeleri (bu projeye uyarlanmış)

- **Doğrulanabilirlik önce gelir:** "mikser ekranını güzelleştir" loop işi değildir (öznel); "MixerScreen'e golden test ekle ve geçir" loop işidir.
- **İş birimi = küçük PR (<400 satır):** loop raydan çıktığında kayıp küçük kalır; defter okunur kalır.
- **Aralığı gerçeğe eşle:** kod yazarken aralık gerekmez; CI ~8 dk sürüyorsa uyanma ona göre zamanlanır, 1 dk'da bir bakmak israftır.
- **Defter dosyaları loop'un hafızasıdır:** `LOOP_STATE.md`, `BLOCKERS.md`, `DECISIONS_NEEDED.md`.
- **Loop ≠ schedule:** loop tek hedefi (projeyi bitirmek) kovalar; takvimle tekrar eden işler (haftalık metrik özeti, GEO denetimi, rakip takibi) scheduled task'tır — lansman yaklaşınca ayrıca kurulur.

## 4. Riskin dürüst kaydı

Kesintisiz-loop modelini sen seçtin; bedeli şu: F2'deki ses kalitesi ve M3'teki gerçek gece doğrulaması gibi "kulakla/gerçekte" testler docs/10'a ertelendi. Kod otomatik testlerle doğru olabilir ama _ürün hissi_ lansman öncesi tek seferde test edilecek — orada büyük bir sorun çıkarsa (ör. sesler ucuz duyuluyorsa) geri dönüş maliyeti faz içinde yakalamaktan yüksek olur. İstediğin an ara kontrol yapabilirsin: loop'u durdurmadan repo'yu çekip cihazında build alman yeterli; bunu F2 ve M3 kapanışlarında yapmanı öneririm — zorunlu değil, öneri.
