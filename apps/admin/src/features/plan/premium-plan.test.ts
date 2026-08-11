import { describe, expect, it } from 'vitest';

import { FREE_LIBRARY_SIZE, FREE_MIX_SLOTS, PREMIUM_FEATURES, TRIAL_DAYS } from './premium-plan';
import { dictionaries } from '@/shared/i18n/dictionaries';

/**
 * Panel plan sayfasının sözleşmesi (F5).
 *
 * Sürüklenmeyi `tooling/check-premium-plan-drift.mjs` kolluyor (mobil ↔ panel).
 * Burada kilitlenen şey daha dar ama en az onun kadar kritik: listedeki HER
 * özelliğin bir metni var mı. Metni olmayan bir özellik panelde boş satır
 * olarak görünür ve editör onu "eksik" değil "yok" sanar.
 */
describe('premium plan tablosu', () => {
  it('her premium özelliğin iki dilde de metni var', () => {
    for (const locale of ['tr', 'en'] as const) {
      for (const feature of PREMIUM_FEATURES) {
        const key = `plan.feature.${feature}`;
        expect(
          dictionaries[locale][key as keyof (typeof dictionaries)['tr']],
          `${locale}/${key} eksik`,
        ).toBeTruthy();
      }
    }
  });

  it('ücretsiz kotalar ve deneme süresi anlamlı', () => {
    expect(TRIAL_DAYS).toBeGreaterThan(0);
    expect(FREE_LIBRARY_SIZE).toBeGreaterThan(0);
    expect(FREE_MIX_SLOTS).toBeGreaterThan(0);
  });

  it('ÖDEME BAĞLI DEĞİL uyarısı iki dilde de duruyor', () => {
    // Bu cümle düşerse panel, ekibi kendi ürünü hakkında yanıltır: sunucu bugün
    // HERKESE premium dönüyor ve aşağıdaki sınır uygulanmıyor.
    expect(dictionaries.tr['plan.notConnected']).toContain('BAĞLI DEĞİL');
    expect(dictionaries.en['plan.notConnected']).toContain('NOT CONNECTED');
  });
});
