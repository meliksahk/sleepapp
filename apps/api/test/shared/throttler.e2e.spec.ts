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

  /**
   * SIRA BAĞIMSIZLIĞI (yoksa bu test kırılgandır).
   *
   * Rate-limit sayacı Redis'te ve TÜM testler arasında PAYLAŞILIR. Her e2e testi
   * oturum açmak için `POST /v1/auth/device` çağırdığından, bu dosya paketin
   * sonlarında çalıştığında kota çoktan tükenmiş olur ve döngünün ilk isteği
   * 201 yerine 429 alır. Gerçekten yaşandı: alakasız bir birim test dosyası
   * eklenince jest'in dosya sırası değişti ve test kırıldı — kod hiç değişmemişti.
   *
   * Bu yüzden sayaçları test BAŞINDA sıfırlıyoruz. Testler `--runInBand`
   * (sıralı) koştuğu için başka bir testin sayacını yarıda silme riski yok.
   */
  async function resetThrottleCounters(): Promise<void> {
    const url = process.env.REDIS_URL;
    // REDIS_URL yoksa depolama bellek-içidir ve her app kurulumunda zaten sıfırdır.
    if (!url) return;
    const { default: IORedis } = await import('ioredis');
    const redis = new IORedis(url, { maxRetriesPerRequest: null });
    try {
      const keys = await redis.keys('throttle:*');
      if (keys.length > 0) await redis.del(...keys);
    } finally {
      await redis.quit();
    }
  }

  // HER TESTTEN ÖNCE sıfırla, yalnızca dosya başında değil: iki test AYNI IP'yi
  // kullanıyor ve sayaç pencereye (TTL) bağlı olduğu için ilk testin tükettiği
  // kota ikinciyi zamanlamaya göre bazen düşürüyordu (arka arkaya iki koşuda
  // biri geçip biri kalıyordu — klasik flake).
  beforeEach(resetThrottleCounters);

  beforeAll(async () => {
    process.env.THROTTLE_LIMIT = String(LIMIT);
    await resetThrottleCounters();
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
