import type { NewAnalyticsEvent } from './analytics-event';

/** analytics_events yazımı — userId ile scope'lu (docs/02 §2.1). */
export interface AnalyticsEventRepository {
  saveBatch(userId: string, events: readonly NewAnalyticsEvent[]): Promise<number>;
}

export const ANALYTICS_EVENT_REPOSITORY = Symbol('AnalyticsEventRepository');
