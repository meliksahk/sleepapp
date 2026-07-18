import { Module, type Provider } from '@nestjs/common';
import { IdentityModule } from '../identity';
import { ProfileModule, GetProfileUseCase } from '../profile';
import { PrismaService } from '../../shared/infra/prisma.service';
import { OutboxWriter } from '../../shared/outbox/outbox-writer';
import {
  CLOCK,
  PROFILE_TIMEZONE_READER,
  SLEEP_SESSION_REPOSITORY,
  type Clock,
  type ProfileTimezoneReader,
  type SleepSessionRepository,
} from './domain/ports';
import { PrismaSleepSessionRepository } from './infrastructure/prisma-sleep-session.repository';
import { RecordSleepSessionUseCase } from './application/record-sleep-session.usecase';
import { ListSleepSessionsUseCase } from './application/list-sleep-sessions.usecase';
import { GetNightReportUseCase } from './application/get-night-report.usecase';
import { GetStreakUseCase } from './application/get-streak.usecase';
import { GetSleepStatsUseCase } from './application/get-sleep-stats.usecase';
import { GetWeeklyTrendUseCase } from './application/get-weekly-trend.usecase';
import { SleepController } from './presentation/sleep.controller';

const providers: Provider[] = [
  {
    provide: SLEEP_SESSION_REPOSITORY,
    inject: [PrismaService, OutboxWriter],
    useFactory: (prisma: PrismaService, outbox: OutboxWriter): SleepSessionRepository =>
      new PrismaSleepSessionRepository(prisma, outbox),
  },
  // Cross-module adapter (module-def): profile public servisinden timezone okur.
  // Sleep, profiles tablosuna DOKUNMAZ (port üzerinden).
  {
    provide: PROFILE_TIMEZONE_READER,
    inject: [GetProfileUseCase],
    useFactory: (getProfile: GetProfileUseCase): ProfileTimezoneReader => ({
      timezoneFor: async (userId) => (await getProfile.execute(userId)).timezone,
    }),
  },
  {
    provide: RecordSleepSessionUseCase,
    inject: [SLEEP_SESSION_REPOSITORY, PROFILE_TIMEZONE_READER],
    useFactory: (
      repo: SleepSessionRepository,
      timezones: ProfileTimezoneReader,
    ): RecordSleepSessionUseCase => new RecordSleepSessionUseCase(repo, timezones),
  },
  {
    provide: ListSleepSessionsUseCase,
    inject: [SLEEP_SESSION_REPOSITORY],
    useFactory: (repo: SleepSessionRepository): ListSleepSessionsUseCase =>
      new ListSleepSessionsUseCase(repo),
  },
  {
    provide: GetNightReportUseCase,
    inject: [SLEEP_SESSION_REPOSITORY],
    useFactory: (repo: SleepSessionRepository): GetNightReportUseCase =>
      new GetNightReportUseCase(repo),
  },
  { provide: CLOCK, useValue: ((): Date => new Date()) satisfies Clock },
  {
    provide: GetStreakUseCase,
    inject: [SLEEP_SESSION_REPOSITORY, PROFILE_TIMEZONE_READER, CLOCK],
    useFactory: (
      repo: SleepSessionRepository,
      timezones: ProfileTimezoneReader,
      now: Clock,
    ): GetStreakUseCase => new GetStreakUseCase(repo, timezones, now),
  },
  {
    provide: GetSleepStatsUseCase,
    inject: [SLEEP_SESSION_REPOSITORY],
    useFactory: (repo: SleepSessionRepository): GetSleepStatsUseCase =>
      new GetSleepStatsUseCase(repo),
  },
  {
    provide: GetWeeklyTrendUseCase,
    inject: [SLEEP_SESSION_REPOSITORY, PROFILE_TIMEZONE_READER, CLOCK],
    useFactory: (
      repo: SleepSessionRepository,
      timezones: ProfileTimezoneReader,
      now: Clock,
    ): GetWeeklyTrendUseCase => new GetWeeklyTrendUseCase(repo, timezones, now),
  },
];

@Module({
  imports: [IdentityModule, ProfileModule],
  controllers: [SleepController],
  providers,
  // Modüller-arası okuma için dışa açılır (ör. sharing gece raporu kartı üretir).
  exports: [GetNightReportUseCase, ListSleepSessionsUseCase],
})
export class SleepModule {}
