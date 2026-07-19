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
import { SetSoundscapeStatusUseCase } from './application/set-soundscape-status.usecase';
import { SetSoundscapeRecipeUseCase } from './application/set-soundscape-recipe.usecase';
import { GetAdminSoundscapeUseCase } from './application/get-admin-soundscape.usecase';
import { UpdateSoundscapeUseCase } from './application/update-soundscape.usecase';
import { CountSoundscapesUseCase } from './application/count-soundscapes.usecase';
import { PrismaContentRepository } from './infrastructure/prisma-content.repository';
import { S3AssetSigner } from './infrastructure/s3-asset.signer';
import { GetFeedUseCase } from './application/get-feed.usecase';
import { GetSoundscapeUseCase } from './application/get-soundscape.usecase';
import { GetWeeklyReleaseUseCase } from './application/get-weekly-release.usecase';
import { ListAudioAssetsUseCase } from './application/list-audio-assets.usecase';
import { GetAudioAssetUseCase } from './application/get-audio-asset.usecase';
import { AUDIO_ASSET_REPOSITORY, type AudioAssetRepository } from './domain/audio-asset';
import { PrismaAudioAssetRepository } from './infrastructure/prisma-audio-asset.repository';
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
    provide: AUDIO_ASSET_REPOSITORY,
    inject: [PrismaService],
    useFactory: (prisma: PrismaService): AudioAssetRepository =>
      new PrismaAudioAssetRepository(prisma),
  },
  {
    provide: ListAudioAssetsUseCase,
    inject: [AUDIO_ASSET_REPOSITORY],
    useFactory: (repo: AudioAssetRepository): ListAudioAssetsUseCase =>
      new ListAudioAssetsUseCase(repo),
  },
  {
    provide: GetAudioAssetUseCase,
    inject: [AUDIO_ASSET_REPOSITORY, ASSET_URL_SIGNER, ENV],
    useFactory: (
      repo: AudioAssetRepository,
      signer: AssetUrlSigner,
      env: Env,
    ): GetAudioAssetUseCase =>
      new GetAudioAssetUseCase(repo, signer, env.MINIO_BUCKET_AUDIO_ASSETS),
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
  {
    provide: SetSoundscapeStatusUseCase,
    inject: [CONTENT_REPOSITORY, CACHE],
    useFactory: (repo: ContentRepository, cache: Cache): SetSoundscapeStatusUseCase =>
      new SetSoundscapeStatusUseCase(repo, cache),
  },
  {
    provide: CountSoundscapesUseCase,
    inject: [CONTENT_REPOSITORY],
    useFactory: (repo: ContentRepository): CountSoundscapesUseCase =>
      new CountSoundscapesUseCase(repo),
  },
  {
    provide: UpdateSoundscapeUseCase,
    inject: [CONTENT_REPOSITORY, CACHE],
    useFactory: (repo: ContentRepository, cache: Cache): UpdateSoundscapeUseCase =>
      new UpdateSoundscapeUseCase(repo, cache),
  },
  {
    provide: GetAdminSoundscapeUseCase,
    inject: [CONTENT_REPOSITORY],
    useFactory: (repo: ContentRepository): GetAdminSoundscapeUseCase =>
      new GetAdminSoundscapeUseCase(repo),
  },
  {
    provide: SetSoundscapeRecipeUseCase,
    inject: [CONTENT_REPOSITORY, CACHE],
    useFactory: (repo: ContentRepository, cache: Cache): SetSoundscapeRecipeUseCase =>
      new SetSoundscapeRecipeUseCase(repo, cache),
  },
];

@Module({
  imports: [IdentityModule, ArchetypeModule],
  controllers: [ContentController],
  providers,
  // Yalnızca admin listesi dışa açılır; feed/detay uygulamaya özeldir.
  exports: [
    ListAllSoundscapesUseCase,
    CreateSoundscapeUseCase,
    SetSoundscapeStatusUseCase,
    SetSoundscapeRecipeUseCase,
    GetAdminSoundscapeUseCase,
    UpdateSoundscapeUseCase,
    CountSoundscapesUseCase,
  ],
})
export class ContentModule {}
