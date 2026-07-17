import { MiddlewareConsumer, Module, type NestModule } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { loadEnv } from './shared/config/env';
import { PrismaModule } from './shared/infra/prisma.module';
import { CacheModule } from './shared/cache/cache.module';
import { RequestIdMiddleware } from './shared/http/request-id.middleware';
import { SecurityHeadersMiddleware } from './shared/http/security-headers.middleware';
import { HealthModule } from './shared/health/health.module';
import { IdentityModule } from './modules/identity/identity.module';
import { ProfileModule } from './modules/profile/profile.module';
import { ArchetypeModule } from './modules/archetype/archetype.module';
import { FlagsModule } from './modules/flags/flags.module';
import { AdminModule } from './modules/admin/admin.module';
import { ContentModule } from './modules/content/content.module';
import { WaitlistModule } from './modules/waitlist/waitlist.module';
import { NotificationModule } from './modules/notification/notification.module';
import { SharingModule } from './modules/sharing/sharing.module';
import { SleepModule } from './modules/sleep/sleep.module';
import { AnalyticsModule } from './modules/analytics/analytics.module';
import { EntitlementModule } from './modules/entitlement';
import { PrivacyModule } from './modules/privacy/privacy.module';

@Module({
  imports: [
    // In-memory IP rate-limit. Limitler env'den (test tek IP'den yüzlerce istek atar).
    // forRootAsync: fabrika HER app kurulumunda çalışır → testler limiti env ile ayarlayabilir.
    // Dağıtık/Redis tabanlı storage B4 sertleşmede.
    ThrottlerModule.forRootAsync({
      useFactory: () => {
        const env = loadEnv();
        return [{ ttl: env.THROTTLE_TTL_MS, limit: env.THROTTLE_LIMIT }];
      },
    }),
    PrismaModule,
    CacheModule,
    HealthModule,
    IdentityModule,
    ProfileModule,
    ArchetypeModule,
    FlagsModule,
    AdminModule,
    ContentModule,
    WaitlistModule,
    NotificationModule,
    SharingModule,
    SleepModule,
    AnalyticsModule,
    EntitlementModule,
    PrivacyModule,
  ],
  providers: [
    // KRİTİK: ThrottlerModule tek başına HİÇBİR ŞEY zorlamaz — guard'ın kayıtlı
    // olması gerekir. Bu yoktu: rate-limit yalnızca @UseGuards(ThrottlerGuard)
    // yazan iki public controller'da çalışıyordu; /v1/auth/* dahil geri kalan
    // TÜM uçlar korumasızdı (sınırsız anonim hesap açma, magic-link spam'i).
    { provide: APP_GUARD, useClass: ThrottlerGuard },
  ],
})
export class AppModule implements NestModule {
  configure(consumer: MiddlewareConsumer): void {
    // Güvenlik başlıkları + correlation-id: her ikisi de guard'lardan önce, tüm rotalara.
    consumer.apply(SecurityHeadersMiddleware, RequestIdMiddleware).forRoutes('*');
  }
}
