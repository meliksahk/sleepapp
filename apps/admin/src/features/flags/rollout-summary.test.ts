import { describe, it, expect } from 'vitest';
import { rolloutSummary } from './rollout-summary';

describe('rolloutSummary', () => {
  it('yüzde tanımsızsa tüm kullanıcılar', () => {
    expect(rolloutSummary('tr', { enabled: true })).toBe('tüm kullanıcılar');
  });

  it('yüzde varsa gösterilir', () => {
    expect(rolloutSummary('tr', { enabled: true, rolloutPercentage: 25 })).toBe('%25 kullanıcı');
  });

  it('yüzde 0-100 aralığına kırpılır (bozuk veri UI kırmaz)', () => {
    expect(rolloutSummary('tr', { enabled: true, rolloutPercentage: 250 })).toBe('%100 kullanıcı');
    expect(rolloutSummary('tr', { enabled: true, rolloutPercentage: -5 })).toBe('%0 kullanıcı');
  });

  it('platform + sürüm segmentleri GÖRÜNÜR olur (görünmez kısıt yok)', () => {
    expect(
      rolloutSummary('tr', { enabled: true, platforms: ['ios'], minAppVersion: '1.4.0' }),
    ).toBe('tüm kullanıcılar · yalnızca ios · sürüm ≥ 1.4.0');
  });

  it('tüm kurallar birlikte tek satırda', () => {
    expect(
      rolloutSummary('tr', {
        enabled: true,
        rolloutPercentage: 50,
        platforms: ['ios', 'android'],
        minAppVersion: '2.0.0',
      }),
    ).toBe('%50 kullanıcı · yalnızca ios, android · sürüm ≥ 2.0.0');
  });

  it('ÇEKİRDEK: EN panelde özet İngilizce ve yüzde işareti SONDA', () => {
    // Özet tamamen TR sabit-koduydu — EN panelde Türkçe kalıyordu.
    expect(
      rolloutSummary('en', {
        enabled: true,
        rolloutPercentage: 50,
        platforms: ['ios'],
        minAppVersion: '2.0.0',
      }),
    ).toBe('50% of users · ios only · version ≥ 2.0.0');
    expect(rolloutSummary('en', { enabled: true })).toBe('all users');
  });

  it('ondalık rollout YUVARLANMAZ (elle girilen değer gerçek veridir)', () => {
    // Regresyon kilidi: formatPercent varsayılanı 0 ondalık ve rollout onu
    // kullansaydı %12,5 panelde %13 görünürdü — operatöre yanlış değer.
    expect(rolloutSummary('tr', { enabled: true, rolloutPercentage: 12.5 })).toContain('%12,5');
    expect(rolloutSummary('en', { enabled: true, rolloutPercentage: 12.5 })).toContain('12.5%');
    // Tam sayıda gereksiz ondalık ÇIKMAZ.
    expect(rolloutSummary('tr', { enabled: true, rolloutPercentage: 25 })).toContain('%25');
  });
});
