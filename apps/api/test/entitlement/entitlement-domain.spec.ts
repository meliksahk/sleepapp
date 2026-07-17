import { GetEntitlementUseCase } from '../../src/modules/entitlement/application/get-entitlement.usecase';
import {
  isPremium,
  type EntitlementService,
} from '../../src/modules/entitlement/domain/entitlement';
import { DevEntitlementService } from '../../src/modules/entitlement/infrastructure/dev-entitlement.service';

describe('entitlement domain', () => {
  describe('isPremium — premium kapısı TEK yerde', () => {
    it('ÇEKİRDEK: plus ve lifetime premium; free değil', () => {
      expect(isPremium('plus')).toBe(true);
      expect(isPremium('lifetime')).toBe(true);
      expect(isPremium('free')).toBe(false);
    });
  });

  describe('DevEntitlementService (geliştirme stub)', () => {
    it('ÇEKİRDEK: herkes premium döner (docs/02 B1, CLAUDE.md §6)', async () => {
      const e = await new DevEntitlementService().entitlementFor('any-user');
      expect(isPremium(e.tier)).toBe(true);
    });

    it('userId ne olursa olsun aynı sonucu döner (kim sorarsa premium)', async () => {
      const svc = new DevEntitlementService();
      const a = await svc.entitlementFor('user-a');
      const b = await svc.entitlementFor('user-b');
      expect(a.tier).toBe(b.tier);
    });
  });

  describe('GetEntitlementUseCase', () => {
    it("ÇEKİRDEK: sonuç STUB'a değil PORT'a bağlı — IAP geldiğinde free de dönebilir", async () => {
      // Use case premium'u SABİTLEMEZ; ne dönerse porttan döner. B5'te gerçek
      // adaptör free dönebilmeli; bu test o sözleşmeyi kilitler.
      const calls: string[] = [];
      const fakeFree: EntitlementService = {
        entitlementFor: async (userId) => {
          calls.push(userId);
          return { tier: 'free' };
        },
      };
      const result = await new GetEntitlementUseCase(fakeFree).execute('u-123');
      expect(calls).toEqual(['u-123']); // token'daki sub ile çağrılır
      expect(result.tier).toBe('free');
      expect(isPremium(result.tier)).toBe(false);
    });
  });
});
