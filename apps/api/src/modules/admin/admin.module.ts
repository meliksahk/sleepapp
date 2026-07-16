import { Module, type Provider } from '@nestjs/common';
import { IdentityModule } from '../identity';
import type { SoundscapeSummary } from '../content';
import {
  ContentModule,
  CreateSoundscapeUseCase,
  ListAllSoundscapesUseCase,
  SetSoundscapeStatusUseCase,
} from '../content';
import { AdminController } from './presentation/admin.controller';
import {
  SOUNDSCAPE_CATALOG,
  type CatalogEntry,
  type SoundscapeCatalog,
} from './domain/soundscape-catalog';

/**
 * content'in özetini admin'in portuna çevirir. Başlık çözümü bir SUNUM kararıdır:
 * EN yoksa slug — panelde boş hücre yerine hiç değilse tanınabilir bir şey görünsün.
 */
function toEntry(s: SoundscapeSummary): CatalogEntry {
  return {
    id: s.id,
    slug: s.slug,
    title: s.titleI18n.en ?? s.slug,
    status: s.status,
    archetypeAffinity: s.archetypeAffinity,
    version: s.version,
    createdAt: s.createdAt,
  };
}

const providers: Provider[] = [
  {
    // Adaptasyon module-def'te: admin, content'in PUBLIC use case'ini kendi portuna
    // bağlar; content'in repo'suna/Prisma modeline dokunmaz (docs/02 §2 boundary).
    provide: SOUNDSCAPE_CATALOG,
    inject: [ListAllSoundscapesUseCase, CreateSoundscapeUseCase, SetSoundscapeStatusUseCase],
    useFactory: (
      listAll: ListAllSoundscapesUseCase,
      create: CreateSoundscapeUseCase,
      setStatus: SetSoundscapeStatusUseCase,
    ): SoundscapeCatalog => ({
      list: async () => {
        const all = await listAll.execute();
        return all.map(toEntry);
      },
      create: async (input) => toEntry(await create.execute(input)),
      publish: async (slug) => toEntry(await setStatus.publish(slug)),
      unpublish: async (slug) => toEntry(await setStatus.unpublish(slug)),
    }),
  },
];

/**
 * Admin modülü (docs/02 §2). A0: yalnızca oturum/rol doğrulama.
 * İçerik CMS'i ve metrikler A1–A3'te; onlar da diğer modüllerin PUBLIC
 * application servislerinden tüketilir (repo/Prisma modeline dokunulmaz).
 */
@Module({
  imports: [IdentityModule, ContentModule],
  controllers: [AdminController],
  providers,
})
export class AdminModule {}
