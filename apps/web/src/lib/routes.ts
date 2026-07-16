import { ARCHETYPE_SLUGS } from '@/content/archetypes';

export const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://nocta.app';

/** İndekslenebilir tüm rota yolları (sitemap tek kaynağı). /r/ paylaşımları noindex. */
export function getSiteRoutes(): string[] {
  return ['/', '/test', '/archetypes', ...ARCHETYPE_SLUGS.map((slug) => `/a/${slug}`)];
}
