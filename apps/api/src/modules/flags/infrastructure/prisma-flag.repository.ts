import { parseRules, type Flag, type FlagRepository } from '../domain/flag';
import type { PrismaService } from '../../../shared/infra/prisma.service';

export class PrismaFlagRepository implements FlagRepository {
  constructor(private readonly prisma: PrismaService) {}

  async findAll(): Promise<Flag[]> {
    const rows = await this.prisma.feature_flags.findMany();
    return rows.map((row) => ({ key: row.key, rules: parseRules(row.rules) }));
  }
}
