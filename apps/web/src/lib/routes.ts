import { ARCHETYPE_SLUGS } from '@/content/archetypes';
import { BLOG_SLUGS } from '@/content/blog';
import { LOCALES, type Locale } from '@/lib/i18n';

export const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://nocta.app';

/** İndekslenebilir tüm EN rota yolları (sitemap tek kaynağı). /r/ paylaşımları noindex. */
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

/**
 * TR karşılığı OLAN sayfaların dilden bağımsız yolları.
 *
 * Blog TR'de YOK (bilinçli kapsam kararı — 6 uzun yazının çevirisi bu dilime
 * sığmıyor): blog yalnızca EN'de kalır, dolayısıyla blog sayfalarına hreflang
 * eklenmez. Karşılığı olmayan bir dile hreflang vermek yanlış sinyaldir.
 */
export const TRANSLATED_ROUTES: readonly string[] = [
  '/',
  '/test',
  '/archetypes',
  '/faq',
  ...ARCHETYPE_SLUGS.map((slug) => `/a/${slug}`),
];

/**
 * Dilden bağımsız yolu ([TRANSLATED_ROUTES] üyesi) o dildeki gerçek URL yoluna çevirir.
 * EN kökte kalır (`/faq`), TR alt dizine iner (`/tr/faq`) — mevcut EN URL'leri ve
 * dış bağlantılar korunur.
 */
export function localePath(locale: Locale, path: string): string {
  if (locale === 'en') return path;
  return path === '/' ? '/tr' : `/tr${path}`;
}

/** Sitemap için: her dilin her çevrilmiş sayfası + yalnızca-EN sayfalar. */
export function getLocalizedRoutes(): Array<{ locale: Locale; path: string }> {
  const translated = LOCALES.flatMap((locale) =>
    TRANSLATED_ROUTES.map((path) => ({ locale, path: localePath(locale, path) })),
  );
  const enOnly = getSiteRoutes()
    .filter((path) => !TRANSLATED_ROUTES.includes(path))
    .map((path) => ({ locale: 'en' as Locale, path }));
  return [...translated, ...enOnly];
}

/**
 * hreflang + canonical (docs/05 SEO zinciri).
 *
 * Her dil sürümü kendi canonical'ını gösterir ve DİĞER dilleri `alternates.languages`
 * ile işaret eder; `x-default` EN'dir (birincil dil, CLAUDE.md §4). Karşılıklı
 * işaretleme olmadan Google hreflang'i yok sayar — bu yüzden iki taraf da yazılır.
 */
export function buildAlternates(
  locale: Locale,
  path: string,
): { canonical: string; languages: Record<string, string> } {
  return {
    canonical: `${SITE_URL}${localePath(locale, path)}`,
    languages: {
      en: `${SITE_URL}${localePath('en', path)}`,
      tr: `${SITE_URL}${localePath('tr', path)}`,
      'x-default': `${SITE_URL}${localePath('en', path)}`,
    },
  };
}
