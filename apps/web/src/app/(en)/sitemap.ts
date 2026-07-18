import type { MetadataRoute } from 'next';
import { getLocalizedRoutes, SITE_URL } from '@/lib/routes';

/**
 * Otomatik sitemap (docs/05 §3.1) — rota listesi tek kaynaktan üretilir.
 *
 * KÖKTE KALIR (`/sitemap.xml`): `(en)` bir rota grubu olduğu için URL değişmez.
 * Locale altına taşımak `/sitemap.xml`i 404 yapardı ve robots.txt'teki referansı kırardı.
 * TR sayfaları da bu listede — yoksa `/tr/*` indekslenmezdi.
 */
export default function sitemap(): MetadataRoute.Sitemap {
  return getLocalizedRoutes().map(({ path }) => ({
    url: `${SITE_URL}${path}`,
    changeFrequency: 'weekly',
    priority: path === '/' ? 1 : 0.7,
  }));
}
