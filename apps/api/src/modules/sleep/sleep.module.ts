import { Module, type Provider } from '@nestjs/common';
import { IdentityModule } from '../identity';
import { ProfileModule, GetProfileUseCase } from '../profile';
import { PrismaService } from '../../shared/infra/prisma.service';
import {
  PROFILE_TIMEZONE_READER,
  SLEEP_SESSION_REPOSITORY,
  type ProfileTimezoneReader,
  type SleepSessionRepository,
} from './domain/ports';
import { PrismaSleepSessionRepository } from './infrastructure/prisma-sleep-session.repository';
import { RecordSleepSessionUseCase } from './application/record-sleep-session.usecase';
import { ListSleepSessionsUseCase } from './application/list-sleep-sessions.usecase';
import { SleepController } from './presentation/sleep.controller';

const providers: Provider[] = [
  {
    provide: SLEEP_SESSION_REPOSITORY,
    inject: [PrismaService],
    useFactory: (prisma: PrismaService): SleepSessionRepository =>
      new PrismaSleepSessionRepository(prisma),
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
];

@Module({
  imports: [IdentityModule, ProfileModule],
  controllers: [SleepController],
  providers,
})
export class SleepModule {}
