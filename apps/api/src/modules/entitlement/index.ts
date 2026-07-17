// entitlement public API — diğer modüller premium kapısı için YALNIZCA buradan
// tüketir (docs/02 §2 boundary). IAP adaptörü değişse de bu yüzey sabit kalır.
export { EntitlementModule } from './entitlement.module';
export {
  ENTITLEMENT_SERVICE,
  isPremium,
  type Entitlement,
  type EntitlementService,
  type EntitlementTier,
} from './domain/entitlement';
