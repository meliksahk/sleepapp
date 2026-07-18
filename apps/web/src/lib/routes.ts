import { ARCHETYPE_SLUGS } from '@/content/archetypes';
import { BLOG_SLUGS } from '@/content/blog';

export const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://nocta.app';

/** İndekslenebilir tüm rota yolları (sitemap tek kaynağı). /r/ paylaşımları noindex. */
export function getSiteRoutes(): string[] {
  return [
    '/',
    '/test',
    '/archetypes',
    '/faq',
    '/blog',
    ...ARCHETYPE_SLUGS.map((slug) => `/a/${slug}`),
    ...BLOG_SLUGS.map((slug) => `/blog/${slug}`),
  ];
}
