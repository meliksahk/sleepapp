import { Module, type Provider } from '@nestjs/common';
import { IdentityModule } from '../identity';
import { PrismaService } from '../../shared/infra/prisma.service';
import { CONTENT_REPOSITORY, type ContentRepository } from './domain/soundscape';
import { PrismaContentRepository } from './infrastructure/prisma-content.repository';
import { GetFeedUseCase } from './application/get-feed.usecase';
import { GetSoundscapeUseCase } from './application/get-soundscape.usecase';
import { ContentController } from './presentation/content.controller';

const providers: Provider[] = [
  {
    provide: CONTENT_REPOSITORY,
    inject: [PrismaService],
    useFactory: (prisma: PrismaService): ContentRepository => new PrismaContentRepository(prisma),
  },
  {
    provide: GetFeedUseCase,
    inject: [CONTENT_REPOSITORY],
    useFactory: (repo: ContentRepository): GetFeedUseCase => new GetFeedUseCase(repo),
  },
  {
    provide: GetSoundscapeUseCase,
    inject: [CONTENT_REPOSITORY],
    useFactory: (repo: ContentRepository): GetSoundscapeUseCase => new GetSoundscapeUseCase(repo),
  },
];

@Module({
  imports: [IdentityModule],
  controllers: [ContentController],
  providers,
})
export class ContentModule {}
