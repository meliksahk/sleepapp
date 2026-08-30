import type { CommunityRepository } from '../domain/ports';
import type { UserSound, UserSoundStatus } from '../domain/user-sound';
import type { PrismaService } from '../../../shared/infra/prisma.service';

interface UserSoundRow {
  id: string;
  user_id: string;
  title: string;
  storage_key: string;
  byte_size: bigint | null;
  duration_seconds: number;
  status: string;
  rejection_reason: string | null;
  moderated_at: Date | null;
  created_at: Date;
}

/**
 * `id` biçim denetimi: rastgele dizgiyle uuid sorgusu Prisma'da "bulunamadı"
 * DEĞİL, İSTİSNA döner (P2023) → 500. Biçimi burada eliyoruz; olmayan kayıt 404'tür.
 * (audio_assets reposundaki aynı desen.)
 */
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const STATUSES: readonly UserSoundStatus[] = ['pending', 'approved', 'rejected'];

export class PrismaCommunityRepository implements CommunityRepository {
  constructor(private readonly prisma: PrismaService) {}

  async create(input: {
    id: string;
    userId: string;
    title: string;
    storageKey: string;
    durationSeconds: number;
  }): Promise<UserSound> {
    const row = await this.prisma.user_sounds.create({
      data: {
        id: input.id,
        user_id: input.userId,
        title: input.title,
        storage_key: input.storageKey,
        duration_seconds: input.durationSeconds,
      },
    });
    return toSound(row);
  }

  async findById(id: string): Promise<UserSound | null> {
    if (!UUID_RE.test(id)) return null;
    const row = await this.prisma.user_sounds.findUnique({ where: { id } });
    return row ? toSound(row) : null;
  }

  async findByUser(userId: string): Promise<UserSound[]> {
    // userId çağıranın token'ından gelir (uuid); yine de biçimsel guard ucuzdur.
    if (!UUID_RE.test(userId)) return [];
    const rows = await this.prisma.user_sounds.findMany({
      where: { user_id: userId },
      orderBy: { created_at: 'desc' },
    });
    return rows.map(toSound);
  }

  async countPendingByUser(userId: string): Promise<number> {
    if (!UUID_RE.test(userId)) return 0;
    return this.prisma.user_sounds.count({
      where: { user_id: userId, status: 'pending' },
    });
  }

  async markUploaded(id: string, byteSize: number): Promise<UserSound | null> {
    if (!UUID_RE.test(id)) return null;
    const row = await this.prisma.user_sounds.update({
      where: { id },
      data: { byte_size: BigInt(byteSize), updated_at: new Date() },
    });
    return toSound(row);
  }

  async moderate(input: {
    id: string;
    status: 'approved' | 'rejected';
    rejectionReason: string | null;
    moderatedAt: Date;
  }): Promise<UserSound | null> {
    if (!UUID_RE.test(input.id)) return null;
    const row = await this.prisma.user_sounds.update({
      where: { id: input.id },
      data: {
        status: input.status,
        rejection_reason: input.rejectionReason,
        moderated_at: input.moderatedAt,
        updated_at: new Date(),
      },
    });
    return toSound(row);
  }

  async listByStatus(status: UserSoundStatus, limit: number, offset: number): Promise<UserSound[]> {
    if (!STATUSES.includes(status)) return [];
    const rows = await this.prisma.user_sounds.findMany({
      where: { status },
      orderBy: { created_at: 'desc' },
      take: Math.max(1, Math.min(200, limit)),
      skip: Math.max(0, offset),
    });
    return rows.map(toSound);
  }

  async countByStatus(status: UserSoundStatus): Promise<number> {
    if (!STATUSES.includes(status)) return 0;
    return this.prisma.user_sounds.count({ where: { status } });
  }

  async findAbandonedPending(before: Date): Promise<UserSound[]> {
    const rows = await this.prisma.user_sounds.findMany({
      // byte_size NULL = "uploaded" hiç çağrılmadı: slot açılmış, dosya gelmemiş.
      where: { status: 'pending', byte_size: null, created_at: { lt: before } },
    });
    return rows.map(toSound);
  }

  async findRejectedBefore(before: Date): Promise<UserSound[]> {
    const rows = await this.prisma.user_sounds.findMany({
      where: { status: 'rejected', updated_at: { lt: before } },
    });
    return rows.map(toSound);
  }

  async delete(id: string): Promise<void> {
    if (!UUID_RE.test(id)) return;
    await this.prisma.user_sounds.delete({ where: { id } });
  }

  async listAllKeys(): Promise<string[]> {
    const rows = await this.prisma.user_sounds.findMany({
      select: { storage_key: true },
    });
    return rows.map((r) => r.storage_key);
  }
}

function toSound(row: UserSoundRow): UserSound {
  return {
    id: row.id,
    userId: row.user_id,
    title: row.title,
    storageKey: row.storage_key,
    byteSize: row.byte_size === null ? null : Number(row.byte_size),
    durationSeconds: row.duration_seconds,
    status: row.status as UserSoundStatus,
    rejectionReason: row.rejection_reason,
    moderatedAt: row.moderated_at,
    createdAt: row.created_at,
  };
}
