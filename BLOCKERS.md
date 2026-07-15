# BLOCKERS — çözülmesi gereken engeller

> Loop bir işte 3 iterasyon üst üste takılırsa buraya yazar ve bağımsız işe geçer
> (LOOP.md). Aşağıdakiler F0 kickoff sırasında tespit edildi.

## Aktif blocker'lar

### B-3 · Java yok → Dart API client üretilemiyor

- **Ne:** `openapi-generator` (dart-dio) Java 11+ gerektirir; ortamda Java kurulu değil.
- **Etki:** `apps/mobile/packages/api_client` üretilemedi (README'de komut hazır). TS tarafı (`@nocta/shared-types`) sorunsuz üretiliyor.
- **Çözüm:** Java kur + `npx @openapitools/openapi-generator-cli generate ...` (README), ya da saf-Dart alternatifi `swagger_parser` değerlendir (M0).

### B-4 · Branch protection / CI-zorunlu kilit (GitHub free plan)

- **Ne:** Private repoda `branches/*/protection` ve `rulesets` API'leri "Upgrade to GitHub Pro or make public" (HTTP 403) döndürüyor.
- **Etki:** "CI yeşil olmadan merge yok" ve "PR zorunlu" platform düzeyinde ZORLANAMIYOR. CI workflow'u kurulu ve yeşil; şimdilik yalnızca PR disiplinine bağlı.
- **Karar gerekiyor:** bkz. DECISIONS_NEEDED D-1 (Pro'ya yükselt / repoyu public yap / disiplinle devam). Kickoff kuralı gereği ücretli servis açılmadı.

## Çözülenler

- **B-1 · Docker daemon (ÇÖZÜLDÜ, iter #1):** Docker Desktop başlatıldı; `docker compose up -d` ile lokal stack (Postgres16 + Redis7 + MinIO) ayakta; migration gerçek Postgres'e uygulandı, down/up tersinirliği kanıtlandı, seed doğrulandı.
- **B-2 · dbmate (ÇÖZÜLDÜ, iter #1):** host'a binary kurmadan `ghcr.io/amacneil/dbmate` Docker image'ı ile koşuldu; `db/schema.sql` üretildi.
