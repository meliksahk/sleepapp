# BLOCKERS — çözülmesi gereken engeller

> Loop bir işte 3 iterasyon üst üste takılırsa buraya yazar ve bağımsız işe geçer
> (LOOP.md). Aşağıdakiler F0 kickoff sırasında tespit edildi.

## Aktif blocker'lar

### B-1 · Docker daemon kapalı → lokal DB canlı doğrulanamadı

- **Ne:** `docker-compose.yml` + dbmate ilk migration yazıldı ve `docker compose config` ile doğrulandı, ama Docker Desktop kapalı olduğu için `docker compose up -d` + `pnpm db:migrate` KOŞULMADI.
- **Etki:** migration SQL'i ve seed gerçek Postgres'e karşı henüz uygulanmadı; API hâlâ in-memory repo kullanıyor.
- **Çözüm:** Docker Desktop'ı başlat → `docker compose up -d db` → dbmate kur (`scoop install dbmate` / binary) → `pnpm db:migrate` → `psql "$DATABASE_URL" -f db/seed.sql`. Sonra Prisma adaptörlerini yaz + testcontainers integration testleri.
- **Bağımlı iş:** F1'de Prisma repository adaptörleri.

### B-2 · dbmate kurulu değil

- **Ne:** migration aracı (`dbmate`) PATH'te yok.
- **Çözüm:** `scoop install dbmate` veya https://github.com/amacneil/dbmate/releases binary (db/README).
- **Not:** Repoya binary koyulmaz.

### B-3 · Java yok → Dart API client üretilemiyor

- **Ne:** `openapi-generator` (dart-dio) Java 11+ gerektirir; ortamda Java kurulu değil.
- **Etki:** `apps/mobile/packages/api_client` üretilemedi (README'de komut hazır). TS tarafı (`@nocta/shared-types`) sorunsuz üretiliyor.
- **Çözüm:** Java kur + `npx @openapitools/openapi-generator-cli generate ...` (README), ya da saf-Dart alternatifi `swagger_parser` değerlendir (M0).

### B-4 · Branch protection / CI-zorunlu kilit (GitHub free plan)

- **Ne:** Private repoda `branches/*/protection` ve `rulesets` API'leri "Upgrade to GitHub Pro or make public" (HTTP 403) döndürüyor.
- **Etki:** "CI yeşil olmadan merge yok" ve "PR zorunlu" platform düzeyinde ZORLANAMIYOR. CI workflow'u kurulu ve yeşil; şimdilik yalnızca PR disiplinine bağlı.
- **Karar gerekiyor:** bkz. DECISIONS_NEEDED D-1 (Pro'ya yükselt / repoyu public yap / disiplinle devam). Kickoff kuralı gereği ücretli servis açılmadı.
