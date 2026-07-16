import type { Scores } from '../domain/archetype';
import type {
  ArchetypeResult,
  ArchetypeResultRepository,
  SaveArchetypeResult,
} from '../domain/ports';
import type { PrismaService } from '../../../shared/infra/prisma.service';

interface ArchetypeRow {
  user_id: string;
  archetype_slug: string;
  scores: unknown;
  version: number;
  created_at: Date;
}

export class PrismaArchetypeResultRepository implements ArchetypeResultRepository {
  constructor(private readonly prisma: PrismaService) {}

  async save(userId: string, result: SaveArchetypeResult): Promise<ArchetypeResult> {
    const row = await this.prisma.archetype_results.create({
      data: {
        user_id: userId,
        archetype_slug: result.archetypeSlug,
        answers: result.answers as Record<string, string>,
        scores: result.scores,
        version: result.version,
      },
    });
    return toResult(row);
  }

  async findLatestByUserId(userId: string): Promise<ArchetypeResult | null> {
    const row = await this.prisma.archetype_results.findFirst({
      where: { user_id: userId },
      orderBy: { created_at: 'desc' },
    });
    return row ? toResult(row) : null;
  }

  async listByUserId(userId: string): Promise<ArchetypeResult[]> {
    const rows = await this.prisma.archetype_results.findMany({
      where: { user_id: userId },
      orderBy: { created_at: 'desc' },
    });
    return rows.map(toResult);
  }
}

function toResult(row: ArchetypeRow): ArchetypeResult {
  return {
    userId: row.user_id,
    archetypeSlug: row.archetype_slug as ArchetypeResult['archetypeSlug'],
    scores: row.scores as Scores,
    version: row.version,
    createdAt: row.created_at,
  };
}
