import type { Profile, ProfileUpdate } from '../domain/profile.entity';
import type { ProfileRepository } from '../domain/ports';
import type { PrismaService } from '../../../shared/infra/prisma.service';

export class PrismaProfileRepository implements ProfileRepository {
  constructor(private readonly prisma: PrismaService) {}

  async findByUserId(userId: string): Promise<Profile | null> {
    const row = await this.prisma.profiles.findUnique({ where: { id: userId } });
    return row ? toProfile(row) : null;
  }

  async upsert(userId: string, update: ProfileUpdate): Promise<Profile> {
    const row = await this.prisma.profiles.upsert({
      where: { id: userId },
      // create: eksik locale/timezone DB @default'ları ('en'/'UTC') ile dolar.
      create: {
        id: userId,
        display_name: update.displayName ?? null,
        chronotype: update.chronotype ?? null,
        ...(update.locale !== undefined ? { locale: update.locale } : {}),
        ...(update.timezone !== undefined ? { timezone: update.timezone } : {}),
        ...(update.notificationsEnabled !== undefined
          ? { notifications_enabled: update.notificationsEnabled }
          : {}),
      },
      // update: yalnızca verilen alanlar (undefined → değişmez, null → temizler).
      update: {
        ...(update.displayName !== undefined ? { display_name: update.displayName } : {}),
        ...(update.chronotype !== undefined ? { chronotype: update.chronotype } : {}),
        ...(update.locale !== undefined ? { locale: update.locale } : {}),
        ...(update.timezone !== undefined ? { timezone: update.timezone } : {}),
        ...(update.notificationsEnabled !== undefined
          ? { notifications_enabled: update.notificationsEnabled }
          : {}),
      },
    });
    return toProfile(row);
  }
}

function toProfile(row: {
  id: string;
  display_name: string | null;
  chronotype: string | null;
  locale: string;
  timezone: string;
  notifications_enabled: boolean;
}): Profile {
  return {
    userId: row.id,
    displayName: row.display_name,
    chronotype: row.chronotype,
    locale: row.locale,
    timezone: row.timezone,
    notificationsEnabled: row.notifications_enabled,
  };
}
