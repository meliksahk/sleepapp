import type { PrismaService } from '../infra/prisma.service';
import type { OutboxRecord, OutboxRepository } from './outbox.types';

interface Row {
  id: string;
  aggregate_type: string;
  event_type: string;
  payload: unknown;
  created_at: Date;
}

function toDomain(row: Row): OutboxRecord {
  return {
    id: row.id,
    aggregateType: row.aggregate_type,
    eventType: row.event_type,
    // payload yazarken Record<string, unknown> olarak konur; okurken aynı şekle indiririz.
    payload: (row.payload ?? {}) as Record<string, unknown>,
    createdAt: row.created_at,
  };
}

export class PrismaOutboxRepository implements OutboxRepository {
  constructor(private readonly prisma: PrismaService) {}

  async findUnpublished(limit: number): Promise<OutboxRecord[]> {
    const rows = await this.prisma.outbox.findMany({
      where: { published_at: null },
      orderBy: { created_at: 'asc' },
      take: limit,
    });
    return rows.map(toDomain);
  }

  async markPublished(id: string): Promise<void> {
    await this.prisma.outbox.update({
      where: { id },
      data: { published_at: new Date() },
    });
  }
}
