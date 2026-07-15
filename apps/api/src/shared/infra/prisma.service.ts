import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

/**
 * Prisma bağlantı yaşam döngüsü. DB dış dünyaya kapalı; tek kapı API (docs/02 §3).
 * Migration'lar SQL-first (dbmate); Prisma yalnızca sorgu/erişim katmanı.
 */
@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PrismaService.name);

  async onModuleInit(): Promise<void> {
    await this.$connect();
    this.logger.log('Prisma bağlandı.');
  }

  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
  }
}
