import type { NewAnalyticsEvent } from './analytics-event';

/**
 * Paylaşım hunisi ham sayıları. ORAN burada hesaplanmaz — bölme domain'in işi;
 * repo yalnızca sayar (sıfıra bölme kararı SQL'e gömülmemeli).
 */
export interface ShareFunnelCounts {
  readonly completed: number;
  readonly shared: number;
}

/** analytics_events yazımı — userId ile scope'lu (docs/02 §2.1). */
export interface AnalyticsEventRepository {
  saveBatch(userId: string, events: readonly NewAnalyticsEvent[]): Promise<number>;
  /**
   * Panel panosu: verilen olay adlarının BENZERSİZ KULLANICI sayısı.
   *
   * Neden kullanıcı, neden olay değil: tek kullanıcı kartını 5 kez paylaşırsa
   * huni "%500" gösterirdi. Viral kanca sorusu "kaç kişi paylaştı?"dır.
   * Bu yüzden `COUNT(DISTINCT user_id)` — satırları çekmez.
   */
  shareFunnel(): Promise<ShareFunnelCounts>;
}

export const ANALYTICS_EVENT_REPOSITORY = Symbol('AnalyticsEventRepository');
