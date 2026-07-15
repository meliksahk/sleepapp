import type { MetadataRoute } from 'next';
import { getSiteRoutes, SITE_URL } from '@/lib/routes';

// Otomatik sitemap (docs/05 §3.1) — rota listesi tek kaynaktan üretilir.
export default function sitemap(): MetadataRoute.Sitemap {
  return getSiteRoutes().map((path) => ({
    url: `${SITE_URL}${path}`,
    changeFrequency: 'weekly',
    priority: path === '/' ? 1 : 0.7,
  }));
}
