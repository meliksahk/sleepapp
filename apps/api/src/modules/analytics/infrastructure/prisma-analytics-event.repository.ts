import type { PrismaService } from '../../../shared/infra/prisma.service';
import type { NewAnalyticsEvent } from '../domain/analytics-event';
import type { AnalyticsEventRepository, ShareFunnelCounts } from '../domain/ports';

export class PrismaAnalyticsEventRepository implements AnalyticsEventRepository {
  constructor(private readonly prisma: PrismaService) {}

  async saveBatch(userId: string, events: readonly NewAnalyticsEvent[]): Promise<number> {
    const result = await this.prisma.analytics_events.createMany({
      data: events.map((e) => ({
        user_id: userId,
        name: e.name,
        occurred_at: e.occurredAt,
        props: e.props as object,
      })),
    });
    return result.count;
  }

  async shareFunnel(): Promise<ShareFunnelCounts> {
    // BENZERSİZ KULLANICI: tek kullanıcı 5 kez paylaşırsa oran "%500" olurdu.
    // Prisma'da COUNT(DISTINCT) yok → groupBy(user_id) satır sayısı aynı şeydir
    // ve DB'de yapılır (satırlar belleğe çekilmez).
    const [completed, shared] = await Promise.all([
      this.prisma.analytics_events.groupBy({
        by: ['user_id'],
        where: { name: 'archetype_completed' },
      }),
      this.prisma.analytics_events.groupBy({
        by: ['user_id'],
        where: { name: 'share_tapped' },
      }),
    ]);
    return { completed: completed.length, shared: shared.length };
  }
}
