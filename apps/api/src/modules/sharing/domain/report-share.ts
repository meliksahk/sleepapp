import type { ShareUrls } from './share';

/**
 * Gece raporu paylaşım kartı — saf domain (viral kanca #2). SAĞLIK İDDİASI YOK:
 * "relaxation & sleep ritual" çerçevesi; süre + göreli calm skoru (sağlık ölçüsü
 * değil). Web hedefi kişisel değil — indirme CTA'sı (site) + uygulama deep-link'i.
 */
export interface NightReportShare {
  readonly nightDate: string;
  readonly title: string;
  readonly subtitle: string;
  readonly durationText: string;
  readonly calmScore: number;
  readonly webUrl: string;
  readonly deepLink: string;
}

/** Dakika → "7h 42m" / "45m". */
export function formatDuration(totalMinutes: number): string {
  const h = Math.floor(totalMinutes / 60);
  const m = totalMinutes % 60;
  if (h === 0) return `${m}m`;
  if (m === 0) return `${h}h`;
  return `${h}h ${m}m`;
}

export function buildNightReportShare(
  input: { nightDate: string; totalDurationMinutes: number; calmScore: number },
  urls: ShareUrls,
): NightReportShare {
  const durationText = formatDuration(input.totalDurationMinutes);
  const base = urls.webBaseUrl.replace(/\/+$/, '');
  return {
    nightDate: input.nightDate,
    title: `My night: ${durationText}`,
    subtitle: `Calm ${input.calmScore}/100 · NOCTA sleep ritual`,
    durationText,
    calmScore: input.calmScore,
    webUrl: base, // indirme CTA (kişisel rapor sayfası yok)
    deepLink: `${urls.appScheme}://report/${input.nightDate}`,
  };
}
