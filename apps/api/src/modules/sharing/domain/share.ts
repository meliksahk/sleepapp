/**
 * Archetype paylaşım kartı — saf domain (docs/02 sharing). Viral kanca #1.
 * SAĞLIK İDDİASI YASAK (CLAUDE.md §1.1): yalnızca "relaxation & sleep ritual" dili.
 */
export interface ArchetypeShare {
  readonly archetypeSlug: string;
  readonly title: string;
  readonly description: string;
  readonly webUrl: string;
  readonly deepLink: string;
}

export interface ShareUrls {
  readonly webBaseUrl: string;
  readonly appScheme: string;
}

/** slug ("deep-ocean") → görünen ad ("Deep Ocean"). */
export function slugToDisplayName(slug: string): string {
  return slug
    .split('-')
    .filter((w) => w.length > 0)
    .map((w) => `${w.charAt(0).toUpperCase()}${w.slice(1)}`)
    .join(' ');
}

export function buildArchetypeShare(slug: string, urls: ShareUrls): ArchetypeShare {
  const name = slugToDisplayName(slug);
  const base = urls.webBaseUrl.replace(/\/+$/, '');
  return {
    archetypeSlug: slug,
    title: `My sleep identity is ${name}`,
    description: 'Take the NOCTA sleep ritual test to discover yours.',
    webUrl: `${base}/a/${slug}`,
    deepLink: `${urls.appScheme}://a/${slug}`,
  };
}
