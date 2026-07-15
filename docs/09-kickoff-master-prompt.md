# 09 — Kickoff Master Prompt (kod tarafındaki İLK prompt)

> Kullanım: Boş bir klasöre bu paketteki dosyaları koy (`CLAUDE.md` ve `LOOP.md` köke, `docs/` klasörü). O klasörde Claude Code'u aç ve aşağıdaki bloğu **aynen** yapıştır. Bu prompt projeyi başlatan tek seferlik zemin kurulumudur; bittiğinde loop'a geçilir (`docs/08`).

## Başlamadan önce elinde olması gerekenler

- GitHub hesabı + `gh auth login` yapılmış olması (veya token)
- Hostinger VPS: IP, SSH kullanıcısı (root şifresiyle başlanabilir — prompt key kurulumunu yapar)
- Staging için bir subdomain (ör. `api-staging.alanadin.com`; yoksa şimdilik IP ile devam edilir, prompt sormadan DNS değiştirmez)
- Sentry hesabı (free)
- **Gerekmeyenler:** Apple/Google dev hesapları, ödeme altyapısı — bunlar en son fazda (docs/10) istenecek.

## MASTER PROMPT — aynen yapıştır

```
Bu klasörde CLAUDE.md, LOOP.md ve docs/01..10 mimari dokümanları var. Önce
CLAUDE.md'yi (özellikle Dürüstlük Protokolü'nü) ve docs/01 + docs/02'yi oku.
Görevin: loop'un üzerinde koşacağı doğrulanabilir zemini kurmak (Faz F0
kickoff'u). Sıra ve öncelik şu; her adımı bitirdiğinde doğrulama kanıtıyla
kısa rapor ver, büyük sapma gerekiyorsa durup sor:

0) ORTAM: git, node>=20, pnpm, docker, gh, flutter kurulu mu doğrula;
   eksikleri kur. gh auth durumunu kontrol et.

1) GITHUB (öncelikli): "nocta" private repo'sunu gh ile oluştur. Monorepo
   iskeletini CLAUDE.md §2'deki yapıya birebir uygun kur: pnpm workspaces +
   Turborepo; packages/config (eslint+prettier+tsconfig+commitlint), husky +
   commitlint hook'ları, boundary lint altyapısı. PR şablonu DURUM RAPORU
   bloğunu zorunlu içersin. main branch koruması + CI zorunluluğu ayarla.
   CI: path-filtered GitHub Actions (lint+typecheck+test+build, app başına).

2) VPS (öncelikli): Hostinger VPS bilgilerini benden iste (IP, kullanıcı;
   bilgileri asla repoya/koda yazma). Sırayla: SSH key-only erişim, ufw
   (yalnızca 22/80/443), fail2ban, unattended-upgrades, docker kur.
   Staging compose stack'ini ayağa kaldır: Postgres + MinIO + Redis
   (YALNIZCA docker iç ağı — dışarı port açma) + Caddy (otomatik SSL) +
   şimdilik placeholder API container'ı. GitHub Actions'tan staging'e SSH
   deploy hattını kur ve boş bir commit'le uçtan uca test et. Secrets
   yalnızca GitHub Environments + VPS ortam dosyalarında yaşar. Günlük
   pg_dump + off-site yedek cron'unu kur ve bir yedeği doğrula.

3) LOKAL VERİ KATMANI: kökte docker-compose (Postgres+MinIO+Redis lokal),
   db/ klasörü + dbmate migration akışı; İLK migration'ı yaz: users,
   auth_devices, refresh_tokens, one_time_tokens, profiles (docs/02 §3
   şemasına uygun) + down blokları + seed scripti.

4) UYGULAMA İSKELETLERİ (çatı): apps/api = NestJS + shared/kernel + tipli
   env + /health + Sentry + OpenAPI pipeline + identity modülünün v1'i
   (anonim cihaz kaydı POST /v1/auth/device, access/refresh token akışı,
   rotation + reuse-detection; argon2id + jose kullan, kripto elle yazma) —
   "kullanıcı A, B'nin verisini okuyamaz" ve token güvenlik testleriyle.
   apps/admin ve apps/web = boş Next.js (App Router, TS strict, tailwind +
   tokens); apps/mobile = flutter create + flavor'lar (dev/staging/prod) +
   CI'da analyze/test. packages/design-tokens'ı docs/06'daki token'larla
   doldur; gen:tokens (CSS+Dart) ve gen:api-types (OpenAPI→TS+Dart)
   zincirlerini uçtan uca çalıştır.

5) DEPLOY: gerçek API image'ını staging'e deploy et; staging'de /health 200
   ve anonim kayıt→token→yetkili istek zincirini curl ile kanıtla.

6) DOĞRULAMA: pnpm turbo lint test build tüm workspace'te yeşil; CI yeşil;
   flutter analyze && flutter test yeşil. Kanıtları göster.

7) KAPANIŞ: LOOP_STATE.md (aktif faz: F1), BLOCKERS.md, DECISIONS_NEEDED.md
   dosyalarını oluştur (LOOP.md'nin beklediği format). CLAUDE.md §9 komut
   listesini gerçekte kurduğun komutlarla eşitle. DURUM RAPORU üret ve
   "loop başlatılabilir" bildir.

Sınırlar: production stack'i kurma (yalnızca staging); DNS/domain
değişikliğini sormadan yapma; secrets'ı asla dosyaya yazma; ücretli hiçbir
servis/hesap açma; Apple/Google dev hesabı gerektiren hiçbir işe girme
(docs/10'a ertelendi).
```

## Sonrası

Kickoff bitince tek satır:

```
/loop LOOP.md'yi oku ve tek iterasyon uygula.
```

Loop kesintisizdir: fazları kendiliğinden geçer, ödeme ve dev-hesabı işlerini sona erteler, F5 bitince dev hesaplarını senden ister (docs/10) ve bağlandıktan sonra lansman listesini uygulayarak projeyi kapatır. Günlük 5 dakikalık rutinin: `LOOP_STATE.md` + `BLOCKERS.md` + `DECISIONS_NEEDED.md` okumak.
