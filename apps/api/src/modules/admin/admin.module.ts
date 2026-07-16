import { Module, type Provider } from '@nestjs/common';
import { IdentityModule } from '../identity';
import type { SoundscapeSummary } from '../content';
import { WaitlistModule, CountWaitlistUseCase } from '../waitlist';
import { AnalyticsModule, GetShareFunnelUseCase } from '../analytics';
import {
  ContentModule,
  CountSoundscapesUseCase,
  CreateSoundscapeUseCase,
  GetAdminSoundscapeUseCase,
  UpdateSoundscapeUseCase,
  ListAllSoundscapesUseCase,
  SetSoundscapeRecipeUseCase,
  SetSoundscapeStatusUseCase,
} from '../content';
import { PrismaService } from '../../shared/infra/prisma.service';
import { AdminController } from './presentation/admin.controller';
import { AUDIT_LOG, type AuditLog } from './domain/audit';
import { PrismaAuditLog } from './infrastructure/prisma-audit-log';
import {
  OVERVIEW_SOURCE,
  SOUNDSCAPE_CATALOG,
  type CatalogEntry,
  type OverviewSource,
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
    provide: AUDIT_LOG,
    inject: [PrismaService],
    useFactory: (prisma: PrismaService): AuditLog => new PrismaAuditLog(prisma),
  },
  {
    // Adaptasyon module-def'te: admin, content'in PUBLIC use case'ini kendi portuna
    // bağlar; content'in repo'suna/Prisma modeline dokunmaz (docs/02 §2 boundary).
    provide: SOUNDSCAPE_CATALOG,
    inject: [
      ListAllSoundscapesUseCase,
      CreateSoundscapeUseCase,
      SetSoundscapeStatusUseCase,
      SetSoundscapeRecipeUseCase,
      GetAdminSoundscapeUseCase,
      UpdateSoundscapeUseCase,
    ],
    useFactory: (
      listAll: ListAllSoundscapesUseCase,
      create: CreateSoundscapeUseCase,
      setStatus: SetSoundscapeStatusUseCase,
      setRecipe: SetSoundscapeRecipeUseCase,
      getOne: GetAdminSoundscapeUseCase,
      updateOne: UpdateSoundscapeUseCase,
    ): SoundscapeCatalog => ({
      list: async () => {
        const all = await listAll.execute();
        return all.map(toEntry);
      },
      get: async (slug) => {
        const view = await getOne.execute(slug);
        return { entry: toEntry(view.summary), recipe: view.recipe };
      },
      create: async (input) => toEntry(await create.execute(input)),
      publish: async (slug) => toEntry(await setStatus.publish(slug)),
      unpublish: async (slug) => toEntry(await setStatus.unpublish(slug)),
      setRecipe: async (slug, recipe) => toEntry(await setRecipe.execute(slug, recipe)),
      update: async (slug, patch) => toEntry(await updateOne.execute(slug, patch)),
    }),
  },
  {
    /**
     * Pano kaynağı: İKİ modülün PUBLIC use case'ini birleştirir (content + waitlist);
     * ikisinin de repo'suna dokunmaz. Sorgular PARALEL — bağımsız sayımlar, biri
     * diğerini beklemesin.
     */
    provide: OVERVIEW_SOURCE,
    inject: [CountSoundscapesUseCase, CountWaitlistUseCase, GetShareFunnelUseCase],
    useFactory: (
      countSoundscapes: CountSoundscapesUseCase,
      countWaitlist: CountWaitlistUseCase,
      shareFunnel: GetShareFunnelUseCase,
    ): OverviewSource => ({
      read: async () => {
        const [soundscapes, waitlist, funnel] = await Promise.all([
          countSoundscapes.execute(),
          countWaitlist.execute(),
          shareFunnel.execute(),
        ]);
        return { soundscapes, waitlist, shareFunnel: funnel };
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
  imports: [IdentityModule, ContentModule, WaitlistModule, AnalyticsModule],
  controllers: [AdminController],
  providers,
})
export class AdminModule {}
