/** sleep modülü tipli hataları (CLAUDE.md §4: boş catch / string hata yasak). */
export class SleepError extends Error {
  constructor(
    readonly code: 'invalid_range',
    message: string,
  ) {
    super(message);
    this.name = 'SleepError';
  }
}
