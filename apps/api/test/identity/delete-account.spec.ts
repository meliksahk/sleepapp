import { buildIdentityStack } from './harness';
import { DeleteAccountUseCase } from '../../src/modules/identity/application/delete-account.usecase';

describe('DeleteAccountUseCase (in-memory)', () => {
  it('kullanıcıyı siler → bir daha bulunamaz, parmak izi serbest kalır', async () => {
    const s = await buildIdentityStack();
    const session = await s.registerDevice.execute({ fingerprint: 'del-1', platform: 'ios' });

    expect(await s.users.findById(session.userId)).not.toBeNull();

    const useCase = new DeleteAccountUseCase(s.users);
    await useCase.execute(session.userId);

    expect(await s.users.findById(session.userId)).toBeNull();
    expect(await s.users.findByDeviceFingerprint('del-1')).toBeNull();
  });

  it('olmayan kullanıcıyı silmek hata fırlatmaz (idempotent)', async () => {
    const s = await buildIdentityStack();
    const useCase = new DeleteAccountUseCase(s.users);
    await expect(useCase.execute('yok-boyle-id')).resolves.toBeUndefined();
  });
});

/**
 * Silme SAYACI (#F1 admin ayağı). `users` satırı hard-delete edildiği için
 * "kaç hesap silindi" sorusunun başka cevabı yok; panel bunu gösteriyor.
 */
describe('DeleteAccountUseCase — silme sayacı', () => {
  class FakeDeletionLog {
    ticks: Date[] = [];
    shouldThrow = false;
    async record(): Promise<void> {
      if (this.shouldThrow) throw new Error('sayaç yazılamadı');
      this.ticks.push(new Date());
    }
    async countSince(since: Date): Promise<number> {
      return this.ticks.filter((t) => t >= since).length;
    }
  }

  it('silme BAŞARILI olunca sayaç bir artar', async () => {
    const s = await buildIdentityStack();
    const session = await s.registerDevice.execute({ fingerprint: 'del-2', platform: 'ios' });
    const log = new FakeDeletionLog();

    await new DeleteAccountUseCase(s.users, log).execute(session.userId);

    expect(log.ticks).toHaveLength(1);
  });

  it('SİLME PATLARSA sayaç yazılmaz (olmamış olay sayılmaz)', async () => {
    const s = await buildIdentityStack();
    const log = new FakeDeletionLog();
    const failing = Object.assign(Object.create(Object.getPrototypeOf(s.users)), s.users, {
      deleteById: async (): Promise<void> => {
        throw new Error('db yok');
      },
    }) as typeof s.users;

    await expect(new DeleteAccountUseCase(failing, log).execute('u-1')).rejects.toThrow();
    expect(log.ticks).toHaveLength(0);
  });
});
