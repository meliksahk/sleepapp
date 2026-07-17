import { Injectable } from '@nestjs/common';

import type { Entitlement, EntitlementService, EntitlementTier } from '../domain/entitlement';

/**
 * Geliştirme stub'ı — **HERKES premium** (docs/02 §152 B1, CLAUDE.md §6).
 *
 * Gerçek IAP (docs/10) bu SINIFI, transaction'ı doğrulayan (Apple App Store Server
 * API'si / StoreKit 2) ve `entitlements` tablosundan okuyan bir adaptörle değiştirir;
 * başka hiçbir yer değişmez. Bu yüzden burada DB yok, HTTP yok, secret yok — kasıtlı.
 *
 * **Neden `plus`, `lifetime` değil:** ikisi de premium'dur (bkz. `isPremium`), ama
 * "herkes ömür boyu satın almış" demek gerçek durumu yanlış temsil ederdi. `plus`
 * (aktif abone) geliştirmede daha dürüst bir varsayılan.
 */
@Injectable()
export class DevEntitlementService implements EntitlementService {
  private static readonly devTier: EntitlementTier = 'plus';

  // userId kasıtlı kullanılmıyor: stub kime sorulursa sorulsun premium döner.
  async entitlementFor(_userId: string): Promise<Entitlement> {
    return { tier: DevEntitlementService.devTier };
  }
}
