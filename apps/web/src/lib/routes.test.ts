import { describe, it, expect } from 'vitest';
import { getSiteRoutes } from './routes';
import { ARCHETYPE_SLUGS } from '@/content/archetypes';
import { BLOG_SLUGS } from '@/content/blog';

describe('getSiteRoutes (sitemap kaynağı)', () => {
  it('ana sayfa, test, dizin, sss, blog ve tüm archetype sayfalarını içerir', () => {
    const routes = getSiteRoutes();
    expect(routes).toContain('/');
    expect(routes).toContain('/test');
    expect(routes).toContain('/archetypes');
    expect(routes).toContain('/faq');
    expect(routes).toContain('/blog');
    for (const slug of ARCHETYPE_SLUGS) {
      expect(routes).toContain(`/a/${slug}`);
    }
  });

  it("tüm blog yazıları sitemap'te (long-tail indekslenebilir)", () => {
    const routes = getSiteRoutes();
    for (const slug of BLOG_SLUGS) {
      expect(routes).toContain(`/blog/${slug}`);
    }
  });

  it('sayfa sayısıyla tutarlı (5 sabit + N archetype + M blog)', () => {
    expect(getSiteRoutes()).toHaveLength(5 + ARCHETYPE_SLUGS.length + BLOG_SLUGS.length);
  });
});
