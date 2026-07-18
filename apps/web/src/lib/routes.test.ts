import { describe, it, expect } from 'vitest';
import {
  buildAlternates,
  getLocalizedRoutes,
  getSiteRoutes,
  localePath,
  SITE_URL,
  TRANSLATED_ROUTES,
} from './routes';
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

describe('localePath (TR alt dizini)', () => {
  it('EN kökte kalır — mevcut URL ve dış bağlantılar korunur', () => {
    expect(localePath('en', '/')).toBe('/');
    expect(localePath('en', '/faq')).toBe('/faq');
    expect(localePath('en', '/a/deep-ocean')).toBe('/a/deep-ocean');
  });

  it('TR /tr altına iner, ana sayfa /tr olur (çift eğik çizgi yok)', () => {
    expect(localePath('tr', '/')).toBe('/tr');
    expect(localePath('tr', '/faq')).toBe('/tr/faq');
    expect(localePath('tr', '/a/deep-ocean')).toBe('/tr/a/deep-ocean');
  });

  it('SLUG ÇEVRİLMEZ — paylaşım linkleri ve derin linkler sabit kalır', () => {
    // Slug'lar mobil paylaşım kartında ve `nocta://a/deep-ocean` derin linkinde
    // dokümante; çevirmek 301 zinciri + kırık paylaşım linki demek olurdu.
    for (const slug of ARCHETYPE_SLUGS) {
      expect(localePath('tr', `/a/${slug}`)).toBe(`/tr/a/${slug}`);
    }
  });
});

describe('getLocalizedRoutes (sitemap)', () => {
  const routes = getLocalizedRoutes().map((r) => r.path);

  it('her çevrilmiş sayfanın hem EN hem TR sürümü var', () => {
    for (const path of TRANSLATED_ROUTES) {
      expect(routes).toContain(localePath('en', path));
      expect(routes).toContain(localePath('tr', path));
    }
  });

  it('yalnızca-EN sayfalar (blog) TEK kez, TR sürümü olmadan yer alır', () => {
    expect(routes).toContain('/blog');
    expect(routes).not.toContain('/tr/blog');
    for (const slug of BLOG_SLUGS) {
      expect(routes).toContain(`/blog/${slug}`);
      expect(routes).not.toContain(`/tr/blog/${slug}`);
    }
  });

  it('tekrar eden URL yok', () => {
    expect(new Set(routes).size).toBe(routes.length);
  });
});

describe('buildAlternates (hreflang zinciri)', () => {
  it('canonical kendi dilini gösterir', () => {
    expect(buildAlternates('en', '/faq').canonical).toBe(`${SITE_URL}/faq`);
    expect(buildAlternates('tr', '/faq').canonical).toBe(`${SITE_URL}/tr/faq`);
  });

  it('iki dil KARŞILIKLI işaret eder (tek yönlü hreflang Google tarafından yok sayılır)', () => {
    const en = buildAlternates('en', '/test').languages;
    const tr = buildAlternates('tr', '/test').languages;
    expect(en).toEqual(tr);
    expect(en.en).toBe(`${SITE_URL}/test`);
    expect(en.tr).toBe(`${SITE_URL}/tr/test`);
  });

  it('x-default EN (birincil dil, CLAUDE.md §4)', () => {
    expect(buildAlternates('tr', '/').languages['x-default']).toBe(`${SITE_URL}/`);
    expect(buildAlternates('tr', '/archetypes').languages['x-default']).toBe(
      `${SITE_URL}/archetypes`,
    );
  });
});
