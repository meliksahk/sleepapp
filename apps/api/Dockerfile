# syntax=docker/dockerfile:1

# ─────────────────────────────────────────────────────────────────────────────
# NOCTA API — çok aşamalı üretim imajı (docs/09, CLAUDE.md §6: self-hosted).
#
# **Build context = REPO KÖKÜ** (pnpm workspace + @nocta/config gerekir):
#     docker build -f apps/api/Dockerfile -t nocta-api .
#
# Neden multi-stage: derleme araçları (nest CLI, ts, prisma CLI, tüm devDeps) son
# imaja SIZMAZ. Runtime yalnızca `dist/` + prod bağımlılıkları + üretilmiş Prisma
# client'ı taşır. Secret yok (imaja .env girmez, bkz. .dockerignore) — hepsi
# runtime env'den okunur.
# ─────────────────────────────────────────────────────────────────────────────

# bookworm-slim: @node-rs/argon2 (native) ve Prisma glibc prebuild'leri için
# alpine/musl'dan daha güvenli. openssl + ca-certs Prisma engine ve npx için.
FROM node:22-bookworm-slim AS base
ENV PNPM_HOME=/pnpm
ENV PATH=/pnpm:$PATH
RUN apt-get update \
  && apt-get install -y --no-install-recommends openssl ca-certificates \
  && rm -rf /var/lib/apt/lists/*
# corepack, pnpm sürümünü kök package.json'daki packageManager'dan SABİTLER
RUN corepack enable
WORKDIR /repo

# ── build: derle, Prisma client üret, prod-only deploy dizini çıkar ──────────
FROM base AS build
# Kaynağın tamamı (.dockerignore node_modules/dist/secrets'i zaten dışlıyor).
COPY . .
# Yalnızca @nocta/api ALT GRAFI (deps'iyle) kurulur — admin/web kurulmaz.
RUN --mount=type=cache,id=pnpm,target=/pnpm/store \
  pnpm install --frozen-lockfile --filter "@nocta/api..."
# Prisma client'ı build makinesinde (linux) üret → engine runtime platformuyla eşleşir.
RUN pnpm --filter @nocta/api exec prisma generate
RUN pnpm --filter @nocta/api run build
# Tek başına çalışabilir, prod-only bir ağaç: dist + prod node_modules (symlink yok).
RUN pnpm --filter @nocta/api deploy --prod --legacy /app
# **GÜVENLİK AĞI:** pnpm deploy üretilmiş Prisma client'ını her zaman taşımıyor;
# /app içinde yeniden üret (CLI'ı store yerine npx ile pinli sürümden çalıştır).
RUN cd /app && npx --yes prisma@6.19.3 generate

# ── runtime: küçük, non-root, yalnızca çalışması için gerekenler ─────────────
FROM base AS runtime
ENV NODE_ENV=production
ENV API_PORT=3001
WORKDIR /app
COPY --from=build /app /app
# node:22 imajı 'node' kullanıcısını içerir — root DEĞİL (CLAUDE.md §6).
USER node
EXPOSE 3001

# Konteyner sağlıklı mı: liveness (DB'ye dokunmaz, hızlı). curl yok → node fetch.
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.API_PORT||3001)+'/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "dist/main.js"]
