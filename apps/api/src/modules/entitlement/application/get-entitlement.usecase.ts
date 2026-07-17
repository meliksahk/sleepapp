import type { Entitlement, EntitlementService } from '../domain/entitlement';

/**
 * Kullanıcının güncel yetkilendirmesini döndürür. İnce bir use case: bugün yalnızca
 * port'a delege eder. Yine de VAR çünkü B5'te (gerçek IAP) burada deneme süresi
 * hesabı, senkron tetikleme gibi mantık eklenecek — controller'a değil buraya.
 */
export class GetEntitlementUseCase {
  constructor(private readonly service: EntitlementService) {}

  execute(userId: string): Promise<Entitlement> {
    return this.service.entitlementFor(userId);
  }
}
