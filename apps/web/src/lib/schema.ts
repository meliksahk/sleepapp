// schema.org JSON-LD üretimi — tek util'den (docs/05 §3.1; elle JSON yazılmaz).

const SITE_URL = process.env.NEXT_PUBLIC_SITE_URL ?? 'https://nocta.app';

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
