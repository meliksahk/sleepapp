import { MiddlewareConsumer, Module, type NestModule } from '@nestjs/common';
import { ThrottlerModule } from '@nestjs/throttler';
import { PrismaModule } from './shared/infra/prisma.module';
import { CacheModule } from './shared/cache/cache.module';
import { RequestIdMiddleware } from './shared/http/request-id.middleware';
import { SecurityHeadersMiddleware } from './shared/http/security-headers.middleware';
import { HealthModule } from './shared/health/health.module';
import { IdentityModule } from './modules/identity/identity.module';
import { ProfileModule } from './modules/profile/profile.module';
import { ArchetypeModule } from './modules/archetype/archetype.module';
import { FlagsModule } from './modules/flags/flags.module';
import { ContentModule } from './modules/content/content.module';
import { WaitlistModule } from './modules/waitlist/waitlist.module';
import { NotificationModule } from './modules/notification/notification.module';
import { SharingModule } from './modules/sharing/sharing.module';
import { SleepModule } from './modules/sleep/sleep.module';
import { AnalyticsModule } from './modules/analytics/analytics.module';

@Module({
  imports: [
    // In-memory IP rate-limit (throttler). Dağıtık/Redis tabanlı limit B4 sertleşmede.
    ThrottlerModule.forRoot([{ ttl: 60_000, limit: 30 }]),
    PrismaModule,
    CacheModule,
    HealthModule,
    IdentityModule,
    ProfileModule,
    ArchetypeModule,
    FlagsModule,
    ContentModule,
    WaitlistModule,
    NotificationModule,
    SharingModule,
    SleepModule,
    AnalyticsModule,
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer): void {
    // Güvenlik başlıkları + correlation-id: her ikisi de guard'lardan önce, tüm rotalara.
    consumer.apply(SecurityHeadersMiddleware, RequestIdMiddleware).forRoutes('*');
  }
}
