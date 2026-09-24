import { PendingLimitReachedError } from '../../src/modules/community/domain/errors';
import type {
  CommunityRepository,
  UserSoundStorage,
} from '../../src/modules/community/domain/ports';
import {
  MAX_PENDING_SOUNDS_PER_USER,
  type UserSound,
} from '../../src/modules/community/domain/user-sound';
import { CreateSoundUploadUseCase } from '../../src/modules/community/application/create-sound-upload.usecase';
import { CompleteSoundUploadUseCase } from '../../src/modules/community/application/complete-sound-upload.usecase';
import {
  ListSoundsForModerationUseCase,
  ModerateSoundUseCase,
} from '../../src/modules/community/application/moderate-and-list.usecase';
import {
  ABANDONED_SLOT_RETENTION_MS,
  CleanupOrphanSoundsUseCase,
  REJECTED_RETENTION_MS,
} from '../../src/modules/community/application/cleanup-orphan-sounds.usecase';

/** Bellek-içi repo — use case sözleşmelerini birebir uygular. */
class FakeRepo implements CommunityRepository {
  rows = new Map<string, UserSound>();
  private seq = 0;

  private nextId(): string {
    this.seq += 1;
    return `00000000-0000-4000-8000-${String(this.seq).padStart(12, '0')}`;
  }

  static sound(partial: Partial<UserSound> & { id: string }): UserSound {
    return {
      userId: 'user-a',
      title: 'Test ses',
      storageKey: `community/user-a/${partial.id}`,
      byteSize: null,
      durationSeconds: 60,
      status: 'pending',
      rejectionReason: null,
      moderatedAt: null,
      createdAt: new Date('2026-08-22T00:00:00Z'),
      ...partial,
    };
  }

  async create(input: {
    id: string;
    userId: string;
    title: string;
    storageKey: string;
    durationSeconds: number;
  }): Promise<UserSound> {
    const row = FakeRepo.sound({
      id: input.id,
      userId: input.userId,
      title: input.title,
      storageKey: input.storageKey,
      durationSeconds: input.durationSeconds,
    });
    this.rows.set(row.id, row);
    return row;
  }

  async findById(id: string): Promise<UserSound | null> {
    return this.rows.get(id) ?? null;
  }

  async findByUser(userId: string): Promise<UserSound[]> {
    return [...this.rows.values()].filter((r) => r.userId === userId);
  }

  async countPendingByUser(userId: string): Promise<number> {
    return [...this.rows.values()].filter((r) => r.userId === userId && r.status === 'pending')
      .length;
  }

  async markUploaded(id: string, byteSize: number): Promise<UserSound | null> {
    const row = this.rows.get(id);
    if (!row) return null;
    const updated: UserSound = { ...row, byteSize };
    this.rows.set(id, updated);
    return updated;
  }

  async moderate(input: {
    id: string;
    status: 'approved' | 'rejected';
    rejectionReason: string | null;
    moderatedAt: Date;
  }): Promise<UserSound | null> {
    const row = this.rows.get(input.id);
    if (!row) return null;
    const updated: UserSound = {
      ...row,
      status: input.status,
      rejectionReason: input.rejectionReason,
      moderatedAt: input.moderatedAt,
    };
    this.rows.set(input.id, updated);
    return updated;
  }

  async listByStatus(status: UserSound['status']): Promise<UserSound[]> {
    return [...this.rows.values()].filter((r) => r.status === status);
  }

  async countByStatus(status: UserSound['status']): Promise<number> {
    return (await this.listByStatus(status)).length;
  }

  async findAbandonedPending(before: Date): Promise<UserSound[]> {
    return [...this.rows.values()].filter(
      (r) => r.status === 'pending' && r.byteSize === null && r.createdAt < before,
    );
  }

  async findRejectedBefore(before: Date): Promise<UserSound[]> {
    return [...this.rows.values()].filter(
      (r) => r.status === 'rejected' && r.moderatedAt !== null && r.moderatedAt < before,
    );
  }

  async delete(id: string): Promise<void> {
    this.rows.delete(id);
  }

  async listAllKeys(): Promise<string[]> {
    return [...this.rows.values()].map((r) => r.storageKey);
  }
}

class FakeStorage implements UserSoundStorage {
  objects = new Map<string, number>();
  putUrls: string[] = [];
  removed: string[] = [];
  /** listKeys sonucu — test doldurur; null ise objects'ten üretilir. */
  listingOverride: Array<{ key: string; lastModified: Date }> | null = null;

  async presignedPutUrl(bucket: string, key: string): Promise<string> {
    this.putUrls.push(`${bucket}/${key}`);
    return `https://minio.test/upload?bucket=${bucket}&key=${encodeURIComponent(key)}`;
  }

  async headObject(_bucket: string, key: string): Promise<{ sizeBytes: number } | null> {
    const size = this.objects.get(key);
    return size === undefined ? null : { sizeBytes: size };
  }

  async presignedGetUrl(bucket: string, key: string): Promise<string> {
    return `https://minio.test/get/${bucket}/${encodeURIComponent(key)}?sig=fake`;
  }

  async listKeys(_bucket: string, prefix: string) {
    if (this.listingOverride !== null) return this.listingOverride;
    return [...this.objects.keys()]
      .filter((k) => k.startsWith(prefix))
      .map((k) => ({ key: k, lastModified: new Date() }));
  }

  async removeObject(_bucket: string, key: string): Promise<void> {
    this.removed.push(key);
    this.objects.delete(key);
  }
}

describe('CreateSoundUploadUseCase', () => {
  const BUCKET = 'audio-assets';

  it('slot açar: kayıt pending + anahtar community/{userId}/{id} + presigned PUT', async () => {
    const repo = new FakeRepo();
    const storage = new FakeStorage();
    const uc = new CreateSoundUploadUseCase(repo, storage, BUCKET);

    const slot = await uc.execute('user-a', { title: 'Deniz', durationSeconds: 120 });

    const row = await repo.findById(slot.id);
    expect(row).not.toBeNull();
    expect(row!.status).toBe('pending');
    // Anahtar kullanıcının kontrolündeki hiçbir dizgiyi (başlık) TAŞIMAZ.
    expect(row!.storageKey).toBe(`community/user-a/${slot.id}`);
    expect(storage.putUrls[0]).toBe(`${BUCKET}/community/user-a/${slot.id}`);
    expect(slot.uploadUrl).toContain(encodeURIComponent(row!.storageKey));
  });

  it.each([
    ['başlık boş', { title: '   ', durationSeconds: 10 }],
    ['başlık yok', { title: 42, durationSeconds: 10 }],
    ['süre sıfır', { title: 'x', durationSeconds: 0 }],
    ['süre tavan aşımı', { title: 'x', durationSeconds: 3 * 60 * 60 }],
  ])('%s → TypeError', async (_name, input) => {
    const uc = new CreateSoundUploadUseCase(new FakeRepo(), new FakeStorage(), BUCKET);
    await expect(uc.execute('user-a', input as never)).rejects.toBeInstanceOf(TypeError);
  });

  it(`pending tavanı (${MAX_PENDING_SOUNDS_PER_USER}) dolunca reddeder`, async () => {
    const repo = new FakeRepo();
    const uc = new CreateSoundUploadUseCase(repo, new FakeStorage(), BUCKET);
    for (let i = 0; i < MAX_PENDING_SOUNDS_PER_USER; i++) {
      await uc.execute('user-a', { title: `s${i}`, durationSeconds: 10 });
    }
    await expect(
      uc.execute('user-a', { title: 'taşan', durationSeconds: 10 }),
    ).rejects.toBeInstanceOf(PendingLimitReachedError);

    // Başka kullanıcı ETKİLENMEZ: tavan kullanıcı başınadır.
    await expect(
      uc.execute('user-b', { title: 'başkası', durationSeconds: 10 }),
    ).resolves.toBeTruthy();
  });
});

describe('CompleteSoundUploadUseCase', () => {
  const BUCKET = 'audio-assets';

  const setup = async () => {
    const repo = new FakeRepo();
    const storage = new FakeStorage();
    const create = new CreateSoundUploadUseCase(repo, storage, BUCKET);
    const slot = await create.execute('user-a', { title: 'Ses', durationSeconds: 30 });
    return { repo, storage, complete: new CompleteSoundUploadUseCase(repo, storage, BUCKET), slot };
  };

  it('HEAD boyutu sınırlar içindeyse kayıt işaretlenir', async () => {
    const { repo, storage, complete, slot } = await setup();
    storage.objects.set(`community/user-a/${slot.id}`, 1024 * 512);

    await complete.execute('user-a', slot.id);

    expect((await repo.findById(slot.id))!.byteSize).toBe(1024 * 512);
    expect((await repo.findById(slot.id))!.status).toBe('pending'); // moderasyon hâlâ kapıdır
  });

  it('dosya YOK → UploadIncompleteError (istemciye güvenilmez)', async () => {
    const { complete, slot } = await setup();
    await expect(complete.execute('user-a', slot.id)).rejects.toThrow(/bulunamadı/);
  });

  it('boyut sınır dışı (çok küçük / çok büyük) → UploadIncompleteError', async () => {
    const { storage, complete, slot } = await setup();
    const key = `community/user-a/${slot.id}`;
    storage.objects.set(key, 5); // min altı
    await expect(complete.execute('user-a', slot.id)).rejects.toThrow(/boyut/);
    storage.objects.set(key, 100 * 1024 * 1024); // max üstü
    await expect(complete.execute('user-a', slot.id)).rejects.toThrow(/boyut/);
  });

  it('BAŞKASININ sesi → SoundNotOwnedError (404’e çevrilecek)', async () => {
    const { storage, complete, slot } = await setup();
    storage.objects.set(`community/user-a/${slot.id}`, 2048);
    await expect(complete.execute('user-b', slot.id)).rejects.toThrow(/owned/i);
  });

  it('olmayan id → SoundNotFoundError', async () => {
    const { complete } = await setup();
    await expect(
      complete.execute('user-a', 'ffffffff-ffff-4000-8000-ffffffffffff'),
    ).rejects.toThrow(/bulunamadı/);
  });
});

describe('Moderation use cases', () => {
  const seedPending = async () => {
    const repo = new FakeRepo();
    const row = FakeRepo.sound({ id: '11111111-1111-4000-8000-000000000001' });
    repo.rows.set(row.id, row);
    return repo;
  };

  it('approve: pending → approved, gerekçe temizlenir, tarih yazılır', async () => {
    const repo = await seedPending();
    const uc = new ModerateSoundUseCase(repo);
    const out = await uc.execute({
      soundId: '11111111-1111-4000-8000-000000000001',
      decision: 'approve',
    });
    expect(out.status).toBe('approved');
    expect(out.rejectionReason).toBeNull();
    expect(out.moderatedAt).not.toBeNull();
  });

  it('reject: gerekçe ZORUNLU; boşsa TypeError', async () => {
    const repo = await seedPending();
    const uc = new ModerateSoundUseCase(repo);
    await expect(
      uc.execute({ soundId: '11111111-1111-4000-8000-000000000001', decision: 'reject' }),
    ).rejects.toBeInstanceOf(TypeError);
    await expect(
      uc.execute({
        soundId: '11111111-1111-4000-8000-000000000001',
        decision: 'reject',
        rejectionReason: '   ',
      }),
    ).rejects.toBeInstanceOf(TypeError);

    const out = await uc.execute({
      soundId: '11111111-1111-4000-8000-000000000001',
      decision: 'reject',
      rejectionReason: 'Telif riski',
    });
    expect(out.status).toBe('rejected');
    expect(out.rejectionReason).toBe('Telif riski');
  });

  it('aynı karar İKİ KEZ yazılamaz (audit izi bulanıklaştırmayı önler)', async () => {
    const repo = await seedPending();
    const uc = new ModerateSoundUseCase(repo);
    const id = '11111111-1111-4000-8000-000000000001';
    await uc.execute({ soundId: id, decision: 'approve' });
    await expect(uc.execute({ soundId: id, decision: 'approve' })).rejects.toThrow(/already/);
    await uc.execute({ soundId: id, decision: 'reject', rejectionReason: 'geri çekme' }); // approved→rejected serbest
    await expect(
      uc.execute({ soundId: id, decision: 'reject', rejectionReason: 'tekrar' }),
    ).rejects.toThrow(/already/);
  });

  it('moderasyon listesi durum filtresiyle çalışır', async () => {
    const repo = await seedPending();
    const lister = new ListSoundsForModerationUseCase(repo);
    expect((await lister.execute('pending')).total).toBe(1);
    expect((await lister.execute('approved')).total).toBe(0);
  });
});

describe('CleanupOrphanSoundsUseCase (3b — birikme riskinin kapanışı)', () => {
  const id = (n: number) => `${String(n).padStart(8, '0')}0000-4000-8000-00000000000${n}`;

  const build = () => {
    const repo = new FakeRepo();
    const storage = new FakeStorage();
    const uc = new CleanupOrphanSoundsUseCase(repo, storage, 'audio-assets');
    return { repo, storage, uc };
  };

  const pendingRow = (n: number, createdAt: Date, withBytes: boolean): UserSound =>
    FakeRepo.sound({
      id: id(n),
      status: 'pending',
      createdAt,
      byteSize: withBytes ? 1234 : null,
    });

  const rejectedRow = (n: number, moderatedAt: Date): UserSound => ({
    ...FakeRepo.sound({ id: id(n), status: 'rejected' }),
    rejectionReason: 'test',
    moderatedAt,
  });

  it('yüklenmemiş ESKİ slot silinir; TAZE slot ve yüklenmiş slot kalır', async () => {
    const { repo, storage, uc } = build();
    const now = new Date('2026-08-22T12:00:00Z');
    const old = new Date(now.getTime() - ABANDONED_SLOT_RETENTION_MS - 1000);
    const fresh = new Date(now.getTime() - 1000);

    repo.rows.set(id(1), pendingRow(1, old, false)); // silinir
    repo.rows.set(id(2), pendingRow(2, fresh, false)); // taze → kalır
    repo.rows.set(id(3), pendingRow(3, old, true)); // dosya gelmiş → KALIR

    const report = await uc.execute(now);

    expect(report.abandonedSlots).toBe(1);
    expect(await repo.findById(id(1))).toBeNull();
    expect(await repo.findById(id(2))).not.toBeNull();
    expect(await repo.findById(id(3))).not.toBeNull();
    // Nesne silme girişimi yapıldı ama nesne yoktu → removed yine de kaydeder.
    expect(storage.removed).toContain(`community/user-a/${id(1)}`);
  });

  it('denetim süresi geçmiş REDLER silinir; yeniler kalır', async () => {
    const { repo, uc } = build();
    const now = new Date('2026-08-22T12:00:00Z');
    const expired = new Date(now.getTime() - REJECTED_RETENTION_MS - 60_000);
    const fresh = new Date(now.getTime() - 60_000);

    repo.rows.set(id(4), rejectedRow(4, expired));
    repo.rows.set(id(5), rejectedRow(5, fresh));

    const report = await uc.execute(now);
    expect(report.expiredRejections).toBe(1);
    expect(await repo.findById(id(4))).toBeNull();
    expect(await repo.findById(id(5))).not.toBeNull();
  });

  it('DB’de karşılığı OLMAYAN yetim nesne silinir; onaylılarınki korunur', async () => {
    const { repo, storage, uc } = build();
    const now = new Date();
    const approvedRow = FakeRepo.sound({
      id: id(6),
      status: 'approved',
      byteSize: 4096,
      storageKey: `community/user-a/${id(6)}`,
    });
    repo.rows.set(approvedRow.id, approvedRow);
    storage.objects.set(approvedRow.storageKey, 4096);
    // Yetim: hesabı CASCADE ile silinmiş kullanıcının nesnesi DB'de yok.
    const orphanKey = `community/user-gone/${id(7)}`;
    storage.listingOverride = [
      { key: approvedRow.storageKey, lastModified: now },
      { key: orphanKey, lastModified: now },
    ];

    const report = await uc.execute(now);

    expect(report.orphanObjects).toBe(1);
    expect(storage.removed).toContain(orphanKey);
    expect(storage.removed).not.toContain(approvedRow.storageKey);
    expect(storage.objects.has(approvedRow.storageKey)).toBe(true);
  });
});
