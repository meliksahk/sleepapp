import { Global, Module } from '@nestjs/common';

import { PrismaService } from '../infra/prisma.service';
import { OutboxWriter } from './outbox-writer';
import { OUTBOX_REPOSITORY, type OutboxRepository } from './outbox.types';
import { PrismaOutboxRepository } from './prisma-outbox.repository';

/**
 * Global outbox altyapısı. `OutboxWriter` her modülün transaction'ı içinde olay yazmak için;
 * `OUTBOX_REPOSITORY` relay'in yayınlanmamışları okuması için. Cache/Prisma gibi paylaşımlı
 * altyapı — modül sınırı ihlali değil (relay ve yazar modülleri buradan tüketir).
 */
@Global()
@Module({
  providers: [
    OutboxWriter,
    {
      provide: OUTBOX_REPOSITORY,
      inject: [PrismaService],
      useFactory: (prisma: PrismaService): OutboxRepository => new PrismaOutboxRepository(prisma),
    },
  ],
  exports: [OutboxWriter, OUTBOX_REPOSITORY],
})
export class OutboxModule {}
