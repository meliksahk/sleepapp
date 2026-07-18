import type { users as UserRow } from '@prisma/client';
import type { DeviceRegistration, User, UserKind } from '../../domain/user.entity';
import type { AdminCredentials, AdminUserSummary, UserRepository } from '../../domain/ports';
import type { PrismaService } from '../../../../shared/infra/prisma.service';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** users + auth_devices erişimi (Prisma). userId scope'u domain akışında zorunlu. */
export class PrismaUserRepository implements UserRepository {
  constructor(private readonly prisma: PrismaService) {}

  async createWithDevice(user: User, device: DeviceRegistration): Promise<void> {
    await this.prisma.users.create({
      data: {
        id: user.id,
        kind: user.kind,
        roles: [...user.roles],
        created_at: user.createdAt,
        auth_devices: {
          create: {
            device_fingerprint: device.fingerprint,
            platform: device.platform,
          },
        },
      },
    });
  }

  async findById(id: string): Promise<User | null> {
    const row = await this.prisma.users.findUnique({ where: { id } });
    return row ? toUser(row) : null;
  }

  async searchUsers(query: string, limit: number): Promise<AdminUserSummary[]> {
    // id UUID kolonu: geçersiz bir metni `id: query` olarak sorgulamak Prisma'da
    // ATAR → yalnızca tam UUID ise id koşulunu ekle. Aksi hâlde e-posta alt-dizesi.
    const rows = await this.prisma.users.findMany({
      where: {
        deleted_at: null,
        OR: [
          { email: { contains: query, mode: 'insensitive' } },
          ...(UUID_RE.test(query) ? [{ id: query }] : []),
        ],
      },
      take: limit,
      orderBy: { created_at: 'desc' },
    });
    return rows.map((r) => ({
      id: r.id,
      kind: r.kind as UserKind,
      email: r.email,
      createdAt: r.created_at,
    }));
  }

  async findByDeviceFingerprint(fingerprint: string): Promise<User | null> {
    const device = await this.prisma.auth_devices.findUnique({
      where: { device_fingerprint: fingerprint },
      include: { users: true },
    });
    return device ? toUser(device.users) : null;
  }

  async findByEmail(email: string): Promise<User | null> {
    const row = await this.prisma.users.findUnique({ where: { email } });
    return row ? toUser(row) : null;
  }

  async findAdminCredentialsByEmail(email: string): Promise<AdminCredentials | null> {
    return this.toAdminCredentials(await this.prisma.users.findUnique({ where: { email } }));
  }

  async findAdminCredentialsById(userId: string): Promise<AdminCredentials | null> {
    return this.toAdminCredentials(await this.prisma.users.findUnique({ where: { id: userId } }));
  }

  /** Tek yerde: iki arama yolunun AYNI kabul kurallarını uygulaması şart. */
  private toAdminCredentials(row: UserRow | null): AdminCredentials | null {
    // Dört koşul da şart: admin türü, e-postası ve parolası kurulu, silinmemiş.
    // Silinen hesabın satırı bir süre durabilir — kaskad silme öncesi giriş yapamaz.
    if (!row || row.kind !== 'admin' || !row.password_hash || !row.email) {
      return null;
    }
    if (row.deleted_at !== null) {
      return null;
    }
    return {
      userId: row.id,
      email: row.email,
      roles: row.roles,
      passwordHash: row.password_hash,
      totpSecret: row.totp_secret,
      totpConfirmedAt: row.totp_confirmed_at,
      // bigint → number: Prisma bigint kolonu BigInt döner ve BigInt, number ile
      // yapılan `<=` karşılaştırmasında sessizce YANLIŞ sonuç vermez ama tip
      // hatası verir; JSON'a da serileşmez. Sayaç = unix_saniye/30 ≈ 5.6e7 —
      // Number.MAX_SAFE_INTEGER'ın (9e15) çok altında, dönüşüm kayıpsız.
      totpLastCounter: row.totp_last_counter === null ? null : Number(row.totp_last_counter),
    };
  }

  async setTotpSecret(userId: string, secret: string): Promise<void> {
    // Onay ve sayaç SIFIRLANIR: yeni anahtar yeni kurulumdur. Eski sayacı bırakmak,
    // yeni anahtarın ilk kodlarını "kullanılmış" sayıp kurulumu bozardı.
    await this.prisma.users.update({
      where: { id: userId },
      data: { totp_secret: secret, totp_confirmed_at: null, totp_last_counter: null },
    });
  }

  async confirmTotp(userId: string, confirmedAt: Date, counter: number): Promise<void> {
    await this.prisma.users.update({
      where: { id: userId },
      data: { totp_confirmed_at: confirmedAt, totp_last_counter: BigInt(counter) },
    });
  }

  async recordTotpCounter(userId: string, counter: number): Promise<void> {
    await this.prisma.users.update({
      where: { id: userId },
      data: { totp_last_counter: BigInt(counter) },
    });
  }

  async upgradeToEmail(userId: string, email: string, verifiedAt: Date): Promise<void> {
    await this.prisma.users.update({
      where: { id: userId },
      data: { email, kind: 'registered', email_verified_at: verifiedAt },
    });
  }

  async deleteById(id: string): Promise<void> {
    // deleteMany: satır yoksa hata fırlatmaz (idempotent). FK ON DELETE CASCADE
    // auth_devices/refresh_tokens/one_time_tokens/profiles/archetype_results'ı temizler.
    await this.prisma.users.deleteMany({ where: { id } });
  }
}

function toUser(row: { id: string; kind: string; roles: string[]; created_at: Date }): User {
  return {
    id: row.id,
    kind: row.kind as User['kind'],
    roles: row.roles,
    createdAt: row.created_at,
  };
}
