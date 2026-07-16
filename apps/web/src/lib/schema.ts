// schema.org JSON-LD üretimi — tek util'den (docs/05 §3.1; elle JSON yazılmaz).
// SAĞLIK İDDİASI YASAK (CLAUDE.md §1.1): "relaxation & sleep ritual" dili.

const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://nocta.app';
const SITE_DESCRIPTION = 'A relaxation and sleep ritual app built around your sleep identity.';

export interface ArticleJsonLdInput {
  slug: string;
  name: string;
  summary: string;
}

export function buildArchetypeJsonLd(input: ArticleJsonLdInput): Record<string, unknown> {
  return {
    '@context': 'https://schema.org',
    '@type': 'Article',
    headline: `${input.name} — Sleep Identity`,
    description: input.summary,
    url: `${SITE_URL}/a/${input.slug}`,
    isPartOf: {
      '@type': 'WebSite',
      name: 'NOCTA',
      url: SITE_URL,
    },
  };
}

/** Sayfa gezinti kırıntısı (Home → archetype) — arama sonucu zenginleştirme. */
export function buildBreadcrumbJsonLd(input: {
  slug: string;
  name: string;
}): Record<string, unknown> {
  return {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: [
      { '@type': 'ListItem', position: 1, name: 'Home', item: SITE_URL },
      {
        '@type': 'ListItem',
        position: 2,
        name: input.name,
        item: `${SITE_URL}/a/${input.slug}`,
      },
    ],
  };
}

/** Archetype dizin sayfası — sıralı liste (SEO iç bağlantı sinyali). */
export function buildArchetypeListJsonLd(
  items: ReadonlyArray<{ slug: string; name: string }>,
): Record<string, unknown> {
  return {
    '@context': 'https://schema.org',
    '@type': 'ItemList',
    name: 'Sleep identities',
    itemListElement: items.map((item, i) => ({
      '@type': 'ListItem',
      position: i + 1,
      name: item.name,
      url: `${SITE_URL}/a/${item.slug}`,
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

/** Site geneli Organization — her sayfada (root layout). */
export function buildOrganizationJsonLd(): Record<string, unknown> {
  return {
    '@context': 'https://schema.org',
    '@type': 'Organization',
    name: 'NOCTA',
    url: SITE_URL,
    description: SITE_DESCRIPTION,
  };
}

/** Site geneli WebSite — GEO/SEO kimliği (root layout). */
export function buildWebSiteJsonLd(): Record<string, unknown> {
  return {
    '@context': 'https://schema.org',
    '@type': 'WebSite',
    name: 'NOCTA',
    url: SITE_URL,
    description: SITE_DESCRIPTION,
  };
}
