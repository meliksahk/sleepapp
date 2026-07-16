import { Module, type Provider } from '@nestjs/common';
import { IdentityModule } from '../identity';
import { ArchetypeModule, GetLatestResultUseCase } from '../archetype';
import { PrismaService } from '../../shared/infra/prisma.service';
import { ENV, loadEnv, type Env } from '../../shared/config/env';
import { CACHE, type Cache } from '../../shared/cache/cache.port';
import {
  ASSET_URL_SIGNER,
  CONTENT_REPOSITORY,
  type AssetUrlSigner,
  type ContentRepository,
} from './domain/soundscape';
import { USER_ARCHETYPE_READER, type UserArchetypeReader } from './domain/user-archetype-reader';
import { ListAllSoundscapesUseCase } from './application/list-all-soundscapes.usecase';
import { CreateSoundscapeUseCase } from './application/create-soundscape.usecase';
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
  // Cross-module adapter (module-def): archetype public servisinden kullanıcının
  // en son sonucunu okur. Content, archetype tablosuna DOKUNMAZ (port üzerinden).
  {
    provide: USER_ARCHETYPE_READER,
    inject: [GetLatestResultUseCase],
    useFactory: (getLatest: GetLatestResultUseCase): UserArchetypeReader => ({
      archetypeFor: async (userId) => (await getLatest.execute(userId))?.archetypeSlug,
    }),
  },
  {
    provide: GetFeedUseCase,
    inject: [CONTENT_REPOSITORY, CACHE, USER_ARCHETYPE_READER],
    useFactory: (
      repo: ContentRepository,
      cache: Cache,
      archetypes: UserArchetypeReader,
    ): GetFeedUseCase => new GetFeedUseCase(repo, cache, archetypes),
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
  {
    provide: ListAllSoundscapesUseCase,
    inject: [CONTENT_REPOSITORY],
    useFactory: (repo: ContentRepository): ListAllSoundscapesUseCase =>
      new ListAllSoundscapesUseCase(repo),
  },
  {
    provide: CreateSoundscapeUseCase,
    inject: [CONTENT_REPOSITORY],
    useFactory: (repo: ContentRepository): CreateSoundscapeUseCase =>
      new CreateSoundscapeUseCase(repo),
  },
];

@Module({
  imports: [IdentityModule, ArchetypeModule],
  controllers: [ContentController],
  providers,
  // Yalnızca admin listesi dışa açılır; feed/detay uygulamaya özeldir.
  exports: [ListAllSoundscapesUseCase, CreateSoundscapeUseCase],
})
export class ContentModule {}
