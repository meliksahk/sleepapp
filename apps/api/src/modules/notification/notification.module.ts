import { Module, type Provider } from '@nestjs/common';
import { IdentityModule } from '../identity';
import { PrismaService } from '../../shared/infra/prisma.service';
import { DEVICE_TOKEN_REPOSITORY, type DeviceTokenRepository } from './domain/device-token';
import { PUSH_SENDER, type PushSender } from './domain/push-sender';
import { PrismaDeviceTokenRepository } from './infrastructure/prisma-device-token.repository';
import { LogPushSender } from './infrastructure/log-push-sender';
import { RegisterDeviceTokenUseCase } from './application/register-device-token.usecase';
import { SendNotificationUseCase } from './application/send-notification.usecase';
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
  {
    provide: RegisterDeviceTokenUseCase,
    inject: [DEVICE_TOKEN_REPOSITORY],
    useFactory: (repo: DeviceTokenRepository): RegisterDeviceTokenUseCase =>
      new RegisterDeviceTokenUseCase(repo),
  },
  {
    provide: SendNotificationUseCase,
    inject: [DEVICE_TOKEN_REPOSITORY, PUSH_SENDER],
    useFactory: (repo: DeviceTokenRepository, sender: PushSender): SendNotificationUseCase =>
      new SendNotificationUseCase(repo, sender),
  },
];

@Module({
  imports: [IdentityModule],
  controllers: [NotificationController],
  providers,
  // Fan-out use case modül-dışı tetikleyiciler (admin kampanya / domain-event) için dışa açık.
  exports: [SendNotificationUseCase],
})
export class NotificationModule {}
