# db/ — SQL-first migration'lar (dbmate)

Migration disiplini (CLAUDE.md §6, docs/02 §3):

- **Yalnızca** bu klasör; Prisma `db push`/`migrate` **yasak**. Şema senkronu `prisma db pull` ile.
- Her migration bir **`-- migrate:down`** bloğu içerir (geri alınabilir).
- Staging'de koşmadan prod'a **gitmez**; prod migration'ı yedek-önce kuralına tabidir.
- Kişisel-veri tablosu ekleyen her migration'a "A, B'nin verisini okuyamaz" testi eşlik eder (API katmanında).

## dbmate kurulumu

dbmate tek dosyalık bir Go binary'sidir (repoya girmez):

```bash
# macOS/Linux
brew install dbmate
# veya Windows (scoop)
scoop install dbmate
# veya doğrudan binary: https://github.com/amacneil/dbmate/releases
```

## Kullanım

`DATABASE_URL` `.env`'den okunur (kök `pnpm db:*` script'leri bunu sağlar).

```bash
docker compose up -d db        # Postgres'i ayağa kaldır
pnpm db:migrate                # bekleyen migration'ları uygula (dbmate up)
pnpm db:rollback               # son migration'ı geri al (dbmate down)
pnpm db:new add_something      # yeni migration dosyası aç
pnpm db:seed                   # lokal seed (idempotent — tekrar çalıştırmak güvenli)
```

`pnpm db:seed`, PATH'te `psql` varsa onu `DATABASE_URL` ile kullanır; yoksa
`docker exec nocta-local-db-1 psql` yoluna düşer (Windows'ta host'a psql client
kurmaya gerek kalmasın diye). Container adı `NOCTA_DB_CONTAINER` ile değiştirilir.

## Durum

- `migrations/20260715120001_init_identity_profile.sql` — users, auth_devices,
  refresh_tokens, one_time_tokens, profiles (+ down).
- Sonraki migration'lar (archetype_results, soundscapes, presets, ...) B0/F1'de
  eklenecek (docs/02 §5).

> `schema.sql` dbmate tarafından ilk `db:migrate` koşumunda üretilir; commit edilir
> (şemanın insan-okur anlık görüntüsü).
