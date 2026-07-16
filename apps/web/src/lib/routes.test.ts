import { describe, it, expect } from 'vitest';
import { getSiteRoutes } from './routes';
import { ARCHETYPE_SLUGS } from '@/content/archetypes';

describe('getSiteRoutes (sitemap kaynağı)', () => {
  it('ana sayfa, test, dizin ve tüm archetype sayfalarını içerir', () => {
    const routes = getSiteRoutes();
    expect(routes).toContain('/');
    expect(routes).toContain('/test');
    expect(routes).toContain('/archetypes');
    for (const slug of ARCHETYPE_SLUGS) {
      expect(routes).toContain(`/a/${slug}`);
    }
  });

  it('archetype sayısıyla tutarlı (3 sabit + N archetype)', () => {
    expect(getSiteRoutes()).toHaveLength(3 + ARCHETYPE_SLUGS.length);
  });
});
