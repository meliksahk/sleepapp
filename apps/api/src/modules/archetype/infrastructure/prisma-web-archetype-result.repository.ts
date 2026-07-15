import type { Scores } from '../domain/archetype';
import type {
  SaveWebArchetypeResult,
  WebArchetypeResult,
  WebArchetypeResultRepository,
} from '../domain/web';
import type { PrismaService } from '../../../shared/infra/prisma.service';

interface WebRow {
  share_slug: string;
  archetype_slug: string;
  scores: unknown;
  version: number;
  created_at: Date;
}

export class PrismaWebArchetypeResultRepository implements WebArchetypeResultRepository {
  constructor(private readonly prisma: PrismaService) {}

  async save(result: SaveWebArchetypeResult): Promise<WebArchetypeResult> {
    const row = await this.prisma.web_archetype_results.create({
      data: {
        share_slug: result.shareSlug,
        archetype_slug: result.archetypeSlug,
        scores: result.scores,
        version: result.version,
      },
    });
    return toResult(row);
  }

  async findBySlug(shareSlug: string): Promise<WebArchetypeResult | null> {
    const row = await this.prisma.web_archetype_results.findUnique({
      where: { share_slug: shareSlug },
    });
    return row ? toResult(row) : null;
  }
}

function toResult(row: WebRow): WebArchetypeResult {
  return {
    shareSlug: row.share_slug,
    archetypeSlug: row.archetype_slug as WebArchetypeResult['archetypeSlug'],
    scores: row.scores as Scores,
    version: row.version,
    createdAt: row.created_at,
  };
}
