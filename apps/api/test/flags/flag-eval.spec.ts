import { evaluateFlag, parseRules } from '../../src/modules/flags/domain/flag';
import { CryptoBucketHasher } from '../../src/modules/flags/infrastructure/crypto-bucket-hasher';

describe('flag evaluation (saf domain)', () => {
  it('enabled:false → her zaman kapalı', () => {
    expect(evaluateFlag({ enabled: false }, 0)).toBe(false);
    expect(evaluateFlag({ enabled: false, rolloutPercentage: 100 }, 0)).toBe(false);
  });

  it('enabled:true, rollout yok → açık', () => {
    expect(evaluateFlag({ enabled: true }, 99)).toBe(true);
  });

  it('rollout yüzdesi kovaya göre değerlendirir', () => {
    expect(evaluateFlag({ enabled: true, rolloutPercentage: 50 }, 30)).toBe(true);
    expect(evaluateFlag({ enabled: true, rolloutPercentage: 50 }, 50)).toBe(false);
    expect(evaluateFlag({ enabled: true, rolloutPercentage: 50 }, 70)).toBe(false);
    expect(evaluateFlag({ enabled: true, rolloutPercentage: 0 }, 0)).toBe(false);
    expect(evaluateFlag({ enabled: true, rolloutPercentage: 100 }, 99)).toBe(true);
  });

  it('parseRules güvenli indirger', () => {
    expect(parseRules(null)).toEqual({ enabled: false });
    expect(parseRules('x')).toEqual({ enabled: false });
    expect(parseRules({ enabled: true })).toEqual({ enabled: true });
    expect(parseRules({ enabled: true, rolloutPercentage: 20 })).toEqual({
      enabled: true,
      rolloutPercentage: 20,
    });
  });
});

describe('CryptoBucketHasher', () => {
  const h = new CryptoBucketHasher();
  it('deterministik ve 0-99 aralığında', () => {
    const a = h.bucket('user-1', 'flag-a');
    expect(a).toBe(h.bucket('user-1', 'flag-a'));
    expect(a).toBeGreaterThanOrEqual(0);
    expect(a).toBeLessThan(100);
  });
  it('farklı kullanıcı/flag farklı kova üretebilir', () => {
    expect(h.bucket('user-1', 'flag-a')).not.toBe(h.bucket('user-1', 'flag-b'));
  });
});
