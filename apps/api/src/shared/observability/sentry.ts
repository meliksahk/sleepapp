import * as Sentry from '@sentry/node';

/**
 * Sentry hata izleme başlatma (CLAUDE.md §4: "Tüm yüzeylerde Sentry aktif").
 *
 * **DSN yoksa init EDİLMEZ** — `Sentry.captureException` init'siz güvenle no-op'tur, yani
 * geliştirmede/testte (SENTRY_DSN boş) hiçbir şey gönderilmez. Secret asla koda gömülmez;
 * DSN yalnız process.env'den gelir (§6) → deploy'da .env / GitHub Environments'ta verilir.
 *
 * Tracing kapalı (tracesSampleRate: 0): şimdilik yalnız hata izleme; performans örneklemesi
 * maliyet kararı (free-tier ilkesi) — açılacaksa bilinçli açılır.
 */
export function initSentry(dsn: string | undefined, environment: string): boolean {
  if (dsn === undefined || dsn.length === 0) return false;
  Sentry.init({
    dsn,
    environment,
    tracesSampleRate: 0,
  });
  return true;
}
