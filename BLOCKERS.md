# BLOCKERS — çözülmesi gereken engeller

> Loop bir işte 3 iterasyon üst üste takılırsa buraya yazar ve bağımsız işe geçer
> (LOOP.md). Aşağıdakiler F0 kickoff sırasında tespit edildi.

## Aktif blocker'lar

### ~~B-3 · Java yok → Dart API client üretilemiyor~~ → ⛔ **BU BLOCKER YANLIŞTI (#137)**

- **Yazdığım iddia:** "ortamda Java kurulu değil."
- **Gerçek (müdür denetimiyle DÜZELTİLDİ):** JDK **var ama PATH'te DEĞİL.**
  `java -version` → _command not found_; `JAVA_HOME` → **boş**. JDK yalnızca şurada:
  `C:/Program Files/Android/Android Studio/jbr/bin/java.exe` → `openjdk 17.0.9`.
  Flutter'ın Android build'inin **zaten kullandığı** JBR.
- **Doğru komut:** `JAVA_HOME="C:/Program Files/Android/Android Studio/jbr" npx @openapitools/openapi-generator-cli generate ...`
- **NOT:** ilk düzeltmem "Java KURULU" diyordu — bu da yanıltıcıydı: `java -version`
  koşan sonraki okuyucu "command not found" alıp blocker'ı geri yazardı. Yanlış bir
  cümleyi başka bir yanlış cümleyle düzeltmek, hatanın kendisinin tekrarıdır.
  `apps/api/openapi.json` da yerinde (71.550 bayt). Yani ön koşulların ikisi de vardı.
- **Neden önemli:** bu tek yanlış cümle bir blocker dosyasında durdu ve **her planlama
  kararını zehirledi** — Dart client "üretilemez" sayıldığı için mobil API katmanı
  hiç başlamadı. Kimse doğrulamadı; ben de doğrulamadan yazmıştım.
- **Ders:** blocker yazmak ucuz, blocker DOĞRULAMAK zorunlu. Bir "yapılamaz" iddiası,
  bir "yapıldı" iddiası kadar kanıt ister (CLAUDE.md §0.4).
- **Durum:** blocker DEĞİL — sıradan iş. `JAVA_HOME` JBR'ye ayarlanıp
  `npx @openapitools/openapi-generator-cli generate ...` koşulacak (M0).

### B-4 · Branch protection / CI-zorunlu kilit (GitHub free plan)

- **Ne:** Private repoda `branches/*/protection` ve `rulesets` API'leri "Upgrade to GitHub Pro or make public" (HTTP 403) döndürüyor.
- **Etki:** "CI yeşil olmadan merge yok" ve "PR zorunlu" platform düzeyinde ZORLANAMIYOR. CI workflow'u kurulu ve yeşil; şimdilik yalnızca PR disiplinine bağlı.
- **Karar gerekiyor:** bkz. DECISIONS_NEEDED D-1 (Pro'ya yükselt / repoyu public yap / disiplinle devam). Kickoff kuralı gereği ücretli servis açılmadı.

## Çözülenler

- **B-1 · Docker daemon (ÇÖZÜLDÜ, iter #1):** Docker Desktop başlatıldı; `docker compose up -d` ile lokal stack (Postgres16 + Redis7 + MinIO) ayakta; migration gerçek Postgres'e uygulandı, down/up tersinirliği kanıtlandı, seed doğrulandı.
- **B-2 · dbmate (ÇÖZÜLDÜ, iter #1):** host'a binary kurmadan `ghcr.io/amacneil/dbmate` Docker image'ı ile koşuldu; `db/schema.sql` üretildi.
