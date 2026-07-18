import { describe, it, expect } from 'vitest';
import { rolloutSummary } from './rollout-summary';

describe('rolloutSummary', () => {
  it('yüzde tanımsızsa tüm kullanıcılar', () => {
    expect(rolloutSummary({ enabled: true })).toBe('tüm kullanıcılar');
  });

  it('yüzde varsa gösterilir', () => {
    expect(rolloutSummary({ enabled: true, rolloutPercentage: 25 })).toBe('%25 kullanıcı');
  });

  it('yüzde 0-100 aralığına kırpılır (bozuk veri UI kırmaz)', () => {
    expect(rolloutSummary({ enabled: true, rolloutPercentage: 250 })).toBe('%100 kullanıcı');
    expect(rolloutSummary({ enabled: true, rolloutPercentage: -5 })).toBe('%0 kullanıcı');
  });

  it('platform + sürüm segmentleri GÖRÜNÜR olur (görünmez kısıt yok)', () => {
    expect(rolloutSummary({ enabled: true, platforms: ['ios'], minAppVersion: '1.4.0' })).toBe(
      'tüm kullanıcılar · yalnızca ios · sürüm ≥ 1.4.0',
    );
  });

  it('tüm kurallar birlikte tek satırda', () => {
    expect(
      rolloutSummary({
        enabled: true,
        rolloutPercentage: 50,
        platforms: ['ios', 'android'],
        minAppVersion: '2.0.0',
      }),
    ).toBe('%50 kullanıcı · yalnızca ios, android · sürüm ≥ 2.0.0');
  });
});
