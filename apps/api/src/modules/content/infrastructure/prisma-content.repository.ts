import type {
  ContentRepository,
  Preset,
  Soundscape,
  SoundscapeDetail,
  WeeklyRelease,
} from '../domain/soundscape';
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
  constructor(private readonly prisma: PrismaService) {}

  async findPublished(): Promise<Soundscape[]> {
    const rows = await this.prisma.soundscapes.findMany({
      where: { status: 'published' },
      orderBy: { created_at: 'desc' },
    });
    return rows.map(toSoundscape);
  }

  async findPublishedBySlug(slug: string): Promise<SoundscapeDetail | null> {
    const row = await this.prisma.soundscapes.findFirst({
      where: { slug, status: 'published' },
      include: { presets: true },
    });
    if (!row) return null;
    const detailRow = row as unknown as SoundscapeDetailRow;
    const presets: Preset[] = row.presets.map((p: PresetRow) => ({
      archetypeSlug: p.archetype_slug,
      mixerState: p.mixer_state,
    }));
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
