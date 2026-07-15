# NOCTA — Sleep Identity Platform (monorepo)

> Çalışma kod adı **NOCTA**. Tek kişilik, sıfır sermayeli, viral motorlu uyku
> ritüeli uygulaması ekosistemi. Kural kaynağı: [`CLAUDE.md`](./CLAUDE.md).
> Mimari: [`docs/`](./docs). Otonom geliştirme döngüsü: [`LOOP.md`](./LOOP.md).

## Yapı

```
apps/
  api/        NestJS modüler monolit (identity, profile, ...) — VPS'te self-hosted
  admin/      Next.js App Router yönetim paneli (shadcn/ui)
  web/        Next.js SSG tanıtım sitesi (SEO/GEO)
  mobile/     Flutter (feature-first Clean Architecture + Riverpod)
packages/
  config/         eslint / prettier / tsconfig / commitlint (paylaşılan)
  design-tokens/  tek kaynak token → CSS vars + Tailwind preset + Dart theme
  shared-types/   OpenAPI → TS tipleri (admin + web tüketir)
  ui/             shadcn tabanlı React primitive kiti (admin + web)
db/           dbmate SQL migration'ları + seed
tooling/      codegen scriptleri
```

## Gereksinimler

- Node **>=20** (`.nvmrc`: 22), **pnpm** 10, **Docker** + compose, **Flutter** 3.x, **gh**
- `dbmate` (migration): `go install` veya binary — bkz. [db/README](./db/README.md)

## Hızlı başlangıç (lokal)

```bash
pnpm i                      # bağımlılıklar
cp .env.example .env        # ortam değişkenleri (gerçek .env commit edilmez)
docker compose up -d        # Postgres + MinIO + Redis (yalnızca lokal)
pnpm db:migrate             # şemayı uygula
pnpm --filter api dev       # API  (http://localhost:3001/health)
pnpm --filter admin dev     # admin panel
pnpm --filter web dev       # tanıtım sitesi
cd apps/mobile && flutter run
```

## Doğrulama

```bash
pnpm turbo lint test build              # tüm TS workspace (path-filtered)
cd apps/mobile && flutter analyze && flutter test
```

## Codegen (tek yönlü — elle müdahale yasak, CLAUDE.md §2)

```bash
pnpm gen:tokens       # design-tokens → CSS/Tailwind/Dart
pnpm gen:api-types    # OpenAPI → shared-types (TS) + Dart client
```

## Durum

Faz **F0 (kickoff)** — zemin kurulumu. Aktif faz ve ilerleme:
[`LOOP_STATE.md`](./LOOP_STATE.md) · Bekleyen kararlar:
[`DECISIONS_NEEDED.md`](./DECISIONS_NEEDED.md) · Bloker'lar:
[`BLOCKERS.md`](./BLOCKERS.md).
