import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { json, urlencoded } from 'express';
import { AppModule } from './app.module';
import { loadEnv } from './shared/config/env';
import { ProblemDetailsFilter } from './shared/http/problem-details.filter';
import { IdempotencyInterceptor } from './shared/http/idempotency.interceptor';

async function bootstrap(): Promise<void> {
  const env = loadEnv();
  // bodyParser: false → limitli parser'ları elle kaydederiz (DoS sertleşme).
  const app = await NestFactory.create(AppModule, {
    logger: ['error', 'warn', 'log'],
    bodyParser: false,
  });

  const bodyLimit = env.MAX_REQUEST_BODY_BYTES;
  app.use(json({ limit: bodyLimit }));
  app.use(urlencoded({ extended: true, limit: bodyLimit }));

  app.setGlobalPrefix('v1', { exclude: ['health'] });
  app.useGlobalPipes(
    new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }),
  );
  app.useGlobalFilters(new ProblemDetailsFilter());
  app.useGlobalInterceptors(new IdempotencyInterceptor());

  const config = new DocumentBuilder()
    .setTitle('NOCTA API')
    .setDescription('Sleep Identity Platform — v1')
    .setVersion('1.0.0')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('docs', app, document);

  await app.listen(env.API_PORT);
  // eslint-disable-next-line no-console
  console.log(`[api] NOCTA API :${env.API_PORT} (docs: /docs, health: /health)`);
}

void bootstrap();
