import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { json } from 'express';
import request from 'supertest';
import { AppModule } from '../../src/app.module';
import { ProblemDetailsFilter } from '../../src/shared/http/problem-details.filter';

/**
 * İstek gövdesi boyut limiti (DoS sertleşme, docs/02). main.ts bodyParser'ı elle
 * limitli kaydeder; burada küçük limitle (1kb) 413'ün problem+json döndüğünü kanıtlarız.
 */
describe('Body size limit e2e', () => {
  let app: INestApplication;
  const LIMIT = 1024; // 1kb — testte küçük tutulur

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication({ bodyParser: false });
    app.use(json({ limit: LIMIT }));
    app.setGlobalPrefix('v1', { exclude: ['health'] });
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }),
    );
    app.useGlobalFilters(new ProblemDetailsFilter());
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('limit altındaki gövde normal işlenir (küçük payload → 413 değil)', async () => {
    const res = await request(app.getHttpServer())
      .post('/v1/auth/device')
      .send({ fingerprint: `bl-ok-${Date.now()}`, platform: 'ios' });
    expect(res.status).not.toBe(413);
  });

  it('limiti aşan gövde → 413 application/problem+json', async () => {
    const huge = { fingerprint: 'x'.repeat(2048), platform: 'ios' }; // > 1kb
    const res = await request(app.getHttpServer()).post('/v1/auth/device').send(huge).expect(413);
    expect(res.headers['content-type']).toContain('application/problem+json');
    expect(res.body).toMatchObject({ title: 'Payload Too Large', status: 413 });
  });
});
