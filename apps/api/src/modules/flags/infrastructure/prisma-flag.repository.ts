import { parseRules, type Flag, type FlagRepository, type FlagRules } from '../domain/flag';
import type { PrismaService } from '../../../shared/infra/prisma.service';

export class PrismaFlagRepository implements FlagRepository {
  constructor(private readonly prisma: PrismaService) {}

  async findAll(): Promise<Flag[]> {
    const rows = await this.prisma.feature_flags.findMany();
    return rows.map((row) => ({ key: row.key, rules: parseRules(row.rules) }));
  }

  async upsert(key: string, rules: FlagRules, updatedBy: string): Promise<Flag> {
    // Normalize edilmiş düz JSON'a çevir: undefined alanları YAZMA (kayıt temiz kalsın),
    // readonly diziyi Prisma'nın InputJson'una kopyala. parseRules bunu tersine okur.
    const rulesJson = {
      enabled: rules.enabled,
      ...(rules.rolloutPercentage !== undefined
        ? { rolloutPercentage: rules.rolloutPercentage }
        : {}),
      ...(rules.platforms && rules.platforms.length > 0 ? { platforms: [...rules.platforms] } : {}),
      ...(rules.minAppVersion ? { minAppVersion: rules.minAppVersion } : {}),
    };
    // updated_at şemada @updatedAt DEĞİL (yalnızca @default(now())) → değişikliği
    // yansıtması için elle bump edilir, yoksa güncelleme eski zamanı korurdu.
    const row = await this.prisma.feature_flags.upsert({
      where: { key },
      create: { key, rules: rulesJson, updated_by: updatedBy, updated_at: new Date() },
      update: { rules: rulesJson, updated_by: updatedBy, updated_at: new Date() },
    });
    return { key: row.key, rules: parseRules(row.rules) };
  }
}
