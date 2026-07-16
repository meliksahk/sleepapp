import { Module, type Provider } from '@nestjs/common';
import { IdentityModule } from '../identity';
import { PrismaService } from '../../shared/infra/prisma.service';
import { ANALYTICS_EVENT_REPOSITORY, type AnalyticsEventRepository } from './domain/ports';
import { PrismaAnalyticsEventRepository } from './infrastructure/prisma-analytics-event.repository';
import { IngestEventsUseCase } from './application/ingest-events.usecase';
import { GetShareFunnelUseCase } from './application/get-share-funnel.usecase';
import { AnalyticsController } from './presentation/analytics.controller';

const providers: Provider[] = [
  {
    provide: ANALYTICS_EVENT_REPOSITORY,
    inject: [PrismaService],
    useFactory: (prisma: PrismaService): AnalyticsEventRepository =>
      new PrismaAnalyticsEventRepository(prisma),
  },
  {
    provide: IngestEventsUseCase,
    inject: [ANALYTICS_EVENT_REPOSITORY],
    useFactory: (repo: AnalyticsEventRepository): IngestEventsUseCase =>
      new IngestEventsUseCase(repo),
  },
  {
    provide: GetShareFunnelUseCase,
    inject: [ANALYTICS_EVENT_REPOSITORY],
    useFactory: (repo: AnalyticsEventRepository): GetShareFunnelUseCase =>
      new GetShareFunnelUseCase(repo),
  },
];

@Module({
  imports: [IdentityModule],
  controllers: [AnalyticsController],
  providers,
  // Yalnızca pano hunisi dışa açılır; olay yutma akışı analytics'e özeldir.
  exports: [GetShareFunnelUseCase],
})
export class AnalyticsModule {}
