import { describe, it, expect } from 'vitest';
import {
  buildArchetypeJsonLd,
  buildBreadcrumbJsonLd,
  buildOrganizationJsonLd,
  buildWebSiteJsonLd,
} from './schema';

const sample = { slug: 'deep-ocean', name: 'Deep Ocean', summary: 'Sinks into stillness.' };

describe('schema.org JSON-LD builders', () => {
  it('Article: tip + url + isPartOf WebSite', () => {
    const ld = buildArchetypeJsonLd(sample);
    expect(ld['@type']).toBe('Article');
    expect(ld.url).toContain('/a/deep-ocean');
    expect((ld.isPartOf as { '@type': string })['@type']).toBe('WebSite');
  });

  it('BreadcrumbList: Home → archetype, doğru pozisyonlar', () => {
    const ld = buildBreadcrumbJsonLd(sample);
    expect(ld['@type']).toBe('BreadcrumbList');
    type Item = { position: number; name: string; item: string };
    const items = ld.itemListElement as [Item, Item];
    expect(items).toHaveLength(2);
    expect(items[0]).toMatchObject({ position: 1, name: 'Home' });
    expect(items[1]).toMatchObject({ position: 2, name: 'Deep Ocean' });
    expect(items[1].item).toContain('/a/deep-ocean');
  });

  it('Organization + WebSite: tip ve zorunlu alanlar', () => {
    const org = buildOrganizationJsonLd();
    expect(org['@type']).toBe('Organization');
    expect(org.name).toBe('NOCTA');
    expect(typeof org.url).toBe('string');

    const site = buildWebSiteJsonLd();
    expect(site['@type']).toBe('WebSite');
    expect(site.url).toBe(org.url);
  });

  it('SAĞLIK İDDİASI YOK — yasak kelimeler hiçbir JSON-LD metninde geçmez', () => {
    const blob = JSON.stringify([
      buildArchetypeJsonLd(sample),
      buildBreadcrumbJsonLd(sample),
      buildOrganizationJsonLd(),
      buildWebSiteJsonLd(),
    ]).toLowerCase();
    for (const banned of ['cure', 'treat', 'therapy', 'clinically', 'medical', 'disease']) {
      expect(blob).not.toContain(banned);
    }
  });
});
