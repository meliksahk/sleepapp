import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { AppModule } from '../../src/app.module';

/** archetype content e2e — PUBLIC (kimlik gerektirmez). */
describe('Archetype content e2e (HTTP)', () => {
  let app: INestApplication;

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

  it('GET /v1/archetype/content → 200 (auth yok), 4 içerik', async () => {
    const res = await request(app.getHttpServer()).get('/v1/archetype/content').expect(200);
    expect(res.body).toHaveLength(4);
    const deep = res.body.find((a: { slug: string }) => a.slug === 'deep-ocean');
    expect(deep.name).toBe('Deep Ocean');
    expect(typeof deep.tagline).toBe('string');
    expect(typeof deep.summary).toBe('string');
  });
});
