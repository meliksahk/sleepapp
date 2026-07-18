// schema.org JSON-LD üretimi — tek util'den (docs/05 §3.1; elle JSON yazılmaz).
// SAĞLIK İDDİASI YASAK (CLAUDE.md §1.1): "relaxation & sleep ritual" dili.

import { localePath } from '@/lib/routes';
import { t, type Locale } from '@/lib/i18n';

const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://nocta.app';

/**
 * Site açıklaması dile göre. Sağlık iddiası YASAK (CLAUDE.md §1.1): iki dilde de
 * konumlandırma "relaxation & sleep ritual" / "rahatlama ve uyku ritüeli".
 */
const SITE_DESCRIPTIONS: Record<Locale, string> = {
  en: 'A relaxation and sleep ritual app built around your sleep identity.',
  tr: 'Uyku kimliğin üzerine kurulu bir rahatlama ve uyku ritüeli uygulaması.',
};
/** Dil sürümünün mutlak URL'i — JSON-LD `url` alanları dile göre ayrışır. */
function localeUrl(locale: Locale, path: string): string {
  return `${SITE_URL}${localePath(locale, path)}`;
}

/** Dilin kök URL'i. EN kökünde sondaki eğik çizgi YOK (canonical ile birebir aynı). */
function localeRoot(locale: Locale): string {
  return locale === 'en' ? SITE_URL : `${SITE_URL}/tr`;
}

export interface ArticleJsonLdInput {
  slug: string;
  name: string;
  summary: string;
}

export function buildArchetypeJsonLd(
  input: ArticleJsonLdInput,
  locale: Locale = 'en',
): Record<string, unknown> {
  return {
    '@context': 'https://schema.org',
    '@type': 'Article',
    headline: t(locale, 'meta.archetype.headline', { name: input.name }),
    description: input.summary,
    inLanguage: locale,
    url: localeUrl(locale, `/a/${input.slug}`),
    isPartOf: {
      '@type': 'WebSite',
      name: 'NOCTA',
      url: localeRoot(locale),
    },
  };
}

/**
 * Genel gezinti kırıntısı — arama sonucu zenginleştirme (docs/05 §3.1).
 * `path` site köküne göredir ('' = ana sayfa). Sıra dizideki sıradır.
 */
export function buildBreadcrumbTrail(
  crumbs: ReadonlyArray<{ name: string; path: string }>,
): Record<string, unknown> {
  return {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: crumbs.map((c, i) => ({
      '@type': 'ListItem',
      position: i + 1,
      name: c.name,
      item: `${SITE_URL}${c.path}`,
    })),
  };
}

/** Sayfa gezinti kırıntısı (Home → archetype) — genel builder'a delege eder. */
export function buildBreadcrumbJsonLd(
  input: { slug: string; name: string },
  locale: Locale = 'en',
): Record<string, unknown> {
  return buildBreadcrumbTrail([
    { name: t(locale, 'crumb.home'), path: locale === 'en' ? '' : '/tr' },
    { name: input.name, path: localePath(locale, `/a/${input.slug}`) },
  ]);
}

/** Archetype dizin sayfası — sıralı liste (SEO iç bağlantı sinyali). */
export function buildArchetypeListJsonLd(
  items: ReadonlyArray<{ slug: string; name: string }>,
  locale: Locale = 'en',
): Record<string, unknown> {
  return {
    '@context': 'https://schema.org',
    '@type': 'ItemList',
    name: t(locale, 'archetypes.listName'),
    itemListElement: items.map((item, i) => ({
      '@type': 'ListItem',
      position: i + 1,
      name: item.name,
      url: localeUrl(locale, `/a/${item.slug}`),
    })),
  };
}

/** SSS sayfası — FAQPage (GEO/AI-özet + arama sonucu zenginleştirme, docs/05 §4). */
export function buildFaqJsonLd(
  items: ReadonlyArray<{ question: string; answer: string }>,
): Record<string, unknown> {
  return {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: items.map((item) => ({
      '@type': 'Question',
      name: item.question,
      acceptedAnswer: { '@type': 'Answer', text: item.answer },
    })),
  };
}

/** Blog yazısı — Article (docs/05 long-tail; datePublished ile tazelik sinyali). */
export function buildBlogPostJsonLd(input: {
  slug: string;
  title: string;
  description: string;
  publishedAt: string;
}): Record<string, unknown> {
  return {
    '@context': 'https://schema.org',
    '@type': 'Article',
    headline: input.title,
    description: input.description,
    datePublished: input.publishedAt,
    url: `${SITE_URL}/blog/${input.slug}`,
    isPartOf: { '@type': 'WebSite', name: 'NOCTA', url: SITE_URL },
    publisher: { '@type': 'Organization', name: 'NOCTA', url: SITE_URL },
  };
}

/** Blog yazısı gezinti kırıntısı (Home → Blog → yazı). */
export function buildBlogBreadcrumbJsonLd(input: {
  slug: string;
  title: string;
}): Record<string, unknown> {
  return buildBreadcrumbTrail([
    { name: 'Home', path: '' },
    { name: 'Blog', path: '/blog' },
    { name: input.title, path: `/blog/${input.slug}` },
  ]);
}

/** Site geneli Organization — her sayfada (root layout). */
export function buildOrganizationJsonLd(locale: Locale = 'en'): Record<string, unknown> {
  return {
    '@context': 'https://schema.org',
    '@type': 'Organization',
    name: 'NOCTA',
    url: SITE_URL,
    description: SITE_DESCRIPTIONS[locale],
  };
}

/** Site geneli WebSite — GEO/SEO kimliği (root layout). */
export function buildWebSiteJsonLd(locale: Locale = 'en'): Record<string, unknown> {
  return {
    '@context': 'https://schema.org',
    '@type': 'WebSite',
    name: 'NOCTA',
    url: localeRoot(locale),
    inLanguage: locale,
    description: SITE_DESCRIPTIONS[locale],
  };
}
