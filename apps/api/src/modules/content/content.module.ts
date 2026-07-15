import { Module, type Provider } from '@nestjs/common';
import { IdentityModule } from '../identity';
import { PrismaService } from '../../shared/infra/prisma.service';
import { ENV, loadEnv, type Env } from '../../shared/config/env';
import {
  ASSET_URL_SIGNER,
  CONTENT_REPOSITORY,
  type AssetUrlSigner,
  type ContentRepository,
} from './domain/soundscape';
import { PrismaContentRepository } from './infrastructure/prisma-content.repository';
import { S3AssetSigner } from './infrastructure/s3-asset.signer';
import { GetFeedUseCase } from './application/get-feed.usecase';
import { GetSoundscapeUseCase } from './application/get-soundscape.usecase';
import { GetWeeklyReleaseUseCase } from './application/get-weekly-release.usecase';
import { ContentController } from './presentation/content.controller';

const providers: Provider[] = [
  { provide: ENV, useFactory: (): Env => loadEnv() },
  {
    provide: CONTENT_REPOSITORY,
    inject: [PrismaService],
    useFactory: (prisma: PrismaService): ContentRepository => new PrismaContentRepository(prisma),
  },
  {
    provide: ASSET_URL_SIGNER,
    inject: [ENV],
    useFactory: (env: Env): AssetUrlSigner =>
      new S3AssetSigner({
        endpoint: env.MINIO_ENDPOINT,
        region: env.MINIO_REGION,
        accessKey: env.MINIO_ROOT_USER,
        secretKey: env.MINIO_ROOT_PASSWORD,
      }),
  },
  {
    provide: GetFeedUseCase,
    inject: [CONTENT_REPOSITORY],
    useFactory: (repo: ContentRepository): GetFeedUseCase => new GetFeedUseCase(repo),
  },
  {
    provide: GetSoundscapeUseCase,
    inject: [CONTENT_REPOSITORY, ASSET_URL_SIGNER, ENV],
    useFactory: (repo: ContentRepository, signer: AssetUrlSigner, env: Env): GetSoundscapeUseCase =>
      new GetSoundscapeUseCase(repo, signer, env.MINIO_BUCKET_SOUNDSCAPES),
  },
  {
    provide: GetWeeklyReleaseUseCase,
    inject: [CONTENT_REPOSITORY],
    useFactory: (repo: ContentRepository): GetWeeklyReleaseUseCase =>
      new GetWeeklyReleaseUseCase(repo),
  },
];

@Module({
  imports: [IdentityModule],
  controllers: [ContentController],
  providers,
})
export class ContentModule {}
