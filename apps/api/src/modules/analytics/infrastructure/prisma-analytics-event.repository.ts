import type { PrismaService } from '../../../shared/infra/prisma.service';
import type { NewAnalyticsEvent } from '../domain/analytics-event';
import type { AnalyticsEventRepository } from '../domain/ports';

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
}
