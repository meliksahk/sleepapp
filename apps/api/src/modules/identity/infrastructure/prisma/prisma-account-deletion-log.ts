import { Logger } from '@nestjs/common';

import type { PrismaService } from '../../../../shared/infra/prisma.service';
import type { AccountDeletionLog } from '../../domain/account-deletion-log';

/**
 * Sayaç adaptörü. `record` HATA YUTAR (port sözleşmesi): silme işlemini bir
 * istatistik yazımı yüzünden geri çeviremeyiz.
 */
export class PrismaAccountDeletionLog implements AccountDeletionLog {
  private readonly logger = new Logger(PrismaAccountDeletionLog.name);

  constructor(private readonly prisma: PrismaService) {}

  async record(): Promise<void> {
    try {
      await this.prisma.account_deletions.create({ data: {} });
    } catch (error) {
      // Sessiz DEĞİL: loglanır. Ama kullanıcının silme akışı devam eder.
      this.logger.error(`hesap silme sayacı yazılamadı: ${String(error)}`);
    }
  }

  async countSince(since: Date): Promise<number> {
    return this.prisma.account_deletions.count({ where: { deleted_at: { gte: since } } });
  }
}
