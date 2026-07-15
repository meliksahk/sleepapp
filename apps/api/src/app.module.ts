import { Module } from '@nestjs/common';
import { PrismaModule } from './shared/infra/prisma.module';
import { HealthModule } from './shared/health/health.module';
import { IdentityModule } from './modules/identity/identity.module';
import { ProfileModule } from './modules/profile/profile.module';

@Module({
  imports: [PrismaModule, HealthModule, IdentityModule, ProfileModule],
})
export class AppModule {}
