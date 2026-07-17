import { Module, type Provider } from '@nestjs/common';

import { GetActiveSessionsUseCase, IdentityModule } from '../identity';
import { GetProfileUseCase, ProfileModule } from '../profile';
import { ArchetypeModule, ListResultsUseCase } from '../archetype';
import { ListSleepSessionsUseCase, SleepModule } from '../sleep';
import {
  EXPORT_SOURCES,
  ExportUserDataUseCase,
  type ExportSources,
} from './application/export-user-data.usecase';
import { PrivacyController } from './presentation/privacy.controller';

const providers: Provider[] = [
  {
    // Cross-module wiring MODÜL dosyasında yapılır (boundary'e izinli); her modülün
    // PUBLIC read use case'i local ExportSources port'una adapte edilir. Application
    // katmanı bu use case'leri asla doğrudan görmez.
    provide: EXPORT_SOURCES,
    inject: [
      GetProfileUseCase,
      ListResultsUseCase,
      ListSleepSessionsUseCase,
      GetActiveSessionsUseCase,
    ],
    useFactory: (
      getProfile: GetProfileUseCase,
      listResults: ListResultsUseCase,
      listSleepSessions: ListSleepSessionsUseCase,
      getSessions: GetActiveSessionsUseCase,
    ): ExportSources => ({
      profile: (userId) => getProfile.execute(userId),
      archetypeResults: (userId) => listResults.execute(userId),
      // Geniş aralık = tüm oturumlar. `listRecentByUser` 100'de cap'liyor; export
      // eksiksiz olmalı, o yüzden gece-aralığı yolu (cap yok) kullanılır.
      sleepSessions: (userId) =>
        listSleepSessions.execute(userId, { from: '1970-01-01', to: '2999-12-31' }),
      sessions: (userId) => getSessions.execute(userId),
    }),
  },
  {
    provide: ExportUserDataUseCase,
    inject: [EXPORT_SOURCES],
    useFactory: (sources: ExportSources): ExportUserDataUseCase =>
      new ExportUserDataUseCase(sources),
  },
];

@Module({
  // Export edilen use case'leri sağlayan modüller (+ AuthGuard için identity).
  imports: [IdentityModule, ProfileModule, ArchetypeModule, SleepModule],
  controllers: [PrivacyController],
  providers,
})
export class PrivacyModule {}
