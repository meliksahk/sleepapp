import { Logger } from '@nestjs/common';
import type {
  AdminSoundscapeView,
  ContentRepository,
  ContentStatus,
  Preset,
  NewSoundscape,
  Soundscape,
  SoundscapeDetail,
  SoundscapeSummary,
  WeeklyRelease,
} from '../domain/soundscape';
import { parseMixerState } from '../domain/mixer-state';
import type { PrismaService } from '../../../shared/infra/prisma.service';

interface SoundscapeRow {
  id: string;
  slug: string;
  title_i18n: unknown;
  engine_params: unknown;
  layer_defs: unknown;
  archetype_affinity: string[];
  version: number;
}
interface PresetRow {
  archetype_slug: string;
  mixer_state: unknown;
}
interface SoundscapeDetailRow extends SoundscapeRow {
  preview_asset_key: string | null;
}

export class PrismaContentRepository implements ContentRepository {
  private readonly logger = new Logger('ContentRepository');

  constructor(private readonly prisma: PrismaService) {}

  async findPublished(): Promise<Soundscape[]> {
    const rows = await this.prisma.soundscapes.findMany({
      where: { status: 'published' },
      orderBy: { created_at: 'desc' },
    });
    return rows.map(toSoundscape);
  }

  async findAllSummaries(): Promise<SoundscapeSummary[]> {
    const rows = await this.prisma.soundscapes.findMany({ orderBy: { created_at: 'desc' } });
    return rows.map(toSummary);
  }

  async createDraft(input: NewSoundscape): Promise<SoundscapeSummary | null> {
    try {
      const row = await this.prisma.soundscapes.create({
        data: {
          slug: input.slug,
          title_i18n: input.titleI18n,
          // Ses tarifi BOŞ başlar: taslak, editörün doldurması için bir iskelettir.
          // Uygulama taslakları hiç görmediği için boş tarif kimseye ulaşmaz.
          engine_params: {},
          layer_defs: [],
          archetype_affinity: [...input.archetypeAffinity],
          status: 'draft',
          created_by: input.createdBy,
        },
      });
      return toSummary(row);
    } catch (e) {
      // P2002 = UNIQUE ihlali (slug). Yarışta "önce sor sonra yaz" yetmez: iki istek
      // aynı anda gelirse ikisi de "yok" görüp ikisi de yazmaya kalkar. DB'nin
      // kısıtına GÜVENİYORUZ — tek doğruluk kaynağı orası.
      if (isUniqueViolation(e)) return null;
      throw e;
    }
  }

  async findAdminBySlug(slug: string): Promise<AdminSoundscapeView | null> {
    const row = await this.prisma.soundscapes.findUnique({ where: { slug } });
    if (!row) return null;
    const params = row.engine_params as Record<string, unknown> | null;
    return {
      summary: toSummary(row),
      // "Tarif var" = en az bir anahtar. `{}` boş sayılır — taslak böyle doğuyor.
      hasRecipe: params !== null && typeof params === 'object' && Object.keys(params).length > 0,
      recipe: row.engine_params,
    };
  }

  async setStatus(slug: string, status: ContentStatus): Promise<SoundscapeSummary | null> {
    const updated = await this.prisma.soundscapes.updateMany({ where: { slug }, data: { status } });
    if (updated.count === 0) return null;
    const row = await this.prisma.soundscapes.findUnique({ where: { slug } });
    return row ? toSummary(row) : null;
  }

  async setEngineParams(slug: string, params: unknown): Promise<SoundscapeSummary | null> {
    const updated = await this.prisma.soundscapes.updateMany({
      where: { slug },
      data: { engine_params: params as object },
    });
    if (updated.count === 0) return null;
    const row = await this.prisma.soundscapes.findUnique({ where: { slug } });
    return row ? toSummary(row) : null;
  }

  async findPublishedBySlug(slug: string): Promise<SoundscapeDetail | null> {
    const row = await this.prisma.soundscapes.findFirst({
      where: { slug, status: 'published' },
      include: { presets: true },
    });
    if (!row) return null;
    const detailRow = row as unknown as SoundscapeDetailRow;
    // Sözleşme kapısı: mixer_state serbest jsonb'dir. Bozuk preset'i domain'e
    // ALMAYIZ — aksi halde hata kullanıcının telefonunda, çalma anında patlar.
    // Sessizce elemek yerine LOGLARIZ ki bozuk içerik görünür olsun (CLAUDE.md §0).
    const presets: Preset[] = [];
    for (const p of row.presets as PresetRow[]) {
      const mixerState = parseMixerState(p.mixer_state);
      if (!mixerState) {
        this.logger.error(
          `Geçersiz mixer_state → preset atlandı (soundscape=${slug}, archetype=${p.archetype_slug}). ` +
            'Beklenen şema: {layers:[{id,type:white|pink|brown,gain:0..1}]} (docs/02).',
        );
        continue;
      }
      presets.push({ archetypeSlug: p.archetype_slug, mixerState });
    }
    return {
      soundscape: toSoundscape(row),
      presets,
      previewAssetKey: detailRow.preview_asset_key,
    };
  }

  async findLatestWeeklyRelease(): Promise<WeeklyRelease | null> {
    const release = await this.prisma.weekly_releases.findFirst({
      orderBy: { week_start: 'desc' },
    });
    if (!release) return null;
    const rows = await this.prisma.soundscapes.findMany({
      where: { id: { in: release.soundscape_ids }, status: 'published' },
    });
    return {
      weekStart: release.week_start.toISOString().slice(0, 10),
      notes: release.notes,
      soundscapes: rows.map(toSoundscape),
    };
  }
}

function toSoundscape(row: SoundscapeRow): Soundscape {
  return {
    id: row.id,
    slug: row.slug,
    titleI18n: (row.title_i18n as Record<string, string>) ?? {},
    engineParams: (row.engine_params as Record<string, unknown>) ?? {},
    layerDefs: row.layer_defs,
    archetypeAffinity: row.archetype_affinity,
    version: row.version,
  };
}

/** Prisma P2002: benzersizlik kısıtı ihlali. */
function isUniqueViolation(e: unknown): boolean {
  return typeof e === 'object' && e !== null && (e as { code?: string }).code === 'P2002';
}

/** Satır → admin özeti. Tek yerde: üç çağrı yeri arasında sapma olmasın. */
function toSummary(row: {
  id: string;
  slug: string;
  title_i18n: unknown;
  status: string;
  archetype_affinity: string[] | null;
  version: number;
  created_at: Date;
}): SoundscapeSummary {
  return {
    id: row.id,
    slug: row.slug,
    titleI18n: (row.title_i18n ?? {}) as Record<string, string>,
    status: row.status as ContentStatus,
    archetypeAffinity: row.archetype_affinity ?? [],
    version: row.version,
    createdAt: row.created_at,
  };
}
