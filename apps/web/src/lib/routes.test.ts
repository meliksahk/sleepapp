import { describe, it, expect } from 'vitest';
import { getSiteRoutes } from './routes';
import { ARCHETYPE_SLUGS } from '@/content/archetypes';

describe('getSiteRoutes (sitemap kaynağı)', () => {
  it('ana sayfa, test ve tüm archetype sayfalarını içerir', () => {
    const routes = getSiteRoutes();
    expect(routes).toContain('/');
    expect(routes).toContain('/test');
    for (const slug of ARCHETYPE_SLUGS) {
      expect(routes).toContain(`/a/${slug}`);
    }
  });

  it('archetype sayısıyla tutarlı (2 sabit + N archetype)', () => {
    expect(getSiteRoutes()).toHaveLength(2 + ARCHETYPE_SLUGS.length);
  });
});
