/** analytics modülü tipli hataları (CLAUDE.md §4). */
export class AnalyticsError extends Error {
  constructor(
    readonly code: 'empty_batch' | 'batch_too_large' | 'invalid_event_name' | 'unknown_event',
    message: string,
  ) {
    super(message);
    this.name = 'AnalyticsError';
  }
}
