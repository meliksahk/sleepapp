import { z } from 'zod';

/**
 * Tipli ortam değişkenleri (docs/02 §2). Eksik/yanlış değerde boot FAIL eder.
 * Secrets asla koda gömülmez; yalnızca process.env'den okunur (CLAUDE.md §6).
 */
const EnvSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  API_PORT: z.coerce.number().int().positive().default(3001),

  // identity — RS256 anahtar çifti (PEM). Boşsa development'ta ephemeral üretilir.
  JWT_PRIVATE_KEY: z.string().optional(),
  JWT_PUBLIC_KEY: z.string().optional(),
  ACCESS_TOKEN_TTL: z.coerce.number().int().positive().default(900), // 15 dk
  REFRESH_TOKEN_TTL: z.coerce.number().int().positive().default(2_592_000), // 30 gün
  MAGIC_LINK_TTL: z.coerce.number().int().positive().default(900), // 15 dk
  MAGIC_LINK_BASE_URL: z.string().default('http://localhost:3003/auth/verify'),

  // Paylaşım (sharing) — derin link + web kart URL'leri.
  WEB_BASE_URL: z.string().default('https://nocta.app'),
  APP_DEEPLINK_SCHEME: z.string().default('nocta'),

  // İstek gövdesi boyut limiti (DoS sertleşme). Payload'larımız küçük (auth/profil/cevaplar).
  MAX_REQUEST_BODY_BYTES: z.coerce.number().int().positive().default(65_536), // 64kb

  // IP rate-limit (throttler). Env'den gelir çünkü e2e testleri tek IP'den yüzlerce
  // istek atar → testte yüksek, üretimde sıkı. Dağıtık (Redis) storage B4'te.
  THROTTLE_LIMIT: z.coerce.number().int().positive().default(60), // pencere başına istek
  THROTTLE_TTL_MS: z.coerce.number().int().positive().default(60_000), // pencere (ms)
  // Admin girişi için AYRI ve çok daha sıkı limit (dakikada 5 deneme). Global 60/dk
  // "gezinme" için makul, "parola tahmini" için değil. Ayarlanabilir çünkü bu bir
  // operasyon kararı — ama YÜKSELTMEK kaba kuvvet kapısını açar, bilinçli yapılsın.
  ADMIN_LOGIN_LIMIT: z.coerce.number().int().positive().default(5),

  DATABASE_URL: z.string().optional(),
  REDIS_URL: z.string().optional(),
  SENTRY_DSN: z.string().optional(),

  // MinIO / S3 (presigned URL üretimi offline; canlı bağlantı erişimde doğrulanır)
  MINIO_ENDPOINT: z.string().default('http://localhost:9000'),
  MINIO_ROOT_USER: z.string().default('nocta'),
  MINIO_ROOT_PASSWORD: z.string().default('nocta_local_dev'),
  MINIO_REGION: z.string().default('us-east-1'),
  MINIO_BUCKET_SOUNDSCAPES: z.string().default('soundscape-assets'),
});

export type Env = z.infer<typeof EnvSchema>;

export function loadEnv(source: NodeJS.ProcessEnv = process.env): Env {
  const parsed = EnvSchema.safeParse(source);
  if (!parsed.success) {
    const issues = parsed.error.issues
      .map((i) => `  - ${i.path.join('.')}: ${i.message}`)
      .join('\n');
    throw new Error(`Geçersiz ortam değişkenleri:\n${issues}`);
  }
  return parsed.data;
}

export const ENV = Symbol('ENV');
