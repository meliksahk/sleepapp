import { compareVersions, evaluateFlag, parseRules } from '../../src/modules/flags/domain/flag';
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

  it('parseRules segment alanlarını okur (platforms + minAppVersion)', () => {
    expect(
      parseRules({ enabled: true, platforms: ['ios', 42, 'android'], minAppVersion: '1.4.0' }),
    ).toEqual({ enabled: true, platforms: ['ios', 'android'], minAppVersion: '1.4.0' });
    // boş/geçersiz platform dizisi atlanır
    expect(parseRules({ enabled: true, platforms: [] })).toEqual({ enabled: true });
  });

  describe('platform allowlist (fail-closed)', () => {
    const rules = { enabled: true, platforms: ['ios'] };
    it('eşleşen platform → açık', () => {
      expect(evaluateFlag(rules, 0, { platform: 'ios' })).toBe(true);
    });
    it('eşleşmeyen platform → kapalı', () => {
      expect(evaluateFlag(rules, 0, { platform: 'android' })).toBe(false);
    });
    it('context yoksa → kapalı (fail-closed)', () => {
      expect(evaluateFlag(rules, 0)).toBe(false);
    });
  });

  describe('minAppVersion (fail-closed)', () => {
    const rules = { enabled: true, minAppVersion: '1.4.0' };
    it('yeni/eşit sürüm → açık', () => {
      expect(evaluateFlag(rules, 0, { appVersion: '1.4.0' })).toBe(true);
      expect(evaluateFlag(rules, 0, { appVersion: '1.5.2' })).toBe(true);
    });
    it('eski sürüm → kapalı', () => {
      expect(evaluateFlag(rules, 0, { appVersion: '1.3.9' })).toBe(false);
    });
    it('sürüm yoksa → kapalı (fail-closed)', () => {
      expect(evaluateFlag(rules, 0)).toBe(false);
    });
  });

  it('segment + rollout birlikte: her ikisi de geçmeli', () => {
    const rules = { enabled: true, platforms: ['ios'], rolloutPercentage: 50 };
    expect(evaluateFlag(rules, 30, { platform: 'ios' })).toBe(true);
    expect(evaluateFlag(rules, 70, { platform: 'ios' })).toBe(false); // rollout dışı
    expect(evaluateFlag(rules, 30, { platform: 'android' })).toBe(false); // platform dışı
  });
});

describe('compareVersions', () => {
  it('küçük/eşit/büyük', () => {
    expect(compareVersions('1.3.9', '1.4.0')).toBe(-1);
    expect(compareVersions('1.4.0', '1.4.0')).toBe(0);
    expect(compareVersions('2.0.0', '1.9.9')).toBe(1);
  });
  it('farklı uzunluk (eksik parça = 0)', () => {
    expect(compareVersions('1.4', '1.4.0')).toBe(0);
    expect(compareVersions('1.4.1', '1.4')).toBe(1);
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
