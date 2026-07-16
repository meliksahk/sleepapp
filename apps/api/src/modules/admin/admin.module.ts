import { Module, type Provider } from '@nestjs/common';
import { IdentityModule } from '../identity';
import { ContentModule, CreateSoundscapeUseCase, ListAllSoundscapesUseCase } from '../content';
import { AdminController } from './presentation/admin.controller';
import { SOUNDSCAPE_CATALOG, type SoundscapeCatalog } from './domain/soundscape-catalog';

const providers: Provider[] = [
  {
    // Adaptasyon module-def'te: admin, content'in PUBLIC use case'ini kendi portuna
    // bağlar; content'in repo'suna/Prisma modeline dokunmaz (docs/02 §2 boundary).
    provide: SOUNDSCAPE_CATALOG,
    inject: [ListAllSoundscapesUseCase, CreateSoundscapeUseCase],
    useFactory: (
      listAll: ListAllSoundscapesUseCase,
      create: CreateSoundscapeUseCase,
    ): SoundscapeCatalog => ({
      list: async () => {
        const all = await listAll.execute();
        return all.map((s) => ({
          id: s.id,
          slug: s.slug,
          // Başlık çözümü bir SUNUM kararıdır: EN yoksa slug — panelde boş hücre
          // yerine hiç değilse tanınabilir bir şey görünsün.
          title: s.titleI18n.en ?? s.slug,
          status: s.status,
          archetypeAffinity: s.archetypeAffinity,
          version: s.version,
          createdAt: s.createdAt,
        }));
      },
      create: async (input) => {
        const s = await create.execute(input);
        return {
          id: s.id,
          slug: s.slug,
          title: s.titleI18n.en ?? s.slug,
          status: s.status,
          archetypeAffinity: s.archetypeAffinity,
          version: s.version,
          createdAt: s.createdAt,
        };
      },
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
