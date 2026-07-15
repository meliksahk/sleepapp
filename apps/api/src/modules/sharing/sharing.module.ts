import { Module, type Provider } from '@nestjs/common';
import { IdentityModule } from '../identity';
import { ArchetypeModule, GetLatestResultUseCase } from '../archetype';
import { ENV, loadEnv, type Env } from '../../shared/config/env';
import { ARCHETYPE_RESULT_READER, type ArchetypeResultReader } from './domain/ports';
import { type ShareUrls } from './domain/share';
import { GetArchetypeShareUseCase } from './application/get-archetype-share.usecase';
import { SharingController } from './presentation/sharing.controller';

const providers: Provider[] = [
  { provide: ENV, useFactory: (): Env => loadEnv() },
  // Cross-module adapter (module-def seviyesi): archetype public servisini
  // sharing'in domain portuna bağlar. Sharing archetype tablosuna DOKUNMAZ.
  {
    provide: ARCHETYPE_RESULT_READER,
    inject: [GetLatestResultUseCase],
    useFactory: (getLatest: GetLatestResultUseCase): ArchetypeResultReader => ({
      latestFor: async (userId) => {
        const result = await getLatest.execute(userId);
        return result ? { archetypeSlug: result.archetypeSlug } : null;
      },
    }),
  },
  {
    provide: GetArchetypeShareUseCase,
    inject: [ARCHETYPE_RESULT_READER, ENV],
    useFactory: (reader: ArchetypeResultReader, env: Env): GetArchetypeShareUseCase => {
      const urls: ShareUrls = { webBaseUrl: env.WEB_BASE_URL, appScheme: env.APP_DEEPLINK_SCHEME };
      return new GetArchetypeShareUseCase(reader, urls);
    },
  },
];

@Module({
  imports: [IdentityModule, ArchetypeModule],
  controllers: [SharingController],
  providers,
})
export class SharingModule {}
