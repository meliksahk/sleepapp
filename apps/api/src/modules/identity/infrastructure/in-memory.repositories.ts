import type {
  ActiveSessionInfo,
  DeviceRegistration,
  OneTimeTokenRecord,
  RefreshTokenRecord,
  User,
} from '../domain/user.entity';
import type {
  AdminCredentials,
  AdminUserSummary,
  OneTimeTokenRepository,
  RefreshTokenRepository,
  UserRepository,
} from '../domain/ports';

/**
 * In-memory repository adaptörleri — F0 dev + unit test (docker'sız koşar).
 * Hexagonal sınır sayesinde Prisma adaptörü docker/DB gelince tak-çıkar eklenir
 * (docs/02 §2). Prod'da KULLANILMAZ.
 */
export class InMemoryUserRepository implements UserRepository {
  private readonly usersById = new Map<string, User>();
  private readonly userIdByFingerprint = new Map<string, string>();
  private readonly emailByUserId = new Map<string, string>();
  private readonly passwordHashByUserId = new Map<string, string>();
  private readonly totpByUserId = new Map<
    string,
    { secret: string; confirmedAt: Date | null; lastCounter: number | null }
  >();

  async createWithDevice(user: User, device: DeviceRegistration): Promise<void> {
    this.usersById.set(user.id, user);
    this.userIdByFingerprint.set(device.fingerprint, user.id);
  }

  async findById(id: string): Promise<User | null> {
    return this.usersById.get(id) ?? null;
  }

  async searchUsers(query: string, limit: number): Promise<AdminUserSummary[]> {
    const q = query.toLowerCase();
    const out: AdminUserSummary[] = [];
    for (const user of this.usersById.values()) {
      const email = this.emailByUserId.get(user.id) ?? null;
      if (user.id === query || (email !== null && email.toLowerCase().includes(q))) {
        out.push({ id: user.id, kind: user.kind, email, createdAt: user.createdAt });
      }
    }
    return out.slice(0, limit);
  }

  async findByDeviceFingerprint(fingerprint: string): Promise<User | null> {
    const id = this.userIdByFingerprint.get(fingerprint);
    return id ? (this.usersById.get(id) ?? null) : null;
  }

  async findByEmail(email: string): Promise<User | null> {
    for (const user of this.usersById.values()) {
      if (this.emailByUserId.get(user.id) === email) return user;
    }
    return null;
  }

  /** Test/dev sahtesi: parola hash'i `passwordHashByUserId` ile kurulur. */
  async findAdminCredentialsByEmail(email: string): Promise<AdminCredentials | null> {
    const user = await this.findByEmail(email);
    return user ? this.toAdminCredentials(user) : null;
  }

  async findAdminCredentialsById(userId: string): Promise<AdminCredentials | null> {
    const user = this.usersById.get(userId);
    return user ? this.toAdminCredentials(user) : null;
  }

  private toAdminCredentials(user: User): AdminCredentials | null {
    if (user.kind !== 'admin') return null;
    const passwordHash = this.passwordHashByUserId.get(user.id);
    const email = this.emailByUserId.get(user.id);
    if (!passwordHash || !email) return null;
    const totp = this.totpByUserId.get(user.id);
    return {
      userId: user.id,
      email,
      roles: user.roles,
      passwordHash,
      totpSecret: totp?.secret ?? null,
      totpConfirmedAt: totp?.confirmedAt ?? null,
      totpLastCounter: totp?.lastCounter ?? null,
    };
  }

  setPasswordHash(userId: string, hash: string): void {
    this.passwordHashByUserId.set(userId, hash);
  }

  async setTotpSecret(userId: string, secret: string): Promise<void> {
    // Yeni anahtar = yeni kurulum: onay ve sayaç sıfırlanır (Prisma ile aynı davranış).
    this.totpByUserId.set(userId, { secret, confirmedAt: null, lastCounter: null });
  }

  async confirmTotp(userId: string, confirmedAt: Date, counter: number): Promise<void> {
    const current = this.totpByUserId.get(userId);
    if (!current) return;
    this.totpByUserId.set(userId, { ...current, confirmedAt, lastCounter: counter });
  }

  async recordTotpCounter(userId: string, counter: number): Promise<void> {
    const current = this.totpByUserId.get(userId);
    if (!current) return;
    this.totpByUserId.set(userId, { ...current, lastCounter: counter });
  }

  async upgradeToEmail(userId: string, email: string, _verifiedAt: Date): Promise<void> {
    const current = this.usersById.get(userId);
    if (current) {
      this.usersById.set(userId, { ...current, kind: 'registered' });
      this.emailByUserId.set(userId, email);
    }
  }

  async deleteById(id: string): Promise<void> {
    this.usersById.delete(id);
    this.emailByUserId.delete(id);
    for (const [fp, uid] of this.userIdByFingerprint) {
      if (uid === id) this.userIdByFingerprint.delete(fp);
    }
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

  async hasActiveInFamily(familyId: string, now: Date): Promise<boolean> {
    for (const rec of this.byId.values()) {
      if (rec.familyId === familyId && rec.revokedAt === null && rec.expiresAt > now) {
        return true;
      }
    }
    return false;
  }

  async revokeAllExceptFamily(
    userId: string,
    keepFamilyId: string,
    revokedAt: Date,
  ): Promise<number> {
    let revoked = 0;
    for (const [id, rec] of this.byId) {
      if (rec.userId === userId && rec.familyId !== keepFamilyId && rec.revokedAt === null) {
        this.byId.set(id, { ...rec, revokedAt });
        revoked++;
      }
    }
    return revoked;
  }

  async listActiveByUser(userId: string, now: Date): Promise<ActiveSessionInfo[]> {
    const active: ActiveSessionInfo[] = [];
    for (const rec of this.byId.values()) {
      if (
        rec.userId === userId &&
        rec.revokedAt === null &&
        rec.expiresAt.getTime() > now.getTime()
      ) {
        active.push({ familyId: rec.familyId, createdAt: rec.createdAt, expiresAt: rec.expiresAt });
      }
    }
    active.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
    return active;
  }
}

export class InMemoryOneTimeTokenRepository implements OneTimeTokenRepository {
  private readonly byId = new Map<string, OneTimeTokenRecord>();
  private readonly idByHash = new Map<string, string>();

  async save(record: OneTimeTokenRecord): Promise<void> {
    this.byId.set(record.id, record);
    this.idByHash.set(record.tokenHash, record.id);
  }

  async findByHash(tokenHash: string): Promise<OneTimeTokenRecord | null> {
    const id = this.idByHash.get(tokenHash);
    return id ? (this.byId.get(id) ?? null) : null;
  }

  async markUsed(id: string, usedAt: Date): Promise<void> {
    const current = this.byId.get(id);
    if (current && current.usedAt === null) {
      this.byId.set(id, { ...current, usedAt });
    }
  }
}
