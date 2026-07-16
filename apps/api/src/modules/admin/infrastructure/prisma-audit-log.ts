import { Logger } from '@nestjs/common';
import type { PrismaService } from '../../../shared/infra/prisma.service';
import type { AuditAction, AuditEntry, AuditLog, NewAuditEntry } from '../domain/audit';

/**
 * Denetim izi (Prisma).
 *
 * `actor_email` DONDURULUR: hesap silinse bile "kim yaptı" okunabilsin (FK
 * ON DELETE SET NULL — iz kaybolmasın diye CASCADE değil). Bu denormalizasyon
 * bilinçli: denetim izinin bütün anlamı geçmişin değişmemesidir.
 */
export class PrismaAuditLog implements AuditLog {
  private readonly logger = new Logger(PrismaAuditLog.name);

  constructor(private readonly prisma: PrismaService) {}

  async record(entry: NewAuditEntry): Promise<void> {
    try {
      // E-posta çağıranın KENDİ kaydından okunur; gövdeden gelen bir değere
      // güvenmek izi işe yaramaz kılardı.
      const user = await this.prisma.users.findUnique({ where: { id: entry.actorId } });

      await this.prisma.admin_audit_log.create({
        data: {
          actor_id: entry.actorId,
          // Hesabın e-postası yoksa (olmamalı) id'yi yaz: "bilinmiyor" demektense
          // izlenebilir bir şey bırak.
          actor_email: user?.email ?? `id:${entry.actorId}`,
          action: entry.action,
          target: entry.target,
          // Prisma'nın InputJsonValue'suna daraltma: details serbest bağlam (PII yok).
          details: (entry.details ?? {}) as object,
        },
      });
    } catch (e) {
      // ASLA ATMA: iz yazılamadı diye editörün yayınlama işlemi başarısız olmamalı.
      // Ama SESSİZ de kalma — kayıp iz görünür olsun (boş catch yasak, CLAUDE.md §4).
      this.logger.error(
        `Denetim izi yazılamadı: ${entry.action} ${entry.target}`,
        e instanceof Error ? e.stack : String(e),
      );
    }
  }

  async recent(limit: number): Promise<AuditEntry[]> {
    const rows = await this.prisma.admin_audit_log.findMany({
      orderBy: { created_at: 'desc' },
      take: limit,
    });
    return rows.map((r) => ({
      id: r.id,
      actorEmail: r.actor_email,
      action: r.action as AuditAction,
      target: r.target,
      details: (r.details ?? {}) as Record<string, unknown>,
      createdAt: r.created_at,
    }));
  }
}
