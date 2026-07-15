import type { DeviceRegistration, RefreshTokenRecord, User } from '../domain/user.entity';
import type { RefreshTokenRepository, UserRepository } from '../domain/ports';

/**
 * In-memory repository adaptörleri — F0 dev + unit test (docker'sız koşar).
 * Hexagonal sınır sayesinde Prisma adaptörü docker/DB gelince tak-çıkar eklenir
 * (docs/02 §2). Prod'da KULLANILMAZ.
 */
export class InMemoryUserRepository implements UserRepository {
  private readonly usersById = new Map<string, User>();
  private readonly userIdByFingerprint = new Map<string, string>();

  async createWithDevice(user: User, device: DeviceRegistration): Promise<void> {
    this.usersById.set(user.id, user);
    this.userIdByFingerprint.set(device.fingerprint, user.id);
  }

  async findById(id: string): Promise<User | null> {
    return this.usersById.get(id) ?? null;
  }

  async findByDeviceFingerprint(fingerprint: string): Promise<User | null> {
    const id = this.userIdByFingerprint.get(fingerprint);
    return id ? (this.usersById.get(id) ?? null) : null;
  }
}

export class InMemoryRefreshTokenRepository implements RefreshTokenRepository {
  private readonly byId = new Map<string, RefreshTokenRecord>();
  private readonly idByHash = new Map<string, string>();

  async save(record: RefreshTokenRecord): Promise<void> {
    this.byId.set(record.id, record);
    this.idByHash.set(record.tokenHash, record.id);
  }

  async findByHash(tokenHash: string): Promise<RefreshTokenRecord | null> {
    const id = this.idByHash.get(tokenHash);
    return id ? (this.byId.get(id) ?? null) : null;
  }

  async markRevoked(id: string, revokedAt: Date): Promise<void> {
    const current = this.byId.get(id);
    if (current && current.revokedAt === null) {
      this.byId.set(id, { ...current, revokedAt });
    }
  }

  async revokeFamily(familyId: string, revokedAt: Date): Promise<void> {
    for (const [id, rec] of this.byId) {
      if (rec.familyId === familyId && rec.revokedAt === null) {
        this.byId.set(id, { ...rec, revokedAt });
      }
    }
  }
}
