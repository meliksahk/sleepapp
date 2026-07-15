import type { MetadataRoute } from 'next';
import { SITE_URL } from '@/lib/routes';

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: '*',
        allow: '/',
        // /r/ = paylaşılan gece raporları (noindex, OG'li — docs/05).
        disallow: ['/r/'],
      },
    ],
    sitemap: `${SITE_URL}/sitemap.xml`,
  };
}
