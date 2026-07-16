import type { DeviceRegistration, User } from '../../domain/user.entity';
import type { AdminCredentials, UserRepository } from '../../domain/ports';
import type { PrismaService } from '../../../../shared/infra/prisma.service';

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
    const row = await this.prisma.users.findUnique({ where: { email } });
    // Üç koşul da şart: admin türü, parolası kurulu, silinmemiş. Silinen hesabın
    // satırı bir süre durabilir — kaskad silme öncesi giriş yapabilmesi olmaz.
    if (!row || row.kind !== 'admin' || !row.password_hash || row.deleted_at !== null) {
      return null;
    }
    return { userId: row.id, roles: row.roles, passwordHash: row.password_hash };
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
