import 'reflect-metadata';
import { type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../../src/app.module';

/**
 * Global IP rate-limit (docs/02 B4).
 *
 * REGRESYON: `ThrottlerModule` kayıtlıydı ama **guard kayıtlı değildi** →
 * rate-limit yalnızca `@UseGuards(ThrottlerGuard)` yazan iki public controller'da
 * çalışıyordu; `/v1/auth/*` dahil TÜM uçlar korumasızdı. Bu test guard'ın global
 * olarak bağlı olduğunu kanıtlar.
 *
 * Limit env'den okunur ve fabrika her app kurulumunda çalışır → burada düşük
 * limit kurup gerçek davranışı ölçebiliyoruz (jest-setup-env testlerde yüksek
 * bırakır ki diğer e2e'ler 429 yemesin).
 */
describe('Global throttler e2e', () => {
  let app: INestApplication;
  const originalLimit = process.env.THROTTLE_LIMIT;
  const LIMIT = 3;

  beforeAll(async () => {
    process.env.THROTTLE_LIMIT = String(LIMIT);
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('v1', { exclude: ['health'] });
    await app.init();
  });

  afterAll(async () => {
    process.env.THROTTLE_LIMIT = originalLimit;
    await app.close();
  });

  it('limit aşılınca 429 döner (guard global olarak bağlı)', async () => {
    // Limit kadar istek geçmeli...
    for (let i = 0; i < LIMIT; i++) {
      await request(app.getHttpServer()).get('/health').expect(200);
    }
    // ...bir fazlası reddedilmeli. Guard bağlı DEĞİLKEN bu 200 dönerdi.
    await request(app.getHttpServer()).get('/health').expect(429);
  });

  it('anonim hesap açma korumalı (eskiden SINIRSIZDI)', async () => {
    // NOT: throttler sayacı ROTA BAŞINA tutulur (IP başına tek havuz değil) —
    // /health'i doldurmak burayı etkilemez, bu yüzden ucu kendisi doldurulur.
    const post = (): request.Test =>
      request(app.getHttpServer())
        .post('/v1/auth/device')
        .send({
          fingerprint: `throttle-${Date.now()}-${Math.round(process.hrtime()[1])}`,
          platform: 'ios',
        });

    for (let i = 0; i < LIMIT; i++) {
      await post().expect(201);
    }
    // Guard bağlı DEĞİLKEN bu da 201 dönerdi → sınırsız anonim hesap (DB şişirme).
    await post().expect(429);
  });
});
