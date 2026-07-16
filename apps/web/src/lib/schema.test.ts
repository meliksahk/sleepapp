import { describe, it, expect } from 'vitest';
import {
  buildArchetypeJsonLd,
  buildArchetypeListJsonLd,
  buildBreadcrumbJsonLd,
  buildFaqJsonLd,
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

  it('ItemList: sıralı archetype listesi', () => {
    const ld = buildArchetypeListJsonLd([
      { slug: 'deep-ocean', name: 'Deep Ocean' },
      { slug: 'overthinker', name: '3AM Overthinker' },
    ]);
    expect(ld['@type']).toBe('ItemList');
    const items = ld.itemListElement as Array<{ position: number; name: string; url: string }>;
    expect(items).toHaveLength(2);
    expect(items[0]).toMatchObject({ position: 1, name: 'Deep Ocean' });
    expect(items[1]?.url).toContain('/a/overthinker');
  });

  it('FAQPage: mainEntity Question/acceptedAnswer yapısı', () => {
    const ld = buildFaqJsonLd([
      { question: 'What is NOCTA?', answer: 'A relaxation and sleep ritual app.' },
      { question: 'Is it free?', answer: 'Yes, generous free tier.' },
    ]);
    expect(ld['@type']).toBe('FAQPage');
    type Q = { '@type': string; name: string; acceptedAnswer: { '@type': string; text: string } };
    const items = ld.mainEntity as Q[];
    expect(items).toHaveLength(2);
    expect(items[0]).toMatchObject({ '@type': 'Question', name: 'What is NOCTA?' });
    expect(items[0]?.acceptedAnswer).toMatchObject({ '@type': 'Answer' });
    expect(items[1]?.acceptedAnswer.text).toContain('free tier');
  });

  it('SAĞLIK İDDİASI YOK — yasak kelimeler hiçbir JSON-LD metninde geçmez', () => {
    const blob = JSON.stringify([
      buildArchetypeJsonLd(sample),
      buildBreadcrumbJsonLd(sample),
      buildOrganizationJsonLd(),
      buildWebSiteJsonLd(),
      buildArchetypeListJsonLd([{ slug: 'deep-ocean', name: 'Deep Ocean' }]),
      buildFaqJsonLd([
        { question: 'What is NOCTA?', answer: 'A relaxation and sleep ritual app.' },
      ]),
    ]).toLowerCase();
    for (const banned of ['cure', 'treat', 'therapy', 'clinically', 'medical', 'disease']) {
      expect(blob).not.toContain(banned);
    }
  });
});
