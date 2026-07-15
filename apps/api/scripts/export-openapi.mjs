// OpenAPI şemasını dist'ten üretir → apps/api/openapi.json (codegen'in tek kaynağı).
// Kullanım: pnpm --filter @nocta/api build && pnpm --filter @nocta/api openapi:export
import { writeFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUT = resolve(__dirname, '..', 'openapi.json');

const { NestFactory } = await import('@nestjs/core');
const { DocumentBuilder, SwaggerModule } = await import('@nestjs/swagger');
const { AppModule } = await import('../dist/app.module.js');

process.env.NODE_ENV ??= 'development';

const app = await NestFactory.create(AppModule, { logger: false });
app.setGlobalPrefix('v1', { exclude: ['health'] });

const config = new DocumentBuilder()
  .setTitle('NOCTA API')
  .setDescription('Sleep Identity Platform — v1')
  .setVersion('1.0.0')
  .addBearerAuth()
  .build();

const document = SwaggerModule.createDocument(app, config);
writeFileSync(OUT, JSON.stringify(document, null, 2) + '\n');
await app.close();
console.warn(`[api] OpenAPI yazıldı → ${OUT}`);
