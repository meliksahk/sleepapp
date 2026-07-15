import { buildIdentityStack } from './harness';
import { InvalidAccessTokenError } from '../../src/modules/identity/domain/errors';

/**
 * "Kullanıcı A, B'nin verisine erişemez" (CLAUDE.md §6). identity düzeyinde:
 * token'lar birbirine karışmaz, A'nın token'ı yalnızca A'yı çözer, A'nın refresh
 * token'ı yalnızca A'nın oturumunu döndürür.
 */
describe('İzolasyon: A, B olamaz', () => {
  it("A'nın access token'ı A'yı, B'ninki B'yi çözer (karışmaz)", async () => {
    const s = await buildIdentityStack();
    const a = await s.registerDevice.execute({ fingerprint: 'user-a', platform: 'ios' });
    const b = await s.registerDevice.execute({ fingerprint: 'user-b', platform: 'ios' });

    const claimsA = await s.authorize.execute(a.accessToken);
    const claimsB = await s.authorize.execute(b.accessToken);

    expect(claimsA.sub).toBe(a.userId);
    expect(claimsB.sub).toBe(b.userId);
    expect(claimsA.sub).not.toBe(claimsB.sub);
  });

  it("A'nın refresh token'ı yalnızca A'nın oturumunu üretir (B'yi asla)", async () => {
    const s = await buildIdentityStack();
    const a = await s.registerDevice.execute({ fingerprint: 'user-a2', platform: 'ios' });
    await s.registerDevice.execute({ fingerprint: 'user-b2', platform: 'ios' });

    const rotated = await s.refreshSession.execute(a.refreshToken);
    expect(rotated.userId).toBe(a.userId);
  });

  it('kurcalanmış / yabancı imzalı token reddedilir', async () => {
    const s1 = await buildIdentityStack();
    const s2 = await buildIdentityStack(); // farklı ephemeral anahtar
    const a = await s1.registerDevice.execute({ fingerprint: 'user-a3', platform: 'ios' });

    // s2'nin signer'ı s1'in token'ını doğrulayamaz (farklı anahtar).
    await expect(s2.authorize.execute(a.accessToken)).rejects.toBeInstanceOf(
      InvalidAccessTokenError,
    );

    // Kurcalanmış token de reddedilir.
    await expect(s1.authorize.execute(a.accessToken + 'x')).rejects.toBeInstanceOf(
      InvalidAccessTokenError,
    );
  });
});
