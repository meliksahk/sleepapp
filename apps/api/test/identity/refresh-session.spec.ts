import { buildIdentityStack, MutableClock } from './harness';
import {
  InvalidRefreshTokenError,
  RefreshTokenReuseError,
} from '../../src/modules/identity/domain/errors';

describe('RefreshSessionUseCase (rotation + reuse-detection)', () => {
  it('geçerli refresh token yeni token çifti üretir ve eskisini iptal eder', async () => {
    const s = await buildIdentityStack();
    const first = await s.registerDevice.execute({ fingerprint: 'dev-1', platform: 'ios' });

    const rotated = await s.refreshSession.execute(first.refreshToken);
    expect(rotated.refreshToken).not.toBe(first.refreshToken);
    expect(rotated.userId).toBe(first.userId);

    // Yeni token de bir kez daha çalışır.
    const rotated2 = await s.refreshSession.execute(rotated.refreshToken);
    expect(rotated2.userId).toBe(first.userId);
  });

  it('iptal edilmiş (rotasyona uğramış) token yeniden kullanılırsa reuse tespit edilir ve aile düşürülür', async () => {
    const s = await buildIdentityStack();
    const first = await s.registerDevice.execute({ fingerprint: 'dev-2', platform: 'ios' });

    const rotated = await s.refreshSession.execute(first.refreshToken);

    // Eski (artık iptal) token yeniden kullanılır → reuse.
    await expect(s.refreshSession.execute(first.refreshToken)).rejects.toBeInstanceOf(
      RefreshTokenReuseError,
    );

    // Aile düşürüldüğü için rotasyondan gelen (artık iptal) token da reuse sayılır
    // ve aileyi yeniden düşürür — geçerli oturuma dönüş yok.
    await expect(s.refreshSession.execute(rotated.refreshToken)).rejects.toBeInstanceOf(
      RefreshTokenReuseError,
    );
  });

  it('bilinmeyen refresh token geçersizdir', async () => {
    const s = await buildIdentityStack();
    await expect(s.refreshSession.execute('bilinmeyen-token')).rejects.toBeInstanceOf(
      InvalidRefreshTokenError,
    );
  });

  it('süresi dolmuş refresh token geçersizdir', async () => {
    const clock = new MutableClock();
    const s = await buildIdentityStack({ refreshTtl: 10, clock });
    const first = await s.registerDevice.execute({ fingerprint: 'dev-3', platform: 'ios' });

    clock.advanceSeconds(11);
    await expect(s.refreshSession.execute(first.refreshToken)).rejects.toBeInstanceOf(
      InvalidRefreshTokenError,
    );
  });
});
