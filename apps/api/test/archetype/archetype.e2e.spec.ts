import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../../src/app.module';

/** archetype uçtan uca (gerçek DB). Skorlama + kalıcılık + izolasyon. */
describe('Archetype e2e (HTTP)', () => {
  let app: INestApplication;

  const token = async (): Promise<{ token: string; userId: string }> => {
    const res = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({
        fingerprint: `arch-e2e-${Date.now()}-${Math.round(process.hrtime()[1])}`,
        platform: 'ios',
      })
      .expect(201);
    return { token: res.body.accessToken, userId: res.body.userId };
  };

  const allB = { q1: 'q1b', q2: 'q2b', q3: 'q3b', q4: 'q4b', q5: 'q5b', q6: 'q6b' };

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('v1', { exclude: ['health'] });
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }),
    );
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('GET questions → version 1, 6 soru', async () => {
    const { token: t } = await token();
    const res = await request(app.getHttpServer())
      .get('/v1/archetype/questions')
      .set('Authorization', `Bearer ${t}`)
      .expect(200);
    expect(res.body.version).toBe(1);
    expect(res.body.questions).toHaveLength(6);
  });

  it('POST answers (tüm B) → overthinker, sonra GET result kalıcı', async () => {
    const { token: t, userId } = await token();
    const submit = await request(app.getHttpServer())
      .post('/v1/archetype/answers')
      .set('Authorization', `Bearer ${t}`)
      .send({ version: 1, answers: allB })
      .expect(201);
    expect(submit.body.archetypeSlug).toBe('overthinker');
    expect(submit.body.userId).toBe(userId);
    expect(submit.body.scores.overthinker).toBe(6);

    const result = await request(app.getHttpServer())
      .get('/v1/archetype/result')
      .set('Authorization', `Bearer ${t}`)
      .expect(200);
    expect(result.body.archetypeSlug).toBe('overthinker');
  });

  it('sonuç geçmişi: testi tekrar edince kayıtlar birikir, yeniden eskiye sıralı', async () => {
    const { token: t } = await token();
    const allA = { q1: 'q1a', q2: 'q2a', q3: 'q3a', q4: 'q4a', q5: 'q5a', q6: 'q6a' };

    // 1) overthinker
    await request(app.getHttpServer())
      .post('/v1/archetype/answers')
      .set('Authorization', `Bearer ${t}`)
      .send({ version: 1, answers: allB })
      .expect(201);
    // 2) testi tekrar et → deep-ocean (kimlik zamanla değişir)
    await request(app.getHttpServer())
      .post('/v1/archetype/answers')
      .set('Authorization', `Bearer ${t}`)
      .send({ version: 1, answers: allA })
      .expect(201);

    const res = await request(app.getHttpServer())
      .get('/v1/archetype/results')
      .set('Authorization', `Bearer ${t}`)
      .expect(200);

    // Eskiden yalnızca EN SON sonuç erişilebiliyordu; ilk kayıt kayıp görünürdü.
    expect(res.body).toHaveLength(2);
    expect(res.body[0].archetypeSlug).toBe('deep-ocean'); // en yeni önce
    expect(res.body[1].archetypeSlug).toBe('overthinker');
    // /result hâlâ en sonu döner (geçmiş onu değiştirmez)
    const latest = await request(app.getHttpServer())
      .get('/v1/archetype/result')
      .set('Authorization', `Bearer ${t}`)
      .expect(200);
    expect(latest.body.archetypeSlug).toBe('deep-ocean');
  });

  it('izolasyon: geçmiş yalnızca kendi sonuçlarını içerir', async () => {
    const a = await token();
    const b = await token();
    await request(app.getHttpServer())
      .post('/v1/archetype/answers')
      .set('Authorization', `Bearer ${a.token}`)
      .send({ version: 1, answers: allB })
      .expect(201);

    // B hiç test yapmadı → boş geçmiş (A'nınkini GÖRMEZ)
    const res = await request(app.getHttpServer())
      .get('/v1/archetype/results')
      .set('Authorization', `Bearer ${b.token}`)
      .expect(200);
    expect(res.body).toEqual([]);
  });

  it('eksik cevap → 400', async () => {
    const { token: t } = await token();
    await request(app.getHttpServer())
      .post('/v1/archetype/answers')
      .set('Authorization', `Bearer ${t}`)
      .send({ version: 1, answers: { q1: 'q1a' } })
      .expect(400);
  });

  it('desteklenmeyen sürüm → 400', async () => {
    const { token: t } = await token();
    await request(app.getHttpServer())
      .post('/v1/archetype/answers')
      .set('Authorization', `Bearer ${t}`)
      .send({ version: 999, answers: allB })
      .expect(400);
  });

  it('izolasyon: yeni kullanıcının sonucu yok → 404 (başkasının sonucunu görmez)', async () => {
    const { token: a } = await token();
    await request(app.getHttpServer())
      .post('/v1/archetype/answers')
      .set('Authorization', `Bearer ${a}`)
      .send({ version: 1, answers: allB })
      .expect(201);

    const { token: b } = await token();
    await request(app.getHttpServer())
      .get('/v1/archetype/result')
      .set('Authorization', `Bearer ${b}`)
      .expect(404);
  });
});
