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
