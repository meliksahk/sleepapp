import { Module } from '@nestjs/common';
import { ThrottlerModule } from '@nestjs/throttler';
import { PrismaModule } from './shared/infra/prisma.module';
import { HealthModule } from './shared/health/health.module';
import { IdentityModule } from './modules/identity/identity.module';
import { ProfileModule } from './modules/profile/profile.module';
import { ArchetypeModule } from './modules/archetype/archetype.module';
import { FlagsModule } from './modules/flags/flags.module';
import { ContentModule } from './modules/content/content.module';

@Module({
  imports: [
    // In-memory IP rate-limit (throttler). Dağıtık/Redis tabanlı limit B4 sertleşmede.
    ThrottlerModule.forRoot([{ ttl: 60_000, limit: 30 }]),
    PrismaModule,
    HealthModule,
    IdentityModule,
    ProfileModule,
    ArchetypeModule,
    FlagsModule,
    ContentModule,
  ],
})
export class AppModule {}
