import { Module, type Provider } from '@nestjs/common';
import { IdentityModule } from '../identity';
import { PrismaService } from '../../shared/infra/prisma.service';
import { DEVICE_TOKEN_REPOSITORY, type DeviceTokenRepository } from './domain/device-token';
import { PrismaDeviceTokenRepository } from './infrastructure/prisma-device-token.repository';
import { RegisterDeviceTokenUseCase } from './application/register-device-token.usecase';
import { NotificationController } from './presentation/notification.controller';

const providers: Provider[] = [
  {
    provide: DEVICE_TOKEN_REPOSITORY,
    inject: [PrismaService],
    useFactory: (prisma: PrismaService): DeviceTokenRepository =>
      new PrismaDeviceTokenRepository(prisma),
  },
  {
    provide: RegisterDeviceTokenUseCase,
    inject: [DEVICE_TOKEN_REPOSITORY],
    useFactory: (repo: DeviceTokenRepository): RegisterDeviceTokenUseCase =>
      new RegisterDeviceTokenUseCase(repo),
  },
];

@Module({
  imports: [IdentityModule],
  controllers: [NotificationController],
  providers,
})
export class NotificationModule {}
