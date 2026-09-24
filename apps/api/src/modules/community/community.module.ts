import { Module, type Provider } from '@nestjs/common';
import { IdentityModule } from '../identity';
import { PrismaService } from '../../shared/infra/prisma.service';
import { ENV, loadEnv, type Env } from '../../shared/config/env';
import {
  COMMUNITY_REPOSITORY,
  USER_SOUND_STORAGE,
  type CommunityRepository,
  type UserSoundStorage,
} from './domain/ports';
import { CreateSoundUploadUseCase } from './application/create-sound-upload.usecase';
import { CompleteSoundUploadUseCase } from './application/complete-sound-upload.usecase';
import {
  ListMySoundsUseCase,
  ListSoundsForModerationUseCase,
  ModerateSoundUseCase,
  GetSoundPreviewUseCase,
} from './application/moderate-and-list.usecase';
import { PrismaCommunityRepository } from './infrastructure/prisma-community.repository';
import { S3UserSoundStorage } from './infrastructure/s3-user-sound.storage';
import { CommunityCleanupScheduler } from './infrastructure/community-cleanup.scheduler';
import { CleanupOrphanSoundsUseCase } from './application/cleanup-orphan-sounds.usecase';
import { CommunityController } from './presentation/community.controller';
import { AdminCommunityController } from './presentation/admin-community.controller';

const providers: Provider[] = [
  { provide: ENV, useFactory: (): Env => loadEnv() },
  {
    provide: COMMUNITY_REPOSITORY,
    inject: [PrismaService],
    useFactory: (prisma: PrismaService): CommunityRepository =>
      new PrismaCommunityRepository(prisma),
  },
  {
    provide: USER_SOUND_STORAGE,
    inject: [ENV],
    useFactory: (env: Env): UserSoundStorage =>
      new S3UserSoundStorage({
        endpoint: env.MINIO_ENDPOINT,
        region: env.MINIO_REGION,
        accessKey: env.MINIO_ROOT_USER,
        secretKey: env.MINIO_ROOT_PASSWORD,
      }),
  },
  {
    provide: CreateSoundUploadUseCase,
    inject: [COMMUNITY_REPOSITORY, USER_SOUND_STORAGE, ENV],
    useFactory: (
      repo: CommunityRepository,
      storage: UserSoundStorage,
      env: Env,
    ): CreateSoundUploadUseCase =>
      // Katalog bucket'ı bilinçli SEÇİM (ayrı bucket DEĞİL): onaylı topluluk
      // sesleri audio-assets listesinde BİRLEŞİR ve presigned GET tek bucket
      // varsayımıyla çalışır. Ayrı bucket, "yanlış-bucket" hata sınıfı doğururdu.
      // İzolasyon prefix ile sağlanır: community/{userId}/{soundId}.
      new CreateSoundUploadUseCase(repo, storage, env.MINIO_BUCKET_AUDIO_ASSETS),
  },
  {
    provide: CompleteSoundUploadUseCase,
    inject: [COMMUNITY_REPOSITORY, USER_SOUND_STORAGE, ENV],
    useFactory: (
      repo: CommunityRepository,
      storage: UserSoundStorage,
      env: Env,
    ): CompleteSoundUploadUseCase =>
      new CompleteSoundUploadUseCase(repo, storage, env.MINIO_BUCKET_AUDIO_ASSETS),
  },
  {
    provide: ListMySoundsUseCase,
    inject: [COMMUNITY_REPOSITORY],
    useFactory: (repo: CommunityRepository): ListMySoundsUseCase => new ListMySoundsUseCase(repo),
  },
  {
    provide: ListSoundsForModerationUseCase,
    inject: [COMMUNITY_REPOSITORY],
    useFactory: (repo: CommunityRepository): ListSoundsForModerationUseCase =>
      new ListSoundsForModerationUseCase(repo),
  },
  {
    provide: ModerateSoundUseCase,
    inject: [COMMUNITY_REPOSITORY],
    useFactory: (repo: CommunityRepository): ModerateSoundUseCase => new ModerateSoundUseCase(repo),
  },
  {
    provide: GetSoundPreviewUseCase,
    inject: [COMMUNITY_REPOSITORY, USER_SOUND_STORAGE, ENV],
    useFactory: (
      repo: CommunityRepository,
      storage: UserSoundStorage,
      env: Env,
    ): GetSoundPreviewUseCase =>
      new GetSoundPreviewUseCase(repo, storage, env.MINIO_BUCKET_AUDIO_ASSETS),
  },
  {
    provide: CleanupOrphanSoundsUseCase,
    inject: [COMMUNITY_REPOSITORY, USER_SOUND_STORAGE, ENV],
    useFactory: (
      repo: CommunityRepository,
      storage: UserSoundStorage,
      env: Env,
    ): CleanupOrphanSoundsUseCase =>
      new CleanupOrphanSoundsUseCase(repo, storage, env.MINIO_BUCKET_AUDIO_ASSETS),
  },
  // Temizlik zamanlayıcısı — Nest-managed (onModuleDestroy otomatik). redis
  // yoksa INERT instance döner: bağlantı açmaz, hook'ları no-op'tur.
  {
    provide: CommunityCleanupScheduler,
    inject: [CleanupOrphanSoundsUseCase, ENV],
    useFactory: (cleanup: CleanupOrphanSoundsUseCase, env: Env): CommunityCleanupScheduler =>
      new CommunityCleanupScheduler(env.REDIS_URL ?? null, cleanup),
  },
];

@Module({
  imports: [IdentityModule],
  controllers: [CommunityController, AdminCommunityController],
  providers,
  // Moderasyon use case'leri admin panelinin public yüzüdür; kullanıcı uçları uygulamaya özeldir.
  exports: [ListSoundsForModerationUseCase, ModerateSoundUseCase, ListMySoundsUseCase],
})
export class CommunityModule {}
