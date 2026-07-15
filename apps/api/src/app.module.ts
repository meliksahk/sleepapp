import { Module } from '@nestjs/common';
import { PrismaModule } from './shared/infra/prisma.module';
import { HealthModule } from './shared/health/health.module';
import { IdentityModule } from './modules/identity/identity.module';
import { ProfileModule } from './modules/profile/profile.module';
import { ArchetypeModule } from './modules/archetype/archetype.module';

@Module({
  imports: [PrismaModule, HealthModule, IdentityModule, ProfileModule, ArchetypeModule],
})
export class AppModule {}
