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
