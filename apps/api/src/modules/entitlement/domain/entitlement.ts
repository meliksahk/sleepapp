/**
 * Entitlement (yetkilendirme) domain — premium kapısının TEK kaynağı
 * (docs/02 §148 B1, CLAUDE.md §6).
 *
 * **Neden ayrı bir port, neden ödeme kodu YOK:** IAP EN SON fazdır (docs/10).
 * "tüm yapı çalışır olmadan ve geliştirici hesapları bağlanmadan ödeme kodu
 * yazılmaz" (CLAUDE.md §6). O güne dek premium gating tek bir arayüzün —
 * `EntitlementService` — arkasında durur ve geliştirmede herkes premium döner.
 * Gerçek IAP geldiğinde YALNIZCA bu portun adaptörü değişir; uygulamanın başka
 * hiçbir yeri değişmez. Arayüzün varlık sebebi tam olarak budur: ödeme entegrasyonunu
 * "tak-çıkar" yapmak.
 */

/** Sunucu şeması (docs/02 §107): entitlements.tier = free | plus | lifetime. */
export type EntitlementTier = 'free' | 'plus' | 'lifetime';

export interface Entitlement {
  readonly tier: EntitlementTier;
}

/**
 * Premium kapısı — TEK yer. `plus` (abonelik) ve `lifetime` (tek seferlik satın alma)
 * premium'dur; `free` değildir. Bu mantığı çağıran her yere kopyalamak yerine burada
 * tutuyoruz ki "premium ne demek" tek bir yerde tanımlı kalsın (ör. lifetime ileride
 * eklendiğinde bir gating unutulmasın).
 */
export function isPremium(tier: EntitlementTier): boolean {
  return tier === 'plus' || tier === 'lifetime';
}

/**
 * Bir kullanıcının güncel yetkilendirmesini döndüren port. Diğer modüller premium
 * kapısı için YALNIZCA bunu enjekte eder — IAP'yi, App Store'u, DB'yi asla doğrudan
 * bilmezler.
 */
export interface EntitlementService {
  entitlementFor(userId: string): Promise<Entitlement>;
}

export const ENTITLEMENT_SERVICE = Symbol('EntitlementService');
