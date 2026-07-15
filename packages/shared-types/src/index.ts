// OpenAPI'den üretilen tipler. `pnpm gen:api-types` ile yenilenir; generated/
// klasörü elle düzenlenmez ve git'e girmez (üretim çıktısı).
export type { paths, components, operations } from './generated/api';
