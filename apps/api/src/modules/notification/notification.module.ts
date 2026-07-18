import { Module, type Provider } from '@nestjs/common';
import { IdentityModule } from '../identity';
import { ProfileModule, GetProfileUseCase } from '../profile';
import { PrismaService } from '../../shared/infra/prisma.service';
import { loadEnv } from '../../shared/config/env';
import { DEVICE_TOKEN_REPOSITORY, type DeviceTokenRepository } from './domain/device-token';
import {
  NOTIFICATION_PREFERENCE_READER,
  type NotificationPreferenceReader,
} from './domain/notification-preference';
import { PUSH_SENDER, type PushSender } from './domain/push-sender';
import { PUSH_QUEUE, type PushQueue } from './domain/push-queue';
import { PrismaDeviceTokenRepository } from './infrastructure/prisma-device-token.repository';
import { LogPushSender } from './infrastructure/log-push-sender';
import { InlinePushQueue } from './infrastructure/inline-push-queue';
import { BullMqPushQueue } from './infrastructure/bullmq-push-queue';
import { RegisterDeviceTokenUseCase } from './application/register-device-token.usecase';
import { SendNotificationUseCase } from './application/send-notification.usecase';
import { SendCampaignUseCase } from './application/send-campaign.usecase';
import { CountPushAudienceUseCase } from './application/count-push-audience.usecase';
import { NotificationController } from './presentation/notification.controller';

const providers: Provider[] = [
  {
    provide: DEVICE_TOKEN_REPOSITORY,
    inject: [PrismaService],
    useFactory: (prisma: PrismaService): DeviceTokenRepository =>
      new PrismaDeviceTokenRepository(prisma),
  },
  // Geliştirmede log-adaptörü; gerçek APNs/FCM docs/10'da bu provider değişerek takılır.
  { provide: PUSH_SENDER, useFactory: (): PushSender => new LogPushSender() },
  // Cross-module adapter (module-def): profil public servisinden opt-out bayrağını okur.
  // Notification, profiles tablosuna DOKUNMAZ (port üzerinden).
  {
    provide: NOTIFICATION_PREFERENCE_READER,
    inject: [GetProfileUseCase],
    useFactory: (getProfile: GetProfileUseCase): NotificationPreferenceReader => ({
      isEnabledFor: async (userId) => (await getProfile.execute(userId)).notificationsEnabled,
    }),
  },
  {
    provide: RegisterDeviceTokenUseCase,
    inject: [DEVICE_TOKEN_REPOSITORY],
    useFactory: (repo: DeviceTokenRepository): RegisterDeviceTokenUseCase =>
      new RegisterDeviceTokenUseCase(repo),
  },
  {
    provide: SendNotificationUseCase,
    inject: [DEVICE_TOKEN_REPOSITORY, PUSH_SENDER, NOTIFICATION_PREFERENCE_READER],
    useFactory: (
      repo: DeviceTokenRepository,
      sender: PushSender,
      preferences: NotificationPreferenceReader,
    ): SendNotificationUseCase => new SendNotificationUseCase(repo, sender, preferences),
  },
  // Push kuyruğu: REDIS_URL varsa BullMQ (asenkron, worker + retry), yoksa inline (senkron —
  // dev/test). Cache modülüyle aynı env-gate deseni. BullMqPushQueue.onModuleDestroy'u NestJS
  // otomatik çağırır (RedisCache gibi) → açık Redis soketleri süreçte asılı kalmaz.
  {
    provide: PUSH_QUEUE,
    inject: [SendNotificationUseCase],
    useFactory: (send: SendNotificationUseCase): PushQueue => {
      const { REDIS_URL } = loadEnv();
      return REDIS_URL ? new BullMqPushQueue(REDIS_URL, send) : new InlinePushQueue(send);
    },
  },
  {
    provide: SendCampaignUseCase,
    inject: [DEVICE_TOKEN_REPOSITORY, PUSH_QUEUE],
    useFactory: (repo: DeviceTokenRepository, queue: PushQueue): SendCampaignUseCase =>
      new SendCampaignUseCase(repo, queue),
  },
  {
    provide: CountPushAudienceUseCase,
    inject: [DEVICE_TOKEN_REPOSITORY],
    useFactory: (repo: DeviceTokenRepository): CountPushAudienceUseCase =>
      new CountPushAudienceUseCase(repo),
  },
];

@Module({
  imports: [IdentityModule, ProfileModule],
  controllers: [NotificationController],
  providers,
  // Fan-out use case modül-dışı tetikleyiciler (admin kampanya / domain-event) için dışa açık.
  exports: [SendNotificationUseCase, SendCampaignUseCase, CountPushAudienceUseCase],
})
export class NotificationModule {}
