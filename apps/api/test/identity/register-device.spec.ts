import { buildIdentityStack } from './harness';

describe('RegisterDeviceUseCase (anonim cihaz kaydı)', () => {
  it('yeni cihaz için geçerli access+refresh token üretir', async () => {
    const s = await buildIdentityStack();
    const session = await s.registerDevice.execute({ fingerprint: 'device-aaaa', platform: 'ios' });

    expect(session.userId).toBeTruthy();
    expect(session.accessToken.split('.')).toHaveLength(3); // JWT
    expect(session.refreshToken.length).toBeGreaterThan(20);
    expect(session.accessTokenExpiresIn).toBe(900);

    const claims = await s.authorize.execute(session.accessToken);
    expect(claims.sub).toBe(session.userId);
    expect(claims.aud).toBe('app');
  });

  it('aynı cihaz parmak izi aynı kullanıcıyı yeniden kullanır (idempotent)', async () => {
    const s = await buildIdentityStack();
    const first = await s.registerDevice.execute({
      fingerprint: 'device-bbbb',
      platform: 'android',
    });
    const second = await s.registerDevice.execute({
      fingerprint: 'device-bbbb',
      platform: 'android',
    });

    expect(second.userId).toBe(first.userId);
    // Yine de yeni (farklı) refresh token verir.
    expect(second.refreshToken).not.toBe(first.refreshToken);
  });

  it('farklı cihazlar farklı kullanıcı üretir', async () => {
    const s = await buildIdentityStack();
    const a = await s.registerDevice.execute({ fingerprint: 'device-cccc', platform: 'ios' });
    const b = await s.registerDevice.execute({ fingerprint: 'device-dddd', platform: 'ios' });
    expect(a.userId).not.toBe(b.userId);
  });
});
