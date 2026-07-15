import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../../src/app.module';

/** Public bekleme listesi e2e (docs/05 W0, gerçek DB). */
describe('Waitlist e2e (HTTP, public)', () => {
  let app: INestApplication;
  const prisma = new PrismaClient();
  const emails: string[] = [];
  const mk = (): string => {
    const e = `wl-${Date.now()}-${Math.round(process.hrtime()[1])}@example.com`;
    emails.push(e);
    return e;
  };

  beforeAll(async () => {
    await prisma.$connect();
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    app.setGlobalPrefix('v1', { exclude: ['health'] });
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }),
    );
    await app.init();
  });

  afterAll(async () => {
    if (emails.length) await prisma.waitlist.deleteMany({ where: { email: { in: emails } } });
    await prisma.$disconnect();
    await app.close();
  });

  it("token olmadan katılır (202) ve DB'ye yazılır", async () => {
    const email = mk();
    await request(app.getHttpServer())
      .post('/v1/waitlist')
      .send({ email, source: 'tiktok' })
      .expect(202);
    const row = await prisma.waitlist.findUnique({ where: { email } });
    expect(row?.source).toBe('tiktok');
  });

  it('aynı e-posta idempotent (ikinci kez 202, tek satır)', async () => {
    const email = mk();
    await request(app.getHttpServer()).post('/v1/waitlist').send({ email }).expect(202);
    await request(app.getHttpServer()).post('/v1/waitlist').send({ email }).expect(202);
    const count = await prisma.waitlist.count({ where: { email } });
    expect(count).toBe(1);
  });

  it('geçersiz e-posta → 400', async () => {
    await request(app.getHttpServer())
      .post('/v1/waitlist')
      .send({ email: 'not-an-email' })
      .expect(400);
  });
});
