import 'reflect-metadata';
import { ValidationPipe, type INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../../src/app.module';

/**
 * Admin girişine ÖZEL kaba kuvvet limiti.
 *
 * NEDEN AYRI LİMİT: global limit route başına 60 istek/dakika (env.ts varsayılanı).
 * Sistemdeki EN DEĞERLİ hesap için bu, tek IP'den dakikada 60 / günde 86.400 parola
 * denemesi demektir — #114'te bu riski kendim işaretledim. Global limit "gezinme"
 * için makul, "parola tahmini" için değil; bu yüzden uca özel ve çok daha sıkı.
 *
 * Bu test, ADMIN_LOGIN_THROTTLE eklenmeden ÖNCE kırmızıydı: 10 deneme de 401
 * dönüyordu, 429 hiç gelmiyordu (kanıt PR açıklamasında).
 *
 * THROTTLE_LIMIT burada BİLEREK yüksek bırakılıyor (jest-setup-env varsayılanı):
 * böylece 429 gelirse bunun sebebi GLOBAL limit değil, uca özel limittir.
 */
describe('Admin girişi kaba kuvvet limiti e2e', () => {
  let app: INestApplication;
  const prisma = new PrismaClient();
  const email = `throttle-${Date.now()}@nocta.test`;

  const ADMIN_LOGIN_LIMIT = 5;
  const originalLoginLimit = process.env.ADMIN_LOGIN_LIMIT;

  beforeAll(async () => {
    // Açıkça sabitlenir: başka bir spec ADMIN_LOGIN_LIMIT'i yükseltip bırakırsa
    // bu test sessizce anlamsızlaşırdı (429 hiç gelmez, ama "geçer" görünürdü).
    process.env.ADMIN_LOGIN_LIMIT = String(ADMIN_LOGIN_LIMIT);
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
    process.env.ADMIN_LOGIN_LIMIT = originalLoginLimit;
    await prisma.$disconnect();
    await app.close();
  });

  it(`${ADMIN_LOGIN_LIMIT} yanlış denemeden sonra 429 (global limit 60'a takılmadan)`, async () => {
    const attempt = () =>
      request(app.getHttpServer())
        .post('/v1/auth/admin/login')
        .send({ email, password: 'wrong-password-guess' });

    // Limit kadar deneme 401 almalı (hesap yok → kimlik hatası, limit hatası değil).
    for (let i = 0; i < ADMIN_LOGIN_LIMIT; i++) {
      await attempt().expect(401);
    }
    // Bir fazlası artık DENENMEMELİ — parola doğru olsa bile kapı kapalı.
    await attempt().expect(429);
  });
});
