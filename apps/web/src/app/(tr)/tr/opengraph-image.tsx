import { OG_CONTENT_TYPE, OG_SIZE, renderOgImage } from '@/lib/og';
import { t } from '@/lib/i18n';

// TR bölümünün OG görseli (/tr ve altındaki sayfalar). EN karşılığı `(en)/opengraph-image.tsx`.
export const alt = 'NOCTA — Gecenin bir kimliği var';
export const size = OG_SIZE;
export const contentType = OG_CONTENT_TYPE;

export default function Image() {
  return renderOgImage({
    eyebrow: 'NOCTA',
    title: t('tr', 'home.title'),
    subtitle: t('tr', 'home.cta') + ' →',
  });
}
