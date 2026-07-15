# api_client — OpenAPI'den üretilen Dart istemcisi

Bu paket `apps/api/openapi.json`'dan **openapi-generator** ile üretilir; elle
dokunulmaz (CLAUDE.md §2). Üretilen kod `lib/generated/` altındadır ve git'e
girmez (gitignore).

## Üretim

openapi-generator **Java** gerektirir (bu ortamda Java kurulu değil → şimdilik
ertelendi, bkz. `BLOCKERS.md`).

```bash
# openapi-generator-cli (npm sarmalayıcı, Java 11+ gerekir)
npx @openapitools/openapi-generator-cli generate \
  -i ../../../api/openapi.json \
  -g dart-dio \
  -o . \
  --additional-properties=pubName=nocta_api_client,nullableFields=true
```

Alternatif (Java'sız, saf Dart): `dart run swagger_parser` — M0'da değerlendirilecek.

## Tüketim

`apps/mobile` bu paketi path bağımlılığı olarak kullanır (auth interceptor +
offline kuyruk `core/api` katmanında sarar). TS tarafındaki eşleniği
`packages/shared-types` (aynı OpenAPI kaynağı).
